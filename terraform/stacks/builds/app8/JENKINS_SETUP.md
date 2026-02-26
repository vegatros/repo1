# Jenkins on Red Hat - Deployment Complete

## ✅ Infrastructure Deployed

### Server Details
- **OS**: Red Hat Enterprise Linux 9
- **Instance Type**: t3.medium
- **Private IP**: 10.10.1.15
- **Instance ID**: i-0e60bf85c35a2e7e3

### Jenkins Dashboard
🌐 **URL**: http://10.10.1.15:8080

### User Credentials
- **Username**: cada5000
- **Password**: REDACTED_PASSWORD
- **SSH Command**: `ssh cada5000@10.10.1.15`

## Installation Status

Jenkins is being installed automatically via user data script. The installation includes:

1. ✅ Red Hat system updates
2. ✅ User `cada5000` created with sudo access
3. ⏳ Java 17 OpenJDK installation
4. ⏳ Jenkins installation from official repository
5. ⏳ Jenkins service startup

**Note**: Jenkins installation takes 3-5 minutes after instance launch.

## Accessing Jenkins

### Step 1: Wait for Installation
The instance is running and accessible, but Jenkins needs a few more minutes to complete installation.

Test Jenkins availability:
```bash
curl -I http://10.10.1.15:8080
```

When you see HTTP 200 or 403, Jenkins is ready.

### Step 2: Get Initial Admin Password

Option A - Via SSH:
```bash
ssh cada5000@10.10.1.15
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Option B - Check the info file:
```bash
ssh cada5000@10.10.1.15
cat ~/jenkins-info.txt
```

### Step 3: Access Dashboard

1. Open browser: http://10.10.1.15:8080
2. Enter the initial admin password
3. Click "Install suggested plugins"
4. Create your admin user
5. Start using Jenkins!

## Testing Connectivity

```bash
# Test ping
ping 10.10.1.15

# Test Jenkins port
curl http://10.10.1.15:8080

# Test SSH
ssh cada5000@10.10.1.15
```

## Quick Test Script

Run this to check status:
```bash
/tmp/test-jenkins.sh
```

Or manually:
```bash
# Check if Jenkins is responding
curl -s -o /dev/null -w "%{http_code}\n" http://10.10.1.15:8080

# Expected responses:
# 000 = Not ready yet (still installing)
# 403 = Jenkins is up (setup wizard)
# 200 = Jenkins is up and configured
```

## VPN Connection

Your Site-to-Site VPN is active:
- ✅ Tunnel 1: UP (34.199.146.50)
- ✅ Tunnel 2: UP (34.224.187.194)

Check VPN status:
```bash
sudo ipsec status
```

## Security Configuration

### Firewall Rules
- Port 22 (SSH): Open from 192.168.1.0/24
- Port 8080 (Jenkins): Open from 192.168.1.0/24
- ICMP: Allowed from 192.168.1.0/24

### User Access
- User `cada5000` has sudo privileges
- Password authentication enabled for SSH
- SSM Session Manager available

## Troubleshooting

### Jenkins not responding?
```bash
# SSH to server
ssh cada5000@10.10.1.15

# Check Jenkins status
sudo systemctl status jenkins

# View Jenkins logs
sudo journalctl -u jenkins -f

# Restart Jenkins if needed
sudo systemctl restart jenkins
```

### Can't SSH?
Wait 5-10 minutes for user data script to complete. The script:
1. Creates the user
2. Installs software
3. Configures SSH
4. Starts Jenkins

### Check installation progress:
```bash
# Via AWS Console: EC2 > Instance > Actions > Monitor and troubleshoot > Get system log
# Or wait for SSM agent to connect, then:
aws ssm start-session --target i-0e60bf85c35a2e7e3 --region us-east-1
```

## What's Installed

- Red Hat Enterprise Linux 9
- Java 17 OpenJDK
- Jenkins (latest stable)
- SSM Agent (for AWS Systems Manager)

## Cost Estimate

- EC2 t3.medium: ~$30/month
- VPN Connection: ~$36/month
- NAT Gateway: ~$32/month
- **Total**: ~$98/month

## Next Steps

1. ⏳ Wait 3-5 minutes for Jenkins to finish installing
2. 🌐 Access http://10.10.1.15:8080 in your browser
3. 🔑 Get initial admin password via SSH
4. 🚀 Complete Jenkins setup wizard
5. 📦 Install plugins and configure jobs

## Terraform Outputs

```bash
cd /home/cadat/Documents/repo2/repo1/terraform/stacks/builds/app8

# Get all outputs
terraform output

# Get Jenkins URL
terraform output jenkins_url

# Get SSH command
terraform output ssh_command

# Get credentials
terraform output jenkins_credentials
```

## Cleanup

When done testing:
```bash
cd /home/cadat/Documents/repo2/repo1/terraform/stacks/builds/app8
terraform destroy -var-file="vars/dev.tfvars"
```

---
**Deployment Time**: 2026-02-26 13:36 EST
**Status**: Installation in progress (3-5 minutes remaining)
**Jenkins URL**: http://10.10.1.15:8080
