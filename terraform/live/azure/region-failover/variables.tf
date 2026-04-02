##──────────────────────────────────────────────────────────────
## Variables – Azure Multi-Region Failover
##──────────────────────────────────────────────────────────────

variable "project" {
  description = "Project name used for resource naming"
  type        = string
  default     = "regionfo"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "primary_location" {
  description = "Primary Azure region"
  type        = string
  default     = "eastus2"
}

variable "secondary_location" {
  description = "Secondary Azure region for failover"
  type        = string
  default     = "westus2"
}

variable "vm_size" {
  description = "Low-cost VM size (B-series burstable)"
  type        = string
  default     = "Standard_B2s"
}

variable "vm_admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureadmin"
}

variable "vm_admin_ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "db_admin_login" {
  description = "SQL Server admin login"
  type        = string
  default     = "sqladmin"
}

variable "db_admin_password" {
  description = "SQL Server admin password"
  type        = string
  sensitive   = true
}

variable "db_sku" {
  description = "Azure SQL Database SKU (low-cost tier)"
  type        = string
  default     = "S0"
}

variable "storage_replication_type" {
  description = "Storage account replication type for geo-redundancy"
  type        = string
  default     = "GZRS" # Geo-zone-redundant
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}

locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = merge(var.tags, {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
    pattern     = "multi-region-failover"
  })
}
