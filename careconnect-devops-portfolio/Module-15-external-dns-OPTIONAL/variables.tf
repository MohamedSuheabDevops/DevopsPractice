variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "careconnect-eks"
}

variable "domain_name" {
  description = "ExternalDNS will ONLY manage records under this domain"
  type        = string
}

variable "zone_id" {
  description = "terraform output zone_id from 01-domain-route53-acm"
  type        = string
}

variable "dns_policy" {
  description = "sync = create AND delete records (good for practice, records vanish with the Ingress). upsert-only = never delete (safer in production)."
  type        = string
  default     = "sync"
}
