aws_region           = "us-east-1"
environment          = "dev"
project_name         = "app8-site-to-site-vpn"
vpc_cidr             = "10.10.0.0/16"
azs                  = ["us-east-1a", "us-east-1b"]
private_subnet_cidrs = ["10.10.1.0/24", "10.10.2.0/24"]
public_subnet_cidrs  = ["10.10.101.0/24", "10.10.102.0/24"]
customer_gateway_ip  = "68.74.135.188"
on_premise_cidr      = "192.168.1.0/24"

# Credentials (stored in AWS Secrets Manager)
linux_password   = "REDACTED_PASSWORD"
jenkins_username = "cada5000"
jenkins_password = "REDACTED_PASSWORD"
