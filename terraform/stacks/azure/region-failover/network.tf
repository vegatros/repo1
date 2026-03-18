##──────────────────────────────────────────────────────────────
## Networking – VNets, Subnets, NSGs, Peering
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

  delegation {
    name = "sql-delegation"
    service_delegation {
      name = "Microsoft.Sql/managedInstances"
    }
  }
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

  delegation {
    name = "sql-delegation"
    service_delegation {
      name = "Microsoft.Sql/managedInstances"
    }
  }
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

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1020
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
