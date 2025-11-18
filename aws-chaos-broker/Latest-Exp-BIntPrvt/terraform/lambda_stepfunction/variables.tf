variable "aws_region" {
  description = "AWS region to deploy the Step Function"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "state_machine_name" {
  description = "Name of the Step Functions state machine"
  type        = string
  default     = "chaos-experiment-runner"
}

variable "lambda_function_arn" {
  description = "ARN of the Lambda handler that executes chaos experiments"
  type        = string
  default     = "arn:aws:lambda:us-east-1:150965600868:function:experiment_lambda"
}

variable "payload_template" {
  description = "Default payload passed to the Step Function (must match handler expectations)"
  type        = any
  default = {
    Payload = {
      list = [
        {
          experiment_source = "Demo-Kubernetes(EKS)-Worker Node (Pod)-State-TerminationCrash.yml"
          bucket_name       = "resiliencyvr-package-build-bucket-demo"
          output_config = {
            S3 = {
              bucket_name = "resiliencyvr-package-build-bucket-demo"
              path        = "experiment_journals"
            }
            OPENSEARCH = {
              index = "resiliency-experiment-journals"
              host  = "search-resiliency-health-index-5kbdxdwunwcdt7u4ti4musfw34.us-east-1.es.amazonaws.com"
            }
          }
        }
      ]
      state = "pending"
    }
  }
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}
