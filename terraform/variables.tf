#############################################
# terraform/variables.tf (root variables - updated)
#############################################
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "environment" {
  description = "Environment name (dev/uat/prod)"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for Amazon Linux 2023 in us-east-1"
  type        = string
  # Amazon Linux 2023 (AL2023) AMI in us-east-1 (as of Dec 2025)
  default     = "ami-0c101f26f147fa7fd"
}

variable "userdata_revision" {
  description = "Bump this number to force EC2 replacement and re-run user_data (e.g., after Node Exporter changes)"
  type        = number
  default     = 1
}

variable "key_name" {
  type        = string
  description = "SSH key pair name for the EC2 instance"
}

variable "project" {
  type        = string
  description = "Project name prefix"
  default     = "sre"
}
