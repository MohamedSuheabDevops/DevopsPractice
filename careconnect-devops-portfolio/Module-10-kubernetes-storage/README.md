# Module-10: Kubernetes Persistent Storage

**Course section 10 (3 demos) · Status:** ☐ not started  ☐ done

## What this shows
How databases keep their data when pods are replaced.

| Demo | File | Concepts |
|---|---|---|
| 1. EBS CSI driver | `04-gp3-storageclass-eks.yaml` | StorageClass backed by EBS (EKS only, needs Module-13) |
| 2. Integration with a database | `03-statefulset-postgres.yaml` | StatefulSet with storage, used by billing |
| 3. Dynamic and static volumes | `01-static-pv-pvc.yaml`, `02-dynamic-pvc.yaml` | PV, PVC, StorageClass, dynamic provisioning |

## Run it (kind)
```
kubectl apply -f Module-08-kubernetes-foundation/00-namespace.yaml
kubectl apply -f Module-10-kubernetes-storage/01-static-pv-pvc.yaml
kubectl apply -f Module-10-kubernetes-storage/02-dynamic-pvc.yaml
kubectl get pv,pvc -n careconnect

kubectl apply -f Module-10-kubernetes-storage/03-statefulset-postgres.yaml
kubectl wait --for=condition=ready pod/pg-0 -n careconnect --timeout=120s
kubectl exec pg-0 -n careconnect -- psql -U postgres -c "CREATE TABLE invoices(id int); INSERT INTO invoices VALUES (1),(2);"
kubectl delete pod pg-0 -n careconnect
kubectl wait --for=condition=ready pod/pg-0 -n careconnect --timeout=120s
kubectl exec pg-0 -n careconnect -- psql -U postgres -c "SELECT * FROM invoices;"     # data survived
```

## Key point to explain
Deleting a **pod** keeps the data. Deleting the **PVC** deletes it (reclaim policy `Delete`), so back up anything you cannot lose.

## Screenshots to take
- `docs/screenshots/module-10-pv-pvc.png`: `kubectl get pv,pvc`
- `docs/screenshots/module-10-data-survived.png`: the query result after the pod was deleted
