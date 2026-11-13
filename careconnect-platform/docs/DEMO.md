# Demo script, screenshots and interview talking points

## 5-minute demo (record it with any screen recorder)

| Time | Show | Say |
|---|---|---|
| 0:00 | README architecture diagram | "Three microservices, delivered by GitOps. CI never touches the cluster." |
| 0:45 | `docker compose up`, curl `/appointments/health` | "Local dev mirrors production dependencies. Health depends on Postgres and Redis." |
| 1:30 | Repo tree: `charts/`, `gitops/`, `infra/` | "One chart, values per service and environment, Terraform split by lifecycle." |
| 2:00 | ArgoCD UI: all apps Synced/Healthy | "The cluster is bootstrapped with one apply: app-of-apps." |
| 2:45 | Change code, tag `v1.0.x`, show Actions run, bot commit | "Tests, multi-arch build, push, then a commit to Git. That commit is the deployment." |
| 3:45 | ArgoCD rolls out; `kubectl get pods -w` | "Rolling update, `maxUnavailable: 0`, readiness-gated." |
| 4:15 | Break something (bad tag), then `git revert` | "Rollback is a Git revert: auditable." |
| 4:45 | Runbook page | "Operations are documented: playbooks, teardown, cost controls." |

## Screenshots to capture for the README
1. ArgoCD application tree (Synced + Healthy)
2. GitHub Actions: PR checks green, release run with all jobs
3. `kubectl get pods,hpa,ingress -n careconnect`
4. `terraform plan` summary for the EKS stack (and the AWS console showing the cluster, then deleted)
5. ALB target group with healthy targets
6. Docker Hub tags showing amd64 + arm64

## Interview talking points (use the STAR format: Situation, Task, Action, Result)

- **"Walk me through your CI/CD."** Tag -> tests -> multi-arch build -> push -> CI commits the tag into Git -> ArgoCD pulls and deploys. *Why pull-based:* no cluster credentials in CI, Git as audit log, drift self-healing.
- **"How do you roll back?"** `git revert` of the deploy commit; ArgoCD reconciles. No `kubectl rollout undo`, because it would be reverted.
- **"How did you keep deployments safe?"** Readiness probes, `maxUnavailable: 0`, PDBs, zone spread, HPA, promotion through a reviewed PR to the prod-like environment.
- **"How do you manage infrastructure?"** Terraform stacks split by lifecycle (network+cluster, add-ons, data), a reusable VPC module, validation in PR checks, remote state with locking.
- **"How do pods get AWS permissions?"** EKS Pod Identity, one role per workload, no keys.
- **"What would you improve?"** Image scanning, NetworkPolicies, secrets via ESO/CSI, Karpenter + spot, OpenTelemetry + SLO alerts, HTTPS on a custom domain, progressive delivery with Argo Rollouts. (All have kits/pointers in the earlier tiers.)
- **"What went wrong while building it?"** Prepare 2 real stories from your own run: e.g. a stuck Terraform destroy caused by an orphaned ALB, a readiness probe that kept a pod unready because a dependency was down. Real debugging stories are worth more than any feature list.

## Do not claim
Don't claim production experience with things you only ran in a lab. Say "I built and operated this in a practice environment on EKS" and be ready to go deep on exactly what you did.
