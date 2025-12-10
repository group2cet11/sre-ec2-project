terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ---------------------------
#   VPC
# ---------------------------
resource "aws_vpc" "app" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.env}-vpc"
    Environment = var.env
  }
}

# PRIVATE SUBNET A
resource "aws_subnet" "private_a" {
  vpc_id                  = aws_vpc.app.id
  cidr_block              = var.private_a
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.env}-private-a"
  }
}

# PRIVATE SUBNET B
resource "aws_subnet" "private_b" {
  vpc_id                  = aws_vpc.app.id
  cidr_block              = var.private_b
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.env}-private-b"
  }
}

# INTERNET GATEWAY (for NAT)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.app.id

  tags = {
    Name = "${var.env}-igw"
  }
}

# ---------------------------
# NAT + ROUTES
# ---------------------------
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.private_a.id

  tags = {
    Name = "${var.env}-nat"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.app.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.env}-private-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# ---------------------------
# SSM ENDPOINTS
# ---------------------------
resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = aws_vpc.app.id
  service_name      = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  security_group_ids = [aws_security_group.ssm_sg.id]
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id            = aws_vpc.app.id
  service_name      = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  security_group_ids = [aws_security_group.ssm_sg.id]
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id            = aws_vpc.app.id
  service_name      = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  security_group_ids = [aws_security_group.ssm_sg.id]
}

# SSM SG
resource "aws_security_group" "ssm_sg" {
  name   = "${var.env}-ssm-sg"
  vpc_id = aws_vpc.app.id

  ingress {
    from_port   = 443
    to_port     = 443
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

# ---------------------------
# EC2 INSTANCE (PRIVATE ONLY)
# ---------------------------
resource "aws_instance" "app" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.ssm_sg.id]

  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  associate_public_ip_address = false

  tags = {
    Name = "${var.env}-ec2"
    Environment = var.env
  }
}

# ---------------------------
# SSM PROFILE
# ---------------------------
resource "aws_iam_role" "ssm_role" {
  name = "${var.env}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.env}-ssm-profile"
  role = aws_iam_role.ssm_role.name
}

# ---------------------------
# OUTPUTS
# ---------------------------
output "vpc_id" {
  value = aws_vpc.app.id
}

output "private_subnets" {
  value = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "instance_id" {
  value = aws_instance.app.id
}
