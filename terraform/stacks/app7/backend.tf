terraform {
  backend "s3" {
    bucket         = "terraform-state-925185632967"
    key            = "app7/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
