output "ecs_sg_id" {
  value       = module.ecs.ecs_sg_id  # or whatever resource creates the ECS SG in monitoring
  description = "ECS tasks security group ID"
}

output "alb_dns" {
  value       = module.alb.alb_dns_name  # or the ALB DNS output from your monitoring/alb module
  description = "ALB DNS name"
}
