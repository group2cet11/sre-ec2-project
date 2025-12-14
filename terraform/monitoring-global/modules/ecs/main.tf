#############################################
# terraform/monitoring-global/modules/ecs/main.tf
#############################################
# VARIABLES
#############################################
variable "cluster_name" {}
variable "ecs_sg_id" {}
variable "subnets" { type = list(string) }
variable "prometheus_ap_id" {}
variable "efs_id" {}
variable "alb_prom_tg" {}
variable "alb_graf_tg" {}

#############################################
# LOOKUP CLUSTER + IAM ROLE
#############################################
data "aws_ecs_cluster" "cluster" {
  cluster_name = var.cluster_name
}

data "aws_iam_role" "ecs_exec" {
  name = "monitoring-ecs-execution-role"
}

#############################################
# IAM POLICY — Allow ECS task to read S3 config (optional - keep if you use S3 later)
#############################################
resource "aws_iam_role_policy" "ecs_exec_s3" {
  name = "ecs-exec-s3-policy"
  role = data.aws_iam_role.ecs_exec.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::sre-monitoring-config",
          "arn:aws:s3:::sre-monitoring-config/*"
        ]
      }
    ]
  })
}

#############################################
# PROMETHEUS TASK DEFINITION (using your custom ECR image with EC2 discovery)
#############################################
resource "aws_ecs_task_definition" "prom" {
  family                   = "prometheus"
  cpu                      = "512"
  memory                   = "1024"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = data.aws_iam_role.ecs_exec.arn
  task_role_arn            = data.aws_iam_role.ecs_exec.arn

  container_definitions = jsonencode([
    {
      name      = "prometheus"
      image     = "108471662249.dkr.ecr.us-east-1.amazonaws.com/sre-prometheus:latest"  # Your custom image with baked prometheus.yml
      essential = true

      portMappings = [
        {
          containerPort = 9090
          protocol      = "tcp"
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "storage"
          containerPath = "/prometheus"
          readOnly      = false
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/prometheus"
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  volume {
    name = "storage"

    efs_volume_configuration {
      file_system_id     = var.efs_id
      root_directory     = "/"
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = var.prometheus_ap_id
        iam             = "ENABLED"
      }
    }
  }
}

#############################################
# GRAFANA TASK DEFINITION
#############################################
resource "aws_ecs_task_definition" "graf" {
  family                   = "grafana"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = data.aws_iam_role.ecs_exec.arn
  task_role_arn            = data.aws_iam_role.ecs_exec.arn

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

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/grafana"
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

#############################################
# PROMETHEUS ECS SERVICE
#############################################
resource "aws_ecs_service" "prometheus" {
  name            = "prometheus-service"
  cluster         = data.aws_ecs_cluster.cluster.cluster_name
  task_definition = aws_ecs_task_definition.prom.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.alb_prom_tg
    container_name   = "prometheus"
    container_port   = 9090
  }

  depends_on = [aws_ecs_task_definition.prom]
}

#############################################
# GRAFANA ECS SERVICE
#############################################
resource "aws_ecs_service" "grafana" {
  name            = "grafana-service"
  cluster         = data.aws_ecs_cluster.cluster.cluster_name
  task_definition = aws_ecs_task_definition.graf.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.alb_graf_tg
    container_name   = "grafana"
    container_port   = 3000
  }

  depends_on = [aws_ecs_task_definition.graf]
}

#############################################
# OUTPUTS
#############################################
output "ecs_cluster_name" {
  value = data.aws_ecs_cluster.cluster.cluster_name
}
