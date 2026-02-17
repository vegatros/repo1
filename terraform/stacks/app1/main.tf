# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project_name             = var.project_name
  vpc_cidr                 = var.vpc_cidr
  enable_nat_gateway       = true
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
  subnet_ids     = module.vpc.private_subnet_ids
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

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-alb-sg"
    Environment = var.environment
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnet_ids

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
  }
}

# Target Group
resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.project_name}-tg"
    Environment = var.environment
  }
}

# Target Group Attachment
resource "aws_lb_target_group_attachment" "main" {
  count            = var.instance_count
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = module.ec2.instance_ids[count.index]
  port             = 80
}

# ALB Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
