# terraform {
#   backend "s3" {
#     dynamodb_table = "experiment_pipeline_terraform_state_rich-demoo"
#     bucket         = "experiment-pipeline-backend-bucket-rich-demoo"
#     region         = "us-east-1"
#     key            = "lambda_infra.terraform.tfstate"
#   }
# }

# provider "aws" {
#   region = "us-east-1"
#   default_tags {
#     tags = {
#       Team = "ResiliencyTeam",
#     }
#   }
# }
