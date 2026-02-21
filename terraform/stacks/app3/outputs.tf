output "global_accelerator_dns" {
  description = "Global Accelerator DNS name"
  value       = aws_globalaccelerator_accelerator.main.dns_name
}

output "global_accelerator_ips" {
  description = "Global Accelerator static IPs"
  value       = aws_globalaccelerator_accelerator.main.ip_sets[0].ip_addresses
}

output "route53_nameservers" {
  description = "Route 53 nameservers for domain delegation"
  value       = aws_route53_zone.main.name_servers
}

output "domain_name" {
  description = "Configured domain name"
  value       = var.domain_name
}

output "ec2_west_public_ip" {
  description = "EC2 public IP in us-west-2"
  value       = module.ec2_west.instance_public_ips[0]
}

output "ec2_east_public_ip" {
  description = "EC2 public IP in us-east-1"
  value       = module.ec2_east.instance_public_ips[0]
}
