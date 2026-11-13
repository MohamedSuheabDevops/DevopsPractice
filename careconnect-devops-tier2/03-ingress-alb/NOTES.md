# Section 11: Kubernetes Ingress (HTTP, HTTPS, ALB)

Two tracks. Do **Track A** (free, kind) to learn Ingress itself. Do **Track B** (EKS) once to see the AWS ALB version.

## The idea
A `Service` of type LoadBalancer = one cloud LB per service (expensive). An **Ingress** = one entry point that routes by host and path to many Services.
Two parts: the **Ingress resource** (your routing rules) and an **Ingress controller** (the thing that implements them: nginx, or the AWS Load Balancer Controller which makes an ALB).

## Track A: free, on kind (ingress-nginx)

```bash
kind create cluster --name ing --config 03-ingress-alb/local-kind/kind-ingress.yaml
kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s

docker build -f 02-dockerfile-mastery/Dockerfile.good -t careconnect-service:1.0.0 apps/python-service   # from the Tier 1 kit
kind load docker-image careconnect-service:1.0.0 --name ing
kubectl create namespace careconnect
kubectl apply -f 03-ingress-alb/local-kind/apps.yaml

# path-based routing
kubectl apply -f 03-ingress-alb/local-kind/ingress-path.yaml
curl.exe http://localhost/patients/health
curl.exe http://localhost/appointments/health
kubectl get ingress -n careconnect
kubectl describe ingress careconnect -n careconnect

# host-based routing (no DNS needed: fake the Host header)
kubectl delete -f 03-ingress-alb/local-kind/ingress-path.yaml
kubectl apply  -f 03-ingress-alb/local-kind/ingress-host.yaml
curl.exe -H "Host: patients.local" http://localhost/health
curl.exe -H "Host: appointments.local" http://localhost/health
curl.exe http://localhost/health        # 404: no rule for this host
```
Experiments: break the Service name in the Ingress (503/404?), scale a deployment to 0 (503), `kubectl logs -n ingress-nginx deploy/ingress-nginx-controller`.

**TLS locally (self-signed):**
```bash
openssl req -x509 -nodes -days 30 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=patients.local"
kubectl create secret tls patients-tls --cert=tls.crt --key=tls.key -n careconnect
```
Add to the Ingress spec: `tls: [{hosts: [patients.local], secretName: patients-tls}]`, then `curl.exe -k --resolve patients.local:443:127.0.0.1 https://patients.local/health`.

Cleanup: `kind delete cluster --name ing`

## Track B: AWS ALB on EKS (needs 01 + 02 applied)

```bash
kubectl create namespace careconnect
kubectl apply -f 03-ingress-alb/eks-alb/apps-clusterip.yaml      # edit the image first
kubectl apply -f 03-ingress-alb/eks-alb/ingress-http.yaml
kubectl get ingress -n careconnect -w                             # ADDRESS appears in 2-3 min
curl http://<alb-dns-name>/health
kubectl describe ingress careconnect-alb -n careconnect
kubectl logs -n kube-system deploy/aws-load-balancer-controller   # if ADDRESS never appears: read this
```
Check in the AWS console: EC2 > Load Balancers > the new ALB > listeners > target group > **targets are pod IPs**, health `healthy`.

**HTTPS/SSL** (`ingress-https.yaml`): needs a domain + ACM certificate. Without a domain, read the file and understand each annotation. If you have a domain: request the cert in ACM (DNS validation), put the ARN in the annotation, create a Route 53/CNAME record pointing your host to the ALB. TLS terminates **at the ALB**; ACM renews the certificate automatically.

| Annotation | Meaning |
|---|---|
| `scheme` | internet-facing (public subnets) vs internal (private) |
| `target-type: ip` | ALB -> pod IP directly (best). `instance` = via NodePort |
| `healthcheck-path` | what the target group probes. Wrong path = targets `unhealthy` = 502/503 |
| `listen-ports` + `ssl-redirect` | open 443 and redirect HTTP |
| `certificate-arn` | ACM cert for TLS termination |
| `group.name` | merge many Ingresses into one ALB |

Subnet discovery: public subnets need tag `kubernetes.io/role/elb=1`, private `kubernetes.io/role/internal-elb=1` (your Tier 1 VPC module already sets them).

**Delete the Ingress before `terraform destroy`:** `kubectl delete ingress --all -n careconnect`, or the ALB is orphaned and blocks VPC deletion.

## Troubleshooting table
| Symptom | Likely cause |
|---|---|
| ADDRESS empty | controller not running/IAM denied, subnets not tagged |
| 502 / 503 from ALB | targets unhealthy: wrong health-check path/port, readiness failing, SG blocks ALB->pod |
| 404 | no matching host/path rule |
| Works by IP not by name | DNS record missing |
| HTTPS cert error | ARN in wrong region, cert not validated, host not covered by cert |

## Interview questions
- Service types vs Ingress: when do you use each?
- ALB vs NLB? (L7 HTTP routing vs L4 TCP, static IPs)
- `target-type: ip` vs `instance`?
- Where does TLS terminate, and how do certificates renew? (ACM at ALB; nginx would use cert-manager)
- How do you share one ALB across many apps? (`group.name`)
- A user gets 502 from the ALB. How do you debug? (target health, probe path, SGs, pod logs)
- What does an Ingress controller do that the Ingress resource doesn't?
