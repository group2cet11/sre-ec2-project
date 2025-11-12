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
  default     = "ami-0c101f26f147fa7fd"
}
