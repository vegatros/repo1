output "vpc1_id" {
  description = "VPC1 ID"
  value       = aws_vpc.vpc1.id
}

output "vpc2_id" {
  description = "VPC2 ID"
  value       = aws_vpc.vpc2.id
}

output "transit_gateway_id" {
  description = "Transit Gateway ID"
  value       = aws_ec2_transit_gateway.main.id
}

output "vpc1_instance_id" {
  description = "VPC1 Instance ID"
  value       = aws_instance.vpc1.id
}

output "vpc1_instance_private_ip" {
  description = "VPC1 Instance Private IP"
  value       = aws_instance.vpc1.private_ip
}

output "vpc1_instance_public_ip" {
  description = "VPC1 Instance Public IP"
  value       = aws_instance.vpc1.public_ip
}

output "vpc2_instance_id" {
  description = "VPC2 Instance ID"
  value       = aws_instance.vpc2.id
}

output "vpc2_instance_private_ip" {
  description = "VPC2 Instance Private IP"
  value       = aws_instance.vpc2.private_ip
}

output "vpc2_instance_public_ip" {
  description = "VPC2 Instance Public IP"
  value       = aws_instance.vpc2.public_ip
}

output "connectivity_test_command" {
  description = "Command to test connectivity from VPC1 to VPC2"
  value       = "aws ssm start-session --target ${aws_instance.vpc1.id} --document-name AWS-StartInteractiveCommand --parameters command='ping -c 4 ${aws_instance.vpc2.private_ip}'"
}
