resource "aws_dynamodb_table" "terraform-backend" {
  name           = "experiment_pipeline_terraform_state_${var.environment_id}"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  tags = {
    "Name" = "DynamoDB Terraform State Lock Table for Experiment Broker Deployment Testing"
  }
}



# resource "aws_dynamodb_table" "experiment-pipeline-alpha-reporting" {
#   name           = "experiment_pipeline_alpha_reporting"
#   read_capacity  = 5
#   write_capacity = 5
#   hash_key       = "ISO8601"
#   attribute {
#     name = "ISO8601"
#     type = "S"
#   }
#   tags = {
#     "Name" = "DynamoDB Terraform Dynamo Table for Experiment Broker Reporting"
#   }
# }