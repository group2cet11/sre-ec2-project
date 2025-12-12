variable "vpc_id" {}
variable "public_subnets" { type = list(string) }
variable "alb_sg_id" {}

#############################################
# APPLICATION LOAD BALANCER
#############################################
resource "aws_lb" "alb" {
  name               = "monitoring-alb"
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnets
}

#############################################
# TARGET GROUPS
#############################################
resource "aws_lb_target_group" "prometheus" {
  name        = "prometheus-tg"
  port        = 9090
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
}

resource "aws_lb_target_group" "grafana" {
  name        = "grafana-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
}

#############################################
# LISTENERS
#############################################

# PROMETHEUS LISTENER :9090
resource "aws_lb_listener" "prometheus_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 9090
  protocol          = "HTTP"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.prometheus.arn
        weight = 1
      }
    }
  }
}

# GRAFANA LISTENER :3000
resource "aws_lb_listener" "grafana_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 3000
  protocol          = "HTTP"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.grafana.arn
        weight = 1
      }
    }
  }
}

#############################################
# OUTPUTS
#############################################
output "prom_tg_arn" {
  value = aws_lb_target_group.prometheus.arn
}

output "graf_tg_arn" {
  value = aws_lb_target_group.grafana.arn
}

output "alb_dns" {
  value = aws_lb.alb.dns_name
}

output "prometheus_listener_arn" {
  value = aws_lb_listener.prometheus_listener.arn
}

output "grafana_listener_arn" {
  value = aws_lb_listener.grafana_listener.arn
}
