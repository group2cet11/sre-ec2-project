variable "vpc_id" {}
variable "public_a_id" {}
variable "public_b_id" {}
variable "alb_sg_id" {}
variable "ecs_sg_id" {}

# These resources already exist — Terraform will reference them.

data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_subnet" "public_a" {
  id = var.public_a_id
}

data "aws_subnet" "public_b" {
  id = var.public_b_id
}

data "aws_security_group" "alb_sg" {
  id = var.alb_sg_id
}

data "aws_security_group" "ecs_sg" {
  id = var.ecs_sg_id
}

output "vpc_id" {
  value = data.aws_vpc.main.id
}

output "public_subnets" {
  value = [
    data.aws_subnet.public_a.id,
    data.aws_subnet.public_b.id
  ]
}

output "ecs_sg_id" {
  value = data.aws_security_group.ecs_sg.id
}

output "alb_sg_id" {
  value = data.aws_security_group.alb_sg.id
}

output "cluster_name" {
  value = "monitoring-global-cluster"
}
