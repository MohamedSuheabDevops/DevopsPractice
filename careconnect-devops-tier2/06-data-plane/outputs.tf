output "carts_table" {
  value = aws_dynamodb_table.carts.name
}

output "orders_queue_url" {
  value = aws_sqs_queue.orders.url
}

output "orders_dlq_arn" {
  value = aws_sqs_queue.orders_dlq.arn
}

output "catalog_mysql_endpoint" {
  value = var.create_rds ? aws_db_instance.catalog_mysql[0].address : null
}

output "orders_postgres_endpoint" {
  value = var.create_rds ? aws_db_instance.orders_postgres[0].address : null
}

output "redis_endpoint" {
  value = var.create_elasticache ? aws_elasticache_replication_group.checkout[0].primary_endpoint_address : null
}
