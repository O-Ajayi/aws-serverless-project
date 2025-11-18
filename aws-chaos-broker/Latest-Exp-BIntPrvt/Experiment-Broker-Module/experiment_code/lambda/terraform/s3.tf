# S3 Bucket for storing experiment files
resource "aws_s3_bucket" "experiment_bucket" {
  bucket = var.s3_bucket_name

  tags = merge(
    var.tags,
    {
      Name        = var.s3_bucket_name
      Purpose     = "Chaos Experiment Storage"
      Environment = var.environment
    }
  )
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "experiment_bucket_versioning" {
  bucket = aws_s3_bucket.experiment_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "experiment_bucket_encryption" {
  bucket = aws_s3_bucket.experiment_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "experiment_bucket_pab" {
  bucket = aws_s3_bucket.experiment_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Policy for Lambda access
resource "aws_s3_bucket_policy" "experiment_bucket_policy" {
  bucket = aws_s3_bucket.experiment_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_role.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.experiment_bucket.arn,
          "${aws_s3_bucket.experiment_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Output S3 bucket information
output "experiment_bucket_name" {
  description = "Name of the S3 bucket for experiments"
  value       = aws_s3_bucket.experiment_bucket.id
}

output "experiment_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.experiment_bucket.arn
}

