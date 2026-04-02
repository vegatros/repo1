terraform {
  backend "s3" {
    bucket         = "terraform-state-925185632967"
    key            = "stacks/builds/sagemaker/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}
