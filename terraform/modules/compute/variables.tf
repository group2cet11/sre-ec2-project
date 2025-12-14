#############################################
# terraform/modules/compute/variables.tf
#############################################
variable "subnet_id" {
  type        = string
  description = "Subnet ID for the EC2 instance"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
}

variable "ami_id" {
  type        = string
  description = "AMI ID for the EC2 instance"
}

variable "environment" {
  type        = string
  description = "Environment name (dev/uat/prod)"
}

variable "key_name" {
  type        = string
  description = "EC2 key pair name for SSH access"
}

variable "userdata_revision" {
  type        = number
  description = "Revision number to force user_data change"
  default     = 1
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names"
}

variable "prometheus_ecs_sg_id" {
  type        = string
  description = "Security group ID of the Prometheus Fargate tasks (to allow Node Exporter access on port 9100)"
}
