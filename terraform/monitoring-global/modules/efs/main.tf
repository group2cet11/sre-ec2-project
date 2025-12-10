variable "efs_id" {}

data "aws_efs_file_system" "efs" {
  file_system_id = var.efs_id
}

resource "aws_efs_access_point" "ap" {
  file_system_id = var.efs_id

  root_directory {
    path = "/prometheus"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "755"
    }
  }
}

output "efs_id" {
  value = data.aws_efs_file_system.efs.id
}

output "prometheus_ap_id" {
  value = aws_efs_access_point.ap.id
}
