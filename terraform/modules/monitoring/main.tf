variable "environment" { type = string }

locals {
  prefix = "sre-${var.environment}"
}

resource "aws_cloudwatch_log_group" "ec2" {
  name              = "/sre/${var.environment}/ec2"
  retention_in_days = 14

  tags = {
    Environment = var.environment
  }
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.ec2.name
}
