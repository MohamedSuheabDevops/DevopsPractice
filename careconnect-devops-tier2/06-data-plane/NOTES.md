# Section 14: Retail Store (CareConnect) with the AWS Data Plane

**Concept section with a free practice part.** The idea: Kubernetes runs the *stateless* apps (control/compute plane), and **managed AWS services** hold the state (data plane).

| Service | Datastore | AWS service | In this folder |
|---|---|---|---|
| Catalog (Go) | relational | RDS MySQL | `rds.tf` (real AWS) |
| Carts (Spring Boot) | NoSQL | DynamoDB | `dynamodb-sqs.tf` (**free on Floci**) |
| Orders (Spring Boot) | relational + queue | RDS PostgreSQL + SQS | `rds.tf`, `dynamodb-sqs.tf` |
| Checkout (Node.js) | cache | ElastiCache Redis | `elasticache.tf` (real AWS) |

CareConnect mapping: appointments -> PostgreSQL, doctors -> MySQL/MariaDB, carts-style data -> DynamoDB, appointment reminders -> SQS, session/slot cache -> Redis. Same architecture, your own domain.

## Why managed data services?
Backups, patching, Multi-AZ failover, encryption, and scaling are handled for you. Running databases inside Kubernetes (Section 10) is possible but you own all of that.

## Free practice (Floci): DynamoDB and SQS
```bash
cd 06-data-plane
terraform init
terraform apply                           # use_emulator = true by default
aws --endpoint-url http://localhost:4566 dynamodb list-tables        # adjust the port for Floci
aws --endpoint-url http://localhost:4566 dynamodb put-item --table-name careconnect-carts \
  --item '{"id":{"S":"c1"},"customerId":{"S":"u1"}}'
aws --endpoint-url http://localhost:4566 dynamodb query --table-name careconnect-carts \
  --index-name idx_global_customerId --key-condition-expression "customerId = :c" \
  --expression-attribute-values '{":c":{"S":"u1"}}'
aws --endpoint-url http://localhost:4566 sqs send-message --queue-url <orders_queue_url> --message-body '{"order":1}'
aws --endpoint-url http://localhost:4566 sqs receive-message --queue-url <orders_queue_url>
```
(PowerShell: JSON quoting is awkward; save the JSON in a file and use `file://item.json`.)

Dead-letter queue experiment: receive the same message 3 times without deleting it, wait for the visibility timeout each time, then check the DLQ.

## Real AWS practice (optional, costs money)
```bash
terraform apply -var use_emulator=false -var create_rds=true \
  -var vpc_id=<vpc> -var 'private_subnet_ids=["subnet-a","subnet-b","subnet-c"]' \
  -var 'allowed_security_group_ids=["<eks-cluster-sg>"]'
```
RDS takes ~10 minutes to create. **Destroy the same day:** `terraform destroy` with the same `-var` flags.
With `manage_master_user_password = true`, the password lives in Secrets Manager: pods read it via the Secrets Store CSI driver (Tier 1 `07-secrets` + `02-eks-addons`). That is the production pattern: no password in Terraform state files, Git or Helm values.

## How apps reach the data plane
1. **Network:** RDS/ElastiCache sit in private subnets; the security group allows only the EKS node/cluster SG.
2. **Identity:** pods call DynamoDB/SQS using **Pod Identity** (IAM role scoped to one table/queue).
3. **Config:** endpoints pass via ConfigMap/Helm values; passwords via Secrets Manager.
4. **Resilience:** SQS decouples Orders from Checkout; retries + DLQ catch poison messages.

Least-privilege example for the Carts pod role: `dynamodb:GetItem, PutItem, UpdateItem, DeleteItem, Query` on the table ARN and `.../index/*` only.

## Interview questions
- Why use RDS instead of a database in Kubernetes?
- How does a pod authenticate to DynamoDB/SQS without keys?
- What is a dead-letter queue and a visibility timeout?
- DynamoDB on-demand vs provisioned capacity? Partition key design?
- Multi-AZ vs read replicas?
- How do you keep the DB password out of Git and Terraform state? (`manage_master_user_password`, Secrets Manager)
- ElastiCache cluster mode vs replication group? Why is a cache not a source of truth?
