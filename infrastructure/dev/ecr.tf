resource "aws_ecr_repository" "app_repo" {
  name                 = "team7-app"
  image_tag_mutability = "MUTABLE"  # Allows overwriting tags

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = var.tags
}

# ECR lifecycle policy to clean up untagged images
resource "aws_ecr_lifecycle_policy" "app_lifecycle" {
  repository = aws_ecr_repository.app_repo.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images, remove untagged"
      selection = {
        tagStatus   = "untagged"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}