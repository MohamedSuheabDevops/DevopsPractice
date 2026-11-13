# Module-11: Kubernetes Ingress

**Course section 11 (3 demos) · Status:** ☐ not started  ☐ done

## What this shows
One entry point routing to several services. The free version uses ingress-nginx on kind; the AWS version uses an Application Load Balancer.

| Demo | Files | Needs |
|---|---|---|
| 1. AWS Load Balancer Controller installation | Module-13 | EKS |
| 2. Ingress with HTTP | `local-kind/` (free) and `eks-alb/ingress-http.yaml` | kind, or EKS |
| 3. Ingress with HTTPS/SSL | `eks-alb/ingress-https.yaml` | EKS + a domain (optional, see Module-16) |

## Run the free version (kind)
```
kind create cluster --name ing --config Module-11-kubernetes-ingress/local-kind/kind-ingress.yaml
kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s

docker build -t careconnect-portal:dev apps/portal && docker build -t careconnect-doctors:dev apps/doctors
kind load docker-image careconnect-portal:dev careconnect-doctors:dev --name ing
kubectl create namespace careconnect
kubectl apply -f Module-11-kubernetes-ingress/local-kind/apps.yaml
kubectl apply -f Module-11-kubernetes-ingress/local-kind/ingress.yaml
curl localhost/portal/health
curl localhost/doctors/health
kubectl describe ingress careconnect -n careconnect
```

## On EKS
Apply `eks-alb/ingress-http.yaml`, wait for an ADDRESS (`kubectl get ingress -n careconnect`), then `curl http://<alb-dns>/portal/health`. Delete the Ingress before destroying the cluster so the ALB is removed.

## Screenshots to take
- `docs/screenshots/module-11-ingress-curl.png`: both `curl` calls through one entry point
- `docs/screenshots/module-11-alb.png`: the ALB and its target group in the AWS console (if you ran EKS)
