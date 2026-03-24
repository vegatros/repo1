#!/bin/bash
set -e

# Update system
dnf update -y

# Install AWS CLI and jq
dnf install -y aws-cli jq

# Get credentials from Secrets Manager
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id ${secret_name} --region ${region} --query SecretString --output text)
LINUX_PASSWORD=$(echo $SECRET_JSON | jq -r '.linux_password')
JENKINS_PASSWORD=$(echo $SECRET_JSON | jq -r '.jenkins_password')

# Create user cada5000
useradd -m -s /bin/bash cada5000
echo "cada5000:$LINUX_PASSWORD" | chpasswd

# Add user to sudoers
echo 'cada5000 ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/cada5000
chmod 440 /etc/sudoers.d/cada5000

# Install Java and wget (required for Jenkins)
dnf install -y java-17-openjdk java-17-openjdk-devel wget

# Add Jenkins repository
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Install Jenkins
dnf install -y jenkins

# Start and enable Jenkins
systemctl enable jenkins
systemctl start jenkins

# Wait for Jenkins to start
sleep 30

# Get initial admin password
JENKINS_INITIAL_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "Not ready yet")

# Create info file
cat > /home/cada5000/jenkins-info.txt <<EOF
Jenkins Installation Complete
=============================
Jenkins URL: http://$(hostname -I | awk '{print $1}'):8080
Initial Admin Password: $JENKINS_INITIAL_PASSWORD

User: cada5000
Password: Retrieved from AWS Secrets Manager

To access Jenkins:
1. From your local machine: http://$(hostname -I | awk '{print $1}'):8080
2. Use the initial admin password above
3. Complete the setup wizard
4. Create admin user with credentials from Secrets Manager
EOF

chown cada5000:cada5000 /home/cada5000/jenkins-info.txt

# Enable password authentication for SSH
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
