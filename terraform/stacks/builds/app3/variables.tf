variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "app3"
}

# us-west-2 variables
variable "vpc_cidr_west" {
  description = "VPC CIDR for us-west-2"
  type        = string
}

variable "public_subnet_cidrs_west" {
  description = "Public subnet CIDRs for us-west-2"
  type        = list(string)
}

variable "availability_zones_west" {
  description = "Availability zones for us-west-2"
  type        = list(string)
}

variable "ami_id_west" {
  description = "Amazon Linux AMI ID for us-west-2"
  type        = string
}

# us-east-1 variables
variable "vpc_cidr_east" {
  description = "VPC CIDR for us-east-1"
  type        = string
}

variable "public_subnet_cidrs_east" {
  description = "Public subnet CIDRs for us-east-1"
  type        = list(string)
}

variable "availability_zones_east" {
  description = "Availability zones for us-east-1"
  type        = list(string)
}

variable "ami_id_east" {
  description = "Amazon Linux AMI ID for us-east-1"
  type        = string
}

# Common variables
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}
