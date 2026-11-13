variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "careconnect-eks"
}

variable "vpc_id" {
  description = "From the 01-eks-terraform output: terraform output vpc_id"
  type        = string
}
