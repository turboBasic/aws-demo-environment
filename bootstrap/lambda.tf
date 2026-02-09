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
# IAM Policy — State Backend Access (S3, DynamoDB, Secrets Manager)
################################################################################

resource "aws_iam_role_policy" "lambda_state_access" {
  name = "${local.name_prefix}-state-access"
  role = aws_iam_role.lambda_destroyer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3StateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.terraform_state.arn,
          "${aws_s3_bucket.terraform_state.arn}/*",
        ]
      },
      {
        Sid    = "DynamoDBLockAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
        ]
        Resource = aws_dynamodb_table.terraform_locks.arn
      },
      {
        Sid    = "SecretsManagerAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Resource = aws_secretsmanager_secret.github_token.arn
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${var.aws_region}.amazonaws.com"
          }
        }
      },
    ]
  })
}

################################################################################
# IAM Policy — Demo Resource Management (for terraform destroy)
################################################################################

resource "aws_iam_role_policy" "lambda_demo_resource_management" {
  name = "${local.name_prefix}-demo-resource-mgmt"
  role = aws_iam_role.lambda_destroyer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2NetworkManagement"
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSecurityGroupRules",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeNatGateways",
          "ec2:DescribeAddresses",
          "ec2:DescribeRouteTables",
          "ec2:DescribeVpcEndpoints",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceAttribute",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeVpcAttribute",
          "ec2:DeleteVpc",
          "ec2:DeleteSubnet",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteInternetGateway",
          "ec2:DeleteNatGateway",
          "ec2:DeleteRouteTable",
          "ec2:DeleteRoute",
          "ec2:DeleteVpcEndpoints",
          "ec2:DetachInternetGateway",
          "ec2:DisassociateRouteTable",
          "ec2:DisassociateAddress",
          "ec2:ReleaseAddress",
          "ec2:TerminateInstances",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
        ]
        Resource = "*"
      },
      {
        Sid    = "ELBManagement"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DeregisterTargets",
        ]
        Resource = "*"
      },
      {
        Sid    = "STSAccess"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
        ]
        Resource = "*"
      },
    ]
  })
}

################################################################################
# Docker Build and Push to ECR
################################################################################

# Ensure buildx builder exists (required for Lambda-compatible images)
resource "null_resource" "ensure_buildx_builder" {
  provisioner "local-exec" {
    command = <<-EOT
      # Check if lambda-builder exists, create if not
      if ! docker buildx inspect lambda-builder >/dev/null 2>&1; then
        docker buildx create --name lambda-builder --driver docker-container --use
      else
        docker buildx use lambda-builder
      fi
    EOT
  }
}

resource "null_resource" "lambda_docker_build" {
  depends_on = [null_resource.ensure_buildx_builder]

  triggers = {
    dockerfile_hash   = filemd5("${path.module}/lambda-destroyer/Dockerfile")
    handler_hash      = filemd5("${path.module}/lambda-destroyer/handler.py")
    requirements_hash = filemd5("${path.module}/lambda-destroyer/requirements.txt")
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      aws ecr get-login-password --region ${var.aws_region} | \
        docker login --username AWS --password-stdin ${aws_ecr_repository.lambda_destroyer.repository_url}
      docker buildx build --platform linux/amd64 \
        --provenance=false --sbom=false \
        --push \
        -t ${aws_ecr_repository.lambda_destroyer.repository_url}:latest \
        ${path.module}/lambda-destroyer
    EOT
  }
}

data "aws_ecr_image" "lambda_destroyer" {
  repository_name = aws_ecr_repository.lambda_destroyer.name
  image_tag       = "latest"

  depends_on = [null_resource.lambda_docker_build]
}

################################################################################
# Lambda Function
################################################################################

resource "aws_lambda_function" "destroyer" {
  function_name = "${local.name_prefix}-destroyer"
  role          = aws_iam_role.lambda_destroyer.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.lambda_destroyer.repository_url}@${data.aws_ecr_image.lambda_destroyer.image_digest}"
  architectures = ["x86_64"]
  timeout       = 900
  memory_size   = 512

  environment {
    variables = {
      GITHUB_REPO    = var.github_repo
      SECRET_ARN     = aws_secretsmanager_secret.github_token.arn
      STATE_BUCKET   = aws_s3_bucket.terraform_state.id
      STATE_KEY      = var.state_key
      STATE_REGION   = var.aws_region
      DYNAMODB_TABLE = aws_dynamodb_table.terraform_locks.id
      TTL_HOURS      = tostring(var.ttl_hours)
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
