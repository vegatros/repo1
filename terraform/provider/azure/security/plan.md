# Azure — Security Summary Plan

## Architecture Overview

```
                          ┌─────────────────────────────────────────────────┐
                          │              Azure Security                      │
                          └──────┬──────────┬──────────┬──────────┬─────────┘
                                 │          │          │          │
               ┌─────────────────┘  ┌───────┘  ┌──────┘  ┌───────┘
               ▼                    ▼           ▼         ▼
    ┌─────────────────┐  ┌────────────────┐  ┌──────────────────┐  ┌──────────────────┐
    │    Identity     │  │    Network     │  │ Data Protection  │  │   Governance     │
    ├─────────────────┤  ├────────────────┤  ├──────────────────┤  ├──────────────────┤
    │ Entra ID / RBAC │  │ Azure Firewall │  │  Key Vault       │  │  Defender for    │
    │ Managed Identity│  │ NSGs + ASGs    │  │  CMEK            │  │  Cloud (CSPM)    │
    │ PIM (JIT access)│  │ Private Endpts │  │  Storage Encrypt │  │  Azure Policy    │
    │ Conditional Acc.│  │ DDoS Protection│  │  Purview (DLP)   │  │  Activity Logs   │
    │ MFA Enforcement │  │ VNet Flow Logs │  │  Confidential VM │  │  Microsoft Senti │
    └─────────────────┘  └────────────────┘  └──────────────────┘  └──────────────────┘
                                                      │
                                          ┌───────────┘
                                          ▼
                               ┌─────────────────────┐
                               │      Compute        │
                               ├─────────────────────┤
                               │ Trusted Launch VMs  │
                               │ Secure Boot + vTPM  │
                               │ Disk Encryption     │
                               │ AKS Workload Ident. │
                               └─────────────────────┘
```

---

## Identity & Access Management

### Management Group Hierarchy
```
Tenant Root Group
└── org-root
    ├── Platform MG
    │   ├── Identity Subscription     ← Entra ID, PIM
    │   ├── Management Subscription   ← Defender, Log Analytics
    │   └── Connectivity Subscription ← Firewall, VPN/ER, DNS
    ├── Landing Zones MG
    │   ├── Corp MG (private, hub-connected)
    │   │   ├── Dev Subscription(s)
    │   │   ├── QA Subscription(s)
    │   │   └── Prod Subscription(s)
    │   └── Online MG (internet-facing)
    └── Sandbox MG (isolated)
```

### Managed Identity (no credentials)
```hcl
resource "azurerm_linux_virtual_machine" "app" {
  # ...
  identity {
    type = "SystemAssigned" # no client secrets or certificates
  }
}

# Grant VM access to Key Vault secrets
resource "azurerm_key_vault_access_policy" "vm" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_virtual_machine.app.identity[0].principal_id
  secret_permissions = ["Get", "List"]
}
```

### Privileged Identity Management (PIM)
- Just-in-time privileged access — no standing Owner/Contributor roles
- Approval workflow + MFA required for activation
- Time-bound access (max 8 hours)

---

## Network Security

### Hub-and-Spoke with Azure Firewall
```hcl
resource "azurerm_firewall_policy_rule_collection_group" "app" {
  name               = "app-rules"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 200

  network_rule_collection {
    name     = "allow-outbound"
    priority = 100
    action   = "Allow"
    rule {
      name                  = "allow-https"
      protocols             = ["TCP"]
      source_addresses      = ["10.1.0.0/16"]
      destination_addresses = ["*"]
      destination_ports     = ["443"]
    }
  }
}
```

### NSGs + ASGs
```hcl
# Application Security Group — group VMs logically, not by IP
resource "azurerm_application_security_group" "app" {
  name                = "app-asg"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_network_security_rule" "allow_https_inbound" {
  name                                       = "allow-https-inbound"
  priority                                   = 100
  direction                                  = "Inbound"
  access                                     = "Allow"
  protocol                                   = "Tcp"
  source_port_range                          = "*"
  destination_port_range                     = "443"
  source_address_prefix                      = "AzureLoadBalancer"
  destination_application_security_group_ids = [azurerm_application_security_group.app.id]
  # ...
}
```

### Private Endpoints
```hcl
resource "azurerm_private_endpoint" "storage" {
  name                = "storage-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.private.id

  private_service_connection {
    name                           = "storage-psc"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
}
```

---

## Data Protection

### Key Vault (CMEK)
```hcl
resource "azurerm_key_vault" "main" {
  name                        = "prod-kv"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "premium" # HSM-backed
  purge_protection_enabled    = true
  soft_delete_retention_days  = 90
  public_network_access_enabled = false  # private endpoint only
}

resource "azurerm_key_vault_key" "disk" {
  name         = "disk-encryption-key"
  key_vault_id = azurerm_key_vault.main.id
  key_type     = "RSA"
  key_size     = 4096
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]
}
```

### Storage Encryption
```hcl
resource "azurerm_storage_account" "main" {
  # ...
  min_tls_version           = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled = false  # Entra ID auth only

  blob_properties {
    versioning_enabled = true
  }

  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.storage.id
    user_assigned_identity_id = azurerm_user_assigned_identity.storage.id
  }
}
```

### Microsoft Purview (DLP)
- Scan Azure Storage, SQL, Synapse for PII/PCI/PHI
- Data classification labels applied automatically
- Sensitivity labels enforced via Conditional Access

---

## Compute Security

### Trusted Launch VMs
```hcl
resource "azurerm_linux_virtual_machine" "app" {
  # ...
  vtpm_enabled        = true
  secure_boot_enabled = true

  os_disk {
    security_encryption_type = "VMGuestStateOnly"
  }
}
```

### AKS Security
```hcl
resource "azurerm_kubernetes_cluster" "main" {
  # ...
  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  default_node_pool {
    enable_node_public_ip = false
    vnet_subnet_id        = azurerm_subnet.aks.id
  }

  api_server_access_profile {
    authorized_ip_ranges = var.admin_ip_ranges
  }

  azure_policy_enabled = true

  microsoft_defender {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }
}
```

---

## Governance & Threat Detection

### Microsoft Defender for Cloud (CSPM)
- Secure Score — continuous posture assessment
- Workload protections: Defender for Servers, Storage, SQL, Containers, Key Vault
- Attack path analysis and cloud security graph

```hcl
resource "azurerm_security_center_subscription_pricing" "defender" {
  for_each      = toset(["VirtualMachines", "StorageAccounts", "SqlServers", "KeyVaults", "Containers"])
  tier          = "Standard"
  resource_type = each.value
}
```

### Azure Policy Guardrails

| Policy | Effect |
|--------|--------|
| Require HTTPS on storage accounts | Deny |
| Allowed locations | Deny (restrict regions) |
| Require managed identity on VMs | Audit/Deny |
| No public IP on VMs | Deny |
| Key Vault purge protection required | Deny |
| TLS 1.2 minimum | Deny |
| Disk encryption required | Audit/Deny |
| No public blob access | Deny |

```hcl
resource "azurerm_management_group_policy_assignment" "no_public_ips" {
  name                 = "deny-public-ips"
  management_group_id  = azurerm_management_group.prod.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/83a86a26-fd1f-447c-b59d-e51f44264114"
  enforce              = true
}
```

### Activity Logs + Microsoft Sentinel
```hcl
# Export activity logs to Log Analytics
resource "azurerm_monitor_diagnostic_setting" "activity" {
  name               = "activity-logs"
  target_resource_id = "/subscriptions/${var.subscription_id}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id

  enabled_log { category = "Administrative" }
  enabled_log { category = "Security" }
  enabled_log { category = "Policy" }
  enabled_log { category = "Alert" }
}
```

---

## Guardrails per Management Group

| Management Group | Controls |
|-----------------|---------|
| **Sandbox** | Region lock, no hub connectivity, Defender monitoring |
| **Corp/Dev-QA** | Above + no public IPs, HTTPS required, managed identity |
| **Corp/Prod** | All above + CMEK, Trusted Launch, PIM, Purview, Sentinel |
| **Platform/Security** | Strictest — break-glass accounts only, all diagnostic logs |

---

## Terraform Provider Configuration

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.50"
    }
  }
}

provider "azurerm" {
  features {}
  # Auth via Workload Identity Federation (OIDC) or Managed Identity
  # No client secrets stored in code
  use_oidc = true
}
```

---

## Comparison: Azure vs AWS vs GCP vs OCI Security

| Capability | Azure | AWS | GCP | OCI |
|------------|-------|-----|-----|-----|
| IAM boundary | Subscriptions / MGs | Accounts / OUs | Projects / Folders | Compartments |
| Threat detection | Defender for Cloud | GuardDuty | SCC | Cloud Guard |
| Security posture | Azure Policy | Security Hub | Org Policies | Security Zones |
| KMS | Key Vault | KMS | Cloud KMS | Vault |
| Secrets | Key Vault Secrets | Secrets Manager | Secret Manager | Vault Secrets |
| Data discovery | Purview | Macie | Cloud DLP | Data Safe |
| Audit | Activity Logs | CloudTrail | Cloud Audit Logs | Audit Service |
| Bastion | Azure Bastion | SSM Session Manager | IAP TCP Forwarding | Bastion Service |
| Vulnerability scan | Defender for Cloud | Inspector | SCC | Vulnerability Scanning |
| WAF | Azure WAF | WAF | Cloud Armor | WAF |
| SIEM | Microsoft Sentinel | Security Lake | Chronicle | — |
