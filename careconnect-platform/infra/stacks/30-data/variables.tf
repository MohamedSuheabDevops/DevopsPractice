variable "region" {
  type    = string
  default = "us-east-1"
}

variable "use_emulator" {
  description = "true = Floci/local emulator (DynamoDB + SQS only). false = real AWS."
  type        = bool
  default     = true
}

variable "endpoint" {
  type    = string
  default = "http://localhost:4566"   # check the Floci docs for the real port
}

variable "project" {
  type    = string
  default = "careconnect"
}

# ----- only needed for RDS / ElastiCache on real AWS -----
variable "create_rds" {
  description = "RDS costs money (about $0.02/hr for db.t4g.micro) and takes ~10 min. Real AWS only."
  type        = bool
  default     = false
}

variable "create_elasticache" {
  type    = bool
  default = false
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "private_subnet_ids" {
  type    = list(string)
  default = []
}

variable "allowed_security_group_ids" {
  description = "Who may connect: e.g. the EKS node/cluster security group"
  type        = list(string)
  default     = []
}
