##──────────────────────────────────────────────────────────────
## Virtual Machines – Private Subnets, Behind Load Balancers
##──────────────────────────────────────────────────────────────

locals {
  regions = {
    primary = {
      rg     = azurerm_resource_group.primary
      subnet = azurerm_subnet.primary_vm
      nsg    = azurerm_network_security_group.vm["primary"]
    }
    secondary = {
      rg     = azurerm_resource_group.secondary
      subnet = azurerm_subnet.secondary_vm
      nsg    = azurerm_network_security_group.vm["secondary"]
    }
  }
}

##── Public Load Balancers (front door for Traffic Manager) ──

resource "azurerm_public_ip" "lb" {
  for_each = local.regions

  name                = "${local.name_prefix}-${each.key}-lb-pip"
  location            = each.value.rg.location
  resource_group_name = each.value.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

resource "azurerm_lb" "main" {
  for_each = local.regions

  name                = "${local.name_prefix}-${each.key}-lb"
  location            = each.value.rg.location
  resource_group_name = each.value.rg.name
  sku                 = "Standard"
  tags                = local.common_tags

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.lb[each.key].id
  }
}

resource "azurerm_lb_backend_address_pool" "main" {
  for_each = local.regions

  name            = "vm-backend-pool"
  loadbalancer_id = azurerm_lb.main[each.key].id
}

resource "azurerm_lb_probe" "health" {
  for_each = local.regions

  name                = "http-health"
  loadbalancer_id     = azurerm_lb.main[each.key].id
  protocol            = "Tcp"
  port                = 443
  interval_in_seconds = 10
  number_of_probes    = 3
}

resource "azurerm_lb_rule" "https" {
  for_each = local.regions

  name                           = "https-rule"
  loadbalancer_id                = azurerm_lb.main[each.key].id
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main[each.key].id]
  probe_id                       = azurerm_lb_probe.health[each.key].id
  disable_outbound_snat          = true
}

resource "azurerm_lb_rule" "http" {
  for_each = local.regions

  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.main[each.key].id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main[each.key].id]
  probe_id                       = azurerm_lb_probe.health[each.key].id
  disable_outbound_snat          = true
}

##── NICs (private only – no public IPs) ─────────────────────

resource "azurerm_network_interface" "vm" {
  for_each = local.regions

  name                = "${local.name_prefix}-${each.key}-vm-nic"
  location            = each.value.rg.location
  resource_group_name = each.value.rg.name
  tags                = local.common_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = each.value.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "vm" {
  for_each = local.regions

  network_interface_id      = azurerm_network_interface.vm[each.key].id
  network_security_group_id = each.value.nsg.id
}

resource "azurerm_network_interface_backend_address_pool_association" "vm" {
  for_each = local.regions

  network_interface_id    = azurerm_network_interface.vm[each.key].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main[each.key].id
}

##── Virtual Machines (B-series – private, no public IP) ─────

resource "azurerm_linux_virtual_machine" "vm" {
  for_each = local.regions

  name                            = "${local.name_prefix}-${each.key}-vm"
  location                        = each.value.rg.location
  resource_group_name             = each.value.rg.name
  size                            = var.vm_size
  admin_username                  = var.vm_admin_username
  disable_password_authentication = true
  tags                            = local.common_tags

  network_interface_ids = [
    azurerm_network_interface.vm[each.key].id
  ]

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = var.vm_admin_ssh_public_key
  }

  os_disk {
    name                 = "${local.name_prefix}-${each.key}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_ZRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

##── Managed Data Disks (replicated across zones) ────────────

resource "azurerm_managed_disk" "data" {
  for_each = local.regions

  name                 = "${local.name_prefix}-${each.key}-datadisk"
  location             = each.value.rg.location
  resource_group_name  = each.value.rg.name
  storage_account_type = "StandardSSD_ZRS"
  create_option        = "Empty"
  disk_size_gb         = 64
  tags                 = local.common_tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  for_each = local.regions

  managed_disk_id    = azurerm_managed_disk.data[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.vm[each.key].id
  lun                = 0
  caching            = "ReadWrite"
}
