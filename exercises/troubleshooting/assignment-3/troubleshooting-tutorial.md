# Node and Kubelet Troubleshooting Tutorial

This tutorial covers node-level troubleshooting: diagnosing NotReady nodes, kubelet issues, container runtime problems, and node recovery.

## Part 1: Node Status and Conditions

### Checking Node Status

```bash
kubectl get nodes
```

Healthy nodes show Ready status. NotReady indicates problems.

### Node Conditions

```bash
kubectl describe node <node-name> | grep -A10 "Conditions:"
```

Key conditions: Ready (kubelet healthy), MemoryPressure (low memory), DiskPressure (low disk), PIDPressure (too many processes), NetworkUnavailable (CNI not configured).

### Node Events

```bash
kubectl describe node <node-name> | grep -A20 "Events:"
```

Events show recent node activity and errors.

## Part 2: Kubelet Troubleshooting

### Checking Kubelet Status

On the node (for kind clusters).

```bash
docker exec kind-worker systemctl status kubelet
```

### Kubelet Logs

```bash
docker exec kind-worker journalctl -u kubelet | tail -100
```

Common kubelet issues: certificate problems, container runtime unavailable, API server connectivity, resource exhaustion.

## Part 3: Container Runtime

### Checking Container Runtime

```bash
docker exec kind-worker crictl ps
docker exec kind-worker crictl info
```

If crictl fails, the container runtime may be down.

## Part 4: Node Conditions and Taints

### Automatic Taints

When conditions are unhealthy, taints are added automatically: node.kubernetes.io/not-ready, node.kubernetes.io/unreachable, node.kubernetes.io/memory-pressure, node.kubernetes.io/disk-pressure, node.kubernetes.io/pid-pressure.

### Checking Taints

```bash
kubectl describe node <node> | grep -A5 "Taints:"
```

## Part 5: Node Drain and Recovery

### Draining a Node

```bash
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
```

This evicts pods and marks the node unschedulable.

### Recovering a Node

After fixing the issue.

```bash
kubectl uncordon <node>
```

This marks the node schedulable again.

## Reference Commands

| Task | Command |
|------|---------|
| Node status | `kubectl get nodes` |
| Node details | `kubectl describe node <node>` |
| Node conditions | `kubectl get nodes -o jsonpath='{.items[*].status.conditions}'` |
| Kubelet status | `systemctl status kubelet` (on node) |
| Kubelet logs | `journalctl -u kubelet` (on node) |
| Drain node | `kubectl drain <node> --ignore-daemonsets` |
| Uncordon node | `kubectl uncordon <node>` |
