# Module-12: Helm Package Manager

**Course section 12 (5 demos) · Status:** ☐ not started  ☐ done

## What this shows
Helm lets one chart deploy all five CareConnect services. The chart is in `charts/careconnect-service/`; each service's settings are in `gitops/envs/dev/<service>.yaml`.

Install Helm: https://helm.sh/docs/intro/install/ then `helm version`.

## Demo 1: Helm basics
```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo nginx
helm install web bitnami/nginx -n demo --create-namespace
helm list -n demo
helm uninstall web -n demo
```

## Demo 2: custom values and overrides
```
helm install web bitnami/nginx -n demo --set replicaCount=2
helm get values web -n demo
helm upgrade web bitnami/nginx -n demo --set replicaCount=3 --reuse-values
helm history web -n demo
helm rollback web 1 -n demo
helm uninstall web -n demo
```

## Demo 3: chart exploration (our chart)
```
ls charts/careconnect-service charts/careconnect-service/templates
helm lint charts/careconnect-service -f gitops/envs/dev/portal.yaml
helm template portal charts/careconnect-service -f gitops/envs/dev/portal.yaml | more
```
Templates: `deployment`, `service`, `configmap`, `serviceaccount`, `pdb`, `hpa`, `ingress` and shared `_helpers.tpl`.

## Demo 4: package and publish
```
helm package charts/careconnect-service
helm registry login registry-1.docker.io -u <dockerhub-user>
helm push careconnect-service-0.3.0.tgz oci://registry-1.docker.io/<dockerhub-user>
```

## Demo 5: deploy the whole CareConnect store with Helm (kind)
```
kind create cluster --name cc --config k8s/kind-config.yaml
for s in portal appointments billing doctors booking; do docker build -t careconnect-$s:dev apps/$s; kind load docker-image careconnect-$s:dev --name cc; done
kubectl create namespace careconnect
kubectl apply -f k8s/platform/
for s in portal appointments billing doctors booking; do helm upgrade --install $s charts/careconnect-service -n careconnect -f gitops/envs/dev/$s.yaml; done
helm list -n careconnect
kubectl get pods -n careconnect
helm upgrade appointments charts/careconnect-service -n careconnect -f gitops/envs/dev/appointments.yaml --set replicaCount=3
helm history appointments -n careconnect
helm rollback appointments 1 -n careconnect
```
Clean up: `helm uninstall portal appointments billing doctors booking -n careconnect`

## Key points
Values layering (`-f` files, then `--set`), one chart reused by every service, chart `version` vs `appVersion`, and rollback.

## Screenshots to take
- `docs/screenshots/module-12-helm-list.png`: `helm list -n careconnect` showing 5 releases
- `docs/screenshots/module-12-helm-template.png`: `helm template` output
