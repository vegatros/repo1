output "ecr_repository_url" {
  description = "ECR repository URL for nanoclaw image"
  value       = aws_ecr_repository.nanoclaw.repository_url
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.main.name
}
