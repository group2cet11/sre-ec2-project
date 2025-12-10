module "app_env" {
  source = "../../modules/app-env"

  env          = "dev"
  region       = "us-east-1"
  vpc_cidr     = "10.10.0.0/16"
  private_a    = "10.10.1.0/24"
  private_b    = "10.10.2.0/24"
  instance_type = "t3.micro"
  ami_id        = "ami-0c101f26f147fa7fd"
}
