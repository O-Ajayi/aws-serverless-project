variable "aws_region" {
  description = "AWS Account region"
  type        = string
  default     = "us-east-1"
}

variable "env" {
  description = "AWS Environment"
  type        = string
  default     = "dev"
}

variable "function_name" {
  description = "Lambda function nname"
  type        = string
  default     = "reports-api"
}

variable "description" {
  description = "AWS Environment"
  type        = string
  default     = "This is the lambda function that handles report"
}
