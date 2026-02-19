output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "instance_ids" {
  description = "EC2 instance IDs"
  value       = module.ec2.instance_ids
}

output "instance_private_ips" {
  description = "EC2 private IPs"
  value       = module.ec2.instance_private_ips
}

output "instance_public_ips" {
  description = "EC2 public IPs"
  value       = module.ec2.instance_public_ips
}

output "nginx_url" {
  description = "Nginx web server URL"
  value       = length(module.ec2.instance_public_ips) > 0 ? "https://${module.ec2.instance_public_ips[0]}" : "No public IP"
}

# output "alb_dns_name" {
#   description = "Application Load Balancer DNS name"
#   value       = aws_lb.main.dns_name
# }
