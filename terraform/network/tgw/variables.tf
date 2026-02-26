variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "vpc1_cidr" {
  description = "CIDR block for VPC 1"
  type        = string
  default     = "10.1.0.0/16"
}

variable "vpc2_cidr" {
  description = "CIDR block for VPC 2"
  type        = string
  default     = "10.2.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}
