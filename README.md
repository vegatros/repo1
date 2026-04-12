# Cloud Infrastructure — Terraform DevOps

Production-grade Terraform infrastructure across AWS and Azure, covering application stacks, AI/ML pipelines, multi-cloud networking, governance, and migration planning. Fully automated CI/CD via GitHub Actions.

---

## Repository Structure

```
repo1/
├── terraform/
│   ├── live/                          # All deployed infrastructure
│   │   ├── aws/
│   │   │   ├── stacks/                # AWS application stacks
│   │   │   │   ├── app1/              #   ALB + EC2, Lambda scheduler, ACM/TLS
│   │   │   │   ├── app2/              #   EKS + Linkerd mesh, NGINX Ingress, Helm
│   │   │   │   ├── app3/              #   Multi-region, Global Accelerator, DynamoDB
│   │   │   │   ├── app4/              #   ECS Fargate cluster
│   │   │   │   ├── app5/              #   S3 static website + CloudFront
│   │   │   │   ├── app6/              #   EKS + ArgoCD GitOps
│   │   │   │   ├── app7/              #   Site-to-Site VPN + Jenkins CI/CD
│   │   │   │   └── app8/              #   Lambda container (Node.js)
│   │   │   ├── ai/
│   │   │   │   ├── app-bedrock/       #   Bedrock agent (Amazon Nova)
│   │   │   │   ├── app-sagemaker/     #   SageMaker MLOps pipeline
│   │   │   │   └── crew/              #   CrewAI multi-agent framework
│   │   │   ├── network/
│   │   │   │   └── tgw/               #   Transit Gateway, 2 VPCs
│   │   │   ├── global/
│   │   │   │   └── control-tower/     #   Control Tower plan (multi-region)
│   │   │   └── security/
│   │   │       └── cloudtrail/        #   Real-time CloudTrail monitoring
│   │   └── azure/
│   │       ├── region-failover/       #   Multi-region VMs + Traffic Manager
│   │       ├── global/
│   │       │   └── landing-zone/      #   Azure Landing Zone plan
│   │       ├── aws-azure-migrate/     #   AWS EC2 + RDS → Azure migration plan
│   │       └── onprem-to-azure/       #   VMware + SQL Server → Azure plan
│   └── modules/
│       ├── aws/
│       │   ├── network/vpc/           #   VPC, subnets, IGW, NAT, flow logs
│       │   ├── network/transit-gateway/  # Transit Gateway attachments
│       │   ├── compute/ec2/           #   EC2, IAM, security groups, KMS
│       │   ├── containers/eks/        #   EKS cluster, node groups, IRSA
│       │   ├── containers/ecs/        #   Fargate cluster, task definitions
│       │   ├── database/dynamodb/     #   Global tables, streams, PITR
│       │   ├── ai/bedrock/            #   Bedrock agent, IAM, alias
│       │   └── iam/                   #   Roles, managed policies
│       └── azure/
│           └── compute/vm/            #   Linux VM, NIC, optional public IP + data disk
├── .github/workflows/                 # CI/CD pipelines
│   ├── terraform-sagemaker.yml        #   SageMaker deploy pipeline
│   ├── terraform-audit.yml            #   Security & AI audit pipeline
│   └── code-scan.yml                  #   Code quality & security scan
└── scripts/
    ├── create-stack.sh                # Scaffold new stacks
    ├── check-workflow.sh              # Validate workflow status
    └── cleanup-old-state.sh           # Remove stale S3 state files
```

---

## AWS Stacks

### App1 — EC2 with ALB & Lambda Scheduler

```mermaid
graph TB
    Internet((Internet)) --> R53[Route53]
    R53 --> ALB[ALB\nHTTP→HTTPS]
    subgraph VPC ["VPC — 10.0.0.0/16"]
        subgraph Public ["Public Subnets"]
            ALB
            NAT[NAT Gateway]
        end
        subgraph Private ["Private Subnets"]
            EC2a[EC2 t2.nano]
            EC2b[EC2 t2.nano]
        end
    end
    ALB --> EC2a & EC2b
    EB[EventBridge] --> Lambda1[Lambda Start\n6 AM ET] & Lambda2[Lambda Stop\n12 AM ET]
    Lambda1 & Lambda2 -.-> EC2a & EC2b
    ACM[ACM TLS] -.-> ALB
    style VPC fill:#e3f2fd
    style Public fill:#c8e6c9
    style Private fill:#ffccbc
    style ALB fill:#2196f3,color:#fff
```

- ALB + ACM HTTPS, HTTP redirect, private EC2 subnets
- Lambda scheduler: start 6 AM / stop midnight ET via EventBridge
- IMDSv2 enforced, KMS-encrypted EBS

### App2 — EKS + Linkerd Service Mesh

```mermaid
graph TB
    Internet((Internet)) --> NLB[NLB]
    NLB --> NGINX[NGINX Ingress Controller]
    subgraph VPC ["VPC — 10.1.0.0/16"]
        subgraph Public ["Public Subnets"]
            NLB
            NAT[NAT Gateway]
        end
        subgraph Private ["Private Subnets"]
            subgraph EKS ["EKS Cluster"]
                NGINX
                subgraph Mesh ["Linkerd mTLS"]
                    P1[Pod + Sidecar]
                    P2[Pod + Sidecar]
                end
                PROM[Prometheus]
                GRAF[Grafana]
            end
        end
    end
    NGINX --> P1 & P2
    OIDC[OIDC / IRSA] -.-> EKS
    style VPC fill:#e3f2fd
    style Public fill:#c8e6c9
    style Private fill:#ffccbc
    style Mesh fill:#f3e5f5
    style EKS fill:#fff9c4
```

- EKS in private subnets, NGINX Ingress on NLB
- Linkerd mTLS between all pods, IRSA via OIDC
- Production Helm chart: HPA, PDB, NetworkPolicy, non-root containers
- Prometheus + Grafana monitoring stack

### App3 — Multi-Region Active-Active

```mermaid
graph TB
    Internet((Internet)) --> R53[Route53]
    R53 --> GA[Global Accelerator\n50/50 split]
    GA -->|50%| EC2W[EC2 Nginx\nus-west-2]
    GA -->|50%| EC2E[EC2 Nginx\nus-east-1]
    EC2W --> DDBW[(DynamoDB\nprimary)]
    EC2E --> DDBE[(DynamoDB\nreplica)]
    DDBW <-->|bi-directional replication| DDBE
    style GA fill:#ff9900,color:#fff
    style DDBW fill:#9c27b0,color:#fff
    style DDBE fill:#9c27b0,color:#fff
```

- Global Accelerator 50/50 traffic split across us-east-1 / us-west-2
- DynamoDB global tables with cross-region stream replication
- Route53 → Global Accelerator → regional EC2 fleets

### App4 — ECS Fargate

```mermaid
graph TB
    Internet((Internet)) --> ALB[ALB]
    subgraph VPC ["VPC"]
        subgraph Public ["Public Subnets"]
            ALB
        end
        subgraph Private ["Private Subnets"]
            subgraph ECS ["ECS Cluster"]
                T1[Fargate Task]
                T2[Fargate Task]
            end
        end
    end
    ALB --> T1 & T2
    CW[CloudWatch\nContainer Insights] -.-> ECS
    style VPC fill:#e3f2fd
    style Public fill:#c8e6c9
    style Private fill:#ffccbc
    style ECS fill:#fff9c4
```

- Serverless containers, Container Insights, CloudWatch logging

### App5 — S3 Static Website + CloudFront

```mermaid
graph TB
    Users((Users)) --> R53[Route53]
    R53 --> CF[CloudFront CDN\nHTTPS + OAC]
    CF --> S3[S3 Bucket\nStatic Website]
    ACM[ACM TLS\nus-east-1] -.-> CF
    style CF fill:#ff9900,color:#fff
    style S3 fill:#569a31,color:#fff
```

- CloudFront + ACM TLS, Origin Access Control, HTTP→HTTPS redirect

### App6 — EKS + ArgoCD GitOps

```mermaid
graph TB
    Git[GitHub Repo] -->|push| ArgoCD[ArgoCD]
    subgraph VPC ["VPC"]
        subgraph EKS ["EKS Cluster"]
            ArgoCD -->|sync| Dev[Dev Namespace]
            ArgoCD -->|sync| QA[QA Namespace]
            ArgoCD -->|sync| Prod[Prod Namespace]
        end
    end
    ArgoCD -->|self-heal rollback| Prod
    style EKS fill:#fff9c4
    style ArgoCD fill:#f06292,color:#fff
```

- ArgoCD declarative sync, multi-env (dev/qa/prod), self-healing rollbacks

### App7 — Site-to-Site VPN + Jenkins

```mermaid
graph TB
    OnPrem[On-Premises\nNetwork] <-->|IPSec VPN| VGW[Virtual Private Gateway]
    subgraph VPC ["VPC — 10.10.0.0/16"]
        subgraph Public ["Public Subnets"]
            Jenkins[Jenkins EC2\nCI/CD Server]
        end
        subgraph Private ["Private Subnets"]
            App[App Servers]
        end
        VGW
    end
    CGW[Customer Gateway\n68.74.135.x] --> VGW
    Jenkins --> App
    style VPC fill:#e3f2fd
    style Public fill:#c8e6c9
    style Private fill:#ffccbc
    style VGW fill:#ff9900,color:#fff
```

- AWS Site-to-Site VPN to on-premises network
- Jenkins CI/CD server on EC2 with pipeline automation

### App8 — Lambda Container

```mermaid
graph TB
    Client((Client)) --> APIGW[API Gateway]
    APIGW --> Lambda[Lambda\nNode.js Container]
    ECR[ECR\nContainer Image] -.->|deploy| Lambda
    style APIGW fill:#ff9900,color:#fff
    style Lambda fill:#f9a825,color:#000
    style ECR fill:#1565c0,color:#fff
```

- Containerized Node.js Lambda via ECR, API Gateway trigger

---

## AI / ML

### Bedrock Agent (app-bedrock)

- Amazon Bedrock agent using Nova micro model
- VPC with private subnets, VPC endpoints (no internet)
- IAM roles for secure API access, agent alias for versioning

### SageMaker MLOps Pipeline (app-sagemaker)

```mermaid
flowchart LR
    S3[(S3 Input)] --> Pre[Preprocess\nscikit-learn]
    Pre --> Train[Train\nXGBoost]
    Train --> Eval[Evaluate\nMetrics]
    Eval --> Gate{Accuracy\n≥ 0.75?}
    Gate -->|Pass| Reg[Register\nModel]
    Gate -->|Pass| Deploy[Deploy\nEndpoint]
    Gate -->|Fail| Fail[Pipeline Fail]
    Reg --> MR[(Model Registry)]
    Deploy --> EP[SageMaker Endpoint]
    style Pre fill:#42a5f5,color:#fff
    style Train fill:#66bb6a,color:#fff
    style Eval fill:#ab47bc,color:#fff
    style Gate fill:#ffa726,color:#fff
    style Deploy fill:#26a69a,color:#fff
    style Fail fill:#ef5350,color:#fff
```

- Full MLOps: preprocess → XGBoost train → evaluate → conditional register + deploy
- Accuracy threshold gate (default 0.75) — pipeline fails if not met
- Model Registry for versioned artifacts, real-time inference endpoint
- VPC with 2 AZs, all traffic via VPC endpoints (no NAT)
- [diagram.md](terraform/live/aws/ai/app-sagemaker/diagram.md)

### CrewAI Agents (crew)

- Multi-agent AI framework using CrewAI
- Automated infrastructure audit and reporting

---

## Network Infrastructure

### Transit Gateway

- Hub-and-spoke topology connecting 2 VPCs (10.1.0.0/16, 10.2.0.0/16)
- ICMP cross-VPC connectivity verified, SSM access

---

## Global / Governance

### AWS Control Tower (plan)

- Multi-region governance: us-east-1 (home), us-west-2, eu-west-1
- OU hierarchy: Platform, Landing Zones (Dev/QA/Prod), Sandbox
- Guardrail strategy: preventive SCPs + detective Config rules per OU
- Account vending via AFT (Account Factory for Terraform)
- [plan.md](terraform/live/aws/global/control-tower/plan.md)

---

## Azure Infrastructure

### Region Failover

- Multi-region VMs (East US 2 + West US 2) with Traffic Manager priority routing
- Azure SQL with geo-replication, ZRS managed disks, NAT Gateway

### Azure Landing Zone (plan)

- Management Group hierarchy: Platform, Landing Zones (Corp/Online), Sandbox
- Hub-and-spoke: Azure Firewall Premium, DNS Resolver, VPN/ER Gateway
- Policy strategy: built-in initiatives (Azure Security Benchmark, NIST 800-53) + custom policies
- Subscription vending flow with auto-applied policies and monitoring
- [plan.md](terraform/live/azure/global/landing-zone/plan.md)

---

## Migration Plans

### AWS EC2 + RDS → Azure

- EC2 → Azure VM via Azure Migrate (agentless, near-zero downtime)
- RDS SQL Server → Azure SQL MI via Azure DMS (online CDC migration)
- Resource mapping, sizing tables, cutover sequence, rollback plan
- [plan.md](terraform/live/azure/aws-azure-migrate/plan.md)

### On-Premises VMware + SQL Server → Azure

- VMware VMs → Azure VMs via Azure Migrate appliance (OVA on ESXi)
- SQL Server → Azure SQL MI / SQL DB via Azure DMS
- SQL target selection guide, DMS online migration flow
- Hub-and-spoke network with ExpressRoute/VPN during migration
- [plan.md](terraform/live/azure/onprem-to-azure/plan.md)

---

## CI/CD Pipeline

```mermaid
flowchart LR
    A[Push / PR] --> B[OIDC Auth]
    B --> C[Terraform Init]
    C --> D[Trivy Scan]
    D --> E[Terraform Plan]
    E --> F{Action?}
    F -->|plan| G([Done])
    F -->|apply| H[Apply]
    F -->|destroy| I[Destroy]
    style A fill:#24292e,color:#fff
    style B fill:#ff9900,color:#fff
    style D fill:#1904da,color:#fff
    style H fill:#4caf50,color:#fff
    style I fill:#f44336,color:#fff
```

| Feature | Details |
|---------|---------|
| Auth | AWS OIDC — no static credentials |
| Security | Trivy infrastructure scanning, SARIF reports |
| Quality | SonarCloud code analysis |
| State | S3 backend with native S3 locking (`use_lockfile = true`), AES-256 |
| Environments | dev, qa, prod via tfvars |
| Terraform | >= 1.10 required |
| Trigger | Manual dispatch, PR, or push to master |

---

## Terraform Modules

| Module | Resources | Purpose |
|--------|-----------|---------|
| `aws/network/vpc` | VPC, Subnets, IGW, NAT, Route Tables, Flow Logs | Network foundation |
| `aws/network/transit-gateway` | Transit Gateway, VPC Attachments | Hub-and-spoke VPC connectivity |
| `aws/compute/ec2` | EC2, IAM Role, Security Group, KMS | Compute with IMDSv2, encrypted EBS |
| `aws/containers/eks` | EKS Cluster, Node Group, OIDC/IRSA, Access Entry | Managed Kubernetes |
| `aws/containers/ecs` | ECS Cluster, Fargate Task Def, Service, CloudWatch | Serverless containers |
| `aws/database/dynamodb` | Global Table, Replicas, Streams | Cross-region replication with PITR |
| `aws/ai/bedrock` | Bedrock Agent, IAM, Alias | AI agent (Amazon Nova) |
| `aws/iam` | 15+ IAM Roles | EKS, SageMaker, CodeBuild, SSM, etc. |

---

## Security Posture

```mermaid
mindmap
  root((Security))
    Authentication
      AWS OIDC
      No static credentials
      Temporary sessions
    Network
      Private subnets
      NAT Gateway
      VPC endpoints
      VPC Flow Logs
    Encryption
      KMS for EBS volumes
      S3 native state locking
      ACM for TLS
      Linkerd mTLS
    Compute
      IMDSv2 enforced
      Least-privilege IAM
      IRSA pod-level access
      Non-root containers
    Scanning
      Trivy infrastructure
      SonarCloud quality
      SARIF to GitHub Security
```

---

## State Management

| Component | Value |
|-----------|-------|
| S3 Bucket | `terraform-state-925185632967` |
| Locking | S3 native (`use_lockfile = true`) — DynamoDB decommissioned |
| Versioning | Enabled |
| Encryption | AES-256 |
| Key Pattern | `{stack}/{environment}/terraform.tfstate` |

---

## Quick Start

```bash
# Navigate to any stack
cd terraform/live/aws/stacks/app1

# Initialize (migrates backend if needed)
terraform init

# Plan
terraform plan -var-file="vars/dev.tfvars"

# Apply
terraform apply -var-file="vars/dev.tfvars"

# Destroy
terraform destroy -var-file="vars/dev.tfvars"
```

### Required GitHub Secrets

| Secret | Purpose |
|--------|---------|
| `AWS_ROLE_ARN` | IAM role ARN for OIDC authentication |
| `SONAR_TOKEN` | SonarCloud authentication token |

---

## Contributing

1. Create a feature branch from `master`
2. Make changes and test with `terraform plan`
3. Open a pull request — CI runs Trivy + SonarCloud automatically
4. Address any security or quality findings
5. Merge after review
