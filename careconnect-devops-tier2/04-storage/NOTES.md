# Section 10: Kubernetes Persistent Storage

Practise on kind (free). The EKS/EBS parts are in `04-gp3-storageclass-eks.yaml` and the notes below.

```bash
kind create cluster --name st
kubectl create namespace careconnect
kubectl get storageclass            # "standard (default)" = local-path provisioner
```

## The model
```
Pod --uses--> PVC (claim: "I need 5Gi RWO") --binds--> PV (the actual disk) <--created by-- StorageClass (provisioner)
```
- **PV** = a piece of storage (cluster-scoped). **PVC** = a request for storage (namespaced). **StorageClass** = a template + provisioner for creating PVs on demand.
- **Access modes:** `ReadWriteOnce` (one node), `ReadOnlyMany`, `ReadWriteMany` (EFS/NFS, not EBS), `ReadWriteOncePod`.
- **Reclaim policy:** `Delete` (disk removed with PVC) or `Retain` (kept, manual cleanup).

## Exercise 1: static provisioning
```bash
kubectl apply -f 04-storage/01-static-pv-pvc.yaml
kubectl get pv,pvc -n careconnect                 # PVC Bound to manual-pv
kubectl exec writer-static -n careconnect -- cat /data/log.txt
kubectl delete pod writer-static -n careconnect
kubectl apply -f 04-storage/01-static-pv-pvc.yaml  # recreate pod: file still there, line appended
kubectl exec writer-static -n careconnect -- cat /data/log.txt
kubectl delete pvc manual-pvc -n careconnect
kubectl get pv                                    # status Released (Retain keeps it)
```

## Exercise 2: dynamic provisioning
```bash
kubectl apply -f 04-storage/02-dynamic-pvc.yaml
kubectl get pvc -n careconnect                    # Pending until the pod is scheduled (WaitForFirstConsumer)
kubectl get pv                                    # a PV was created for you
kubectl exec writer-dynamic -n careconnect -- cat /data/log.txt
kubectl describe storageclass standard
```

## Exercise 3: StatefulSet with persistent storage (database)
```bash
kubectl apply -f 04-storage/03-statefulset-postgres.yaml
kubectl get sts,pods,pvc -n careconnect
kubectl exec pg-0 -n careconnect -- psql -U postgres -c "CREATE TABLE t(id int); INSERT INTO t VALUES (1),(2);"
kubectl delete pod pg-0 -n careconnect                      # StatefulSet recreates it
kubectl wait --for=condition=ready pod/pg-0 -n careconnect --timeout=90s
kubectl exec pg-0 -n careconnect -- psql -U postgres -c "SELECT * FROM t;"      # data survived
kubectl scale sts pg --replicas=0 -n careconnect ; kubectl get pvc -n careconnect   # PVC remains!
kubectl delete sts pg -n careconnect ; kubectl delete pvc data-pg-0 -n careconnect  # you must delete it yourself
```
PVC name pattern: `<template-name>-<statefulset>-<ordinal>` = `data-pg-0`.

## On EKS (read, or do once on the cluster from Tier 2 part 1)
```bash
kubectl get storageclass                     # gp2 may exist by default; EBS CSI add-on needed for gp3
kubectl apply -f 04-storage/04-gp3-storageclass-eks.yaml
kubectl apply -f 04-storage/03-statefulset-postgres.yaml   # an EBS volume appears in the AWS console
kubectl get pv -o wide
# expand it:
kubectl patch pvc data-pg-0 -n careconnect -p '{"spec":{"resources":{"requests":{"storage":"1Gi"}}}}'
kubectl get pvc -n careconnect -w
```
EBS facts: **zonal** (a volume lives in one AZ, so the pod must be scheduled there), attaches to one node at a time, `WaitForFirstConsumer` avoids creating a volume in the wrong AZ. For shared storage across pods/AZs use **EFS** (RWX).
Delete PVCs before destroying the cluster, or EBS volumes stay and keep billing.

## Databases: in-cluster vs managed
Running Postgres in a StatefulSet is fine for learning/dev. Production usually uses **RDS** (backups, failover, patching handled), see `06-data-plane`. Know the trade-off in interviews.

## Cleanup
`kind delete cluster --name st`

## Interview questions
- PV vs PVC vs StorageClass?
- Static vs dynamic provisioning?
- What happens to data when a pod is deleted? When the PVC is deleted? (reclaim policy)
- Why `WaitForFirstConsumer`?
- Can an EBS volume be mounted in two AZs / by two nodes? (no; use EFS)
- Why StatefulSet and not Deployment for a database?
- How do you back up a PV? (VolumeSnapshots / EBS snapshots / app-level dumps)
- How do you resize a volume? (`allowVolumeExpansion`)
