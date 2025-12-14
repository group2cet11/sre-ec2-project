# terraform/monitoring-global/variables.tf
variable "cluster_name" {
  type        = string
  description = "Name of the ECS cluster"
}

variable "ecs_sg_id" {
  type        = string
  description = "Security group ID for ECS"
}

variable "subnets" {
  type        = list(string)
  description = "List of subnet IDs for ECS"
}

variable "prometheus_ap_id" {
  type        = string
  description = "EFS access point ID for Prometheus"
}

variable "efs_id" {
  type        = string
  description = "EFS file system ID"
}

variable "alb_prom_tg" {
  type        = string
  description = "ALB target group ARN for Prometheus"
}

variable "alb_graf_tg" {
  type        = string
  description = "ALB target group ARN for Grafana"
}

variable "dummy" {
  type        = string
  description = "Dummy variable to force task replacement when changed"
  default     = ""
}
