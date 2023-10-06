resource "aws_cloudwatch_event_rule" "profile_generator_lambda_event_rule" {
  name                = var.event_bridge_name
  description         = var.event_bridge_description
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "profile_generator_lambda_target" {
  arn   = var.target_lambda_arn
  rule  = aws_cloudwatch_event_rule.profile_generator_lambda_event_rule.name
  input = var.input

}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_rw_fallout_retry_step_deletion_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = var.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.profile_generator_lambda_event_rule.arn
}






#################################
######## Put below into main.tf #
#################################




module "event_bridge" {
  source = "./modules/cw_evnt_brdg"

  event_bridge_name        = "profile-generator-lambda-event-rule"
  event_bridge_description = "retry scheduled every 2 min"
  schedule_expression      = "cron(15 5 * * ? *)"
  function_name            = module.lambda_function.lambda_function_name
  target_lambda_arn        = module.lambda_function.lambda_function_arn
  input                    = <<EOF
{
  "instance_id": "myID",
  "instance_status": "Richard"
}
EOF
}

module "event_bridge_second" {
  source = "./modules/cw_evnt_brdg"

  event_bridge_name        = "second_profile-generator-lambda-event-rule"
  event_bridge_description = "retry scheduled every 2 min"
  schedule_expression      = "cron(30 5 * * ? *)"
  function_name            = module.lambda_function.lambda_function_name
  target_lambda_arn        = module.lambda_function.lambda_function_arn
  input                    = <<EOF
{
  "instance_id": "myID",
  "instance_status": "Richard"
}
EOF
}

module "event_bridge_third" {
  source = "./modules/cw_evnt_brdg"

  event_bridge_name        = "third_profile-generator-lambda-event-rule"
  event_bridge_description = "retry scheduled every 2 min"
  schedule_expression      = "cron(45 5 * * ? *)"
  function_name            = module.lambda_function.lambda_function_name
  target_lambda_arn        = module.lambda_function.lambda_function_arn
  input                    = <<EOF
{
  "instance_id": "myID",
  "instance_status": "Richard"
}
EOF
}
