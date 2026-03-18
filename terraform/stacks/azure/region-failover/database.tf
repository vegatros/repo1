##──────────────────────────────────────────────────────────────
## Azure SQL Database – Private Endpoints, Geo-Replicated
##──────────────────────────────────────────────────────────────

##── Primary SQL Server (public access disabled) ─────────────

resource "azurerm_mssql_server" "primary" {
  name                          = "${local.name_prefix}-primary-sql"
  location                      = azurerm_resource_group.primary.location
  resource_group_name           = azurerm_resource_group.primary.name
  version                       = "12.0"
  administrator_login           = var.db_admin_login
  administrator_login_password  = var.db_admin_password
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = local.common_tags
}

##── Secondary SQL Server (public access disabled) ───────────

resource "azurerm_mssql_server" "secondary" {
  name                          = "${local.name_prefix}-secondary-sql"
  location                      = azurerm_resource_group.secondary.location
  resource_group_name           = azurerm_resource_group.secondary.name
  version                       = "12.0"
  administrator_login           = var.db_admin_login
  administrator_login_password  = var.db_admin_password
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  tags                          = local.common_tags
}

##── Database (on primary server) ────────────────────────────

resource "azurerm_mssql_database" "main" {
  name      = "${local.name_prefix}-db"
  server_id = azurerm_mssql_server.primary.id
  sku_name  = var.db_sku

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

##── Private DNS Zone for SQL ────────────────────────────────

resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.primary.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_primary" {
  name                  = "sql-dns-link-primary"
  resource_group_name   = azurerm_resource_group.primary.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.primary.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_secondary" {
  name                  = "sql-dns-link-secondary"
  resource_group_name   = azurerm_resource_group.primary.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.secondary.id
  registration_enabled  = false
}

##── Private Endpoints for SQL Servers ───────────────────────

resource "azurerm_private_endpoint" "sql_primary" {
  name                = "${local.name_prefix}-primary-sql-pe"
  location            = azurerm_resource_group.primary.location
  resource_group_name = azurerm_resource_group.primary.name
  subnet_id           = azurerm_subnet.primary_pe.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "sql-primary-psc"
    private_connection_resource_id = azurerm_mssql_server.primary.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sql-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
  }
}

resource "azurerm_private_endpoint" "sql_secondary" {
  name                = "${local.name_prefix}-secondary-sql-pe"
  location            = azurerm_resource_group.secondary.location
  resource_group_name = azurerm_resource_group.secondary.name
  subnet_id           = azurerm_subnet.secondary_pe.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "sql-secondary-psc"
    private_connection_resource_id = azurerm_mssql_server.secondary.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sql-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
  }
}
