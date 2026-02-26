# VPC Module
module "vpc" {
  source = "../../../modules/network/vpc"

  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
  azs          = var.azs

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  enable_nat_gateway = true
}

# Customer Gateway (Your local network)
resource "aws_customer_gateway" "main" {
  bgp_asn    = 65000
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"

  tags = {
    Name = "${var.project_name}-cgw"
  }
}

# Virtual Private Gateway
resource "aws_vpn_gateway" "main" {
  vpc_id = module.vpc.vpc_id

  tags = {
    Name = "${var.project_name}-vgw"
  }
}

# VPN Gateway Attachment
resource "aws_vpn_gateway_attachment" "main" {
  vpc_id         = module.vpc.vpc_id
  vpn_gateway_id = aws_vpn_gateway.main.id
}

# Site-to-Site VPN Connection
resource "aws_vpn_connection" "main" {
  vpn_gateway_id      = aws_vpn_gateway.main.id
  customer_gateway_id = aws_customer_gateway.main.id
  type                = "ipsec.1"
  static_routes_only  = true

  tags = {
    Name = "${var.project_name}-vpn"
  }
}

# VPN Connection Route
resource "aws_vpn_connection_route" "home" {
  destination_cidr_block = var.on_premise_cidr
  vpn_connection_id      = aws_vpn_connection.main.id
}

# Enable VPN route propagation
resource "aws_vpn_gateway_route_propagation" "private" {
  vpn_gateway_id = aws_vpn_gateway.main.id
  route_table_id = module.vpc.private_route_table_ids[0]
}

# AWS Key Pair
resource "aws_key_pair" "jenkins" {
  key_name   = "${var.project_name}-jenkins-key"
  public_key = file("~/.ssh/temp_key.pub")
}

# Test EC2 instance in private subnet
resource "aws_instance" "test" {
  ami                    = data.aws_ami.redhat.id
  instance_type          = "t3.medium"
  subnet_id              = module.vpc.private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.test_instance.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  key_name               = aws_key_pair.jenkins.key_name
  user_data              = base64encode(templatefile("${path.module}/user_data.sh", {}))

  tags = {
    Name = "${var.project_name}-jenkins-server"
  }
}

# Security group for test instance
resource "aws_security_group" "test_instance" {
  name        = "${var.project_name}-test-instance-sg"
  description = "Security group for test instance"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.on_premise_cidr]
    description = "SSH from on-premise"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.on_premise_cidr]
    description = "Jenkins from on-premise"
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.on_premise_cidr]
    description = "ICMP from on-premise"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-test-instance-sg"
  }
}

# IAM role for SSM access
resource "aws_iam_role" "ssm" {
  name = "${var.project_name}-ssm-role"

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
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.project_name}-ssm-profile"
  role = aws_iam_role.ssm.name
}

data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"] # Red Hat

  filter {
    name   = "name"
    values = ["RHEL-9*_HVM-*-x86_64-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
