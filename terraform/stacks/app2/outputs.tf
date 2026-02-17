output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "node_group_id" {
  description = "EKS node group ID"
  value       = module.eks.node_group_id
}

output "helm_release_name" {
  description = "Helm release name"
  value       = var.enable_helm_deployment ? helm_release.app[0].name : null
}

output "helm_release_status" {
  description = "Helm release status"
  value       = var.enable_helm_deployment ? helm_release.app[0].status : null
}
