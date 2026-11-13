# Terraform for the OIDC trust (real AWS). Run once per AWS account.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # AWS now validates GitHub's cert itself; value kept for older provider versions
}

resource "aws_iam_role" "github_ci" {
  name = "github-actions-ecr-push"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        # ONLY your repo (and only version tags) can assume this role:
        StringLike = { "token.actions.githubusercontent.com:sub" = "repo:<github-user>/<repo>:ref:refs/tags/v*" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "ecr_push" {
  role = aws_iam_role.github_ci.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"
        ]
        Resource = "arn:aws:ecr:us-east-1:<ACCOUNT_ID>:repository/careconnect/*"
      }
    ]
  })
}

resource "aws_ecr_repository" "appointment" {
  name                 = "careconnect/appointment-service"
  image_tag_mutability = "IMMUTABLE"   # a tag can never be overwritten
  image_scanning_configuration { scan_on_push = true }
}
