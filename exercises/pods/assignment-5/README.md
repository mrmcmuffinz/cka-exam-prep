# Assignment 5: Pod Resources and QoS

This is the fifth assignment in a series of pod-focused exercises for CKA exam preparation. It covers how pods declare their CPU and memory needs, how Kubernetes enforces those declarations at runtime, and how the three Quality of Service classes emerge from the interaction between requests and limits.

## Files

| File | Description |
|------|-------------|
| `pod-resources-qos-tutorial.md` | Complete step-by-step tutorial covering resource requests, limits, QoS classes, OOMKill, CPU throttling, LimitRange, and ResourceQuota. Work through this first. |
| `pod-resources-qos-homework.md` | 15 progressive exercises organized across five difficulty levels. Attempt these after completing the tutorial. |
| `pod-resources-qos-homework-answers.md` | Full solutions and explanations for all 15 exercises, plus common mistakes and a verification cheat sheet. |

## Recommended Workflow

1. **Tutorial first.** Work through `pod-resources-qos-tutorial.md` end-to-end. It builds from a bare pod with no resource declarations all the way through LimitRange and ResourceQuota admission controls.
2. **Exercises second.** Attempt all 15 exercises in `pod-resources-qos-homework.md` without looking at answers. Use the tutorial's reference sections if you get stuck.
3. **Answers last.** Check your work against `pod-resources-qos-homework-answers.md`. Pay special attention to the debugging exercises: the diagnostic workflow matters as much as the fix.

## Difficulty Progression

| Level | Exercises | Description |
|-------|-----------|-------------|
| Level 1 | 1.1, 1.2, 1.3 | Single-concept tasks: one pod, one resource configuration, basic verification |
| Level 2 | 2.1, 2.2, 2.3 | Multi-concept tasks: combining CPU, memory, ephemeral-storage, multi-container QoS reasoning |
| Level 3 | 3.1, 3.2, 3.3 | Debugging broken configurations: diagnose from Events, pod status, and admission errors |
| Level 4 | 4.1, 4.2, 4.3 | Complex real-world build tasks: namespace policies, SLO-driven sizing, multi-container resource profiles |
| Level 5 | 5.1, 5.2, 5.3 | Advanced debugging with multiple interacting issues, or comprehensive multi-tenant namespace configuration |

## Prerequisites

- **Kubernetes knowledge:** CKA course sections S1 through S6 (Core Concepts, Scheduling, Logging & Monitoring, Application Lifecycle Management, Cluster Maintenance, Security through KubeConfig). Assignments 1 through 4 (Pod Fundamentals, Configuration Injection, Health & Observability, Scheduling) are assumed knowledge.
- **Cluster:** A kind cluster, ideally the multi-node cluster (1 control-plane, 3 workers) from Assignment 4. If you don't have it, refer to Assignment 4's setup instructions. Most exercises work fine on a single-node cluster; the few that benefit from multiple nodes are noted.
- **Container runtime:** nerdctl with rootless containerd. kind uses `KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster`.
- **kubectl:** Installed and configured to talk to your kind cluster.

## Know Your Cluster

Before starting, check your cluster's allocatable resources. kind worker nodes inherit from the host, so they often report generous capacity (8+ CPUs, 16+ GB memory) that wouldn't exist on a real production node.

```bash
# Quick overview of all nodes
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
CPU:.status.allocatable.cpu,\
MEM:.status.allocatable.memory

# Detailed view of a single worker node
kubectl describe node kind-worker | grep -A 6 "Allocatable:"
```

Note the allocatable CPU and memory values. Several exercises create pods with deliberately large requests to trigger scheduling failures, and the required values depend on your actual node capacity.

## Estimated Time

- **Tutorial:** 60 to 90 minutes
- **Level 1 exercises:** 15 to 20 minutes
- **Level 2 exercises:** 20 to 30 minutes
- **Level 3 exercises:** 30 to 45 minutes
- **Level 4 exercises:** 45 to 60 minutes
- **Level 5 exercises:** 45 to 60 minutes
- **Total:** 3 to 5 hours

## Assignment Series

This is Assignment 5 in a planned series of pod-focused assignments:

1. Pod Fundamentals (pod spec, commands/args, restart policy, labels/annotations)
2. Pod Configuration Injection (ConfigMaps, Secrets, environment variables)
3. Pod Health and Observability (probes, lifecycle hooks, termination)
4. Pod Scheduling (nodeSelector, affinity, taints, tolerations, priority classes)
5. **Pod Resources and QoS** (this assignment)
6. Advanced Multi-Container Patterns (sidecars, init containers, shared volumes)
7. Workload Controllers (ReplicaSets, Deployments, DaemonSets)

## Important Notes

- Some exercises deliberately trigger OOMKills and resource exhaustion. This is expected behavior and will not harm your cluster or host system. The stress workloads are time-bounded and clean up after themselves.
- Each exercise uses its own namespace (ex-1-1, ex-1-2, etc.) to prevent LimitRange and ResourceQuota interference between exercises.
- The tutorial uses its own namespace (tutorial-pod-resources) with separate resource names.
- All stress commands include timeouts so they terminate on their own. You do not need to manually kill any workloads.
