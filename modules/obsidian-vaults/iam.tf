resource "aws_iam_user" "obsidian" {
  name = var.iam_user_name
  tags = var.tags
}

resource "aws_iam_access_key" "obsidian" {
  user = aws_iam_user.obsidian.name
}

resource "aws_iam_user_policy" "obsidian_s3_access" {
  name = "obsidian-vault-access"
  user = aws_iam_user.obsidian.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.vault.arn
      },
      {
        Sid    = "ObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.vault.arn}/*"
      }
    ]
  })
}
