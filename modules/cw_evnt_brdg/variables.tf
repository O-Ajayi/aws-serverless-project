# variable "create_event_bridge" {
#   description = "Controls whether event bridge should be created"
#   type        = bool
#   default     = false
# }

variable "event_bridge_name" {
  description = "Event Bridge Name"
  type        = string
  default     = ""

}

variable "event_bridge_description" {
  description = "Event Bridge Description"
  type        = string
  default     = ""

}

variable "schedule_expression" {
  description = "Scheduled expression"
  type        = string
  default     = ""
}

variable "target_lambda_arn" {
  description = "Lambda function arn"
  type        = string
  default     = ""
}

variable "function_name" {
  description = "Lambda function arn"
  type        = string
  default     = ""
}

variable "input" {
  type    = string
  default = ""
}

# variable "shared_credentials_file" {
#   description = "Profile file with credentials to the AWS account"
#   type        = string
#   default     = "~/.aws/credentials"
# }

# variable "tags" {
#   description = "A map of tags to add to all resources."
#   type        = map(string)
#   default = {
#     application = "SmartGuy"
#     env         = "Dev"
#   }
# }
