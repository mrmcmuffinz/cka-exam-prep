# Prompt: StatefulSets (assignment-1)

## Header

- **Series:** StatefulSets (1 of 1)
- **CKA domain:** Workloads & Scheduling (15%)
- **Competencies covered:** Understand application deployments (stateful workloads with stable identity), self-healing primitives for stateful workloads
- **Course sections referenced:** S2 (pods and controllers), S8 (storage for the `volumeClaimTemplates` portion), S9 (for headless Services)
- **Prerequisites:** `pods/assignment-7` (Workload Controllers), `services/assignment-1` (headless Services), `storage/assignment-2` (PVC fundamentals)

## Scope declaration

### In scope for this assignment

*StatefulSet spec structure*
- `apiVersion: apps/v1`, `kind: StatefulSet`
- `spec.serviceName` (required; points at a headless Service for DNS)
- `spec.selector` and `spec.template` (same pattern as Deployments)
- `spec.replicas`
- `spec.volumeClaimTemplates` (creates a unique PVC per pod)
- `spec.podManagementPolicy` (OrderedReady vs Parallel)
- `spec.updateStrategy` (RollingUpdate and OnDelete types)

*Headless Service requirement*
- `spec.clusterIP: None` on the Service
- Why the StatefulSet needs a headless Service (to publish per-pod DNS records)
- DNS names produced: `<pod-name>.<service-name>.<namespace>.svc.cluster.local`
- Using `nslookup` from another pod to resolve a specific replica

*Ordered pod lifecycle*
- Pod creation in order (pod-0, then pod-1, then pod-2), each must be Ready before the next starts under OrderedReady
- Pod deletion in reverse order (pod-2, pod-1, pod-0) during scale-down
- Parallel mode (`podManagementPolicy: Parallel`) for when ordering is not required
- Consequences of a pod stuck in Pending (blocks all subsequent pods under OrderedReady)

*Per-pod persistent storage*
- `volumeClaimTemplates` generates PVCs named `<volume-name>-<pod-name>-<ordinal>`
- Each pod keeps the same PVC across restarts and reschedules
- Scale-down does not delete the PVCs (intentional; data survives scale-down)
- Scale-up reuses existing PVCs if the pod name matches

*Update strategies*
- `updateStrategy: RollingUpdate` with `partition` for staged rollouts (only pods with ordinal >= partition get the new template)
- `updateStrategy: OnDelete` for manual update control (user deletes pods to trigger template re-materialization)
- Revision history via ControllerRevision objects

*Scaling*
- `kubectl scale sts <name> --replicas=N`
- Scale-up creates new pods and PVCs in order
- Scale-down terminates pods in reverse order but leaves PVCs

*Diagnostic workflow*
- Reading `kubectl describe sts` for status conditions
- Reading `kubectl get pods -l <selector> -o wide` to see pod ordinals and nodes
- Reading Events for PVC binding failures
- Debugging a stuck rollout (pod-N stuck in ImagePullBackOff blocks the rolling update)

### Out of scope (covered in other assignments, do not include)

- Long-running stateless workloads (ReplicaSets, Deployments): covered in `pods/assignment-7`
- PV/PVC mechanics (StorageClass, access modes, reclaim policy): covered in the `storage/` series
- Headless Service mechanics beyond the StatefulSet requirement: covered in `services/assignment-1`
- Pod DNS format: covered in `coredns/assignment-1`
- Backup and restore of stateful application data (out of CKA scope)
- Operator-based stateful workload management: covered in `crds-and-operators/`

## Environment requirements

- Multi-node kind cluster per `docs/cluster-setup.md#multi-node-kind-cluster` so that pod distribution across workers and ordered lifecycle are observable
- kind's default `rancher.io/local-path` StorageClass satisfies `volumeClaimTemplates` without extra setup

## Resource gate

All CKA resources are in scope. The assignment uses StatefulSets, headless Services, PVCs (created automatically via `volumeClaimTemplates`), and pods that reference the PVCs.

## Topic-specific conventions

- Every StatefulSet exercise must include a headless Service with `clusterIP: None` selecting the same pods. Without it, per-pod DNS does not work.
- Resource names: pick ordinal-friendly base names (`web`, `db`, `cache`) that read naturally with ordinal suffixes (`web-0`, `web-1`, `web-2`).
- Tutorial should demonstrate pod-specific DNS lookup by running `nslookup web-0.web-hdr` from a curl or busybox pod in the same namespace.
- Verification that storage is per-pod: write a distinct file to each pod's volume from inside the pod, then delete the pod and verify the file survives the restart.
- Partitioned update exercises should use replicas=5 or greater so the partition's effect is clearly visible.
- Cleanup must explicitly delete PVCs after StatefulSet deletion (StatefulSet controller does not garbage-collect them).

## Cross-references

**Prerequisites (must be completed first):**
- `exercises/pods/assignment-7`: Deployments and reconciliation model
- `exercises/services/assignment-1`: headless Services
- `exercises/storage/assignment-2`: PVC fundamentals

**Adjacent topics:**
- `exercises/jobs-and-cronjobs/`: batch workloads (contrasts with long-running stateful)
- `exercises/autoscaling/`: HPA can target StatefulSets (one exercise in the autoscaling assignment covers this)

**Forward references:**
- `exercises/troubleshooting/assignment-1`: application-layer troubleshooting will include StatefulSet-specific scenarios (stuck rolling update, per-pod storage issues)
