# REAL AWS ONLY. Redis for the Checkout service.
resource "aws_elasticache_subnet_group" "this" {
  count      = var.create_elasticache ? 1 : 0
  name       = "${var.project}-redis"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_replication_group" "checkout" {
  count                      = var.create_elasticache ? 1 : 0
  replication_group_id       = "${var.project}-checkout"
  description                = "Checkout cache"
  engine                     = "redis"
  engine_version             = "7.1"
  node_type                  = "cache.t4g.micro"
  num_cache_clusters         = 1               # prod: 2+ with automatic_failover_enabled = true
  subnet_group_name          = aws_elasticache_subnet_group.this[0].name
  security_group_ids         = [aws_security_group.data[0].id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = false           # app must use TLS if you turn this on
}
