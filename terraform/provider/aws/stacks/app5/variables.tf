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
  default     = "app5-s3-website"
}

variable "bucket_name" {
  description = "S3 bucket name for static website"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the website"
  type        = string
  default     = "futurev.io"
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = "Z3LLP0B81D4CRA"
}
