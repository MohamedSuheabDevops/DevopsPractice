# Section 8: Kubernetes Foundation

All free: runs on **kind** (Kubernetes inside Docker). Needs Docker Desktop, `kind`, `kubectl`.
Run commands from the repo root. Every YAML here targets the namespace `careconnect`.

## 0. Create the cluster and load your image

```bash
docker build -f 02-dockerfile-mastery/Dockerfile.good -t careconnect-service:1.0.0 apps/python-service
kind create cluster --name cc --config 06-kubernetes/kind-config.yaml
kind load docker-image careconnect-service:1.0.0 --name cc
kubectl get nodes
kubectl apply -f 06-kubernetes/00-namespace.yaml
```
(kind nodes can't see your local images unless you `kind load` them. That's why `imagePullPolicy: IfNotPresent`.)

Tip: `kubectl config set-context --current --namespace=careconnect` so you can drop `-n careconnect`.

## 1. Pods

```bash
kubectl apply -f 06-kubernetes/01-pod.yaml
kubectl get pods -n careconnect -o wide
kubectl describe pod patient-pod -n careconnect
kubectl logs patient-pod -n careconnect
kubectl exec -it patient-pod -n careconnect -- sh
kubectl port-forward pod/patient-pod 9000:8000 -n careconnect      # then curl.exe localhost:9000
kubectl delete pod patient-pod -n careconnect                       # gone forever
```
A Pod is the smallest unit: 1+ containers sharing network and storage. Bare pods don't self-heal, so use a controller.

## 2. Deployments

```bash
kubectl apply -f 06-kubernetes/02-deployment.yaml
kubectl get deploy,rs,pods -n careconnect
kubectl delete pod <one-pod> -n careconnect       # a new one appears: self-healing
kubectl scale deploy appointment-service --replicas=5 -n careconnect
kubectl set image deploy/appointment-service app=careconnect-service:1.0.1 -n careconnect   # bad tag on purpose
kubectl rollout status deploy/appointment-service -n careconnect
kubectl get pods -n careconnect                    # ErrImagePull on the new pod; old ones keep serving (maxUnavailable 0)
kubectl rollout history deploy/appointment-service -n careconnect
kubectl rollout undo deploy/appointment-service -n careconnect
```
Chain: **Deployment -> ReplicaSet -> Pods**. A rolling update creates a new ReplicaSet and shifts pods gradually.
Real rollout: build `careconnect-service:1.0.1`, `kind load` it, then `kubectl set image`.

## 3. Services

```bash
kubectl apply -f 06-kubernetes/03-service-clusterip.yaml
kubectl get svc,endpoints -n careconnect
kubectl run tmp --rm -it --image=busybox:1.36 -n careconnect -- wget -qO- http://appointment-service
#   repeat it: "container" changes = load balancing across pods
kubectl apply -f 06-kubernetes/03b-service-nodeport.yaml
curl.exe http://localhost:8080
```
Service types: **ClusterIP** (internal), **NodePort** (node port 30000-32767), **LoadBalancer** (cloud LB; on EKS you'll use ALB via Ingress in Section 11), **ExternalName**, **Headless** (`clusterIP: None`).
DNS: `<svc>.<namespace>.svc.cluster.local`. Experiment: change the Service selector label to something wrong and watch `endpoints` go empty.

## 4. ConfigMaps

```bash
kubectl apply -f 06-kubernetes/04-configmap.yaml
kubectl exec deploy/doctor-service -n careconnect -- env | grep SERVICE_NAME
kubectl exec deploy/doctor-service -n careconnect -- cat /etc/config/app.properties
kubectl edit configmap doctor-config -n careconnect
```
Env vars from a ConfigMap do NOT update in running pods (restart: `kubectl rollout restart deploy/doctor-service`). Mounted files DO update (after a delay).

## 5. StatefulSets

```bash
kubectl apply -f 06-kubernetes/05-statefulset-redis.yaml
kubectl get sts,pods,pvc -n careconnect       # redis-0 then redis-1, in order. PVC per pod
kubectl exec redis-0 -n careconnect -- redis-cli set patient:1 asha
kubectl delete pod redis-0 -n careconnect      # same name comes back, same PVC attached
kubectl exec redis-0 -n careconnect -- redis-cli get patient:1     # data survived
kubectl delete sts redis -n careconnect        # PVCs stay! delete them manually to free storage
```
Deployment vs StatefulSet: stable names (`redis-0`), ordered start/stop, per-pod storage, stable DNS via headless Service. Use for databases/queues.

## 6. Probes, resources, labels (the "additional topics")

```bash
kubectl apply -f 06-kubernetes/06-broken-readiness.yaml
kubectl get pods -n careconnect -w            # 0/1 Running, then restarts
kubectl describe pod -l app=broken-service -n careconnect    # Events: probe failed 503
```
Fix it by removing the bad `DEPENDENCIES` env and re-applying.

| Probe | Question | On failure |
|---|---|---|
| **readiness** | can it take traffic? | removed from Service endpoints |
| **liveness** | is it stuck? | container restarted |
| **startup** | has slow app finished starting? | blocks the other two until done |

**Requests vs limits:** *request* = what the scheduler reserves (placement); *limit* = hard cap. CPU over limit = throttled; memory over limit = **OOMKilled**.
Try: set memory limit to `8Mi`, apply, watch `kubectl get pods` show `OOMKilled` / `CrashLoopBackOff`.

Labels and selectors:
```bash
kubectl get pods -n careconnect --show-labels
kubectl get pods -n careconnect -l tier=backend
kubectl get pods -n careconnect -l 'app in (appointment-service,doctor-service)'
kubectl label pod <pod> env=test -n careconnect
kubectl annotate pod <pod> owner=me -n careconnect
```
Labels select things. Annotations are free-form metadata (tools read them, e.g. ingress controllers).

## Cleanup

```bash
kubectl delete namespace careconnect     # removes everything inside
kind delete cluster --name cc
```

## Debug checklist (interview gold)

`kubectl get pods` -> `describe pod` (Events!) -> `logs` (`--previous` for crashed) -> `exec` -> `get events --sort-by=.lastTimestamp`.

| Status | Usual cause |
|---|---|
| Pending | no node fits (requests too big), PVC not bound |
| ImagePullBackOff | wrong tag/registry/credentials |
| CrashLoopBackOff | app crashes, bad command, failing liveness probe |
| Running 0/1 | readiness probe failing |
| OOMKilled | memory limit too low |

## Interview questions

- Pod vs Deployment vs ReplicaSet vs StatefulSet vs DaemonSet?
- How does a Service find its pods? (label selector -> Endpoints)
- Liveness vs readiness vs startup probe?
- Requests vs limits? What's QoS class (Guaranteed/Burstable/BestEffort)?
- How does a rolling update work? How do you roll back?
- What happens when you `kubectl apply` a Deployment? (API server -> etcd -> controller -> scheduler -> kubelet)
- ConfigMap vs Secret?
- How do pods talk to each other across namespaces? (`svc.namespace` DNS)
