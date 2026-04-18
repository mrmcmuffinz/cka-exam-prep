# Cluster Lifecycle Tutorial: Cluster Upgrades and Maintenance

This tutorial covers Kubernetes cluster upgrades and node maintenance operations. You will learn the kubeadm upgrade workflow, how to safely drain nodes, and how to verify successful upgrades.

## Introduction

Kubernetes releases new versions approximately every four months. Staying current ensures you have security patches and bug fixes. However, upgrades must be performed carefully to maintain cluster availability. This tutorial explains the upgrade process and the node maintenance operations that support it.

## Prerequisites

Before starting this tutorial, ensure you have:

- A multi-node kind cluster running
- kubectl configured to communicate with your cluster
- Completed cluster-lifecycle/assignment-1

## Tutorial Setup

```bash
kubectl create namespace tutorial-cluster-lifecycle
```

## Version Skew Policy

Kubernetes components have strict version compatibility rules:

- **kubelet:** Can be one minor version behind the API server (e.g., API server 1.30, kubelet 1.29)
- **kubectl:** Can be one minor version ahead or behind the API server
- **kube-proxy, controller-manager, scheduler:** Must match the API server version

### Upgrade Order

Upgrades must be sequential. You cannot skip minor versions:
- 1.29 to 1.30: Valid
- 1.29 to 1.31: Invalid (must go 1.29 to 1.30, then 1.30 to 1.31)

### Checking Versions

```bash
kubectl version
kubectl get nodes
```

## Node Maintenance Operations

Before upgrading node components, you must safely remove workloads from the node.

### Cordon

Cordon marks a node as unschedulable. New pods will not be scheduled to this node, but existing pods continue running.

```bash
# Cordon a node
kubectl cordon kind-worker

# Verify
kubectl get nodes
# Shows SchedulingDisabled

# Uncordon
kubectl uncordon kind-worker
```

### Drain

Drain evicts all pods from a node. It:
1. Cordons the node (marks unschedulable)
2. Evicts all pods (respecting PodDisruptionBudgets)
3. Waits for pods to terminate

```bash
# Create a deployment for testing
kubectl create deployment drain-test --image=nginx:1.25 --replicas=4 -n tutorial-cluster-lifecycle
kubectl wait --for=condition=available deployment/drain-test -n tutorial-cluster-lifecycle --timeout=60s

# Check pod distribution
kubectl get pods -n tutorial-cluster-lifecycle -o wide

# Drain a worker node
kubectl drain kind-worker --ignore-daemonsets

# Check pods moved to other nodes
kubectl get pods -n tutorial-cluster-lifecycle -o wide

# Uncordon
kubectl uncordon kind-worker
```

### Drain Flags

Important flags:
- `--ignore-daemonsets`: Required because DaemonSet pods cannot be evicted
- `--delete-emptydir-data`: Allow eviction of pods using emptyDir volumes
- `--force`: Evict pods not managed by controllers (standalone pods)
- `--grace-period`: Override pod termination grace period

### PodDisruptionBudgets

PDBs limit how many pods can be unavailable during disruptions.

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: drain-test-pdb
  namespace: tutorial-cluster-lifecycle
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: drain-test
EOF
```

With this PDB, drain will only proceed if at least 3 pods remain available.

```bash
# Try draining (may take time as it respects PDB)
kubectl drain kind-worker2 --ignore-daemonsets --timeout=60s

# Uncordon
kubectl uncordon kind-worker2

# Cleanup
kubectl delete pdb drain-test-pdb -n tutorial-cluster-lifecycle
kubectl delete deployment drain-test -n tutorial-cluster-lifecycle
```

## Control Plane Upgrade Workflow

In a real cluster (not kind), the upgrade workflow is:

### 1. Upgrade kubeadm

```bash
# Ubuntu/Debian
apt-get update && apt-get install -y kubeadm=1.30.0-00

# Verify
kubeadm version
```

### 2. Plan the Upgrade

```bash
kubeadm upgrade plan
```

This shows available upgrade paths and what will be upgraded.

### 3. Apply the Upgrade

```bash
kubeadm upgrade apply v1.30.0
```

This upgrades static pod manifests and cluster configuration.

### 4. Drain and Upgrade kubelet

```bash
# From another machine
kubectl drain <control-plane-node> --ignore-daemonsets

# On the control plane node
apt-get install -y kubelet=1.30.0-00 kubectl=1.30.0-00
systemctl daemon-reload
systemctl restart kubelet

# From another machine
kubectl uncordon <control-plane-node>
```

## Worker Node Upgrade Workflow

For each worker node:

### 1. Drain the Node

```bash
kubectl drain <worker-node> --ignore-daemonsets
```

### 2. Upgrade kubeadm and Apply

```bash
# On the worker node
apt-get install -y kubeadm=1.30.0-00
kubeadm upgrade node
```

Note: Workers use `kubeadm upgrade node`, not `kubeadm upgrade apply`.

### 3. Upgrade kubelet

```bash
apt-get install -y kubelet=1.30.0-00 kubectl=1.30.0-00
systemctl daemon-reload
systemctl restart kubelet
```

### 4. Uncordon

```bash
kubectl uncordon <worker-node>
```

## Post-Upgrade Verification

After upgrading all nodes:

```bash
# All nodes should show new version
kubectl get nodes

# Control plane pods should be running new version
kubectl get pods -n kube-system -o wide

# Test cluster functionality
kubectl run test --image=nginx:1.25 --rm -it --restart=Never -- echo "Cluster working"
```

## Tutorial Cleanup

```bash
kubectl delete namespace tutorial-cluster-lifecycle
```

## Reference Commands

| Task | Command |
|------|---------|
| Check version | `kubectl version` |
| Cordon node | `kubectl cordon <node>` |
| Uncordon node | `kubectl uncordon <node>` |
| Drain node | `kubectl drain <node> --ignore-daemonsets` |
| Force drain | `kubectl drain <node> --ignore-daemonsets --force` |
| Check node status | `kubectl get nodes` |
| Upgrade plan | `kubeadm upgrade plan` |
| Apply upgrade | `kubeadm upgrade apply vX.Y.Z` |
| Upgrade node | `kubeadm upgrade node` |
