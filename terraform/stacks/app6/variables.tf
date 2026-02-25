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
  default     = "app6-s3-website"
}

variable "bucket_name" {
  description = "S3 bucket name for static website"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the website (optional)"
  type        = string
  default     = ""
}
