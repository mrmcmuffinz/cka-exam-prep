# Jobs and CronJobs

**CKA Domain:** Workloads & Scheduling (15%)
**Competencies covered:** Understand primitives for robust, self-healing application deployments (batch workloads), ReplicaSets as the reconciliation mechanism (contrasted with Jobs)

---

## Rationale for Number of Assignments

Jobs run a set of pods to completion and then stop. CronJobs wrap Jobs with a schedule and concurrency policy for repeating batch work. The CKA-relevant surface covers the Job spec (completions, parallelism, backoffLimit, activeDeadlineSeconds), completion modes (Indexed vs NonIndexed), Job restart policies (OnFailure vs Never and how they interact with backoffLimit), CronJob scheduling syntax, concurrency policy (Allow, Forbid, Replace), startingDeadlineSeconds, history limits, TTL for finished Jobs (ttlSecondsAfterFinished), and diagnostic workflow for failed batch runs. The material totals roughly 8 focused subtopics, which fits a single well-scoped assignment at the 15-exercise depth without padding and without leaving anything meaningful uncovered.

---

## Assignment Summary

| Assignment | Description | Prerequisites |
|---|---|---|
| assignment-1 | Jobs and CronJobs | Job spec (completions, parallelism, backoffLimit, activeDeadlineSeconds), Indexed vs NonIndexed completions, Job restart policies, CronJob spec (schedule, concurrencyPolicy, startingDeadlineSeconds), history limits, TTL for finished Jobs, diagnostic workflow for failed batch workloads | pods/assignment-7 (Workload Controllers) |

## Scope Boundaries

This topic covers finite-duration workloads. The following related areas are handled by other topics.

- **Long-running workloads** (ReplicaSets, Deployments, DaemonSets): covered in `pods/assignment-7`
- **Stateful workloads with ordered identity**: covered in `statefulsets/`
- **Autoscaling** (HPA for long-running workloads, not Jobs): covered in `autoscaling/`
- **Scheduling constraints on pods** (node affinity, taints): covered in `pods/assignment-4`
- **Resource requests and limits**: covered in `pods/assignment-5`

## Cluster Requirements

Single-node kind cluster is sufficient for all Job and CronJob exercises. CronJobs rely on the controller-manager's clock, which works correctly in kind. See `docs/cluster-setup.md#single-node-kind-cluster`.

## Recommended Order

Complete `pods/assignment-7` (Workload Controllers) before this topic. Jobs and CronJobs are controllers that produce pods, so the same mental model from ReplicaSets applies. This topic can be generated and worked any time after the S5 course section (Application Lifecycle Management) is complete.

---

## Current Status

Topic scoped on 2026-04-18 as part of Phase 3 of `docs/remediation-plan.md`. Content generation (tutorial, homework, answers) is tracked in the remediation plan under Phase 4. The `prompt.md` for assignment-1 lives in this directory alongside this README.
