variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "careconnect-eks"
}

variable "karpenter_version" {
  description = "Check the latest stable: https://github.com/aws/karpenter-provider-aws/releases (v1.x). Must support your Kubernetes version."
  type        = string
  default     = "1.12.1"
}

variable "private_subnet_name_pattern" {
  description = "Name tag of your private subnets (Tier 2 VPC module names them careconnect-eks-private-<az>)"
  type        = string
  default     = "careconnect-eks-private-*"
}
