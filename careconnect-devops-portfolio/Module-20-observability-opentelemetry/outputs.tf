output "amp_workspace_id" {
  value = aws_prometheus_workspace.this.id
}

output "amp_remote_write_url" {
  description = "Paste into manifests/collector.yaml"
  value       = "${aws_prometheus_workspace.this.prometheus_endpoint}api/v1/remote_write"
}

output "grafana_endpoint" {
  value = var.create_grafana ? aws_grafana_workspace.this[0].endpoint : null
}
