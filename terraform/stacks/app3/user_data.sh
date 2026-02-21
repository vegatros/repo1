#!/bin/bash
set -e

yum update -y
yum install -y nginx

# Get instance metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

# Create self-signed certificate
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/key.pem \
    -out /etc/nginx/ssl/cert.pem \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=cloudconscious.io"

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
    <p>Protocol: HTTPS</p>
</body>
</html>
EOF

# Add SSL server block
cat > /etc/nginx/conf.d/ssl.conf <<'EOF'
server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    server_name _;
    root /usr/share/nginx/html;

    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        index index.html;
    }
}
EOF

# Modify default HTTP server to redirect to HTTPS
sed -i 's/listen       80;/listen       80;\n    return 301 https:\/\/$host$request_uri;/' /etc/nginx/nginx.conf

systemctl start nginx
systemctl enable nginx

