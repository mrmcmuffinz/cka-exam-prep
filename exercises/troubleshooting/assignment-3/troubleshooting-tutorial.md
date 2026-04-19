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

## Part 6: Node Debugging with kubectl debug

When a node is unhealthy or you need to inspect node-level state without SSH access, use `kubectl debug node/<node-name>` to create a privileged pod with direct access to the node's filesystem and processes. This is essential for clusters where nodes are not directly accessible, such as managed Kubernetes services or nodes behind restrictive firewalls.

### How Node Debugging Works

The command `kubectl debug node/<node-name>` creates a temporary pod on the target node with `hostNetwork: true`, `hostPID: true`, and `hostIPC: true`, giving it full access to the node's namespaces. The node's root filesystem is mounted at `/host` inside the debug pod, allowing you to inspect logs, binaries, and configuration files as if you were logged into the node directly.

### Basic Node Debugging

List your nodes.

```bash
kubectl get nodes
```

Pick a worker node and debug it. Replace `kind-worker` with an actual node name from your cluster.

```bash
kubectl debug node/kind-worker -it --image=ubuntu:22.04
```

This drops you into a shell in a privileged pod running on the specified node. The prompt may differ from a normal shell because you are inside a container, but you have full node access.

Inside the debug session, check the node's root filesystem.

```bash
ls /host
```

You see the node's actual root filesystem. This includes `/host/etc`, `/host/var`, `/host/proc`, and all other directories. To run commands as if you were on the node itself, use `chroot /host`.

```bash
chroot /host
```

Now you are effectively on the node. Check the kubelet status.

```bash
systemctl status kubelet
```

This shows whether the kubelet service is running. If it is stopped or failing, this is often the cause of a NotReady node. Check kubelet logs.

```bash
journalctl -u kubelet --no-pager | tail -50
```

This shows recent kubelet log entries. Look for errors related to the container runtime, certificate problems, or connectivity to the API server. Exit the chroot and then exit the debug pod.

```bash
exit  # Exit chroot
exit  # Exit debug pod
```

The debug pod is automatically deleted after you exit.

### Inspecting Container Runtime State

Node debugging is useful for inspecting the container runtime when containers are failing to start or the runtime itself is unhealthy.

```bash
kubectl debug node/kind-worker -it --image=ubuntu:22.04 -- bash -c "chroot /host crictl ps -a"
```

This lists all containers on the node, including stopped and crashed ones. If `crictl` is not found, the containerd or CRI-O runtime may not be installed or configured correctly. You can also check containerd status.

```bash
kubectl debug node/kind-worker -it --image=ubuntu:22.04 -- bash -c "chroot /host systemctl status containerd"
```

If containerd is stopped, the kubelet cannot create containers, causing pods to remain Pending or fail with CreateContainerError.

### Inspecting Node Logs and Configuration

Node debugging provides access to system logs that are not available through kubectl logs or describe.

```bash
kubectl debug node/kind-worker -it --image=ubuntu:22.04 -- bash -c "chroot /host dmesg | tail -50"
```

This shows kernel messages from the node. Look for OOMKiller entries, hardware errors, or kernel panics. You can also inspect kubelet configuration.

```bash
kubectl debug node/kind-worker -it --image=ubuntu:22.04 -- bash -c "cat /host/var/lib/kubelet/config.yaml"
```

This displays the kubelet's configuration file. Common issues include incorrect API server endpoints, wrong certificate paths, or misconfigured feature gates.

### When to Use Node Debugging

Use `kubectl debug node/<node-name>` when a node is NotReady and you cannot SSH into it, when you need to inspect kubelet or container runtime logs without external access, when you need to verify that certificates or configuration files are present on the node, or when system-level diagnostics like `dmesg` or disk usage checks are required. This technique is critical in managed Kubernetes environments where node SSH access is restricted or unavailable.

### Node Debug Cleanup

The debug pod is ephemeral and automatically cleaned up after exit. If you need to leave the session running for extended diagnostics, you can omit the `-it` flags and use `kubectl exec` to re-enter later, but this is rare. Most node debugging sessions are short-lived interactive investigations.

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
| Debug node | `kubectl debug node/<node> -it --image=ubuntu:22.04` |
| Debug node with command | `kubectl debug node/<node> -it --image=ubuntu:22.04 -- bash -c "chroot /host <cmd>"` |
