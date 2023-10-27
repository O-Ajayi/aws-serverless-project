# EventBridge Rule
output "eventbridge_rule_ids" {
  description = "The EventBridge Rule IDs"
  value       = { for k, v in aws_cloudwatch_event_rule.this : k => v.id }
}

output "eventbridge_rule_arns" {
  description = "The EventBridge Rule ARNs"
  value       = { for k, v in aws_cloudwatch_event_rule.this : k => v.arn }
}
