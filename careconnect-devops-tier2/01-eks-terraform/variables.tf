variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "careconnect-eks"
}

variable "kubernetes_version" {
  description = "Check supported versions: aws eks describe-cluster-versions --region us-east-1. Pick a standard-support one."
  type        = string
  default     = "1.33"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "admin_principal_arn" {
  description = "Optional extra IAM user/role to give cluster-admin (the creator already gets it)"
  type        = string
  default     = ""
}
