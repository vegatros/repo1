# Azure Landing Zone — Architecture & Policy Strategy

---

## Management Group Hierarchy

```
  Tenant Root Group
  └── org-root (Management Group)
      ├── Platform MG
      │   ├── Identity Subscription       ← Azure AD DS, Entra ID
      │   ├── Management Subscription     ← Log Analytics, Defender, Automation
      │   └── Connectivity Subscription   ← Hub VNet, Firewall, VPN/ExpressRoute, DNS
      ├── Landing Zones MG
      │   ├── Corp MG (private, connected to hub)
      │   │   ├── Dev Subscription(s)
      │   │   ├── QA Subscription(s)
      │   │   └── Prod Subscription(s)
      │   └── Online MG (internet-facing)
      │       └── Public Workload Subscriptions
      ├── Sandbox MG
      │   └── Sandbox Subscriptions (isolated, no hub connectivity)
      └── Decommissioned MG
          └── Subscriptions being retired
```

---

## Hub-and-Spoke Network Architecture

```
  ┌─────────────────────────────────────────────────────────────────────────┐
  │                    CONNECTIVITY SUBSCRIPTION (Hub)                       │
  │                                                                          │
  │  ┌──────────────────────────────────────────────────────────────────┐   │
  │  │  Hub VNet  10.0.0.0/16                                           │   │
  │  │                                                                  │   │
  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │   │
  │  │  │ Azure        │  │ VPN Gateway  │  │  ExpressRoute        │   │   │
  │  │  │ Firewall     │  │ (on-prem)    │  │  Gateway             │   │   │
  │  │  │ Premium      │  └──────────────┘  └──────────────────────┘   │   │
  │  │  └──────┬───────┘                                               │   │
  │  │         │ (all spoke traffic routed through firewall)           │   │
  │  │  ┌──────▼───────┐                                               │   │
  │  │  │ Azure DNS    │  Private DNS Zones                            │   │
  │  │  │ Resolver     │  privatelink.*.azure.com                      │   │
  │  │  └──────────────┘                                               │   │
  │  └──────────────────────────────────────────────────────────────────┘   │
  │         │ VNet Peering          │ VNet Peering                          │
  └─────────┼───────────────────────┼──────────────────────────────────────┘
            │                       │
  ┌─────────▼──────────┐  ┌─────────▼──────────┐
  │  Corp Spoke VNet   │  │  Online Spoke VNet  │
  │  10.1.0.0/16       │  │  10.2.0.0/16        │
  │  (Dev/QA/Prod)     │  │  (Internet-facing)  │
  │  No direct internet│  │  App Gateway + WAF  │
  └────────────────────┘  └─────────────────────┘
```

---

## Subscription Design

| Subscription | Management Group | Purpose |
|---|---|---|
| Management | Platform | Log Analytics, Defender for Cloud, Automation Account |
| Identity | Platform | Azure AD DS, Entra ID Connect |
| Connectivity | Platform | Hub VNet, Azure Firewall, VPN/ER Gateway, DNS |
| Corp-Dev | Landing Zones / Corp | Dev workloads, connected to hub |
| Corp-QA | Landing Zones / Corp | QA workloads, connected to hub |
| Corp-Prod | Landing Zones / Corp | Prod workloads, connected to hub |
| Online-Prod | Landing Zones / Online | Internet-facing workloads, App Gateway + WAF |
| Sandbox | Sandbox | Experimentation, isolated, auto-budget |

---

## Azure Policy Strategy

### Policy Assignment Levels

```
  Tenant Root Group
  └── Deny non-approved regions (global)
      Require tags: Environment, Owner, CostCenter

  Platform MG
  └── Enforce diagnostic settings → Log Analytics
      Require Azure Monitor Agent on all VMs

  Landing Zones MG
  └── Deny public IP on NICs (Corp MG only)
      Require private endpoints for PaaS services
      Enforce NSG on all subnets
      Deny RDP/SSH from internet

  Corp MG (Prod)
  └── Require encryption at rest (CMK)
      Deny unmanaged disks
      Require Azure Backup on VMs
      Enforce TLS 1.2+ on App Services / Storage

  Sandbox MG
  └── Allowed VM SKUs (small only)
      Budget alert at $200/month
      Auto-shutdown VMs at 7 PM
```

---

### Built-in Policy Initiatives to Assign

| Initiative | Scope | Effect |
|---|---|---|
| Azure Security Benchmark | Root MG | Audit / DeployIfNotExists |
| NIST SP 800-53 Rev 5 | Corp MG | Audit |
| CIS Microsoft Azure Foundations | Corp MG | Audit |
| Enable Azure Monitor for VMs | Platform MG | DeployIfNotExists |
| Configure Azure Defender | Management Sub | DeployIfNotExists |
| Require tags on resource groups | Root MG | Deny |
| Allowed locations | Root MG | Deny |

---

### Custom Policy Examples

**Deny public IP on NICs (Corp workloads):**
```json
{
  "mode": "All",
  "policyRule": {
    "if": {
      "allOf": [
        { "field": "type", "equals": "Microsoft.Network/networkInterfaces" },
        { "count": { "field": "Microsoft.Network/networkInterfaces/ipConfigurations[*].publicIpAddress.id" }, "greater": 0 }
      ]
    },
    "then": { "effect": "Deny" }
  }
}
```

**Require specific tags on all resources:**
```json
{
  "mode": "Indexed",
  "policyRule": {
    "if": {
      "anyOf": [
        { "field": "tags['Environment']", "exists": "false" },
        { "field": "tags['Owner']", "exists": "false" },
        { "field": "tags['CostCenter']", "exists": "false" }
      ]
    },
    "then": { "effect": "Deny" }
  }
}
```

**Enforce private endpoints for Storage Accounts:**
```json
{
  "mode": "Indexed",
  "policyRule": {
    "if": {
      "allOf": [
        { "field": "type", "equals": "Microsoft.Storage/storageAccounts" },
        { "field": "Microsoft.Storage/storageAccounts/publicNetworkAccess", "notEquals": "Disabled" }
      ]
    },
    "then": { "effect": "Deny" }
  }
}
```

---

## Terraform Implementation Structure

```
  terraform/live/azure/global/landing-zone/
  ├── plan.md                          ← this file
  ├── management-groups/
  │   ├── main.tf                      # MG hierarchy
  │   └── outputs.tf
  ├── subscriptions/
  │   ├── main.tf                      # Subscription creation / association
  │   └── variables.tf
  ├── policies/
  │   ├── initiatives.tf               # Built-in initiative assignments
  │   ├── custom-policies.tf           # Custom policy definitions
  │   ├── assignments.tf               # Policy assignments per MG
  │   └── exemptions.tf                # Policy exemptions
  ├── networking/
  │   ├── hub-vnet.tf                  # Hub VNet, subnets, firewall
  │   ├── dns.tf                       # Private DNS zones + resolver
  │   ├── vpn-gateway.tf               # VPN / ExpressRoute gateway
  │   └── peering.tf                   # Hub-spoke peering
  ├── monitoring/
  │   ├── log-analytics.tf             # Central Log Analytics workspace
  │   ├── defender.tf                  # Defender for Cloud plans
  │   └── diagnostics.tf               # Diagnostic settings policy
  ├── identity/
  │   └── entra.tf                     # Entra ID / Azure AD DS config
  └── vars/
      ├── dev.tfvars
      └── prod.tfvars
```

---

## Recommendations

1. **Start with Management Groups** — define the hierarchy before any subscriptions
2. **Assign Region Deny policy at Root MG first** — prevents resource sprawl immediately
3. **Hub VNet before spokes** — deploy Connectivity subscription and peer spokes to it
4. **Use DeployIfNotExists policies** for monitoring — auto-remediate non-compliant resources
5. **Defender for Cloud on all subscriptions** — enable at Management subscription level via policy
6. **Private DNS zones in Connectivity subscription** — centralize all `privatelink.*.azure.com` zones
7. **Tag policy at Root MG** — enforce Environment, Owner, CostCenter on everything
8. **Sandbox isolation** — no VNet peering to hub, budget caps, auto-shutdown

---

## Mermaid Diagrams

### Management Group Hierarchy

```mermaid
graph TD
    Tenant[Tenant Root Group] --> OrgRoot[org-root MG]
    OrgRoot --> Platform[Platform MG]
    OrgRoot --> LandingZones[Landing Zones MG]
    OrgRoot --> Sandbox[Sandbox MG]
    OrgRoot --> Decommissioned[Decommissioned MG]

    Platform --> Identity[Identity\nSubscription]
    Platform --> Management[Management\nSubscription]
    Platform --> Connectivity[Connectivity\nSubscription]

    LandingZones --> Corp[Corp MG\nPrivate Workloads]
    LandingZones --> Online[Online MG\nInternet-facing]

    Corp --> CorpDev[Dev\nSubscription]
    Corp --> CorpQA[QA\nSubscription]
    Corp --> CorpProd[Prod\nSubscription]

    Online --> OnlineProd[Online Prod\nSubscription]

    Sandbox --> SandboxSub[Sandbox\nSubscriptions]

    style Tenant fill:#37474f,color:#fff
    style OrgRoot fill:#37474f,color:#fff
    style Platform fill:#0078d4,color:#fff
    style LandingZones fill:#107c10,color:#fff
    style Sandbox fill:#78909c,color:#fff
    style Decommissioned fill:#616161,color:#fff
    style Corp fill:#107c10,color:#fff
    style Online fill:#0078d4,color:#fff
    style CorpProd fill:#ef5350,color:#fff
    style CorpDev fill:#66bb6a,color:#fff
    style CorpQA fill:#ffa726,color:#fff
    style Identity fill:#0078d4,color:#fff
    style Management fill:#0078d4,color:#fff
    style Connectivity fill:#0078d4,color:#fff
```

---

### Hub-and-Spoke Network

```mermaid
graph TB
    OnPrem[On-Premises\nNetwork] <-->|VPN / ExpressRoute| Hub

    subgraph Connectivity ["Connectivity Subscription"]
        Hub[Hub VNet\n10.0.0.0/16]
        FW[Azure Firewall\nPremium]
        DNS[Azure DNS\nResolver]
        GW[VPN / ER\nGateway]
        Hub --> FW & DNS & GW
    end

    subgraph Corp ["Corp Landing Zone"]
        CorpSpoke[Corp Spoke VNet\n10.1.0.0/16\nDev / QA / Prod]
    end

    subgraph Online ["Online Landing Zone"]
        OnlineSpoke[Online Spoke VNet\n10.2.0.0/16\nApp Gateway + WAF]
    end

    Hub <-->|VNet Peering| CorpSpoke
    Hub <-->|VNet Peering| OnlineSpoke
    Internet((Internet)) --> OnlineSpoke
    FW -->|inspect all traffic| CorpSpoke

    style Connectivity fill:#0078d4,color:#fff
    style Corp fill:#107c10,color:#fff
    style Online fill:#e65100,color:#fff
    style FW fill:#ef5350,color:#fff
    style Hub fill:#1565c0,color:#fff
    style Internet fill:#37474f,color:#fff
```

---

### Policy Assignment Layers

```mermaid
graph TD
    subgraph Root ["Tenant Root — All Subscriptions"]
        R1[Deny non-approved regions]
        R2[Require tags: Environment, Owner, CostCenter]
    end

    subgraph Platform ["Platform MG"]
        P1[Enforce diagnostic settings → Log Analytics]
        P2[Require Azure Monitor Agent on VMs]
        P3[Enable Defender for Cloud]
    end

    subgraph LZ ["Landing Zones MG"]
        L1[Deny public IP on NICs]
        L2[Require private endpoints for PaaS]
        L3[Enforce NSG on all subnets]
        L4[Deny RDP/SSH from internet]
    end

    subgraph Prod ["Corp Prod — Strictest"]
        PR1[Require CMK encryption at rest]
        PR2[Require Azure Backup on VMs]
        PR3[Enforce TLS 1.2+]
        PR4[Deny unmanaged disks]
    end

    subgraph SB ["Sandbox MG"]
        S1[Allowed VM SKUs: small only]
        S2[Budget alert $200/month]
        S3[Auto-shutdown VMs at 7 PM]
    end

    Root --> Platform & LZ & SB
    LZ --> Prod

    style Root fill:#37474f,color:#fff
    style Platform fill:#0078d4,color:#fff
    style LZ fill:#107c10,color:#fff
    style Prod fill:#ef5350,color:#fff
    style SB fill:#78909c,color:#fff
```

---

### Landing Zone Provisioning Flow

```mermaid
flowchart LR
    Request[Subscription\nRequest] --> MG[Assign to\nManagement Group]
    MG --> Policies[Policies\nAuto-Applied]
    Policies --> Hub[Peer to\nHub VNet]
    Hub --> DNS2[Register\nPrivate DNS]
    DNS2 --> Monitor[Enroll in\nLog Analytics]
    Monitor --> Defender[Enable\nDefender Plans]
    Defender --> Tags[Apply\nDefault Tags]
    Tags --> Ready([Subscription\nReady ✅])

    style Request fill:#37474f,color:#fff
    style Ready fill:#107c10,color:#fff
    style Policies fill:#0078d4,color:#fff
    style Hub fill:#0078d4,color:#fff
    style Defender fill:#ef5350,color:#fff
```
