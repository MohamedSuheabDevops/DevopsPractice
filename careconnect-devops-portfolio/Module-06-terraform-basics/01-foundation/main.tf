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

# Concepts: provider, resource, variable, local, output, data source
locals {
  bucket_name = "${var.project}-${var.environment}-assets"
  common_tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

resource "aws_s3_bucket" "assets" {
  bucket = local.bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# data source: READ something that already exists
data "aws_caller_identity" "current" {}
