# App3 - Cross-Region Active-Active Architecture

Multi-region active-active deployment using AWS Global Accelerator and Route 53 for high availability and low latency global traffic distribution with HTTPS encryption.

## Architecture

```
                    ┌─────────────────┐
                    │   Route 53      │
                    │ cloudconscious  │
                    │      .io        │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │     Global      │
                    │   Accelerator   │
                    │   HTTPS (443)   │
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
    │  │ HTTPS (443) │  │        │  │ HTTPS (443) ││
    │  │ Self-signed │  │        │  │ Self-signed ││
    │  └─────────────┘  │        │  └─────────────┘│
    └───────────────────┘        └─────────────────┘
```

## Components

### Infrastructure
- **2 VPCs**: One in us-west-2 (10.3.0.0/16), one in us-east-1 (10.4.0.0/16)
- **2 EC2 Instances**: Amazon Linux with Nginx and SSL in each region
- **AWS Global Accelerator**: Provides static anycast IPs and intelligent traffic routing on port 443
- **Route 53**: DNS management with domain alias to Global Accelerator
- **SSL/TLS**: Self-signed certificates with automatic HTTP to HTTPS redirect

### Traffic Distribution
- **Active-Active**: Both regions serve traffic simultaneously (50/50 split)
- **Health Checks**: TCP health checks on port 443 every 30 seconds
- **Automatic Failover**: Unhealthy endpoints removed from rotation
- **HTTPS Only**: All HTTP traffic redirected to HTTPS

## Deployment

### Prerequisites
1. AWS account with appropriate permissions
2. S3 bucket for Terraform state (update `backend.tf`)
3. Existing Route 53 hosted zone: cloudconscious.io (Z3LLP0B81D4CRA)
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

# us-west-2
vpc_cidr_west            = "10.3.0.0/16"
public_subnet_cidrs_west = ["10.3.1.0/24"]
availability_zones_west  = ["us-west-2a"]
ami_id_west              = "ami-075b5421f670d735c"

# us-east-1
vpc_cidr_east            = "10.4.0.0/16"
public_subnet_cidrs_east = ["10.4.1.0/24"]
availability_zones_east  = ["us-east-1a"]
ami_id_east              = "ami-0f3caa1cf4417e51b"

instance_type = "t3.micro"
```

## Outputs

After deployment:
- `global_accelerator_dns`: Global Accelerator DNS name
- `global_accelerator_ips`: Static anycast IP addresses (2 IPs)
- `domain_name`: cloudconscious.io
- `ec2_west_public_ip`: Direct EC2 IP in us-west-2
- `ec2_east_public_ip`: Direct EC2 IP in us-east-1

## SSL/TLS Configuration

### Self-Signed Certificates
- Automatically generated on instance launch
- Valid for 365 days
- Subject: CN=cloudconscious.io
- Protocols: TLSv1.2, TLSv1.3
- Ciphers: HIGH security only

### HTTP to HTTPS Redirect
- All HTTP (port 80) traffic automatically redirects to HTTPS (port 443)
- 301 permanent redirect
- Preserves request URI

### Upgrading to Let's Encrypt (Production)
For production use with valid certificates:

1. Ensure DNS points to instances
2. SSH into each instance
3. Install certbot: `yum install -y certbot python3-certbot-nginx`
4. Run: `certbot --nginx -d cloudconscious.io -d www.cloudconscious.io`
5. Certificates auto-renew via cron

## Testing

```bash
# Test via Global Accelerator (HTTPS)
curl -k https://<global-accelerator-dns>

# Test via domain (after DNS propagation)
curl -k https://cloudconscious.io

# Test individual regions (HTTPS)
curl -k https://<ec2_west_public_ip>
curl -k https://<ec2_east_public_ip>

# Verify HTTP redirect
curl -I http://cloudconscious.io
# Should return: HTTP/1.1 301 Moved Permanently
```

Each response shows the region and instance ID serving the request.

## Security Features

### Network Security
- Security groups allow only HTTP (80) and HTTPS (443)
- No SSH access by default
- VPCs isolated per region
- IMDSv2 required (enforced)
- EBS encryption enabled

### SSL/TLS Security
- TLS 1.2 and 1.3 only
- Strong cipher suites (HIGH:!aNULL:!MD5)
- Server-preferred cipher order
- HTTP Strict Transport Security ready

### Health Checks
- Protocol: TCP (port 443)
- Interval: 30 seconds
- Threshold: 3 consecutive checks
- Client IP preservation enabled

## Cost Optimization

- **Global Accelerator**: ~$0.025/hour + data transfer fees (~$18/month fixed)
- **EC2 t3.micro**: ~$0.0104/hour per instance (~$15/month for 2)
- **Route 53**: Queries only (hosted zone managed separately)
- **Data Transfer**: Variable based on usage
- **Estimated monthly cost**: ~$35-40 for dev environment

## Monitoring & Observability

### CloudWatch Metrics
- EC2 instance metrics (CPU, network, disk)
- Global Accelerator flow logs
- VPC flow logs (enabled, 7-day retention)

### Health Monitoring
- Global Accelerator endpoint health status
- TCP connectivity checks every 30 seconds
- Automatic traffic routing to healthy endpoints only

## Troubleshooting

### Endpoints showing unhealthy
- Check if port 443 is listening: `nc -zv <instance-ip> 443`
- Verify nginx is running: `systemctl status nginx`
- Check nginx logs: `tail -f /var/log/nginx/error.log`
- Verify security groups allow port 443

### HTTPS not working
- Check SSL certificate: `openssl s_client -connect <instance-ip>:443`
- Verify nginx SSL configuration: `nginx -t`
- Check if certificate files exist: `ls -la /etc/nginx/ssl/`

### HTTP not redirecting to HTTPS
- Test redirect: `curl -I http://<instance-ip>`
- Check nginx configuration for redirect rule
- Verify port 80 is open in security group

### DNS not resolving
- Verify Route 53 record points to Global Accelerator
- Check hosted zone ID is correct (Z3LLP0B81D4CRA)
- Wait for DNS propagation (up to 48 hours)

## Files

- `main.tf` - Multi-region infrastructure with Global Accelerator
- `variables.tf` - Configuration variables
- `outputs.tf` - Infrastructure outputs
- `dev.tfvars` - Dev environment configuration
- `backend.tf` - S3 state backend
- `user_data.sh` - Nginx + SSL installation script
- `README.md` - This file
- `diagrams.md` - Architecture diagrams and service details

## CI/CD Pipeline

### GitHub Actions Workflow
- **Trigger**: Manual dispatch, PR, or push to master
- **Steps**: Init → Format → Validate → Trivy Scan → Plan → Apply/Destroy
- **Security**: OIDC authentication, no static credentials
- **Scanning**: Trivy for infrastructure security

### Security Scanning
- Trivy scans Terraform configurations
- Results uploaded to GitHub Security tab
- Soft fail mode (doesn't block deployment)

## High Availability

### Active-Active Configuration
- Both regions serve traffic simultaneously
- 50/50 traffic distribution
- No primary/secondary designation
- Geographic distribution for low latency

### Automatic Failover
- Health checks every 30 seconds
- Unhealthy endpoints removed automatically
- Traffic routed to healthy region only
- No manual intervention required

## Documentation

- See `diagrams.md` for detailed architecture diagrams
- See GitHub Actions workflow for CI/CD pipeline details
- See Terraform outputs for deployed resource information
