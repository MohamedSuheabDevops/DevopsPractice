# Section 13: EKS Add-ons with Terraform

Needs the cluster from `01-eks-terraform` (real AWS, costs money while running).

## What gets installed

| Add-on | Why | How installed |
|---|---|---|
| **Pod Identity Agent** | gives pods AWS credentials without keys | EKS managed add-on |
| **EBS CSI driver** | PersistentVolumeClaims backed by EBS | EKS managed add-on + Pod Identity role |
| **AWS Load Balancer Controller** | Ingress -> ALB, Service(LoadBalancer) -> NLB | Helm + Pod Identity role |
| **Secrets Store CSI + ASCP** | mount AWS Secrets Manager into pods | Helm |
| **Metrics Server** | `kubectl top`, HPA | Helm |

## Run it
```bash
cd 02-eks-addons
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
terraform init
terraform apply -var vpc_id=$(terraform -chdir=../01-eks-terraform output -raw vpc_id)
```
PowerShell: `$vpc = terraform -chdir=../01-eks-terraform output -raw vpc_id` then `terraform apply -var vpc_id=$vpc`.

## Verify
```bash
kubectl get pods -n kube-system
kubectl get daemonset -n kube-system eks-pod-identity-agent
kubectl get deploy -n kube-system aws-load-balancer-controller
kubectl logs -n kube-system deploy/aws-load-balancer-controller | head
kubectl get csidrivers
kubectl get storageclass
kubectl top nodes
aws eks list-addons --cluster-name careconnect-eks
aws eks list-pod-identity-associations --cluster-name careconnect-eks
```

## Concepts

**Pod Identity flow:** pod calls AWS SDK -> SDK asks the node-local agent (169.254.170.23) for credentials -> agent checks the pod's ServiceAccount against the *association* -> returns temporary credentials for the mapped IAM role.
The IAM role trusts `pods.eks.amazonaws.com`. No annotation on the ServiceAccount needed (unlike IRSA).

**Why does the LB controller need IAM?** It creates ALBs, target groups, listeners and security group rules in your account.

**Managed add-on vs Helm:** EKS add-ons are versioned and upgraded by AWS (`aws eks describe-addon-versions`). Helm gives you more control for things AWS doesn't ship.

**Terraform gotchas**
- Helm/Kubernetes providers need the cluster to exist: apply cluster first, add-ons second (separate projects, as here).
- Destroy add-ons **before** the cluster, and delete Ingresses first so the controller can remove ALBs.
- If `terraform destroy` hangs on the VPC, look for leftover ALBs, ENIs and security groups.

## Exercises
1. Break it on purpose: `kubectl delete pod -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller` and watch it come back (self-healing).
2. Remove the Pod Identity association (`terraform destroy -target=aws_eks_pod_identity_association.lbc`), restart the controller, read its logs: `AccessDenied`. Re-apply.
3. `aws eks describe-addon-versions --addon-name aws-ebs-csi-driver` and upgrade the add-on version in Terraform.
4. Read `iam_policy.json` and list which AWS services the controller touches (EC2, ELB, ACM, WAF, Shield...).

## Interview questions
- Pod Identity vs IRSA vs node IAM role? (Why is giving permissions to the node role a bad idea?)
- How does the AWS Load Balancer Controller work? (watches Ingress/Service, calls ELB APIs)
- What does the EBS CSI driver do? Why can an EBS volume only attach to one AZ?
- Managed add-on vs Helm chart?
- How would you upgrade add-ons during a cluster upgrade?
