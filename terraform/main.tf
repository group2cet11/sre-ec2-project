terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

locals {
  name_prefix = "sre-${var.environment}"
}

# -------------------------------
# NETWORK MODULE
# -------------------------------
module "network" {
  source      = "./modules/network"
  region      = var.region
  environment = var.environment
  name_prefix = "${var.project}-${var.environment}"
}

# -------------------------------
# EC2 COMPUTE MODULE
# -------------------------------
module "compute" {
  source            = "./modules/compute"
  subnet_id         = module.network.public_subnet_ids[0]
  vpc_id            = module.network.vpc_id
  instance_type     = var.instance_type
  ami_id            = var.ami_id
  key_name          = var.key_name
  environment       = var.environment
  userdata_revision = var.userdata_revision
  name_prefix       = "${var.project}-${var.environment}"
}

# -------------------------------
# MONITORING MODULE
# -------------------------------
module "monitoring" {
  source      = "./modules/monitoring"
  environment = var.environment
}

