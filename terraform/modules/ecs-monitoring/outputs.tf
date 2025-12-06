output "sg_id"           { value = aws_security_group.svc.id }
output "cluster_name"    { value = aws_ecs_cluster.cluster.name }
output "service_name"    { value = aws_ecs_service.svc.name }
output "efs_id"          { value = aws_efs_file_system.fs.id }
