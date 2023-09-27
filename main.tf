# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "4.49.0"
#     }
#   }
# }

provider "aws" {
  region = var.aws_region
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.root}/applications/team-projet/lambda_function.py"
  output_path = "${path.root}/out/team-project/lambda_function_payload.zip"
}

module "lambda_function" {
  source = "./modules/lambda"

  function_name          = "${var.env}-${var.function_name}-lambda1"
  description            = var.description
  filename               = data.archive_file.lambda.output_path
  lambda_role            = "arn:aws:iam::975980002439:role/my-lambda-role"
  handler                = "lambda_function.lambda_handler"
  runtime                = "python3.8"
  ephemeral_storage_size = null
  architectures          = ["x86_64"]
  publish                = false
  vpc_security_group_ids = ["sg-07e242858171e4538"]
  vpc_subnet_ids         = ["subnet-06c3e14324a588922", "subnet-09b5d7bc0093dbcc5"]
  source_code_hash       = data.archive_file.lambda.output_base64sha256

  #   source_code_hash = data.archive_file.lambda.output_base64sha256

  #   store_on_s3 = true
  #   s3_bucket   = module.s3_bucket.s3_bucket_id
  #   s3_prefix   = "lambda-builds/"

  #   artifacts_dir = "${path.root}/.terraform/lambda-builds/"

  #   layers = [
  #     "arn:aws:lambda:us-east-1:088190408337:layer:python_requests:3"
  #   ]

  environment_variables = {
    Hello      = "World"
    Serverless = "Terraform"
  }




  #   role_path   = "/tf-managed/"
  #   policy_path = "/tf-managed/"

  #   attach_dead_letter_policy = true
  #   dead_letter_target_arn    = aws_sqs_queue.dlq.arn

  #   allowed_triggers = {
  #     Config = {
  #       principal        = "config.amazonaws.com"
  #       principal_org_id = data.aws_organizations_organization.this.id
  #     }
  #     APIGatewayAny = {
  #       service    = "apigateway"
  #       source_arn = "arn:aws:execute-api:eu-west-1:${data.aws_caller_identity.current.account_id}:aqnku8akd0/*/*/*"
  #     },
  #     APIGatewayDevPost = {
  #       service    = "apigateway"
  #       source_arn = "arn:aws:execute-api:eu-west-1:${data.aws_caller_identity.current.account_id}:aqnku8akd0/dev/POST/*"
  #     },
  #     OneRule = {
  #       principal  = "events.amazonaws.com"
  #       source_arn = "arn:aws:events:eu-west-1:${data.aws_caller_identity.current.account_id}:rule/RunDaily"
  #     }
  #   }
}


##### Create s3 bucket and map to lambda as event trigger

resource "aws_s3_bucket" "my_amplify_source_bucket" {
  bucket = "my-amplify-source-bucket-test"
  #   acl    = "public-read"

}


resource "aws_s3_bucket_notification" "aws-lambda-trigger" {
  bucket = aws_s3_bucket.my_amplify_source_bucket.id
  lambda_function {
    lambda_function_arn = module.lambda_function.lambda_function_arn
    events              = ["s3:ObjectCreated:*"]
    # filter_prefix       = "file-prefix"
    # filter_suffix       = "file-extension"
  }
}
resource "aws_lambda_permission" "test" {
  statement_id   = "AllowS3Invoke"
  action         = "lambda:InvokeFunction"
  function_name  = module.lambda_function.lambda_function_name
  principal      = "s3.amazonaws.com"
  source_account = "975980002439"
  source_arn     = "arn:aws:s3:::${aws_s3_bucket.my_amplify_source_bucket.id}"
}
