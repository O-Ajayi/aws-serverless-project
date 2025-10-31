resource "aws_iam_role" "step_function_role" {
  name = "step-function-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "step_function_policy" {
  name = "step-function-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = resource.aws_lambda_function.experiment_lambda.arn
      }
    ]
  })

  depends_on = [resource.aws_lambda_function.experiment_lambda]
}

resource "aws_iam_role_policy_attachment" "step_function_policy_attachment" {
  policy_arn = aws_iam_policy.step_function_policy.arn
  role       = aws_iam_role.step_function_role.name
}

resource "aws_sfn_state_machine" "state_machine" {
  name     = "Experiment_broker"
  role_arn = aws_iam_role.step_function_role.arn

  definition = templatefile("${path.module}/state_machine.json", {lambda_arn = aws_lambda_function.experiment_lambda.arn})
}
