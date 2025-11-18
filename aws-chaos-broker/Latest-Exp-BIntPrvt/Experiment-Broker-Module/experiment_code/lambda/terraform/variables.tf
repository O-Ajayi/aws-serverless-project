variable "aws_region" {
  description = "AWS region for Lambda function"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "chaos-broker-handler"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for experiments"
  type        = string
  default     = "experiment-bucket-111222333"
}

variable "runtime" {
  description = "Python runtime version"
  type        = string
  default     = "python3.11"
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 900  # 15 minutes
}

variable "memory_size" {
  description = "Lambda function memory in MB"
  type        = number
  default     = 512
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

