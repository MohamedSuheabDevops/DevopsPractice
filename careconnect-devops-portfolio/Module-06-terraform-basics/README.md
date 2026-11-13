# Module-06: Terraform Basics (Infrastructure as Code)

**Course section 6 (7 demos) · Status:** ☐ not started  ☐ done

## What this shows
Terraform fundamentals, ending with a reusable VPC module. Each folder is a complete Terraform project. They run **free on a local AWS emulator** (default) or on real AWS (`-var use_emulator=false`).

| Demo | Folder | Concepts |
|---|---|---|
| 1. Install tools | (below) | AWS CLI, Terraform, kubectl |
| 2. Foundation | `01-foundation` | providers, resources, variables, outputs, data sources |
| 3. Production VPC | `02-vpc` | public and private subnets, internet gateway, NAT, route tables |
| 4. VPC with tfvars | `03-vpc-tfvars` | variable management, `dev.tfvars` and `prod.tfvars` |
| 5. Remote backend | `04-remote-backend-bootstrap` | S3 state bucket and DynamoDB lock table |
| 6. VPC with remote backend | `05-vpc-remote-backend` | state stored in S3 with locking |
| 7. VPC module | `06-vpc-module` | reusable module used for dev and prod |

## Demo 1: install the tools
```
aws --version
terraform version
kubectl version --client
```
Terraform install on Ubuntu: https://developer.hashicorp.com/terraform/install

## Run it (pattern for every folder)
```
cd Module-06-terraform-basics/03-vpc-tfvars
terraform init
terraform validate
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars        # needs the emulator or real AWS
terraform destroy -var-file=dev.tfvars
```
The emulator endpoint defaults to `http://localhost:4566`; change it with `-var endpoint=...`.

## Key concepts to be able to explain
State and locking, variable precedence, data sources, modules, `count`, and plan before apply.

## Screenshots to take
- `docs/screenshots/module-06-plan.png`: `terraform plan` showing the VPC resources
- `docs/screenshots/module-06-state.png`: `terraform state list` after an apply
