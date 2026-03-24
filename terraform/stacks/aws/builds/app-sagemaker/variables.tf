variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "project_name" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.6.0.0/16"
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.6.1.0/24"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.6.101.0/24"]
}
