##──────────────────────────────────────────────────────────────
## Storage – Geo-Redundant with Tiered Lifecycle Policies
##──────────────────────────────────────────────────────────────

resource "azurerm_storage_account" "main" {
  name                     = replace("${local.name_prefix}store", "-", "")
  location                 = azurerm_resource_group.primary.location
  resource_group_name      = azurerm_resource_group.primary.name
  account_tier             = "Standard"
  account_replication_type = var.storage_replication_type # GZRS – geo + zone redundant
  account_kind             = "StorageV2"
  access_tier              = "Hot" # Default tier for new blobs
  tags                     = local.common_tags

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }
}

##── Containers ───────────────────────────────────────────────

resource "azurerm_storage_container" "app_data" {
  name                  = "app-data"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "backups" {
  name                  = "backups"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "logs" {
  name                  = "logs"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

##── Tiered Lifecycle Policy ─────────────────────────────────
## Hot  → Cool   after 30 days
## Cool → Archive after 90 days
## Delete archived blobs after 365 days

resource "azurerm_storage_management_policy" "tiering" {
  storage_account_id = azurerm_storage_account.main.id

  rule {
    name    = "app-data-tiering"
    enabled = true

    filters {
      prefix_match = ["app-data/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 30
        tier_to_archive_after_days_since_modification_greater_than = 90
        delete_after_days_since_modification_greater_than          = 365
      }

      snapshot {
        delete_after_days_since_creation_greater_than = 90
      }

      version {
        delete_after_days_since_creation = 90
      }
    }
  }

  rule {
    name    = "backups-tiering"
    enabled = true

    filters {
      prefix_match = ["backups/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 7
        tier_to_archive_after_days_since_modification_greater_than = 30
        delete_after_days_since_modification_greater_than          = 180
      }
    }
  }

  rule {
    name    = "logs-tiering"
    enabled = true

    filters {
      prefix_match = ["logs/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 14
        tier_to_archive_after_days_since_modification_greater_than = 60
        delete_after_days_since_modification_greater_than          = 365
      }
    }
  }
}

##── Grant VMs access to storage ──────────────────────────────

resource "azurerm_role_assignment" "vm_storage_access" {
  for_each = local.regions

  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.vm[each.key].identity[0].principal_id
}
