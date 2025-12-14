#############################################
# terraform/main.tf (fixed - no destroy on environment change)
#############################################
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

locals {
  prefix = "${var.project}-${var.environment}"
}

# Use data source for existing log group (avoids "already exists" error)
data "aws_cloudwatch_log_group" "ec2" {
  name = "/sre/${var.environment}/ec2"
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
  value = data.aws_cloudwatch_log_group.ec2.name
}

output "public_ip" {
  value = module.compute.public_ip
}
