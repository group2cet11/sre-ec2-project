output "prom_tg_arn" {
  value = aws_lb_target_group.prometheus.arn
}

output "graf_tg_arn" {
  value = aws_lb_target_group.grafana.arn
}

output "alb_dns" {
  value = aws_lb.alb.dns_name
}
