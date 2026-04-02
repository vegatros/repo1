##──────────────────────────────────────────────────────────────
## Networking – VNets, Subnets, NSGs, Peering, NAT Gateways
##──────────────────────────────────────────────────────────────

##── Primary Region ───────────────────────────────────────────

resource "azurerm_virtual_network" "primary" {
  name                = "${local.name_prefix}-primary-vnet"
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name
  address_space       = ["10.1.0.0/16"]
  tags                = local.common_tags
}

resource "azurerm_subnet" "primary_vm" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.primary.name
  virtual_network_name = azurerm_virtual_network.primary.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "primary_db" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.primary.name
  virtual_network_name = azurerm_virtual_network.primary.name
  address_prefixes     = ["10.1.2.0/24"]
}

resource "azurerm_subnet" "primary_pe" {
  name                 = "private-endpoint-subnet"
  resource_group_name  = azurerm_resource_group.primary.name
  virtual_network_name = azurerm_virtual_network.primary.name
  address_prefixes     = ["10.1.3.0/24"]
}

##── Secondary Region ─────────────────────────────────────────

resource "azurerm_virtual_network" "secondary" {
  name                = "${local.name_prefix}-secondary-vnet"
  location            = azurerm_resource_group.secondary.location
  resource_group_name = azurerm_resource_group.secondary.name
  address_space       = ["10.2.0.0/16"]
  tags                = local.common_tags
}

resource "azurerm_subnet" "secondary_vm" {
  name                 = "vm-subnet"
  resource_group_name  = azurerm_resource_group.secondary.name
  virtual_network_name = azurerm_virtual_network.secondary.name
  address_prefixes     = ["10.2.1.0/24"]
}

resource "azurerm_subnet" "secondary_db" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.secondary.name
  virtual_network_name = azurerm_virtual_network.secondary.name
  address_prefixes     = ["10.2.2.0/24"]
}

resource "azurerm_subnet" "secondary_pe" {
  name                 = "private-endpoint-subnet"
  resource_group_name  = azurerm_resource_group.secondary.name
  virtual_network_name = azurerm_virtual_network.secondary.name
  address_prefixes     = ["10.2.3.0/24"]
}

##── NAT Gateways (outbound internet for private VMs) ────────

resource "azurerm_public_ip" "nat" {
  for_each = {
    primary   = azurerm_resource_group.primary
    secondary = azurerm_resource_group.secondary
  }

  name                = "${local.name_prefix}-${each.key}-nat-pip"
  location            = each.value.location
  resource_group_name = each.value.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_nat_gateway" "main" {
  for_each = {
    primary   = azurerm_resource_group.primary
    secondary = azurerm_resource_group.secondary
  }

  name                = "${local.name_prefix}-${each.key}-natgw"
  location            = each.value.location
  resource_group_name = each.value.name
  sku_name            = "Standard"
  tags                = local.common_tags
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  for_each = azurerm_nat_gateway.main

  nat_gateway_id       = each.value.id
  public_ip_address_id = azurerm_public_ip.nat[each.key].id
}

resource "azurerm_subnet_nat_gateway_association" "primary_vm" {
  subnet_id      = azurerm_subnet.primary_vm.id
  nat_gateway_id = azurerm_nat_gateway.main["primary"].id
}

resource "azurerm_subnet_nat_gateway_association" "secondary_vm" {
  subnet_id      = azurerm_subnet.secondary_vm.id
  nat_gateway_id = azurerm_nat_gateway.main["secondary"].id
}

##── VNet Peering (bidirectional) ─────────────────────────────

resource "azurerm_virtual_network_peering" "primary_to_secondary" {
  name                         = "primary-to-secondary"
  resource_group_name          = azurerm_resource_group.primary.name
  virtual_network_name         = azurerm_virtual_network.primary.name
  remote_virtual_network_id    = azurerm_virtual_network.secondary.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

resource "azurerm_virtual_network_peering" "secondary_to_primary" {
  name                         = "secondary-to-primary"
  resource_group_name          = azurerm_resource_group.secondary.name
  virtual_network_name         = azurerm_virtual_network.secondary.name
  remote_virtual_network_id    = azurerm_virtual_network.primary.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

##── Network Security Groups ─────────────────────────────────

resource "azurerm_network_security_group" "vm" {
  for_each = {
    primary   = azurerm_resource_group.primary
    secondary = azurerm_resource_group.secondary
  }

  name                = "${local.name_prefix}-${each.key}-vm-nsg"
  location            = each.value.location
  resource_group_name = each.value.name
  tags                = local.common_tags

  # Allow inbound from Azure Load Balancer only
  security_rule {
    name                       = "AllowLBInbound"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "VirtualNetwork"
  }

  # Allow SSH from within the VNet (jumpbox / bastion)
  security_rule {
    name                       = "AllowSSHFromVNet"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # Deny all other inbound
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
