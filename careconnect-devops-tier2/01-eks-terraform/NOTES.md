# Section 7: EKS Cluster with Terraform

**Real AWS only** (emulators don't run EKS). Rough cost while running: EKS control plane about $0.10/hr,
2x t3.medium about $0.08/hr, 1 NAT gateway about $0.045/hr, plus data. **Roughly $0.25/hr, so a 3-hour session is under $1.**
The bill comes from forgetting to destroy. Set a budget alert in AWS Billing first.

## Prerequisites
```bash
aws --version ; terraform version ; kubectl version --client
aws sts get-caller-identity          # confirms your credentials work
aws eks describe-cluster-versions --region us-east-1 --query "clusterVersions[].clusterVersion"
```
Pick a supported Kubernetes version and set `kubernetes_version` if the default isn't listed.

## Build it
```bash
cd 01-eks-terraform
terraform init
terraform plan -out tf.plan
terraform apply tf.plan              # ~12-15 minutes
$(terraform output -raw update_kubeconfig)     # bash. PowerShell: run the printed command
kubectl get nodes -o wide
kubectl get pods -A
kubectl config current-context
```

## What you just created (be able to draw this)

```
VPC 10.30.0.0/16 (3 AZs)
 ├─ public subnets  -> IGW, NAT gateway (shared), future ALBs
 ├─ private subnets -> worker nodes (outbound via NAT)
EKS control plane (AWS-managed, runs in AWS's account, ENIs in your subnets)
 ├─ IAM cluster role   (lets EKS manage ENIs, LBs)
 ├─ managed node group (EC2 ASG) + IAM node role (join cluster, pull from ECR, CNI)
 └─ add-ons: vpc-cni (pod IPs from VPC), kube-proxy, coredns
```

## Concepts to explain out loud

- **Control plane vs data plane:** AWS runs API server/etcd; you run nodes.
- **Why two IAM roles?** Cluster role = what EKS does for you. Node role = what the *EC2 nodes* may do (join cluster, pull images, manage ENIs).
- **VPC CNI:** pods get real VPC IPs, so subnet size limits pod count.
- **Managed node group vs self-managed vs Fargate vs Karpenter:** managed = AWS handles AMI upgrades/draining; Karpenter = just-in-time nodes (Section 17).
- **Authentication and authorization:** IAM proves *who you are*; **access entries** (new) or `aws-auth` ConfigMap (old) map IAM to Kubernetes RBAC. `kubectl` gets a token from `aws eks get-token`.
- **Endpoint access:** public, private, or both. Production usually private + VPN/bastion, or public with CIDR allow-list.
- **Upgrades:** control plane first (`kubernetes_version`), then node group (rolling replace, respects PodDisruptionBudgets). One minor version at a time.

## Exercises
```bash
# 1. Authentication
aws eks get-token --cluster-name careconnect-eks | head
kubectl auth can-i '*' '*'                    # you're admin because of bootstrap_cluster_creator_admin_permissions
kubectl get cm -n kube-system aws-auth        # may not exist: access entries are used
aws eks list-access-entries --cluster-name careconnect-eks

# 2. Give another IAM user read-only access
#    (set admin_principal_arn, or create an access entry with AmazonEKSViewPolicy)

# 3. Scale the node group
aws eks update-nodegroup-config --cluster-name careconnect-eks --nodegroup-name default \
  --scaling-config minSize=1,maxSize=4,desiredSize=3
kubectl get nodes -w

# 4. Deploy the app from Tier 1 (push the image to Docker Hub first)
kubectl create deployment demo --image=<dockerhub-user>/careconnect-demo:1.0.0 --port=8000 --replicas=2
kubectl get pods -o wide                      # pods spread across nodes/AZs

# 5. Look at the logs the cluster sends to CloudWatch (audit, api, authenticator)
```
Challenge: switch to `single_nat_gateway = false` and compare `terraform plan` (3 NATs, 3 route tables pointing to their own NAT).

## DESTROY (do this the same day)
```bash
kubectl delete deployment demo               # and any Services/Ingresses of type LoadBalancer first!
terraform destroy
aws eks list-clusters
```
Load balancers or EBS volumes created by Kubernetes are NOT in Terraform state and can block VPC deletion
and keep billing. Delete Ingresses/Services/PVCs *before* `terraform destroy`.

## Interview questions

- Walk me through creating an EKS cluster. What IAM roles are needed and why?
- How does a pod get an IP in EKS? What happens when subnets run out of IPs?
- How do users authenticate to the cluster? (IAM + access entries/aws-auth + RBAC)
- Managed node groups vs Fargate vs Karpenter?
- How do you upgrade a cluster with zero downtime?
- Public vs private endpoint?
- Why put nodes in private subnets? Why NAT? (and what do VPC endpoints replace?)
- What is the shared responsibility split in EKS?
