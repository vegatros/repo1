# App3 Architecture Diagrams

## Network Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet Users                          │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ DNS Query
                             ▼
                    ┌────────────────┐
                    │   Route 53     │
                    │ cloudconscious │
                    │      .io       │
                    └────────┬───────┘
                             │ A Record (Alias)
                             ▼
                ┌────────────────────────┐
                │  AWS Global Accelerator│
                │  Static Anycast IPs    │
                │  - IP 1: x.x.x.x       │
                │  - IP 2: x.x.x.x       │
                └────┬──────────────┬────┘
                     │              │
          50% Traffic│              │50% Traffic
                     │              │
        ┌────────────▼──────┐  ┌───▼────────────┐
        │  Endpoint Group   │  │ Endpoint Group │
        │    us-west-2      │  │   us-east-1    │
        │  Health: HTTP/80  │  │ Health: HTTP/80│
        └────────┬──────────┘  └───┬────────────┘
                 │                 │
                 │                 │
    ┌────────────▼──────────┐  ┌──▼─────────────────┐
    │   VPC us-west-2       │  │   VPC us-east-1    │
    │   10.3.0.0/16         │  │   10.4.0.0/16      │
    │                       │  │                    │
    │  ┌─────────────────┐  │  │  ┌──────────────┐ │
    │  │ Public Subnet   │  │  │  │Public Subnet │ │
    │  │ 10.3.1.0/24     │  │  │  │10.4.1.0/24   │ │
    │  │                 │  │  │  │              │ │
    │  │ ┌─────────────┐ │  │  │  │┌────────────┐│ │
    │  │ │   EC2       │ │  │  │  ││   EC2      ││ │
    │  │ │ Amazon Linux│ │  │  │  ││Amazon Linux││ │
    │  │ │   + Nginx   │ │  │  │  ││  + Nginx   ││ │
    │  │ │  t3.micro   │ │  │  │  ││ t3.micro   ││ │
    │  │ │ Port 80/443 │ │  │  │  ││Port 80/443 ││ │
    │  │ └─────────────┘ │  │  │  │└────────────┘│ │
    │  └─────────────────┘  │  │  └──────────────┘ │
    │                       │  │                    │
    │  Internet Gateway     │  │  Internet Gateway  │
    └───────────────────────┘  └────────────────────┘
```

## Traffic Flow Diagram

```
User Request
     │
     ▼
Route 53 DNS Resolution
     │
     ▼
Global Accelerator (Anycast IP)
     │
     ├─────────────────┬─────────────────┐
     │                 │                 │
     ▼                 ▼                 ▼
Health Check      us-west-2         us-east-1
HTTP/80 /         Endpoint          Endpoint
Every 30s         (50% traffic)     (50% traffic)
     │                 │                 │
     ▼                 ▼                 ▼
  Pass/Fail       EC2 Instance      EC2 Instance
                  Nginx:80          Nginx:80
                       │                 │
                       ▼                 ▼
                  HTML Response     HTML Response
                  (Region Info)     (Region Info)
```

## Service Details

### Global Accelerator
- **Type**: Standard Accelerator
- **IP Address Type**: IPv4
- **Static IPs**: 2 Anycast IPs
- **Listener**: TCP Port 80
- **Endpoint Groups**: 2 (us-west-2, us-east-1)
- **Traffic Distribution**: 50/50 active-active
- **Client IP Preservation**: Enabled

### Endpoint Groups

#### us-west-2 Endpoint Group
- **Region**: us-west-2
- **Traffic Dial**: 50%
- **Endpoint Type**: EC2 Instance
- **Health Check Protocol**: HTTP
- **Health Check Port**: 80
- **Health Check Path**: /
- **Health Check Interval**: 30 seconds

#### us-east-1 Endpoint Group
- **Region**: us-east-1
- **Traffic Dial**: 50%
- **Endpoint Type**: EC2 Instance
- **Health Check Protocol**: HTTP
- **Health Check Port**: 80
- **Health Check Path**: /
- **Health Check Interval**: 30 seconds

### VPC Configuration

#### us-west-2 VPC
- **CIDR**: 10.3.0.0/16
- **Public Subnet**: 10.3.1.0/24 (us-west-2a)
- **Internet Gateway**: Yes
- **NAT Gateway**: No
- **Private Subnets**: No

#### us-east-1 VPC
- **CIDR**: 10.4.0.0/16
- **Public Subnet**: 10.4.1.0/24 (us-east-1a)
- **Internet Gateway**: Yes
- **NAT Gateway**: No
- **Private Subnets**: No

### EC2 Instances

#### us-west-2 Instance
- **AMI**: Amazon Linux 2023 (ami-075b5421f670d735c)
- **Instance Type**: t3.micro
- **Subnet**: Public (10.3.1.0/24)
- **Public IP**: Auto-assigned
- **Security Group**: 
  - Inbound: HTTP (80), HTTPS (443)
  - Outbound: All traffic
- **Software**: Nginx web server
- **User Data**: Automated nginx installation and configuration
- **IMDSv2**: Required (enforced)
- **EBS Encryption**: Enabled

#### us-east-1 Instance
- **AMI**: Amazon Linux 2023 (ami-0f3caa1cf4417e51b)
- **Instance Type**: t3.micro
- **Subnet**: Public (10.4.1.0/24)
- **Public IP**: Auto-assigned
- **Security Group**: 
  - Inbound: HTTP (80), HTTPS (443)
  - Outbound: All traffic
- **Software**: Nginx web server
- **User Data**: Automated nginx installation and configuration
- **IMDSv2**: Required (enforced)
- **EBS Encryption**: Enabled

### Route 53
- **Hosted Zone**: cloudconscious.io (Z3LLP0B81D4CRA)
- **Record Type**: A (Alias)
- **Target**: Global Accelerator DNS name
- **Evaluate Target Health**: Enabled

## Security Groups

### EC2 Security Group (Both Regions)
```
Inbound Rules:
┌──────────┬──────┬─────────────┬─────────────────────┐
│ Protocol │ Port │ Source      │ Description         │
├──────────┼──────┼─────────────┼─────────────────────┤
│ TCP      │ 80   │ 0.0.0.0/0   │ HTTP from internet  │
│ TCP      │ 443  │ 0.0.0.0/0   │ HTTPS from internet │
└──────────┴──────┴─────────────┴─────────────────────┘

Outbound Rules:
┌──────────┬──────┬─────────────┬─────────────────────┐
│ Protocol │ Port │ Destination │ Description         │
├──────────┼──────┼─────────────┼─────────────────────┤
│ All      │ All  │ 0.0.0.0/0   │ All traffic         │
└──────────┴──────┴─────────────┴─────────────────────┘
```

## High Availability Features

### Active-Active Configuration
- Both regions serve traffic simultaneously
- 50/50 traffic distribution
- No primary/secondary designation
- Both endpoints must be healthy

### Automatic Failover
- Health checks every 30 seconds
- Unhealthy endpoints removed from rotation
- Traffic automatically routed to healthy region
- No manual intervention required

### Geographic Distribution
- us-west-2: West Coast US
- us-east-1: East Coast US
- Reduced latency for users across US
- Global Accelerator routes to nearest healthy endpoint

## Monitoring & Observability

### CloudWatch Metrics
- EC2 instance metrics (CPU, network, disk)
- Global Accelerator flow logs
- VPC flow logs (enabled)

### Health Checks
- Protocol: HTTP
- Port: 80
- Path: /
- Interval: 30 seconds
- Timeout: 10 seconds
- Healthy threshold: 3 consecutive successes
- Unhealthy threshold: 3 consecutive failures

## Cost Breakdown (Estimated Monthly - Dev Environment)

| Service | Cost |
|---------|------|
| EC2 t3.micro (2 instances) | ~$15 |
| Global Accelerator | ~$18 (fixed) + data transfer |
| Route 53 (queries) | ~$1 |
| Data Transfer | Variable |
| **Total** | **~$35-40/month** |

## Deployment Information

- **Terraform Version**: >= 1.0
- **AWS Provider Version**: ~> 5.0
- **State Backend**: S3 (terraform-state-925185632967)
- **State Lock**: DynamoDB (terraform-state-lock)
- **CI/CD**: GitHub Actions
- **Security Scanning**: Trivy
