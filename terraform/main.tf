terraform {
  backend "s3" {} # values supplied via backend.<env>.tfvars
}

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
  subnet_id      = module.network.public_subnet_id
  vpc_id         = module.network.vpc_id
  instance_type  = var.instance_type
  ami_id         = var.ami_id
  environment    = var.environment
  # pass through the revision switch
  userdata_revision = var.userdata_revision
}

# Monitoring (minimal CW Log Group)
module "monitoring" {
  source      = "./modules/monitoring"
  environment = var.environment
}
