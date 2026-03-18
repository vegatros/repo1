##──────────────────────────────────────────────────────────────
## Virtual Machines – Low-Cost B-Series with Replicated Storage
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

##── Public IPs ──────────────────────────────────────────────

resource "azurerm_public_ip" "vm" {
  for_each = local.regions

  name                = "${local.name_prefix}-${each.key}-vm-pip"
  location            = each.value.rg.location
  resource_group_name = each.value.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

##── NICs ─────────────────────────────────────────────────────

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
    public_ip_address_id          = azurerm_public_ip.vm[each.key].id
  }
}

resource "azurerm_network_interface_security_group_association" "vm" {
  for_each = local.regions

  network_interface_id      = azurerm_network_interface.vm[each.key].id
  network_security_group_id = each.value.nsg.id
}

##── Virtual Machines (B-series – low cost burstable) ────────

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
    storage_account_type = "StandardSSD_ZRS" # Zone-redundant within region
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
