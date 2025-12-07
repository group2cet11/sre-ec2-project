output "grafana_url" {
  value = "http://${aws_lb.monitoring.dns_name}"
}

output "vpc_id" {
  value = aws_vpc.monitoring.id
}
