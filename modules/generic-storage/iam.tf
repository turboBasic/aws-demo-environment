################################################################################
# IAM User
################################################################################
resource "aws_iam_user" "user" {
  name = var.user_name
}

resource "aws_iam_access_key" "user_key" {
  user = aws_iam_user.user.name
}

################################################################################
# S3 policy
################################################################################
resource "aws_iam_policy" "s3_policy" {
  name = "S3FullAccess-generic-storage"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.bucket.arn,
          "${aws_s3_bucket.bucket.arn}/*"
        ]
      }
    ]
  })
}

################################################################################
# Role (MFA enforced trust)
################################################################################
resource "aws_iam_role" "role" {
  name = "S3AccessRole-generic-storage-${var.user_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_user.user.arn
        }
        Action = "sts:AssumeRole"
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

################################################################################
# Allow assume-role
################################################################################
resource "aws_iam_user_policy" "assume_role" {
  name = "AllowAssumeRole"
  user = aws_iam_user.user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = aws_iam_role.role.arn
      }
    ]
  })
}
