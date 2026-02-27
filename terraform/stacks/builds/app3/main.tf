terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  alias  = "us-west-2"
  region = "us-west-2"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

# VPC and EC2 in us-west-2
module "vpc_west" {
  source = "../../../modules/network/vpc"
  providers = {
    aws = aws.us-west-2
  }

  vpc_cidr             = var.vpc_cidr_west
  public_subnet_cidrs  = var.public_subnet_cidrs_west
  private_subnet_cidrs = []
  azs                  = var.availability_zones_west
  project_name         = "${var.project_name}-west"
}

module "ec2_west" {
  source = "../../../modules/ec2"
  providers = {
    aws = aws.us-west-2
  }

  instance_type  = var.instance_type
  ami_id         = var.ami_id_west
  subnet_ids     = [module.vpc_west.public_subnet_ids[0]]
  vpc_id         = module.vpc_west.vpc_id
  project_name   = "${var.project_name}-west"
  user_data      = file("${path.module}/user_data.sh")
  instance_count = 1
}

# VPC and EC2 in us-east-1
module "vpc_east" {
  source = "../../../modules/network/vpc"
  providers = {
    aws = aws.us-east-1
  }

  vpc_cidr             = var.vpc_cidr_east
  public_subnet_cidrs  = var.public_subnet_cidrs_east
  private_subnet_cidrs = []
  azs                  = var.availability_zones_east
  project_name         = "${var.project_name}-east"
}

module "ec2_east" {
  source = "../../../modules/ec2"
  providers = {
    aws = aws.us-east-1
  }

  instance_type  = var.instance_type
  ami_id         = var.ami_id_east
  subnet_ids     = [module.vpc_east.public_subnet_ids[0]]
  vpc_id         = module.vpc_east.vpc_id
  project_name   = "${var.project_name}-east"
  user_data      = file("${path.module}/user_data.sh")
  instance_count = 1
}

# Global Accelerator
resource "aws_globalaccelerator_accelerator" "main" {
  provider        = aws.us-west-2
  name            = "${var.project_name}-${var.environment}-accelerator"
  ip_address_type = "IPV4"
  enabled         = true
}

resource "aws_globalaccelerator_listener" "main" {
  provider        = aws.us-west-2
  accelerator_arn = aws_globalaccelerator_accelerator.main.id
  protocol        = "TCP"

  port_range {
    from_port = 443
    to_port   = 443
  }
}

resource "aws_globalaccelerator_endpoint_group" "west" {
  provider                = aws.us-west-2
  listener_arn            = aws_globalaccelerator_listener.main.id
  endpoint_group_region   = "us-west-2"
  traffic_dial_percentage = 50

  endpoint_configuration {
    endpoint_id                    = module.ec2_west.instance_ids[0]
    weight                         = 100
    client_ip_preservation_enabled = true
  }

  health_check_interval_seconds = 30
  health_check_path             = "/"
  health_check_protocol         = "TCP"
  health_check_port             = 443
}

resource "aws_globalaccelerator_endpoint_group" "east" {
  provider                = aws.us-west-2
  listener_arn            = aws_globalaccelerator_listener.main.id
  endpoint_group_region   = "us-east-1"
  traffic_dial_percentage = 50

  endpoint_configuration {
    endpoint_id                    = module.ec2_east.instance_ids[0]
    weight                         = 100
    client_ip_preservation_enabled = true
  }

  health_check_interval_seconds = 30
  health_check_path             = "/"
  health_check_protocol         = "TCP"
  health_check_port             = 443
}

# Route 53 record pointing to Global Accelerator
resource "aws_route53_record" "accelerator" {
  provider = aws.us-west-2
  zone_id  = "Z3LLP0B81D4CRA"
  name     = "cloudconscious.io"
  type     = "A"

  alias {
    name                   = aws_globalaccelerator_accelerator.main.dns_name
    zone_id                = aws_globalaccelerator_accelerator.main.hosted_zone_id
    evaluate_target_health = true
  }
}

# DynamoDB Global Table
module "dynamodb" {
  source = "../../../modules/dynamodb"
  providers = {
    aws = aws.us-west-2
  }

  table_name      = "${var.project_name}-${var.environment}-data"
  hash_key        = "id"
  billing_mode    = "PAY_PER_REQUEST"
  replica_regions = ["us-east-1"]

  stream_enabled         = true
  stream_view_type       = "NEW_AND_OLD_IMAGES"
  point_in_time_recovery = false

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}
