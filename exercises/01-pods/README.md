# Pods

**CKA Domain:** Workloads & Scheduling (15%)
**Competencies covered:** Application deployments, rolling updates/rollbacks, ConfigMaps
and Secrets, workload autoscaling, self-healing primitives, Pod admission and scheduling

---

## Why Seven Assignments

Pods are the foundational object in Kubernetes. Every other CKA topic builds on the
ability to construct, configure, schedule, and diagnose pods. The breadth of the pod
spec alone (containers, init containers, volumes, probes, scheduling constraints,
resource limits, security contexts, multi-container patterns) produces well over 30
distinct subtopics. Cramming that into one or two assignments would either leave
critical areas unpracticed or make each assignment so long that it loses focus.

The decomposition follows the pod spec's natural structure. Assignment 1 establishes
the spec itself and the mechanics of running containers. Assignments 2 through 6 each
add one layer of configuration or behavior on top of the base spec. Assignment 7
transitions from individual pods to the controllers that manage them. Each assignment
assumes the pod spec knowledge from earlier assignments and explicitly defers topics
that belong to later ones, so the series reads as a coherent progression rather than
seven independent modules.

---

## Assignments

| Assignment | Title | Covers | Prerequisites |
|---|---|---|---|
| assignment-1 | Pod Fundamentals | Spec structure, single/multi-container, commands/args, env vars, restart policy, image pull policy, init containers, pod phases | None |
| assignment-2 | Pod Configuration Injection | ConfigMaps, Secrets, projected volumes, downward API, immutable configs | Assignment 1 |
| assignment-3 | Pod Health and Observability | Liveness/readiness/startup probes, lifecycle hooks, termination, diagnostic workflow | Assignment 1 |
| assignment-4 | Pod Scheduling and Placement | nodeSelector, node affinity, pod affinity/anti-affinity, taints/tolerations, topology spread, priority classes | Assignments 1-3 |
| assignment-5 | Pod Resources and QoS | Requests/limits, QoS classes, OOMKill, LimitRange, ResourceQuota | Assignments 1-3 |
| assignment-6 | Multi-Container Patterns | Sidecar, ambassador, adapter, native sidecars, shared process namespace | Assignments 1-2 |
| assignment-7 | Workload Controllers | ReplicaSets, Deployments (rollouts, rollbacks, strategies), DaemonSets | Assignments 1-5 |

## Scope Boundaries

This topic covers everything about running workloads as pods and managing them with
controllers. The following related areas are handled by other topics:

- **Security contexts** (runAsUser, capabilities, seccomp): covered in `security-contexts/`
- **Services** (exposing pods via ClusterIP, NodePort, LoadBalancer): covered in `services/`
- **Storage** (PersistentVolumes, PersistentVolumeClaims, StorageClasses): covered in `storage/`
- **Network Policies** (controlling traffic to/from pods): covered in `network-policies/`
- **Autoscaling (HPA, VPA, in-place pod resize)**: covered in `autoscaling/` (planned; see `docs/remediation-plan.md` tasks P3.2, P3.6)
- **Jobs and CronJobs**: covered in `jobs-and-cronjobs/` (planned; see `docs/remediation-plan.md` tasks P3.1, P3.6)
- **StatefulSets**: covered in `statefulsets/` (planned; see `docs/remediation-plan.md` tasks P3.3, P3.6)
- **Helm and Kustomize** (managing pod/controller manifests at scale): covered in `helm/` and `kustomize/`

## Cluster Requirements

Assignments 1-3 use a single-node kind cluster. Assignment 4 introduces the multi-node
kind cluster (1 control-plane, 3 workers) which is required from that point forward
for scheduling, DaemonSet, and multi-node deployment exercises.

## Recommended Order

Work through assignments 1-7 in sequence. Each assignment builds on the prior ones
and explicitly declares what it assumes.
