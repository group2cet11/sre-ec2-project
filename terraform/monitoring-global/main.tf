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

# ------------------------------------------------------
# VPC + NETWORKING
# ------------------------------------------------------
resource "aws_vpc" "monitoring" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "monitoring-global-vpc" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.monitoring.id
  cidr_block              = var.subnet_public_a
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"

  tags = { Name = "monitoring-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.monitoring.id
  cidr_block              = var.subnet_public_b
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}b"

  tags = { Name = "monitoring-public-b" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.monitoring.id
  tags = { Name = "monitoring-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.monitoring.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "monitoring-public-rt" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# ------------------------------------------------------
# SECURITY GROUPS
# ------------------------------------------------------
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

  tags = { Name = "monitoring-alb-sg" }
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

  # Required for EFS
  ingress {
    description = "EFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "monitoring-ecs-sg" }
}

# ------------------------------------------------------
# EFS + ACCESS POINT (Prometheus persistent storage)
# ------------------------------------------------------
resource "aws_efs_file_system" "efs" {
  performance_mode = "generalPurpose"
  tags = { Name = "monitoring-efs" }
}

resource "aws_efs_access_point" "prometheus" {
  file_system_id = aws_efs_file_system.efs.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/prometheus"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "755"
    }
  }

  tags = { Name = "prometheus-access-point" }
}

resource "aws_efs_mount_target" "efs_a" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = aws_subnet.public_a.id
  security_groups = [aws_security_group.ecs_sg.id]
}

resource "aws_efs_mount_target" "efs_b" {
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = aws_subnet.public_b.id
  security_groups = [aws_security_group.ecs_sg.id]
}

# ------------------------------------------------------
# ECS CLUSTER
# ------------------------------------------------------
resource "aws_ecs_cluster" "monitoring" {
  name = "monitoring-global-cluster"
}

# ------------------------------------------------------
# ALB + TARGET GROUPS
# ------------------------------------------------------
resource "aws_lb" "monitoring" {
  name               = "monitoring-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

# Grafana Target Group
resource "aws_lb_target_group" "grafana_tg" {
  name_prefix = "graf-"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.monitoring.id

  health_check {
    path     = "/"
    matcher  = "200-399"
  }
}

# Prometheus Target Group
resource "aws_lb_target_group" "prometheus_tg" {
  name_prefix = "prom-"
  port        = 9090
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.monitoring.id

  health_check {
    path     = "/-/healthy"
    matcher  = "200-399"
  }
}

# Listener default → Grafana
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.monitoring.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana_tg.arn
  }
}

# Listener Rule → Prometheus
resource "aws_lb_listener_rule" "prometheus_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus_tg.arn
  }

  condition {
    path_pattern {
      values = ["/prometheus*", "/prom*"]
    }
  }
}

# ------------------------------------------------------
# TASK DEFINITION – GRAFANA
# ------------------------------------------------------
resource "aws_ecs_task_definition" "grafana" {
  family                   = "grafana"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([
    {
      name  = "grafana",
      image = "grafana/grafana:latest",
      essential = true,
      portMappings = [
        { containerPort = 3000, protocol = "tcp" }
      ]
    }
  ])
}

# ------------------------------------------------------
# TASK DEFINITION – PROMETHEUS (with EFS mount)
# ------------------------------------------------------
resource "aws_ecs_task_definition" "prometheus" {
  family                   = "prometheus"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_execution.arn

  volume {
    name = "prometheus-data"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.efs.id
      transit_encryption       = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.prometheus.id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "prometheus",
      image     = "prom/prometheus:latest",
      essential = true,
      portMappings = [
        { containerPort = 9090, protocol = "tcp" }
      ],
      mountPoints = [
        {
          sourceVolume  = "prometheus-data",
          containerPath = "/prometheus"
        }
      ],
      command = [
        "--config.file=/etc/prometheus/prometheus.yml",
        "--storage.tsdb.path=/prometheus"
      ]
    }
  ])
}

# ------------------------------------------------------
# ECS SERVICES
# ------------------------------------------------------
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

resource "aws_ecs_service" "prometheus" {
  name            = "prometheus"
  cluster         = aws_ecs_cluster.monitoring.id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.prometheus_tg.arn
    container_name   = "prometheus"
    container_port   = 9090
  }
}

# ------------------------------------------------------
# IAM ROLES
# ------------------------------------------------------
resource "aws_iam_role" "ecs_execution" {
  name = "monitoring-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
