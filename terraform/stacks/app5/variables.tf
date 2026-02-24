variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "app5-bedrock"
}

variable "agent_name" {
  description = "Name of the Bedrock agent"
  type        = string
  default     = "app5-bedrock-agent"
}

variable "agent_instruction" {
  description = "Instructions for the Bedrock agent"
  type        = string
  default     = "You are a helpful AI assistant that provides accurate and concise responses."
}
