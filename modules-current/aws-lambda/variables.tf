variable "create" {
  description = "Controls whether resources should be created"
  type        = bool
  default     = true
}

variable "filename" {
  description = "Controls whether resources should be created"
  type        = string
  default     = ""
}

variable "source_code_hash" {
  description = "Controls whether resources should be created"
  type        = string
  default     = ""
}



# variable "description" {
#   description = "Lambda Resource Description"
#   type        = string
#   default     = ""
# }

# variable "lambda_role" {
#   description = "Lambda function role"
#   type        = string
#   default     = ""
# }

variable "create_package" {
  description = "Controls whether Lambda package should be created"
  type        = bool
  default     = true
}

variable "create_function" {
  description = "Controls whether Lambda Function resource should be created"
  type        = bool
  default     = true
}

variable "create_layer" {
  description = "Controls whether Lambda Layer resource should be created"
  type        = bool
  default     = false
}

variable "create_role" {
  description = "Controls whether IAM role for Lambda Function should be created"
  type        = bool
  default     = false
}

variable "create_lambda_function_url" {
  description = "Controls whether the Lambda Function URL resource should be created"
  type        = bool
  default     = false
}

variable "create_sam_metadata" {
  description = "Controls whether the SAM metadata null resource should be created"
  type        = bool
  default     = false
}

variable "putin_khuylo" {
  description = "Do you agree that Putin doesn't respect Ukrainian sovereignty and territorial integrity? More info: https://en.wikipedia.org/wiki/Putin_khuylo!"
  type        = bool
  default     = true
}



###########
# Function
###########

variable "lambda_at_edge" {
  description = "Set this to true if using Lambda@Edge, to enable publishing, limit the timeout, and allow edgelambda.amazonaws.com to invoke the function"
  type        = bool
  default     = false
}

variable "lambda_at_edge_logs_all_regions" {
  description = "Whether to specify a wildcard in IAM policy used by Lambda@Edge to allow logging in all regions"
  type        = bool
  default     = true
}

variable "function_name" {
  description = "A unique name for your Lambda Function"
  type        = string
  default     = ""
}

variable "handler" {
  description = "Lambda Function entrypoint in your code"
  type        = string
  default     = ""
}

variable "runtime" {
  description = "Lambda Function runtime"
  type        = string
  default     = ""
}

variable "lambda_role" {
  description = " IAM role ARN attached to the Lambda Function. This governs both who / what can invoke your Lambda Function, as well as what resources our Lambda Function has access to. See Lambda Permission Model for more details."
  type        = string
  default     = ""
}

variable "description" {
  description = "Description of your Lambda Function (or Layer)"
  type        = string
  default     = ""
}

variable "code_signing_config_arn" {
  description = "Amazon Resource Name (ARN) for a Code Signing Configuration"
  type        = string
  default     = null
}

variable "layers" {
  description = "List of Lambda Layer Version ARNs (maximum of 5) to attach to your Lambda Function."
  type        = list(string)
  default     = null
}

variable "architectures" {
  description = "Instruction set architecture for your Lambda function. Valid values are [\"x86_64\"] and [\"arm64\"]."
  type        = list(string)
  default     = null
}

variable "kms_key_arn" {
  description = "The ARN of KMS key to use by your Lambda Function"
  type        = string
  default     = null
}

variable "memory_size" {
  description = "Amount of memory in MB your Lambda Function can use at runtime. Valid value between 128 MB to 10,240 MB (10 GB), in 64 MB increments."
  type        = number
  default     = 128
}

variable "ephemeral_storage_size" {
  description = "Amount of ephemeral storage (/tmp) in MB your Lambda Function can use at runtime. Valid value between 512 MB to 10,240 MB (10 GB)."
  type        = number
  default     = null
}

variable "publish" {
  description = "Whether to publish creation/change as new Lambda Function Version."
  type        = bool
  default     = false
}

variable "reserved_concurrent_executions" {
  description = "The amount of reserved concurrent executions for this Lambda Function. A value of 0 disables Lambda Function from being triggered and -1 removes any concurrency limitations. Defaults to Unreserved Concurrency Limits -1."
  type        = number
  default     = -1
}

variable "timeout" {
  description = "The amount of time your Lambda Function has to run in seconds."
  type        = number
  default     = 3
}

variable "dead_letter_target_arn" {
  description = "The ARN of an SNS topic or SQS queue to notify when an invocation fails."
  type        = string
  default     = null
}

variable "environment_variables" {
  description = "A map that defines environment variables for the Lambda Function."
  type        = map(string)
  default     = {}
}

variable "tracing_mode" {
  description = "Tracing mode of the Lambda Function. Valid value can be either PassThrough or Active."
  type        = string
  default     = null
}

variable "vpc_subnet_ids" {
  description = "List of subnet ids when Lambda Function should run in the VPC. Usually private or intra subnets."
  type        = list(string)
  default     = null
}

variable "vpc_security_group_ids" {
  description = "List of security group ids when Lambda Function should run in the VPC."
  type        = list(string)
  default     = null
}

variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = {}
}

variable "s3_object_tags" {
  description = "A map of tags to assign to S3 bucket object."
  type        = map(string)
  default     = {}
}

variable "s3_object_tags_only" {
  description = "Set to true to not merge tags with s3_object_tags. Useful to avoid breaching S3 Object 10 tag limit."
  type        = bool
  default     = false
}

variable "package_type" {
  description = "The Lambda deployment package type. Valid options: Zip or Image"
  type        = string
  default     = "Zip"
}

variable "image_uri" {
  description = "The ECR image URI containing the function's deployment package."
  type        = string
  default     = null
}

variable "image_config_entry_point" {
  description = "The ENTRYPOINT for the docker image"
  type        = list(string)
  default     = []

}
variable "image_config_command" {
  description = "The CMD for the docker image"
  type        = list(string)
  default     = []
}

variable "image_config_working_directory" {
  description = "The working directory for the docker image"
  type        = string
  default     = null
}

variable "snap_start" {
  description = "(Optional) Snap start settings for low-latency startups"
  type        = bool
  default     = false
}

variable "replace_security_groups_on_destroy" {
  description = "(Optional) When true, all security groups defined in vpc_security_group_ids will be replaced with the default security group after the function is destroyed. Set the replacement_security_group_ids variable to use a custom list of security groups for replacement instead."
  type        = bool
  default     = null
}

variable "replacement_security_group_ids" {
  description = "(Optional) List of security group IDs to assign to orphaned Lambda function network interfaces upon destruction. replace_security_groups_on_destroy must be set to true to use this attribute."
  type        = list(string)
  default     = null
}

variable "timeouts" {
  description = "Define maximum timeout for creating, updating, and deleting Lambda Function resources"
  type        = map(string)
  default     = {}
}



########
# Layer
########

variable "layer_name" {
  description = "Name of Lambda Layer to create"
  type        = string
  default     = ""
}

variable "layer_skip_destroy" {
  description = "Whether to retain the old version of a previously deployed Lambda Layer."
  type        = bool
  default     = false
}

variable "license_info" {
  description = "License info for your Lambda Layer. Eg, MIT or full url of a license."
  type        = string
  default     = ""
}

variable "compatible_runtimes" {
  description = "A list of Runtimes this layer is compatible with. Up to 5 runtimes can be specified."
  type        = list(string)
  default     = []
}

variable "compatible_architectures" {
  description = "A list of Architectures Lambda layer is compatible with. Currently x86_64 and arm64 can be specified."
  type        = list(string)
  default     = null
}

############################
# Lambda Async Event Config
############################

variable "create_async_event_config" {
  description = "Controls whether async event configuration for Lambda Function/Alias should be created"
  type        = bool
  default     = false
}

variable "create_current_version_async_event_config" {
  description = "Whether to allow async event configuration on current version of Lambda Function (this will revoke permissions from previous version because Terraform manages only current resources)"
  type        = bool
  default     = true
}

variable "create_unqualified_alias_async_event_config" {
  description = "Whether to allow async event configuration on unqualified alias pointing to $LATEST version"
  type        = bool
  default     = true
}

variable "maximum_event_age_in_seconds" {
  description = "Maximum age of a request that Lambda sends to a function for processing in seconds. Valid values between 60 and 21600."
  type        = number
  default     = null
}

variable "maximum_retry_attempts" {
  description = "Maximum number of times to retry when the function returns an error. Valid values between 0 and 2. Defaults to 2."
  type        = number
  default     = null
}

variable "destination_on_failure" {
  description = "Amazon Resource Name (ARN) of the destination resource for failed asynchronous invocations"
  type        = string
  default     = null
}

variable "destination_on_success" {
  description = "Amazon Resource Name (ARN) of the destination resource for successful asynchronous invocations"
  type        = string
  default     = null
}

##########################
# Provisioned Concurrency
##########################

variable "provisioned_concurrent_executions" {
  description = "Amount of capacity to allocate. Set to 1 or greater to enable, or set to 0 to disable provisioned concurrency."
  type        = number
  default     = -1
}



############################################
# Lambda Event Source Mapping
############################################

variable "event_source_mapping" {
  description = "Map of event source mapping"
  type        = any
  default     = {}
}

#################
# CloudWatch Logs
#################

variable "use_existing_cloudwatch_log_group" {
  description = "Whether to use an existing CloudWatch log group or create new"
  type        = bool
  default     = false
}

variable "cloudwatch_logs_retention_in_days" {
  description = "Specifies the number of days you want to retain log events in the specified log group. Possible values are: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, and 3653."
  type        = number
  default     = null
}

variable "cloudwatch_logs_kms_key_id" {
  description = "The ARN of the KMS Key to use when encrypting log data."
  type        = string
  default     = null
}

variable "cloudwatch_logs_tags" {
  description = "A map of tags to assign to the resource."
  type        = map(string)
  default     = {}
}

######
# IAM
######

variable "role_name" {
  description = "Name of IAM role to use for Lambda Function"
  type        = string
  default     = null
}

variable "role_description" {
  description = "Description of IAM role to use for Lambda Function"
  type        = string
  default     = null
}

variable "role_path" {
  description = "Path of IAM role to use for Lambda Function"
  type        = string
  default     = null
}

variable "role_force_detach_policies" {
  description = "Specifies to force detaching any policies the IAM role has before destroying it."
  type        = bool
  default     = true
}

variable "role_permissions_boundary" {
  description = "The ARN of the policy that is used to set the permissions boundary for the IAM role used by Lambda Function"
  type        = string
  default     = null
}

variable "role_tags" {
  description = "A map of tags to assign to IAM role"
  type        = map(string)
  default     = {}
}

variable "role_maximum_session_duration" {
  description = "Maximum session duration, in seconds, for the IAM role"
  type        = number
  default     = 3600
}

###########
# Policies
###########

variable "policy_name" {
  description = "IAM policy name. It override the default value, which is the same as role_name"
  type        = string
  default     = null
}

variable "attach_cloudwatch_logs_policy" {
  description = "Controls whether CloudWatch Logs policy should be added to IAM role for Lambda Function"
  type        = bool
  default     = true
}

variable "attach_dead_letter_policy" {
  description = "Controls whether SNS/SQS dead letter notification policy should be added to IAM role for Lambda Function"
  type        = bool
  default     = false
}

variable "attach_network_policy" {
  description = "Controls whether VPC/network policy should be added to IAM role for Lambda Function"
  type        = bool
  default     = false
}

variable "attach_tracing_policy" {
  description = "Controls whether X-Ray tracing policy should be added to IAM role for Lambda Function"
  type        = bool
  default     = false
}

variable "attach_async_event_policy" {
  description = "Controls whether async event policy should be added to IAM role for Lambda Function"
  type        = bool
  default     = false
}

variable "attach_policy_json" {
  description = "Controls whether policy_json should be added to IAM role for Lambda Function"
  type        = bool
  default     = false
}

variable "attach_policy_jsons" {
  description = "Controls whether policy_jsons should be added to IAM role for Lambda Function"
  type        = bool
  default     = false
}

variable "attach_policy" {
  description = "Controls whether policy should be added to IAM role for Lambda Function"
  type        = bool
  default     = false
}

variable "attach_policies" {
  description = "Controls whether list of policies should be added to IAM role for Lambda Function"
  type        = bool
  default     = false
}

variable "policy_path" {
  description = "Path of policies to that should be added to IAM role for Lambda Function"
  type        = string
  default     = null
}

variable "number_of_policy_jsons" {
  description = "Number of policies JSON to attach to IAM role for Lambda Function"
  type        = number
  default     = 0
}

variable "number_of_policies" {
  description = "Number of policies to attach to IAM role for Lambda Function"
  type        = number
  default     = 0
}

variable "attach_policy_statements" {
  description = "Controls whether policy_statements should be added to IAM role for Lambda Function"
  type        = bool
  default     = false
}

variable "trusted_entities" {
  description = "List of additional trusted entities for assuming Lambda Function role (trust relationship)"
  type        = any
  default     = []
}

variable "assume_role_policy_statements" {
  description = "Map of dynamic policy statements for assuming Lambda Function role (trust relationship)"
  type        = any
  default     = {}
}

variable "policy_json" {
  description = "An additional policy document as JSON to attach to the Lambda Function role"
  type        = string
  default     = null
}

variable "policy_jsons" {
  description = "List of additional policy documents as JSON to attach to Lambda Function role"
  type        = list(string)
  default     = []
}

variable "policy" {
  description = "An additional policy document ARN to attach to the Lambda Function role"
  type        = string
  default     = null
}

variable "policies" {
  description = "List of policy statements ARN to attach to Lambda Function role"
  type        = list(string)
  default     = []
}

variable "policy_statements" {
  description = "Map of dynamic policy statements to attach to Lambda Function role"
  type        = any
  default     = {}
}

variable "file_system_arn" {
  description = "The Amazon Resource Name (ARN) of the Amazon EFS Access Point that provides access to the file system."
  type        = string
  default     = null
}

variable "file_system_local_mount_path" {
  description = "The path where the function can access the file system, starting with /mnt/."
  type        = string
  default     = null
}



##########################
# Build artifact settings
##########################

variable "artifacts_dir" {
  description = "Directory name where artifacts should be stored"
  type        = string
  default     = "builds"
}

variable "s3_prefix" {
  description = "Directory name where artifacts should be stored in the S3 bucket. If unset, the path from `artifacts_dir` is used"
  type        = string
  default     = null
}

variable "ignore_source_code_hash" {
  description = "Whether to ignore changes to the function's source code hash. Set to true if you manage infrastructure and code deployments separately."
  type        = bool
  default     = false
}

variable "local_existing_package" {
  description = "The absolute path to an existing zip-file to use"
  type        = string
  default     = null
}

variable "s3_existing_package" {
  description = "The S3 bucket object with keys bucket, key, version pointing to an existing zip-file to use"
  type        = map(string)
  default     = null
}

variable "store_on_s3" {
  description = "Whether to store produced artifacts on S3 or locally."
  type        = bool
  default     = false
}

variable "s3_object_storage_class" {
  description = "Specifies the desired Storage Class for the artifact uploaded to S3. Can be either STANDARD, REDUCED_REDUNDANCY, ONEZONE_IA, INTELLIGENT_TIERING, or STANDARD_IA."
  type        = string
  default     = "ONEZONE_IA" # Cheaper than STANDARD and it is enough for Lambda deployments
}

variable "s3_bucket" {
  description = "S3 bucket to store artifacts"
  type        = string
  default     = null
}

variable "s3_acl" {
  description = "The canned ACL to apply. Valid values are private, public-read, public-read-write, aws-exec-read, authenticated-read, bucket-owner-read, and bucket-owner-full-control. Defaults to private."
  type        = string
  default     = "private"
}

variable "s3_server_side_encryption" {
  description = "Specifies server-side encryption of the object in S3. Valid values are \"AES256\" and \"aws:kms\"."
  type        = string
  default     = null
}

variable "source_path" {
  description = "The absolute path to a local file or directory containing your Lambda source code"
  type        = any # string | list(string | map(any))
  default     = null
}

variable "hash_extra" {
  description = "The string to add into hashing function. Useful when building same source path for different functions."
  type        = string
  default     = ""
}

variable "build_in_docker" {
  description = "Whether to build dependencies in Docker"
  type        = bool
  default     = false
}

variable "docker_file" {
  description = "Path to a Dockerfile when building in Docker"
  type        = string
  default     = ""
}

variable "docker_build_root" {
  description = "Root dir where to build in Docker"
  type        = string
  default     = ""
}

variable "docker_image" {
  description = "Docker image to use for the build"
  type        = string
  default     = ""
}

variable "docker_with_ssh_agent" {
  description = "Whether to pass SSH_AUTH_SOCK into docker environment or not"
  type        = bool
  default     = false
}

variable "docker_pip_cache" {
  description = "Whether to mount a shared pip cache folder into docker environment or not"
  type        = any
  default     = null
}

variable "docker_additional_options" {
  description = "Additional options to pass to the docker run command (e.g. to set environment variables, volumes, etc.)"
  type        = list(string)
  default     = []
}

variable "docker_entrypoint" {
  description = "Path to the Docker entrypoint to use"
  type        = string
  default     = null
}

variable "recreate_missing_package" {
  description = "Whether to recreate missing Lambda package if it is missing locally or not"
  type        = bool
  default     = true
}





####################
##### CW Vars
####################


variable "create_metric_alarm" {
  description = "Whether to create the Cloudwatch metric alarm"
  type        = bool
  default     = true
}

variable "alarm_name" {
  description = "The descriptive name for the alarm. This name must be unique within the user's AWS account."
  type        = string
  default     = null
}

variable "alarm_description" {
  description = "The description for the alarm."
  type        = string
  default     = null
}

variable "comparison_operator" {
  description = "The arithmetic operation to use when comparing the specified Statistic and Threshold. The specified Statistic value is used as the first operand. Either of the following is supported: GreaterThanOrEqualToThreshold, GreaterThanThreshold, LessThanThreshold, LessThanOrEqualToThreshold."
  type        = string
  default     = null
}

variable "evaluation_periods" {
  description = "The number of periods over which data is compared to the specified threshold."
  type        = number
  default     = null
}

variable "threshold" {
  description = "The value against which the specified statistic is compared."
  type        = number
  default     = null
}

variable "threshold_metric_id" {
  description = "If this is an alarm based on an anomaly detection model, make this value match the ID of the ANOMALY_DETECTION_BAND function."
  type        = string
  default     = null
}

variable "unit" {
  description = "The unit for the alarm's associated metric."
  type        = string
  default     = null
}

variable "metric_name" {
  description = "The name for the alarm's associated metric. See docs for supported metrics."
  type        = string
  default     = null
}

variable "namespace" {
  description = "The namespace for the alarm's associated metric. See docs for the list of namespaces. See docs for supported metrics."
  type        = string
  default     = null
}

variable "period" {
  description = "The period in seconds over which the specified statistic is applied."
  type        = string
  default     = null
}

variable "statistic" {
  description = "The statistic to apply to the alarm's associated metric. Either of the following is supported: SampleCount, Average, Sum, Minimum, Maximum"
  type        = string
  default     = null
}

variable "actions_enabled" {
  description = "Indicates whether or not actions should be executed during any changes to the alarm's state. Defaults to true."
  type        = bool
  default     = true
}

variable "datapoints_to_alarm" {
  description = "The number of datapoints that must be breaching to trigger the alarm."
  type        = number
  default     = null
}

variable "dimensions" {
  description = "The dimensions for the alarm's associated metric."
  type        = any
  default     = null
}

variable "alarm_actions" {
  description = "The list of actions to execute when this alarm transitions into an ALARM state from any other state. Each action is specified as an Amazon Resource Name (ARN)."
  type        = list(string)
  default     = null
}

variable "insufficient_data_actions" {
  description = "The list of actions to execute when this alarm transitions into an INSUFFICIENT_DATA state from any other state. Each action is specified as an Amazon Resource Name (ARN)."
  type        = list(string)
  default     = null
}

variable "ok_actions" {
  description = "The list of actions to execute when this alarm transitions into an OK state from any other state. Each action is specified as an Amazon Resource Name (ARN)."
  type        = list(string)
  default     = null
}

variable "extended_statistic" {
  description = "The percentile statistic for the metric associated with the alarm. Specify a value between p0.0 and p100."
  type        = string
  default     = null
}

variable "treat_missing_data" {
  description = "Sets how this alarm is to handle missing data points. The following values are supported: missing, ignore, breaching and notBreaching."
  type        = string
  default     = "missing"
}

variable "evaluate_low_sample_count_percentiles" {
  description = "Used only for alarms based on percentiles. If you specify ignore, the alarm state will not change during periods with too few data points to be statistically significant. If you specify evaluate or omit this parameter, the alarm will always be evaluated and possibly change state no matter how many data points are available. The following values are supported: ignore, and evaluate."
  type        = string
  default     = null
}

variable "metric_query" {
  description = "Enables you to create an alarm based on a metric math expression. You may specify at most 20."
  type        = any
  default     = []
}

# variable "tags" {
#   description = "A mapping of tags to assign to all resources"
#   type        = map(string)
#   default     = {}
# }
