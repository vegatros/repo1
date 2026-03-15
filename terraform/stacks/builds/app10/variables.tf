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
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = []
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 3000
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 1
}

variable "cpu" {
  description = "Task CPU units"
  type        = string
  default     = "1024"
}

variable "memory" {
  description = "Task memory in MB"
  type        = string
  default     = "2048"
}

variable "nanoclaw_image_tag" {
  description = "Docker image tag for nanoclaw"
  type        = string
  default     = "latest"
}
