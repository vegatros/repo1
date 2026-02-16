output "instance_ids" {
  description = "List of EC2 instance IDs"
  value       = aws_instance.this[*].id
}

output "instance_private_ips" {
  description = "List of private IP addresses"
  value       = aws_instance.this[*].private_ip
}

output "instance_public_ips" {
  description = "List of public IP addresses"
  value       = aws_instance.this[*].public_ip
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.ec2.id
}
