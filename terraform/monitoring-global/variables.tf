variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_public_a" {
  type    = string
  default = "10.0.1.0/24"
}

variable "subnet_public_b" {
  type    = string
  default = "10.0.2.0/24"
}
