# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AWS Infrastructure as Code repository using Terraform with GitHub Actions CI/CD pipelines. Manages two application stacks:
- **app1**: EC2-based application (VPC + EC2 modules)
- **app2**: EKS Kubernetes-based application (VPC + EKS modules)

## Common Commands

### Terraform Operations (run from stack directory)
```bash
cd terraform/stacks/app1  # or app2

terraform init
terraform validate
terraform fmt -check
terraform plan -var-file="dev.tfvars"    # or qa.tfvars, prod.tfvars
terraform apply -var-file="dev.tfvars"
terraform destroy -var-file="dev.tfvars"
```

### Utility Scripts
```bash
./scripts/create-stack.sh <stack-name>   # Create new stack from template
./scripts/check-workflow.sh              # Validate workflow status
./scripts/cleanup-old-state.sh           # Clean up old state files
```

## Architecture

### Directory Structure
```
terraform/
├── stacks/           # Deployment targets
│   ├── app1/         # EC2 stack: main.tf, variables.tf, backend.tf, *.tfvars
│   └── app2/         # EKS stack: same structure
└── modules/          # Reusable components
    ├── vpc/          # VPC, subnets, IGW, NAT Gateway, route tables
    ├── ec2/          # EC2 instances, security groups
    ├── eks/          # EKS cluster, managed node groups, IAM roles
    ├── ecs/          # ECS service configurations
    ├── iam/          # IAM roles and policies
    └── bedrock/      # AWS Bedrock AI/ML configurations
```

### CI/CD Workflows (.github/workflows/)
- **terraform-app1.yml** / **terraform-app2.yml**: Full deployment pipeline with Checkov security scan, SonarCloud analysis, and Terraform plan/apply/destroy
- **code-scan.yml**: Standalone code quality scanning

### Key Patterns
- Environment-specific configs via tfvars files (dev, qa, prod)
- S3 backend for state storage with DynamoDB locking
- AWS OIDC authentication (no static credentials)
- Checkov for infrastructure security scanning
- SonarCloud for code quality analysis

## Required GitHub Secrets
- `AWS_ROLE_ARN`: IAM role ARN for OIDC authentication
- `SONAR_TOKEN`: SonarCloud authentication token

## Trading Module (Bonus)

Located in `trading/`. Python backtesting engine for NQ futures using EMA 9/21 crossover strategy.

```bash
cd trading
pip install pandas numpy yfinance matplotlib
python nq_ema_backtest.py
```
