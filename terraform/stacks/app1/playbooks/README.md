# Ansible Playbooks for App1

This directory contains Ansible playbooks for configuring the app1 EC2 instance.

## Playbooks

### test-playbook.yml
Basic test playbook to verify Ansible installation and functionality.

**Usage:**
```bash
ansible-playbook playbooks/test-playbook.yml
```

**Tasks:**
- Prints test message
- Displays system information
- Creates test file at `/tmp/ansible-test.txt`

### install-nginx.yml
Installs and configures Nginx web server.

**Usage:**
```bash
ansible-playbook playbooks/install-nginx.yml
```

**Tasks:**
- Enables nginx repository via amazon-linux-extras
- Installs nginx package
- Starts and enables nginx service
- Creates custom index page

**Verification:**
```bash
curl http://localhost
```

## Running Playbooks on Instance

1. SSH to the instance:
```bash
ssh -i ~/.ssh/myapp-dev-key.pem ec2-user@<instance-ip>
```

2. Copy playbooks to instance (if needed):
```bash
scp -i ~/.ssh/myapp-dev-key.pem playbooks/*.yml ec2-user@<instance-ip>:~/
```

3. Run playbook:
```bash
ansible-playbook ~/install-nginx.yml
```
