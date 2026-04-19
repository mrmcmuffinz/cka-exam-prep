# Assignment 6: Multi-Container Patterns

**Series:** CKA Pod-Focused Assignments (6 of 7)
**Prerequisites:** Assignments 1-5 (Pod Fundamentals, Configuration Injection, Health & Observability, Scheduling, Resources & QoS)
**Estimated Time:** 6-8 hours (tutorial + exercises)

---

## Overview

This is the final pod-focused assignment in the series. After this, the series moves on to workload controllers (Deployments, ReplicaSets, DaemonSets, Jobs, and beyond).

Assignment 1 introduced the mechanics of multi-container pods: writing multiple containers in a spec, selecting containers with `-c`, sharing storage via emptyDir, and basic init container behavior. This assignment builds on those mechanics to teach the *patterns*, the named design approaches that the Kubernetes community uses to structure multi-container pods for real production workloads. You will learn when to use each pattern, when *not* to use a multi-container pod at all, and how to debug the unique failure modes that arise when containers share a pod.

The patterns covered here (sidecar, ambassador, adapter, init container orchestration, and native sidecars) appear regularly on the CKA exam and are fundamental to understanding how production Kubernetes workloads are composed.

## Files

| File | Description |
|------|-------------|
| `multi-container-patterns-tutorial.md` | Complete tutorial covering all multi-container patterns with working examples. Start here. |
| `multi-container-patterns-homework.md` | 15 progressive exercises organized by difficulty (Levels 1-5). |
| `multi-container-patterns-homework-answers.md` | Complete solutions, debugging explanations, common mistakes, and reference material. |

## Recommended Workflow

1. **Read the tutorial end-to-end**, building each example in your cluster as you go. The tutorial teaches the patterns in a deliberate progression: init containers for prerequisites, classical sidecars, ambassadors, adapters, native sidecars, and shared process namespace.
2. **Work through the exercises in order** (Level 1 through Level 5). Each level assumes you can do everything from the levels before it.
3. **Consult the answers only after a genuine attempt.** For debugging exercises, spend at least 10-15 minutes investigating before checking the solution. The diagnostic process is the skill being tested.

## Difficulty Progression

| Level | Exercises | Focus |
|-------|-----------|-------|
| Level 1 (3 exercises) | Basic single-concept tasks | One pattern, minimum viable example, 2-3 verification checks |
| Level 2 (3 exercises) | Multi-concept tasks | Combined patterns, ordering dependencies, mount options, 4-6 checks |
| Level 3 (3 exercises) | Debugging broken configurations | Pre-built broken YAML, single issue per exercise, diagnose from kubectl output |
| Level 4 (3 exercises) | Complex real-world scenarios | Production-style compositions, 8+ verification checks per exercise |
| Level 5 (3 exercises) | Advanced debugging and comprehensive builds | Multiple issues or comprehensive build tasks, 10+ verification checks |

## Prerequisites

Before starting this assignment, you should have:

- A running **kind** cluster (created with `KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster`)
- Completed CKA course sections S1-S6 (Core Concepts through Security/KubeConfig)
- Completed Assignments 1-5 in this series
- Familiarity with multi-container pod mechanics from Assignment 1 (writing two containers in a spec, `kubectl exec -c`, `kubectl logs -c`, emptyDir basics, init container sequential execution)

## Native Sidecar Support

Several exercises in this assignment use **native sidecars** (init containers with `restartPolicy: Always`), a feature that reached stable status in Kubernetes 1.33. The feature is available in beta starting with Kubernetes 1.29.

Check your cluster's Kubernetes version:

```bash
kubectl version --short 2>/dev/null || kubectl version
```

If your kind cluster runs Kubernetes 1.29 or later, native sidecar exercises will work. If you are on an older version, you can still complete all non-native-sidecar exercises and read the native sidecar material conceptually. To get a newer kind cluster, update your `kind` binary and specify an image:

```bash
kind create cluster --image kindest/node:v1.33.0
```

Exercises that require native sidecar support are marked with **(Requires K8s 1.29+)** in their setup section.

## Cleanup

After completing all exercises:

```bash
# Remove all exercise namespaces
for ns in tutorial-multi-container \
  ex-1-1 ex-1-2 ex-1-3 \
  ex-2-1 ex-2-2 ex-2-3 \
  ex-3-1 ex-3-2 ex-3-3 \
  ex-4-1 ex-4-2 ex-4-3 \
  ex-5-1 ex-5-2 ex-5-3; do
  kubectl delete namespace "$ns" --ignore-not-found
done
```
