output "node_role_name" {
  description = "Paste into manifests/ec2nodeclass.yaml (spec.role)"
  value       = module.karpenter.node_iam_role_name
}

output "interruption_queue" {
  value = module.karpenter.queue_name
}
