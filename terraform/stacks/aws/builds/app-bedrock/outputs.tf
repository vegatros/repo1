output "bedrock_agent_role_arn" {
  description = "ARN of the Bedrock agent role"
  value       = module.bedrock.bedrock_agent_role_arn
}

output "bedrock_agent_id" {
  description = "ID of the Bedrock agent"
  value       = module.bedrock.bedrock_agent_id
}

output "bedrock_agent_alias_id" {
  description = "ID of the Bedrock agent alias"
  value       = module.bedrock.bedrock_agent_alias_id
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "ec2_instance_id" {
  description = "EC2 instance ID (use SSM Session Manager to connect)"
  value       = aws_instance.bedrock_client.id
}

output "ec2_private_ip" {
  description = "EC2 instance private IP"
  value       = aws_instance.bedrock_client.private_ip
}
