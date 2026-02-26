# Site-to-Site VPN - Setup Complete

## Status: ✅ OPERATIONAL

### Deployment Summary
- **Deployment Date**: 2026-02-26
- **VPN Connection ID**: vpn-0515f72664ffbc052
- **VPC ID**: vpc-0c395a0db1cc6ea8a
- **VPC CIDR**: 10.10.0.0/16

### Tunnel Status
- **Tunnel 1**: ✅ UP (34.199.146.50)
- **Tunnel 2**: ⚠️  DOWN (34.224.187.194) - Standby

### Local Configuration
- **Public IP**: 68.74.135.188
- **Local Network**: 192.168.1.0/24
- **VPN Software**: strongSwan 5.9.5
- **Configuration**: /etc/ipsec.conf
- **Secrets**: /etc/ipsec.secrets

### Test Results
```
✅ VPN Tunnel Established
✅ AWS Reports Tunnel UP
✅ Ping to EC2 Instance (10.10.1.60): SUCCESS
   - 4 packets transmitted, 4 received, 0% packet loss
   - Average latency: ~29.6ms
```

### Connectivity Test
```bash
$ ping -c 4 10.10.1.60
PING 10.10.1.60 (10.10.1.60) 56(84) bytes of data.
64 bytes from 10.10.1.60: icmp_seq=1 ttl=127 time=29.4 ms
64 bytes from 10.10.1.60: icmp_seq=2 ttl=127 time=29.5 ms
64 bytes from 10.10.1.60: icmp_seq=3 ttl=127 time=29.5 ms
64 bytes from 10.10.1.60: icmp_seq=4 ttl=127 time=30.2 ms

--- 10.10.1.60 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3003ms
```

## Quick Commands

### Check VPN Status
```bash
sudo ipsec status
```

### Restart VPN
```bash
sudo ipsec restart
```

### View Logs
```bash
sudo journalctl -u strongswan-starter -f
```

### Check AWS Tunnel Status
```bash
aws ec2 describe-vpn-connections \
  --vpn-connection-ids vpn-0515f72664ffbc052 \
  --query 'VpnConnections[0].VgwTelemetry' \
  --region us-east-1
```

### Test Connectivity
```bash
ping 10.10.1.60
```

### Access EC2 via SSM
```bash
aws ssm start-session --target i-0243005322e5550ec --region us-east-1
```

## Configuration Files

### /etc/ipsec.conf
```
config setup
    charondebug="ike 2, knl 2, cfg 2, net 2, esp 2, dmn 2, mgr 2"

conn aws-tunnel1
    type=tunnel
    auto=start
    keyexchange=ikev1
    authby=secret
    left=%defaultroute
    leftid=68.74.135.188
    leftsubnet=192.168.1.0/24
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
    leftsubnet=192.168.1.0/24
    right=34.224.187.194
    rightsubnet=10.10.0.0/16
    ike=aes128-sha1-modp1024!
    esp=aes128-sha1-modp1024!
    keyingtries=%forever
    dpddelay=10
    dpdtimeout=30
    dpdaction=restart
```

### /etc/ipsec.secrets
```
68.74.135.188 34.199.146.50 : PSK "ImbBSSceoNDiWnq6394sa..Lt8BNA8Vn"
68.74.135.188 34.224.187.194 : PSK "bEIUXZRZaj1D7DXtTNwwmrE63.73tg7U"
```

## Network Topology

```
Local Network (192.168.1.0/24)
        │
        │ Your Machine: 192.168.1.214
        │
        ▼
   [strongSwan]
        │
        │ IPsec Tunnel (Encrypted)
        │
        ▼
   [AWS VPN Gateway]
        │
        ▼
   AWS VPC (10.10.0.0/16)
        │
        ├─ Private Subnet 1 (10.10.1.0/24)
        │  └─ Test EC2: 10.10.1.60 ✅
        │
        └─ Private Subnet 2 (10.10.2.0/24)
```

## Security Features
- ✅ IPsec encryption (AES-128, SHA-1)
- ✅ Pre-shared key authentication
- ✅ Dead Peer Detection (DPD)
- ✅ Automatic tunnel restart
- ✅ Firewall rules configured (UDP 500, 4500)
- ✅ IP forwarding enabled

## Cost Estimate
- VPN Connection: ~$36/month
- NAT Gateway: ~$32/month
- EC2 t2.micro: ~$8.50/month
- **Total**: ~$76/month

## Troubleshooting

### If tunnel goes down:
```bash
sudo ipsec restart
sleep 10
sudo ipsec status
```

### If public IP changes:
1. Update Customer Gateway in AWS
2. Update /etc/ipsec.conf and /etc/ipsec.secrets
3. Restart IPsec

### View detailed logs:
```bash
sudo tail -f /var/log/syslog | grep charon
```

## Next Steps
- ✅ VPN configured and tested
- ✅ Connectivity verified
- ⚠️  Consider enabling tunnel 2 for redundancy
- 📝 Document any additional resources you deploy in the VPC
- 💰 Monitor costs in AWS Cost Explorer

## Cleanup
When you're done testing:
```bash
cd /home/cadat/Documents/repo2/repo1/terraform/stacks/builds/app8
terraform destroy -var-file="vars/dev.tfvars"
```

---
**Last Updated**: 2026-02-26 13:30 EST
**Status**: Operational
