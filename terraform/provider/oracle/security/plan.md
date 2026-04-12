# Oracle Cloud Infrastructure — Security Summary Plan

## Architecture Overview

```
                          ┌─────────────────────────────────────────────────┐
                          │              OCI Security                        │
                          └──────┬──────────┬──────────┬──────────┬─────────┘
                                 │          │          │          │
               ┌─────────────────┘  ┌───────┘  ┌──────┘  ┌───────┘
               ▼                    ▼           ▼         ▼
    ┌─────────────────┐  ┌────────────────┐  ┌──────────────────┐  ┌──────────────────┐
    │    Identity     │  │    Network     │  │ Data Protection  │  │   Governance     │
    ├─────────────────┤  ├────────────────┤  ├──────────────────┤  ├──────────────────┤
    │ IAM Compartments│  │ Security Lists │  │  Vault / KMS     │  │  Cloud Guard     │
    │ Groups/Policies │  │ NSGs           │  │  Customer Keys   │  │  Security Zones  │
    │ Dynamic Groups  │  │ VCN Flow Logs  │  │  Object Storage  │  │  Audit Service   │
    │ Instance Princ. │  │ WAF            │  │  Data Safe       │  │  Vuln Scanning   │
    │ IDCS Federation │  │ Bastion Svc    │  │                  │  │                  │
    └─────────────────┘  └────────────────┘  └──────────────────┘  └──────────────────┘
                                                      │
                                          ┌───────────┘
                                          ▼
                               ┌─────────────────────┐
                               │      Compute        │
                               ├─────────────────────┤
                               │ Shielded Instances  │
                               │ Secure Boot + vTPM  │
                               │ OS Management Hub   │
                               │ OKE Image Scanning  │
                               └─────────────────────┘
```

---

## Identity & Access Management

### Compartment Hierarchy
```
root
├── platform/
│   ├── network/
│   └── security/
├── workloads/
│   ├── dev/
│   ├── qa/
│   └── prod/
└── sandbox/
```

### Policy Model
Policies are written in human-readable syntax and attached to compartments:

```hcl
# Allow app instances to read secrets from Vault
Allow dynamic-group app-instances to read secret-family in compartment workloads/prod

# Allow network admins to manage VCNs
Allow group network-admins to manage virtual-network-family in compartment platform/network

# Deny all access outside approved regions
Deny any-user to use all-resources where request.region != 'us-ashburn-1'
```

### Dynamic Groups (Instance Principals)
```hcl
# Compute instances in prod compartment — no static credentials
resource "oci_identity_dynamic_group" "app_instances" {
  name           = "app-instances-prod"
  description    = "Prod compute instances"
  compartment_id = var.tenancy_ocid
  matching_rule  = "instance.compartment.id = '${var.prod_compartment_id}'"
}
```

---

## Network Security

### Security Lists vs NSGs

| Feature | Security Lists | NSGs |
|---------|---------------|------|
| Scope | Subnet-level | NIC-level |
| Stateful | Yes | Yes |
| Best for | Broad subnet rules | Fine-grained per-resource |
| Recommended | Legacy | ✅ Preferred |

### NSG Rules (example)
```hcl
resource "oci_core_network_security_group_security_rule" "allow_https" {
  network_security_group_id = oci_core_network_security_group.app.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = var.lb_nsg_id
  source_type               = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range { min = 443; max = 443 }
  }
}
```

### Bastion Service
- Managed SSH access — no public IPs on compute
- Session types: SSH port forwarding, managed SSH
- Audit trail of all sessions

---

## Data Protection

### Vault (KMS)
```hcl
resource "oci_kms_vault" "main" {
  compartment_id = var.security_compartment_id
  display_name   = "prod-vault"
  vault_type     = "DEFAULT" # or VIRTUAL_PRIVATE for HSM-backed
}

resource "oci_kms_key" "block_volume" {
  compartment_id      = var.security_compartment_id
  display_name        = "block-volume-key"
  management_endpoint = oci_kms_vault.main.management_endpoint
  key_shape {
    algorithm = "AES"
    length    = 32
  }
}
```

### Data Safe
| Feature | Purpose |
|---------|---------|
| Security Assessment | Detect DB misconfigurations |
| User Assessment | Identify privileged/inactive users |
| Activity Auditing | Track all DB operations |
| Data Masking | Mask sensitive data in non-prod |
| Sensitive Data Discovery | Find PII/PCI data automatically |

---

## Compute Security

### Shielded Instances
```hcl
resource "oci_core_instance" "app" {
  # ...
  platform_config {
    type                           = "AMD_VM"
    is_secure_boot_enabled         = true
    is_trusted_platform_module_enabled = true
    is_measured_boot_enabled       = true
  }
}
```

### OKE (Kubernetes) Security
- Node pool images scanned via Vulnerability Scanning service
- Pod security via OPA/Gatekeeper
- Workload identity — pods use instance principals (no static keys)
- Private API endpoint + private node pools

---

## Governance & Threat Detection

### Cloud Guard
- Detects: public buckets, open security lists, inactive users, anomalous activity
- Responders: auto-remediate (e.g., make bucket private, disable user)

```hcl
resource "oci_cloud_guard_cloud_guard_configuration" "main" {
  compartment_id   = var.tenancy_ocid
  reporting_region = var.region
  status           = "ENABLED"
}
```

### Security Zones
Enforce security posture — policies that **cannot be overridden**:

| Zone Policy | Effect |
|-------------|--------|
| No public buckets | Object Storage buckets must be private |
| Encryption required | All block volumes must use customer-managed keys |
| No public IPs | Compute instances cannot have public IPs |
| Audit enabled | Audit service cannot be disabled |

### Audit Service
- All API calls logged automatically (no config needed)
- Retention: 90 days default, export to Object Storage for long-term
- Integrates with SIEM via Streaming service

---

## Vulnerability Scanning

```hcl
resource "oci_vulnerability_scanning_host_scan_recipe" "main" {
  compartment_id = var.security_compartment_id
  display_name   = "prod-scan-recipe"
  agent_settings {
    scan_level = "STANDARD"
    agent_configuration {
      vendor = "OCI"
    }
  }
  schedule {
    type = "DAILY"
  }
}
```

---

## Guardrails per Compartment

| Compartment | Controls |
|-------------|---------|
| **sandbox** | Region lock, no public IPs, Cloud Guard monitoring |
| **workloads/dev** | Above + NSGs required, Vault encryption |
| **workloads/prod** | All above + Security Zones, Data Safe, Shielded Instances |
| **platform/security** | Strictest — deny all except security admin group |

---

## Terraform Provider Configuration

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }
}

provider "oci" {
  region              = var.region
  auth                = "InstancePrincipal" # no static credentials
}
```

---

## Comparison: OCI vs AWS Security

| Capability | OCI | AWS Equivalent |
|------------|-----|---------------|
| IAM boundary | Compartments | Accounts / OUs |
| Threat detection | Cloud Guard | GuardDuty |
| Security posture | Security Zones | Security Hub |
| KMS | Vault | KMS |
| DB security | Data Safe | Macie / Inspector |
| Audit | Audit Service | CloudTrail |
| Bastion | Bastion Service | Systems Manager Session Manager |
| Vulnerability scan | Vulnerability Scanning | Inspector |
