# VPC Module

Reusable Terraform module for creating AWS VPC with public/private subnets, NAT gateway, and VPC flow logs.

## Features
- VPC with configurable CIDR
- Public and private subnets across AZs
- Internet Gateway for public subnets
- Optional NAT Gateway for private subnets
- VPC Flow Logs with KMS encryption
- Restricted default security group
- Auto-calculated subnet CIDRs

## Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"

  project_name            = "myapp"
  vpc_cidr                = "10.0.0.0/16"
  enable_nat_gateway      = true
  enable_flow_logs        = true
  flow_logs_retention_days = 7

  tags = {
    Environment = "dev"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Project name for resource naming | string | - | yes |
| vpc_cidr | VPC CIDR block | string | 10.0.0.0/16 | no |
| azs | Availability zones | list(string) | [] (auto) | no |
| public_subnet_cidrs | Public subnet CIDRs | list(string) | [] (auto) | no |
| private_subnet_cidrs | Private subnet CIDRs | list(string) | [] (auto) | no |
| enable_nat_gateway | Enable NAT gateway | bool | false | no |
| enable_flow_logs | Enable VPC flow logs | bool | true | no |
| flow_logs_retention_days | Flow logs retention | number | 7 | no |
| tags | Additional tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| vpc_cidr | VPC CIDR block |
| public_subnet_ids | List of public subnet IDs |
| private_subnet_ids | List of private subnet IDs |
| internet_gateway_id | Internet Gateway ID |
| nat_gateway_id | NAT Gateway ID (if enabled) |
| default_security_group_id | Default security group ID |

## Security Features
- Default security group blocks all traffic
- VPC Flow Logs with KMS encryption
- KMS key rotation enabled
- IMDSv2 ready
