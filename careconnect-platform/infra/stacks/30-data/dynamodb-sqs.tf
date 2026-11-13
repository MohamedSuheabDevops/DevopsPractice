# ---- Carts service: DynamoDB (NoSQL) ----
resource "aws_dynamodb_table" "carts" {
  name         = "${var.project}-carts"
  billing_mode = "PAY_PER_REQUEST"      # no capacity planning
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
  attribute {
    name = "customerId"
    type = "S"
  }

  global_secondary_index {
    name            = "idx_global_customerId"
    hash_key        = "customerId"
    projection_type = "ALL"
  }
}

# ---- Orders service: SQS queue with a dead-letter queue ----
resource "aws_sqs_queue" "orders_dlq" {
  name                      = "${var.project}-orders-dlq"
  message_retention_seconds = 1209600   # 14 days
}

resource "aws_sqs_queue" "orders" {
  name                       = "${var.project}-orders"
  visibility_timeout_seconds = 30
  receive_wait_time_seconds  = 10        # long polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_dlq.arn
    maxReceiveCount     = 3             # after 3 failed receives, move to the DLQ
  })
}
