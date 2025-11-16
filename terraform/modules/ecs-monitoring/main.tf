locals {
  name = "sre-${var.environment}-mon"
}

# ---------- Security Groups ----------
resource "aws_security_group" "svc" {
  name        = "${local.name}-sg"
  description = "Monitoring ECS SG"
  vpc_id      = var.vpc_id

  # Prometheus
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  # Alertmanager
  ingress {
    from_port   = 9093
    to_port     = 9093
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  # Grafana
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-sg"
  }
}


# ---------- IAM ----------
# Task execution role (pull images, write logs)
resource "aws_iam_role" "exec" {
  name = "${local.name}-exec"
  assume_role_policy = data.aws_iam_policy_document.exec_assume.json
}

data "aws_iam_policy_document" "exec_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "exec_attach" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task role (runtime perms for Prometheus EC2 SD + S3 read)
resource "aws_iam_role" "task" {
  name = "${local.name}-task"
  assume_role_policy = data.aws_iam_policy_document.exec_assume.json
}

data "aws_iam_policy_document" "task_policy" {
  statement {
    sid     = "EC2Describe"
    actions = ["ec2:DescribeInstances", "ec2:DescribeTags"]
    resources = ["*"]
  }
  statement {
    sid     = "S3ReadConfigs"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${var.config_bucket}",
      "arn:aws:s3:::${var.config_bucket}/*"
    ]
  }
}
resource "aws_iam_policy" "task" {
  name   = "${local.name}-task-policy"
  policy = data.aws_iam_policy_document.task_policy.json
}
resource "aws_iam_role_policy_attachment" "task_attach" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.task.arn
}

# ---------- Logs ----------
resource "aws_cloudwatch_log_group" "lg_prom" {
  name              = "/ecs/${local.name}/prometheus"
  retention_in_days = 14
}
resource "aws_cloudwatch_log_group" "lg_alert" {
  name              = "/ecs/${local.name}/alertmanager"
  retention_in_days = 14
}
resource "aws_cloudwatch_log_group" "lg_graf" {
  name              = "/ecs/${local.name}/grafana"
  retention_in_days = 14
}
resource "aws_cloudwatch_log_group" "lg_cfg" {
  name              = "/ecs/${local.name}/config-sync"
  retention_in_days = 7
}

# ---------- ECS ----------
resource "aws_ecs_cluster" "cluster" {
  name = "${local.name}-cluster"
}

# Task definition with 4 containers sharing EFS volumes
resource "aws_ecs_task_definition" "task" {
  family                   = "${local.name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.exec.arn
  task_role_arn            = aws_iam_role.task.arn

  # Fargate + EFS volumes
  volume {
    name = "config"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.fs.id
      transit_encryption = "ENABLED"
      root_directory = "/config"
    }
  }
  volume {
    name = "prom_data"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.fs.id
      transit_encryption = "ENABLED"
      root_directory = "/prom-data"
    }
  }
  volume {
    name = "grafana_data"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.fs.id
      transit_encryption = "ENABLED"
      root_directory = "/grafana-data"
    }
  }

  container_definitions = jsonencode([
  {
    name        = "config-sync"
    image       = var.config_sync_image
    essential   = false
    entryPoint  = ["bash", "-lc"]

    command = [
      "/bin/sh",
      "-c",
      <<-EOC
        yum -y install unzip gzip tar curl awscli &&
        mkdir -p /config &&
        aws s3 cp s3://${var.config_bucket}/prometheus.yml /config/prometheus.yml &&
        aws s3 cp s3://${var.config_bucket}/alertmanager.yml /config/alertmanager.yml &&
        aws s3 cp s3://${var.config_bucket}/grafana-dashboard.json /config/grafana-dashboard.json &&
        echo 'config ready'; sleep 5m
      EOC
    ]

        mountPoints = [
      {
        sourceVolume  = "config"
        containerPath = "/config"
      }
    ]

    "logConfiguration" = {
      "logDriver" = "awslogs",
      "options" = {
        "awslogs-group"         = aws_cloudwatch_log_group.lg_cfg.name,
        "awslogs-region"        = data.aws_region.current.name,
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }
])

      "mountPoints": [{"sourceVolume":"config","containerPath":"/config"}],
      "logConfiguration": {"logDriver":"awslogs","options":{
        "awslogs-group": aws_cloudwatch_log_group.lg_cfg.name,
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-stream-prefix": "ecs"}}
    },
    {
      "name": "prometheus",
      "image": var.prometheus_image,
      "essential": true,
      "portMappings": [{"containerPort":9090,"protocol":"tcp"}],
      "entryPoint": ["sh","-lc"],
      command = [
      "/bin/sh",
      "-c",
      <<-PROM
        while [ ! -f /config/prometheus.yml ]; do echo 'wait cfg'; sleep 2; done;
        exec /bin/prometheus \
          --config.file=/config/prometheus.yml \
          --storage.tsdb.path=/prom-data \
          --web.enable-admin-api \
          --web.enable-lifecycle
      PROM
    ]

      "mountPoints": [
        {"sourceVolume":"config","containerPath":"/config"},
        {"sourceVolume":"prom_data","containerPath":"/prom-data"}
      ],
      "logConfiguration": {"logDriver":"awslogs","options":{
        "awslogs-group": aws_cloudwatch_log_group.lg_prom.name,
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-stream-prefix": "ecs"}}
    },
    {
      "name": "alertmanager",
      "image": var.alertmanager_image,
      "essential": true,
      "portMappings": [{"containerPort":9093,"protocol":"tcp"}],
      "entryPoint": ["sh","-lc"],
         command = [
      "/bin/sh",
      "-c",
      <<-ALERT
        while [ ! -f /config/alertmanager.yml ]; do echo 'wait cfg'; sleep 2; done;
        exec /bin/alertmanager \
          --config.file=/config/alertmanager.yml \
          --storage.path=/alert-data
      ALERT
    ]

      "mountPoints": [{"sourceVolume":"config","containerPath":"/config"}],
      "logConfiguration": {"logDriver":"awslogs","options":{
        "awslogs-group": aws_cloudwatch_log_group.lg_alert.name,
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-stream-prefix": "ecs"}}
    },
    {
      "name": "grafana",
      "image": var.grafana_image,
      "essential": true,
      "portMappings": [{"containerPort":3000,"protocol":"tcp"}],
      "environment": [
        {"name":"GF_SECURITY_ADMIN_USER","value":"admin"},
        {"name":"GF_SECURITY_ADMIN_PASSWORD","value":"admin"}
      ],
      "mountPoints": [
        {"sourceVolume":"config","containerPath":"/config"},
        {"sourceVolume":"grafana_data","containerPath":"/var/lib/grafana"}
      ],
      "logConfiguration": {"logDriver":"awslogs","options":{
        "awslogs-group": aws_cloudwatch_log_group.lg_graf.name,
        "awslogs-region": "${data.aws_region.current.name}",
        "awslogs-stream-prefix": "ecs"}}
    }
  ])
}

data "aws_region" "current" {}

# The ECS service (single task with all 4 containers)
resource "aws_ecs_service" "svc" {
  name            = "${local.name}-svc"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.public_subnet_ids
    assign_public_ip = true
    security_groups = [aws_security_group.svc.id]
  }

  lifecycle { ignore_changes = [task_definition] } # easier updates via new revision
}
