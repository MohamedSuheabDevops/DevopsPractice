# Section 9: Kubernetes Secrets

Parts 1 you can practise free on kind. Parts 2 to 4 need EKS: read the files in `eks-only/`, understand the flow, practise for real if you run the EKS cluster once.

## Part 1: Secret basics (kind)

```bash
kubectl apply -f 07-secrets/01-secret-basics.yaml
kubectl get secret db-credentials -n careconnect -o yaml          # values are base64
kubectl get secret db-credentials -n careconnect -o jsonpath="{.data.DB_PASSWORD}"
# decode (PowerShell):
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("<paste>"))
# decode (bash):  echo <paste> | base64 -d

kubectl apply -f 07-secrets/02-pod-using-secret.yaml
kubectl exec secret-demo -n careconnect -- env | grep DB_
kubectl exec secret-demo -n careconnect -- ls -l /etc/secrets
kubectl exec secret-demo -n careconnect -- cat /etc/secrets/DB_PASSWORD
```

Create imperatively:
```bash
kubectl create secret generic api-key --from-literal=key=abc123 -n careconnect
kubectl create secret generic tls-files --from-file=./some.crt -n careconnect
kubectl create secret docker-registry regcred --docker-username=u --docker-password=p -n careconnect
```

**Important truths**
- base64 is **encoding, not encryption**. Anyone who can `get secret` can read it.
- Protect with: RBAC (who can read Secrets), **encryption at rest** (EKS: KMS envelope encryption), never commit Secret YAML with real values to Git.
- Env vars leak easily (logs, crash dumps, `docker inspect`-style tools). Files are slightly safer, and updated automatically when the Secret changes (env vars are not).

## Part 2: EKS Pod Identity (concept + `eks-only/pod-identity.tf`)

Goal: pods call AWS APIs without access keys.
Flow: install the **EKS Pod Identity Agent** add-on -> create IAM role trusted by `pods.eks.amazonaws.com` -> create a **pod identity association** (cluster + namespace + ServiceAccount + role) -> pods using that ServiceAccount get temporary credentials automatically.
**Pod Identity vs IRSA:** Pod Identity is simpler (no OIDC provider per cluster, no annotation on the ServiceAccount, reusable across clusters). IRSA uses the cluster's OIDC provider + `eks.amazonaws.com/role-arn` annotation.

## Part 3: Secrets Store CSI Driver + ASCP (`eks-only/secretproviderclass.yaml`)

Pod mounts a CSI volume -> driver asks AWS (via Pod Identity role) for the value from **AWS Secrets Manager** (or SSM Parameter Store) -> secret appears as a file, and optionally as a K8s Secret (`secretObjects`).
Benefits: single source of truth, rotation in AWS, access audited in CloudTrail, nothing sensitive in Git.
Gotcha: the K8s Secret only exists while a pod mounts the volume.

## Part 4: External Secrets Operator (alternative)

ESO runs in the cluster, reads from Secrets Manager and **creates ordinary K8s Secrets** on a refresh interval:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata: { name: catalog-db, namespace: careconnect }
spec:
  refreshInterval: 1h
  secretStoreRef: { name: aws-secrets, kind: ClusterSecretStore }
  target: { name: catalog-db }
  dataFrom:
    - extract: { key: careconnect/catalog/db }
```
| | CSI driver + ASCP | External Secrets Operator |
|---|---|---|
| Mechanism | volume mount at pod start | controller syncs K8s Secrets |
| K8s Secret created | optional | always |
| Works w/o mounting | no | yes (any pod can use the Secret) |

## Interview questions

- Are Kubernetes Secrets encrypted? (base64 only, unless encryption at rest is enabled)
- How do you avoid storing secrets in Git? (Secrets Manager + CSI/ESO, Sealed Secrets, SOPS)
- How does a pod authenticate to AWS without keys? (Pod Identity / IRSA)
- Env var vs mounted file for secrets?
- How do you rotate a secret without downtime?
- What's the difference between ConfigMap and Secret?
