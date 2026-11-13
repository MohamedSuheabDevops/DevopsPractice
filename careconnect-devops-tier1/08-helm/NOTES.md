# Section 12: Helm

Helm = package manager + templating for Kubernetes. A **chart** is a folder of templates + default values.
A **release** is one installed instance of a chart. Install Helm: https://helm.sh/docs/intro/install/ (`helm version`).
Use the kind cluster from `06-kubernetes/NOTES.md` (image `careconnect-service:1.0.0` already loaded).

## 1. Basics: install someone else's chart

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo nginx
helm show chart bitnami/nginx
helm show values bitnami/nginx | more
helm install web bitnami/nginx -n demo --create-namespace
helm list -A
helm status web -n demo
helm get manifest web -n demo | more
helm uninstall web -n demo
```

## 2. Custom values and overrides

```bash
helm install web bitnami/nginx -n demo --set replicaCount=2 --set service.type=ClusterIP
helm upgrade web bitnami/nginx -n demo --set replicaCount=3 --reuse-values
helm get values web -n demo
helm history web -n demo
helm rollback web 1 -n demo
helm uninstall web -n demo
```
Use a file instead of many `--set`: `helm install web bitnami/nginx -f my-values.yaml`.
**Precedence (low to high):** chart `values.yaml` < `-f file1 -f file2` (later wins) < `--set`.

## 3. Explore chart structure (our own chart)

```
careconnect-service/
├── Chart.yaml          # name, chart version, appVersion
├── values.yaml         # defaults
├── values-dev.yaml     # per-environment overrides
├── values-prod.yaml
├── services/           # per-service overrides (patient, appointment, doctor)
└── templates/
    ├── _helpers.tpl    # named templates (reusable snippets)
    ├── configmap.yaml
    ├── deployment.yaml
    ├── service.yaml
    └── NOTES.txt       # printed after install
```
Template syntax you must know:
`{{ .Values.x }}` values, `{{ .Release.Name }}`, `{{ .Chart.Name }}`, `{{ include "name" . }}`, `{{- if }}...{{- end }}`, `{{- range }}`, `| default "x"`, `| quote`, `| nindent 4`, `toYaml`.
`{{-` trims whitespace before. YAML indentation errors are the #1 Helm bug.

```bash
helm lint 08-helm/careconnect-service
helm template patient 08-helm/careconnect-service -f 08-helm/careconnect-service/services/patient.yaml     # render only, no cluster
helm template patient 08-helm/careconnect-service --debug | more
```

## 4. Retail-store style: one chart, one release per microservice

```bash
kubectl create namespace careconnect-helm
helm install patient     08-helm/careconnect-service -n careconnect-helm -f 08-helm/careconnect-service/services/patient.yaml
helm install appointment 08-helm/careconnect-service -n careconnect-helm -f 08-helm/careconnect-service/services/appointment.yaml
helm install doctor      08-helm/careconnect-service -n careconnect-helm -f 08-helm/careconnect-service/services/doctor.yaml
kubectl get all -n careconnect-helm
helm list -n careconnect-helm
```
Environment-specific values (layer files, later wins):
```bash
helm upgrade appointment 08-helm/careconnect-service -n careconnect-helm \
  -f 08-helm/careconnect-service/services/appointment.yaml \
  -f 08-helm/careconnect-service/values-prod.yaml
kubectl get pods -n careconnect-helm          # 3 replicas now
helm upgrade appointment ... --set image.tag=9.9.9    # bad tag on purpose
helm history appointment -n careconnect-helm
helm rollback appointment 2 -n careconnect-helm
```
Atomic upgrades (auto-rollback on failure): `helm upgrade --install --atomic --timeout 2m ...`

Test: `kubectl port-forward svc/patient 9000:80 -n careconnect-helm` then `curl.exe localhost:9000/health`

## 5. Package and publish

```bash
helm package 08-helm/careconnect-service                # creates careconnect-service-0.1.0.tgz
helm install test ./careconnect-service-0.1.0.tgz -n demo --create-namespace
# publish to an OCI registry (Docker Hub / GHCR / ECR):
helm registry login registry-1.docker.io -u <user>
helm push careconnect-service-0.1.0.tgz oci://registry-1.docker.io/<user>
helm install patient oci://registry-1.docker.io/<user>/careconnect-service --version 0.1.0
```
**Versioning:** `version` = chart (bump on any template/default change, SemVer). `appVersion` = app being deployed.

## 6. Chart dependencies (umbrella charts)

Add to `Chart.yaml`:
```yaml
dependencies:
  - name: redis
    version: "20.x.x"
    repository: https://charts.bitnami.com/bitnami
```
then `helm dependency update 08-helm/careconnect-service`. (Challenge: add Redis as a dependency, toggle with `condition: redis.enabled`.)

## Cleanup
```bash
helm uninstall patient appointment doctor -n careconnect-helm
kubectl delete ns careconnect-helm demo
```

## Interview questions

- Helm vs Kustomize? (templating + packaging + releases vs overlay patches without templates)
- What happens on `helm upgrade`? (renders, 3-way merge, stores new revision as a Secret)
- Where does Helm store release info? (Secrets in the release namespace)
- How does rollback work? (re-applies an earlier stored revision, creating a new revision)
- `helm template` vs `helm install --dry-run`? (client-side render vs server-side validated render)
- How do you manage per-environment config? (values files layered with `-f`)
- Chart `version` vs `appVersion`?
- How do you make pods restart when a ConfigMap changes? (checksum annotation, see `deployment.yaml`)
