output "lbc_role_arn" {
  value = aws_iam_role.lbc.arn
}

output "ebs_csi_role_arn" {
  value = aws_iam_role.ebs_csi.arn
}
