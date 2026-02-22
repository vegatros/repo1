# AWS Infrastructure as Code Repository

This repository contains Terraform configurations for managing AWS infrastructure and GitHub Actions workflows for automated deployment and security scanning.

## Architecture Diagram

![Network Architecture](terraform/stacks/app1/diagrams/network-diagram.drawio.png)

## Repository Structure

```
.
├── terraform/
│   ├── stacks/              # Application stacks
│   │   ├── app1/           # EC2-based application
│   │   └── app2/           # EKS-based application
│   └── modules/            # Reusable Terraform modules
│       ├── vpc/            # VPC with public/private subnets
│       ├── ec2/            # EC2 instance module
│       ├── eks/            # EKS cluster module
│       ├── ecs/            # ECS service module
│       ├── iam/            # IAM roles and policies
│       └── bedrock/        # AWS Bedrock configurations
├── cloudtrail/             # CloudTrail logging configurations
├── .github/workflows/      # GitHub Actions CI/CD pipelines
└── install.sh              # Setup script
```

## Terraform Modules

### VPC Module (`terraform/modules/vpc/`)
Reusable VPC module with configurable public/private subnets, internet gateway, and optional NAT gateway.

**Key Resources:**
- VPC with DNS support
- Public/Private subnets
- Internet Gateway
- NAT Gateway (optional)
- Route tables

### EC2 Module (`terraform/modules/ec2/`)
Manages EC2 instances with security groups.

**Key Resources:**
- EC2 instances
- Security Groups

### EKS Module (`terraform/modules/eks/`)
Provisions Amazon Elastic Kubernetes Service clusters using existing VPC infrastructure.

**Key Resources:**
- EKS cluster
- Managed node groups
- IAM roles for cluster and nodes
- Security groups

### Application Stacks

#### App1 Stack (`terraform/stacks/app1/`)
EC2-based application using VPC and EC2 modules.

**Components:**
- VPC module (public/private subnets)
- EC2 module (instances in public subnet)
- Multi-environment support (dev, qa, prod)

#### App2 Stack (`terraform/stacks/app2/`)
EKS-based application using VPC and EKS modules.

**Components:**
- VPC module (with NAT gateway for private subnets)
- EKS module (cluster in private subnets)
- Managed node groups (1 node per environment)
- Multi-environment support (dev, qa, prod)

### ECS Module (`terraform/ecs/`)
Manages Amazon Elastic Container Service for Docker container deployments.

### IAM Module (`terraform/iam/`)
Centralized IAM role and policy management for AWS resources.

### Bedrock Module (`terraform/bedrock/`)
Configurations for AWS Bedrock AI/ML services.

## GitHub Actions Workflows

### Terraform App1 Workflow (`.github/workflows/terraform-app1.yml`)

**Purpose:** Automates Terraform infrastructure deployment for app1 (EC2) stack with validation, planning, and approval gates.

**Triggers:**
- Manual dispatch (`workflow_dispatch`) with environment and action selection
- Pull requests affecting `terraform/stacks/app1/**` files
- Pushes to `master` branch

**Workflow Steps:**
1. **Checkout** - Retrieves repository code
2. **AWS Authentication** - Uses OIDC to assume AWS role (no long-lived credentials)
3. **Terraform Init** - Initializes backend with environment-specific state
4. **Terraform Format** - Validates code formatting
5. **Terraform Validate** - Checks configuration syntax
6. **Checkov Scan** - Security and compliance scanning
7. **SonarCloud Scan** - Code quality analysis
8. **Terraform Plan** - Generates execution plan with environment tfvars
9. **Terraform Apply/Destroy** - Executes based on selected action

**Security Features:**
- OIDC authentication (no static credentials)
- Environment-specific state management
- Security and quality scanning
- 15-minute timeout to prevent runaway jobs

### Terraform App2 Workflow (`.github/workflows/terraform-app2.yml`)

**Purpose:** Automates Terraform infrastructure deployment for app2 (EKS) stack with validation, planning, and approval gates.

**Triggers:**
- Manual dispatch (`workflow_dispatch`) with environment and action selection
- Pull requests affecting `terraform/stacks/app2/**` files
- Pushes to `master` branch

**Workflow Steps:**
1. **Checkout** - Retrieves repository code
2. **AWS Authentication** - Uses OIDC to assume AWS role (no long-lived credentials)
3. **Terraform Init** - Initializes backend with environment-specific state
4. **Terraform Format** - Validates code formatting
5. **Terraform Validate** - Checks configuration syntax
6. **Checkov Scan** - Security and compliance scanning
7. **SonarCloud Scan** - Code quality analysis
8. **Terraform Plan** - Generates execution plan with environment tfvars
9. **Terraform Apply/Destroy** - Executes based on selected action

**Security Features:**
- OIDC authentication (no static credentials)
- Environment-specific state management
- Security and quality scanning
- 15-minute timeout to prevent runaway jobs

### Checkov Security Scan (`.github/workflows/checkov.yml`)

**Purpose:** Performs static security analysis on Terraform code to identify misconfigurations and compliance violations.

**Triggers:**
- Pull requests to `master` branch
- Pushes to `master` branch

**Workflow Steps:**
1. **Checkout** - Retrieves repository code
2. **Run Checkov** - Scans Terraform configurations for security issues
3. **Check SARIF** - Verifies scan results file exists
4. **Upload Results** - Publishes findings to GitHub Security tab

**Security Checks:**
- Infrastructure misconfigurations
- Security best practices violations
- Compliance policy violations
- Results viewable in GitHub Security > Code scanning alerts

**Configuration:**
- Scans: `terraform/ec2` directory
- Output: CLI (logs) + SARIF (GitHub Security)
- Mode: `soft_fail` (doesn't block on findings)

## Setup Instructions

### Prerequisites
- AWS Account with appropriate permissions
- GitHub repository with Actions enabled
- Terraform >= 1.0

### AWS Configuration

1. **Create OIDC Provider in AWS:**
   ```bash
   aws iam create-open-id-connect-provider \
     --url https://token.actions.githubusercontent.com \
     --client-id-list sts.amazonaws.com \
     --thumbprint-list <github-thumbprint>
   ```

2. **Create IAM Role for GitHub Actions:**
   - Trust policy allowing GitHub OIDC
   - Attach necessary AWS permissions
   - Store role ARN in GitHub secret: `AWS_ROLE_ARN`

3. **Configure S3 Backend:**
   - Create S3 bucket for Terraform state
   - Enable versioning and encryption
   - Update `backend.tf` files with bucket name

### GitHub Secrets

Required secrets in repository settings:
- `AWS_ROLE_ARN` - IAM role ARN for OIDC authentication

### Running Terraform Locally

```bash
# Navigate to stack directory
cd terraform/stacks/app1  # or app2

# Initialize Terraform
terraform init

# Plan changes with environment-specific variables
terraform plan -var-file="dev.tfvars"

# Apply changes
terraform apply -var-file="dev.tfvars"

# Destroy infrastructure
terraform destroy -var-file="dev.tfvars"
```

## Workflow Permissions

Both workflows use minimal required permissions:
- `id-token: write` - OIDC authentication
- `contents: read` - Repository access
- `pull-requests: write` - PR comments
- `security-events: write` - Security scan uploads

## Best Practices

1. **Always create pull requests** for infrastructure changes
2. **Review Terraform plans** before approving
3. **Address Checkov findings** before merging
4. **Use feature branches** for development
5. **Keep modules isolated** for independent deployment
6. **Monitor GitHub Actions logs** for deployment status

## Troubleshooting

### Terraform Apply Fails
- Check AWS credentials and permissions
- Verify backend state bucket exists
- Review Terraform plan output for errors

### Checkov Scan Failures
- Review security findings in GitHub Security tab
- Update configurations to address violations
- Consider exceptions for false positives

### Workflow Permission Errors
- Verify GitHub Actions permissions in repository settings
- Check AWS IAM role trust policy
- Ensure OIDC provider is configured correctly

## Contributing

1. Create feature branch from `master`
2. Make infrastructure changes
3. Test locally with `terraform plan`
4. Create pull request
5. Review Terraform plan in PR comments
6. Address Checkov security findings
7. Merge after approval

## Support

For issues or questions:
- Check GitHub Actions logs
- Review Terraform documentation
- Consult AWS service documentation
