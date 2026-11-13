module "vpc" {
  source = "../../modules/vpc"

  project              = "careconnect"
  environment          = "eks"
  vpc_cidr             = "10.30.0.0/16"
  azs                  = var.azs
  public_subnet_cidrs  = ["10.30.0.0/24", "10.30.1.0/24", "10.30.2.0/24"]
  private_subnet_cidrs = ["10.30.10.0/24", "10.30.11.0/24", "10.30.12.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true   # cost saver for practice. Use false in real production.
}
