# Section 21: CI/CD with GitHub Actions, ECR, ArgoCD and Helm (GitOps)

## The flow you are building

```
git tag v1.0.1 -> GitHub Actions: build image -> push to registry
              -> CI commits new image.tag into Helm values (in Git)
              -> ArgoCD sees the Git change -> syncs the cluster -> new pods roll out
```
**GitOps principles:** Git is the single source of truth; the desired state is declarative; an agent *inside* the cluster pulls and reconciles (CI never needs cluster credentials); drift is auto-corrected.

You need a **GitHub repo** with this whole folder pushed to it (ArgoCD reads from Git, so local-only won't work).

## Part 1: CI with GitHub Actions (free, Docker Hub)

1. Create a Docker Hub **access token** (Account Settings > Security).
2. In your repo: Settings > Secrets and variables > Actions > add `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`.
3. Copy the workflow: `.github/workflows/ci.yml` <- `09-cicd-argocd/github-workflows/ci-dockerhub.yml`
4. Commit to `main`, then release:
```bash
git tag v1.0.0
git push origin v1.0.0
```
5. Watch the **Actions** tab. Check Docker Hub for tags `1.0.0`, `1.0`, `sha-xxxxxxx` and an amd64+arm64 manifest.
6. Check Git history: a `ci: appointment-service -> v1.0.0` commit from the bot.

Workflow vocabulary: `on` (triggers), `jobs`, `steps`, `uses` (reusable action), `run` (shell), `secrets`, `needs` (job order), `if`, `env`, `permissions`, `outputs`, `matrix`, cache.

**Semantic versioning with tags:** `vMAJOR.MINOR.PATCH`. PATCH = bug fix, MINOR = backward-compatible feature, MAJOR = breaking change.
Try: `git tag v1.0.1`, push, see a new image. Delete a wrong tag: `git tag -d v1.0.1 && git push origin :refs/tags/v1.0.1`.

## Part 2: OIDC to AWS (no access keys): the course version

Problem: storing `AWS_ACCESS_KEY_ID` in GitHub secrets = long-lived credentials that can leak.
Solution: GitHub issues a short-lived signed token per workflow run; AWS trusts GitHub as an identity provider and exchanges the token for temporary credentials.

1. Create the OIDC provider + role + ECR repo (`aws-oidc/oidc-role.tf`, edit `<github-user>/<repo>` and `<ACCOUNT_ID>`).
2. Store the role ARN in the secret `AWS_ROLE_ARN` (it's not sensitive, but keeps config tidy).
3. Use `github-workflows/ci-ecr-oidc.yml`. Note `permissions: id-token: write`.
4. The trust policy's **`sub` condition** is the security boundary: it restricts which repo/branch/tag can assume the role. A too-loose `sub` is a classic misconfiguration.

## Part 3: ArgoCD on kind (free)

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl get pods -n argocd -w
kubectl port-forward svc/argocd-server -n argocd 8443:443
# UI: https://localhost:8443  user: admin
# password (PowerShell):
$p = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($p))
```
Components: **API server** (UI/CLI/API), **repo server** (clones Git, renders Helm), **application controller** (compares desired vs live, syncs), **Redis** (cache), **Dex** (SSO), **ApplicationSet controller**.
On EKS the same install works; expose it with an Ingress (Section 11).

## Part 4: Deploy with ArgoCD + Helm

1. Edit `argocd/application.yaml` (`repoURL`). Make sure `services/appointment.yaml` has `image.repository: <dockerhub-user>/careconnect-appointment` and a tag that exists.
2. Public repo = works immediately. Private repo: add credentials in ArgoCD Settings > Repositories.
```bash
kubectl apply -f 09-cicd-argocd/argocd/application.yaml
kubectl get applications -n argocd
kubectl get pods -n careconnect-gitops
```

**Auto-sync and self-heal: experiments**
```bash
# self-heal: change the cluster by hand, ArgoCD reverts it within ~3 minutes (or click Refresh)
kubectl scale deploy appointment -n careconnect-gitops --replicas=5
kubectl get deploy -n careconnect-gitops -w
# prune: delete a template file in Git, push, watch ArgoCD remove the resource
# drift: set automated.selfHeal=false, repeat the scale: app shows OutOfSync but stays 5
```
`prune`: delete cluster resources removed from Git. `selfHeal`: revert manual edits. Default sync check interval ~3 min (webhooks make it instant).

## Part 5: Full end-to-end test and rollback

```bash
# 1. change app.py (e.g. add a field), commit, push to main
# 2. release
git tag v1.0.2 && git push origin v1.0.2
# 3. Actions builds -> bot commits tag 1.0.2 -> ArgoCD syncs
kubectl get pods -n careconnect-gitops -w
kubectl get deploy appointment -n careconnect-gitops -o jsonpath="{.spec.template.spec.containers[0].image}"
```

**Rollback strategies (know all of them)**
| Strategy | How | Notes |
|---|---|---|
| **Git revert** (preferred) | `git revert <bot-commit> && git push` | keeps Git as truth, auditable |
| Re-point the tag | set `image.tag` back to a good version | same idea, manual |
| ArgoCD UI/CLI rollback | App > History and Rollback | requires disabling auto-sync, and Git then disagrees |
| `kubectl rollout undo` | NOT recommended | ArgoCD will "heal" it straight back |
| Progressive delivery | Argo Rollouts (canary/blue-green) | advanced, mention in interviews |

**Practise:** push a broken tag (`image.tag: does-not-exist`), watch the app go Degraded (old pods keep serving), then `git revert` and watch it recover.

## Challenges
1. Add a `staging` and `prod` Application using `values-prod.yaml` and a different namespace.
2. Use an **ApplicationSet** to generate one Application per service (patient, appointment, doctor).
3. Add a `test` job that builds the image and curls `/health` before pushing.
4. Add Trivy image scanning to the workflow and fail on HIGH/CRITICAL.
5. Protect `main` with a PR requirement and have CI open a PR instead of pushing directly.

## Interview questions

- What is GitOps? Push vs pull deployment? (CI pushes to cluster vs agent in cluster pulls from Git)
- Why OIDC instead of access keys? What does the `sub` claim do?
- How do you version images? (semver git tags + immutable tags; never deploy `latest`)
- What does ArgoCD `selfHeal` / `prune` do? What does OutOfSync mean?
- How does CI hand off to CD in your pipeline? (a commit updating `image.tag` in Git)
- How would you roll back a bad release? (see table)
- How do you handle secrets with GitOps? (Secrets Manager + ESO/CSI, Sealed Secrets, SOPS: never plain Secrets in Git)
- ArgoCD vs Flux? ArgoCD vs Jenkins?
