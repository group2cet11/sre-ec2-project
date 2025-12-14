#############################################
# terraform/main.tf (updated - fixed log group duplicate error)
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

variable "environment" {
  type = string
  description = "Environment name (dev/uat/prod)"
}

variable "region" {
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  type        = string
  default     = "ami-0c101f26f147fa7fd"
}

variable "key_name" {
  type        = string
  description = "SSH key pair name"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for the EC2 instance"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "userdata_revision" {
  type        = number
  default     = 1
}

variable "project" {
  type        = string
  default     = "sre"
}

locals {
  prefix = "${var.project}-${var.environment}"
}

# Import existing log group instead of creating (avoids "already exists" error)
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
