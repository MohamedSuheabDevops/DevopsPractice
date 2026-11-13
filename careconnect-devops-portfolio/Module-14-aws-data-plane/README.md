# Module-14: CareConnect with the AWS Data Plane

**Course section 14 (2 demos) · Status:** ☐ not started  ☐ done

## What this shows
Kubernetes runs the stateless services, and **managed AWS services** hold the data:

| Service | AWS data service | File |
|---|---|---|
| appointments | DynamoDB table | `dynamodb-sqs.tf` |
| billing | RDS PostgreSQL + an SQS queue (with a dead-letter queue) | `rds.tf`, `dynamodb-sqs.tf` |
| doctors | RDS MySQL | `rds.tf` |
| booking | ElastiCache Redis + an SQS queue | `elasticache.tf`, `dynamodb-sqs.tf` |

Demo 1 is the data plane setup (Terraform). Demo 2 wires the endpoints into the services (their `env:` values and Pod Identity roles).

## Run it
Free part (DynamoDB and SQS on the emulator, the default):
```
cd Module-14-aws-data-plane
terraform init
terraform apply
terraform output
```
Costly part (RDS and ElastiCache, real AWS, destroy the same day):
```
terraform apply -var use_emulator=false -var create_rds=true -var create_elasticache=true \
  -var vpc_id=<vpc-id> -var 'private_subnet_ids=["subnet-a","subnet-b","subnet-c"]' \
  -var 'allowed_security_group_ids=["<eks-cluster-sg>"]'
```
Then put the endpoints from `terraform output` into `gitops/envs/eks/billing.yaml` (`DB_HOST`), `doctors.yaml` and `booking.yaml` (`REDIS_HOST`).

## Key points
Why managed databases beat running them in the cluster, the dead-letter queue, passwords through Secrets Manager (`manage_master_user_password`), private subnets and security groups.

## Screenshots to take
- `docs/screenshots/module-14-terraform-output.png`: `terraform output`
- `docs/screenshots/module-14-dynamodb.png`: the DynamoDB table (console or CLI)
