# data "archive_file" "lambda_source_package" {
#   type        = "zip"
#   source_dir  = local.lambda_src_path
#   output_path = "${path.module}/.tmp/${random_uuid.lambda_src_hash.result}.zip"

#   excludes = [
#     "__pycache__",
#     "tests"
#   ]

#   depends_on = [null_resource.install_dependencies]
# }

data local_file lambda_zip {
  filename = "${path.module}/build_temp/experimentvr_lambda.zip"
  depends_on = [null_resource.build_lambda_package]
}

data "aws_iam_policy_document" "lambda_trust_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "AWSLambdaBasicExecutionRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}