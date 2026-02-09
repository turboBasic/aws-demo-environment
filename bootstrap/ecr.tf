resource "aws_ecr_repository" "lambda_destroyer" {
  name                 = "${local.name_prefix}-destroyer"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-destroyer"
  })
}

resource "aws_ecr_lifecycle_policy" "lambda_destroyer" {
  repository = aws_ecr_repository.lambda_destroyer.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 3 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 3
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
