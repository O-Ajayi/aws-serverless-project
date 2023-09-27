terraform {
  backend "s3" {
    bucket         = "terraform-state-dev-v3ddd"
    key            = "hub-eft-complete/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-remote-state-rds"
  }
}
