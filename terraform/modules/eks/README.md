# EKS Module

Reusable Terraform module for deploying Amazon EKS clusters.

## Features
- EKS cluster with managed node groups
- IAM roles for cluster and nodes
- Configurable node scaling
- Uses existing VPC and subnets

## Usage

```hcl
module "eks" {
  source = "../../modules/eks"

  cluster_name  = "my-cluster"
  vpc_id        = module.vpc.vpc_id
  subnet_ids    = module.vpc.private_subnet_ids
  instance_type = "t3.medium"
  desired_size  = 2
  min_size      = 1
  max_size      = 3

  tags = {
    Environment = "dev"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| cluster_name | EKS cluster name | string | - | yes |
| vpc_id | VPC ID | string | - | yes |
| subnet_ids | List of subnet IDs | list(string) | - | yes |
| instance_type | Worker node instance type | string | t3.medium | no |
| desired_size | Desired number of nodes | number | 2 | no |
| min_size | Minimum number of nodes | number | 1 | no |
| max_size | Maximum number of nodes | number | 3 | no |
| tags | Additional tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | EKS cluster ID |
| cluster_name | EKS cluster name |
| cluster_endpoint | EKS cluster endpoint |
| cluster_security_group_id | Cluster security group ID |
| cluster_arn | EKS cluster ARN |
| node_group_id | Node group ID |
| node_group_arn | Node group ARN |

## Requirements
- VPC with private subnets
- NAT Gateway for private subnet internet access
