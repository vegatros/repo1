##──────────────────────────────────────────────────────────────
## Provider & Resource Groups – Azure Multi-Region Failover
##──────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {}
}

##── Resource Groups ──────────────────────────────────────────

resource "azurerm_resource_group" "primary" {
  name     = "${local.name_prefix}-primary-rg"
  location = var.primary_location
  tags     = local.common_tags
}

resource "azurerm_resource_group" "secondary" {
  name     = "${local.name_prefix}-secondary-rg"
  location = var.secondary_location
  tags     = local.common_tags
}
