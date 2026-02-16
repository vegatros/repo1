terraform {
  backend "s3" {
    bucket         = "terraform-state-925185632967"
    key            = "STACK_NAME/terraform.tfstate"  # Change STACK_NAME
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
