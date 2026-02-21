# App3 - Cross-Region Active-Active Architecture

Multi-region active-active deployment using AWS Global Accelerator and Route 53 for high availability and low latency global traffic distribution.

## Architecture

```
                    ┌─────────────────┐
                    │   Route 53      │
                    │ cloudconcious   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │     Global      │
                    │   Accelerator   │
                    └────┬──────┬─────┘
                         │      │
              ┌──────────┘      └──────────┐
              │                            │
    ┌─────────▼─────────┐        ┌────────▼────────┐
    │   us-west-2       │        │   us-east-1     │
    │   VPC 10.3.0.0/16 │        │   VPC 10.4.0.0/16│
    │                   │        │                 │
    │  ┌─────────────┐  │        │  ┌─────────────┐│
    │  │ EC2 + Nginx │  │        │  │ EC2 + Nginx ││
    │  │ Amazon Linux│  │        │  │ Amazon Linux││
    │  └─────────────┘  │        │  └─────────────┘│
    └───────────────────┘        └─────────────────┘
```

## Components

### Infrastructure
- **2 VPCs**: One in us-west-2 (10.3.0.0/16), one in us-east-1 (10.4.0.0/16)
- **2 EC2 Instances**: Amazon Linux with Nginx in each region
- **AWS Global Accelerator**: Provides static anycast IPs and intelligent traffic routing
- **Route 53**: DNS management with domain alias to Global Accelerator

### Traffic Distribution
- **Active-Active**: Both regions serve traffic simultaneously (50/50 split)
- **Health Checks**: HTTP health checks on port 80 every 30 seconds
- **Automatic Failover**: Unhealthy endpoints removed from rotation

## Deployment

### Prerequisites
1. AWS account with appropriate permissions
2. S3 bucket for Terraform state (update `backend.tf`)
3. Domain name configured in `dev.tfvars`
4. Valid AMI IDs for both regions

### Local Deployment

```bash
cd terraform/stacks/app3

# Initialize
terraform init

# Plan
terraform plan -var-file="dev.tfvars"

# Apply
terraform apply -var-file="dev.tfvars"
```

### GitHub Actions Deployment

Trigger via workflow dispatch:
1. Go to Actions → Terraform App3
2. Select environment (dev/qa/prod)
3. Select action (plan/apply/destroy)
4. Run workflow

## Configuration

### Environment Variables (dev.tfvars)

```hcl
environment  = "dev"
domain_name  = "cloudconcious.dev"

# us-west-2
vpc_cidr_west            = "10.3.0.0/16"
public_subnet_cidrs_west = ["10.3.1.0/24"]
availability_zones_west  = ["us-west-2a"]
ami_id_west              = "ami-xxxxx"

# us-east-1
vpc_cidr_east            = "10.4.0.0/16"
public_subnet_cidrs_east = ["10.4.1.0/24"]
availability_zones_east  = ["us-east-1a"]
ami_id_east              = "ami-xxxxx"

instance_type = "t3.micro"
```

## Outputs

After deployment:
- `global_accelerator_dns`: Global Accelerator DNS name
- `global_accelerator_ips`: Static anycast IP addresses
- `route53_nameservers`: Nameservers for domain delegation
- `domain_name`: Configured domain
- `ec2_west_public_ip`: Direct EC2 IP in us-west-2
- `ec2_east_public_ip`: Direct EC2 IP in us-east-1

## DNS Configuration

After deployment, delegate your domain to Route 53:
1. Get nameservers from `route53_nameservers` output
2. Update your domain registrar with these nameservers
3. Wait for DNS propagation (up to 48 hours)

## Testing

```bash
# Test via Global Accelerator
curl http://<global-accelerator-dns>

# Test via domain (after DNS delegation)
curl http://cloudconcious.dev

# Test individual regions
curl http://<ec2_west_public_ip>
curl http://<ec2_east_public_ip>
```

Each response shows the region and instance ID serving the request.

## Cost Optimization

- **Global Accelerator**: ~$0.025/hour + data transfer fees
- **EC2 t3.micro**: ~$0.0104/hour per instance
- **Route 53**: $0.50/month per hosted zone + query charges
- **Estimated monthly cost**: ~$20-30 for dev environment

## Security

- Security groups allow HTTP (port 80) from Global Accelerator
- No SSH access by default (configure `ssh_allowed_cidrs` if needed)
- VPCs isolated per region
- Health checks ensure only healthy endpoints receive traffic

## Monitoring

Monitor via AWS Console:
- **Global Accelerator**: Flow logs, health check status
- **EC2**: CloudWatch metrics, instance health
- **Route 53**: Query logs, health check status

## Troubleshooting

### Traffic not routing
- Check Global Accelerator health checks in AWS Console
- Verify security groups allow port 80
- Ensure Nginx is running: `systemctl status nginx`

### DNS not resolving
- Verify nameserver delegation at domain registrar
- Check Route 53 hosted zone configuration
- Wait for DNS propagation

### Region failover not working
- Check endpoint health in Global Accelerator console
- Verify health check path returns 200 OK
- Review CloudWatch logs for errors
