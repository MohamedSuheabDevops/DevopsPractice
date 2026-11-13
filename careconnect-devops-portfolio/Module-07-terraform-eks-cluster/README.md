# Module-07: Complete AWS EKS Cluster with Terraform

**Course section 7 (1 comprehensive demo) · Status:** ☐ not started  ☐ done  ☐ validated only

## What this shows
An EKS cluster built entirely from code: the VPC (reusing the module from Module-06), IAM roles for the cluster and the nodes, a managed node group in private subnets, core add-ons, and access for your IAM user.

| File | Purpose |
|---|---|
| `vpc.tf`, `modules/vpc` | Network with a single NAT gateway (cheaper for practice) |
| `eks.tf` | Cluster role, cluster, node role, node group, VPC CNI / kube-proxy / CoreDNS add-ons, access entries |
| `variables.tf`, `outputs.tf` | Inputs and the `update-kubeconfig` command |

## Cost warning
Real AWS only. About **$0.25 per hour** while running (control plane, 2 nodes, NAT). Create an AWS Budget alert first and destroy the same day.

## Run it
```
cd Module-07-terraform-eks-cluster
terraform init
terraform validate                     # free, no AWS account needed
terraform plan                         # needs AWS credentials
terraform apply                        # about 15 minutes
aws eks update-kubeconfig --region us-east-1 --name careconnect-eks
kubectl get nodes
kubectl get pods -A
terraform destroy                      # delete Kubernetes load balancers and volumes first (see Module-19)
```

## Screenshots to take
- `docs/screenshots/module-07-eks-console.png`: the EKS cluster and node group in the AWS console
- `docs/screenshots/module-07-kubectl-nodes.png`: `kubectl get nodes` against EKS
(If you only validated, screenshot `terraform validate` and say so honestly in the main README.)
