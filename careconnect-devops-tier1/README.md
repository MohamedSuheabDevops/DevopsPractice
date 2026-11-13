# CareConnect DevOps: Tier 1 Practice Kit

One project, six skills. Everything uses the same tiny CareConnect-style microservice
(`apps/`), so each section builds on the last, and the finished repo is a **GitHub portfolio**.

```
Docker -> Dockerfiles -> Compose -> buildx -> Terraform -> Kubernetes -> Secrets -> Helm -> CI/CD + ArgoCD
```

## Study order, with time estimates

| # | Folder | Course section | Time | Cost |
|---|---|---|---|---|
| 1 | `01-docker-commands` | Sec 2: Docker commands | 1 hr | free |
| 2 | `02-dockerfile-mastery` | Sec 3: Dockerfiles | 2 hrs | free |
| 3 | `03-docker-compose` | Sec 4: Compose | 3 hrs (Steps 1, 2, 4 = 2.5 hrs core) | free |
| 4 | `04-buildkit-buildx` | Sec 5: BuildKit | 1.5 hrs | free (Docker Hub) |
| 5 | `05-terraform` | Sec 6: Terraform basics | 5 hrs | free with Floci |
| 6 | `06-kubernetes` | Sec 8: Kubernetes | 6 hrs | free (kind) |
| 7 | `07-secrets` | Sec 9: Secrets | 1.5 hrs (EKS parts: read only) | free |
| 8 | `08-helm` | Sec 12: Helm | 3 hrs | free (kind) |
| 9 | `09-cicd-argocd` | Sec 21: CI/CD + GitOps | 5 hrs | free (Docker Hub), ECR optional |

**Total: about 28 hours.** Realistic plan: 3 to 4 weeks at 1 to 2 hrs a day. Don't binge it. Do one folder, then explain it out loud.

## Tools to install (Windows + Docker Desktop + VS Code)

| Tool | Check |
|---|---|
| Docker Desktop (with Compose + buildx) | `docker version`, `docker compose version`, `docker buildx version` |
| kubectl | `kubectl version --client` |
| kind | `kind version` |
| Helm | `helm version` |
| Terraform (>= 1.6) | `terraform version` |
| Git + a GitHub account | `git --version` |
| Floci (local AWS emulator) | see its docs |

Use PowerShell with `curl.exe` (not `curl`). Linux/macOS: the same commands work, just use `curl` and `base64 -d`.

## How to use each folder

1. Read `NOTES.md` (concepts, commands, exercises, interview questions).
2. Type the commands yourself. Don't copy-paste everything.
3. **Break something on purpose** and fix it. Each notes file has experiments for this.
4. Close the notes and answer the interview questions out loud.

Always run commands from this repo's root unless a note says otherwise.

## Layout

```
careconnect-devops-tier1/
├── apps/
│   ├── python-service/      # tiny HTTP service (used by Docker, Compose, K8s, Helm, CI)
│   └── go-service/          # tiny Go service (multi-stage and multi-arch demos)
├── 01-docker-commands/      NOTES.md
├── 02-dockerfile-mastery/   Dockerfile.bad / .good / .multistage-*, NOTES.md
├── 03-docker-compose/       the Compose kit (README + 5 steps + final file)
├── 04-buildkit-buildx/      Dockerfile.multiarch, .cache-mount, NOTES.md
├── 05-terraform/            01-foundation ... 06-vpc-module, NOTES.md
├── 06-kubernetes/           kind config + manifests 00-06, NOTES.md
├── 07-secrets/              K8s Secrets + eks-only/ (CSI driver, Pod Identity), NOTES.md
├── 08-helm/                 careconnect-service chart + values per service/env, NOTES.md
└── 09-cicd-argocd/          GitHub Actions workflows, OIDC role, ArgoCD Application, NOTES.md
```

## Make it your portfolio

1. Create a GitHub repo `careconnect-devops` and push this folder.
2. Add your own touches: swap the stand-in service for real CareConnect code, add screenshots of ArgoCD synced, Actions green, `terraform plan` output.
3. Write a short top-level README story: "Built a CI/CD pipeline from commit to Kubernetes using GitHub Actions, Helm and ArgoCD."
4. Keep secrets out of Git: Docker Hub tokens in GitHub secrets, never in files.

## Honest notes about this kit

- It was written without running Docker, Terraform, kind or Helm on my side, so treat a first-run error as a normal debugging exercise and send it to me to fix.
- Floci's port/endpoint and which AWS services it supports may differ from the defaults in the Terraform files (`endpoint` variable, `localhost:4566`). Check its docs.
- Version numbers (images, Terraform provider, GitHub Actions) were current when I wrote this. If one fails to pull or resolve, bump to the latest.
- Real AWS (EKS, NAT gateways, ECR) costs money. Everything marked "free" runs locally. Run EKS once, learn, and `terraform destroy` the same day.

## What's not here (Tier 2/3)

EKS with Terraform (Sec 7), Ingress/ALB (11), add-ons (13), RDS/Redis/SQS data plane (14), storage (10), HPA (18), ExternalDNS (15-16), Karpenter (17), OpenTelemetry (20).
Ask for these next.
