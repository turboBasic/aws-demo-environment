################################################################################
# IAM Role for Lambda
################################################################################

resource "aws_iam_role" "lambda_destroyer" {
  name = "${local.name_prefix}-destroyer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-destroyer-role"
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_destroyer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

################################################################################
# IAM Policy — State Read & Resource Discovery
################################################################################

resource "aws_iam_role_policy" "lambda_state_access" {
  name = "${local.name_prefix}-state-access"
  role = aws_iam_role.lambda_destroyer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3StateReadOnly"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*",
        ]
      },
      {
        Sid    = "ResourceTagDiscovery"
        Effect = "Allow"
        Action = [
          "tag:GetResources",
        ]
        Resource = "*"
      },
    ]
  })
}

################################################################################
# IAM Policy — Expensive Resource Deletion
################################################################################

resource "aws_iam_role_policy" "lambda_demo_resource_management" {
  name = "${local.name_prefix}-demo-resource-mgmt"
  role = aws_iam_role.lambda_destroyer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2DestroyOperations"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeNatGateways",
          "ec2:DescribeAddresses",
          "ec2:TerminateInstances",
          "ec2:DeleteNatGateway",
          "ec2:ReleaseAddress",
        ]
        Resource = "*"
      },
      {
        Sid    = "ELBDestroyOperations"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteTargetGroup",
        ]
        Resource = "*"
      },
      {
        Sid    = "ECSDestroyOperations"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DeleteService",
          "ecs:DescribeServices",
        ]
        Resource = "*"
      },
    ]
  })
}

################################################################################
# Lambda Function (zip deployment)
################################################################################

data "archive_file" "destroyer" {
  type        = "zip"
  source_file = "${path.module}/lambda-destroyer/handler.py"
  output_path = "${path.module}/lambda-destroyer/handler.zip"
}

resource "aws_lambda_function" "destroyer" {
  function_name    = "${local.name_prefix}-destroyer"
  role             = aws_iam_role.lambda_destroyer.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.destroyer.output_path
  source_code_hash = data.archive_file.destroyer.output_base64sha256
  timeout          = 900
  memory_size      = 256

  environment {
    variables = {
      STATE_BUCKET = aws_s3_bucket.terraform_state.id
      STATE_KEY    = var.state_key
      STATE_REGION = var.aws_region
      TTL_MINUTES  = tostring(var.ttl_minutes)
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-destroyer"
  })
}

################################################################################
# EventBridge Schedule (hourly)
################################################################################

resource "aws_cloudwatch_event_rule" "destroyer_schedule" {
  name                = "${local.name_prefix}-destroyer-schedule"
  description         = "Trigger Lambda destroyer every hour to check for expired demo environments"
  schedule_expression = "rate(1 hour)"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-destroyer-schedule"
  })
}

resource "aws_cloudwatch_event_target" "destroyer_lambda" {
  rule      = aws_cloudwatch_event_rule.destroyer_schedule.name
  target_id = "destroyer"
  arn       = aws_lambda_function.destroyer.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.destroyer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.destroyer_schedule.arn
}
