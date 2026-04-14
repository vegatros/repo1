terraform {
  required_version = ">= 1.5"

  required_providers {
    vercel = {
      source  = "vercel/vercel"
      version = "~> 1.0"
    }
  }

  backend "s3" {
    bucket       = "terraform-state-925185632967"
    key          = "vercel/app1/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "vercel" {
  api_token = var.vercel_api_token
  team      = var.vercel_team
}
