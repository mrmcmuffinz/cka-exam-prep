# Assignment 4: Pod Scheduling and Placement

**Series:** CKA Pod Fundamentals Homework
**Position:** Assignment 4 of a planned series
**Prerequisites:** CKA course sections S1-S6, Assignments 1-3 completed
**Estimated time:** 6-8 hours (tutorial: 2-3 hours, exercises: 4-5 hours)

---

## What This Assignment Covers

This assignment teaches how Kubernetes decides which node a pod runs on, and how pod authors and cluster operators influence that decision. You will learn the full range of scheduling mechanisms (from simple nodeSelector through topology spread constraints and priority classes), build practical muscle memory for configuring them under time pressure, and develop the diagnostic skill of reading FailedScheduling events to understand why a pod is stuck in Pending.

Pod construction fundamentals (Assignment 1), configuration injection (Assignment 2), and health/observability (Assignment 3) are assumed knowledge. This assignment uses simple busybox sleep pods because the point is where the pod runs, not what it does.

## Files

| File | Contents |
|------|----------|
| `README.md` | This file. Overview, cluster setup, and workflow guidance. |
| `pod-scheduling-tutorial.md` | Step-by-step tutorial covering every scheduling mechanism, with working examples. |
| `pod-scheduling-homework.md` | 15 progressive exercises across 5 difficulty levels. |
| `pod-scheduling-homework-answers.md` | Complete solutions, common mistakes, and verification cheat sheet. |

## Recommended Workflow

1. **Set up the multi-node kind cluster** using the instructions below.
2. **Work through the tutorial** end to end. It teaches each scheduling mechanism in order, with both success and failure cases. Type along rather than just reading.
3. **Attempt the exercises** in order, starting from Level 1. Use the tutorial as a reference. Follow the cleanup steps at the end of each exercise before moving on.
4. **Check your work** against the answer key only after you have attempted the exercise and verified it yourself.

## Difficulty Progression

| Level | Exercises | Focus |
|-------|-----------|-------|
| Level 1 (3 exercises) | Basic single-concept tasks | One mechanism, one pod, straightforward verification |
| Level 2 (3 exercises) | Multi-concept tasks | Combine 2-3 scheduling concepts on one pod |
| Level 3 (3 exercises) | Debugging broken configurations | Diagnose and fix scheduling failures from Events |
| Level 4 (3 exercises) | Complex real-world scenarios | Production-style placement patterns |
| Level 5 (3 exercises) | Advanced debugging and comprehensive builds | Multiple issues or full topology design |

## Cluster Setup (REQUIRED)

Pod scheduling cannot be meaningfully practiced on a single-node cluster. You need a kind cluster with multiple worker nodes. This setup uses rootless nerdctl as the container provider.

### Kind Config File

Save the following as `kind-scheduling-cluster.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
  - role: worker
```

### Create the Cluster

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster \
  --name scheduling-lab \
  --config kind-scheduling-cluster.yaml
```

### Verify the Cluster

```bash
kubectl get nodes
```

Expected output (node names may vary slightly, but you should see four nodes):

```
NAME                           STATUS   ROLES           AGE   VERSION
scheduling-lab-control-plane   Ready    control-plane   1m    v1.x.x
scheduling-lab-worker          Ready    <none>          1m    v1.x.x
scheduling-lab-worker2         Ready    <none>          1m    v1.x.x
scheduling-lab-worker3         Ready    <none>          1m    v1.x.x
```

**Important:** The tutorial and exercises reference nodes as `scheduling-lab-worker`, `scheduling-lab-worker2`, and `scheduling-lab-worker3`. If your kind cluster uses different names (check with `kubectl get nodes`), substitute accordingly.

### Teardown

When you are finished with all exercises:

```bash
kind delete cluster --name scheduling-lab
```

## Node Labels and Taints: Why Cleanup Matters

Many exercises add custom labels and taints to nodes. These persist across exercises and namespaces, so a label or taint applied in Exercise 1.1 will still be present in Exercise 2.1 unless you remove it. Every exercise includes explicit cleanup steps. Follow them before moving to the next exercise, even if the exercise went smoothly. If you skip cleanup and something behaves unexpectedly later, run the global cleanup commands at the top of the homework file to reset all nodes.

## Planned Assignment Series

This is Assignment 4 in a pod-focused series:

1. **Pod Fundamentals** (pod spec, commands/args, restart policy, image pull, labels/annotations)
2. **Pod Configuration Injection** (ConfigMaps, Secrets, environment variables, volume mounts)
3. **Pod Health and Observability** (probes, lifecycle hooks, termination, logging)
4. **Pod Scheduling and Placement** (this assignment)
5. **Pod Resources and QoS** (requests, limits, QoS classes, LimitRanges)
6. **Advanced Pod Patterns** (multi-container patterns, init containers, ephemeral containers)
7. **Controllers and Services** (ReplicaSets, Deployments, DaemonSets, Services)
