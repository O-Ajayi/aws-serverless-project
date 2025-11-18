# output "lambda_function_name" {
#   description = "Name of the Lambda function"
#   value       = aws_lambda_function.handler.function_name
# }

# output "lambda_function_arn" {
#   description = "ARN of the Lambda function"
#   value       = aws_lambda_function.handler.arn
# }

# output "lambda_function_url" {
#   description = "Function URL for HTTP invocations"
#   value       = aws_lambda_function_url.handler_url.function_url
# }

# output "lambda_invoke_arn" {
#   description = "Invoke ARN of the Lambda function"
#   value       = aws_lambda_function.handler.invoke_arn
# }

# output "s3_bucket_name" {
#   description = "Name of the S3 bucket for experiments"
#   value       = aws_s3_bucket.experiment_bucket.id
# }

# output "s3_bucket_arn" {
#   description = "ARN of the S3 bucket"
#   value       = aws_s3_bucket.experiment_bucket.arn
# }

# output "iam_role_arn" {
#   description = "ARN of the Lambda IAM role"
#   value       = aws_iam_role.lambda_role.arn
# }

# output "cloudwatch_log_group" {
#   description = "CloudWatch log group name"
#   value       = aws_cloudwatch_log_group.lambda_logs.name
# }

