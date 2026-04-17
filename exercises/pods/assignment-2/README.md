# Assignment 2: Pod Configuration Injection

This is the second assignment in a planned series of pod-focused CKA practice assignments. It covers how external configuration data is delivered into pods through ConfigMaps, Secrets, projected volumes, and the downward API. Assignment 1 covered pod construction fundamentals (spec, containers, commands, restart policy, image handling), and those are treated as prerequisite knowledge here. The focus of this assignment is strictly configuration injection.

## Files in This Assignment

The assignment is split into four files so you can work through it in a natural order. The tutorial teaches the concepts with a single worked example, the homework drills those concepts through progressive exercises, the answer key walks through complete solutions, and this README ties everything together.

| File | Purpose |
|---|---|
| `README.md` | This overview, recommended workflow, and prerequisites |
| `pod-config-injection-tutorial.md` | Step-by-step tutorial building a realistic web app pod with config from multiple sources |
| `pod-config-injection-homework.md` | 15 progressive exercises across 5 difficulty levels |
| `pod-config-injection-homework-answers.md` | Complete solutions for all 15 exercises |

## Recommended Workflow

Work through the tutorial first. It builds a single realistic pod end to end, pulling in app config from a ConfigMap, database credentials from a Secret, pod metadata from the downward API, and combining them into a projected volume. The tutorial is the only place where every injection pattern is explained as it is introduced, so skipping it and jumping straight to exercises will make the debugging levels harder than they need to be.

Once the tutorial is complete, move to the homework exercises. Do them in order. Levels 1 and 2 build muscle memory for ConfigMap and Secret creation and the four main injection patterns. Level 3 is debugging, where the setup commands install broken configurations that you have to diagnose from pod status, events, and resource inspection. Level 4 is realistic production-style build tasks. Level 5 combines multiple issues per scenario and includes a comprehensive three-tier configuration exercise.

Only look at the answer key after you have genuinely attempted an exercise. For debugging exercises especially, the diagnostic process matters more than the fix, and the answer key walks through how to read the pod events and resource YAML to find the problem.

## Difficulty Level Progression

Level 1 exercises are single-concept tasks. You create one ConfigMap or Secret and wire it into a pod through one injection pattern, with two or three verification checks. Level 2 exercises combine two or three patterns in one pod, for instance pulling some environment variables from a Secret, some from a ConfigMap, and mounting a config file via subPath. Level 3 exercises give you broken YAML and ask you to identify and fix whatever is wrong, with failure modes ranging from a missing key reference to a Secret value that was not base64 encoded to a subPath pointing at a non-existent key. Level 4 exercises are realistic production scenarios (nginx config directory pattern, projected volume combining multiple sources with restrictive file permissions, multi-container pod with shared configuration). Level 5 exercises either stack multiple issues in one scenario or require a comprehensive three-tier configuration build.

## Prerequisites

You need a working Kubernetes cluster. A local `kind` cluster running under rootless nerdctl is the target environment for this assignment, which you create with `KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster`. KodeKloud browser-based labs also work fine. Any single-node or multi-node cluster where you have full administrative access is acceptable.

On the CKA course side, this assignment assumes you have completed sections S1 through S6 (Core Concepts, Scheduling, Logging and Monitoring, Application Lifecycle Management, Cluster Maintenance) and the first part of S7 (Security through KubeConfig). You do not need the remainder of S7, S8 (Storage), or S9 (Networking) to do this assignment. Storage in this assignment is limited to the volume types that ride inside the pod spec itself (configMap, secret, projected, downwardAPI, emptyDir), none of which require PersistentVolumes or StorageClasses.

From Assignment 1, you should already be comfortable with basic pod construction, commands and arguments, restart policies, image pull policies, and labels. The exercises in this assignment use single-container pods almost exclusively, and the few multi-container scenarios exist specifically to demonstrate shared-volume behavior, not to teach multi-container patterns in general (that comes in Assignment 6).

## Estimated Time Commitment

The tutorial takes about 60 to 90 minutes if you work through every command and inspect the results. The 15 homework exercises take roughly 4 to 6 hours in total, with most of the time on Levels 3 and 5 where diagnosis is the main work. Budget two sittings for the homework, one for Levels 1 and 2 and another for Levels 3 through 5. The answer key is long but primarily reference material once the exercises are done.

## This Assignment in the Pod Series

This is Assignment 2 of a planned pod series. The other assignments are scoped separately so that each one stays focused on a single conceptual area.

| Assignment | Topic | Status |
|---|---|---|
| 1 | Pod Fundamentals (spec, containers, commands, restart, images, labels) | Planned / prerequisite |
| **2** | **Pod Configuration Injection (this assignment)** | **Current** |
| 3 | Pod Health and Observability (probes, lifecycle hooks, logs) | Planned |
| 4 | Pod Scheduling (nodeSelector, affinity, taints, tolerations) | Planned |
| 5 | Pod Resources and QoS (requests, limits, QoS classes, LimitRange) | Planned |
| 6 | Advanced Multi-Container Patterns (sidecars, init containers, ambassador patterns) | Planned |
| 7 | Workload Controllers (ReplicaSets, Deployments, DaemonSets, rollouts) | Planned |

Topics that touch pods but belong to other parts of the CKA study sequence (RBAC for ConfigMap and Secret access, etcd encryption for Secrets at rest, external secret management tools like Vault and External Secrets Operator) are deliberately excluded from this series and are covered either in the Security section work or not at all within the scope of CKA prep.

## A Note on Secrets Before You Start

Kubernetes Secrets are base64-encoded, not encrypted. Anyone with read access to a Secret object can trivially decode it. The actual security controls for Secrets are RBAC (restricting which subjects can read Secret objects) and etcd encryption at rest (encrypting the Secret values in the backing store). Both of those are out of scope for this assignment but are covered in the Security section later in the CKA course. Treat Secrets in this assignment as an interface for carrying sensitive-ish data through the pod spec, not as a security primitive on their own.
