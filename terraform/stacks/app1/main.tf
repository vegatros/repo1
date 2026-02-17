# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project_name             = var.project_name
  vpc_cidr                 = var.vpc_cidr
  enable_nat_gateway       = false
  enable_flow_logs         = false  # Disabled - requires IAM permissions

  tags = {
    Environment = var.environment
  }
}

# EC2 Module
module "ec2" {
  source = "../../modules/ec2"

  project_name   = var.project_name
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.public_subnet_ids
  instance_type  = var.instance_type
  instance_count = var.instance_count
  key_name       = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install ansible2 -y
              yum install -y git
              
              # Create playbooks directory
              mkdir -p /home/ec2-user/playbooks
              
              # Create nginx playbook
              cat > /home/ec2-user/playbooks/install-nginx.yml << 'PLAYBOOK'
              ---
              - name: Install and configure Nginx
                hosts: localhost
                connection: local
                become: yes
                tasks:
                  - name: Enable nginx in amazon-linux-extras
                    command: amazon-linux-extras enable nginx1
                    changed_when: false
                  
                  - name: Install nginx
                    yum:
                      name: nginx
                      state: present
                  
                  - name: Start nginx service
                    service:
                      name: nginx
                      state: started
                      enabled: yes
                  
                  - name: Create custom index page
                    copy:
                      content: |
                        <html>
                        <head><title>Ansible Nginx - ${var.project_name}</title></head>
                        <body>
                          <h1>Nginx installed via Ansible on ${var.environment}</h1>
                          <p>Deployed automatically during EC2 launch</p>
                        </body>
                        </html>
                      dest: /usr/share/nginx/html/index.html
                      mode: '0644'
              PLAYBOOK
              
              # Set ownership
              chown -R ec2-user:ec2-user /home/ec2-user/playbooks
              
              # Run nginx playbook
              su - ec2-user -c "ansible-playbook /home/ec2-user/playbooks/install-nginx.yml"
              
              echo "Ansible and Nginx setup complete" > /var/log/ansible-setup.log
              EOF

  tags = {
    Environment = var.environment
  }
}
