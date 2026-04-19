# Node and Kubelet Troubleshooting Homework

This homework contains 15 exercises for node-level troubleshooting. Due to kind cluster constraints, some exercises are conceptual.

## Setup

Multi-node kind cluster required.

```bash
kubectl get nodes
```

-----

## Level 1: Node Status

### Exercise 1.1

**Objective:** List all nodes and identify their conditions using kubectl.

**Verification:**

```bash
kubectl get nodes -o wide
kubectl describe nodes | grep -A10 "Conditions:"
```

-----

### Exercise 1.2

**Objective:** Identify any nodes with NotReady status and determine the cause from events.

**Verification:**

```bash
kubectl get nodes | grep -v Ready
kubectl describe node <node> | grep -A20 "Events:"
```

-----

### Exercise 1.3

**Objective:** View detailed node resource allocation and capacity.

**Verification:**

```bash
kubectl describe node <node> | grep -A20 "Capacity:" 
kubectl describe node <node> | grep -A20 "Allocatable:"
```

-----

## Level 2: Kubelet Issues

### Exercise 2.1

**Objective:** Access a worker node and check kubelet status.

**Verification:**

```bash
docker exec kind-worker systemctl status kubelet
```

-----

### Exercise 2.2

**Objective:** View kubelet logs and identify any errors or warnings.

**Verification:**

```bash
docker exec kind-worker journalctl -u kubelet | tail -50
```

-----

### Exercise 2.3

**Objective:** Identify kubelet configuration file location and view key settings.

**Verification:**

```bash
docker exec kind-worker cat /var/lib/kubelet/config.yaml | head -30
```

-----

## Level 3: Node Failures

### Exercise 3.1

**Objective:** Describe how to diagnose a node showing MemoryPressure condition.

**Verification:**

Document the diagnostic commands for memory pressure.

-----

### Exercise 3.2

**Objective:** Describe how to diagnose a node showing DiskPressure condition.

**Verification:**

Document the diagnostic commands for disk pressure.

-----

### Exercise 3.3

**Objective:** Explain how to troubleshoot container runtime issues on a node.

**Verification:**

Document the steps to check containerd/crictl status.

-----

## Level 4: Recovery

### Exercise 4.1

**Objective:** Drain a worker node and verify pods are evicted.

**Verification:**

```bash
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl get pods -A -o wide | grep <node>
```

-----

### Exercise 4.2

**Objective:** Uncordon the drained node and verify it can schedule pods.

**Verification:**

```bash
kubectl uncordon <node>
kubectl get nodes
kubectl run test-pod --image=nginx:1.25 --restart=Never
kubectl get pod test-pod -o wide
```

-----

### Exercise 4.3

**Objective:** Verify node recovery by checking conditions and capacity.

**Verification:**

```bash
kubectl describe node <node> | grep -A10 "Conditions:"
```

-----

## Level 5: Complex Scenarios

### Exercise 5.1

**Objective:** Design a diagnostic workflow for a node that suddenly becomes NotReady.

**Verification:**

Create a troubleshooting checklist.

-----

### Exercise 5.2

**Objective:** Describe how to handle a node that is causing pod failures across multiple workloads.

**Verification:**

Document the identification and isolation steps.

-----

### Exercise 5.3

**Objective:** Create a complete node recovery procedure from NotReady to healthy.

**Verification:**

Document the full recovery process.

-----

## Key Takeaways

Understanding node conditions, kubelet troubleshooting, drain/uncordon operations, and systematic node recovery.
