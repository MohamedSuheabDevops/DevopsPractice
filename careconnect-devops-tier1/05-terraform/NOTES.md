# Section 6: Terraform Basics (Infrastructure as Code)

You will build, in order: a bucket (concepts), a VPC, the VPC with variables, a remote backend, and a reusable VPC module.
Folders `01` to `06` each hold ONE complete Terraform project. `cd` into one, run the workflow, `destroy`, move on.

## Setup: free, local, with Floci

1. Install Terraform (>= 1.6), then check: `terraform version`
2. Start Floci (your local AWS emulator) the way its docs say and note its endpoint URL/port.
3. Every project has `use_emulator = true` and `endpoint = "http://localhost:4566"` as defaults.
   If Floci uses another port: `terraform plan -var endpoint=http://localhost:<port>`
4. Real AWS later: `-var use_emulator=false` (uses your AWS credentials). NAT gateways and EIPs cost money on real AWS.

> Emulators don't implement every API. If a resource errors on Floci (NAT gateways are a common one),
> use `enable_nat_gateway=false`, or run `terraform plan` only: planning still proves your code is right.

## The workflow (memorise it)

```bash
terraform init          # download providers/modules, configure backend
terraform fmt           # format code
terraform validate      # syntax + internal consistency
terraform plan          # preview: + create  ~ update  - destroy
terraform apply         # do it (type yes, or -auto-approve)
terraform output        # show outputs
terraform state list    # what Terraform manages
terraform destroy       # delete everything
```

## 01-foundation: providers, resources, variables, outputs, data sources

```bash
cd 05-terraform/01-foundation
terraform init
terraform plan
terraform apply
terraform output
terraform apply -var environment=staging
terraform apply -var environment=banana        # fails: validation block
terraform destroy
```
Look at the files: `main.tf` (provider, resources, locals, data), `variables.tf` (types, defaults, validation), `outputs.tf`.

**Variable precedence (later in this list overrides earlier):**
1. `default` in the variable block
2. environment variables `TF_VAR_name`
3. `terraform.tfvars` / `terraform.tfvars.json`
4. `*.auto.tfvars` (alphabetical)
5. `-var` and `-var-file` on the command line (last one given wins)

**Try it:** set the same variable at several levels (for example `TF_VAR_environment=staging` plus `-var environment=prod`) and see which wins.

**Key vocab**
- *resource* creates/manages. *data source* reads existing things. *local* = named expression. *output* = exposed value.
- Reference syntax: `aws_s3_bucket.assets.id`, `var.name`, `local.name`, `data.aws_caller_identity.current.account_id`, `module.vpc.vpc_id`.

## 02-vpc: a real VPC, hardcoded

Public + private subnets across 3 AZs, internet gateway, one NAT gateway per AZ, public route table, private route tables.

```bash
cd ../02-vpc
terraform init && terraform plan
terraform apply
terraform state list
terraform destroy
```
Questions to answer from the code:
- Why does a public subnet need `map_public_ip_on_launch` and a route to the IGW?
- Why do private subnets route to a NAT gateway, and why does the NAT live in a *public* subnet?
- Why one NAT per AZ? (If one AZ fails, the others still have outbound access. Cheaper: a single shared NAT.)
- Why `depends_on = [aws_internet_gateway.this]` on the NAT?
- What do the `kubernetes.io/role/elb` tags do? (EKS load balancer controller finds subnets with them: Section 11.)

`count` vs `for_each`: `count` indexes by number (remove item 0 and everything shifts); `for_each` keys by name (safer). This lab uses `count` for lists; try converting subnets to `for_each`.

## 03-vpc-tfvars: variables + one tfvars file per environment

```bash
cd ../03-vpc-tfvars
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
terraform destroy -var-file=dev.tfvars
terraform plan -var-file=prod.tfvars        # compare: 3 NAT gateways appear
```
Notice the same code, different inputs. Never commit real secrets in tfvars.

## 04 and 05: remote backend with S3 + DynamoDB locking

**Why?** Local state breaks teams: no sharing, no locking, easy to lose. Remote state = shared + versioned + locked (DynamoDB stops two applies at once).

```bash
# 1. bootstrap (local state) creates the bucket and lock table
cd ../04-remote-backend-bootstrap
terraform init && terraform apply

# 2. a project that stores state remotely
cd ../05-vpc-remote-backend
terraform init -backend-config=backend-emulator.hcl
terraform apply -var-file=dev.tfvars
terraform state list                       # now read from S3
terraform force-unlock <LOCK_ID>           # only if a crashed run left a lock
```
Experiment: delete `.terraform/` and `terraform.tfstate*` locally, re-run `init -backend-config=...`: your state is still there.
Migrate local to remote: add `backend.tf`, run `terraform init -migrate-state`.

Real AWS: copy `backend-aws.hcl.example` and make the bucket name unique.
> Note: Terraform 1.10+ can lock with S3 alone (`use_lockfile = true`) and the DynamoDB table is being deprecated. The course (and many employers) still use DynamoDB, so learn both.

## 06-vpc-module: reusable infrastructure

```bash
cd ../06-vpc-module
terraform init
terraform plan          # shows module.vpc_dev.* and module.vpc_prod.*
terraform apply
terraform destroy
```
A module = a folder with `variables.tf` (inputs), `main.tf`, `outputs.tf`.
Rules: no provider blocks inside, expose only needed outputs, validate inputs, version it (git tag) when shared.
Challenge: publish the module in its own GitHub repo and use `source = "github.com/<you>/terraform-aws-vpc?ref=v1.0.0"`.

## Cheat sheet

| Need | Command |
|---|---|
| Show plan as file | `terraform plan -out tf.plan` then `terraform apply tf.plan` |
| One resource only | `terraform apply -target=aws_vpc.this` (debugging only) |
| Import existing | `terraform import aws_s3_bucket.assets <bucket-name>` |
| Rename in state | `terraform state mv a.b c.d` |
| Remove from state | `terraform state rm aws_x.y` |
| Re-create a resource | `terraform apply -replace=aws_nat_gateway.this[0]` |
| Console | `terraform console` |
| Graph | `terraform graph` |

## Interview questions

- **What is state and why is it sensitive?** Maps config to real resources; may contain secrets, so encrypt the bucket and restrict access.
- **What does DynamoDB do in the backend?** State locking to prevent concurrent applies.
- **Plan shows a resource will be destroyed and recreated. Why?** A changed argument is "forces replacement" (e.g., CIDR, name).
- **count vs for_each?** See above.
- **How do you manage dev/staging/prod?** Same module, different tfvars/workspaces/state keys (folders-per-env is the clearest).
- **`terraform refresh` / drift?** Drift = real infra differs from state. `plan` detects it; `apply -refresh-only` updates state.
- **Modules: how do you version them?** Git tags or registry versions.
- **How do you avoid committing secrets?** Variables marked `sensitive`, env vars, a secrets manager; never in `.tfvars` in git.
- **Provisioners?** Last resort; prefer user data/config management.
- **`lifecycle`?** `prevent_destroy`, `create_before_destroy`, `ignore_changes`.
