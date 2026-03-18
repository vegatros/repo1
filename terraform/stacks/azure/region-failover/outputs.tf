##──────────────────────────────────────────────────────────────
## Outputs
##──────────────────────────────────────────────────────────────

output "traffic_manager_fqdn" {
  description = "Traffic Manager FQDN – single entry point with auto-failover"
  value       = azurerm_traffic_manager_profile.main.fqdn
}

output "primary_lb_public_ip" {
  description = "Primary load balancer public IP"
  value       = azurerm_public_ip.lb["primary"].ip_address
}

output "secondary_lb_public_ip" {
  description = "Secondary load balancer public IP"
  value       = azurerm_public_ip.lb["secondary"].ip_address
}

output "sql_failover_group_endpoint" {
  description = "SQL Failover Group read-write listener (auto-routes to active primary)"
  value       = "${azurerm_mssql_failover_group.main.name}.database.windows.net"
}

output "sql_failover_group_readonly_endpoint" {
  description = "SQL Failover Group read-only listener (routes to secondary replica)"
  value       = "${azurerm_mssql_failover_group.main.name}.secondary.database.windows.net"
}

output "sql_primary_private_endpoint_ip" {
  description = "Primary SQL private endpoint IP"
  value       = azurerm_private_endpoint.sql_primary.private_service_connection[0].private_ip_address
}

output "sql_secondary_private_endpoint_ip" {
  description = "Secondary SQL private endpoint IP"
  value       = azurerm_private_endpoint.sql_secondary.private_service_connection[0].private_ip_address
}

output "storage_account_name" {
  description = "Geo-redundant storage account name"
  value       = azurerm_storage_account.main.name
}

output "storage_primary_blob_endpoint" {
  description = "Storage primary blob endpoint"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "storage_secondary_blob_endpoint" {
  description = "Storage secondary (geo-replicated) blob endpoint"
  value       = azurerm_storage_account.main.secondary_blob_endpoint
}
