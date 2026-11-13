module "vpc" {
  source = "../../modules/vpc"

  project              = var.project
  environment          = "local"
  vpc_cidr             = "10.50.0.0/16"
  azs                  = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnet_cidrs  = ["10.50.0.0/24", "10.50.1.0/24", "10.50.2.0/24"]
  private_subnet_cidrs = ["10.50.10.0/24", "10.50.11.0/24", "10.50.12.0/24"]
  enable_nat_gateway   = false   # keep the emulator simple
}
