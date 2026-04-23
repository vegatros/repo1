# Cline Repository Summary — repo1

> Generated for Cline CLI context. Keep this file updated when major architectural changes occur.

---

## Overview

Production-grade Terraform infrastructure repository covering **AWS** and **Azure**, with application stacks, AI/ML pipelines, multi-cloud networking, governance, and migration planning. Automated CI/CD via GitHub Actions.

- **Primary Cloud**: AWS (8 app stacks, AI/ML, networking, security)
- **Secondary Cloud**: Azure (region failover, landing zone, migration plans)
- **Other**: GCP & Oracle security plans, Vercel app
- **IaC Tool**: Terraform >= 1.10
- **State Backend**: S3 with native locking (`use_lockfile = true`)

---

## Repository Layout

```
repo1/
├── terraform/
│   ├── provider/          # Live/stack deployments (was "stacks/builds")
│   │   ├── aws/stacks/app[1-8]/    # AWS application stacks
│   │   ├── aws/ai/                 # Bedrock, SageMaker, CrewAI
│   │   ├── aws/network/tgw/        # Transit Gateway
│   │   ├── aws/global/control-tower/
│   │   ├── aws/security/cloudtrail/
│   │   ├── azure/stacks/region-failover/
│   │   ├── azure/migrate/
│   │   ├── azure/security/
│   │   ├── gcp/security/
│   │   ├── oracle/security/
│   │   └── vercel/app1/
│   └── modules/           # Reusable Terraform modules
│       ├── aws/network/vpc, transit-gateway
│       ├── aws/compute/ec2
│       ├── aws/containers/eks, ecs
│       ├── aws/database/dynamodb
│       ├── aws/ai/bedrock
│       └── azure/compute/vm
├── .github/workflows/     # CI/CD pipelines
├── scripts/               # Helper scripts (create-stack, cleanup, etc.)
└── README.md              # Full documentation with Mermaid diagrams
```

---

## Key Stacks

| Stack | Cloud | Description |
|-------|-------|-------------|
| `app1` | AWS | EC2 + ALB + Lambda scheduler (start/stop) |
| `app2` | AWS | EKS + Linkerd service mesh + NGINX Ingress + Prometheus/Grafana |
| `app3` | AWS | Multi-region active-active (Global Accelerator + DynamoDB global tables) |
| `app4` | AWS | ECS Fargate cluster |
| `app5` | AWS | S3 static website + CloudFront CDN |
| `app6` | AWS | EKS + ArgoCD GitOps (dev/qa/prod) |
| `app7` | AWS | Site-to-Site VPN (IPSec, dual tunnels) |
| `app8` | AWS | Lambda container (Node.js) + API Gateway |
| `app-bedrock` | AWS | Amazon Bedrock AI agent (Nova micro model) |
| `app-sagemaker` | AWS | SageMaker MLOps pipeline (XGBoost, accuracy gate, model registry) |
| `crew` | AWS | CrewAI multi-agent Terraform audit framework |
| `region-failover` | Azure | Multi-region VMs + Traffic Manager + Azure SQL geo-replication |

---

## AI / ML Components

### Bedrock Agent (`terraform/provider/aws/ai/app-bedrock/`)
- Uses module `aws/ai/bedrock` with `amazon.nova-micro-v1:0` foundation model
- Private VPC with VPC endpoints (no NAT/internet)
- EC2 client in private subnet with SSM access
- IAM: `bedrock:InvokeAgent`, `bedrock:InvokeModel`

### SageMaker MLOps (`terraform/provider/aws/ai/app-sagemaker/`)
- Pipeline: Preprocess → XGBoost Train → Evaluate → Conditional Register/Deploy
- Accuracy threshold gate (default 0.75)
- Model Registry + real-time inference endpoint
- VPC with 2 AZs, all traffic via VPC endpoints

### CrewAI Audit (`terraform/provider/aws/ai/crew/`)
- Multi-agent framework: Security Analyst, Cost Optimizer, Report Writer
- Targets Terraform stacks for automated audit
- Uses Anthropic Claude API (model: `claude-sonnet-4-20250514`)
- Triggered via GitHub Actions (`terraform-audit.yml`)

---

## CI/CD Pipelines

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `terraform-sagemaker.yml` | Manual dispatch | Deploy SageMaker stack (dev/qa/prod) + trigger pipeline |
| `terraform-audit.yml` | PR/push to `master` (azure/region-failover path) | Snyk IaC scan + CrewAI audit |
| `code-scan.yml` | PR/push | Code quality & security scan |

**Auth**: AWS OIDC (no static credentials)  
**Scanning**: Trivy (config), Snyk (IaC), SonarCloud  
**State**: S3 backend, AES-256, versioning enabled

---

## Terraform Modules

| Module | Resources |
|--------|-----------|
| `aws/network/vpc` | VPC, subnets, IGW, NAT, route tables, flow logs |
| `aws/network/transit-gateway` | TGW, VPC attachments |
| `aws/compute/ec2` | EC2, IAM role, security group, KMS, IMDSv2 |
| `aws/containers/eks` | EKS cluster, node groups, OIDC/IRSA, access entries |
| `aws/containers/ecs` | ECS cluster, Fargate task def, service, CloudWatch |
| `aws/database/dynamodb` | Global tables, replicas, streams, PITR |
| `aws/ai/bedrock` | Bedrock agent, IAM, alias |
| `aws/iam/*` | 15+ IAM roles (EKS, SageMaker, CodeBuild, SSM, etc.) |
| `azure/compute/vm` | Linux VM, NIC, optional public IP + data disk |

---

## Security Posture

- **Auth**: AWS OIDC, no static credentials, temporary sessions
- **Network**: Private subnets, NAT Gateway, VPC endpoints, VPC Flow Logs
- **Encryption**: KMS (EBS), ACM (TLS), S3 native locking, Linkerd mTLS
- **Compute**: IMDSv2 enforced, least-privilege IAM, IRSA pod-level access, non-root containers
- **Scanning**: Trivy infrastructure, SonarCloud quality, SARIF to GitHub Security

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

## Quick Commands

```bash
# Init any stack
cd terraform/provider/aws/stacks/app1
terraform init

# Plan / Apply / Destroy
terraform plan -var-file="vars/dev.tfvars"
terraform apply -var-file="vars/dev.tfvars"
terraform destroy -var-file="vars/dev.tfvars"
```

---

## Notes for Cline

- **Path references**: The README mentions `terraform/stacks/builds/` — the actual live paths are `terraform/provider/` and `terraform/modules/`. Some GitHub Actions workflows still reference old paths (`terraform/stacks/aws/builds/app-sagemaker`) and may need updates.
- **Bedrock model**: Currently `amazon.nova-micro-v1:0` — can be swapped via `terraform/modules/aws/ai/bedrock/main.tf` and `variables.tf`.
- **CrewAI model**: Hardcoded to `claude-sonnet-4-20250514` in `.github/workflows/terraform-audit.yml`.
- **Sensitive files**: `.pem` key files and VPN configs are in `.gitignore` — never commit them.
- **Backend config**: Each stack has its own `backend.tf` pointing to the shared S3 bucket.
