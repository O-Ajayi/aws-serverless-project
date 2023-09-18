# This script creates cloudfront dist/ Amplify/ S3 and Lambda
# Steps Create s3, then lambda and associate both, then create amplify updating the source to s3. Then create the cdn and point it to amplify



provider "aws" {
  region = "us-east-1" # Update with your desired region
}

data "aws_caller_identity" "current" {}


################################## amp/lambda/s3 ##################################

resource "aws_amplify_app" "my_amplify_app" {
  name = "MyAmplifyAppTest"

}

resource "aws_amplify_branch" "my_amplify_branch" {
  app_id                = aws_amplify_app.my_amplify_app.id
  branch_name           = "Test"
  enable_auto_build     = true
  environment_variables = {}

}

resource "aws_s3_bucket" "my_amplify_source_bucket" {
  bucket = "my-amplify-source-bucket-test"
  #   acl    = "public-read"

}


# ##########################
# resource "aws_amplify_domain" "example_amplify_domain" {
#   domain_name = "test.cmcloudlab1751.info" # Replace with your desired domain name
#   app_id      = aws_amplify_app.my_amplify_app.id
# }
# ##########################

# resource "aws_amplify_domain_association" "example_amplify_domain" {
#   domain_name = "cmcloudlab1751.info" # Replace with your desired domain name
#   app_id      = aws_amplify_app.my_amplify_app.id

#   sub_domain {
#     branch_name = aws_amplify_branch.my_amplify_branch.branch_name
#     prefix      = "www"
#   }
# }

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.my_amplify_source_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "example_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.example]
  bucket     = aws_s3_bucket.my_amplify_source_bucket.id
  acl        = "private"
  #   expected_bucket_owner = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket_policy" "allow_access_from_another_account" {
  bucket = aws_s3_bucket.my_amplify_source_bucket.id
  policy = data.aws_iam_policy_document.allow_access_from_another_account.json
}

data "aws_iam_policy_document" "allow_access_from_another_account" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["922726392568"]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.my_amplify_source_bucket.arn,
      "${aws_s3_bucket.my_amplify_source_bucket.arn}/*",
    ]
  }
}



################################## lambda ##################################



data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "test_lambda" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "lambda_function_payload.zip"
  function_name = "sync-s3-amplify"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "python3.9"

  environment {
    variables = {
      foo = "bar"
    }
  }
}


resource "aws_s3_bucket_notification" "aws-lambda-trigger" {
  bucket = aws_s3_bucket.my_amplify_source_bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.test_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    # filter_prefix       = "file-prefix"
    # filter_suffix       = "file-extension"
  }
}
resource "aws_lambda_permission" "test" {
  statement_id   = "AllowS3Invoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.test_lambda.function_name
  principal      = "s3.amazonaws.com"
  source_account = 922726392568
  source_arn     = "arn:aws:s3:::${aws_s3_bucket.my_amplify_source_bucket.id}"
}




################################## cdn ##################################

# provider "aws" {
#   alias  = "us-east-1"
#   region = "us-east-1"
# }

# data "aws_route53_zone" "documents" {
#   name = "cmcloudlab1751.info"
# }

# resource "aws_route53_record" "www" {
#   zone_id = data.aws_route53_zone.documents.zone_id
#   name    = "dev.cmcloudlab1751.info"
#   type    = "A"

#   alias {
#     name                   = aws_cloudfront_distribution.documents.domain_name
#     zone_id                = aws_cloudfront_distribution.documents.hosted_zone_id
#     evaluate_target_health = true
#   }
# }

# resource "aws_acm_certificate" "apex" {
#   provider          = aws.us-east-1
#   domain_name       = "dev.cmcloudlab1751.info"
#   validation_method = "DNS"

#   lifecycle {
#     create_before_destroy = true
#   }
# }

# resource "aws_route53_record" "apex-certificate-validation" {
#   provider = aws.us-east-1
#   for_each = {
#     for dvo in aws_acm_certificate.apex.domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   }

#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 3600
#   type            = each.value.type
#   zone_id         = data.aws_route53_zone.documents.zone_id
# }

# resource "aws_acm_certificate_validation" "apex-certificate" {
#   provider                = aws.us-east-1
#   certificate_arn         = aws_acm_certificate.apex.arn
#   validation_record_fqdns = [for record in aws_route53_record.apex-certificate-validation : record.fqdn]
# }

# resource "aws_cloudfront_origin_access_identity" "documents-identity" {
#   comment = "Cloudfront identity for access to S3 Bucket"
# }

# resource "aws_cloudfront_distribution" "documents" {
#   aliases = [aws_acm_certificate.apex.domain_name]
#   origin {
#     domain_name = aws_amplify_app.example_amplify_domain.domain_name
#     origin_id   = "AmplifyOrigin"

#     s3_origin_config {
#       origin_access_identity = aws_cloudfront_origin_access_identity.documents-identity.cloudfront_access_identity_path
#     }
#   }

#   enabled         = true
#   is_ipv6_enabled = true
#   comment         = "Distribution of signed S3 objects"

#   default_cache_behavior {
#     allowed_methods  = ["GET", "HEAD", "OPTIONS"] # reads only
#     cached_methods   = ["GET", "HEAD"]
#     target_origin_id = "s3"
#     compress         = true

#     # trusted_key_groups = [
#     #   aws_cloudfront_key_group.documents-signing-key-group.id # This to also add to implementation
#     # ]

#     forwarded_values {
#       query_string = false

#       cookies {
#         forward = "none"
#       }
#     }

#     viewer_protocol_policy = "redirect-to-https"
#     min_ttl                = 0
#     default_ttl            = 3600
#     max_ttl                = 86400
#   }

#   ordered_cache_behavior {
#     path_pattern     = "index.html"
#     allowed_methods  = ["GET", "HEAD", "OPTIONS"] # reads only
#     cached_methods   = ["GET", "HEAD"]
#     target_origin_id = "s3"
#     compress         = true

#     # trusted_key_groups = [
#     #   aws_cloudfront_key_group.documents-signing-key-group.id # This to also add to implementation
#     # ]

#     forwarded_values {
#       query_string = false

#       cookies {
#         forward = "none"
#       }
#     }

#     viewer_protocol_policy = "redirect-to-https"
#     min_ttl                = 0
#     default_ttl            = 3600
#     max_ttl                = 86400
#   }

#   price_class = "PriceClass_100"

#   restrictions {
#     geo_restriction {
#       restriction_type = "whitelist"
#       locations        = ["US", "CA"]
#     }
#   }

#   tags = {
#     Name = aws_acm_certificate.apex.domain_name # So it looks nice in the console
#   }

#   # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/secure-connections-supported-viewer-protocols-ciphers.html
#   viewer_certificate {
#     acm_certificate_arn      = aws_acm_certificate.apex.arn
#     ssl_support_method       = "sni-only"
#     minimum_protocol_version = "TLSv1.2_2021"
#   }

#   depends_on = [
#     aws_acm_certificate_validation.apex-certificate
#   ]
# }





######################## leave below commented out


# resource "aws_s3_bucket_policy" "documents" {
#   bucket = aws_s3_bucket.documents.id
#   policy = data.aws_iam_policy_document.documents-cloudfront-policy.json
# }
# data "aws_iam_policy_document" "documents-cloudfront-policy" {
#   statement {
#     effect = "Allow"
#     principals {
#       type        = "AWS"
#       identifiers = [aws_cloudfront_origin_access_identity.documents-identity.iam_arn]
#     }
#     actions = [
#       "s3:GetObject",
#     ]
#     resources = [
#       "${aws_s3_bucket.documents.arn}/*",
#     ]
#   }
# }







# resource "aws_s3_bucket_policy" "my_amplify_bucket_policy" {
#   bucket = aws_s3_bucket.my_amplify_source_bucket.id
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Action    = "s3:GetObject",
#       Effect    = "Allow",
#       Resource  = "${aws_s3_bucket.my_amplify_source_bucket.arn}/*"
#       Principal = "*",
#     }]
#   })

# }

# resource "aws_s3_bucket" "amplify_app_bucket" {
#   bucket = "my-amplify-app-source" # Update with your desired bucket name
#   acl    = "private"

#   versioning {
#     enabled = true
#   }
# }

# resource "aws_amplify_app" "amplify_app" {
#   name = "MyAmplifyApp" # Update with your desired app name

#   repository = aws_s3_bucket.amplify_app_bucket.id
# }

# resource "aws_amplify_branch" "amplify_branch" {
#   app_id            = aws_amplify_app.amplify_app.id
#   branch_name       = "master" # Update with your desired branch name
#   stage             = "PRODUCTION"
#   enable_auto_build = true
# }
