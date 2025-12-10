variable "vpc_id" {}
variable "public_subnets" { type = list(string) }
variable "alb_sg_id" {}

resource "aws_lb" "alb" {
  name               = "monitoring-alb"
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnets
}

resource "aws_lb_target_group" "prometheus" {
  name     = "prometheus-tg"
  port     = 9090
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group" "grafana" {
  name     = "grafana-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

output "prometheus_tg" {
  value = aws_lb_target_group.prometheus.arn
}

output "grafana_tg" {
  value = aws_lb_target_group.grafana.arn
}
