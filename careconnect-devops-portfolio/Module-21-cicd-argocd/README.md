# Module-21: DevOps CI/CD Pipeline with GitOps

**Course section 21 (4 demos) · Status:** ☐ not started  ☐ done

## What this shows
A complete flow: **code change, build, push to a registry, update Helm values in Git, ArgoCD deploys**, with rollback by reverting a commit.

| Demo | Where |
|---|---|
| 1. CI with GitHub Actions and a registry | `.github/workflows/pr.yml` and `release.yml` (Docker Hub). The ECR + OIDC version (no access keys) is `ecr-oidc-release.yml.example` with `oidc-role.tf` |
| 2. ArgoCD installation | commands below |
| 3. CD with ArgoCD and Helm (auto-sync, self-heal) | `gitops/argocd/root-app.yaml`, `gitops/apps/`, `gitops/envs/` |
| 4. Complete CI/CD flow testing and rollback | commands below |

## Demo 1: set up the pipeline (one time)
1. Create a Docker Hub access token. In GitHub: Settings, Secrets and variables, Actions, add `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`.
2. Replace the placeholders and push:
```
grep -rl '<your-user>' . | xargs sed -i "s/<your-user>/$(gh api user -q .login)/g"
grep -rl '<dockerhub-user>' . | xargs sed -i "s/<dockerhub-user>/YOUR_DOCKERHUB_NAME/g"
git add -A && git commit -m "set my names" && git push
```

## Demo 2: install ArgoCD on kind
```
kind create cluster --name cc --config k8s/kind-config.yaml
kubectl create namespace argocd
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
kubectl port-forward svc/argocd-server -n argocd 8443:443
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

## Demo 3: let ArgoCD deploy everything from Git
```
kubectl apply -f gitops/argocd/root-app.yaml
kubectl get applications -n argocd -w
kubectl get pods -n careconnect
```
Self-heal test: `kubectl scale deploy appointments -n careconnect --replicas=5`, and ArgoCD puts it back to 2.

## Demo 4: the complete flow and a rollback
```
git tag v1.0.0 && git push origin v1.0.0       # release: builds 5 images, pushes them, commits the new tag
gh run watch
git pull                                        # get the bot's commit
kubectl get deploy -n careconnect -o wide       # new image running
```
Bad release and rollback:
```
# edit gitops/envs/dev/portal.yaml: image.tag: does-not-exist ; commit and push
kubectl get pods -n careconnect                 # ImagePullBackOff; old pods keep serving
git revert HEAD --no-edit && git push           # rollback = revert the commit
```

## Key points to explain
GitOps (pull, not push), why CI never touches the cluster, immutable version tags, `selfHeal` and `prune`, rollback by `git revert`, and OIDC instead of stored access keys.

## Screenshots to take
- `docs/screenshots/module-21-argocd.png`: all applications Synced and Healthy
- `docs/screenshots/module-21-actions.png`: a green release run with the matrix of 5 services
- `docs/screenshots/module-21-bot-commit.png`: the bot commit `ci: deploy v1.0.0`
- `docs/screenshots/module-21-rollback.png`: the revert commit and the app healthy again
