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
