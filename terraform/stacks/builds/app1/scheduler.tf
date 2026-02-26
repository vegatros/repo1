# IAM role for Lambda
resource "aws_iam_role" "ec2_scheduler" {
  name = "${var.project_name}-ec2-scheduler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "ec2_scheduler" {
  name = "${var.project_name}-ec2-scheduler"
  role = aws_iam_role.ec2_scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Create Lambda deployment packages
data "archive_file" "stop_ec2" {
  type        = "zip"
  source_file = "${path.module}/schedule/lambda_stop.py"
  output_path = "${path.module}/schedule/lambda_stop.zip"
}

data "archive_file" "start_ec2" {
  type        = "zip"
  source_file = "${path.module}/schedule/lambda_start.py"
  output_path = "${path.module}/schedule/lambda_start.zip"
}

# Lambda function to stop EC2
resource "aws_lambda_function" "stop_ec2" {
  filename      = data.archive_file.stop_ec2.output_path
  function_name = "${var.project_name}-stop-ec2"
  role          = aws_iam_role.ec2_scheduler.arn
  handler       = "lambda_stop.handler"
  runtime       = "python3.11"
  timeout       = 60
  source_code_hash = data.archive_file.stop_ec2.output_base64sha256

  environment {
    variables = {
      INSTANCE_ID = module.ec2.instance_ids[0]
    }
  }
}

# Lambda function to start EC2
resource "aws_lambda_function" "start_ec2" {
  filename      = data.archive_file.start_ec2.output_path
  function_name = "${var.project_name}-start-ec2"
  role          = aws_iam_role.ec2_scheduler.arn
  handler       = "lambda_start.handler"
  runtime       = "python3.11"
  timeout       = 60
  source_code_hash = data.archive_file.start_ec2.output_base64sha256

  environment {
    variables = {
      INSTANCE_ID = module.ec2.instance_ids[0]
    }
  }
}

# EventBridge rule to stop at 12 AM ET (5 AM UTC)
resource "aws_cloudwatch_event_rule" "stop_ec2" {
  name                = "${var.project_name}-stop-ec2"
  description         = "Stop EC2 at 12 AM ET"
  schedule_expression = "cron(0 5 * * ? *)"
}

resource "aws_cloudwatch_event_target" "stop_ec2" {
  rule      = aws_cloudwatch_event_rule.stop_ec2.name
  target_id = "StopEC2"
  arn       = aws_lambda_function.stop_ec2.arn
}

resource "aws_lambda_permission" "stop_ec2" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_ec2.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_ec2.arn
}

# EventBridge rule to start at 6 AM ET (11 AM UTC)
resource "aws_cloudwatch_event_rule" "start_ec2" {
  name                = "${var.project_name}-start-ec2"
  description         = "Start EC2 at 6 AM ET"
  schedule_expression = "cron(0 11 * * ? *)"
}

resource "aws_cloudwatch_event_target" "start_ec2" {
  rule      = aws_cloudwatch_event_rule.start_ec2.name
  target_id = "StartEC2"
  arn       = aws_lambda_function.start_ec2.arn
}

resource "aws_lambda_permission" "start_ec2" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_ec2.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_ec2.arn
}
