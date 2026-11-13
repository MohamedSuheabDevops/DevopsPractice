# Module-17: Karpenter, Pod-Driven Node Autoscaling

**Course section 17 (4 demos) · Status:** ☐ not started  ☐ done  ☐ explained only

## What this shows
Karpenter adds right-sized EC2 nodes when pods cannot be scheduled, and removes them when they are no longer needed. It can use **Spot** instances (up to about 70 percent cheaper) and handles Spot interruptions.

| Demo | Where |
|---|---|
| 1. Install with Terraform (IAM, SQS queue, EventBridge rules, controller) | `main.tf` (real EKS needed: Modules 07 and 13 first) |
| 2. On-demand instances | `manifests/ec2nodeclass.yaml`, `manifests/nodepool-ondemand.yaml` |
| 3. Spot instances | `manifests/nodepool-spot.yaml` |
| 4. Spot interruption handling | `manifests/spot-workload-pdb.yaml` (replicas + PodDisruptionBudget) |

## Cost warning
Real AWS, extra EC2 nodes while pods are scheduled. The NodePools cap CPU at 8 vCPUs. Delete the test workloads and NodePools when finished.

## Run it
```
cd Module-17-karpenter
terraform init && terraform apply
kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter
# edit manifests/ec2nodeclass.yaml: role -> terraform output node_role_name
kubectl apply -f manifests/ec2nodeclass.yaml -f manifests/nodepool-ondemand.yaml
kubectl apply -f manifests/inflate.yaml
kubectl scale deployment inflate --replicas=5
kubectl get nodeclaims -w
kubectl get nodes -L karpenter.sh/capacity-type,node.kubernetes.io/instance-type
kubectl scale deployment inflate --replicas=0          # watch the node disappear
kubectl apply -f manifests/nodepool-spot.yaml
```
Cleanup order: delete workloads, then `kubectl delete nodepool --all`, wait until `kubectl get nodeclaims` is empty, then `terraform destroy`.

## Can't run EKS? Free alternative
Practise the PodDisruptionBudget on kind: apply `manifests/spot-workload-pdb.yaml` (remove the `nodeSelector` line), then `kubectl drain` a worker and watch the budget protect the pods.

## What to be able to explain
Karpenter vs Cluster Autoscaler, NodePool vs EC2NodeClass, Spot interruption flow (EventBridge, SQS, drain, 2-minute warning), and why a PodDisruptionBudget matters.

## Screenshots to take
- `docs/screenshots/module-17-nodeclaims.png`: `kubectl get nodeclaims` and nodes after scaling up
- `docs/screenshots/module-17-spot-nodes.png`: nodes labelled `spot`
