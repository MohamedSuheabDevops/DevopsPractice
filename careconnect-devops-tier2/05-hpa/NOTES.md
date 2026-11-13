# Section 18: Horizontal Pod Autoscaler (HPA)

Runs free on kind. On EKS, the same manifests work; the add-on project already installs metrics-server.

## 1. Install Metrics Server (kind)
```bash
kind create cluster --name hpa
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# kind's kubelet uses self-signed certs, so tell metrics-server to skip verification (KIND ONLY):
kubectl patch -n kube-system deployment metrics-server --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl rollout status deploy/metrics-server -n kube-system
kubectl top nodes                      # takes ~1 min before data appears
kubectl top pods -A
```
PowerShell: put the patch JSON in a file (`patch.json`) and use `--patch-file patch.json` to avoid quoting issues.

## 2. CPU-based autoscaling
```bash
kubectl create namespace careconnect
kubectl apply -f 05-hpa/01-php-apache.yaml
kubectl apply -f 05-hpa/02-hpa-cpu.yaml
kubectl get hpa -n careconnect -w      # TARGETS <unknown> for a minute, then 0%/50%
```
In a second terminal, generate load:
```bash
kubectl run load-generator -n careconnect --rm -it --image=busybox:1.36 --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"
```
Watch `REPLICAS` climb (up to 8), then press Ctrl+C on the load generator and watch it scale down after the stabilization window (about 5 minutes by default).
```bash
kubectl describe hpa php-apache -n careconnect      # Events explain every decision
kubectl get pods -n careconnect -w
```

**The formula:** `desiredReplicas = ceil( currentReplicas x currentMetric / targetMetric )`.
Example: 1 pod at 200% CPU with a 50% target -> ceil(1 x 200/50) = 4 pods.

**Requirements that bite people**
- Pods MUST have `resources.requests` for the metric (utilization is % of the *request*). No request = `<unknown>`.
- Metrics Server must be healthy.
- Don't set `replicas:` in the Deployment manifest when HPA manages it (Helm/GitOps will fight the HPA). Omit it.

## 3. CPU + memory + behavior
```bash
kubectl apply -f 05-hpa/03-hpa-cpu-memory-behavior.yaml
kubectl get hpa -n careconnect
```
Memory-based HPA works poorly for apps that never release memory (JVMs): scaling up won't lower usage. Prefer CPU or custom/request-rate metrics (KEDA, Prometheus adapter) for those.

Imperative shortcut: `kubectl autoscale deploy php-apache --cpu-percent=50 --min=1 --max=8 -n careconnect`

## 4. HPA + Karpenter (concept, practised in `07-karpenter`)

```
traffic up -> CPU up -> HPA adds pods -> pods Pending (no room) -> Karpenter launches a node -> pods scheduled
traffic down -> HPA removes pods -> nodes empty/underused -> Karpenter consolidates and terminates nodes
```
HPA scales **pods**. Karpenter (or Cluster Autoscaler) scales **nodes**. Without node autoscaling, HPA just creates Pending pods once the cluster is full.
Related: **VPA** resizes pod requests (don't use VPA and HPA on the same CPU metric); **KEDA** scales on events (SQS queue length is perfect for the Orders/Checkout path).

## Exercises
1. Set the CPU request to `50m`: scaling becomes far more sensitive. Why?
2. Remove `resources.requests` and apply: read `kubectl describe hpa` for the error.
3. Set `maxReplicas: 2` and run the load: see `ScalingLimited` condition.
4. Add a PodDisruptionBudget (`minAvailable: 1`) for the app.
5. Scale the metrics-server to 0 and see what HPA reports.

## Cleanup
`kind delete cluster --name hpa`

## Interview questions
- How does the HPA decide the number of replicas? (formula above)
- Why must you set resource requests?
- HPA vs VPA vs Cluster Autoscaler vs Karpenter vs KEDA?
- What is the stabilization window and why does scale-down lag?
- Pods are Pending after HPA scaled up. Why, and what fixes it? (no node capacity -> node autoscaler)
- What if CPU and memory metrics disagree? (takes the larger result)
- How do you autoscale on queue depth or requests-per-second?
