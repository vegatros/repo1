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
  subnet_ids     = module.vpc.private_subnet_ids
  instance_type  = var.instance_type
  instance_count = var.instance_count

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>${var.project_name} - ${var.environment}</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Environment = var.environment
  }
}
