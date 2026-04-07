# On-Premises VMware & MS SQL Server → Azure Migration Plan

End-to-end migration plan covering:
- **VMware VMs → Azure VMs** via Azure Migrate (agentless replication)
- **On-Prem SQL Server → Azure SQL / Azure SQL Managed Instance** via Azure DMS

---

## Architecture Overview

```
  On-Premises                                          Azure (Target)
  ──────────────────────────────────────────────────────────────────────

  ┌──────────────────────┐                    ┌──────────────────────────┐
  │  VMware vSphere      │                    │  Landing Zone            │
  │  ├─ vCenter          │                    │  ├─ Hub VNet             │
  │  ├─ ESXi Hosts       │  ─── Replicate ──► │  ├─ Spoke VNet          │
  │  └─ VMs (any OS)     │                    │  └─ Azure VMs            │
  └──────────────────────┘                    └──────────────────────────┘

  ┌──────────────────────┐                    ┌──────────────────────────┐
  │  SQL Server          │                    │  Azure SQL MI            │
  │  (Standalone /       │  ─── DMS ────────► │  or Azure SQL DB         │
  │   Always On AG)      │                    │  (fully managed)         │
  └──────────────────────┘                    └──────────────────────────┘

            │                                              │
            └──────── ExpressRoute / Site-to-Site VPN ─────┘
                         (required throughout migration)
```

---

## Migration Phases

```
  Phase 1          Phase 2          Phase 3          Phase 4          Phase 5
  ──────────       ──────────       ──────────       ──────────       ──────────
  ASSESS      ──►  PREPARE     ──►  REPLICATE   ──►  TEST        ──►  CUTOVER
  2–4 weeks        1–2 weeks        2–4 weeks        1–2 weeks        Hours

  • Inventory      • Azure          • Deploy         • Test VMs       • Stop VMs
    VMware VMs       Migrate          appliance        in Azure         on-prem
  • Inventory        setup          • Agentless      • Validate       • Final sync
    SQL Servers    • Landing          VM replication   apps            • Update DNS
  • Dependency       Zone           • DMS full       • SQL perf       • Cutover SQL
    mapping          networking       load + CDC       testing        • Decommission
  • Size Azure     • ExpressRoute   • Delta sync     • Rollback
    targets          / VPN            (continuous)     test
```

---

## Part 1 — VMware VMs → Azure VMs

### How Azure Migrate Works with VMware

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │                  AZURE MIGRATE — AGENTLESS REPLICATION               │
  └─────────────────────────────────────────────────────────────────────┘

  On-Premises vSphere                      Azure
  ──────────────────────────────────────────────────────────────────────

  ┌──────────────────────┐                 ┌──────────────────────────┐
  │  Azure Migrate       │                 │  Azure Migrate Project   │
  │  Appliance (OVA)     │────────────────►│  (Discovery + Assess)    │
  │  Deployed on ESXi    │  HTTPS 443      └──────────────────────────┘
  └──────────────────────┘
           │                               ┌──────────────────────────┐
           │  vSphere snapshot-based       │  Replication Storage     │
           │  disk replication             │  Account (staging)       │
           ▼                               │                          │
  ┌──────────────────────┐                 │  ┌──────────────────────┐│
  │  Source VMware VMs   │────────────────►│  │  Managed Disks       ││
  │  (no agent needed)   │                 │  │  (target disks)      ││
  └──────────────────────┘                 │  └──────────────────────┘│
                                           └──────────────────────────┘
                                                      │
                                                      ▼
                                           ┌──────────────────────────┐
                                           │  Target Azure VM         │
                                           │  ├─ NIC                  │
                                           │  ├─ OS Managed Disk      │
                                           │  ├─ Data Managed Disk(s) │
                                           │  └─ NSG                  │
                                           └──────────────────────────┘
```

### VMware → Azure VM Sizing

```
  VMware VM         vCPU  RAM      Azure VM            Series
  ──────────────────────────────────────────────────────────────
  1 vCPU,  2 GB     1     2 GB    B1ms                 B-series (burstable)
  2 vCPU,  4 GB     2     4 GB    B2s                  B-series
  2 vCPU,  8 GB     2     8 GB    D2s_v5               D-series (general)
  4 vCPU, 16 GB     4    16 GB    D4s_v5               D-series
  8 vCPU, 32 GB     8    32 GB    D8s_v5               D-series
  4 vCPU, 32 GB     4    32 GB    E4s_v5               E-series (memory)
  8 vCPU, 64 GB     8    64 GB    E8s_v5               E-series
  4 vCPU,  8 GB     4     8 GB    F4s_v2               F-series (compute)
```

### VMware Disk → Azure Managed Disk Mapping

```
  VMware Disk Type    IOPS          Azure Managed Disk     Tier
  ──────────────────────────────────────────────────────────────
  VMDK (standard)     < 500         Standard HDD           S-series
  VMDK (SSD)          500–2300      Standard SSD           E-series
  VMDK (SSD)          2300–16000    Premium SSD            P-series
  VMDK (NVMe/SAN)     > 16000       Ultra Disk             Ultra
```

---

## Part 2 — SQL Server → Azure SQL

### Target Selection Guide

```
  On-Prem SQL Server Feature          Recommended Azure Target
  ──────────────────────────────────────────────────────────────────────
  Basic workload, no special features  Azure SQL Database (PaaS)
  SQL Agent, linked servers, CLR       Azure SQL Managed Instance (PaaS)
  Full OS control required             SQL Server on Azure VM (IaaS)
  Always On Availability Group         SQL MI Business Critical tier
  Distributed transactions (MSDTC)     SQL MI
  Custom collation / filestream        SQL Server on Azure VM
```

### SQL Server → Azure SQL MI Sizing

```
  On-Prem SQL Server    vCPU  RAM      Azure SQL MI              Tier
  ──────────────────────────────────────────────────────────────────────
  4 core,  16 GB        4    16 GB    GP 4 vCores, 20.4 GB      General Purpose
  8 core,  32 GB        8    40 GB    GP 8 vCores, 40.8 GB      General Purpose
  16 core, 64 GB       16    81 GB    GP 16 vCores, 81.6 GB     General Purpose
  8 core,  64 GB        8    40 GB    BC 8 vCores, 40.8 GB      Business Critical
  16 core, 128 GB      16    81 GB    BC 16 vCores, 81.6 GB     Business Critical
```

### DMS Migration Flow

```
  ┌─────────────────────────────────────────────────────────────────────┐
  │              AZURE DMS — ONLINE MIGRATION (near-zero downtime)       │
  └─────────────────────────────────────────────────────────────────────┘

  On-Prem SQL Server              Azure DMS               Azure SQL MI
  ──────────────────────────────────────────────────────────────────────

  ┌──────────────┐  Full backup   ┌─────────────┐  Restore  ┌──────────┐
  │  Databases   │ ─────────────► │             │ ────────► │  DBs     │
  └──────────────┘                │  Migration  │           └──────────┘
                                  │  Service    │
  ┌──────────────┐  Log backups   │  (Premium)  │  Apply    ┌──────────┐
  │  T-Log       │ ─────────────► │             │ ────────► │  Logs    │
  │  Backups     │  (continuous)  └─────────────┘           └──────────┘
  └──────────────┘
         │                             │
         │    ExpressRoute / VPN       │
         └─────────────────────────────┘

  Requirements:
  ├─ SQL Server 2005+
  ├─ Full recovery model enabled
  ├─ Backup to network share accessible by DMS
  └─ sysadmin rights on source
```

### SQL Migration Options Comparison

| Method | Downtime | Best For | Tool |
|---|---|---|---|
| Online (DMS + log shipping) | Minutes | Production, large DBs | Azure DMS Premium |
| Offline (backup/restore) | Hours | Dev/QA, small DBs | SSMS / AzCopy |
| Database Migration Assistant | Minutes | Assessment + schema | DMA |
| Log Shipping manual | Minutes | Full control | SQL Server native |

---

## Network Architecture During Migration

```
  ┌──────────────────────────────────────────────────────────────────────┐
  │                    HYBRID CONNECTIVITY                                │
  └──────────────────────────────────────────────────────────────────────┘

  On-Premises                                      Azure
  ─────────────────────────────────────────────────────────────────────

  ┌──────────────────┐                        ┌──────────────────────┐
  │  VMware vSphere  │                        │  Hub VNet            │
  │  SQL Servers     │                        │  10.0.0.0/16         │
  │                  │                        │                      │
  │  ┌────────────┐  │   ExpressRoute         │  ┌────────────────┐  │
  │  │ On-prem    │◄─┼────────────────────────┼─►│ ER / VPN GW    │  │
  │  │ Router /   │  │   (recommended)        │  └────────────────┘  │
  │  │ Firewall   │  │   or Site-to-Site VPN  │                      │
  │  └────────────┘  │                        │  ┌────────────────┐  │
  │                  │                        │  │ Azure Firewall │  │
  │  ┌────────────┐  │                        │  └────────────────┘  │
  │  │ Azure      │  │                        │                      │
  │  │ Migrate    │  │                        │  ┌────────────────┐  │
  │  │ Appliance  │  │                        │  │ Spoke VNet     │  │
  │  └────────────┘  │                        │  │ Azure VMs      │  │
  └──────────────────┘                        │  │ Azure SQL MI   │  │
                                              │  └────────────────┘  │
                                              └──────────────────────┘

  Bandwidth recommendation:
  ├─ ExpressRoute 1 Gbps  : large environments (> 10 TB data)
  └─ Site-to-Site VPN     : smaller environments (< 10 TB)
```

---

## Cutover Sequence

```
  T-48h                T-1h                 T=0 (Cutover)         T+24h
  ──────────────────────────────────────────────────────────────────────
  • Final delta        • Maintenance        • Stop VMware VMs     • Monitor
    sync check           window start       • Final disk sync       Azure VMs
  • Validate           • Drain app          • Start Azure VMs     • Validate
    Azure VMs            connections        • SQL: stop log         SQL perf
  • Pre-warm           • SQL: final           shipping            • Update
    Azure VMs            log backup         • Update DNS            monitoring
  • Reduce DNS         • Verify sync          (TTL 60s)           • Keep VMs
    TTL to 60s           complete           • Smoke test            off on-prem
                                            • Confirm health        (72h hold)
```

---

## Rollback Plan

```
  If issues detected within 72h of cutover:

  VMware VMs:
  1. Power on VMware VMs (kept powered off, not deleted)
  2. Revert DNS to on-prem IP addresses
  3. Notify stakeholders

  SQL Server:
  1. Resume log shipping to on-prem (if still configured)
  2. Failback to on-prem SQL Server
  3. Update connection strings

  ⚠️  Do NOT decommission on-prem VMs or SQL Servers until 72h stable
```

---

## Terraform Implementation Structure

```
  terraform/live/azure/onprem-to-azure/
  ├── plan.md                          ← this file
  ├── networking/
  │   ├── hub-vnet.tf                  # Hub VNet, subnets, firewall
  │   ├── spoke-vnet.tf                # Spoke VNet for migrated workloads
  │   ├── expressroute.tf              # ER circuit + gateway
  │   └── dns.tf                       # Private DNS zones
  ├── migrate/
  │   ├── migrate-project.tf           # Azure Migrate project
  │   └── recovery-vault.tf            # Recovery Services Vault
  ├── compute/
  │   └── vms.tf                       # Target Azure VMs (post-migration)
  ├── database/
  │   ├── sql-mi.tf                    # Azure SQL Managed Instance
  │   ├── dms.tf                       # Azure DMS instance + project
  │   └── private-endpoint.tf          # Private endpoint for SQL MI
  ├── variables.tf
  ├── outputs.tf
  └── vars/
      ├── dev.tfvars
      └── prod.tfvars
```

---

## Pre-Migration Checklist

### VMware
- [ ] Inventory all VMs: vCPU, RAM, disk sizes, OS, applications
- [ ] Map inter-VM dependencies (use Azure Migrate dependency analysis)
- [ ] Identify VMs with unsupported features (physical RDM disks, passthrough)
- [ ] Deploy Azure Migrate appliance OVA on vSphere
- [ ] Run discovery (24–48h for full inventory)
- [ ] Review Azure Migrate sizing recommendations
- [ ] Establish ExpressRoute or Site-to-Site VPN
- [ ] Create target resource groups, VNets, NSGs

### SQL Server
- [ ] Inventory all SQL instances, databases, sizes, versions, editions
- [ ] Run Database Migration Assistant (DMA) assessment
- [ ] Identify blockers: linked servers, CLR, MSDTC, custom collations
- [ ] Choose target: SQL DB vs SQL MI vs SQL on VM
- [ ] Enable Full Recovery Model on all databases
- [ ] Configure backup to network share accessible by DMS
- [ ] Create Azure SQL MI with private endpoint
- [ ] Create Azure DMS Premium instance
- [ ] Verify network connectivity: DMS → on-prem SQL (port 1433)

### Post-Migration
- [ ] Validate all applications for 72h
- [ ] Set up Azure Monitor + Log Analytics alerts
- [ ] Configure Azure Backup for VMs and SQL MI
- [ ] Enable Defender for Cloud on subscription
- [ ] Decommission on-prem VMs and SQL Servers
- [ ] Remove ExpressRoute / VPN (if no longer needed)
- [ ] Update CMDB and documentation

---

## Mermaid Diagrams

### End-to-End Migration Flow

```mermaid
flowchart LR
    subgraph OnPrem ["🏢 On-Premises"]
        VMW[VMware VMs\nvSphere]
        SQL[SQL Server\nStandalone / AG]
        APP[Appliance\nOVA on ESXi]
    end

    subgraph Tools ["🔄 Migration Tools"]
        AZM[Azure Migrate\nAgentless Replication]
        DMS[Azure DMS\nOnline Migration]
        VPN[ExpressRoute /\nSite-to-Site VPN]
    end

    subgraph Azure ["☁️ Azure (Target)"]
        VM[Azure VMs\nManaged Disks]
        SQLMI[Azure SQL MI\nor SQL DB]
        VNET[Spoke VNet\n+ NSGs]
    end

    VMW -->|discover| APP
    APP -->|assess + replicate| AZM
    AZM -->|cutover| VM
    SQL -->|full backup + log shipping| DMS
    DMS -->|restore + apply logs| SQLMI
    VPN <-->|private connectivity| Tools

    style OnPrem fill:#546e7a,color:#fff
    style Tools fill:#0078d4,color:#fff
    style Azure fill:#107c10,color:#fff
    style VMW fill:#607d8b,color:#fff
    style SQL fill:#607d8b,color:#fff
    style AZM fill:#29b6f6,color:#fff
    style DMS fill:#29b6f6,color:#fff
    style VPN fill:#1565c0,color:#fff
    style VM fill:#107c10,color:#fff
    style SQLMI fill:#107c10,color:#fff
```

---

### Migration Phases Timeline

```mermaid
gantt
    title On-Prem to Azure Migration Timeline
    dateFormat  YYYY-MM-DD
    section Phase 1 — Assess
    Inventory VMs and SQL Servers        :a1, 2024-01-01, 14d
    Run DMA assessment on SQL            :a2, after a1, 7d
    Size Azure targets                   :a3, after a2, 5d
    section Phase 2 — Prepare
    Deploy ExpressRoute / VPN            :b1, after a3, 10d
    Create Landing Zone networking       :b2, after b1, 5d
    Deploy Azure Migrate appliance       :b3, after b2, 2d
    Create Azure SQL MI                  :b4, after b2, 3d
    section Phase 3 — Replicate
    VM initial replication               :c1, after b3, 14d
    SQL full backup + restore            :c2, after b4, 7d
    Continuous delta sync (VMs)          :c3, after c1, 14d
    SQL log shipping (continuous)        :c4, after c2, 14d
    section Phase 4 — Test
    Test VM migration (no cutover)       :d1, after c1, 7d
    SQL validation and perf testing      :d2, after c2, 7d
    App integration testing              :d3, after d1, 5d
    section Phase 5 — Cutover
    Maintenance window + cutover         :crit, e1, after d3, 1d
    Post-cutover monitoring              :e2, after e1, 3d
    Decommission on-prem                 :e3, after e2, 2d
```

---

### SQL Target Selection

```mermaid
flowchart TD
    Start([SQL Server\nMigration]) --> Features{SQL Agent /\nLinked Servers /\nCLR needed?}
    Features -->|No| Size{DB size\n< 4 TB?}
    Features -->|Yes| AG{Always On AG\nor MSDTC?}
    Size -->|Yes| SQLDB[Azure SQL Database\nPaaS — Serverless or DTU]
    Size -->|No| SQLMI2[Azure SQL MI\nGeneral Purpose]
    AG -->|Yes| SQLMIBC[Azure SQL MI\nBusiness Critical]
    AG -->|No| SQLMI[Azure SQL MI\nGeneral Purpose]
    SQLDB --> Done([Deploy & Migrate])
    SQLMI --> Done
    SQLMI2 --> Done
    SQLMIBC --> Done

    style Start fill:#546e7a,color:#fff
    style Done fill:#107c10,color:#fff
    style SQLDB fill:#0078d4,color:#fff
    style SQLMI fill:#0078d4,color:#fff
    style SQLMI2 fill:#0078d4,color:#fff
    style SQLMIBC fill:#ef5350,color:#fff
```

---

### Network Architecture

```mermaid
graph TB
    subgraph OnPrem ["On-Premises"]
        ESXi[VMware ESXi\nHosts]
        SQLSRV[SQL Server]
        Router[On-Prem\nRouter / Firewall]
    end

    subgraph Connectivity ["Azure — Connectivity Subscription"]
        ERGW[ExpressRoute /\nVPN Gateway]
        HubVNet[Hub VNet\n10.0.0.0/16]
        AzFW[Azure Firewall]
    end

    subgraph Workload ["Azure — Workload Subscription"]
        SpokeVNet[Spoke VNet\n10.1.0.0/16]
        AzVM[Azure VMs\n migrated workloads]
        SQLMI3[Azure SQL MI\nprivate endpoint]
    end

    Router <-->|ExpressRoute\nor S2S VPN| ERGW
    ERGW --> HubVNet
    HubVNet --> AzFW
    AzFW -->|inspect traffic| SpokeVNet
    HubVNet <-->|VNet Peering| SpokeVNet
    SpokeVNet --> AzVM & SQLMI3

    style OnPrem fill:#546e7a,color:#fff
    style Connectivity fill:#0078d4,color:#fff
    style Workload fill:#107c10,color:#fff
    style AzFW fill:#ef5350,color:#fff
    style SQLMI3 fill:#0078d4,color:#fff
```

---

### Cutover Decision Flow

```mermaid
flowchart TD
    Start([Maintenance Window]) --> StopApps[Stop Application\nConnections]
    StopApps --> FinalSync[Final VM Disk\nSync + SQL Log Backup]
    FinalSync --> Check{Sync\nComplete?}
    Check -->|No| Wait[Wait 15 min]
    Wait --> Check
    Check -->|Yes| StartAzure[Start Azure VMs\nApply Final SQL Logs]
    StartAzure --> Validate{App + DB\nHealth Check?}
    Validate -->|Pass| DNS[Update DNS\nto Azure IPs]
    DNS --> Monitor[Monitor 24h]
    Monitor --> Stable{Stable\n72h?}
    Stable -->|Yes| Decom([Decommission\nOn-Prem ✅])
    Stable -->|No| Rollback[Power On VMware VMs\nFailback SQL]
    Validate -->|Fail| Rollback
    Rollback --> Investigate([Investigate\n& Retry ⚠️])

    style Start fill:#0078d4,color:#fff
    style Decom fill:#107c10,color:#fff
    style Rollback fill:#ef5350,color:#fff
    style Investigate fill:#ff9800,color:#fff
    style DNS fill:#0078d4,color:#fff
```
