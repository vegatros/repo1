# Google Cloud Platform — Security Summary Plan

## Architecture Overview

```
                          ┌─────────────────────────────────────────────────┐
                          │              GCP Security                        │
                          └──────┬──────────┬──────────┬──────────┬─────────┘
                                 │          │          │          │
               ┌─────────────────┘  ┌───────┘  ┌──────┘  ┌───────┘
               ▼                    ▼           ▼         ▼
    ┌─────────────────┐  ┌────────────────┐  ┌──────────────────┐  ┌──────────────────┐
    │    Identity     │  │    Network     │  │ Data Protection  │  │   Governance     │
    ├─────────────────┤  ├────────────────┤  ├──────────────────┤  ├──────────────────┤
    │ IAM + Org Policy│  │ VPC Firewall   │  │  Cloud KMS       │  │  Security Command│
    │ Workload Identity│  │ VPC Flow Logs  │  │  CMEK            │  │  Center (SCC)    │
    │ Service Accounts│  │ Cloud Armor    │  │  Secret Manager  │  │  Org Policies    │
    │ Workforce IdP   │  │ Private Google │  │  DLP API         │  │  Audit Logs      │
    │ Domain Restrict │  │ Access / PSC   │  │  CSEK            │  │  Asset Inventory │
    └─────────────────┘  └────────────────┘  └──────────────────┘  └──────────────────┘
                                                      │
                                          ┌───────────┘
                                          ▼
                               ┌─────────────────────┐
                               │      Compute        │
                               ├─────────────────────┤
                               │ Shielded VMs        │
                               │ Secure Boot + vTPM  │
                               │ OS Login            │
                               │ GKE Workload Ident. │
                               └─────────────────────┘
```

---

## Identity & Access Management

### Resource Hierarchy
```
Organization
├── folders/
│   ├── platform/
│   │   ├── network/        (host project — Shared VPC)
│   │   └── security/
│   └── workloads/
│       ├── dev/
│       ├── qa/
│       └── prod/
└── folders/sandbox/
```

### IAM Principles
- Least privilege — prefer predefined roles over primitive (Owner/Editor)
- No service account keys — use Workload Identity Federation or attached service accounts
- Domain-restricted sharing org policy — prevent external identities

```hcl
resource "google_organization_policy" "domain_restrict" {
  org_id     = var.org_id
  constraint = "iam.allowedPolicyMemberDomains"
  list_policy {
    allow {
      values = ["C0xxxxxxx"] # your Google Workspace customer ID
    }
  }
}
```

### Workload Identity (no service account keys)
```hcl
resource "google_service_account" "app" {
  account_id   = "app-sa"
  display_name = "App Service Account"
}

resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.ksa_name}]"
}
```

---

## Network Security

### VPC Firewall Rules
```hcl
resource "google_compute_firewall" "deny_all_ingress" {
  name      = "deny-all-ingress"
  network   = google_compute_network.vpc.name
  priority  = 65534
  direction = "INGRESS"
  deny { protocol = "all" }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_https_lb" {
  name      = "allow-https-from-lb"
  network   = google_compute_network.vpc.name
  priority  = 1000
  direction = "INGRESS"
  allow { protocol = "tcp"; ports = ["443"] }
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"] # GCP LB health check ranges
}
```

### Private Google Access / PSC
- VMs without public IPs reach Google APIs via Private Google Access
- Private Service Connect (PSC) for managed services (Cloud SQL, GCS) — no internet traversal

### Cloud Armor (WAF)
```hcl
resource "google_compute_security_policy" "waf" {
  name = "waf-policy"

  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      expr { expression = "evaluatePreconfiguredExpr('sqli-stable')" }
    }
  }

  rule {
    action   = "deny(403)"
    priority = 1001
    match {
      expr { expression = "evaluatePreconfiguredExpr('xss-stable')" }
    }
  }

  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config { src_ip_ranges = ["*"] }
    }
  }
}
```

---

## Data Protection

### Cloud KMS (CMEK)
```hcl
resource "google_kms_key_ring" "main" {
  name     = "prod-keyring"
  location = var.region
}

resource "google_kms_crypto_key" "storage" {
  name            = "gcs-key"
  key_ring        = google_kms_key_ring.main.id
  rotation_period = "7776000s" # 90 days
}
```

### Secret Manager
```hcl
resource "google_secret_manager_secret" "db_password" {
  secret_id = "db-password"
  replication { automatic {} }
}
```

### Cloud DLP
- Scan GCS buckets and BigQuery for PII/PCI data automatically
- De-identify sensitive data before use in non-prod environments

---

## Compute Security

### Shielded VMs
```hcl
resource "google_compute_instance" "app" {
  # ...
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private.id
    # no access_config block = no public IP
  }
}
```

### GKE Security
```hcl
resource "google_container_cluster" "main" {
  # ...
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  enable_shielded_nodes = true
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }
}
```

---

## Governance & Threat Detection

### Security Command Center (SCC)
- Threat detection: anomalous IAM grants, crypto mining, data exfiltration
- Vulnerability findings: public buckets, open firewall rules, unencrypted disks
- Integrates with Chronicle SIEM

### Organization Policies

| Policy Constraint | Effect |
|-------------------|--------|
| `compute.requireShieldedVm` | All VMs must use Shielded VM |
| `compute.vmExternalIpAccess` | Block public IPs on VMs |
| `storage.uniformBucketLevelAccess` | Enforce uniform bucket IAM |
| `storage.publicAccessPrevention` | Block public GCS buckets |
| `iam.disableServiceAccountKeyCreation` | No downloadable SA keys |
| `iam.allowedPolicyMemberDomains` | Restrict to org domain only |
| `gcp.resourceLocations` | Restrict to approved regions |

```hcl
resource "google_organization_policy" "no_public_ips" {
  org_id     = var.org_id
  constraint = "compute.vmExternalIpAccess"
  list_policy { deny { all = true } }
}

resource "google_organization_policy" "no_sa_keys" {
  org_id     = var.org_id
  constraint = "iam.disableServiceAccountKeyCreation"
  boolean_policy { enforced = true }
}
```

### Audit Logs
```hcl
resource "google_project_iam_audit_config" "all" {
  project = var.project_id
  service = "allServices"
  audit_log_config { log_type = "ADMIN_READ" }
  audit_log_config { log_type = "DATA_READ" }
  audit_log_config { log_type = "DATA_WRITE" }
}
```

---

## Guardrails per Folder

| Folder | Controls |
|--------|---------|
| **sandbox** | Region lock, no public IPs, SCC monitoring |
| **workloads/dev** | Above + no SA keys, uniform bucket access |
| **workloads/prod** | All above + CMEK, Shielded VMs, Binary Authorization, DLP |
| **platform/security** | Strictest — org admin group only, all audit logs |

---

## Terraform Provider Configuration

```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  # Auth via Workload Identity Federation or Application Default Credentials
  # No static service account keys
}
```

---

## Comparison: GCP vs AWS vs OCI Security

| Capability | GCP | AWS | OCI |
|------------|-----|-----|-----|
| IAM boundary | Projects / Folders | Accounts / OUs | Compartments |
| Threat detection | SCC | GuardDuty | Cloud Guard |
| Security posture | Org Policies | Security Hub | Security Zones |
| KMS | Cloud KMS | KMS | Vault |
| Secrets | Secret Manager | Secrets Manager | Vault Secrets |
| Data discovery | Cloud DLP | Macie | Data Safe |
| Audit | Cloud Audit Logs | CloudTrail | Audit Service |
| Bastion | IAP TCP Forwarding | SSM Session Manager | Bastion Service |
| Vulnerability scan | SCC / Container Analysis | Inspector | Vulnerability Scanning |
| WAF | Cloud Armor | WAF | WAF |
