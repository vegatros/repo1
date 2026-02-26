#!/bin/bash
set -e

# Update system
dnf update -y

# Create user cada5000
useradd -m -s /bin/bash cada5000
echo 'cada5000:REDACTED_PASSWORD' | chpasswd

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
JENKINS_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo "Not ready yet")

# Create info file
cat > /home/cada5000/jenkins-info.txt <<EOF
Jenkins Installation Complete
=============================
Jenkins URL: http://10.10.1.60:8080
Initial Admin Password: $JENKINS_PASSWORD

User: cada5000
Password: REDACTED_PASSWORD

To access Jenkins:
1. From your local machine: http://10.10.1.60:8080
2. Use the initial admin password above
3. Complete the setup wizard
EOF

chown cada5000:cada5000 /home/cada5000/jenkins-info.txt

# Enable password authentication for SSH
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
