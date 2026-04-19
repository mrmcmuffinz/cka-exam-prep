# Cluster Lifecycle Tutorial: etcd Operations and High Availability

This tutorial covers etcd architecture, backup and restore operations, health verification, and HA control plane concepts.

## Introduction

Etcd is the distributed key-value store that holds all Kubernetes cluster state: resource definitions, secrets, configuration, and more. If etcd data is lost, the cluster loses all its state. Regular backups and understanding recovery procedures are essential for cluster administrators.

## Prerequisites

- Multi-node kind cluster running
- Completed 17-cluster-lifecycle/assignment-1 and assignment-2

## Tutorial Setup

```bash
kubectl create namespace tutorial-cluster-lifecycle
```

## etcd Architecture

### Role in Kubernetes

Etcd stores all cluster state:
- Resource definitions (Deployments, Services, ConfigMaps)
- Secrets
- Cluster configuration
- RBAC rules
- Service account tokens

The API server is the only component that communicates directly with etcd.

### etcd Topologies

**Stacked etcd:** etcd runs on control plane nodes as static pods. Simpler to set up but couples etcd availability with control plane.

**External etcd:** etcd runs on dedicated nodes. More complex but provides better isolation and can be scaled independently.

In kind, etcd runs stacked on the control plane.

### Quorum Requirements

Etcd requires a majority (quorum) to accept writes:
- 1 node: No fault tolerance
- 3 nodes: Tolerates 1 failure
- 5 nodes: Tolerates 2 failures

Formula: Can tolerate (n-1)/2 failures for n nodes.

## Exploring etcd in Kind

### Locating etcd

```bash
# Find etcd pod
kubectl get pods -n kube-system -l component=etcd

# Examine etcd static pod manifest
nerdctl exec kind-control-plane cat /etc/kubernetes/manifests/etcd.yaml
```

### etcd Certificate Paths

etcdctl requires certificates for authentication:

```bash
nerdctl exec kind-control-plane ls /etc/kubernetes/pki/etcd/
# ca.crt, server.crt, server.key, peer.crt, peer.key, etc.
```

Key files:
- **ca.crt:** etcd CA certificate
- **server.crt, server.key:** etcd server certificate
- **peer.crt, peer.key:** peer communication certificates

## etcd Backup

### Using etcdctl

etcdctl is the CLI for etcd. In kind, etcd is inside a container, so we exec into it.

```bash
# Exec into kind control plane
nerdctl exec -it kind-control-plane /bin/bash

# Set environment and create backup
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify backup
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup.db

exit
```

### Backup Best Practices

1. **Regular schedule:** Backup at least daily
2. **Before upgrades:** Always backup before cluster changes
3. **Off-cluster storage:** Copy backups to external storage
4. **Test restores:** Periodically verify backups work

### Copy Backup Out of Kind

```bash
nerdctl cp kind-control-plane:/tmp/etcd-backup.db ./etcd-backup.db
```

## etcd Restore (Conceptual)

Restore is complex because it creates a new etcd cluster. In kind, this is not practical to perform, but understanding the process is important.

### Restore Workflow

1. Stop the API server (or prevent it from connecting to etcd)
2. Run etcdctl snapshot restore with new data directory
3. Update etcd static pod manifest to use new data directory
4. Restart etcd
5. Verify cluster state

### Restore Command

```bash
ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-backup.db \
  --data-dir=/var/lib/etcd-new
```

The --data-dir flag specifies where to restore data. This should be a new directory to avoid corrupting existing data.

### Post-Restore

After restore, update the etcd static pod manifest:

```yaml
# In /etc/kubernetes/manifests/etcd.yaml
volumes:
- hostPath:
    path: /var/lib/etcd-new  # Changed from /var/lib/etcd
    type: DirectoryOrCreate
  name: etcd-data
```

## etcd Health Verification

### Endpoint Health

```bash
nerdctl exec kind-control-plane /bin/bash -c '
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
'
```

### Endpoint Status

```bash
nerdctl exec kind-control-plane /bin/bash -c '
ETCDCTL_API=3 etcdctl endpoint status \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
'
```

### Member List

```bash
nerdctl exec kind-control-plane /bin/bash -c '
ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
'
```

## HA Control Plane Concepts

### Stacked HA Topology

Multiple control plane nodes, each running:
- etcd
- API server
- Controller manager
- Scheduler

Requires:
- Load balancer for API server access
- Odd number of nodes (3 or 5) for etcd quorum
- kubeadm init with --control-plane-endpoint

### External etcd HA Topology

Dedicated etcd cluster separate from control plane:
- Better isolation
- Can scale etcd independently
- More complex to set up

### Leader Election

Controller manager and scheduler use leader election. Only one instance is active at a time. Others are standby.

```bash
kubectl get lease -n kube-system
```

## Tutorial Cleanup

```bash
kubectl delete namespace tutorial-cluster-lifecycle
```

## Reference Commands

| Task | Command |
|------|---------|
| Backup etcd | `etcdctl snapshot save <file>` |
| Verify backup | `etcdctl snapshot status <file>` |
| Restore etcd | `etcdctl snapshot restore <file> --data-dir=<new-dir>` |
| Check health | `etcdctl endpoint health` |
| Check status | `etcdctl endpoint status` |
| List members | `etcdctl member list` |

Always include authentication flags:
```
--endpoints=https://127.0.0.1:2379
--cacert=/etc/kubernetes/pki/etcd/ca.crt
--cert=/etc/kubernetes/pki/etcd/server.crt
--key=/etc/kubernetes/pki/etcd/server.key
```

And set: `ETCDCTL_API=3`
