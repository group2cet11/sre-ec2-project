variable "environment" { type = string }

resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ec2/sre-${var.environment}-logs"
  retention_in_days = 7
}
