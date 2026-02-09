resource "aws_secretsmanager_secret" "github_token" {
  name        = "${local.name_prefix}/github-token"
  description = "GitHub personal access token for cloning the demo environment repository"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-github-token"
  })
}

resource "aws_secretsmanager_secret_version" "github_token" {
  secret_id     = aws_secretsmanager_secret.github_token.id
  secret_string = var.github_token
}
