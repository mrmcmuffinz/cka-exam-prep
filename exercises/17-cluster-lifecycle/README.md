# Cluster Lifecycle

**CKA Domain:** Cluster Architecture, Installation & Configuration (25%)
**Competencies covered:** Prepare underlying infrastructure for installing a Kubernetes cluster, create and manage Kubernetes clusters using kubeadm, manage the lifecycle of Kubernetes clusters, implement and configure a highly available control plane, understand extension interfaces (CNI, CSI, CRI)

---

## Rationale for Number of Assignments

Cluster lifecycle encompasses cluster installation with kubeadm, cluster version upgrades, node maintenance operations (drain, cordon, uncordon), etcd backup and restore, extension interfaces (CNI, CSI, CRI), and HA control plane design. This produces roughly 16-18 distinct subtopics. The material splits naturally into three focused progressions: installation and bootstrap (kubeadm init/join, prerequisites, extension interfaces), upgrades and maintenance (version upgrades, node lifecycle operations), and etcd operations with HA concepts. Each assignment delivers 5-6 subtopics at depth, building from initial cluster creation through operational maintenance to data management and availability design.

---

## Assignment Summary

| Assignment | Description | Prerequisites |
|---|---|---|
| assignment-1 | Cluster Installation | Node prerequisites and preparation, kubeadm init workflow and configuration, kubeadm join for worker nodes, control plane component verification, extension interfaces (CNI, CSI, CRI) at conceptual level, cluster health checks | None (foundational topic) |
| assignment-2 | Cluster Upgrades and Maintenance | Upgrade planning (kubeadm upgrade plan, version compatibility), control plane node upgrade workflow, worker node upgrade workflow, node drain best practices and scenarios, node cordon and uncordon, post-upgrade verification | cluster-lifecycle/assignment-1 |
| assignment-3 | etcd Operations and High Availability | etcd architecture in Kubernetes, etcd backup with etcdctl snapshot save, etcd restore with etcdctl snapshot restore, etcd health and data integrity verification, HA control plane with stacked etcd, HA control plane with external etcd | cluster-lifecycle/assignment-2 |

## Scope Boundaries

This topic covers cluster bootstrapping, lifecycle management, and data operations. The following related areas are handled by other topics:

- **TLS certificates and PKI** (cluster certificates, certificate creation, Certificates API): covered in `tls-and-certificates/`
- **RBAC** (cluster-admin permissions, bootstrap tokens): covered in `rbac/`
- **Troubleshooting control plane failures** (API server down, etcd corruption, certificate expiration): covered in `troubleshooting/assignment-2`
- **Troubleshooting node failures** (kubelet not running, node NotReady): covered in `troubleshooting/assignment-3`

Assignment-1 focuses on successful cluster creation. Assignment-2 focuses on successful upgrades and planned maintenance. Assignment-3 focuses on etcd operations and HA architecture. The troubleshooting series adds failure scenarios where these operations go wrong.

## Cluster Requirements

Multi-node kind cluster for assignments 1 and 2 (1 control-plane, 2-3 workers). Assignment-3 may need custom kind configuration for etcd exercises, or may use conceptual scenarios where kind limitations prevent hands-on practice. The tutorial should clearly identify which exercises work in kind and which are conceptual.

**Kind cluster note:** Kind abstracts some kubeadm operations. Assignment-1 should explain where kind behavior diverges from bare-metal kubeadm clusters and how to observe kubeadm artifacts within kind nodes (static pod manifests, kubeadm config). HA control plane exercises in assignment-3 may be conceptual only, as kind's control plane is containerized.

## Recommended Order

1. Complete `cluster-lifecycle/assignment-1` first (prerequisite for understanding cluster structure)
2. Work through assignments 1, 2, 3 sequentially
3. Assignment-2 assumes understanding of kubeadm-managed clusters from assignment-1
4. Assignment-3 assumes understanding of cluster upgrades and node operations from assignment-2
5. Generate `tls-and-certificates` immediately after completing cluster-lifecycle series (certificates build on cluster PKI understanding)
