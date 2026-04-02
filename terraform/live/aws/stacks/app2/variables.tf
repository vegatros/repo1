variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.1.0.0/16"
}

variable "instance_type" {
  description = "EKS node instance type"
  type        = string
  default     = "t3.medium"
}

variable "desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 3
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks for EKS nodes"
  type        = list(string)
  default     = []
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks for NLB and NAT"
  type        = list(string)
  default     = []
}

variable "admin_arns" {
  description = "List of IAM ARNs for EKS cluster admin access"
  type        = list(string)
  default     = []
}
