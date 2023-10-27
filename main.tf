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

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}
data "aws_canonical_user_id" "current" {}
data "aws_cloudfront_log_delivery_canonical_user_id" "cloudfront" {}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.root}/applications/team-projet/lambda_function.py"
  output_path = "${path.root}/out/team-project/lambda_function_payload.zip"
}

locals {
  name        = "hub-mft"
  bucket_name = "${local.name}-s3-bucket"

  tags = {
    Name = local.name
  }
}



################################################################################
# Lambda
################################################################################

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



data "aws_sns_topic" "cloud_security_scan" {
  name = "sample-topicssss"

}

resource "aws_lambda_permission" "with_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_function.lambda_function_name
  principal     = "sns.amazonaws.com"
  source_arn    = data.aws_sns_topic.cloud_security_scan.arn
}



################################################################################
# SNS
################################################################################


module "sns" {
  source = "./modules/aws_sns_topic"

  name              = "${local.name}-avscan-sns-topic-${var.env}"
  signature_version = 2

  data_protection_policy = jsonencode(
    {
      Description = "Deny Inbound Address"
      Name        = "DenyInboundEmailAdressPolicy"
      Statement = [
        {
          "DataDirection" = "Inbound"
          "DataIdentifier" = [
            "arn:aws:dataprotection::aws:data-identifier/EmailAddress",
          ]
          "Operation" = {
            "Deny" = {}
          }
          "Principal" = [
            "*",
          ]
          "Sid" = "DenyInboundEmailAddress"
        },
      ]
      Version = "2021-06-01"
    }
  )

  subscriptions = {
    lambda = {
      protocol = "lambda"
      endpoint = module.lambda_function.lambda_function_arn
      # filter_policy = {
      #   "notification" = ["scanResult"]
      # }
    }
  }

  tags = local.tags
}




################################################################################
# S3
################################################################################

resource "aws_kms_key" "objects" {
  description             = "KMS key is used to encrypt bucket objects"
  deletion_window_in_days = 7
}

resource "aws_iam_role" "this" {
  name               = "avscan-bucket-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.this.arn]
    }

    actions = [
      "s3:*",
    ]

    resources = [
      "arn:aws:s3:::${local.bucket_name}-${var.env}",
    ]
  }
}


module "s3" {
  source = "./modules/aws_s3"

  bucket = "${local.bucket_name}-${var.env}"

  force_destroy = true
  tags = {
    Owner = "eft"
  }
  attach_policy = true
  policy        = data.aws_iam_policy_document.bucket_policy.json
  # acl           = "private" # "acl" conflicts with "grant" and "owner"
}


# locals {
#   region = "us-east-1"
#   name   = "ex-${basename(path.cwd)}"

#   vpc_cidr = "10.0.0.0/16"
#   azs      = slice(data.aws_availability_zones.available.names, 0, 3)

#   container_name = "ecsdemo-frontend"
#   container_port = 3000

#   tags = {
#     Name       = local.name
#     Example    = local.name
#     Repository = "https://github.com/terraform-aws-modules/terraform-aws-ecs"
#   }
# }

################################################################################
# Cluster
################################################################################

module "ecs_cluster" {
  source = "./modules/ecs_cluster"

  cluster_name = "${local.name}-sftp-push-cluster"

  # Capacity provider
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 50
        base   = 20
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
  }

  tags = local.tags
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
