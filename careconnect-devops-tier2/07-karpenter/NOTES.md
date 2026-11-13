# Section 17: Karpenter (concept-first)

Karpenter needs real EKS and a lot of IAM/SQS/EventBridge wiring, so treat this as **learn it, draw it, explain it**.
The manifests in `manifests/` are reference examples for the day you run it. Check the Karpenter docs for the exact install version; the API (v1) fields change between releases.

## Problem it solves
Cluster Autoscaler scales *node groups* (fixed instance types). It reacts slowly and wastes capacity.
**Karpenter** watches **Pending pods**, looks at their requests/constraints, and launches the **cheapest right-sized EC2 instance** directly (about a minute), then removes nodes when no longer needed.

```
Pending pod (requests 2 CPU, 4Gi)
   -> Karpenter reads NodePool rules + EC2NodeClass
   -> calls EC2 CreateFleet: picks best-fit instance (spot or on-demand)
   -> node joins cluster -> pod schedules
Later: pods gone / nodes underused -> consolidation: move pods, terminate nodes
```

## The two custom resources
- **NodePool** (`karpenter.sh/v1`): *what* nodes are allowed. Requirements (capacity type, arch, instance family/size), limits, disruption/consolidation rules, `expireAfter`.
- **EC2NodeClass** (`karpenter.k8s.aws/v1`): *how* to build them on AWS. AMI, IAM role, subnets, security groups (found by tag `karpenter.sh/discovery`), disk.

## Installation (what the course does with Terraform)
1. Tag private subnets + node security group with `karpenter.sh/discovery=<cluster>`.
2. IAM: **controller role** (Pod Identity; can call EC2/pricing/SQS) and **node role** (like the managed node group role).
3. **SQS queue + EventBridge rules** for interruption events (see below).
4. Helm install Karpenter into `kube-system`, with a small **managed node group** to run Karpenter itself (it can't provision the node it runs on).
5. Apply the EC2NodeClass + NodePool.

## Sizing and consolidation (Karpenter, part 2)
- Karpenter packs pods using their **requests**, not real usage. Wrong requests = wrong nodes. Set honest requests.
- `consolidationPolicy: WhenEmptyOrUnderutilized` deletes empty nodes and replaces several lightly-used nodes with one cheaper node.
- `limits.cpu` caps spend. `expireAfter` forces regular node replacement.

## Spot (part 3)
- Spot = spare EC2 capacity at up to ~70% discount, but AWS can reclaim it with **2 minutes' notice**.
- **Diversify:** allow many instance families/sizes/AZs. A narrow list = all nodes interrupted together.
- Good for stateless, replicated, restart-tolerant work. Keep databases and singletons on on-demand.
- Common production design: on-demand NodePool for critical pods, spot NodePool for the rest, steered with `nodeSelector`/affinity or taints.

## Spot interruption handling (part 4)
```
AWS decides to reclaim a spot instance
  -> EventBridge rule ("EC2 Spot Instance Interruption Warning", also rebalance, health, state-change events)
  -> SQS queue (Karpenter's interruption queue)
  -> Karpenter reads it ->  cordons + drains the node immediately
  -> launches a replacement  -> evicted pods reschedule
  (all inside the 2-minute window)
```
What makes it **zero-downtime**:
- `replicas >= 2` spread across nodes/zones (`topologySpreadConstraints`)
- **PodDisruptionBudget** (see `workload-spot-pdb.yaml`): limits how many pods may be evicted at once
- readiness probes: traffic only goes to ready pods
- short `terminationGracePeriodSeconds` and graceful SIGTERM handling (remember exec-form CMD from Dockerfile Mastery!)

## Things you CAN practise for free
```bash
kind create cluster --name pdb
kubectl create namespace careconnect
# remove the nodeSelector line from workload-spot-pdb.yaml first (kind has no spot nodes), set a real/loaded image
kubectl apply -f 07-karpenter/manifests/workload-spot-pdb.yaml
kubectl get pdb -n careconnect
kubectl drain <kind-worker-node> --ignore-daemonsets --delete-emptydir-data   # PDB blocks/limits evictions: read the output
kubectl uncordon <node>
```
Experiment: set `minAvailable: 4` (equal to replicas) and try to drain: it refuses (`Cannot evict pod ... disruption budget`). This is exactly what protects you during spot reclaim and node upgrades, and what can *block* upgrades if set too strictly.

## Karpenter vs Cluster Autoscaler
| | Cluster Autoscaler | Karpenter |
|---|---|---|
| Unit | node groups (ASGs) | individual instances |
| Instance choice | fixed per group | any type that fits, cheapest first |
| Speed | slower | faster (direct EC2 API) |
| Consolidation | basic scale-down | active bin-packing/replacement |
| Spot | per-group config | native, diversified |

## Interview questions
- How does Karpenter decide what to launch? (pending pod requests + NodePool constraints)
- NodePool vs EC2NodeClass?
- How do you save ~70% with Spot safely? What are the risks?
- What happens during a spot interruption? (EventBridge -> SQS -> cordon/drain, 2-minute warning)
- Why a PodDisruptionBudget? What breaks if it's too strict?
- Why does Karpenter itself run on a managed node group (or Fargate)?
- HPA + Karpenter: who scales what?
- What is consolidation, and what are its risks? (churn: use PDBs, `do-not-disrupt` annotation)
