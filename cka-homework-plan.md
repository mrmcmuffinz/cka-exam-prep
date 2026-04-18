# CKA Homework Assignment Plan

**Status:** Active
**Last updated:** 2026-04-18

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
| Cluster Architecture, Installation & Configuration | 25% | cluster-lifecycle, tls-and-certificates, rbac, crds-and-operators, helm, kustomize |
| Workloads & Scheduling | 15% | pods (assignments 1-7), security-contexts |
| Services & Networking | 20% | services, coredns, network-policies, ingress-and-gateway-api |
| Storage | 10% | storage |
| Troubleshooting | 30% | troubleshooting (assignments 1-4), plus debugging exercises across all topics |

---

## Assignment Status Summary

**Total assignments:** 38
- **Completed:** 8 (pods 1-7, rbac/assignment-1)
- **Planned:** 30 (all remaining topics with 3+ assignments each)

**Assignment distribution:**
- **3-assignment topics:** 11 topics (cluster-lifecycle, tls-and-certificates, security-contexts, crds-and-operators, storage, services, coredns, network-policies, ingress-and-gateway-api, helm, kustomize)
- **4-assignment topic:** 1 topic (troubleshooting)
- **7-assignment series:** 1 topic (pods, completed)
- **2-assignment series:** 1 topic (rbac, 1 completed + 1 planned)

---

## Generation Sequence

This is the recommended order for generating assignments, aligned with the daily
study plan. The "Unlocked After" column indicates when the relevant course material
has been covered. You do not need to generate the assignment on that exact day, but
you should not generate it before the course material has been studied.

**Note:** Generation orders 1-38 represent the complete sequence from current state (8 completed) through all 30 remaining assignments.

| Order | Assignment | Unlocked After | Dependencies |
|---|---|---|---|
| 1 | cluster-lifecycle/assignment-1 | Day 6 (S6 complete) | None (kind cluster sufficient for exercises) |
| 2 | cluster-lifecycle/assignment-2 | Day 6 (S6 complete) | cluster-lifecycle/assignment-1 |
| 3 | cluster-lifecycle/assignment-3 | Day 6 (S6 complete) | cluster-lifecycle/assignment-2 (etcd builds on maintenance workflows) |
| 4 | tls-and-certificates/assignment-1 | Day 6 (S7 partial, through KubeConfig) | cluster-lifecycle/assignment-1 (cert concepts build on cluster PKI) |
| 5 | tls-and-certificates/assignment-2 | Day 6 (S7 partial) | tls-and-certificates/assignment-1 (Certificates API builds on manual cert creation) |
| 6 | tls-and-certificates/assignment-3 | Day 6 (S7 partial) | tls-and-certificates/assignment-2 (troubleshooting builds on both manual and API workflows) |
| 7 | rbac/assignment-2 | Day 7 (S7, RBAC section complete) | rbac/assignment-1 (namespace-scoped RBAC as prerequisite), tls-and-certificates/assignment-2 (cert-based auth) |
| 8 | security-contexts/assignment-1 | Day 7 (S7, security contexts section) | pods/assignment-1, pods/assignment-2 (pod spec and volume fundamentals) |
| 9 | security-contexts/assignment-2 | Day 7 (S7, security contexts section) | security-contexts/assignment-1 (capabilities build on user/group foundation) |
| 10 | security-contexts/assignment-3 | Day 7 (S7, security contexts section) | security-contexts/assignment-2 (filesystem constraints complete the security picture) |
| 11 | crds-and-operators/assignment-1 | Day 8 (S7 complete) | None (CRD authoring is foundational) |
| 12 | crds-and-operators/assignment-2 | Day 8 (S7 complete) | crds-and-operators/assignment-1 (custom resources build on CRD foundation) |
| 13 | crds-and-operators/assignment-3 | Day 8 (S7 complete) | crds-and-operators/assignment-2 (operators consume custom resources) |
| 14 | storage/assignment-1 | Day 8 (S8 complete) | None (PV creation is foundational) |
| 15 | storage/assignment-2 | Day 8 (S8 complete) | storage/assignment-1 (PVCs build on PV foundation) |
| 16 | storage/assignment-3 | Day 8 (S8 complete) | storage/assignment-2 (StorageClass automates provisioning) |
| 17 | services/assignment-1 | Day 9 (S9 partial) | pods/assignment-7 (needs Deployments for service targets) |
| 18 | services/assignment-2 | Day 9 (S9 partial) | services/assignment-1 (external types build on ClusterIP foundation) |
| 19 | services/assignment-3 | Day 9 (S9 partial) | services/assignment-2 (advanced patterns build on all service types) |
| 20 | coredns/assignment-1 | Day 10 (S9 complete) | services/assignment-1 (DNS resolves service names) |
| 21 | coredns/assignment-2 | Day 10 (S9 complete) | coredns/assignment-1 (configuration builds on DNS usage) |
| 22 | coredns/assignment-3 | Day 10 (S9 complete) | coredns/assignment-2 (troubleshooting applies configuration knowledge) |
| 23 | network-policies/assignment-1 | Day 10 (S9 complete) | services/assignment-1 (policies filter traffic to/from services) |
| 24 | network-policies/assignment-2 | Day 10 (S9 complete) | network-policies/assignment-1 (advanced selectors build on fundamentals) |
| 25 | network-policies/assignment-3 | Day 10 (S9 complete) | network-policies/assignment-2 (debugging applies advanced pattern knowledge) |
| 26 | ingress-and-gateway-api/assignment-1 | Day 10 (S9 complete) | services/assignment-1 (Ingress routes to backend services) |
| 27 | ingress-and-gateway-api/assignment-2 | Day 10 (S9 complete) | ingress-and-gateway-api/assignment-1 (TLS builds on basic Ingress) |
| 28 | ingress-and-gateway-api/assignment-3 | Day 10 (S9 complete) | ingress-and-gateway-api/assignment-2 (Gateway API is next-generation approach) |
| 29 | helm/assignment-1 | Day 11 (S12 complete) | None (chart consumption is foundational) |
| 30 | helm/assignment-2 | Day 11 (S12 complete) | helm/assignment-1 (lifecycle builds on installation) |
| 31 | helm/assignment-3 | Day 11 (S12 complete) | helm/assignment-2 (templates and debugging build on lifecycle mastery) |
| 32 | kustomize/assignment-1 | Day 12 (S13 complete) | None (basic kustomization is foundational) |
| 33 | kustomize/assignment-2 | Day 12 (S13 complete) | kustomize/assignment-1 (patches build on fundamentals) |
| 34 | kustomize/assignment-3 | Day 12 (S13 complete) | kustomize/assignment-2 (overlays use patches) |
| 35 | troubleshooting/assignment-1 | Day 13 (S14 complete) | All previous assignments (cross-domain application troubleshooting) |
| 36 | troubleshooting/assignment-2 | Day 13 (S14 complete) | cluster-lifecycle, tls-and-certificates (control plane concepts) |
| 37 | troubleshooting/assignment-3 | Day 13 (S14 complete) | cluster-lifecycle (node management concepts) |
| 38 | troubleshooting/assignment-4 | Day 13 (S14 complete) | services, coredns, network-policies (network troubleshooting combines all networking topics) |

---

## Design Decisions

**Progressive resource gating.** Assignments generated early in the course (through Storage,
generation order 1-16) explicitly list which Kubernetes resources are in scope. This prevents
exercises from referencing objects the learner has not yet encountered. Assignments generated
after Networking (generation order 17+) have access to the full set of CKA resources, since by
that point in the course all major resource types have been introduced.

**Troubleshooting as capstone.** The four troubleshooting assignments are generated last
regardless of when S14 is completed in the course. Troubleshooting exercises are inherently
cross-domain (a single scenario might involve a broken Service, a misconfigured PVC, and a
pod with wrong resource limits). Generating them after all other assignments ensures the
prompt builder can reference the full scope of what the learner has practiced.

**3+ focused assignments per topic.** Each topic (except the legacy pod series and RBAC) is
decomposed into 3+ focused assignments with 5-6 core subtopics each. This preference for depth
over breadth allows each assignment to explore its subtopics thoroughly rather than skimming
12-15 subtopics in a single dense assignment. The pod series (7 assignments) predates this
structure. Troubleshooting uses 4 assignments organized by failure layer (application, control
plane, node, network).

**Debugging exercises are distributed, not centralized.** Every assignment includes
debugging exercises at Levels 3 and 5. The troubleshooting series adds cross-domain
debugging scenarios that combine multiple failure modes. This means troubleshooting
practice is woven throughout the entire exercise corpus, not isolated in one section.

**Security is distributed across assignments, not a single series.** The CKA exam does
not have a standalone Security domain (it was consolidated into the other five domains
in the 2025 curriculum update). Security topics are distributed to the domains they
belong to: RBAC and TLS under Cluster Architecture, security contexts under Workloads
& Scheduling, network policies under Services & Networking, and certificate
troubleshooting under Troubleshooting. This matches how the exam tests them.
