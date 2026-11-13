# CareConnect DevOps: Tier 2 Practice Kit

Builds on the **Tier 1 kit** (Docker, Terraform, Kubernetes, Helm, CI/CD). Finish Tier 1 first:
Tier 2 reuses its VPC module, its container image, and its Kubernetes and Helm knowledge.

## Study order, with time and cost

| # | Folder | Course section | Type | Time | Cost |
|---|---|---|---|---|---|
| 1 | `04-storage` | Sec 10: Persistent storage | hands-on on kind | 2 hrs | free |
| 2 | `05-hpa` | Sec 18: HPA | hands-on on kind | 2 hrs | free |
| 3 | `03-ingress-alb` | Sec 11: Ingress | Track A free on kind, Track B on EKS | 2 + 1 hrs | free / EKS |
| 4 | `01-eks-terraform` | Sec 7: EKS with Terraform | hands-on, real AWS | 3 hrs | about $0.25/hr, destroy same day |
| 5 | `02-eks-addons` | Sec 13: Add-ons | hands-on, real AWS (same session as 4) | 2 hrs | same cluster |
| 6 | `06-data-plane` | Sec 14: AWS data plane | DynamoDB/SQS free on Floci, RDS optional | 2 hrs | free / small |
| 7 | `07-karpenter` | Sec 17: Karpenter | concept + PDB drill on kind | 2 hrs | free |
| 8 | `08-opentelemetry` | Sec 20: OpenTelemetry | concept + free collector lab | 2 hrs | free |

**Total: about 18 hours.** Do 1, 2, 3 (Track A) first: they cost nothing and cover most interview questions.
Then do 4, 5 and 3 (Track B) **in one sitting** so you only pay for the cluster once.

Skipped on purpose: Sections 15-16 (ExternalDNS, custom domains, ACM automation) need a real domain. Ask later if you buy one.

## Run EKS once, cheaply
1. Set an **AWS Budget alert** ($10) before you start.
2. `01-eks-terraform` apply (about 15 min) -> `02-eks-addons` apply (about 5 min).
3. Do `03-ingress-alb` Track B, try `04-storage` EKS section, try HPA on the cluster.
4. **Delete Ingresses, Services of type LoadBalancer and PVCs first**, then `terraform destroy` in `02` and then in `01`.
5. Check the AWS console for leftover load balancers, volumes and NAT gateways.

## Tools needed (on top of Tier 1)
`aws` CLI v2 (configured: `aws sts get-caller-identity`), plus everything from Tier 1. For `06-data-plane` on Floci, the same Floci setup you used for Terraform.

## How to use each folder
Same as Tier 1: read `NOTES.md`, type the commands, **break something on purpose**, then answer the interview questions out loud.

## Layout
```
careconnect-devops-tier2/
├── 01-eks-terraform/   VPC module (+ single-NAT option), cluster, node group, IAM, access entries
├── 02-eks-addons/      Pod Identity, EBS CSI, LB Controller, Secrets Store CSI + ASCP, Metrics Server
├── 03-ingress-alb/     local-kind/ (ingress-nginx, free) and eks-alb/ (HTTP, HTTPS, ACM annotations)
├── 04-storage/         static PV, dynamic PVC, StatefulSet Postgres, gp3 StorageClass
├── 05-hpa/             php-apache demo, CPU HPA, CPU+memory HPA with behavior
├── 06-data-plane/      DynamoDB, SQS+DLQ (free), RDS MySQL/Postgres, ElastiCache (real AWS)
├── 07-karpenter/       NodePools (on-demand, spot), EC2NodeClass, PDB workload
└── 08-opentelemetry/   local collector + Jaeger lab, ADOT EKS reference
```

## Honest notes
- Written without running AWS, Terraform, kind or Helm on my side: expect to debug a first-run error and send it to me.
- **Version-sensitive files:** Kubernetes version (`kubernetes_version`), Karpenter v1 fields, `telemetrygen` flags, add-on and image versions. If something errors on a field or tag, check the current docs and bump.
- `02-eks-addons` needs the official LB controller IAM policy downloaded as `iam_policy.json` (command is in the file).
- Cost warnings are estimates; check the AWS pricing page.
- Karpenter is reference material here. The full install (IAM, SQS, EventBridge, Helm) is not in this kit.

## Where this leaves you
Tier 1 + Tier 2 covers the whole course except the domain/DNS sections and a full Karpenter install.
Good next steps: run the whole thing end to end for CareConnect on EKS (Terraform -> Helm -> ArgoCD), record a short demo, and put it in your portfolio README.
