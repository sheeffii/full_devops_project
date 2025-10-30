# Team role for SSM access (attach to team users/roles)
resource "aws_iam_role" "team_dev_role" {
  name = "team7-dev-role"
  description = "Role for team7 dev access to SSM and EC2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::647523695124:user/shefqet.salihu"  # Your team users (adjust account/user ARNs)
        }
      }
    ]
  })

  tags = var.tags
}

# SSM policy for team (StartSession, etc.)
resource "aws_iam_policy" "team_ssm_access" {
  name = "team-ssm-access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:StartSession",
          "ssm:DescribeInstanceInformation",
          "ssm:GetConnectionStatus"
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Attach SSM policy to team role
resource "aws_iam_role_policy_attachment" "team_ssm" {
  role       = aws_iam_role.team_dev_role.name  # Now the role exists
  policy_arn = aws_iam_policy.team_ssm_access.arn
}