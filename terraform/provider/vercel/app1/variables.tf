variable "vercel_api_token" {
  description = "Vercel API token"
  type        = string
  sensitive   = true
}

variable "vercel_team" {
  description = "Vercel team slug (leave empty for personal account)"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Vercel project name"
  type        = string
  default     = "vercel-app1"
}

variable "github_repo" {
  description = "GitHub repo in format owner/repo"
  type        = string
}

variable "domain" {
  description = "Custom domain for production"
  type        = string
}

variable "aws_lambda_url" {
  description = "AWS Lambda function URL (app8)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "dynamodb_table" {
  description = "DynamoDB table name"
  type        = string
  default     = ""
}
