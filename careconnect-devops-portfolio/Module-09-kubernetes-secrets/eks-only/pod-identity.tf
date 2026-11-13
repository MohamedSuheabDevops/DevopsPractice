# EKS ONLY (reference). EKS Pod Identity: map a ServiceAccount to an IAM role.
resource "aws_iam_role" "billing" {
  name = "careconnect-billing-pod-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

resource "aws_iam_role_policy" "read_secret" {
  role = aws_iam_role.billing.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = "arn:aws:secretsmanager:us-east-1:<ACCOUNT_ID>:secret:careconnect/billing/db-*"
    }]
  })
}

resource "aws_eks_pod_identity_association" "billing" {
  cluster_name    = "careconnect-eks"
  namespace       = "careconnect"
  service_account = "billing-sa"
  role_arn        = aws_iam_role.billing.arn
}
