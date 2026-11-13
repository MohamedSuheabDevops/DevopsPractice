output "bucket_name" {
  value = aws_s3_bucket.assets.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.assets.arn
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
