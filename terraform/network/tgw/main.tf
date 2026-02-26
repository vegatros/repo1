data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# VPC 1
resource "aws_vpc" "vpc1" {
  cidr_block           = var.vpc1_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc1"
  }
}

resource "aws_subnet" "vpc1_private" {
  vpc_id            = aws_vpc.vpc1.id
  cidr_block        = cidrsubnet(var.vpc1_cidr, 8, 1)
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-vpc1-private"
  }
}

resource "aws_internet_gateway" "vpc1" {
  vpc_id = aws_vpc.vpc1.id

  tags = {
    Name = "${var.project_name}-vpc1-igw"
  }
}

resource "aws_route_table" "vpc1" {
  vpc_id = aws_vpc.vpc1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc1.id
  }

  route {
    cidr_block         = var.vpc2_cidr
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-vpc1-rt"
  }
}

resource "aws_route_table_association" "vpc1" {
  subnet_id      = aws_subnet.vpc1_private.id
  route_table_id = aws_route_table.vpc1.id
}

# VPC 2
resource "aws_vpc" "vpc2" {
  cidr_block           = var.vpc2_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc2"
  }
}

resource "aws_subnet" "vpc2_private" {
  vpc_id            = aws_vpc.vpc2.id
  cidr_block        = cidrsubnet(var.vpc2_cidr, 8, 1)
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-vpc2-private"
  }
}

resource "aws_internet_gateway" "vpc2" {
  vpc_id = aws_vpc.vpc2.id

  tags = {
    Name = "${var.project_name}-vpc2-igw"
  }
}

resource "aws_route_table" "vpc2" {
  vpc_id = aws_vpc.vpc2.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc2.id
  }

  route {
    cidr_block         = var.vpc1_cidr
    transit_gateway_id = aws_ec2_transit_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-vpc2-rt"
  }
}

resource "aws_route_table_association" "vpc2" {
  subnet_id      = aws_subnet.vpc2_private.id
  route_table_id = aws_route_table.vpc2.id
}

# Transit Gateway
resource "aws_ec2_transit_gateway" "main" {
  description                     = "${var.project_name} Transit Gateway"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = {
    Name = "${var.project_name}-tgw"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc1" {
  subnet_ids         = [aws_subnet.vpc1_private.id]
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.vpc1.id

  tags = {
    Name = "${var.project_name}-tgw-vpc1"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "vpc2" {
  subnet_ids         = [aws_subnet.vpc2_private.id]
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.vpc2.id

  tags = {
    Name = "${var.project_name}-tgw-vpc2"
  }
}

# Security Groups
resource "aws_security_group" "vpc1_instance" {
  name        = "${var.project_name}-vpc1-instance"
  description = "Security group for VPC1 instance"
  vpc_id      = aws_vpc.vpc1.id

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc2_cidr]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-vpc1-sg"
  }
}

resource "aws_security_group" "vpc2_instance" {
  name        = "${var.project_name}-vpc2-instance"
  description = "Security group for VPC2 instance"
  vpc_id      = aws_vpc.vpc2.id

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc1_cidr]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-vpc2-sg"
  }
}

# IAM Role for EC2
resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# EC2 Instance in VPC1
resource "aws_instance" "vpc1" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.vpc1_private.id
  vpc_security_group_ids      = [aws_security_group.vpc1_instance.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              echo "VPC1 Instance - ${var.project_name}" > /var/www/html/index.html
              EOF

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "${var.project_name}-vpc1-instance"
  }
}

# EC2 Instance in VPC2
resource "aws_instance" "vpc2" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.vpc2_private.id
  vpc_security_group_ids      = [aws_security_group.vpc2_instance.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              echo "VPC2 Instance - ${var.project_name}" > /var/www/html/index.html
              EOF

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "${var.project_name}-vpc2-instance"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}
