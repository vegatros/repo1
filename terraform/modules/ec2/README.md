# EC2 Module

Reusable Terraform module for deploying EC2 instances.

## Features
- Automatic AMI selection (latest Amazon Linux 2)
- Security group with egress rules
- IMDSv2 enforced
- Encrypted root volumes
- Multi-instance support with subnet distribution

## Usage

```hcl
module "ec2" {
  source = "../../modules/ec2"

  project_name   = "myapp"
  vpc_id         = aws_vpc.main.id
  subnet_ids     = [aws_subnet.private[0].id, aws_subnet.private[1].id]
  instance_type  = "t2.micro"
  instance_count = 2

  tags = {
    Environment = "dev"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Project name for resource naming | string | - | yes |
| vpc_id | VPC ID | string | - | yes |
| subnet_ids | List of subnet IDs | list(string) | - | yes |
| instance_type | EC2 instance type | string | t2.micro | no |
| instance_count | Number of instances | number | 1 | no |
| ami_id | AMI ID (uses latest AL2 if empty) | string | "" | no |
| key_name | SSH key pair name | string | "" | no |
| user_data | User data script | string | "" | no |
| tags | Additional tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_ids | List of EC2 instance IDs |
| instance_private_ips | List of private IP addresses |
| instance_public_ips | List of public IP addresses |
| security_group_id | Security group ID |
