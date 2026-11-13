terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

provider "aws" {
  region = var.region

  # emulator-only settings (all null/false against real AWS)
  access_key                  = var.use_emulator ? "test" : null
  secret_key                  = var.use_emulator ? "test" : null
  skip_credentials_validation = var.use_emulator
  skip_metadata_api_check     = var.use_emulator
  skip_requesting_account_id  = var.use_emulator
  s3_use_path_style           = var.use_emulator

  dynamic "endpoints" {
    for_each = var.use_emulator ? [1] : []
    content {
      ec2      = var.endpoint
      s3       = var.endpoint
      dynamodb = var.endpoint
      sts      = var.endpoint
      iam      = var.endpoint
    }
  }
}
# Creates the S3 bucket (state) and DynamoDB table (locking) that OTHER projects will use.
# This project itself uses LOCAL state (chicken-and-egg).
resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"   # lets you recover an older state file
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "locks" {
  name         = var.lock_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"   # this exact name is required by the S3 backend

  attribute {
    name = "LockID"
    type = "S"
  }
}

output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}

output "lock_table" {
  value = aws_dynamodb_table.locks.name
}
