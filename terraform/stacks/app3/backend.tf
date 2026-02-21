terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket"
    key            = "app3/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
