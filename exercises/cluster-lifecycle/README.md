# Cluster Lifecycle

**CKA Domain:** Cluster Architecture, Installation & Configuration (25%)
**Competencies covered:** Prepare infrastructure, create/manage clusters with kubeadm,
manage cluster lifecycle, implement HA control plane, understand extension interfaces

---

## Why One Assignment

Cluster lifecycle covers the operational tasks of building, upgrading, and maintaining
a Kubernetes cluster: kubeadm installation, version upgrades, node maintenance (drain,
cordon, uncordon), etcd backup and restore, and high availability concepts. While this
spans several CKA competencies, the tasks are sequential in nature (you install, then
upgrade, then back up) and the subtopic count is roughly 10-12. The HA control plane
material is largely conceptual in a kind environment, which keeps the exercise count
manageable. If etcd backup/restore proves dense enough to warrant separation, this
topic can be split later.

---

## Assignments

| Assignment | Title | Covers | Prerequisites |
|---|---|---|---|
| assignment-1 | Cluster Lifecycle | kubeadm install workflow, cluster version upgrades (upgrade plan, upgrade apply), node drain/cordon/uncordon, etcd backup (etcdctl snapshot save), etcd restore (etcdctl snapshot restore), extension interfaces overview (CNI, CSI, CRI), HA control plane concepts | None |

## Scope Boundaries

This topic covers cluster-level operations. The following related areas are handled
by other topics:

- **RBAC** (who can perform cluster operations): covered in `rbac/`
- **TLS certificates** (cluster PKI, certificate creation and management): covered in `tls-and-certificates/`
- **Helm** (installing cluster components via charts): covered in `helm/`
- **Control plane troubleshooting** (diagnosing failed components): covered in `troubleshooting/assignment-2`
- **Node troubleshooting** (diagnosing NotReady nodes): covered in `troubleshooting/assignment-3`

## Cluster Requirements

Multi-node kind cluster. Some exercises (particularly etcd backup/restore and upgrade
simulations) may require custom kind configuration. The tutorial should document any
kind-specific workarounds for operations that behave differently than on bare-metal
kubeadm clusters.

## Recommended Order

This is the first planned assignment in the generation sequence. No prerequisites
beyond a working kind cluster.
