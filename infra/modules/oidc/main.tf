resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
  tags = { Name = "github-actions-oidc" }
}

resource "aws_iam_role" "github_actions" {
  name = "github-actions-blog-app-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*" }
      }
    }]
  })
  tags = { Name = "github-actions-blog-app-role" }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "github-actions-ecr-eks"
  role = aws_iam_role.github_actions.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken","ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer","ecr:BatchGetImage","ecr:PutImage",
          "ecr:InitiateLayerUpload","ecr:UploadLayerPart","ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories","ecr:ListImages"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["eks:ListClusters","eks:DescribeCluster"]
        Resource = "*"
      }
    ]
  })
}
