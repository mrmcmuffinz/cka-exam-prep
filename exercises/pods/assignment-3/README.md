# Assignment 3: Pod Health and Observability

## Overview

This is the third assignment in a series of pod-focused exercises for CKA exam preparation. It covers how Kubernetes determines whether a pod is healthy, how pods signal their state through probes and lifecycle hooks, and how operators inspect pod behavior through logs and events.

## Files

| File | Description |
|------|-------------|
| `pod-health-observability-tutorial.md` | Complete step-by-step tutorial covering probes, lifecycle hooks, termination behavior, and diagnostic workflows. Work through this first. |
| `pod-health-observability-homework.md` | 15 progressive exercises organized by difficulty. No solutions included. |
| `pod-health-observability-homework-answers.md` | Complete solutions, explanations, and diagnostic reasoning for all 15 exercises. Consult only after attempting each exercise. |

## Recommended Workflow

1. **Tutorial first.** Read and follow `pod-health-observability-tutorial.md` end to end. It builds a realistic pod configuration, then deliberately breaks it three ways so you practice diagnosing each failure. Type every command yourself.
2. **Exercises second.** Work through `pod-health-observability-homework.md` in order. The difficulty ramps progressively, and earlier exercises build muscle memory you will need for later ones.
3. **Answers last.** Check `pod-health-observability-homework-answers.md` only after you have genuinely attempted an exercise. For debugging exercises, spend at least 5 minutes investigating before looking at the solution.

## Difficulty Progression

| Level | Exercises | Description |
|-------|-----------|-------------|
| Level 1 | 1.1, 1.2, 1.3 | Single-concept tasks: one probe or one lifecycle hook on a single pod |
| Level 2 | 2.1, 2.2, 2.3 | Multi-concept tasks: combine probes with tuning, or hooks with termination settings |
| Level 3 | 3.1, 3.2, 3.3 | Debugging: fix broken pod configurations using kubectl diagnostics |
| Level 4 | 4.1, 4.2, 4.3 | Complex builds: realistic production-style health configurations |
| Level 5 | 5.1, 5.2, 5.3 | Advanced debugging and comprehensive builds with multiple interacting concerns |

## Prerequisites

- A running `kind` cluster created with nerdctl (`KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster`)
- `kubectl` configured and working against the cluster
- CKA course sections S1 through S6 completed (Core Concepts, Scheduling, Logging and Monitoring, Application Lifecycle Management, Cluster Maintenance, Security through KubeConfig)
- Assignment 1 (Pod Fundamentals) and Assignment 2 (Pod Configuration Injection) completed

## Estimated Time

- **Tutorial:** 60 to 90 minutes
- **Exercises:** 3 to 5 hours total (varies by experience)
- **Total:** 4 to 6 hours across one or two sessions

## Timing Note

Many exercises in this assignment require observing behavior over time. Probes fire on configurable intervals (default every 10 seconds), restartCount increments only after a container actually crashes and restarts, and termination sequences take at least as long as the configured grace period. Expect to wait 30 to 120 seconds during verification steps. The exercises call out specific wait times where they matter.

## Pod Assignment Series

This assignment is part of a planned series covering pod-related CKA topics:

1. **Pod Fundamentals** (complete): Pod spec basics, commands/args, restart policy, image pull, labels, annotations, init containers
2. **Pod Configuration Injection** (complete): ConfigMaps, Secrets, environment variables, volume mounts
3. **Pod Health and Observability** (this assignment): Probes, lifecycle hooks, termination, logs, events, conditions
4. **Pod Scheduling**: Node selectors, node affinity, taints, tolerations, manual scheduling
5. **Pod Resources and QoS**: Resource requests/limits, QoS classes, LimitRanges
6. **Advanced Pod Patterns**: Multi-container design patterns, native sidecars, ephemeral containers
7. **Workload Controllers**: ReplicaSets, Deployments, DaemonSets, Jobs, CronJobs
