resource "aws_ecr_repository" "app_repo" {
  name                 = "team7-app"
  image_tag_mutability = "MUTABLE"  # Allows overwriting tags
  force_delete = true            # Allow deletion even if not empty
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

# Discord Bot ECR Repository
resource "aws_ecr_repository" "discord_bot_repo" {
  name                 = "discord-bot"
  image_tag_mutability = "MUTABLE"
  force_delete = true            # Allow deletion even if not empty

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name        = "discord-bot-ecr"
    Description = "Discord bot container images"
  })
}

# ECR lifecycle policy for Discord bot
resource "aws_ecr_lifecycle_policy" "discord_bot_lifecycle" {
  repository = aws_ecr_repository.discord_bot_repo.name

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