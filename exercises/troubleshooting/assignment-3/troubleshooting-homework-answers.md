# Node and Kubelet Troubleshooting Homework Answers

Solutions for all 15 exercises.

-----

## Exercise 1.1 Solution

```bash
kubectl get nodes -o wide
```

Shows all nodes with IP, OS, kernel, container runtime.

```bash
for node in $(kubectl get nodes -o name); do
  echo "=== $node ==="
  kubectl describe $node | grep -A10 "Conditions:"
done
```

-----

## Exercise 1.2 Solution

```bash
kubectl get nodes | grep -v " Ready"
```

For each NotReady node.

```bash
kubectl describe node <node> | grep -A20 "Events:"
```

Look for: kubelet stopped, network issues, resource pressure.

-----

## Exercise 1.3 Solution

```bash
kubectl describe node <node> | grep -A20 "Capacity:"
```

Shows total CPU, memory, pods.

```bash
kubectl describe node <node> | grep -A20 "Allocatable:"
```

Shows available resources after system reservations.

-----

## Exercise 2.1 Solution

```bash
docker exec kind-worker systemctl status kubelet
```

Should show "active (running)". If not active, kubelet has failed.

-----

## Exercise 2.2 Solution

```bash
docker exec kind-worker journalctl -u kubelet | tail -50
```

Look for: "error", "failed", "unable to", certificate issues, API server connection failures.

-----

## Exercise 2.3 Solution

```bash
docker exec kind-worker cat /var/lib/kubelet/config.yaml
```

Key settings: clusterDNS, clusterDomain, authentication, authorization, eviction thresholds.

-----

## Exercise 3.1 Solution

Memory pressure diagnosis.

1. Check condition.
```bash
kubectl describe node <node> | grep MemoryPressure
```

2. Check memory usage on node.
```bash
docker exec <node> free -h
```

3. Check what is using memory.
```bash
docker exec <node> ps aux --sort=-%mem | head
```

4. Check kubelet eviction thresholds.
```bash
docker exec <node> cat /var/lib/kubelet/config.yaml | grep -A5 eviction
```

-----

## Exercise 3.2 Solution

Disk pressure diagnosis.

1. Check condition.
```bash
kubectl describe node <node> | grep DiskPressure
```

2. Check disk usage.
```bash
docker exec <node> df -h
```

3. Check large directories.
```bash
docker exec <node> du -sh /* 2>/dev/null | sort -h
```

4. Check container images.
```bash
docker exec <node> crictl images
```

-----

## Exercise 3.3 Solution

Container runtime troubleshooting.

1. Check containerd status.
```bash
docker exec <node> systemctl status containerd
```

2. Check containerd logs.
```bash
docker exec <node> journalctl -u containerd | tail -50
```

3. Test crictl.
```bash
docker exec <node> crictl ps
docker exec <node> crictl info
```

4. Check socket.
```bash
docker exec <node> ls -la /run/containerd/containerd.sock
```

-----

## Exercise 4.1 Solution

```bash
kubectl drain kind-worker --ignore-daemonsets --delete-emptydir-data
```

Verify eviction.

```bash
kubectl get pods -A -o wide | grep kind-worker
```

Only DaemonSet pods should remain.

-----

## Exercise 4.2 Solution

```bash
kubectl uncordon kind-worker
kubectl get nodes
```

Node should show Ready,SchedulingDisabled becomes just Ready.

Test scheduling.

```bash
kubectl run test-pod --image=nginx:1.25 --restart=Never
kubectl get pod test-pod -o wide
kubectl delete pod test-pod
```

-----

## Exercise 4.3 Solution

```bash
kubectl describe node kind-worker | grep -A10 "Conditions:"
```

All conditions should show healthy values: Ready=True, MemoryPressure=False, DiskPressure=False, PIDPressure=False.

-----

## Exercise 5.1 Solution

NotReady node diagnostic workflow.

1. Identify the node.
```bash
kubectl get nodes
```

2. Check node conditions.
```bash
kubectl describe node <node> | grep -A10 "Conditions:"
```

3. Check events.
```bash
kubectl describe node <node> | grep -A20 "Events:"
```

4. Access the node and check kubelet.
```bash
docker exec <node> systemctl status kubelet
docker exec <node> journalctl -u kubelet | tail -50
```

5. Check container runtime.
```bash
docker exec <node> crictl info
```

6. Check resources.
```bash
docker exec <node> free -h
docker exec <node> df -h
```

-----

## Exercise 5.2 Solution

Handling problematic node.

1. Identify the node.
```bash
kubectl get pods -A -o wide | grep -v Running
```

2. Cordon the node to prevent new scheduling.
```bash
kubectl cordon <node>
```

3. Drain the node.
```bash
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data --force
```

4. Diagnose and fix the issue.

5. Uncordon after fix.
```bash
kubectl uncordon <node>
```

-----

## Exercise 5.3 Solution

Complete node recovery procedure.

1. Identify NotReady node.
2. Access node directly (SSH or docker exec).
3. Check kubelet status and logs.
4. Check container runtime.
5. Check disk and memory.
6. Fix identified issues.
7. Restart kubelet if needed: `systemctl restart kubelet`.
8. Verify node becomes Ready.
9. Uncordon if cordoned.
10. Verify pods can schedule.

-----

## Common Mistakes

1. Not checking kubelet logs when node is NotReady
2. Forgetting to uncordon after draining
3. Not checking resource pressure conditions
4. Assuming kubectl works when accessing a failed node
