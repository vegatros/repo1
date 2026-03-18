##──────────────────────────────────────────────────────────────
## Azure SQL Database – Geo-Replicated with Auto-Failover Group
##──────────────────────────────────────────────────────────────

##── Primary SQL Server ──────────────────────────────────────

resource "azurerm_mssql_server" "primary" {
  name                         = "${local.name_prefix}-primary-sql"
  location                     = azurerm_resource_group.primary.location
  resource_group_name          = azurerm_resource_group.primary.name
  version                      = "12.0"
  administrator_login          = var.db_admin_login
  administrator_login_password = var.db_admin_password
  minimum_tls_version          = "1.2"
  tags                         = local.common_tags
}

##── Secondary SQL Server ────────────────────────────────────

resource "azurerm_mssql_server" "secondary" {
  name                         = "${local.name_prefix}-secondary-sql"
  location                     = azurerm_resource_group.secondary.location
  resource_group_name          = azurerm_resource_group.secondary.name
  version                      = "12.0"
  administrator_login          = var.db_admin_login
  administrator_login_password = var.db_admin_password
  minimum_tls_version          = "1.2"
  tags                         = local.common_tags
}

##── Database (on primary server) ────────────────────────────

resource "azurerm_mssql_database" "main" {
  name      = "${local.name_prefix}-db"
  server_id = azurerm_mssql_server.primary.id
  sku_name  = var.db_sku # S0 – low cost Standard tier

  short_term_retention_policy {
    retention_days = 7
  }

  long_term_retention_policy {
    weekly_retention  = "P4W"
    monthly_retention = "P12M"
  }

  tags = local.common_tags
}

##── Auto-Failover Group ─────────────────────────────────────
## Automatic failover if primary is unreachable for > 1 hour.
## The failover group provides a listener endpoint that
## automatically routes to whichever server is currently primary.

resource "azurerm_mssql_failover_group" "main" {
  name      = "${local.name_prefix}-fog"
  server_id = azurerm_mssql_server.primary.id

  databases = [
    azurerm_mssql_database.main.id
  ]

  partner_server {
    id = azurerm_mssql_server.secondary.id
  }

  read_write_endpoint_failover_policy {
    mode          = "Automatic"
    grace_minutes = 60
  }

  readonly_endpoint_failover_policy_enabled = true

  tags = local.common_tags
}

##── Firewall: allow Azure services ──────────────────────────

resource "azurerm_mssql_firewall_rule" "azure_services_primary" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.primary.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_firewall_rule" "azure_services_secondary" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.secondary.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

##── VNet Rules – allow VM subnets ───────────────────────────

resource "azurerm_mssql_virtual_network_rule" "primary" {
  name      = "allow-primary-vms"
  server_id = azurerm_mssql_server.primary.id
  subnet_id = azurerm_subnet.primary_vm.id
}

resource "azurerm_mssql_virtual_network_rule" "secondary" {
  name      = "allow-secondary-vms"
  server_id = azurerm_mssql_server.secondary.id
  subnet_id = azurerm_subnet.secondary_vm.id
}
