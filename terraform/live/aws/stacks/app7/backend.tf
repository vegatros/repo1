terraform {
  backend "s3" {
    bucket         = "terraform-state-925185632967"
    key            = "stacks/builds/app7/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
    encrypt        = true
  }
}
