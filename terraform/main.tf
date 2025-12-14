terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {}
}

# Define the 3 environments
locals {
  environments = ["dev", "uat", "prod"]
  prefix       = "sre"
}

# Create CloudWatch log group for each environment
resource "aws_cloudwatch_log_group" "ec2" {
  for_each = toset(local.environments)

  name              = "/sre/${each.key}/ec2"
  retention_in_days = 14
  tags = {
    Environment = each.key
  }
}

# Deploy one EC2 per environment
module "compute" {
  for_each = toset(local.environments)

  source            = "./modules/compute"
  subnet_id         = var.subnet_id            # You can make this per-env if needed
  vpc_id            = var.vpc_id
  instance_type     = var.instance_type
  ami_id            = var.ami_id
  key_name          = var.key_name
  environment       = each.key
  userdata_revision = var.userdata_revision
  name_prefix       = "${local.prefix}-${each.key}"
}

# Outputs - all public IPs
output "ec2_public_ips" {
  value = { for env, mod in module.compute : env => mod.public_ip }
  description = "Public IPs for all environments"
}

output "log_group_names" {
  value = { for env, lg in aws_cloudwatch_log_group.ec2 : env => lg.name }
}
