#!/bin/bash
exec > >(tee /var/log/user-data.log)
exec 2>&1
set -x

yum update -y
yum install -y nginx python3-pip

# Install certbot with Route53 plugin
pip3 install certbot certbot-nginx certbot-dns-route53

# Get instance metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

# Create custom index page
cat > /usr/share/nginx/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>App3 - Active-Active</title>
</head>
<body>
    <h1>App3 Active-Active Architecture</h1>
    <p>Region: $REGION</p>
    <p>Instance ID: $INSTANCE_ID</p>
    <p>Protocol: HTTPS (Let's Encrypt)</p>
</body>
</html>
EOF

# Start nginx with default config first
systemctl enable nginx
systemctl start nginx

# Wait for nginx to be ready
sleep 5

# Obtain Let's Encrypt certificate using Route53 DNS challenge
certbot --nginx \
    --non-interactive \
    --agree-tos \
    --email vegatros@gmail.com \
    --dns-route53 \
    --domains cloudconscious.io \
    --redirect

# Setup auto-renewal
echo "0 0,12 * * * root certbot renew --quiet" > /etc/cron.d/certbot-renew

# Restart nginx to apply certificate
systemctl restart nginx

# Verify
systemctl status nginx
netstat -tlnp | grep 443

