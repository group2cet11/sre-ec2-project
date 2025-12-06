terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  name_prefix = "sre-${var.environment}"
}

# Networking
module "network" {
  source = "./modules/network"
  region = var.region
  environment = var.environment
}

# Compute
module "compute" {
  source         = "./modules/compute"
  subnet_id      = module.network.public_subnet_ids[0]   # <--- UPDATED
  vpc_id         = module.network.vpc_id
  instance_type  = var.instance_type
  ami_id         = var.ami_id
  environment    = var.environment
  userdata_revision = var.userdata_revision
}

# Monitoring (minimal CW Log Group)
module "monitoring" {
  source      = "./modules/monitoring"
  environment = var.environment
}

# S3 bucket to store ECS monitoring configuration files
resource "aws_s3_bucket" "mon_config" {
  bucket = "sre-${var.environment}-mon-config-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name        = "sre-${var.environment}-mon-config"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "mon_config" {
  bucket                  = aws_s3_bucket.mon_config.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- NOW YOUR ECS MODULE HERE ---

# ECS-based monitoring stack (Prometheus + Alertmanager + Grafana)
module "ecs_monitoring" {
  source = "./modules/ecs-monitoring"

  environment       = var.environment
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids

  # Who can access Grafana/Prometheus
  allowed_cidrs = ["0.0.0.0/0"]

  # S3 that stores yaml/json config files
  config_bucket = aws_s3_bucket.mon_config.bucket
}


