# Module-19: Helm Retail Store (CareConnect) with the AWS Data Plane

**Course section 19 (1 comprehensive demo) · Status:** ☐ not started  ☐ done  ☐ validated only

## What this shows
The whole CareConnect platform deployed with Helm on EKS: separate releases per microservice, environment-specific values, managed AWS data services, chart versioning and release management.

| Course topic | Where |
|---|---|
| Separate chart usage for each microservice | one chart, five releases: `charts/careconnect-service` + `gitops/envs/eks/<service>.yaml` |
| Managing AWS data plane services | Module-14 (Terraform) and the endpoints in each service's `env:` |
| Environment-specific values | `gitops/envs/dev/` (kind) vs `gitops/envs/eks/` (AWS) |
| Chart versioning and release management | `Chart.yaml`, `helm history`, `helm rollback` |

## Run it (EKS from Modules 07 and 13)
```
# images must exist on Docker Hub (a release from Module-21 pushes them). Replace <dockerhub-user> in gitops/envs/eks/*.yaml
for s in portal appointments billing doctors booking; do
  helm upgrade --install $s charts/careconnect-service -n careconnect --create-namespace \
    -f gitops/envs/eks/$s.yaml --atomic --timeout 5m
done
helm list -n careconnect
kubectl get deploy,svc,ingress,hpa,pdb -n careconnect
kubectl get ingress -n careconnect                      # one shared ALB (group.name)
curl http://<alb-dns>/portal/health
curl http://<alb-dns>/doctors/health
helm history billing -n careconnect
```
Roll one back: `helm upgrade billing ... --set image.tag=does-not-exist --atomic` fails and rolls back by itself.

## Teardown (important, same day)
```
helm uninstall portal appointments billing doctors booking -n careconnect     # removes the Ingresses, and so the ALB
kubectl get svc,ingress,pvc -A                                                # nothing with an external address left
# then terraform destroy: Module-13, then Module-07
aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerArn"
```

## Screenshots to take
- `docs/screenshots/module-19-helm-list.png`: `helm list -n careconnect`
- `docs/screenshots/module-19-alb-curl.png`: `curl` of two services through the ALB
