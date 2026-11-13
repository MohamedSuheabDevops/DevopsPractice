# STEP 2: Everything hardcoded in locals. Works, but to make a prod copy you
# would edit the file. Step 3 fixes that with variables + tfvars.
locals {
  project              = "careconnect"
  environment          = "dev"
  vpc_cidr             = "10.10.0.0/16"
  azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnet_cidrs  = ["10.10.0.0/24", "10.10.1.0/24", "10.10.2.0/24"]
  private_subnet_cidrs = ["10.10.10.0/24", "10.10.11.0/24", "10.10.12.0/24"]
  enable_nat_gateway   = true
}

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

locals {
  name = "${local.project}-${local.environment}"
  tags = merge({}, {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terraform"
  })
}

resource "aws_vpc" "this" {
  cidr_block           = local.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = "${local.name}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${local.name}-igw" })
}

resource "aws_subnet" "public" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags = merge(local.tags, {
    Name                     = "${local.name}-public-${local.azs[count.index]}"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags = merge(local.tags, {
    Name                              = "${local.name}-private-${local.azs[count.index]}"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# one NAT gateway per AZ (high availability). Set enable_nat_gateway=false to save money.
resource "aws_eip" "nat" {
  count  = local.enable_nat_gateway ? length(local.azs) : 0
  domain = "vpc"
  tags   = merge(local.tags, { Name = "${local.name}-nat-eip-${count.index}" })
}

resource "aws_nat_gateway" "this" {
  count         = local.enable_nat_gateway ? length(local.azs) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = merge(local.tags, { Name = "${local.name}-nat-${count.index}" })
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${local.name}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = length(local.azs)
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${local.name}-private-rt-${count.index}" })
}

resource "aws_route" "private_nat" {
  count                  = local.enable_nat_gateway ? length(local.azs) : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
