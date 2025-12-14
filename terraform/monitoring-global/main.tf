#############################################
# terraform/monitoring-global/main.tf (complete with pass-through)
#############################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {}
}

module "network" {
  source      = "./modules/network"
  vpc_id      = "vpc-0e76ad8a9fd3d2633"
  public_a_id = "subnet-0eac7bd1ef91ab150"
  public_b_id = "subnet-0ca78294d9d6eb52b" # us-east-1b
  alb_sg_id   = "sg-06c1f180e84160ea7"
  ecs_sg_id   = "sg-031da0f1810bc1e3d"
}

module "efs" {
  source = "./modules/efs"
  efs_id = "fs-0277ec69cad1dc4f4"
}

module "alb" {
  source         = "./modules/alb"
  vpc_id         = module.network.vpc_id
  public_subnets = module.network.public_subnets
  alb_sg_id      = module.network.alb_sg_id
}

module "ecs" {
  source           = "./modules/ecs"
  cluster_name     = module.network.cluster_name
  ecs_sg_id        = module.network.ecs_sg_id
  subnets          = module.network.public_subnets
  prometheus_ap_id = module.efs.prometheus_ap_id
  efs_id           = module.efs.efs_id
  alb_prom_tg      = module.alb.prom_tg_arn
  alb_graf_tg      = module.alb.graf_tg_arn

  # <-- ADD THIS LINE to pass your custom image
  prometheus_image = "108471662249.dkr.ecr.us-east-1.amazonaws.com/sre-prometheus:latest"
}

output "alb_dns" {
  value = module.alb.alb_dns
}
