# App8 - Site-to-Site VPN

AWS Site-to-Site VPN connection from your local Linux machine to AWS VPC.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS VPC (10.10.0.0/16)                  │
│                                                                 │
│  ┌──────────────────┐              ┌──────────────────┐        │
│  │  Public Subnets  │              │ Private Subnets  │        │
│  │  10.10.101.0/24  │              │  10.10.1.0/24    │        │
│  │  10.10.102.0/24  │              │  10.10.2.0/24    │        │
│  │                  │              │                  │        │
│  │  ┌────────────┐  │              │  ┌────────────┐  │        │
│  │  │ NAT Gateway│  │              │  │ Test EC2   │  │        │
│  │  └────────────┘  │              │  │ Instance   │  │        │
│  └──────────────────┘              └──────────────────┘        │
│           │                                  ▲                  │
│           │                                  │                  │
│  ┌────────▼──────────┐              ┌───────┴────────┐         │
│  │ Internet Gateway  │              │ Virtual Private│         │
│  └───────────────────┘              │    Gateway     │         │
└─────────────────────────────────────┴────────┬───────┴─────────┘
                                               │
                                               │ IPsec Tunnels
                                               │ (2 tunnels)
                                               │
                                      ┌────────▼────────┐
                                      │ Customer Gateway│
                                      │  68.74.135.188  │
                                      └────────┬────────┘
                                               │
                                      ┌────────▼────────┐
                                      │  Your Local     │
                                      │  Linux Machine  │
                                      │ 192.168.1.0/24  │
                                      └─────────────────┘
```

## Infrastructure Components

- **VPC**: 10.10.0.0/16 in us-east-1
- **Private Subnets**: 10.10.1.0/24, 10.10.2.0/24
- **Public Subnets**: 10.10.101.0/24, 10.10.102.0/24
- **Virtual Private Gateway**: Attached to VPC
- **Customer Gateway**: Your public IP (68.74.135.188)
- **VPN Connection**: 2 IPsec tunnels for redundancy
- **Test EC2 Instance**: In private subnet for connectivity testing

## Prerequisites

- Linux machine with root/sudo access
- strongSwan or Libreswan installed
- Your public IP: 68.74.135.188
- Local network: 192.168.1.0/24

## Deployment

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="vars/dev.tfvars"

# Deploy infrastructure
terraform apply -var-file="vars/dev.tfvars"

# Download VPN configuration
aws ec2 describe-vpn-connections \
  --vpn-connection-ids $(terraform output -raw vpn_connection_id) \
  --query 'VpnConnections[0].CustomerGatewayConfiguration' \
  --output text > vpn-config.xml
```

## VPN Configuration on Linux

### Option 1: strongSwan (Recommended)

1. **Install strongSwan**:
```bash
sudo apt-get update
sudo apt-get install strongswan strongswan-pki libstrongswan-extra-plugins
```

2. **Configure IPsec** (`/etc/ipsec.conf`):
```bash
config setup
    charondebug="ike 2, knl 2, cfg 2, net 2, esp 2, dmn 2, mgr 2"

conn aws-tunnel1
    type=tunnel
    auto=start
    keyexchange=ikev1
    authby=secret
    left=%defaultroute
    leftid=68.74.135.188
    right=34.199.146.50
    rightsubnet=10.10.0.0/16
    ike=aes128-sha1-modp1024!
    esp=aes128-sha1-modp1024!
    keyingtries=%forever
    dpddelay=10
    dpdtimeout=30
    dpdaction=restart

conn aws-tunnel2
    type=tunnel
    auto=start
    keyexchange=ikev1
    authby=secret
    left=%defaultroute
    leftid=68.74.135.188
    right=34.224.187.194
    rightsubnet=10.10.0.0/16
    ike=aes128-sha1-modp1024!
    esp=aes128-sha1-modp1024!
    keyingtries=%forever
    dpddelay=10
    dpdtimeout=30
    dpdaction=restart
```

3. **Configure Secrets** (`/etc/ipsec.secrets`):
```bash
# Get pre-shared keys from Terraform output
terraform output vpn_config

# Add to /etc/ipsec.secrets:
68.74.135.188 34.199.146.50 : PSK "ImbBSSceoNDiWnq6394sa..Lt8BNA8Vn"
68.74.135.188 34.224.187.194 : PSK "bEIUXZRZaj1D7DXtTNwwmrE63.73tg7U"
```

4. **Enable IP Forwarding**:
```bash
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
```

5. **Start VPN**:
```bash
sudo ipsec restart
sudo ipsec status
```

### Option 2: Libreswan

1. **Install Libreswan**:
```bash
sudo apt-get update
sudo apt-get install libreswan
```

2. **Configure** (`/etc/ipsec.d/aws-tunnel1.conf`):
```bash
conn aws-tunnel1
    type=tunnel
    authby=secret
    left=%defaultroute
    leftid=68.74.135.188
    right=34.199.146.50
    rightsubnet=10.10.0.0/16
    ike=aes128-sha1;modp1024
    phase2alg=aes128-sha1;modp1024
    auto=start
```

3. **Add secrets** (`/etc/ipsec.d/aws.secrets`):
```bash
68.74.135.188 34.199.146.50: PSK "ImbBSSceoNDiWnq6394sa..Lt8BNA8Vn"
```

4. **Start VPN**:
```bash
sudo systemctl restart ipsec
sudo ipsec status
```

## Testing Connectivity

1. **Check VPN tunnel status**:
```bash
sudo ipsec status
```

2. **Ping test EC2 instance**:
```bash
# Get instance private IP
terraform output test_instance_private_ip

# Ping from your local machine
ping 10.10.1.60
```

3. **SSH to test instance** (via SSM):
```bash
aws ssm start-session --target i-0243005322e5550ec
```

## Troubleshooting

### Tunnel not connecting

1. **Check firewall rules**:
```bash
# Allow UDP 500 and 4500 for IPsec
sudo ufw allow 500/udp
sudo ufw allow 4500/udp
```

2. **Verify your public IP hasn't changed**:
```bash
curl -4 ifconfig.me
# Should be: 68.74.135.188
```

3. **Check strongSwan logs**:
```bash
sudo journalctl -u strongswan -f
```

4. **Verify AWS tunnel status**:
```bash
aws ec2 describe-vpn-connections \
  --vpn-connection-ids $(terraform output -raw vpn_connection_id) \
  --query 'VpnConnections[0].VgwTelemetry'
```

### Can't ping EC2 instance

1. **Verify security group allows ICMP**:
```bash
terraform show | grep -A 10 "test_instance_sg"
```

2. **Check route propagation**:
```bash
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"
```

3. **Verify EC2 instance is running**:
```bash
aws ec2 describe-instances \
  --instance-ids i-0243005322e5550ec \
  --query 'Reservations[0].Instances[0].State.Name'
```

## Outputs

```bash
# VPC ID
terraform output vpc_id

# VPN Connection ID
terraform output vpn_connection_id

# Customer Gateway ID
terraform output customer_gateway_id

# Virtual Private Gateway ID
terraform output vpn_gateway_id

# Test instance private IP
terraform output test_instance_private_ip

# VPN tunnel configuration (sensitive)
terraform output vpn_config
```

## Cost Considerations

- **VPN Connection**: ~$0.05/hour (~$36/month)
- **NAT Gateway**: ~$0.045/hour + data transfer (~$32/month)
- **EC2 t2.micro**: Free tier eligible or ~$8.50/month
- **Data Transfer**: $0.09/GB outbound

**Estimated monthly cost**: ~$76/month

## Cleanup

```bash
terraform destroy -var-file="vars/dev.tfvars"
```

## Security Features

- IPsec encryption with AES-128 and SHA-1
- Pre-shared key authentication
- Dead Peer Detection (DPD) for tunnel monitoring
- VPC Flow Logs with KMS encryption
- Private subnet isolation
- SSM access (no SSH keys required)

## Notes

- Two tunnels provide redundancy (active/passive)
- Static routing configured for 192.168.1.0/24
- BGP ASN 65000 used for Customer Gateway
- VPN route propagation enabled on private route table
- Test instance has SSM agent for remote access
