# Module-13: Terraform EKS Cluster with Add-ons

**Course section 13 (1 comprehensive demo) · Status:** ☐ not started  ☐ done  ☐ validated only

## What this shows
Everything installed into the EKS cluster from Module-07, with Terraform:

| Add-on | File | Purpose |
|---|---|---|
| EKS Pod Identity Agent | `pod-identity-roles.tf` | Gives pods AWS permissions without keys |
| EBS CSI driver | `pod-identity-roles.tf` | Disks for PersistentVolumes |
| AWS Load Balancer Controller | `lb-controller.tf` | Turns an Ingress into an ALB |
| Secrets Store CSI driver + AWS provider (ASCP) | `secrets-and-metrics.tf` | Mount AWS Secrets Manager into pods |
| Metrics Server | `secrets-and-metrics.tf` | Needed by `kubectl top` and the HPA (Module-18) |

## Run it (real AWS, cluster from Module-07 must exist)
```
cd Module-13-terraform-eks-addons
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
terraform init
terraform apply -var vpc_id=$(terraform -chdir=../Module-07-terraform-eks-cluster output -raw vpc_id)
kubectl get pods -n kube-system
aws eks list-addons --cluster-name careconnect-eks
aws eks list-pod-identity-associations --cluster-name careconnect-eks
```
No AWS account? Run `terraform init -backend=false && echo '{}' > iam_policy.json && terraform validate` and say "validated" honestly.

## Screenshots to take
- `docs/screenshots/module-13-kube-system.png`: `kubectl get pods -n kube-system` with the controllers running
- `docs/screenshots/module-13-addons.png`: the add-ons list
