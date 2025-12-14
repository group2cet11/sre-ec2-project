#############################################
# terraform/main.tf (fixed - no duplicate variables)
#############################################
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Silences the backend warning
  backend "s3" {}
}

# All variables are declared in variables.tf - do NOT redeclare them here
# (this was the cause of the duplicate errors)

locals {
  prefix = "${var.project}-${var.environment}"
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
  subnet_id         = var.subnet_id
  vpc_id            = var.vpc_id
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
  value = module.compute.public_ip
}
