output "project_id" {
  description = "Vercel project ID"
  value       = vercel_project.app1.id
}

output "deployment_url" {
  description = "Production deployment URL"
  value       = "https://${var.domain}"
}
