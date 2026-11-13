variable "region" {
  type    = string
  default = "us-east-1"
}

variable "domain_name" {
  description = "Your domain (example.com) or a delegated subdomain (careconnect.example.com)"
  type        = string
}

variable "create_zone" {
  description = "true = Terraform creates the hosted zone. false = reuse a zone that already exists (e.g. created automatically when you registered the domain in Route 53)."
  type        = bool
  default     = true
}

variable "create_certificate" {
  description = "Phase 2. Leave false until the registrar points at the Route 53 name servers."
  type        = bool
  default     = false
}
