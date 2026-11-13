# CareConnect Platform: Runbook

Operational guide. If something is on fire, jump to **section 5 (incident playbooks)**.
Commands are for bash; on Windows PowerShell use `curl.exe` instead of `curl`, and `$env:NAME` instead of `$NAME`.

## 0. Quick reference

| I want to... | Do this |
|---|---|
| See everything's health | `kubectl get applications -n argocd` then `kubectl get pods -A` |
| Deploy a new version | `git tag vX.Y.Z && git push origin vX.Y.Z` (section 3.1) |
| Promote to EKS | GitHub Actions > promote > Run workflow (3.2) |
| Roll back | `git revert <deploy commit>` and push (3.3) |
| Scale a service | edit `replicaCount` / `autoscaling` in `gitops/envs/<env>/<svc>.yaml` (3.4) |
| Why is a pod unhealthy? | `kubectl describe pod <pod> -n careconnect` and read **Events** |
| Logs | `kubectl logs deploy/<svc> -n careconnect --tail=100` |
| Open ArgoCD UI | `kubectl port-forward svc/argocd-server -n argocd 8443:443` then https://localhost:8443 |
| Stop all spending | section 7 |

**Golden rules**
1. **Git is the source of truth.** Don't fix things with `kubectl edit`: ArgoCD will revert it (self-heal). Change Git.
2. Never deploy `latest`. Every deploy is a version tag in a values file.
3. Change one thing at a time; read the Events before guessing.
4. Anything that costs money gets destroyed the same day (section 7).

## 1. Environments

| | local | eks |
|---|---|---|
| Where | kind cluster `cc` on your machine | EKS `careconnect-eks`, `us-east-1` |
| Namespace | `careconnect` (apps), `argocd` | same |
| Git folders | `gitops/envs/local`, `gitops/apps/local` | `gitops/envs/eks`, `gitops/apps/eks` |
| Entry | `kubectl port-forward` | ALB DNS name, paths `/patients` `/appointments` `/doctors` |
| Change path | release tag = automatic | promotion PR = reviewed |
| Cost | free | about $0.25/hr while up |

## 2. Bootstrap from zero

### 2A. Local: kind + ArgoCD (free)

**Prerequisites:** Docker Desktop, `kind`, `kubectl`, Git, a GitHub account (public repo).

1. **Fork or push this repo** to your GitHub, then replace the placeholders:
   ```powershell
   # PowerShell, from the repo root. Replace myname with your GitHub username.
   Get-ChildItem -Recurse gitops, .github, apps -File | ForEach-Object { (Get-Content $_.FullName) -replace '<your-user>','myname' -replace '<dockerhub-user>','mydockerhubname' | Set-Content $_.FullName }
   git add -A ; git commit -m "set my names" ; git push
   ```
   (bash: `grep -rl '<your-user>' . | xargs sed -i 's/<your-user>/myname/g'`)
2. **Cluster and image**
   ```bash
   kind create cluster --name cc --config k8s/kind/kind-config.yaml
   docker build -t careconnect-service:dev apps/careconnect-service
   kind load docker-image careconnect-service:dev --name cc
   kubectl get nodes
   ```
3. **Install ArgoCD**
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
   ```
4. **Hand over to GitOps** (the only manual apply)
   ```bash
   kubectl apply -f gitops/bootstrap/root-local.yaml
   kubectl get applications -n argocd -w
   ```
   Expect: `root-local`, `careconnect-platform-local`, `careconnect-patient-local`, `...-appointment-local`, `...-doctor-local` all `Synced / Healthy` within a few minutes.
5. **Verify**
   ```bash
   kubectl get pods -n careconnect                  # postgres-0, redis-0, 2 pods per service
   kubectl port-forward svc/appointment 9002:80 -n careconnect
   curl http://localhost:9002/health                # healthy:true and dependencies reachable
   ```
   `appointment` only becomes Ready after Postgres and Redis answer: that's the readiness probe doing its job.
6. **ArgoCD UI**
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8443:443
   # user: admin   password:
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d      # PowerShell: see Tier 1 kit, 09-cicd-argocd
   ```

**Done when:** all apps Synced/Healthy, `curl /health` returns 200 for all three services.

### 2B. AWS EKS (costs money; read section 7 first)

**Prerequisites:** AWS CLI configured (`aws sts get-caller-identity`), Terraform >= 1.6, kubectl, an **AWS Budget alert** set.

1. **Network + cluster** (about 15 min)
   ```bash
   cd infra/stacks/10-eks
   terraform init && terraform plan -out tf.plan && terraform apply tf.plan
   $(terraform output -raw update_kubeconfig)
   kubectl get nodes
   ```
2. **Add-ons + ArgoCD** (about 5 min)
   ```bash
   cd ../20-addons
   curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
   terraform init
   terraform apply -var vpc_id=$(terraform -chdir=../10-eks output -raw vpc_id)
   kubectl get pods -n kube-system
   kubectl get pods -n argocd
   ```
3. **Image on Docker Hub** (the cluster can't see your laptop): push a release tag first (section 3.1) or build and push manually:
   ```bash
   docker buildx build --platform linux/amd64,linux/arm64 -t <dockerhub-user>/careconnect-service:1.0.0 --push apps/careconnect-service
   ```
   Make sure `gitops/envs/eks/*.yaml` has `repository` and `tag` that exist.
4. **Hand over to GitOps**
   ```bash
   cd ../../..
   kubectl apply -f gitops/bootstrap/root-eks.yaml
   kubectl get applications -n argocd -w
   kubectl get ingress -n careconnect                 # ADDRESS = ALB DNS (2-3 min)
   curl http://<alb-dns>/patients/health
   curl http://<alb-dns>/appointments/health
   ```
5. Optional data plane (free on the emulator; RDS etc. cost money): `infra/stacks/30-data`.

**Done when:** three Healthy apps, one ALB shared by three Ingresses, all three URLs return 200.

## 3. Routine operations

### 3.1 Release a new version (local env)
```bash
# 1. change code, open a PR, wait for pr-checks to go green, merge
# 2. tag
git checkout main && git pull
git tag v1.0.1
git push origin v1.0.1
```
- Watch **GitHub > Actions > release**: test -> build-push -> update-gitops-local.
- A bot commit appears: `ci: deploy v1.0.1 to local`.
- ArgoCD syncs it (about 3 minutes, or press Refresh in the UI): `kubectl rollout status deploy/patient -n careconnect`.
- Verify: `kubectl get deploy -n careconnect -o wide` shows the new image; `curl /health`.
Versioning: PATCH = fix, MINOR = backwards-compatible feature, MAJOR = breaking change.

### 3.2 Promote to EKS
1. GitHub > Actions > **promote** > Run workflow: version `1.0.1`, environment `eks`.
2. Review the PR (the diff shows exactly the image tag change), confirm pr-checks are green, **merge**.
3. `kubectl get applications -n argocd` (on the EKS context) and `kubectl rollout status`.
Check first that the version really exists on Docker Hub, or pods will go `ImagePullBackOff`.

### 3.3 Roll back
Preferred (keeps Git honest):
```bash
git log --oneline -n 10 -- gitops/envs/<env>        # find the deploy commit
git revert <commit-sha>
git push origin main
```
ArgoCD syncs back to the previous tag. Verify with `kubectl rollout status`.
Faster for an emergency: edit `image.tag` in the values files to the last known good version, commit, push.
**Do not** use `kubectl rollout undo` (ArgoCD will re-apply Git). The ArgoCD UI "History and rollback" works only with auto-sync off and leaves Git out of date: avoid except as a last resort, and fix Git right after.

### 3.4 Scale
- Local: change `replicaCount` in `gitops/envs/local/<svc>.yaml`.
- EKS: HPA owns replicas (`autoscaling.minReplicas/maxReplicas`). To pre-scale for an event raise `minReplicas`.
- Check: `kubectl get hpa -n careconnect` and `kubectl top pods -n careconnect`.
- If pods go `Pending` because the cluster is full: add nodes (`aws eks update-nodegroup-config ...` or the node group size in Terraform), or install Karpenter (Tier 3 kit).

### 3.5 Change configuration
Edit the `env:` block in the values file, commit, push. The chart's `checksum/config` annotation makes pods roll automatically.

### 3.6 Secrets
Local dev password is a placeholder in `k8s/platform/local/postgres.yaml`: dev only.
On EKS: store credentials in **AWS Secrets Manager** and mount via the Secrets Store CSI driver (installed by `20-addons`; patterns in the Tier 1 kit `07-secrets`) or use RDS `manage_master_user_password`. Never commit real secrets. If a secret leaks: **rotate it first**, then clean Git history.

### 3.7 Add a new microservice
1. Add `gitops/envs/local/<name>.yaml` and `gitops/envs/eks/<name>.yaml`.
2. Add `- service: <name>` to both `gitops/apps/*/appset.yaml`.
3. Add it to the loops in `pr.yml`, `release.yml`, `promote.yml`.
4. PR -> merge -> ArgoCD creates the Application.

### 3.8 Upgrade the chart
Change templates in `charts/`, bump `version` in `Chart.yaml`, run `helm lint` / `helm template` for every values file (the PR checks do it), PR, merge. All services roll together; consider testing on `local` first by pointing only that env at a branch.

### 3.9 Upgrade Kubernetes (EKS)
1. Read the release notes, check add-on and Karpenter/controller compatibility.
2. Upgrade **one minor version at a time**: change `kubernetes_version` in `infra/stacks/10-eks`, `terraform plan`, apply. Control plane first.
3. The managed node group rolls nodes (respects PDBs, `max_unavailable = 1`).
4. Upgrade add-ons (`aws eks describe-addon-versions`), then verify all apps Healthy.
5. If a drain is blocked: `kubectl get pdb -A`, find the PDB that allows 0 disruptions.

### 3.10 Node maintenance
```bash
kubectl cordon <node>
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
# do the maintenance
kubectl uncordon <node>
```

## 4. Health and monitoring

**Daily 2-minute check**
```bash
kubectl get applications -n argocd                       # all Synced + Healthy?
kubectl get pods -A | grep -v "Running\|Completed"       # anything unusual?
kubectl get hpa -n careconnect
kubectl top nodes
kubectl get events -A --sort-by=.lastTimestamp | tail -20
```
**What "healthy" looks like:** no `CrashLoopBackOff`/`Pending`, restarts not climbing, HPA targets not `<unknown>`, ArgoCD apps Synced, `/health` 200 through the ingress.

**Four golden signals to watch** (if you add the Tier 3 observability stack): latency, traffic, errors, saturation (CPU/memory/pending pods).
**Alerts worth having:** error rate > 5% for 5 min; pods Pending > 5 min; node NotReady; ArgoCD app Degraded > 10 min; AWS Budget at 80%.

## 5. Incident playbooks

First 5 minutes of any incident: **(1) what changed?** (`git log -n 5`, recent deploys, ArgoCD history) **(2) scope** (one service or all? one pod or all?) **(3) read** `kubectl describe` Events and the logs. Roll back first if a recent deploy is the likely cause; investigate afterwards.

### 5.1 Pod `CrashLoopBackOff`
| Check | Command |
|---|---|
| Why it died | `kubectl logs <pod> -n careconnect --previous` |
| Exit code / OOM | `kubectl describe pod <pod> -n careconnect` (Last State: `OOMKilled`, exit 137, ...) |
| Liveness probe killing it | Events: `Liveness probe failed` |
Fixes: app bug -> roll back (3.3). `OOMKilled` -> raise `resources.limits.memory`. Bad probe path/timing -> fix `probes` in the chart. Missing dependency -> check the DB/Redis pods.

### 5.2 `ImagePullBackOff` / `ErrImagePull`
Describe the pod: usually the tag doesn't exist, typo in repository, private image without credentials, or (kind) the image was never `kind load`ed.
Fix: correct `image.repository/tag` in the values file (Git). On kind: `kind load docker-image careconnect-service:dev --name cc`. Confirm the tag exists on Docker Hub: `docker manifest inspect <repo>:<tag>`.

### 5.3 Pod `Running` but `0/1 Ready`
Readiness probe failing. `kubectl describe pod` -> `Readiness probe failed: HTTP probe failed with statuscode: 503`.
For this app 503 means a **dependency is down**: `curl` the pod's `/health` to see which (`kubectl port-forward pod/<pod> 9000:8000`, `curl localhost:9000/health`). Check `kubectl get pods -n careconnect | grep -i "postgres\|redis"`, their logs, and PVC status (5.8). Traffic is already protected: unready pods are removed from the Service.

### 5.4 Pod `Pending`
`kubectl describe pod`: `Insufficient cpu/memory` -> cluster full: add nodes, or lower requests; `0/3 nodes... didn't match node selector/affinity` -> fix selectors; `unbound PersistentVolumeClaims` -> 5.8; `Too many pods` on EKS small instances -> VPC CNI pod limit: bigger instance type.

### 5.5 ALB returns 502 / 503 / 504 (EKS)
| Symptom | Likely cause | Check |
|---|---|---|
| 503 | no healthy targets | `kubectl get endpoints -n careconnect`; pods Ready? |
| 502 | target closed connection / wrong port | `targetPort` 8000, app listening on 0.0.0.0 |
| 504 | timeouts | app slow; security group blocks ALB -> pod |
| 404 | no matching path rule | `kubectl describe ingress -n careconnect`, path prefix |
| ADDRESS empty | controller can't create ALB | `kubectl logs -n kube-system deploy/aws-load-balancer-controller`: IAM `AccessDenied`? subnet tags? |
Console: EC2 > Target Groups > Targets > health status + reason.

### 5.6 ArgoCD app `OutOfSync`, `Degraded` or `SyncFailed`
```bash
kubectl get applications -n argocd
kubectl describe application <name> -n argocd        # Conditions / sync result
```
| State | Meaning / fix |
|---|---|
| `OutOfSync` (temporary) | Git changed, sync pending: wait or Refresh |
| `OutOfSync` (stuck) | someone changed the cluster by hand and self-heal is off, or a field is mutated by a controller: add `ignoreDifferences` |
| `SyncFailed` | manifest invalid: render locally `helm template x charts/careconnect-service -f gitops/envs/<env>/<svc>.yaml`, fix YAML/values, push |
| `Degraded` | resources unhealthy: look at the pods (5.1-5.4) |
| `Unknown` / repo error | repo URL wrong/private, or branch name: check `repoURL`, `targetRevision` |
| Values file not found | `valueFiles` path relative to chart dir: `../../gitops/envs/<env>/<svc>.yaml` |
Force refresh: UI Refresh (hard), or `kubectl annotate application <name> -n argocd argocd.argoproj.io/refresh=hard --overwrite`.

### 5.7 Node `NotReady`
`kubectl describe node <node>` (Conditions: MemoryPressure, DiskPressure, NetworkUnavailable). Managed node group: terminate the instance, the ASG replaces it (`aws ec2 terminate-instances --instance-ids <id>`) after cordoning/draining. kind: `docker restart cc-worker`.

### 5.8 PVC stuck `Pending` / DB won't start
`kubectl describe pvc <pvc> -n careconnect`: no StorageClass or provisioner (EKS needs the EBS CSI add-on: `kubectl get pods -n kube-system | grep ebs-csi`), or the volume is in a different AZ than the pod. Never delete a PVC with data you need: deleting the PVC deletes the data (reclaim policy `Delete`).

### 5.9 HPA shows `<unknown>`
Metrics Server missing/unhealthy (`kubectl top pods` fails) or pods lack `resources.requests`. `kubectl get deploy metrics-server -n kube-system`. On kind it needs `--kubelet-insecure-tls` (Tier 2 kit `05-hpa`).

### 5.10 Release workflow failed
| Step | Usual cause |
|---|---|
| test | real test failure: fix, new tag (never reuse a tag) |
| login | `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` secrets missing/expired |
| build-push | Dockerfile error, Docker Hub rate limit |
| update-gitops | branch protection blocks the bot push, or `yq` path wrong |
To redo: delete the tag (`git tag -d vX && git push origin :refs/tags/vX`), fix, re-tag with the **next** version.

### 5.11 Terraform problems
| Error | Fix |
|---|---|
| `Error acquiring the state lock` | someone/something else running; if it crashed: `terraform force-unlock <ID>` |
| Plan wants to destroy EKS/VPC unexpectedly | STOP. Read what changed (CIDR, name, subnets force replacement); don't apply |
| `terraform destroy` stuck on the VPC | orphaned ALBs/ENIs/security groups from Kubernetes: delete Ingresses/LoadBalancer Services first (7) |
| Provider/version errors | `terraform init -upgrade`, check version constraints |
| State drift | `terraform plan` shows it; import or revert the manual change |

### 5.12 Unexpected AWS bill
Open Cost Explorer grouped by service. Usual suspects: NAT Gateway (hourly + data), EKS control plane, forgotten ALB, EBS volumes from deleted clusters, CloudWatch Logs retention. Run the teardown (7), then check EC2 > Load Balancers, NAT Gateways, Elastic IPs, Volumes.

### 5.13 Secret/credential leaked into Git
1. **Rotate/revoke it immediately** (Docker Hub token, AWS key).
2. Remove from history if needed (`git filter-repo` or recreate the repo), force-push.
3. Check CloudTrail/Docker Hub activity for misuse.
4. Add a scanner to CI (gitleaks/trufflehog).

## 6. Backup and disaster recovery

| Thing | Where it lives | Recovery |
|---|---|---|
| Desired state of apps | Git | clone, bootstrap (2A/2B): cluster rebuilt in under an hour |
| Infrastructure definition | Terraform in Git | `terraform apply` |
| Terraform **state** | local file or S3 bucket (versioned) | use remote state with versioning (`infra/backend.tf.example`); losing state means `terraform import` pain |
| Container images | Docker Hub (+ rebuild from tag) | `git checkout vX && docker build` |
| App data | local PVCs (dev only) / RDS / DynamoDB | RDS automated backups + snapshots, DynamoDB point-in-time recovery: **enable them** for anything real |
| Secrets | Secrets Manager | separate from Git by design |
Practise a **rebuild drill**: destroy the kind cluster, recreate it with 2A, and time how long until everything is Healthy. That number is your RTO for this setup.

## 7. Cost control and teardown

**While running:** EKS about $0.10/hr + nodes + NAT about $0.045/hr + ALB about $0.025/hr + data. Prices vary: check AWS pricing.

**Teardown order (do not skip steps):**
```bash
# 1. let Kubernetes remove what it created in AWS (ALBs, volumes)
kubectl delete application -n argocd --all            # or: delete the root app and wait. With finalizers ArgoCD prunes the resources
kubectl delete ingress --all -n careconnect
kubectl delete pvc --all -n careconnect
kubectl get svc,ingress,pvc -A                        # make sure no LoadBalancer/PVC remains
# 2. add-ons + ArgoCD
cd infra/stacks/20-addons && terraform destroy -var vpc_id=$(terraform -chdir=../10-eks output -raw vpc_id)
# 3. cluster + network
cd ../10-eks && terraform destroy
# 4. optional data plane
cd ../30-data && terraform destroy
# 5. verify nothing is left
aws eks list-clusters
aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerArn"
aws ec2 describe-nat-gateways --filter Name=state,Values=available --query "NatGateways[].NatGatewayId"
aws ec2 describe-volumes --filters Name=status,Values=available --query "Volumes[].VolumeId"
```
Local: `kind delete cluster --name cc` and `docker compose down -v`.

## 8. On-call

**Severity guide**
| Sev | Meaning | Response |
|---|---|---|
| 1 | all users affected / data loss risk | drop everything, roll back first |
| 2 | one service degraded | fix within the hour |
| 3 | minor, workaround exists | next working day |

**During an incident:** announce, assign roles (one person drives), keep a timeline (time, action, result), prefer rollback over novel fixes, avoid changing several things at once.

**Post-incident template** (copy into `docs/incidents/YYYY-MM-DD.md`)
```
Title / date / severity / duration
Impact: who, what, how long
Timeline: HH:MM event or action
Root cause:
What went well / what went badly:
Action items (owner, due date): ...
```
