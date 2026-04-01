# AWS EC2 → Azure VM Migration Plan

End-to-end migration plan using Azure Migrate for lift-and-shift of EC2 workloads to Azure VMs with near-zero downtime.

---

## Architecture Overview

```
  ┌─────────────────────────────────────────────────────────────────────────┐
  │                          MIGRATION FLOW                                  │
  └─────────────────────────────────────────────────────────────────────────┘

  AWS (Source)                                          Azure (Target)
  ─────────────────────────────────────────────────────────────────────────

  ┌──────────────────────┐                    ┌──────────────────────────┐
  │        VPC           │                    │         VNet             │
  │   10.0.0.0/16        │                    │     10.100.0.0/16        │
  │                      │                    │                          │
  │  ┌────────────────┐  │                    │  ┌────────────────────┐  │
  │  │  EC2 Instance  │  │  ─── Replicate ──► │  │    Azure VM        │  │
  │  │  (any OS)      │  │                    │  │    (same OS)       │  │
  │  │  EBS Volumes   │  │                    │  │    Managed Disks   │  │
  │  └────────────────┘  │                    │  └────────────────────┘  │
  │                      │                    │                          │
  │  ┌────────────────┐  │                    │  ┌────────────────────┐  │
  │  │ Security Group │  │  ─── Translate ──► │  │  Network Security  │  │
  │  │  (inbound/out) │  │                    │  │  Group (NSG)       │  │
  │  └────────────────┘  │                    │  └────────────────────┘  │
  │                      │                    │                          │
  │  ┌────────────────┐  │                    │  ┌────────────────────┐  │
  │  │   IAM Role     │  │  ─── Map to ─────► │  │  Managed Identity  │  │
  │  └────────────────┘  │                    │  └────────────────────┘  │
  │                      │                    │                          │
  │  ┌────────────────┐  │                    │  ┌────────────────────┐  │
  │  │  ALB / NLB     │  │  ─── Replace ───► │  │  App Gateway / LB  │  │
  │  └────────────────┘  │                    │  └────────────────────┘  │
  └──────────────────────┘                    └──────────────────────────┘
            │                                              │
            └──────────── VPN / ExpressRoute ─────────────┘
                         (active during migration)
```

---

## Migration Phases

```
  Phase 1          Phase 2          Phase 3          Phase 4          Phase 5
  ──────────       ──────────       ──────────       ──────────       ──────────
  ASSESS      ──►  PREPARE     ──►  REPLICATE   ──►  TEST        ──►  CUTOVER
  2–4 weeks        1–2 weeks        1–2 weeks        1 week           Hours

  • Inventory      • Azure          • Deploy         • Spin up        • Stop
    EC2s             Migrate          appliance        test VMs         replication
  • Map             setup          • Initial        • Validate       • Update DNS
    dependencies   • VNet/NSG        replication      app/data       • Decommission
  • Size VMs         creation       • Delta sync     • Perf test       EC2s
  • Estimate       • VPN/ER          (continuous)   • Rollback
    costs            setup                            test
```

---

## Detailed Architecture

```
  ┌─────────────────────────────────────────────────────────────────────────┐
  │                     AZURE MIGRATE REPLICATION FLOW                       │
  └─────────────────────────────────────────────────────────────────────────┘

  AWS Account                          Azure Subscription
  ──────────────────────────────────────────────────────────────────────────

  ┌─────────────────────┐              ┌──────────────────────────────────┐
  │  Azure Migrate      │              │  Azure Migrate Project           │
  │  Appliance (EC2)    │──────────────►  (Discovery + Assessment)        │
  │  - Discovers VMs    │  HTTPS 443   └──────────────────────────────────┘
  │  - Sends metadata   │
  └─────────────────────┘              ┌──────────────────────────────────┐
                                       │  Replication Storage Account     │
  ┌─────────────────────┐              │  (staging area for disk data)    │
  │  Source EC2         │──────────────►                                  │
  │  - OS disk          │  Block-level │  ┌──────────────────────────┐    │
  │  - Data disks       │  replication │  │  Managed Disks (target)  │    │
  │  - Running apps     │              │  │  Premium SSD / Standard  │    │
  └─────────────────────┘              │  └──────────────────────────┘    │
                                       └──────────────────────────────────┘
                                                      │
                                                      ▼
                                       ┌──────────────────────────────────┐
                                       │  Target Azure VM                 │
                                       │  ┌────────────────────────────┐  │
                                       │  │  Resource Group            │  │
                                       │  │  ├─ Virtual Machine        │  │
                                       │  │  ├─ NIC                    │  │
                                       │  │  ├─ OS Managed Disk        │  │
                                       │  │  ├─ Data Managed Disk(s)   │  │
                                       │  │  └─ NSG                    │  │
                                       │  └────────────────────────────┘  │
                                       └──────────────────────────────────┘
```

---

## AWS → Azure Resource Mapping

| AWS Resource | Azure Equivalent | Notes |
|---|---|---|
| EC2 Instance | Azure VM | Match vCPU/RAM; see sizing table below |
| EBS gp3 Volume | Premium SSD Managed Disk | Match IOPS/throughput |
| EBS gp2 Volume | Standard SSD Managed Disk | |
| EBS io2 Volume | Ultra Disk | High-perf workloads |
| VPC | Virtual Network (VNet) | |
| Subnet | Subnet | |
| Security Group | Network Security Group (NSG) | Rules translate 1:1 |
| Internet Gateway | Default outbound / NAT Gateway | |
| NAT Gateway | NAT Gateway | |
| Route Table | Route Table (UDR) | |
| ALB | Azure Application Gateway | Layer 7 |
| NLB | Azure Load Balancer | Layer 4 |
| Route53 | Azure DNS / Traffic Manager | |
| IAM Role | Managed Identity | |
| IAM Policy | Azure RBAC Role Assignment | |
| CloudWatch | Azure Monitor + Log Analytics | |
| S3 | Azure Blob Storage | |
| RDS | Azure Database (MySQL/PostgreSQL/SQL) | Separate migration path |

---

## EC2 → Azure VM Sizing

```
  AWS Instance    vCPU  RAM     Azure Equivalent    Series
  ─────────────────────────────────────────────────────────
  t3.micro          2    1 GB   B1s                 B-series (burstable)
  t3.small          2    2 GB   B1ms                B-series
  t3.medium         2    4 GB   B2s                 B-series
  t3.large          2    8 GB   B2ms                B-series
  m5.large          2    8 GB   D2s_v3              D-series (general)
  m5.xlarge         4   16 GB   D4s_v3              D-series
  m5.2xlarge        8   32 GB   D8s_v3              D-series
  m5.4xlarge       16   64 GB   D16s_v3             D-series
  c5.large          2    4 GB   F2s_v2              F-series (compute)
  c5.xlarge         4    8 GB   F4s_v2              F-series
  r5.large          2   16 GB   E2s_v3              E-series (memory)
  r5.xlarge         4   32 GB   E4s_v3              E-series
```

---

## Network Architecture During Migration

```
  ┌──────────────────────────────────────────────────────────────────────┐
  │                    HYBRID CONNECTIVITY                                │
  └──────────────────────────────────────────────────────────────────────┘

  AWS                                              Azure
  ─────────────────────────────────────────────────────────────────────

  ┌──────────────────┐                        ┌──────────────────────┐
  │  VPC             │                        │  VNet                │
  │  10.0.0.0/16     │                        │  10.100.0.0/16       │
  │                  │                        │                      │
  │  ┌────────────┐  │                        │  ┌────────────────┐  │
  │  │ EC2 (src)  │  │                        │  │ Azure VM (tgt) │  │
  │  └────────────┘  │                        │  └────────────────┘  │
  │                  │                        │                      │
  │  ┌────────────┐  │   Site-to-Site VPN     │  ┌────────────────┐  │
  │  │ VPN GW /   │◄─┼────────────────────────┼─►│ VPN Gateway /  │  │
  │  │ Direct     │  │   or ExpressRoute       │  │ ExpressRoute   │  │
  │  │ Connect    │  │   (during migration)    │  │ Circuit        │  │
  │  └────────────┘  │                        │  └────────────────┘  │
  └──────────────────┘                        └──────────────────────┘

  Options:
  ├─ Site-to-Site VPN   : Quick setup, ~1.25 Gbps, sufficient for most migrations
  └─ ExpressRoute       : Private, up to 100 Gbps, for large data volumes
```

---

## Cutover Sequence

```
  T-24h                T-1h                 T=0 (Cutover)         T+1h
  ──────────────────────────────────────────────────────────────────────
  • Final delta        • Pause app          • Stop replication    • Monitor
    sync check           writes (maint        on all VMs            Azure VMs
  • Validate             window)            • Final delta sync    • Validate
    Azure VMs          • Verify delta       • Start Azure VMs       app health
  • Pre-warm             sync complete      • Update DNS TTL      • Keep EC2s
    Azure VMs          • Notify users         (60s → live)          stopped
  • Update DNS                              • Smoke test            (48h hold)
    TTL to 60s                              • Confirm health      • Decommission
                                                                    EC2s
```

---

## Rollback Plan

```
  If issues detected within 48h of cutover:

  1. Revert DNS → point back to EC2 Elastic IPs / ALB
  2. Restart EC2 instances (kept stopped, not terminated)
  3. Notify stakeholders
  4. Investigate Azure VM issues
  5. Re-attempt migration after root cause resolved

  ⚠️  Do NOT terminate EC2s until Azure VMs are validated stable for 48h
```

---

## Terraform Implementation Plan

```
  terraform/stacks/azure/aws-azure-migrate/
  ├── main.tf              # Resource group, providers
  ├── network.tf           # VNet, subnets, NSGs, VPN Gateway
  ├── migrate.tf           # Azure Migrate project + replication vault
  ├── vm.tf                # Target Azure VMs (post-migration)
  ├── variables.tf
  ├── outputs.tf
  └── vars/
      ├── dev.tfvars
      └── prod.tfvars
```

**Deployment order:**
1. `network.tf` — VNet, subnets, NSGs, VPN Gateway
2. `migrate.tf` — Azure Migrate project, Recovery Services Vault
3. Run Azure Migrate discovery + replication (console/CLI)
4. `vm.tf` — finalize VM config post-cutover

---

## Checklist

### Pre-Migration
- [ ] Inventory all EC2 instances, EBS volumes, security groups, IAM roles
- [ ] Identify inter-service dependencies (RDS, ElastiCache, SQS, etc.)
- [ ] Create Azure subscription and resource groups
- [ ] Set up VNet with matching CIDR ranges (non-overlapping with AWS)
- [ ] Establish VPN or ExpressRoute connectivity
- [ ] Deploy Azure Migrate appliance in AWS
- [ ] Run discovery and assessment (review sizing recommendations)
- [ ] Translate security groups → NSGs
- [ ] Create Managed Identities to replace IAM roles

### During Replication
- [ ] Verify initial replication completes without errors
- [ ] Monitor delta sync lag (should be < 1 min)
- [ ] Test VM boot in Azure (test migration — no cutover)
- [ ] Validate application functionality on test VMs
- [ ] Performance test against baseline

### Cutover
- [ ] Schedule maintenance window
- [ ] Reduce DNS TTL to 60s (24h before cutover)
- [ ] Stop application writes / enable maintenance mode
- [ ] Confirm final delta sync
- [ ] Start Azure VMs and validate
- [ ] Update DNS records
- [ ] Monitor for 1h post-cutover

### Post-Migration
- [ ] Validate all services operational for 48h
- [ ] Set up Azure Monitor alerts (equivalent to CloudWatch alarms)
- [ ] Configure Azure Backup
- [ ] Decommission EC2 instances
- [ ] Remove VPN/ExpressRoute (if no longer needed)
- [ ] Update documentation and runbooks

---

## Mermaid Diagrams

### End-to-End Migration Flow

```mermaid
flowchart LR
    subgraph AWS ["☁️ AWS (Source)"]
        EC2[EC2 Instance\nEBS Volumes]
        SG[Security Group]
        IAM[IAM Role]
        ALB[ALB / NLB]
        VPC[VPC]
    end

    subgraph Migrate ["🔄 Azure Migrate"]
        APP[Appliance\nDiscovery]
        REP[Replication\nDelta Sync]
        VAULT[Recovery\nServices Vault]
    end

    subgraph Azure ["🔷 Azure (Target)"]
        VM[Azure VM\nManaged Disks]
        NSG[NSG]
        MI[Managed Identity]
        LB[App Gateway / LB]
        VNET[VNet]
    end

    EC2 -->|discover| APP
    APP -->|assess| REP
    REP -->|block-level replication| VAULT
    VAULT -->|cutover| VM
    SG -.->|translate| NSG
    IAM -.->|map to| MI
    ALB -.->|replace with| LB
    VPC -.->|mirror| VNET

    style AWS fill:#ff9900,color:#fff
    style Migrate fill:#0078d4,color:#fff
    style Azure fill:#0078d4,color:#fff
    style EC2 fill:#f90,color:#000
    style APP fill:#29b6f6,color:#fff
    style REP fill:#29b6f6,color:#fff
    style VAULT fill:#29b6f6,color:#fff
    style VM fill:#0078d4,color:#fff
    style NSG fill:#0078d4,color:#fff
    style MI fill:#0078d4,color:#fff
    style LB fill:#0078d4,color:#fff
```

---

### Migration Phases Timeline

```mermaid
gantt
    title AWS → Azure Migration Timeline
    dateFormat  YYYY-MM-DD
    section Phase 1 — Assess
    Inventory EC2s & dependencies     :a1, 2024-01-01, 14d
    Size Azure VMs & estimate costs   :a2, after a1, 7d
    section Phase 2 — Prepare
    Create VNet, NSGs, VPN Gateway    :b1, after a2, 5d
    Deploy Azure Migrate appliance    :b2, after b1, 2d
    section Phase 3 — Replicate
    Initial replication               :c1, after b2, 7d
    Continuous delta sync             :c2, after c1, 7d
    section Phase 4 — Test
    Test migration (no cutover)       :d1, after c1, 5d
    App validation & perf testing     :d2, after d1, 3d
    section Phase 5 — Cutover
    Maintenance window & DNS update   :crit, e1, after d2, 1d
    Post-cutover monitoring           :e2, after e1, 2d
    Decommission EC2s                 :e3, after e2, 1d
```

---

### Network Architecture

```mermaid
graph TB
    Users((Users / DNS)) --> TM

    subgraph Hybrid ["Hybrid Connectivity"]
        TM[Route53 / DNS]
    end

    subgraph AWS ["AWS — Source"]
        VPC[VPC 10.0.0.0/16]
        EC2A[EC2 Instance A]
        EC2B[EC2 Instance B]
        AWSVPN[VPN Gateway /\nDirect Connect]
        VPC --> EC2A & EC2B
        VPC --> AWSVPN
    end

    subgraph Azure ["Azure — Target"]
        VNET[VNet 10.100.0.0/16]
        VMA[Azure VM A]
        VMB[Azure VM B]
        AZVPN[VPN Gateway /\nExpressRoute]
        VNET --> VMA & VMB
        VNET --> AZVPN
    end

    TM -->|during migration| EC2A
    TM -->|cutover| VMA
    AWSVPN <-->|Site-to-Site VPN| AZVPN

    style AWS fill:#ff9900,color:#fff
    style Azure fill:#0078d4,color:#fff
    style Hybrid fill:#37474f,color:#fff
    style EC2A fill:#f90,color:#000
    style EC2B fill:#f90,color:#000
    style VMA fill:#29b6f6,color:#fff
    style VMB fill:#29b6f6,color:#fff
    style AWSVPN fill:#e65100,color:#fff
    style AZVPN fill:#1565c0,color:#fff
    style TM fill:#4caf50,color:#fff
```

---

### Resource Mapping

```mermaid
graph LR
    subgraph AWS ["AWS Resources"]
        A1[EC2 Instance]
        A2[EBS Volume]
        A3[Security Group]
        A4[IAM Role]
        A5[ALB / NLB]
        A6[VPC / Subnet]
        A7[Route53]
        A8[CloudWatch]
    end

    subgraph Azure ["Azure Equivalents"]
        B1[Azure VM]
        B2[Managed Disk]
        B3[NSG]
        B4[Managed Identity]
        B5[App Gateway / LB]
        B6[VNet / Subnet]
        B7[Azure DNS]
        B8[Azure Monitor]
    end

    A1 --> B1
    A2 --> B2
    A3 --> B3
    A4 --> B4
    A5 --> B5
    A6 --> B6
    A7 --> B7
    A8 --> B8

    style AWS fill:#ff9900,color:#fff
    style Azure fill:#0078d4,color:#fff
    style A1 fill:#f90,color:#000
    style A2 fill:#f90,color:#000
    style A3 fill:#f90,color:#000
    style A4 fill:#f90,color:#000
    style A5 fill:#f90,color:#000
    style A6 fill:#f90,color:#000
    style A7 fill:#f90,color:#000
    style A8 fill:#f90,color:#000
    style B1 fill:#29b6f6,color:#fff
    style B2 fill:#29b6f6,color:#fff
    style B3 fill:#29b6f6,color:#fff
    style B4 fill:#29b6f6,color:#fff
    style B5 fill:#29b6f6,color:#fff
    style B6 fill:#29b6f6,color:#fff
    style B7 fill:#29b6f6,color:#fff
    style B8 fill:#29b6f6,color:#fff
```

---

### Cutover Decision Flow

```mermaid
flowchart TD
    Start([Maintenance Window]) --> Pause[Pause App Writes]
    Pause --> Sync[Final Delta Sync]
    Sync --> Check{Delta Sync\nComplete?}
    Check -->|No| Wait[Wait 15 min]
    Wait --> Check
    Check -->|Yes| Boot[Start Azure VMs]
    Boot --> Validate{App Health\nCheck Pass?}
    Validate -->|Yes| DNS[Update DNS Records]
    DNS --> Monitor[Monitor 1h]
    Monitor --> Stable{Stable?}
    Stable -->|Yes| Done([Cutover Complete ✅])
    Stable -->|No| Rollback[Revert DNS to EC2]
    Validate -->|No| Rollback
    Rollback --> Investigate([Investigate & Retry ⚠️])

    style Start fill:#4caf50,color:#fff
    style Done fill:#4caf50,color:#fff
    style Rollback fill:#ef5350,color:#fff
    style Investigate fill:#ff9800,color:#fff
    style DNS fill:#0078d4,color:#fff
    style Boot fill:#0078d4,color:#fff
```
