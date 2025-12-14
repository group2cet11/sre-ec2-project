#############################################
# terraform/main.tf (root module - simple EC2 deployment with monitoring-ready features)
#############################################
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Silences the backend warning when using -backend-config
  backend "s3" {}
}

locals {
  prefix = "sre-${var.environment}"
}

resource "aws_cloudwatch_log_group" "ec2" {
  name              = "/sre/${var.environment}/ec2"
  retention_in_days = 14
  tags = {
    Environment = var.environment
  }
}

module "compute" {
  source            = "./modules/compute"
  subnet_id         = var.subnet_id          # Pass from .tfvars or workflow
  vpc_id            = var.vpc_id             # Pass from .tfvars or workflow
  instance_type     = var.instance_type
  ami_id            = var.ami_id
  key_name          = var.key_name
  environment       = var.environment
  userdata_revision = var.userdata_revision
  name_prefix       = local.prefix
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.ec2.name
}

output "public_ip" {
  value       = module.compute.public_ip
  description = "Public IP of the EC2 instance"
}

