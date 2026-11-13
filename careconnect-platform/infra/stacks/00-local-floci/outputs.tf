output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "carts_table" {
  value = aws_dynamodb_table.carts.name
}

output "orders_queue_url" {
  value = aws_sqs_queue.orders.url
}
