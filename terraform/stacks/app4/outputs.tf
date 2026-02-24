output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "cluster_id" {
  description = "ECS cluster ID"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_url" {
  description = "Application URL"
  value       = "http://${aws_lb.main.dns_name}"
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.main.name
}
