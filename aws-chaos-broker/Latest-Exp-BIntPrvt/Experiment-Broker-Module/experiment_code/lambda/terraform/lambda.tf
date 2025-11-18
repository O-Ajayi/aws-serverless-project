# Create a ZIP file with Lambda function and dependencies
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_package.zip"
  source_dir  = "${path.module}/../package"

  depends_on = [null_resource.build_package]
}

# Build the Lambda package with dependencies
resource "null_resource" "build_package" {
  triggers = {
    handler_hash    = filemd5("${path.module}/../handler.py")
    requirements_hash = filemd5("${path.module}/../requirements.txt")
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      cd ${path.module}/..
      
      # Create package directory
      rm -rf package
      mkdir -p package
      
      # Copy handler and dependencies
      cp handler.py package/
      
      # Install dependencies
      if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt -t package/ --no-deps || true
        pip install -r requirements.txt -t package/ || true
      fi
      
      # Copy local packages if they exist
      if [ -d "../experiment_bofa" ]; then
        cp -r ../experiment_bofa package/ 2>/dev/null || true
      fi
      
      # Copy experiment_runner_lite if it exists in the project root
      if [ -d "../../../experiment_runner_lite" ]; then
        cp -r ../../../experiment_runner_lite package/ 2>/dev/null || true
      fi
      
      # Copy experiment_broker_logging if it exists
      if [ -d "../../../Experiment-Broker-Logging-Module" ]; then
        cp -r ../../../Experiment-Broker-Logging-Module/experiment_broker_logging package/ 2>/dev/null || true
      fi
      
      echo "Package built successfully"
    EOT
  }
}

# Lambda function
resource "aws_lambda_function" "handler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.function_name
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = var.runtime
  timeout          = var.timeout
  memory_size      = var.memory_size

  environment {
    variables = {
      # AWS_REGION           = var.aws_region
      EXPERIMENT_BUCKET    = aws_s3_bucket.experiment_bucket.id
      OUTPUT_BUCKET        = aws_s3_bucket.experiment_bucket.id
      OUTPUT_PATH          = "results/"
      ENVIRONMENT          = var.environment
      # Note: local_mode should be set per-invocation, not as environment variable
      # Setting default to false for Lambda execution
      local_mode           = "false"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.function_name
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_cloudwatch_log_group.lambda_logs
  ]
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14

  tags = merge(
    var.tags,
    {
      Name = "${var.function_name}-logs"
    }
  )
}

# Lambda function URL (optional - for HTTP invocations)
resource "aws_lambda_function_url" "handler_url" {
  function_name      = aws_lambda_function.handler.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = false
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["date", "keep-alive"]
    max_age          = 86400
  }
}

# Outputs
output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.handler.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.handler.arn
}

output "lambda_function_url" {
  description = "URL of the Lambda function"
  value       = aws_lambda_function_url.handler_url.function_url
}

output "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.handler.invoke_arn
}

