#!/bin/bash
yum update -y
yum install -y nginx certbot python3-certbot-nginx

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
    <p>Protocol: HTTPS</p>
</body>
</html>
EOF

# Configure nginx for SSL
cat > /etc/nginx/conf.d/ssl.conf <<'NGINX_EOF'
server {
    listen 80;
    server_name cloudconscious.io www.cloudconscious.io;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name cloudconscious.io www.cloudconscious.io;

    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
NGINX_EOF

# Create self-signed certificate (temporary until Let's Encrypt can be configured)
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/key.pem \
    -out /etc/nginx/ssl/cert.pem \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=cloudconscious.io"

systemctl start nginx
systemctl enable nginx

