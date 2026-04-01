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
