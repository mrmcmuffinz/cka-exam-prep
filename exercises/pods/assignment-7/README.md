# Assignment 7: Workload Controllers

**Series:** CKA Pod-Focused Assignments (7 of 7, final entry)
**Topic:** ReplicaSets, Deployments, and DaemonSets
**CKA Sections Covered:** S2 (Core Concepts), S3 (Scheduling, partial), S5 (Application Lifecycle Management)

---

## What This Assignment Covers

This is the capstone of the pod-focused assignment series. Assignments 1 through 6 built up the skills for constructing individual pods: spec fundamentals, configuration injection, health and observability, scheduling, resource management, and multi-container patterns. This assignment transitions from "the pod itself" to "the things that manage pods," covering the three core workload controllers every CKA candidate must know cold.

**ReplicaSets** are the underlying primitive that ensures a specified number of pod replicas are running at any given time. **Deployments** are the workhorse controller for stateless applications, built on top of ReplicaSets, adding rolling updates, rollbacks, and revision history. **DaemonSets** are the specialized controller that ensures exactly one pod runs on every node (or a selected subset of nodes), used for cluster-wide agents like log collectors and network plugins.

Everything from Assignments 1 through 6 applies here directly, because every controller's template is a full pod spec.

---

## Files

| File | Description |
|------|-------------|
| `workload-controllers-tutorial.md` | Complete tutorial progressing through ReplicaSets, Deployments, and DaemonSets with hands-on examples, reference tables, and diagnostic workflows |
| `workload-controllers-homework.md` | 15 progressive exercises across 5 difficulty levels (basic, multi-concept, debugging, real-world, advanced) |
| `workload-controllers-homework-answers.md` | Full solutions for all 15 exercises with explanations, common mistakes, and verification cheat sheets |

---

## Recommended Workflow

1. **Read the tutorial first.** Work through `workload-controllers-tutorial.md` end to end in your kind cluster. This builds the conceptual foundation and gives you hands-on experience with every controller type, rollout workflow, and diagnostic technique before the exercises begin.

2. **Do the homework exercises.** Work through `workload-controllers-homework.md` in order. The five levels are progressive: Level 1 exercises take a few minutes each, Level 5 exercises may take 20 to 30 minutes. Attempt each exercise fully before checking answers.

3. **Check your work against the answers.** Use `workload-controllers-homework-answers.md` to verify your solutions. For debugging exercises, compare your diagnostic process (not just the fix) against the walkthrough.

---

## Difficulty Progression

| Level | Exercises | Focus | Estimated Time |
|-------|-----------|-------|----------------|
| Level 1 | 1.1, 1.2, 1.3 | Single controller, single action | 5-10 min each |
| Level 2 | 2.1, 2.2, 2.3 | Multi-concept controller tasks | 10-15 min each |
| Level 3 | 3.1, 3.2, 3.3 | Debugging broken configurations | 10-20 min each |
| Level 4 | 4.1, 4.2, 4.3 | Production-realistic build tasks | 15-25 min each |
| Level 5 | 5.1, 5.2, 5.3 | Advanced debugging and comprehensive scenarios | 20-30 min each |

**Total estimated time:** 3 to 5 hours

---

## Prerequisites

**Cluster:** Multi-node kind cluster with 1 control-plane node and 3 worker nodes, created using `nerdctl` as the container runtime. This is the same cluster from Assignment 4 (Scheduling). If you no longer have it running, recreate it:

```bash
cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
  - role: worker
EOF

KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster --config kind-config.yaml
```

Verify your cluster:

```bash
kubectl get nodes
# Expected: 1 control-plane + 3 worker nodes, all Ready
```

**CKA Course Sections Completed:** S1 through S6 (Introduction, Core Concepts, Scheduling, Logging and Monitoring, Application Lifecycle Management, Cluster Maintenance, Security through KubeConfig).

**Prior Assignments Completed:** Assignments 1 through 6 (Pod Fundamentals, Configuration Injection, Health and Observability, Scheduling, Resources and QoS, Multi-Container Patterns).

**Tools:** `kubectl` configured for the kind cluster, `nerdctl` for rootless container operations.

---

## Important Notes

**Node-state cleanup matters.** Several exercises (especially DaemonSet exercises) apply labels and taints to cluster nodes. Each exercise includes cleanup commands for any node-level state it modifies. Always run the cleanup before moving to the next exercise to avoid leaking state that causes confusing behavior in later exercises.

**Tutorial and exercises use separate namespaces.** The tutorial uses `tutorial-workload-controllers`. Each exercise uses its own namespace (`ex-1-1`, `ex-1-2`, etc.). There should be no conflicts if you work through them in order, but always verify with `kubectl get ns` if something seems off.

**This is the final pod-focused assignment.** The natural next topics after mastering workload controllers are StatefulSets (for stateful workloads with stable identity), Jobs and CronJobs (for batch and scheduled work), Services and Ingress (for networking and traffic routing), and storage (PersistentVolumes and PersistentVolumeClaims). These are separate assignment series that build on the foundation established here.
