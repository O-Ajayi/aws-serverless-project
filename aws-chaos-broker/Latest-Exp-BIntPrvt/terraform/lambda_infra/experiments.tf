

# resource "aws_s3_object" "experiment_files" {
#   for_each = fileset("./experiments/", "**")
#   bucket = aws_s3_bucket.experiments_bucket.id
#   key = each.value
#   source = "./experiments/${each.value}"
#   etag = filemd5("./experiments/${each.value}")
#   content_type = "application/x-yaml"
# }