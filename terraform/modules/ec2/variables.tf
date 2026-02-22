variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EC2 instances will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for EC2 instances"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "instance_count" {
  description = "Number of EC2 instances"
  type        = number
  default     = 1
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (optional, uses latest Amazon Linux 2 if not provided)"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
  default     = ""
}

variable "user_data" {
  description = "User data script"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed to SSH (leave empty to disable SSH access)"
  type        = list(string)
  default     = []
}

variable "alb_security_group_id" {
  description = "ALB security group ID to allow traffic from"
  type        = string
  default     = ""
}
