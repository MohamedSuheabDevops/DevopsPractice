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

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "enable_versioning" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = { Owner = "devops-practice" }
}
