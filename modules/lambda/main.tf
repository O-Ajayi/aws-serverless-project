data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  create = var.create

  # archive_filename        = try(data.external.archive_prepare[0].result.filename, null)
  # archive_filename_string = local.archive_filename != null ? local.archive_filename : ""
  # archive_was_missing     = try(data.external.archive_prepare[0].result.was_missing, false)

  # Use a generated filename to determine when the source code has changed.
  # filename - to get package from local
  # filename    = var.local_existing_package != null ? var.local_existing_package : (var.store_on_s3 ? null : local.archive_filename)
  # was_missing = var.local_existing_package != null ? !fileexists(var.local_existing_package) : local.archive_was_missing

  # # s3_* - to get package from S3
  # s3_bucket         = var.s3_existing_package != null ? try(var.s3_existing_package.bucket, null) : (var.store_on_s3 ? var.s3_bucket : null)
  # s3_key            = var.s3_existing_package != null ? try(var.s3_existing_package.key, null) : (var.store_on_s3 ? var.s3_prefix != null ? format("%s%s", var.s3_prefix, replace(local.archive_filename_string, "/^.*//", "")) : replace(local.archive_filename_string, "/^\\.//", "") : null)
  # s3_object_version = var.s3_existing_package != null ? try(var.s3_existing_package.version_id, null) : (var.store_on_s3 ? try(aws_s3_object.lambda_package[0].version_id, null) : null)

}

resource "aws_lambda_function" "this" {
  count = local.create && var.create_function && !var.create_layer ? 1 : 0

  function_name    = var.function_name
  description      = var.description
  role             = var.lambda_role
  filename         = var.filename
  source_code_hash = var.source_code_hash
  # role                               = var.create_role ? aws_iam_role.lambda[0].arn : var.lambda_role
  handler                            = var.package_type != "Zip" ? null : var.handler
  memory_size                        = var.memory_size
  reserved_concurrent_executions     = var.reserved_concurrent_executions
  runtime                            = var.package_type != "Zip" ? null : var.runtime
  layers                             = var.layers
  timeout                            = var.lambda_at_edge ? min(var.timeout, 30) : var.timeout
  kms_key_arn                        = var.kms_key_arn
  image_uri                          = var.image_uri
  package_type                       = var.package_type
  architectures                      = var.architectures
  code_signing_config_arn            = var.code_signing_config_arn
  replace_security_groups_on_destroy = var.replace_security_groups_on_destroy
  replacement_security_group_ids     = var.replacement_security_group_ids

  /* ephemeral_storage is not supported in gov-cloud region, so it should be set to `null` */
  dynamic "ephemeral_storage" {
    for_each = var.ephemeral_storage_size == null ? [] : [true]

    content {
      size = var.ephemeral_storage_size
    }
  }

  # filename         = local.filename
  # source_code_hash = var.ignore_source_code_hash ? null : (local.filename == null ? false : fileexists(local.filename)) && !local.was_missing ? filebase64sha256(local.filename) : null

  # s3_bucket         = local.s3_bucket
  # s3_key            = local.s3_key
  # s3_object_version = local.s3_object_version

  # dynamic "image_config" {
  #   for_each = length(var.image_config_entry_point) > 0 || length(var.image_config_command) > 0 || var.image_config_working_directory != null ? [true] : []
  #   content {
  #     entry_point       = var.image_config_entry_point
  #     command           = var.image_config_command
  #     working_directory = var.image_config_working_directory
  #   }
  # }

  dynamic "environment" {
    for_each = length(keys(var.environment_variables)) == 0 ? [] : [true]
    content {
      variables = var.environment_variables
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_target_arn == null ? [] : [true]
    content {
      target_arn = var.dead_letter_target_arn
    }
  }

  dynamic "tracing_config" {
    for_each = var.tracing_mode == null ? [] : [true]
    content {
      mode = var.tracing_mode
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_subnet_ids != null && var.vpc_security_group_ids != null ? [true] : []
    content {
      security_group_ids = var.vpc_security_group_ids
      subnet_ids         = var.vpc_subnet_ids
    }
  }

  dynamic "file_system_config" {
    for_each = var.file_system_arn != null && var.file_system_local_mount_path != null ? [true] : []
    content {
      local_mount_path = var.file_system_local_mount_path
      arn              = var.file_system_arn
    }
  }

  dynamic "snap_start" {
    for_each = var.snap_start ? [true] : []

    content {
      apply_on = "PublishedVersions"
    }
  }

  timeouts {
    create = try(var.timeouts.create, null)
    update = try(var.timeouts.update, null)
    delete = try(var.timeouts.delete, null)
  }

  tags = var.tags

  depends_on = [
    #   null_resource.archive,
    #   aws_s3_object.lambda_package,

    #   # Depending on the log group is necessary to allow Terraform to create the log group before AWS can.
    #   # When a lambda function is invoked, AWS creates the log group automatically if it doesn't exist yet.
    #   # Without the dependency, this can result in a race condition if the lambda function is invoked before
    #   # Terraform can create the log group.
    aws_cloudwatch_log_group.lambda

    #   # Before the lambda is created the execution role with all its policies should be ready
    #   aws_iam_role_policy_attachment.additional_inline,
    #   aws_iam_role_policy_attachment.additional_json,
    #   aws_iam_role_policy_attachment.additional_jsons,
    #   aws_iam_role_policy_attachment.additional_many,
    #   aws_iam_role_policy_attachment.additional_one,
    #   aws_iam_role_policy_attachment.async,
    #   aws_iam_role_policy_attachment.logs,
    #   aws_iam_role_policy_attachment.dead_letter,
    #   aws_iam_role_policy_attachment.vpc,
    #   aws_iam_role_policy_attachment.tracing,
  ]
}


# resource "aws_lambda_layer_version" "this" {
#   count = local.create && var.create_layer ? 1 : 0

#   layer_name   = var.layer_name
#   license_info = var.license_info

#   compatible_runtimes      = length(var.compatible_runtimes) > 0 ? var.compatible_runtimes : [var.runtime]
#   compatible_architectures = var.compatible_architectures
#   skip_destroy             = var.layer_skip_destroy

#   filename         = local.filename
#   source_code_hash = var.ignore_source_code_hash ? null : (local.filename == null ? false : fileexists(local.filename)) && !local.was_missing ? filebase64sha256(local.filename) : null

#   s3_bucket         = local.s3_bucket
#   s3_key            = local.s3_key
#   s3_object_version = local.s3_object_version

#   depends_on = [null_resource.archive, aws_s3_object.lambda_package]
# }


# data "aws_cloudwatch_log_group" "lambda" {
#   count = local.create && var.create_function && !var.create_layer && var.use_existing_cloudwatch_log_group ? 1 : 0

#   name = "/aws/lambda/${var.lambda_at_edge ? "us-east-1." : ""}${var.function_name}"
# }

resource "aws_cloudwatch_log_group" "lambda" {
  count = local.create && var.create_function && !var.create_layer && !var.use_existing_cloudwatch_log_group ? 1 : 0
  # for_each = var

  name              = "/aws/lambda/${var.lambda_at_edge ? "us-east-1." : ""}${var.function_name}"
  retention_in_days = var.cloudwatch_logs_retention_in_days
  kms_key_id        = var.cloudwatch_logs_kms_key_id

  tags = merge(var.tags, var.cloudwatch_logs_tags)
}



# resource "aws_cloudwatch_metric_alarm" "calculator-time" {
#   alarm_name          = "hub-mft-calculator-execution-time"
#   comparison_operator = "GreaterThanOrEqualToThreshold"
#   evaluation_periods  = "1"
#   metric_name         = "Duration"
#   namespace           = "AWS/Lambda"
#   period              = "60"
#   statistic           = "Maximum"
#   threshold           = var.function_name.timeout
#   alarm_description   = "Calculator Execution Time"
#   treat_missing_data  = "ignore"

#   # insufficient_data_actions = [
#   #   "${aws_sns_topic.alarms.arn}",
#   # ]

#   # alarm_actions = [
#   #   "${aws_sns_topic.alarms.arn}",
#   # ]

#   # ok_actions = [
#   #   "${aws_sns_topic.alarms.arn}",
#   # ]

#   # dimensions {
#   #   FunctionName = var.function_name
#   #   Resource     = var.function_name
#   # }
# }




resource "aws_cloudwatch_metric_alarm" "error-count" {
  alarm_name          = "hub-eft-${var.function_name}-error-count"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "10"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Calculator Error count of lambda function"
  treat_missing_data  = "ignore"

  # insufficient_data_actions = [
  #   "arn:aws:sns:us-east-1:416496057868:Default_CloudWatch_Alarms_Topic",
  # ]

  # alarm_actions = [
  #   "arn:aws:sns:us-east-1:416496057868:Default_CloudWatch_Alarms_Topic",
  # ]

  # ok_actions = [
  #   "${aws_sns_topic.alarms.arn}",
  # ]

  # dimensions {
  #   FunctionName = var.function_name
  #   Resource     = var.function_name
  # }
}

resource "aws_cloudwatch_metric_alarm" "duration" {
  alarm_name          = "hub-eft-${var.function_name}-duration"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Calculator Error count of lambda function"
  treat_missing_data  = "ignore"

  # insufficient_data_actions = [
  #   "arn:aws:sns:us-east-1:416496057868:Default_CloudWatch_Alarms_Topic",
  # ]

  # alarm_actions = [
  #   "arn:aws:sns:us-east-1:416496057868:Default_CloudWatch_Alarms_Topic",
  # ]

  # ok_actions = [
  #   "${aws_sns_topic.alarms.arn}",
  # ]

  # dimensions {
  #   FunctionName = var.function_name
  #   Resource     = var.function_name
  # }
}



resource "aws_cloudwatch_metric_alarm" "invocation" {
  alarm_name          = "hub-eft-${var.function_name}-invocation"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Invocation"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Calculator Execution Time"
  treat_missing_data  = "ignore"

  # insufficient_data_actions = [
  #   "arn:aws:sns:us-east-1:416496057868:Default_CloudWatch_Alarms_Topic",
  # ]

  # alarm_actions = [
  #   "arn:aws:sns:us-east-1:416496057868:Default_CloudWatch_Alarms_Topic",
  # ]

  # ok_actions = [
  #   "${aws_sns_topic.alarms.arn}",
  # ]

  # dimensions {
  #   FunctionName = var.function_name
  #   Resource     = var.function_name
  # }
}














##########################################################

# resource "aws_cloudwatch_metric_alarm" "calculator-time" {
#   alarm_name          = "${local.project-name}-calculator-execution-time"
#   comparison_operator = "GreaterThanOrEqualToThreshold"
#   evaluation_periods  = "1"
#   metric_name         = "Duration"
#   namespace           = "AWS/Lambda"
#   period              = "60"
#   statistic           = "Maximum"
#   threshold           = aws_lambda_function.calculator.timeout * 1000 * 0.75
#   alarm_description   = "Calculator Execution Time"
#   treat_missing_data  = "ignore"

#   insufficient_data_actions = [
#     "${aws_sns_topic.alarms.arn}",
#   ]

#   alarm_actions = [
#     "${aws_sns_topic.alarms.arn}",
#   ]

#   ok_actions = [
#     "${aws_sns_topic.alarms.arn}",
#   ]

#   dimensions {
#     FunctionName = aws_lambda_function.calculator.function_name
#     Resource     = aws_lambda_function.calculator.function_name
#   }
# }


# resource "aws_cloudwatch_metric_alarm" "this" {
#   count = var.create_metric_alarm ? 1 : 0

#   alarm_name        = var.alarm_name
#   alarm_description = var.alarm_description
#   actions_enabled   = var.actions_enabled

#   alarm_actions             = var.alarm_actions
#   ok_actions                = var.ok_actions
#   insufficient_data_actions = var.insufficient_data_actions

#   comparison_operator = var.comparison_operator
#   evaluation_periods  = var.evaluation_periods
#   threshold           = var.threshold
#   unit                = var.unit

#   datapoints_to_alarm                   = var.datapoints_to_alarm
#   treat_missing_data                    = var.treat_missing_data
#   evaluate_low_sample_count_percentiles = var.evaluate_low_sample_count_percentiles

#   # conflicts with metric_query
#   metric_name        = var.metric_name
#   namespace          = var.namespace
#   period             = var.period
#   statistic          = var.statistic
#   extended_statistic = var.extended_statistic

#   dimensions = var.dimensions

#   # conflicts with metric_name
#   dynamic "metric_query" {
#     for_each = var.metric_query
#     content {
#       id          = lookup(metric_query.value, "id")
#       account_id  = lookup(metric_query.value, "account_id", null)
#       label       = lookup(metric_query.value, "label", null)
#       return_data = lookup(metric_query.value, "return_data", null)
#       expression  = lookup(metric_query.value, "expression", null)
#       period      = lookup(metric_query.value, "period", null)

#       dynamic "metric" {
#         for_each = lookup(metric_query.value, "metric", [])
#         content {
#           metric_name = lookup(metric.value, "metric_name")
#           namespace   = lookup(metric.value, "namespace")
#           period      = lookup(metric.value, "period")
#           stat        = lookup(metric.value, "stat")
#           unit        = lookup(metric.value, "unit", null)
#           dimensions  = lookup(metric.value, "dimensions", null)
#         }
#       }
#     }
#   }
#   threshold_metric_id = var.threshold_metric_id

#   tags = var.tags
# }
