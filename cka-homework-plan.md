# CKA Homework Assignment Plan

**Status:** Active
**Last updated:** 2026-04-17

---

## Overview

This document maps every CKA exam competency to a homework assignment, tracks which
assignments have been generated, and sequences the remaining work. It serves as the
run sheet for generating new assignments using the two skills in `skills/`.

The CKA exam tests five domains. Each domain has specific competencies published in
the official CNCF curriculum. Every competency must be covered by at least one
assignment. Some competencies are covered by multiple assignments (for example,
pod scheduling appears in both the pod series and the troubleshooting series).

---

## CKA Exam Domains and Weights

| Domain | Weight | Primary Exercise Directories |
|---|---|---|
| Cluster Architecture, Installation & Configuration | 25% | rbac, cluster-lifecycle, helm, kustomize, crds-and-operators |
| Workloads & Scheduling | 15% | pods (assignments 1-7) |
| Services & Networking | 20% | services, ingress-and-gateway-api, coredns, network-policies |
| Storage | 10% | storage |
| Troubleshooting | 30% | troubleshooting (assignments 1-4), plus debugging exercises across all topics |

---

## Competency Coverage Matrix

Each row is an official CKA competency. The "Assignments" column lists every assignment
that covers it. A competency is considered covered when at least one assignment includes
exercises that directly test it.

### Domain 1: Cluster Architecture, Installation & Configuration (25%)

| Competency | Assignments | Status |
|---|---|---|
| Manage role-based access control (RBAC) | rbac, pods/assignment-1 (service account basics) | Done (rbac), Partial (pods) |
| Prepare underlying infrastructure for installing a Kubernetes cluster | cluster-lifecycle/assignment-1 | Planned |
| Create and manage Kubernetes clusters using kubeadm | cluster-lifecycle/assignment-1 | Planned |
| Manage the lifecycle of Kubernetes clusters | cluster-lifecycle/assignment-1 | Planned |
| Implement and configure a highly available control plane | cluster-lifecycle/assignment-1 | Planned |
| Use Helm to install cluster components | helm/assignment-1 | Planned |
| Use Kustomize to install cluster components | kustomize/assignment-1 | Planned |
| Understand extension interfaces (CNI, CSI, CRI) | cluster-lifecycle/assignment-1, storage/assignment-1 | Planned |
| Understand CRDs and install and configure operators | crds-and-operators/assignment-1 | Planned |

### Domain 2: Workloads & Scheduling (15%)

| Competency | Assignments | Status |
|---|---|---|
| Understand application deployments and perform rolling updates and rollbacks | pods/assignment-7 | Done |
| Use ConfigMaps and Secrets to configure applications | pods/assignment-2 | Done |
| Configure workload autoscaling | pods/assignment-5 | Done |
| Understand primitives for robust, self-healing application deployments | pods/assignment-3, pods/assignment-7 | Done |
| Configure Pod admission and scheduling (limits, node affinity, etc.) | pods/assignment-4, pods/assignment-5 | Done |

### Domain 3: Services & Networking (20%)

| Competency | Assignments | Status |
|---|---|---|
| Understand connectivity between Pods | services/assignment-1, network-policies/assignment-1 | Planned |
| Define and enforce Network Policies | network-policies/assignment-1 | Planned |
| Use ClusterIP, NodePort, LoadBalancer service types and endpoints | services/assignment-1 | Planned |
| Use the Gateway API to manage Ingress traffic | ingress-and-gateway-api/assignment-1 | Planned |
| Know how to use Ingress controllers and Ingress resources | ingress-and-gateway-api/assignment-1 | Planned |
| Understand and use CoreDNS | coredns/assignment-1 | Planned |

### Domain 4: Storage (10%)

| Competency | Assignments | Status |
|---|---|---|
| Implement storage classes and dynamic volume provisioning | storage/assignment-1 | Planned |
| Configure volume types, access modes, and reclaim policies | storage/assignment-1 | Planned |
| Manage persistent volumes and persistent volume claims | storage/assignment-1 | Planned |

### Domain 5: Troubleshooting (30%)

| Competency | Assignments | Status |
|---|---|---|
| Troubleshoot clusters and nodes | troubleshooting/assignment-2, troubleshooting/assignment-3 | Planned |
| Troubleshoot cluster components | troubleshooting/assignment-2 | Planned |
| Monitor cluster and application resource usage | troubleshooting/assignment-1 | Planned |
| Manage and evaluate container output streams | troubleshooting/assignment-1 | Planned |
| Troubleshoot services and networking | troubleshooting/assignment-4 | Planned |

---

## Assignment Directory

### Completed

| Directory | Assignment | Topic | CKA Domain |
|---|---|---|---|
| exercises/pods/assignment-1 | Pod Fundamentals | Spec construction, single/multi-container, commands/args, env vars, restart policy, init containers | Workloads & Scheduling |
| exercises/pods/assignment-2 | Pod Configuration Injection | ConfigMaps, Secrets, projected volumes, downward API | Workloads & Scheduling |
| exercises/pods/assignment-3 | Pod Health and Observability | Probes, lifecycle hooks, termination, diagnostic workflow | Workloads & Scheduling |
| exercises/pods/assignment-4 | Pod Scheduling and Placement | nodeSelector, affinity, taints/tolerations, topology spread, priority classes | Workloads & Scheduling |
| exercises/pods/assignment-5 | Pod Resources and QoS | Requests, limits, QoS classes, OOMKill, LimitRange, ResourceQuota | Workloads & Scheduling |
| exercises/pods/assignment-6 | Multi-Container Patterns | Sidecar, ambassador, adapter, native sidecars, shared process namespace | Workloads & Scheduling |
| exercises/pods/assignment-7 | Workload Controllers | ReplicaSets, Deployments (rollouts/rollbacks), DaemonSets | Workloads & Scheduling |
| exercises/rbac | RBAC (namespace-scoped) | Roles, RoleBindings, service accounts, namespace-scoped permissions | Cluster Architecture |

### Planned

| Directory | Assignment | Topic | CKA Domain | Unlocked After |
|---|---|---|---|---|
| exercises/cluster-lifecycle/assignment-1 | Cluster Lifecycle | kubeadm install/upgrade, etcd backup/restore, HA control plane, extension interfaces | Cluster Architecture | Day 6 (S6) |
| exercises/helm/assignment-1 | Helm | Install, configure, upgrade, rollback charts, chart repositories, values files | Cluster Architecture | Day 11 (S12) |
| exercises/kustomize/assignment-1 | Kustomize | Kustomization files, overlays, patches, transformers, components | Cluster Architecture | Day 12 (S13) |
| exercises/crds-and-operators/assignment-1 | CRDs and Operators | Custom resource definitions, custom controllers, operator framework | Cluster Architecture | Day 8 (S7) |
| exercises/services/assignment-1 | Services | ClusterIP, NodePort, LoadBalancer, endpoints, service discovery, selectors | Services & Networking | Day 9 (S9) |
| exercises/ingress-and-gateway-api/assignment-1 | Ingress and Gateway API | Ingress controllers, Ingress resources, annotations, Gateway API resources | Services & Networking | Day 10 (S9) |
| exercises/coredns/assignment-1 | CoreDNS and Cluster DNS | DNS resolution for services and pods, CoreDNS configuration, DNS debugging | Services & Networking | Day 10 (S9) |
| exercises/network-policies/assignment-1 | Network Policies | Ingress/egress rules, namespace isolation, default deny, CIDR selectors | Services & Networking | Day 10 (S9) |
| exercises/storage/assignment-1 | Persistent Storage | Volumes, PV, PVC, StorageClass, dynamic provisioning, access modes, reclaim policies | Storage | Day 8 (S8) |
| exercises/troubleshooting/assignment-1 | Application Troubleshooting | Pod failures, CrashLoopBackOff, image pull errors, resource exhaustion, log analysis | Troubleshooting | Day 13 (S14) |
| exercises/troubleshooting/assignment-2 | Control Plane Troubleshooting | API server, scheduler, controller manager, etcd, static pod manifests, certificates | Troubleshooting | Day 13 (S14) |
| exercises/troubleshooting/assignment-3 | Node and Kubelet Troubleshooting | Node NotReady, kubelet issues, container runtime problems, node conditions | Troubleshooting | Day 13 (S14) |
| exercises/troubleshooting/assignment-4 | Network Troubleshooting | Service resolution failures, DNS issues, network policy conflicts, connectivity | Troubleshooting | Day 13 (S14) |

---

## Generation Sequence

This is the recommended order for generating assignments, aligned with the daily
study plan. The "Unlocked After" column indicates when the relevant course material
has been covered. You do not need to generate the assignment on that exact day, but
you should not generate it before the course material has been studied.

| Order | Assignment | Unlocked After | Dependencies |
|---|---|---|---|
| 1 | cluster-lifecycle | Day 6 (S6 complete) | None (kind cluster sufficient for etcd exercises) |
| 2 | crds-and-operators | Day 8 (S7 complete) | None |
| 3 | storage | Day 8 (S8 complete) | None |
| 4 | services | Day 9 (S9 partial) | pods/assignment-7 (needs Deployments for service targets) |
| 5 | coredns | Day 10 (S9 complete) | services (DNS resolves service names) |
| 6 | network-policies | Day 10 (S9 complete) | services (policies filter traffic to/from services) |
| 7 | ingress-and-gateway-api | Day 10 (S9 complete) | services (Ingress routes to backend services) |
| 8 | helm | Day 11 (S12 complete) | None |
| 9 | kustomize | Day 12 (S13 complete) | None |
| 10 | troubleshooting/assignment-1 | Day 13 (S14 complete) | All previous assignments (cross-domain scenarios) |
| 11 | troubleshooting/assignment-2 | Day 13 (S14 complete) | cluster-lifecycle (control plane concepts) |
| 12 | troubleshooting/assignment-3 | Day 13 (S14 complete) | cluster-lifecycle (node management concepts) |
| 13 | troubleshooting/assignment-4 | Day 13 (S14 complete) | services, coredns, network-policies |

---

## Prompt Generation Workflow

The two skills in `skills/` support the following workflow in Claude Code:

**Step 1: Build the prompt.** Use the `cka-prompt-builder` skill. Provide the topic
name and optionally the specific subtopics you want covered. The skill consults the
CKA curriculum, the course section map, and the assignment registry to produce a
scoped prompt with the right competencies, resource gates, and cross-references.

Example invocation:
```
Generate a homework prompt for the Network Policies topic covering ingress/egress
rules, namespace isolation, default deny patterns, and CIDR-based selectors.
```

The skill produces a `prompt.md` file in the target assignment directory.

**Step 2: Generate the assignment.** Use the `k8s-homework-generator` skill. Point it
at the prompt that was just generated. The skill reads the base template for structural
conventions and produces the four output files (README.md, tutorial, homework, answers)
in the same directory.

Example invocation:
```
Generate the homework assignment from exercises/network-policies/assignment-1/prompt.md
```

**Step 3: Update the registry.** After generation, update `assignment-registry.md` in the
prompt builder's references to reflect the new assignment's scope and status. Update the
status column in the coverage matrix above from "Planned" to "Done."

---

## Design Decisions

**Progressive resource gating.** Assignments generated early in the course (through Storage,
generation order 1-3) explicitly list which Kubernetes resources are in scope. This prevents
exercises from referencing objects the learner has not yet encountered. Assignments generated
after Networking (generation order 4+) have access to the full set of CKA resources, since by
that point in the course all major resource types have been introduced.

**Troubleshooting as capstone.** The four troubleshooting assignments are generated last
regardless of when S14 is completed in the course. Troubleshooting exercises are inherently
cross-domain (a single scenario might involve a broken Service, a misconfigured PVC, and a
pod with wrong resource limits). Generating them after all other assignments ensures the
prompt builder can reference the full scope of what the learner has practiced.

**Single-assignment vs. multi-assignment topics.** Most topics outside the pod series are
expected to be single assignments. The `assignment-1/` subdirectory convention is used
uniformly so the structure can accommodate additional assignments if a topic proves too
large for one set of 15 exercises. The prompt builder will recommend splitting when a
topic's scope exceeds what fits naturally into the five-level exercise structure.

**Debugging exercises are distributed, not centralized.** Every assignment includes
debugging exercises at Levels 3 and 5. The troubleshooting series adds cross-domain
debugging scenarios that combine multiple failure modes. This means troubleshooting
practice is woven throughout the entire exercise corpus, not isolated in one section.
