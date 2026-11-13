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

