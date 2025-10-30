# Create an IAM role for EC2 to access S3
resource "aws_iam_role" "ec2_role" {
  name = "ec2-s3-access-role"
  description = "IAM role for EC2 instances to access S3 bucket"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"     # This is the permission to assume the role
        Effect = "Allow"    
        Principal = {
          Service = "ec2.amazonaws.com"  # This allows EC2 instances to assume the role
        }
      }
    ]
  })
  tags = var.tags
}
# Create a policy to allow S3 access
resource "aws_iam_policy" "s3_access_policy" {
  name = "s3-access-policy"  # Policy to allow S3 access
  description = "Policy to allow EC2 instances to access S3 bucket"  

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# Create an instance profile to attach the role to EC2 instances
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile" 
  role = aws_iam_role.ec2_role.name 
}


# Attach the S3 access policy to the role
resource "aws_iam_role_policy_attachment" "role_policy_attachment" {
  role = aws_iam_role.ec2_role.name # Attach to the IAM role created above
  policy_arn = aws_iam_policy.s3_access_policy.arn   # Attach the S3 access policy
}   

# Attach Amazon SSM Managed Instance Core policy so EC2 can register with SSM
## AmazonSSMManagedInstanceCore is attached via managed_policy_arns on the role
resource "aws_iam_role_policy_attachment" "ec2_ssm_managed" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_ecr_readonly" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}