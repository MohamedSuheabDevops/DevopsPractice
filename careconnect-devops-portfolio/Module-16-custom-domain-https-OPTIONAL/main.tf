# ---------- Hosted zone ----------
resource "aws_route53_zone" "this" {
  count = var.create_zone ? 1 : 0
  name  = var.domain_name
}

data "aws_route53_zone" "existing" {
  count        = var.create_zone ? 0 : 1
  name         = var.domain_name
  private_zone = false
}

locals {
  zone_id      = var.create_zone ? aws_route53_zone.this[0].zone_id : data.aws_route53_zone.existing[0].zone_id
  name_servers = var.create_zone ? aws_route53_zone.this[0].name_servers : data.aws_route53_zone.existing[0].name_servers
}

# ---------- ACM certificate (apex + wildcard), validated through DNS ----------
resource "aws_acm_certificate" "this" {
  count                     = var.create_certificate ? 1 : 0
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# ACM gives you CNAME records to prove you own the domain. We create them in Route 53.
resource "aws_route53_record" "validation" {
  for_each = var.create_certificate ? {
    for dvo in aws_acm_certificate.this[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true   # apex and wildcard share the same validation record
  zone_id         = local.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
}

# Waits (up to ~45 min) until ACM sees the DNS records and issues the certificate.
resource "aws_acm_certificate_validation" "this" {
  count                   = var.create_certificate ? 1 : 0
  certificate_arn         = aws_acm_certificate.this[0].arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]
}
