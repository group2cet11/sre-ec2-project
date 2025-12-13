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
  # Replace if needed; validate in your account/region
  default = "ami-0c101f26f147fa7fd"
}

variable "userdata_revision" {
  description = "Bump to force EC2 replacement and re-run user_data"
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
  default     = "sre" # <-- You can change this anytime
}
