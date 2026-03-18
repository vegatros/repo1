##──────────────────────────────────────────────────────────────
## Traffic Manager – DNS-Based Auto-Failover
##──────────────────────────────────────────────────────────────
## Priority routing: all traffic goes to the primary LB.
## If the primary health probe fails, traffic automatically
## shifts to the secondary LB.

resource "azurerm_traffic_manager_profile" "main" {
  name                   = "${local.name_prefix}-tm"
  resource_group_name    = azurerm_resource_group.primary.name
  traffic_routing_method = "Priority"
  tags                   = local.common_tags

  dns_config {
    relative_name = "${local.name_prefix}-app"
    ttl           = 60
  }

  monitor_config {
    protocol                     = "HTTPS"
    port                         = 443
    path                         = "/health"
    interval_in_seconds          = 10
    timeout_in_seconds           = 5
    tolerated_number_of_failures = 3
  }
}

##── Primary Endpoint (priority 1 – LB public IP) ───────────

resource "azurerm_traffic_manager_azure_endpoint" "primary" {
  name               = "primary-endpoint"
  profile_id         = azurerm_traffic_manager_profile.main.id
  target_resource_id = azurerm_public_ip.lb["primary"].id
  priority           = 1
}

##── Secondary Endpoint (priority 2 – failover LB) ──────────

resource "azurerm_traffic_manager_azure_endpoint" "secondary" {
  name               = "secondary-endpoint"
  profile_id         = azurerm_traffic_manager_profile.main.id
  target_resource_id = azurerm_public_ip.lb["secondary"].id
  priority           = 2
}
