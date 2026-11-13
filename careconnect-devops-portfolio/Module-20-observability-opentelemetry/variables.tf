variable "region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "careconnect-eks"
}

variable "namespace" {
  description = "Namespace where the collector and apps run"
  type        = string
  default     = "careconnect"
}

variable "enable_container_logs" {
  description = "Install the CloudWatch Observability add-on (Fluent Bit): ships container stdout logs to CloudWatch Logs. Costs money per GB ingested."
  type        = bool
  default     = false
}

variable "create_grafana" {
  description = "Amazon Managed Grafana. Needs IAM Identity Center enabled in your account and costs per active editor/viewer."
  type        = bool
  default     = false
}
