# Module-18: Horizontal Pod Autoscaler (HPA)

**Course section 18 (1 comprehensive demo) · Status:** ☐ not started  ☐ done

## What this shows
Pods scale up and down with load: CPU-based and memory-based autoscaling. (The HPA scales **pods**; Karpenter in Module-17 scales **nodes**.) Runs free on kind with a CPU-hungry demo app.

## Run it
```
kind create cluster --name hpa
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch -n kube-system deployment metrics-server --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl rollout status deploy/metrics-server -n kube-system
kubectl top nodes

kubectl create namespace careconnect
kubectl apply -f Module-18-hpa/01-php-apache.yaml
kubectl apply -f Module-18-hpa/02-hpa-cpu.yaml
kubectl get hpa -n careconnect -w
```
In a second terminal, create load:
```
kubectl run load -n careconnect --rm -it --image=busybox:1.36 --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"
```
Watch `REPLICAS` rise, stop the load, and watch it fall (about 5 minutes). Then `kubectl apply -f Module-18-hpa/03-hpa-cpu-memory-behavior.yaml` for CPU + memory with custom scaling speed.

On EKS the real services scale the same way: `gitops/envs/eks/*.yaml` enables `autoscaling` in the Helm chart.

## Key point to explain
`desiredReplicas = ceil(currentReplicas x currentMetric / targetMetric)`, and pods must have resource **requests** for the percentage to work.

## Screenshots to take
- `docs/screenshots/module-18-hpa-scaling.png`: `kubectl get hpa -w` showing replicas increasing
