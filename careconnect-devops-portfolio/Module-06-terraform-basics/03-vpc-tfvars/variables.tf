variable "region" {
  type    = string
  default = "us-east-1"
}

variable "use_emulator" {
  description = "true = talk to a local AWS emulator (Floci). false = real AWS."
  type        = bool
  default     = true
}

variable "endpoint" {
  description = "Emulator URL. CHECK the port in the Floci docs and change if needed."
  type        = string
  default     = "http://localhost:4566"
}

variable "project" {
  type    = string
  default = "careconnect"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  type = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "azs" {
  description = "Availability zones (we hardcode instead of using a data source so it works on emulators)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "enable_nat_gateway" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
