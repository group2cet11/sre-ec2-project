variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

# Images (you can change tags later if you want)
variable "prometheus_image" {
  type    = string
  default = "prom/prometheus:latest"
}

variable "alertmanager_image" {
  type    = string
  default = "prom/alertmanager:latest"
}

variable "grafana_image" {
  type    = string
  default = "grafana/grafana:latest"
}

variable "config_sync_image" {
  type    = string
  default = "amazonlinux:2023"
}

# S3 bucket that holds prometheus.yml, alertmanager.yml, grafana-dashboard.json
variable "config_bucket" {
  type = string
}

# EFS throughput and task sizing
variable "efs_throughput_mode" {
  type    = string
  default = "bursting" # or "provisioned"
}

variable "task_cpu" {
  type    = number
  default = 1024 # 1 vCPU
}

variable "task_memory" {
  type    = number
  default = 2048 # 2 GiB
}
