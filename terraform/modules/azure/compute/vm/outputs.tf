output "vm_id" {
  description = "VM resource ID"
  value       = azurerm_linux_virtual_machine.this.id
}

output "vm_name" {
  description = "VM name"
  value       = azurerm_linux_virtual_machine.this.name
}

output "private_ip" {
  description = "Private IP address"
  value       = azurerm_network_interface.this.private_ip_address
}

output "public_ip" {
  description = "Public IP address (null if not created)"
  value       = var.create_public_ip ? azurerm_public_ip.this[0].ip_address : null
}

output "nic_id" {
  description = "Network interface ID"
  value       = azurerm_network_interface.this.id
}

output "identity_principal_id" {
  description = "System-assigned managed identity principal ID"
  value       = azurerm_linux_virtual_machine.this.identity[0].principal_id
}
