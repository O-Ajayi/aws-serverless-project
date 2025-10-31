locals {
  lambda_src_path = "${path.module}${var.lambda_relative_path}lambda"
}

# resource "random_uuid" "lambda_src_hash" {
#   keepers = {
#     for filename in setunion(
#       fileset(local.lambda_src_path, "*.py"),
#       fileset(local.lambda_src_path, "requirements.txt"),
#       fileset(local.lambda_src_path, "**/*")
#     ) :
#     filename => filemd5("${local.lambda_src_path}/${filename}")
#   }
# }

resource "null_resource" "build_lambda_package" {
  provisioner "local-exec" {
    command = "${path.module}/build_lambda.sh"
  }

  triggers = {
    deployment = timestamp()
  }
}

resource "aws_iam_role" "experiment_lambda_role" {
  name               = "${var.lambda_name}_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust_policy.json
}

resource "aws_iam_policy" "experiment_lambda_policy" {
  name   = "experiment_lambda_policy"
  policy = templatefile("lambda_policy.json", { experiment_bucket_arn = aws_s3_bucket.experiments_bucket.arn })
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.experiment_lambda_role.name
  policy_arn = aws_iam_policy.experiment_lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "AWSLambdaBasicExecutionRole-attach" {
  role       = aws_iam_role.experiment_lambda_role.name
  policy_arn = data.aws_iam_policy.AWSLambdaBasicExecutionRole.arn
}

resource "aws_lambda_function" "experiment_lambda" {
  function_name = "${var.lambda_name}-${var.environment_id}"
  description   = "experiment Testing Lambda for ${var.owner}"
  role          = aws_iam_role.experiment_lambda_role.arn
  runtime       = "python3.11"
  handler       = "handler.handler"
  memory_size   = 1024
  timeout       = 600

  s3_bucket = "resiliencyvr-package-build-bucketo" #var.experiment_bucket
  s3_key    = aws_s3_object.lambda_file.id

  source_code_hash = data.local_file.lambda_zip.content_md5
  environment {
    variables = {
      LOG_LEVEL = var.lambda_log_level
    }
  }
  lifecycle {
    ignore_changes = [environment]
  }

  depends_on = [aws_s3_object.lambda_file]
}

resource "aws_s3_object" "lambda_file" {
  bucket     = "resiliencyvr-package-build-bucketo"
  key        = "experiment_code_lambda-${var.owner}-${var.environment_id}.zip"
  source     = data.local_file.lambda_zip.filename
  depends_on = [null_resource.build_lambda_package]
  kms_key_id = aws_kms_key.s3_key.arn
}
