# Module-08: Kubernetes Foundation

**Course section 8 (5 demos) · Status:** ☐ not started  ☐ done

## What this shows
Kubernetes core objects, using CareConnect services. Run it on a free local cluster (kind).

| Demo | File | Object |
|---|---|---|
| 1. Pods | `01-pod.yaml` | Pod (portal) |
| 2. Deployments | `02-deployment.yaml` | Deployment with rolling updates, probes, resources, labels (appointments) |
| 3. Services | `03-service.yaml` | ClusterIP Service |
| 4. ConfigMaps | `04-configmap.yaml` | ConfigMap as environment variables (doctors) |
| 5. StatefulSets | `05-statefulset.yaml` | StatefulSet with per-pod storage (Redis) |

Extra topics covered: labels, selectors, annotations, liveness and readiness probes, resource requests and limits.

## Set up the cluster and images
```
kind create cluster --name cc --config k8s/kind-config.yaml
for s in portal appointments doctors; do docker build -t careconnect-$s:dev apps/$s; kind load docker-image careconnect-$s:dev --name cc; done
kubectl apply -f Module-08-kubernetes-foundation/00-namespace.yaml
```

## Run it
```
kubectl apply -f Module-08-kubernetes-foundation/01-pod.yaml
kubectl get pods -n careconnect -o wide
kubectl delete pod portal-pod -n careconnect          # it does not come back

kubectl apply -f Module-08-kubernetes-foundation/02-deployment.yaml
kubectl get deploy,rs,pods -n careconnect
kubectl delete pod -l app=appointments -n careconnect # replacements appear: self-healing
kubectl scale deploy appointments --replicas=5 -n careconnect

kubectl apply -f Module-08-kubernetes-foundation/03-service.yaml
kubectl get svc,endpoints -n careconnect
kubectl run tmp --rm -it --image=busybox:1.36 -n careconnect -- wget -qO- http://appointments

kubectl apply -f Module-08-kubernetes-foundation/04-configmap.yaml
kubectl exec deploy/doctors -n careconnect -- env | grep DB_

kubectl apply -f Module-08-kubernetes-foundation/05-statefulset.yaml
kubectl get sts,pods,pvc -n careconnect

kubectl get pods -n careconnect --show-labels
kubectl get pods -n careconnect -l tier=backend
```
Cleanup: `kubectl delete namespace careconnect`

## Screenshots to take
- `docs/screenshots/module-08-deployment.png`: `kubectl get deploy,rs,pods` for appointments
- `docs/screenshots/module-08-selfheal.png`: a pod deleted and its replacement appearing
- `docs/screenshots/module-08-statefulset.png`: `kubectl get sts,pods,pvc`
