# Architecture and design decisions

## Components

| Layer | Choice | Where |
|---|---|---|
| App | 3 stand-in services (patient, appointment, doctor), one image, behaviour by env vars | `apps/` |
| Edge | nginx gateway (Compose) / ALB Ingress (EKS) | `docker/gateway`, chart ingress |
| Data | Postgres + Redis (local, StatefulSets) / DynamoDB + SQS (+ optional RDS, ElastiCache) on AWS | `k8s/platform/local`, `infra/stacks/30-data` |
| Packaging | One Helm chart for all services | `charts/` |
| Delivery | ArgoCD (pull-based GitOps) | `gitops/` |
| CI | GitHub Actions | `.github/workflows/` |
| Infra | Terraform stacks, one reusable VPC module | `infra/` |

## Environments

| | local | eks |
|---|---|---|
| Cluster | kind (3 nodes in Docker) | EKS, managed node group |
| Images | `careconnect-service:dev` loaded into kind, or Docker Hub after a release | Docker Hub tag set by promotion PR |
| Ingress | none (port-forward) | ALB, path routing (`/patients`, `/appointments`, `/doctors`) |
| Datastores | Postgres/Redis StatefulSets | none by default; DynamoDB/SQS/RDS via Terraform stack 30 |
| Scaling | fixed replicas | HPA 2 to 6 |
| Deploy trigger | commit by release workflow (automatic) | pull request merged by a human (gated) |

## Delivery flow (the part to be able to draw)

1. Developer opens a PR. **pr-checks** run unit tests, hadolint, a Docker build, Helm lint/template for every service x environment, and `terraform validate` for every stack. Nothing is deployed.
2. PR merged to `main`. Nothing deploys yet: Git changes don't touch environments unless their values files change.
3. Developer tags `vX.Y.Z`. **release** runs tests, builds a multi-arch image, pushes it, and commits the new tag to `gitops/envs/local/*.yaml`.
4. ArgoCD (in the cluster) notices the commit, renders the chart with the new values, and applies it. Rolling update with `maxUnavailable: 0` readiness gating.
5. To reach EKS, someone runs **promote**: it opens a PR editing `gitops/envs/eks/*.yaml`. Review, merge, ArgoCD deploys.
6. Rollback = `git revert` of the tag commit. ArgoCD reconciles back. See the runbook.

## Decisions and trade-offs

| Decision | Why | Trade-off |
|---|---|---|
| **GitOps pull model (ArgoCD)** | CI never holds cluster credentials; Git is the audit log; drift is auto-corrected | One more component to run; a bad commit deploys itself |
| **One chart, values per service/env** | Consistency and less duplication | Services that diverge a lot may need their own chart later |
| **App-of-apps + ApplicationSet** | One manual `kubectl apply`; adding a service is a list entry + values file | Slightly more indirection to learn |
| **Image tag in Git (not `latest`)** | Reproducible, rollbackable deploys | A commit per release |
| **Promotion by PR for prod-like env** | Human review gate and a diff | Slower than full automation (deliberate) |
| **Pod Identity (not IRSA / node role)** | No keys, per-service roles, simpler than OIDC providers | Needs the agent add-on; newer feature |
| **Managed node group + (optional) Karpenter** | Karpenter's controller needs somewhere to run; managed group is simple | Two scaling mechanisms to understand |
| **Single NAT gateway in the practice EKS stack** | Roughly one third of the NAT cost | Not AZ-resilient. Production should use one per AZ |
| **Public EKS endpoint in practice stack** | Easy kubectl from a laptop | Production: restrict CIDRs or go private + VPN |
| **Probes + PDB + zone spread in the chart** | Safe rollouts, node drains, spot interruptions | Strict PDBs can block upgrades |
| **Plain-text dev DB password in local manifests** | Local practice only, clearly labelled | EKS path uses Secrets Manager + CSI/ESO (see Tier 1 kit `07-secrets`) |
| **Terraform stacks split by lifecycle** (network+EKS, add-ons, data) | Smaller blast radius; different change rates | Outputs must be passed between stacks |

## Security notes
- Containers run as non-root (UID 10001), pinned base image, healthcheck.
- No cloud credentials in CI for PR checks. Release uses a Docker Hub token in GitHub Secrets. (Upgrade path: OIDC to AWS and ECR, see Tier 1 `09-cicd-argocd`.)
- IAM: per-addon roles via Pod Identity, scoped policies.
- `.gitignore` blocks state files, tfvars, `.env`, kubeconfigs.
- Known gaps (deliberate, listed so you can fix them as practice): no image scanning in CI, no NetworkPolicies, no admission policies, EKS public endpoint, local DB secret in plain manifest.

## Extension ideas
Trivy scan in CI; NetworkPolicies; ExternalDNS + ACM + HTTPS (Tier 3 kit); OpenTelemetry traces/metrics (Tier 3 `06`); Karpenter + spot (Tier 3 `05`); Argo Rollouts canary; External Secrets Operator; cost dashboards.
