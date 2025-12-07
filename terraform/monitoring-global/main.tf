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
# VPC
# ---------------------------
resource "aws_vpc" "monitoring" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "monitoring-global-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.monitoring.id
  cidr_block              = var.subnet_public_a
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"

  tags = {
    Name = "monitoring-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.monitoring.id
  cidr_block              = var.subnet_public_b
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}b"

  tags = {
    Name = "monitoring-public-b"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.monitoring.id

  tags = {
    Name = "monitoring-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.monitoring.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "monitoring-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------
# SECURITY GROUPS
# ---------------------------
resource "aws_security_group" "alb_sg" {
  name   = "monitoring-alb-sg"
  vpc_id = aws_vpc.monitoring.id

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "monitoring-alb-sg"
  }
}

resource "aws_security_group" "ecs_sg" {
  name   = "monitoring-ecs-sg"
  vpc_id = aws_vpc.monitoring.id

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "monitoring-ecs-sg"
  }
}

# ---------------------------
# EFS
# ---------------------------
resource "aws_efs_file_system" "efs" {
  performance_mode = "generalPurpose"

  tags = {
    Name = "monitoring-efs"
  }
}

resource "aws_efs_mount_target" "efs_a" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = aws_subnet.public_a.id
  security_groups = [
    aws_security_group.ecs_sg.id
  ]
}

resource "aws_efs_mount_target" "efs_b" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = aws_subnet.public_b.id
  security_groups = [
    aws_security_group.ecs_sg.id
  ]
}

# ---------------------------
# ECS CLUSTER
# ---------------------------
resource "aws_ecs_cluster" "monitoring" {
  name = "monitoring-global-cluster"
}

# ---------------------------
# ALB (PUBLIC)
# ---------------------------
resource "aws_lb" "monitoring" {
  name               = "monitoring-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]
}

resource "aws_lb_target_group" "grafana_tg" {
  name     = "grafana-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.monitoring.id
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.monitoring.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana_tg.arn
  }
}

# ---------------------------
# ECS TASK DEFINITIONS
# ---------------------------
resource "aws_ecs_task_definition" "grafana" {
  family                   = "grafana"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024

  container_definitions = jsonencode([
    {
      name      = "grafana"
      image     = "grafana/grafana:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "grafana" {
  name            = "grafana"
  cluster         = aws_ecs_cluster.monitoring.id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana_tg.arn
    container_name   = "grafana"
    container_port   = 3000
  }
}
