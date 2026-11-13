output "zone_id" {
  value = local.zone_id
}

output "name_servers" {
  description = "Put these 4 at your registrar (skip if you registered the domain in Route 53)"
  value       = local.name_servers
}

output "certificate_arn" {
  value = var.create_certificate ? aws_acm_certificate_validation.this[0].certificate_arn : null
}
