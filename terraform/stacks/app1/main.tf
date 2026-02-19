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
              EOF

  tags = {
    Environment = var.environment
  }
}

# Elastic IP
resource "aws_eip" "web" {
  instance = module.ec2.instance_ids[0]
  domain   = "vpc"

  tags = {
    Name        = "${var.project_name}-eip"
    Environment = var.environment
  }
}

# # ALB Security Group
# resource "aws_security_group" "alb" {
#   name        = "${var.project_name}-alb-sg"
#   description = "Security group for ALB"
#   vpc_id      = module.vpc.vpc_id

#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#     description = "HTTP from internet"
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name        = "${var.project_name}-alb-sg"
#     Environment = var.environment
#   }
# }

# # Application Load Balancer
# resource "aws_lb" "main" {
#   name               = "${var.project_name}-alb"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.alb.id]
#   subnets            = module.vpc.public_subnet_ids

#   tags = {
#     Name        = "${var.project_name}-alb"
#     Environment = var.environment
#   }
# }

# # Target Group
# resource "aws_lb_target_group" "main" {
#   name     = "${var.project_name}-tg"
#   port     = 80
#   protocol = "HTTP"
#   vpc_id   = module.vpc.vpc_id

#   health_check {
#     enabled             = true
#     healthy_threshold   = 2
#     interval            = 30
#     matcher             = "200"
#     path                = "/"
#     port                = "traffic-port"
#     protocol            = "HTTP"
#     timeout             = 5
#     unhealthy_threshold = 2
#   }

#   tags = {
#     Name        = "${var.project_name}-tg"
#     Environment = var.environment
#   }
# }

# # Target Group Attachment
# resource "aws_lb_target_group_attachment" "main" {
#   count            = var.instance_count
#   target_group_arn = aws_lb_target_group.main.arn
#   target_id        = module.ec2.instance_ids[count.index]
#   port             = 80
# }

# # ALB Listener
# resource "aws_lb_listener" "main" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = "80"
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.main.arn
#   }
# }
