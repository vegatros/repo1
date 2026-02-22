#!/bin/bash
dnf update -y
dnf install -y nginx git

# Download cloudconscious HTML as home page
curl -o /usr/share/nginx/html/index.html \
  https://raw.githubusercontent.com/vegatros/q/master/terraform/stacks/app1/html/cloudconscious.html

# Download resume page
curl -o /usr/share/nginx/html/resume.html \
  https://raw.githubusercontent.com/vegatros/q/master/terraform/stacks/app1/html/resume.html

# Start and enable nginx
systemctl start nginx
systemctl enable nginx

echo "Nginx configured with cloudconscious home page" > /var/log/nginx-setup.log
