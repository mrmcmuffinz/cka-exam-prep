# StatefulSets

**CKA Domain:** Workloads & Scheduling (15%)
**Competencies covered:** Understand application deployments (stateful workloads with stable identity), self-healing primitives for stateful workloads

---

## Rationale for Number of Assignments

StatefulSets provide three guarantees that Deployments do not: stable pod network identity (predictable DNS names via a headless Service), ordered pod creation and deletion (pod-0 starts first, pod-N-1 deletes first), and stable persistent storage (a unique PersistentVolumeClaim per pod via `volumeClaimTemplates`). The CKA-relevant surface covers the StatefulSet spec (`serviceName`, `podManagementPolicy`, `updateStrategy`, `volumeClaimTemplates`), the headless Service requirement, ordered lifecycle behavior, scaling mechanics, RollingUpdate vs OnDelete update strategies, partition-based staged rollouts, and diagnostic workflow for stuck pods. The material totals roughly 7 focused subtopics, which fits a single well-scoped assignment without padding. Splitting would separate the headless Service from the StatefulSet spec it pairs with, which would harm the teaching flow.

---

## Assignment Summary

| Assignment | Description | Prerequisites |
|---|---|---|
| assignment-1 | StatefulSets | StatefulSet spec structure, headless Service (ClusterIP: None) requirement, stable pod network identity (pod-0, pod-1, ... DNS), ordered pod creation and deletion, `podManagementPolicy` (OrderedReady vs Parallel), `volumeClaimTemplates` and per-pod storage, `updateStrategy` (RollingUpdate with partition, OnDelete), scaling StatefulSets, diagnostic workflow for stuck or failed StatefulSets | pods/assignment-7 (Workload Controllers), services/assignment-1 (headless Services), storage/assignment-2 (PVCs) |

## Scope Boundaries

This topic covers the StatefulSet controller. The following related areas are handled by other topics.

- **Stateless workloads** (ReplicaSets, Deployments, DaemonSets): covered in `pods/assignment-7`
- **Batch workloads** (Jobs, CronJobs): covered in `jobs-and-cronjobs/`
- **Services** (the headless Service used by a StatefulSet): covered in `services/assignment-1`
- **Persistent storage** (PV, PVC, StorageClass mechanics that `volumeClaimTemplates` uses): covered in `storage/assignment-1` through `storage/assignment-3`
- **DNS resolution** (how pod DNS names resolve to pod IPs): covered in `coredns/assignment-1`

## Cluster Requirements

Multi-node kind cluster so that StatefulSet pod distribution across workers and ordered lifecycle behavior are observable. kind's default `rancher.io/local-path` StorageClass satisfies `volumeClaimTemplates` without extra setup. See `docs/cluster-setup.md#multi-node-kind-cluster`.

## Recommended Order

Complete `pods/assignment-7` (Workload Controllers), `services/assignment-1` (for headless Services), and at least `storage/assignment-2` (for PVC fundamentals) before this topic. StatefulSets combine all three.

---

## Current Status

Topic scoped on 2026-04-18 as part of Phase 3 of `docs/remediation-plan.md`. Content generation is tracked under Phase 4 of the remediation plan. The `prompt.md` for assignment-1 lives in this directory alongside this README.
