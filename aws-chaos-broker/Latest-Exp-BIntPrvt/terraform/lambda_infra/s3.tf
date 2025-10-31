resource "aws_s3_bucket" "experiments_bucket" {
  bucket = "${var.experiment_bucket}-${var.environment_id}"
}

resource "aws_s3_bucket_public_access_block" "experiments_bucket_acl" {
  bucket = aws_s3_bucket.experiments_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "experiments_bucket_versioning" {
  bucket = aws_s3_bucket.experiments_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "experiments_bucket_sse" {
  bucket = aws_s3_bucket.experiments_bucket.id

    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
      }
    }
}

# resource "aws_s3_object" "lambda_file" {
#   bucket     = var.experiment_bucket
#   key        = "experiment_code_lambda-${var.owner}.zip"
#   source     = data.archive_file.lambda_source_package.output_path
#   depends_on = [data.archive_file.lambda_source_package]
#   kms_key_id = aws_kms_key.s3_key.arn
# }