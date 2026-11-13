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
module "vpc_dev" {
  source = "./modules/vpc"

  project              = "careconnect"
  environment          = "dev"
  vpc_cidr             = "10.10.0.0/16"
  azs                  = var.azs
  public_subnet_cidrs  = ["10.10.0.0/24", "10.10.1.0/24", "10.10.2.0/24"]
  private_subnet_cidrs = ["10.10.10.0/24", "10.10.11.0/24", "10.10.12.0/24"]
  enable_nat_gateway   = false
}

# Same module, second environment: this is the whole point of modules.
module "vpc_prod" {
  source = "./modules/vpc"

  project              = "careconnect"
  environment          = "prod"
  vpc_cidr             = "10.20.0.0/16"
  azs                  = var.azs
  public_subnet_cidrs  = ["10.20.0.0/24", "10.20.1.0/24", "10.20.2.0/24"]
  private_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24", "10.20.12.0/24"]
  enable_nat_gateway   = true
}

output "dev_vpc_id" {
  value = module.vpc_dev.vpc_id
}

output "prod_private_subnets" {
  value = module.vpc_prod.private_subnet_ids
}
