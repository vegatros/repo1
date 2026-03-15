# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
}

data "aws_availability_zones" "available" { state = "available" }

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[0]
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "nanoclaw" {
  name        = "${var.project_name}-sg"
  description = "Security group for nanoclaw EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
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
}

# IAM Role with SSM access
resource "aws_iam_role" "nanoclaw" {
  name = "${var.project_name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.nanoclaw.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "nanoclaw" {
  name = "${var.project_name}-profile"
  role = aws_iam_role.nanoclaw.name
}

# Latest Amazon Linux 2023 AMI
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# EC2 Instance
resource "aws_instance" "nanoclaw" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.nanoclaw.id]
  iam_instance_profile   = aws_iam_instance_profile.nanoclaw.name
  key_name               = var.key_name != "" ? var.key_name : null

  associate_public_ip_address = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Install Docker
    dnf install -y docker git
    systemctl enable docker && systemctl start docker
    usermod -aG docker ec2-user

    # Install Node.js 22
    dnf install -y nodejs22 nodejs22-npm

    # Clone nanoclaw
    su - ec2-user -c 'git clone https://github.com/qwibitai/nanoclaw.git /home/ec2-user/nanoclaw'

    # Install dependencies
    su - ec2-user -c 'cd /home/ec2-user/nanoclaw && npm install'

    echo "NanoClaw ready. SSH in and run: cd nanoclaw && claude"
  EOF

  tags = {
    Name = "${var.project_name}-ec2"
  }
}
