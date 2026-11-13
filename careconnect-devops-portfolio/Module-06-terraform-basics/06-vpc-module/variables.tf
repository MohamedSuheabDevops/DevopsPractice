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
variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
