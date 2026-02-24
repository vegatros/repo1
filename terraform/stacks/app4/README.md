# App4 — ECS Fargate Deployment

Production-grade ECS Fargate cluster with Application Load Balancer and auto-scaling capabilities.

---

## Architecture

```mermaid
graph TB
    Internet((Internet)) --> ALB[Application<br/>Load Balancer]

    subgraph VPC ["VPC — 10.4.0.0/16"]
        subgraph Public ["Public Subnets"]
            ALB
            NAT[NAT Gateway]
        end
        
        subgraph Private ["Private Subnets"]
            subgraph ECS ["ECS Cluster"]
                subgraph Tasks ["Fargate Tasks"]
                    T1[Task 1<br/>nginx<br/>256 CPU / 512 MB]
                    T2[Task 2<br/>nginx<br/>256 CPU / 512 MB]
                end
            end
        end
    end

    ALB --> T1 & T2
    NAT -.-> Private
    
    CW[CloudWatch<br/>Logs] -.->|Logs| Tasks
    IAM[IAM Roles<br/>Execution + Task] -.->|Permissions| Tasks

    style VPC fill:#e3f2fd
    style Public fill:#c8e6c9
    style Private fill:#ffccbc
    style ECS fill:#b39ddb
    style Tasks fill:#90caf9
    style ALB fill:#2196f3,color:#fff
```

---

## Features

- ✅ **ECS Fargate** - Serverless container orchestration
- ✅ **Application Load Balancer** - HTTP/HTTPS traffic distribution
- ✅ **Private Subnets** - Tasks run in private subnets with NAT
- ✅ **CloudWatch Logs** - Centralized logging
- ✅ **IAM Roles** - Separate execution and task roles
- ✅ **Health Checks** - ALB health monitoring
- ✅ **Multi-AZ** - High availability across availability zones

---

## Quick Start

```bash
# Initialize
cd terraform/stacks/app4
terraform init

# Plan
terraform plan -var-file="vars/dev.tfvars"

# Deploy
terraform apply -var-file="vars/dev.tfvars"

# Get application URL
terraform output alb_url
```

---

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `project_name` | Project name | - |
| `environment` | Environment (dev/qa/prod) | - |
| `vpc_cidr` | VPC CIDR block | 10.4.0.0/16 |
| `container_image` | Docker image | nginx:latest |
| `container_port` | Container port | 80 |
| `desired_count` | Number of tasks | 2 |
| `cpu` | Task CPU units | 256 |
| `memory` | Task memory (MB) | 512 |

---

## Outputs

| Output | Description |
|--------|-------------|
| `alb_url` | Application URL |
| `alb_dns_name` | ALB DNS name |
| `cluster_name` | ECS cluster name |
| `service_name` | ECS service name |

---

## Environments

- **dev**: 2 tasks, 256 CPU / 512 MB
- **qa**: 2 tasks, 512 CPU / 1024 MB
- **prod**: 3 tasks, 512 CPU / 1024 MB

---

## Management

### View Tasks
```bash
aws ecs list-tasks --cluster myapp4-dev --region us-east-1
```

### View Logs
```bash
aws logs tail /ecs/myapp4-dev --follow --region us-east-1
```

### Update Service
```bash
terraform apply -var-file="vars/dev.tfvars"
```

---

## Cleanup

```bash
terraform destroy -var-file="vars/dev.tfvars"
```
