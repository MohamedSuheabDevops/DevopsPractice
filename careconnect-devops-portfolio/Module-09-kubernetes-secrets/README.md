# Module-09: Kubernetes Secrets

**Course section 9 (4 demos) · Status:** ☐ not started  ☐ done

## What this shows
How the `billing` service receives its database credentials, from basic Secrets to AWS Secrets Manager.

| Demo | Where | Idea |
|---|---|---|
| 1. Secrets basics | `01-secret.yaml`, `02-pod-using-secret.yaml` | Secret as environment variable and as mounted files |
| 2. EKS Pod Identity agent | `eks-only/pod-identity.tf` | A ServiceAccount gets an IAM role, with no access keys |
| 3. Secrets Store CSI driver | `eks-only/secretproviderclass.yaml` | Mount an AWS Secrets Manager secret into the pod |
| 4. Secrets Manager integration (billing) | `eks-only/deployment-with-csi.yaml` | The billing Deployment using it |

Files under `eks-only/` need a real EKS cluster (Modules 07 and 13). Demo 1 runs on kind.

## Run demo 1
```
kubectl apply -f Module-09-kubernetes-secrets/01-secret.yaml
kubectl get secret billing-db-credentials -n careconnect -o yaml          # values are only base64
kubectl get secret billing-db-credentials -n careconnect -o jsonpath="{.data.DB_PASSWORD}" | base64 -d; echo
kubectl apply -f Module-09-kubernetes-secrets/02-pod-using-secret.yaml
kubectl exec billing-secret-demo -n careconnect -- ls /etc/secrets
kubectl exec billing-secret-demo -n careconnect -- cat /etc/secrets/DB_PASSWORD
```

## Key point to explain
base64 is **encoding, not encryption**. Real protection comes from RBAC, encryption at rest (KMS), and keeping the real secret in AWS Secrets Manager instead of Git.

## Screenshots to take
- `docs/screenshots/module-09-secret-decoded.png`: the base64 value and the decoded value
- `docs/screenshots/module-09-secret-mounted.png`: the secret visible inside the pod as a file
