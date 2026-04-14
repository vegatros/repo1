# Vercel Project
resource "vercel_project" "app1" {
  name      = var.project_name
  framework = "nextjs"

  git_repository = {
    type = "github"
    repo = var.github_repo
  }

  environment = [
    {
      key    = "AWS_LAMBDA_URL"
      value  = var.aws_lambda_url
      target = ["production", "preview", "development"]
    },
    {
      key    = "AWS_REGION"
      value  = var.aws_region
      target = ["production", "preview", "development"]
    },
    {
      key    = "DYNAMODB_TABLE"
      value  = var.dynamodb_table
      target = ["production", "preview", "development"]
    }
  ]
}

# Production domain
resource "vercel_project_domain" "production" {
  project_id = vercel_project.app1.id
  domain     = var.domain
}
