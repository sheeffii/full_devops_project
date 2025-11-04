// IAM permissions for the GitHub Actions CI user to push to ECR

data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "ecr_push_team7_app" {
  name        = "ecr-push-team7-app"
  description = "Allow push/pull to team7-app ECR repo and get auth token"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "ECRGetAuthToken",
        Effect   = "Allow",
        Action   = "ecr:GetAuthorizationToken",
        Resource = "*"
      },
      {
        Sid    = "ECRPushPullTeam7App",
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:InitiateLayerUpload",
          "ecr:ListImages",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ],
        Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/team7-app"
      }
    ]
  })
}

// Attach the policy to the CI IAM user only when ci_user_name is provided
resource "aws_iam_user_policy_attachment" "ci_user_attach_ecr_push" {
  user       = var.ci_user_name
  policy_arn = aws_iam_policy.ecr_push_team7_app.arn
}


