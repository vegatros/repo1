# AWS Infrastructure as Code — `vegatros/q`

Production-grade Terraform infrastructure managing EC2, EKS, and multi-region active-active deployments on AWS, with fully automated CI/CD via GitHub Actions.

---

## Architecture at a Glance

```mermaid
graph TB
    subgraph "CI/CD Layer"
        GH[GitHub Actions]
        OIDC[AWS OIDC Auth]
        Trivy[Trivy Security Scan]
        Sonar[SonarCloud Analysis]
    end

    subgraph "Terraform Layer"
        direction LR
        subgraph Modules
            VPC[vpc]
            EC2M[ec2]
            EKSM[eks]
            ECSM[ecs]
            IAMM[iam]
            BRM[bedrock]
            DDB[dynamodb]
        end
    end

    subgraph "Application Stacks"
        direction LR
        APP1["App1<br/>ALB + EC2<br/>us-east-1"]
        APP2["App2<br/>EKS Cluster<br/>us-east-1"]
        APP3["App3<br/>Multi-Region<br/>us-west-2 + us-east-1"]
    end

    subgraph "AWS Infrastructure"
        direction LR
        R53[Route53<br/>cloudconscious.io]
        ALB[Application<br/>Load Balancer]
        EKS[EKS Cluster]
        GA[Global<br/>Accelerator]
        S3[(S3 State<br/>Backend)]
    end

    GH --> OIDC --> Trivy --> Sonar
    Sonar --> Modules
    Modules --> APP1 & APP2 & APP3
    APP1 --> ALB --> R53
    APP2 --> EKS
    APP3 --> GA --> R53
    APP1 & APP2 & APP3 -.-> S3

    style GH fill:#24292e,color:#fff
    style OIDC fill:#ff9900,color:#fff
    style Trivy fill:#1904da,color:#fff
    style Sonar fill:#f3702a,color:#fff
    style APP1 fill:#4caf50,color:#fff
    style APP2 fill:#2196f3,color:#fff
    style APP3 fill:#9c27b0,color:#fff
    style R53 fill:#8c6bb1
    style S3 fill:#ff9800
```

---

## Repository Structure

```
q/
├── terraform/
│   ├── modules/                   # Reusable infrastructure components
│   │   ├── vpc/                   #   VPC, subnets, IGW, NAT, flow logs
│   │   ├── ec2/                   #   EC2 instances, IAM, security groups
│   │   ├── eks/                   #   EKS cluster, node groups, IAM
│   │   ├── ecs/                   #   Fargate cluster, task definitions
│   │   ├── iam/                   #   Centralized roles & policies
│   │   ├── bedrock/               #   Bedrock agent (Amazon Titan)
│   │   └── dynamodb/              #   Global tables, cross-region replication
│   └── stacks/                    # Deployment targets (dev/qa/prod each)
│       ├── app1/                  #   ALB + EC2, Lambda scheduler, ACM/TLS
│       ├── app2/                  #   EKS + Helm chart, private subnets
│       └── app3/                  #   Multi-region, Global Accelerator, DynamoDB global
├── .github/workflows/             # CI/CD pipelines
│   ├── terraform-app1.yml         #   App1 plan/apply/destroy
│   ├── terraform-app2.yml         #   App2 plan/apply/destroy
│   ├── terraform-app3.yml         #   App3 plan/apply/destroy + SARIF
│   └── code-scan.yml              #   SonarCloud code quality
├── scripts/                       # Utility scripts
│   ├── create-stack.sh            #   Scaffold new stacks from template
│   ├── check-workflow.sh          #   Validate workflow status
│   ├── cleanup-old-state.sh       #   Remove stale S3 state files
│   └── cloudtrail/                #   Real-time AWS event monitoring
├── trading/                       # NQ futures backtesting engine
├── policies/                      # AWS policy definitions
├── DIAGRAMS.md                    # Full Mermaid diagram collection
└── CLAUDE.md                      # AI assistant project guidance
```

---

## Application Stacks

### App1 — EC2 with ALB

```mermaid
graph TB
    Internet((Internet)) --> R53[Route53<br/>cloudconscious.io]
    R53 --> ALB

    subgraph VPC ["VPC — 10.0.0.0/16"]
        subgraph Public ["Public Subnets"]
            ALB[Application Load Balancer<br/>HTTP→HTTPS redirect]
            NAT[NAT Gateway]
        end
        subgraph Private ["Private Subnets"]
            EC2a[EC2 Instance 1<br/>t2.nano]
            EC2b[EC2 Instance 2<br/>t2.nano]
        end
    end

    ALB -->|Target Group| EC2a & EC2b
    NAT --> EC2a & EC2b
    ACM[ACM Certificate<br/>TLS/HTTPS] -.-> ALB

    subgraph Scheduler ["EC2 Scheduler"]
        Lambda1["Lambda: Start<br/>6 AM ET"]
        Lambda2["Lambda: Stop<br/>12 AM ET"]
        EB[EventBridge Cron]
    end

    EB --> Lambda1 & Lambda2
    Lambda1 & Lambda2 -.-> EC2a & EC2b

    style VPC fill:#e3f2fd
    style Public fill:#c8e6c9
    style Private fill:#ffccbc
    style Scheduler fill:#f3e5f5
    style ALB fill:#2196f3,color:#fff
    style ACM fill:#ff9800,color:#fff
```

**Key features:**
- EC2 instances in private subnets with NAT Gateway for outbound
- ALB with ACM certificate for HTTPS, auto HTTP redirect
- Lambda-based scheduler: auto-start at 6 AM ET, auto-stop at midnight
- IMDSv2 enforced, KMS-encrypted EBS volumes

### App2 — EKS Kubernetes

```mermaid
graph TB
    Internet((Internet)) --> IGW[Internet Gateway]

    subgraph VPC ["VPC — 10.0.0.0/16"]
        subgraph Public ["Public Subnets"]
            IGW
            NAT[NAT Gateway]
        end
        subgraph Private ["Private Subnets"]
            subgraph EKS ["EKS Cluster"]
                CP[Control Plane]
                subgraph Nodes ["Managed Node Group"]
                    W1[Worker Node<br/>t3.medium]
                end
            end
        end
    end

    IGW --> NAT --> Private
    IAM[IAM Roles<br/>Cluster + Node] -.-> EKS

    style VPC fill:#e3f2fd
    style Public fill:#c8e6c9
    style Private fill:#ffccbc
    style EKS fill:#b39ddb
    style Nodes fill:#90caf9
```

**Key features:**
- EKS cluster in private subnets with NAT Gateway
- Managed node group with configurable scaling
- Helm chart included for Kubernetes deployments
- Admin access via EKS Access Entry

### App3 — Multi-Region Active-Active

```mermaid
graph TB
    Users((Users)) --> R53[Route53<br/>cloudconscious.io]
    R53 --> GA[Global Accelerator<br/>TCP 443]

    subgraph Region1 ["us-west-2 (Primary)"]
        VPC1[VPC] --> EC2w1[EC2 Instances]
        DDB1[(DynamoDB<br/>Global Table)]
    end

    subgraph Region2 ["us-east-1 (Secondary)"]
        VPC2[VPC] --> EC2e1[EC2 Instances]
        DDB2[(DynamoDB<br/>Replica)]
    end

    GA -->|"50% traffic"| Region1
    GA -->|"50% traffic"| Region2
    DDB1 <-->|"Stream Replication"| DDB2

    style Region1 fill:#e8f5e9
    style Region2 fill:#e3f2fd
    style GA fill:#9c27b0,color:#fff
    style R53 fill:#8c6bb1,color:#fff
```

**Key features:**
- Global Accelerator with 50/50 traffic split
- DynamoDB global tables with cross-region stream replication
- Active-active architecture across us-west-2 and us-east-1
- Route53 DNS pointing to Global Accelerator

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
    H --> J([Deployed])
    I --> K([Torn Down])

    style A fill:#24292e,color:#fff
    style B fill:#ff9900,color:#fff
    style D fill:#1904da,color:#fff
    style H fill:#4caf50,color:#fff
    style I fill:#f44336,color:#fff
```

Each stack has its own workflow with:

| Feature | Details |
|---------|---------|
| **Auth** | AWS OIDC — no static credentials |
| **Security** | Trivy infrastructure scanning, SARIF reports |
| **Quality** | SonarCloud code analysis |
| **State** | S3 backend with DynamoDB locking, AES-256 encryption |
| **Environments** | dev, qa, prod via tfvars |
| **Timeout** | 15-minute max per run |
| **Trigger** | Manual dispatch, PR, or push to master |

---

## Terraform Modules

| Module | Resources | Purpose |
|--------|-----------|---------|
| **vpc** | VPC, Subnets, IGW, NAT, Route Tables, Flow Logs | Network foundation with public/private subnet pattern |
| **ec2** | EC2, IAM Role, Security Group, KMS | Compute with Route53 + DynamoDB access, IMDSv2 |
| **eks** | EKS Cluster, Node Group, IAM Roles, Access Entry | Managed Kubernetes with admin access |
| **ecs** | ECS Cluster, Fargate Task Def, Service, CloudWatch | Container orchestration with Container Insights |
| **iam** | 15+ pre-defined IAM Roles | Roles for EKS, SageMaker, CodeBuild, SSM, etc. |
| **bedrock** | Bedrock Agent, IAM, Alias | AI agent using Amazon Titan text model |
| **dynamodb** | Global Table, Replicas, Streams | Cross-region replication with PITR |

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
      Restricted security groups
      VPC Flow Logs
    Encryption
      KMS for EBS volumes
      AES-256 state files
      ACM for TLS
    Compute
      IMDSv2 enforced
      Least-privilege IAM
      Restricted default SG
    Scanning
      Trivy infrastructure
      SonarCloud quality
      SARIF to GitHub Security
```

---

## Quick Start

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- GitHub repo with Actions enabled + OIDC provider configured

### Deploy locally

```bash
# Navigate to a stack
cd terraform/stacks/app1

# Initialize and deploy
terraform init
terraform plan -var-file="vars/dev.tfvars"
terraform apply -var-file="vars/dev.tfvars"

# Tear down
terraform destroy -var-file="vars/dev.tfvars"
```

### Create a new stack

```bash
./scripts/create-stack.sh <stack-name>
```

### Required GitHub Secrets

| Secret | Purpose |
|--------|---------|
| `AWS_ROLE_ARN` | IAM role ARN for OIDC authentication |
| `SONAR_TOKEN` | SonarCloud authentication token |

---

## State Management

| Component | Value |
|-----------|-------|
| **S3 Bucket** | `terraform-state-925185632967` |
| **DynamoDB Table** | `terraform-state-lock` (us-east-1) |
| **Versioning** | Enabled |
| **Encryption** | AES-256 |
| **Key Pattern** | `{stack}/{environment}/terraform.tfstate` |

---

## Trading Module (Bonus)

NQ (NASDAQ-100) futures backtesting engine using **EMA 9/21 crossover** strategy.

| Parameter | Value |
|-----------|-------|
| Contract | NQ ($20/pt) or MNQ ($2/pt) |
| Timeframe | 1-minute bars |
| Session | 9:30 AM - 4:00 PM ET |
| Stop Loss | 50 points hard stop |
| Trailing Stop | Activates at +25pt, trails 40pt |

```bash
cd trading
pip install pandas numpy yfinance matplotlib
python nq_ema_backtest.py
```

---

## Additional Documentation

- [DIAGRAMS.md](DIAGRAMS.md) — Full collection of Mermaid architecture and workflow diagrams
- [CLAUDE.md](CLAUDE.md) — AI assistant project guidance and conventions

---

## Contributing

1. Create a feature branch from `master`
2. Make changes and test with `terraform plan`
3. Create a pull request — CI runs Trivy + SonarCloud automatically
4. Address any security or quality findings
5. Merge after review and approval
