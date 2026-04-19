# CKA Exam Prep Learning Path

This document provides a structured order for working through the 45 assignments in this repository. The phases are sequenced to build skills progressively: deploy, configure, persist, expose, secure, operate, debug. Each phase maps to one or more CKA exam domains.

**Total assignments:** 45 across 19 topics
**Estimated total time:** 60-80 hours (tutorials + exercises + review)

---

## How to Use This Document

Work through the phases in order. Within each phase, complete assignments sequentially (assignment-1 before assignment-2, etc.). Each assignment has its own tutorial that teaches the topic from scratch, so you can start any phase once you have completed its prerequisites.

The checkboxes are for tracking your progress. Mark an assignment complete after you have worked through the tutorial, attempted all 15 exercises without looking at answers, and reviewed the answer key (including the Common Mistakes section).

---

## Phase 1: Pod Fundamentals

**CKA Domain:** Workloads & Scheduling (15%)
**Course alignment:** S2 Core Concepts, S3 Scheduling, S4 Logging & Monitoring, S5 Application Lifecycle
**Prerequisites:** A working kind cluster, basic kubectl familiarity
**Estimated time:** 14-18 hours

This phase establishes the foundation for everything else. Pods are the atomic unit of Kubernetes, and the concepts introduced here (container specs, volumes, probes, scheduling, resources, multi-container patterns) appear in every other topic.

| Order | Assignment | Focus |
|---|---|---|
| 1 | pods/assignment-1 | Pod spec fundamentals, containers, commands, env vars, restart policy |
| 2 | pods/assignment-2 | ConfigMaps, Secrets, volume mounts, projected volumes, downward API |
| 3 | pods/assignment-3 | Liveness, readiness, startup probes, lifecycle hooks, termination |
| 4 | pods/assignment-4 | Scheduling: nodeSelector, affinity, taints, tolerations, topology spread |
| 5 | pods/assignment-5 | Resources: requests, limits, QoS classes, LimitRange, ResourceQuota |
| 6 | pods/assignment-6 | Multi-container patterns: sidecar, ambassador, adapter, native sidecars |
| 7 | pods/assignment-7 | Controllers: ReplicaSets, Deployments, rollouts, rollbacks, DaemonSets |

**Progress:**
- [ ] pods/assignment-1
- [ ] pods/assignment-2
- [ ] pods/assignment-3
- [ ] pods/assignment-4 (requires multi-node cluster from this point)
- [ ] pods/assignment-5
- [ ] pods/assignment-6
- [ ] pods/assignment-7

---

## Phase 2: Workload Types

**CKA Domain:** Workloads & Scheduling (15%)
**Course alignment:** S5 Application Lifecycle (autoscaling), S2 Core Concepts (Jobs)
**Prerequisites:** Phase 1 complete
**Estimated time:** 5-6 hours

Beyond Deployments and DaemonSets (covered in Phase 1), Kubernetes has specialized controllers for batch workloads, stateful applications, and automatic scaling. This phase extends your deployment knowledge with these patterns.

| Order | Assignment | Focus |
|---|---|---|
| 8 | jobs-and-cronjobs/assignment-1 | Jobs, CronJobs, completions, parallelism, backoff limits |
| 9 | statefulsets/assignment-1 | StatefulSets, stable identity, ordered deployment, headless services |
| 10 | autoscaling/assignment-1 | HPA, VPA concepts, in-place pod resize |

**Progress:**
- [ ] jobs-and-cronjobs/assignment-1
- [ ] statefulsets/assignment-1
- [ ] autoscaling/assignment-1

---

## Phase 3: Configuration Management

**CKA Domain:** Cluster Architecture, Installation & Configuration (25%)
**Course alignment:** S12 Helm Basics, S13 Kustomize Basics
**Prerequisites:** Phase 1 complete
**Estimated time:** 8-10 hours

Helm and Kustomize are the two primary tools for managing Kubernetes manifests at scale. This phase covers chart installation and lifecycle management with Helm, and overlay-based customization with Kustomize. These are tools you will use immediately in practice.

| Order | Assignment | Focus |
|---|---|---|
| 11 | helm/assignment-1 | Chart repositories, helm install, values files |
| 12 | helm/assignment-2 | Upgrades, rollbacks, release history, helm diff |
| 13 | helm/assignment-3 | Chart templates, debugging, creating charts |
| 14 | kustomize/assignment-1 | kustomization.yaml, bases, common transformers |
| 15 | kustomize/assignment-2 | Patches (strategic merge, JSON), patch targets |
| 16 | kustomize/assignment-3 | Overlays, components, multi-environment workflows |

**Progress:**
- [ ] helm/assignment-1
- [ ] helm/assignment-2
- [ ] helm/assignment-3
- [ ] kustomize/assignment-1
- [ ] kustomize/assignment-2
- [ ] kustomize/assignment-3

---

## Phase 4: Storage

**CKA Domain:** Storage (10%)
**Course alignment:** S8 Storage
**Prerequisites:** Phase 1 complete
**Estimated time:** 5-6 hours

This phase covers persistent storage in Kubernetes: how volumes are provisioned (statically and dynamically), claimed by pods, and managed over their lifecycle. Understanding storage is essential before working with stateful networking patterns.

| Order | Assignment | Focus |
|---|---|---|
| 17 | storage/assignment-1 | PersistentVolumes, access modes, reclaim policies |
| 18 | storage/assignment-2 | PersistentVolumeClaims, binding, using PVCs in pods |
| 19 | storage/assignment-3 | StorageClasses, dynamic provisioning, volume expansion |

**Progress:**
- [ ] storage/assignment-1
- [ ] storage/assignment-2
- [ ] storage/assignment-3

---

## Phase 5: Networking

**CKA Domain:** Services & Networking (20%)
**Course alignment:** S9 Networking
**Prerequisites:** Phase 1 complete, Phase 4 recommended
**Estimated time:** 16-20 hours

This is the largest phase after pods. It covers the full networking stack: service discovery, DNS, traffic control with network policies, and external traffic routing with Ingress and Gateway API. The ingress series covers multiple controller implementations to prepare you for the exam's controller-agnostic approach.

| Order | Assignment | Focus |
|---|---|---|
| 20 | services/assignment-1 | ClusterIP, service discovery, endpoints |
| 21 | services/assignment-2 | NodePort, LoadBalancer, external traffic |
| 22 | services/assignment-3 | Headless services, ExternalName, service patterns |
| 23 | coredns/assignment-1 | DNS resolution, service and pod DNS records |
| 24 | coredns/assignment-2 | CoreDNS configuration, Corefile, plugins |
| 25 | coredns/assignment-3 | DNS debugging, resolution failures |
| 26 | network-policies/assignment-1 | Ingress rules, podSelector, namespaceSelector |
| 27 | network-policies/assignment-2 | Egress rules, ipBlock, default deny policies |
| 28 | network-policies/assignment-3 | Policy debugging, traffic flow analysis |
| 29 | ingress-and-gateway-api/assignment-1 | Ingress basics with Traefik controller |
| 30 | ingress-and-gateway-api/assignment-2 | TLS termination with HAProxy Ingress |
| 31 | ingress-and-gateway-api/assignment-3 | Gateway API with Envoy Gateway |
| 32 | ingress-and-gateway-api/assignment-4 | Gateway API with NGINX Gateway Fabric |
| 33 | ingress-and-gateway-api/assignment-5 | Ingress to Gateway API migration (Ingress2Gateway) |

**Progress:**
- [ ] services/assignment-1
- [ ] services/assignment-2
- [ ] services/assignment-3
- [ ] coredns/assignment-1
- [ ] coredns/assignment-2
- [ ] coredns/assignment-3
- [ ] network-policies/assignment-1
- [ ] network-policies/assignment-2
- [ ] network-policies/assignment-3
- [ ] ingress-and-gateway-api/assignment-1
- [ ] ingress-and-gateway-api/assignment-2
- [ ] ingress-and-gateway-api/assignment-3
- [ ] ingress-and-gateway-api/assignment-4
- [ ] ingress-and-gateway-api/assignment-5

---

## Phase 6: Access Control

**CKA Domain:** Cluster Architecture, Installation & Configuration (25%)
**Course alignment:** S7 Security (RBAC sections)
**Prerequisites:** Phase 1 complete
**Estimated time:** 4-5 hours

RBAC controls who can do what in the cluster. Now that you can deploy, configure, and expose applications, this phase teaches you how to secure access to those resources. It covers namespace-scoped permissions (Roles, RoleBindings) and cluster-scoped permissions (ClusterRoles, ClusterRoleBindings).

| Order | Assignment | Focus |
|---|---|---|
| 34 | rbac/assignment-1 | Roles, RoleBindings, service accounts, namespace-scoped access |
| 35 | rbac/assignment-2 | ClusterRoles, ClusterRoleBindings, aggregation, cluster-scoped resources |

**Progress:**
- [ ] rbac/assignment-1
- [ ] rbac/assignment-2

---

## Phase 7: Workload Security

**CKA Domain:** Workloads & Scheduling (15%)
**Course alignment:** S7 Security (security contexts, Pod Security sections)
**Prerequisites:** Phase 1 complete, Phase 6 recommended
**Estimated time:** 6-8 hours

This phase covers security settings applied to pods and containers: user/group identity, Linux capabilities, filesystem restrictions, and the Pod Security Standards enforcement mechanism.

| Order | Assignment | Focus |
|---|---|---|
| 36 | security-contexts/assignment-1 | runAsUser, runAsGroup, fsGroup, runAsNonRoot |
| 37 | security-contexts/assignment-2 | Capabilities (add/drop), allowPrivilegeEscalation |
| 38 | security-contexts/assignment-3 | readOnlyRootFilesystem, seccomp profiles |
| 39 | pod-security/assignment-1 | Pod Security Standards, Pod Security Admission, namespace labels |

**Progress:**
- [ ] security-contexts/assignment-1
- [ ] security-contexts/assignment-2
- [ ] security-contexts/assignment-3
- [ ] pod-security/assignment-1

---

## Phase 8: Extensibility

**CKA Domain:** Cluster Architecture, Installation & Configuration (25%)
**Course alignment:** S7 Security (CRDs section), S3 Scheduling (admission controllers)
**Prerequisites:** Phase 1 complete, Phase 3 recommended
**Estimated time:** 6-8 hours

Kubernetes is extensible through Custom Resource Definitions (CRDs), operators, and admission controllers. This phase covers how to define custom resources, install operators, and configure admission policies.

| Order | Assignment | Focus |
|---|---|---|
| 40 | crds-and-operators/assignment-1 | CRD authoring, custom resource creation |
| 41 | crds-and-operators/assignment-2 | Working with custom resources, validation, status |
| 42 | crds-and-operators/assignment-3 | Operator pattern, installing and using operators |
| 43 | admission-controllers/assignment-1 | Built-in admission controllers, ValidatingAdmissionPolicy |

**Progress:**
- [ ] crds-and-operators/assignment-1
- [ ] crds-and-operators/assignment-2
- [ ] crds-and-operators/assignment-3
- [ ] admission-controllers/assignment-1

---

## Phase 9: Cluster Infrastructure

**CKA Domain:** Cluster Architecture, Installation & Configuration (25%)
**Course alignment:** S6 Cluster Maintenance, S7 Security (TLS sections), S10-S11 Cluster Design and kubeadm
**Prerequisites:** Phase 1 complete, Phase 6 recommended
**Estimated time:** 8-10 hours

This phase covers operational topics: how Kubernetes clusters are bootstrapped, maintained, upgraded, and secured at the infrastructure level. While most learners use managed clusters or kind in practice, the CKA exam tests kubeadm workflows, etcd backup/restore, and certificate management. This phase is placed late because these are operational concerns rather than daily development tasks.

| Order | Assignment | Focus |
|---|---|---|
| 44 | cluster-lifecycle/assignment-1 | kubeadm init/join, cluster bootstrapping, node management |
| 45 | cluster-lifecycle/assignment-2 | Version upgrades with kubeadm, drain/cordon workflows |
| 46 | cluster-lifecycle/assignment-3 | etcd backup and restore, disaster recovery |
| 47 | tls-and-certificates/assignment-1 | Kubernetes PKI, certificate creation with openssl |
| 48 | tls-and-certificates/assignment-2 | Certificates API, CertificateSigningRequests |
| 49 | tls-and-certificates/assignment-3 | kubeconfig management, certificate troubleshooting |

**Progress:**
- [ ] cluster-lifecycle/assignment-1
- [ ] cluster-lifecycle/assignment-2
- [ ] cluster-lifecycle/assignment-3
- [ ] tls-and-certificates/assignment-1
- [ ] tls-and-certificates/assignment-2
- [ ] tls-and-certificates/assignment-3

---

## Phase 10: Troubleshooting Capstone

**CKA Domain:** Troubleshooting (30%)
**Course alignment:** S14 Troubleshooting
**Prerequisites:** All previous phases complete
**Estimated time:** 8-10 hours

Troubleshooting is the largest CKA exam domain (30%). This phase is designed as a capstone that integrates concepts from all previous phases. Each assignment focuses on a different failure layer: application workloads, control plane components, worker nodes, and networking. Complete this phase last.

| Order | Assignment | Focus |
|---|---|---|
| 50 | troubleshooting/assignment-1 | Application failures: pods, deployments, configs |
| 51 | troubleshooting/assignment-2 | Control plane failures: API server, scheduler, controller manager, etcd |
| 52 | troubleshooting/assignment-3 | Node failures: kubelet, container runtime, node conditions |
| 53 | troubleshooting/assignment-4 | Network failures: services, DNS, policies, ingress |

**Progress:**
- [ ] troubleshooting/assignment-1
- [ ] troubleshooting/assignment-2
- [ ] troubleshooting/assignment-3
- [ ] troubleshooting/assignment-4

---

## CKA Domain Coverage Summary

| Domain | Weight | Phases | Assignments |
|---|---|---|---|
| Cluster Architecture, Installation & Configuration | 25% | 3, 6, 8, 9 | 17 |
| Workloads & Scheduling | 15% | 1, 2, 7 | 14 |
| Services & Networking | 20% | 5 | 14 |
| Storage | 10% | 4 | 3 |
| Troubleshooting | 30% | 10 (plus debugging exercises in all phases) | 4 |

Note: The troubleshooting domain is also covered by Level 3 and Level 5 debugging exercises in every assignment throughout the curriculum. The dedicated troubleshooting phase provides cross-domain integration.

---

## Alternate Paths

The phase order above follows a natural progression: build, configure, persist, expose, secure, operate, debug. However, some phases are independent and can be reordered based on your priorities:

**If you want to focus on exam weight:** After Phase 1, jump to Phase 5 (Networking, 20%) and then Phase 10 (Troubleshooting, 30%) since these two domains account for half the exam.

**If you are already comfortable with pods:** Skim Phase 1 tutorials for reference tables, skip the exercises, and start with Phase 2.

**If you need RBAC immediately:** Phase 6 only requires Phase 1 as a prerequisite. You can complete it earlier if access control is blocking your work.

**If you are preparing for the exam soon:** Prioritize Phase 9 (Cluster Infrastructure) earlier, since kubeadm and etcd tasks appear on the exam but are rarely practiced in daily work.

The only hard constraint is that Phase 10 (Troubleshooting) should be completed last, as it assumes familiarity with all other topics.

---

## Cluster Requirements

Most assignments work on a single-node kind cluster. The following require a multi-node cluster (1 control-plane + 3 workers):

- pods/assignment-4 through assignment-7 (scheduling and controllers)
- troubleshooting/assignment-3 (node failures)
- troubleshooting/assignment-4 (network failures)

Cluster setup commands are documented in `docs/cluster-setup.md`. Each assignment README specifies its cluster requirements.
