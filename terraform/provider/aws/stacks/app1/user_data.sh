#!/bin/bash
dnf update -y
dnf install -y nginx

cat > /usr/share/nginx/html/index.html <<'EOF'
<!DOCTYPE html>
<html><head><title>App1</title></head>
<body><h1>App1 - Connected</h1><p>Instance: $(hostname)</p></body>
</html>
EOF

systemctl start nginx
systemctl enable nginx
