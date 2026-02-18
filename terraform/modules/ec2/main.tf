# Data source for AMI if not provided
data "aws_ami" "default" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["125523088429"]  # CentOS official owner ID

  filter {
    name   = "name"
    values = ["CentOS Stream 9 x86_64*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Security Group
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group for EC2 instances"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "HTTP from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name = "${var.project_name}-ec2-sg"
    },
    var.tags
  )
}

# EC2 Instances
resource "aws_instance" "this" {
  count                       = var.instance_count
  ami                         = var.ami_id != "" ? var.ami_id : data.aws_ami.default[0].id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  key_name                    = var.key_name != "" ? var.key_name : null
  user_data                   = var.user_data != "" ? var.user_data : null
  associate_public_ip_address = false

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = merge(
    {
      Name = "${var.project_name}-ec2-${count.index + 1}"
    },
    var.tags
  )
}
