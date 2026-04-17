# Pod Resources and QoS: Tutorial

This tutorial walks through Kubernetes resource management from the ground up. You will start with a pod that has no resource declarations, progressively add requests and limits, observe all three QoS classes, trigger an OOMKill, see CPU throttling behavior, and finally configure namespace-level controls with LimitRange and ResourceQuota.

Everything runs in a dedicated namespace so it won't interfere with your exercises later.

## Understanding Your Cluster's Capacity

Before doing anything with resources, you need to know what your cluster actually has available. Run this command for a quick overview:

```bash
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
CPU:.status.allocatable.cpu,\
MEM:.status.allocatable.memory
```

You should see output like:

```
NAME                 CPU   MEM
kind-control-plane   8     16309892Ki
kind-worker          8     16309892Ki
kind-worker2         8     16309892Ki
kind-worker3         8     16309892Ki
```

For a detailed breakdown of a single node, use:

```bash
kubectl describe node kind-worker | grep -A 6 "Allocatable:"
```

This shows allocatable CPU, memory, ephemeral-storage, and pod count. The allocatable values are what the scheduler uses when placing pods. They exclude system reserves (kubelet, OS) from the raw capacity.

**Important caveat about kind clusters:** kind nodes are containers running on your host machine, so they inherit the host's full CPU and memory. A kind worker might report 8 CPUs and 16Gi of memory even though a real production node might have only 2 CPUs and 4Gi. This means resource requests that would fail to schedule on a real cluster will schedule just fine on kind. Keep this in mind when exercises use deliberately large requests to demonstrate scheduling failures; the values need to exceed your actual allocatable amounts.

The difference between capacity and allocatable matters. Capacity is the total hardware the node reports. Allocatable is capacity minus system reserves (memory reserved for the kubelet, kube-reserved, system-reserved). When you see numbers in `kubectl describe node`, the allocatable line is what the scheduler actually uses.

## Setup

Create the tutorial namespace:

```bash
kubectl create namespace tutorial-pod-resources
```

## Step 1: A Pod with No Resource Declarations

Start with the simplest case. This pod has no requests or limits at all.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: no-resources
  namespace: tutorial-pod-resources
spec:
  containers:
  - name: app
    image: nginx:1.25
EOF
```

Wait for it to be running:

```bash
kubectl wait --for=condition=Ready pod/no-resources -n tutorial-pod-resources --timeout=60s
```

Check the QoS class:

```bash
kubectl get pod no-resources -n tutorial-pod-resources -o jsonpath='{.status.qosClass}'
```

The output is `BestEffort`. When no container in a pod specifies any requests or limits for CPU or memory, Kubernetes assigns the BestEffort QoS class. This means the pod gets whatever resources happen to be available, and under memory pressure, it will be the first to be evicted.

Check the resource fields to confirm they are absent:

```bash
kubectl get pod no-resources -n tutorial-pod-resources \
  -o jsonpath='{.spec.containers[0].resources}'
```

The output is `{}`, confirming no resource declarations exist.

## Step 2: Adding a Memory Request

Now create a pod that declares how much memory it needs but sets no upper bound.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: mem-request-only
  namespace: tutorial-pod-resources
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        memory: "128Mi"
EOF
```

```bash
kubectl wait --for=condition=Ready pod/mem-request-only -n tutorial-pod-resources --timeout=60s
```

Check the QoS class:

```bash
kubectl get pod mem-request-only -n tutorial-pod-resources -o jsonpath='{.status.qosClass}'
```

The output is `Burstable`. The pod has at least one resource request but does not qualify as Guaranteed (which requires every container to have matching requests and limits for both CPU and memory). Burstable pods are evicted after BestEffort pods but before Guaranteed pods under memory pressure.

The `requests.memory: 128Mi` field tells the scheduler: "this pod needs at least 128 mebibytes of memory on whatever node you place it." The scheduler will not place the pod on a node that cannot satisfy that reservation. However, the request does NOT cap how much memory the container can actually use at runtime. Without a memory limit, the container can consume memory up to the node's allocatable amount.

### Understanding Memory Units

Memory is specified in bytes with an optional suffix. Kubernetes supports both binary and decimal suffixes:

| Suffix | Type | Bytes | Example |
|--------|------|-------|---------|
| Ki | Binary (kibibyte) | 1024 | 256Ki = 262,144 bytes |
| Mi | Binary (mebibyte) | 1024^2 = 1,048,576 | 128Mi = 134,217,728 bytes |
| Gi | Binary (gibibyte) | 1024^3 = 1,073,741,824 | 2Gi = 2,147,483,648 bytes |
| K | Decimal (kilobyte) | 1000 | 256K = 256,000 bytes |
| M | Decimal (megabyte) | 1000^2 = 1,000,000 | 128M = 128,000,000 bytes |
| G | Decimal (gigabyte) | 1000^3 = 1,000,000,000 | 2G = 2,000,000,000 bytes |

**Always prefer Mi/Gi (binary) over M/G (decimal).** Binary units match how operating systems and the kernel actually measure memory. Using decimal units creates a subtle mismatch: `128M` is about 122Mi, which is roughly 4.7% less than `128Mi`. This difference can cause unexpected OOMKills when you think you have more memory than you actually do.

## Step 3: Adding a CPU Request

Create a pod with both a CPU request and a memory request, but still no limits.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: cpu-and-mem-request
  namespace: tutorial-pod-resources
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        cpu: "250m"
        memory: "128Mi"
EOF
```

```bash
kubectl wait --for=condition=Ready pod/cpu-and-mem-request -n tutorial-pod-resources --timeout=60s
kubectl get pod cpu-and-mem-request -n tutorial-pod-resources -o jsonpath='{.status.qosClass}'
```

Still `Burstable`. Requests without matching limits never produce a Guaranteed pod.

### Understanding CPU Units

CPU is measured in "millicores" (or millicpu). One CPU equals 1000 millicores:

| Value | Meaning |
|-------|---------|
| `1` | 1 full CPU (one core/hyperthread/vCPU) |
| `1000m` | Same as `1`, just expressed in millicores |
| `500m` | Half a CPU |
| `0.5` | Same as `500m` |
| `250m` | Quarter of a CPU |
| `100m` | One-tenth of a CPU |

What does "one CPU" mean in practice? It's one kernel scheduling slot per CFS (Completely Fair Scheduler) period (usually 100ms). A container with `cpu: 500m` gets 50ms of CPU time per 100ms period. On a multi-core machine, that 50ms can be spread across cores; it does not pin to a single core.

The `requests.cpu: 250m` field tells the scheduler: "this pod needs at least 250 millicores of CPU reserved on the node." Like memory requests, this is a scheduling reservation, not a runtime cap. Without a CPU limit, the container can burst to use as much CPU as the node has available.

## Step 4: Adding Limits (and Achieving Guaranteed QoS)

Now create a pod where every container has requests equal to limits for both CPU and memory. This is the only way to get the Guaranteed QoS class.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: guaranteed-pod
  namespace: tutorial-pod-resources
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        cpu: "250m"
        memory: "128Mi"
      limits:
        cpu: "250m"
        memory: "128Mi"
EOF
```

```bash
kubectl wait --for=condition=Ready pod/guaranteed-pod -n tutorial-pod-resources --timeout=60s
kubectl get pod guaranteed-pod -n tutorial-pod-resources -o jsonpath='{.status.qosClass}'
```

The output is `Guaranteed`. The rules are strict: every container in the pod must have both `requests.cpu` and `requests.memory` set, both `limits.cpu` and `limits.memory` set, and requests must equal limits for both resources in every container. If any container is missing a field, or if any request differs from its corresponding limit, the pod falls to Burstable.

A shortcut: if you specify only `limits` without `requests`, Kubernetes automatically sets `requests` equal to `limits`. This produces the same Guaranteed result:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: guaranteed-shortcut
  namespace: tutorial-pod-resources
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      limits:
        cpu: "250m"
        memory: "128Mi"
EOF
```

```bash
kubectl wait --for=condition=Ready pod/guaranteed-shortcut -n tutorial-pod-resources --timeout=60s
kubectl get pod guaranteed-shortcut -n tutorial-pod-resources \
  -o jsonpath='requests={.spec.containers[0].resources.requests} limits={.spec.containers[0].resources.limits}'
```

You'll see that `requests` was auto-populated to match `limits`. This is a handy shortcut, but it can be surprising if you didn't expect it. Being explicit about both fields is clearer.

### Understanding Limits at Runtime

Limits are hard caps enforced by the kernel (via cgroups), not the scheduler. The scheduler only looks at requests when placing pods. Limits kick in after the pod is running:

- **Memory limit:** If a container tries to allocate memory beyond its limit, the kernel's OOM killer terminates the container's main process. The container gets an OOMKilled status with exit code 137.
- **CPU limit:** If a container tries to use more CPU than its limit allows, the kernel throttles it. The container is NOT killed; it simply runs slower. It gets fewer CPU cycles per scheduling period.

This asymmetry (memory kills, CPU throttles) is one of the most important things to understand about Kubernetes resource management.

## Step 5: Watching an OOMKill

Create a pod that deliberately allocates more memory than its limit allows.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: oom-demo
  namespace: tutorial-pod-resources
spec:
  containers:
  - name: stress
    image: polinux/stress:1.0.4
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "100M", "--timeout", "60"]
    resources:
      requests:
        memory: "64Mi"
      limits:
        memory: "64Mi"
EOF
```

This pod runs the `stress` tool, which will attempt to allocate 100MB of memory. The memory limit is 64Mi. The container will be killed by the OOM killer.

Wait a few seconds, then check the pod status:

```bash
sleep 10
kubectl get pod oom-demo -n tutorial-pod-resources
```

You should see `OOMKilled` in the STATUS column, or possibly `CrashLoopBackOff` if enough restarts have happened. Check the details:

```bash
kubectl get pod oom-demo -n tutorial-pod-resources \
  -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
```

The output is `OOMKilled`. Check the exit code:

```bash
kubectl get pod oom-demo -n tutorial-pod-resources \
  -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
```

The output is `137`. Exit code 137 means the process was killed by signal 9 (SIGKILL). 128 + 9 = 137. This is the universal indicator of an OOM kill.

Check the restart count:

```bash
kubectl get pod oom-demo -n tutorial-pod-resources \
  -o jsonpath='{.status.containerStatuses[0].restartCount}'
```

The default `restartPolicy` is `Always`, so Kubernetes keeps restarting the container. Each restart triggers another OOM kill because the stress command always tries to allocate 100MB against a 64Mi limit. The restart count climbs and eventually the pod enters `CrashLoopBackOff`, where Kubernetes adds exponential backoff delays between restarts.

## Step 6: CPU Throttling Behavior

Create a pod that tries to burn CPU but has a tight CPU limit.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: cpu-throttle-demo
  namespace: tutorial-pod-resources
spec:
  containers:
  - name: burner
    image: busybox:1.36
    command: ["sh", "-c", "timeout 60 dd if=/dev/zero of=/dev/null bs=1M"]
    resources:
      requests:
        cpu: "100m"
      limits:
        cpu: "100m"
        memory: "64Mi"
EOF
```

This pod runs `dd` to burn CPU as fast as it can, but the CPU limit is only 100m (one-tenth of a CPU). The container will NOT be killed. Instead, the kernel throttles it: `dd` gets only 10ms of CPU time per 100ms scheduling period, so it runs much slower than it would without the limit.

```bash
kubectl wait --for=condition=Ready pod/cpu-throttle-demo -n tutorial-pod-resources --timeout=60s
kubectl get pod cpu-throttle-demo -n tutorial-pod-resources
```

The pod stays Running. No OOMKill, no CrashLoopBackOff. The `dd` command simply runs slowly. After 60 seconds (the `timeout` value), it exits normally.

Directly measuring CPU throttling requires either `metrics-server` (not installed by default in kind) or inspecting the container's cgroup `cpu.stat` file for `nr_throttled` and `throttled_time` counters. Both are out of scope for this tutorial, but in production, these are the tools you would use. The key takeaway is: CPU limits cause throttling, not killing. If your application is slower than expected but not crashing, excessive CPU throttling from a tight limit is a common cause.

## Step 7: Scheduling Failure from Insufficient Resources

The scheduler places pods based on requests, not limits. If a pod's requests exceed every node's available capacity, the pod stays Pending with a FailedScheduling event.

First, check how much memory your nodes have:

```bash
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
MEM:.status.allocatable.memory
```

Now create a pod that requests more memory than any single node has. Adjust the value below if your nodes have more or less than 16Gi. The request should exceed the largest node's allocatable memory:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: unschedulable-demo
  namespace: tutorial-pod-resources
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        memory: "64Gi"
EOF
```

Check the pod status:

```bash
kubectl get pod unschedulable-demo -n tutorial-pod-resources
```

It shows `Pending`. Check the events:

```bash
kubectl describe pod unschedulable-demo -n tutorial-pod-resources | grep -A 5 "Events:"
```

You'll see a `FailedScheduling` event with a message like `0/4 nodes are available: 4 Insufficient memory.` This tells you that all four nodes (1 control-plane + 3 workers) were evaluated and none had enough allocatable memory to satisfy the 64Gi request.

The diagnostic workflow for Pending pods is always: `kubectl describe pod` and look at Events. The FailedScheduling message tells you exactly which resource is insufficient and how many nodes were tried.

## Step 8: LimitRange (Namespace Defaults and Bounds)

A LimitRange is a namespace-scoped resource that applies default requests and limits to containers that don't specify their own, and enforces min/max bounds on containers that do.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: tutorial-limits
  namespace: tutorial-pod-resources
spec:
  limits:
  - type: Container
    default:
      cpu: "500m"
      memory: "256Mi"
    defaultRequest:
      cpu: "200m"
      memory: "128Mi"
    max:
      cpu: "2"
      memory: "1Gi"
    min:
      cpu: "50m"
      memory: "32Mi"
EOF
```

This LimitRange says: if a container doesn't specify resources, give it requests of 200m CPU / 128Mi memory and limits of 500m CPU / 256Mi memory. No container may request less than 50m CPU / 32Mi memory or more than 2 CPUs / 1Gi memory.

Now create a pod with no resource fields:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: limitrange-default-demo
  namespace: tutorial-pod-resources
spec:
  containers:
  - name: app
    image: nginx:1.25
EOF
```

```bash
kubectl wait --for=condition=Ready pod/limitrange-default-demo -n tutorial-pod-resources --timeout=60s
```

Check the resources that were injected:

```bash
kubectl get pod limitrange-default-demo -n tutorial-pod-resources \
  -o jsonpath='{.spec.containers[0].resources}'
```

You'll see the default values were applied: `requests.cpu: 200m`, `requests.memory: 128Mi`, `limits.cpu: 500m`, `limits.memory: 256Mi`. The pod didn't declare any resources, but the LimitRange filled them in at admission time.

Now try to create a pod that violates the max:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: limitrange-violation-demo
  namespace: tutorial-pod-resources
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        cpu: "4"
        memory: "2Gi"
      limits:
        cpu: "4"
        memory: "2Gi"
EOF
```

This should fail with an error like: `forbidden: maximum cpu usage per Container is 2, but limit is 4`. The LimitRange rejected the pod at admission because the requested CPU (4 cores) exceeds the max (2 cores).

Check the LimitRange state:

```bash
kubectl describe limitrange tutorial-limits -n tutorial-pod-resources
```

The `maxLimitRequestRatio` field (not set in our example) would constrain the ratio of limit to request for a resource. For example, a ratio of 2 means the limit can be at most 2x the request. This prevents containers from having very low requests (to pass scheduling easily) but very high limits (to burst aggressively).

Delete the LimitRange before continuing so it doesn't interfere with later steps:

```bash
kubectl delete limitrange tutorial-limits -n tutorial-pod-resources
```

## Step 9: ResourceQuota (Namespace-Wide Caps)

A ResourceQuota limits the total resource consumption across all pods in a namespace. While LimitRange controls individual containers, ResourceQuota controls the aggregate.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tutorial-quota
  namespace: tutorial-pod-resources
spec:
  hard:
    requests.cpu: "1"
    requests.memory: "512Mi"
    limits.cpu: "2"
    limits.memory: "1Gi"
    pods: "3"
EOF
```

This quota says: the namespace can contain at most 3 pods, with total CPU requests not exceeding 1 core, total memory requests not exceeding 512Mi, total CPU limits not exceeding 2 cores, and total memory limits not exceeding 1Gi.

**Critical admission rule:** When a ResourceQuota constrains a resource (like `requests.cpu`), every pod created in that namespace MUST explicitly set that resource on every container. If a pod tries to be created without specifying requests or limits for a constrained resource, it will be rejected at admission. Let's demonstrate this.

First, clean up existing pods in the namespace so the quota starts fresh:

```bash
kubectl delete pods --all -n tutorial-pod-resources
```

Now try to create a pod without resource fields:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: quota-no-resources
  namespace: tutorial-pod-resources
spec:
  containers:
  - name: app
    image: nginx:1.25
EOF
```

This fails with an error like: `failed quota: tutorial-quota: must specify limits.cpu, limits.memory, requests.cpu, requests.memory`. The quota requires those fields because it constrains those resources.

Now create a pod with proper resource declarations:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: quota-pod-1
  namespace: tutorial-pod-resources
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        cpu: "200m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "256Mi"
EOF
```

```bash
kubectl wait --for=condition=Ready pod/quota-pod-1 -n tutorial-pod-resources --timeout=60s
```

Check quota usage:

```bash
kubectl describe resourcequota tutorial-quota -n tutorial-pod-resources
```

You'll see the `Used` column now shows `requests.cpu: 200m`, `requests.memory: 128Mi`, etc. Create a second pod:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: quota-pod-2
  namespace: tutorial-pod-resources
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        cpu: "200m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "256Mi"
EOF
```

Now try a third pod that would exceed the CPU request quota:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: quota-pod-3
  namespace: tutorial-pod-resources
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        cpu: "800m"
        memory: "128Mi"
      limits:
        cpu: "1500m"
        memory: "256Mi"
EOF
```

This fails because it would push total `requests.cpu` to 1200m (200 + 200 + 800), exceeding the quota of 1 core (1000m). The error message specifies which resource was exceeded and by how much.

Note that ResourceQuota sums across all pods in the namespace. One pod cannot consume the entire quota if other pods already exist. This is a common source of confusion: you might have enough quota for a pod in isolation, but not when other pods are already consuming quota.

**LimitRange + ResourceQuota together:** In practice, you often use both. The LimitRange provides defaults so developers don't have to remember to set resources on every container. The ResourceQuota provides a ceiling so no single namespace can consume unbounded cluster resources. When both exist, the LimitRange defaults are applied first (filling in missing fields), and then the ResourceQuota admission check runs against the fully-populated pod spec.

## Step 10: Ephemeral Storage

Ephemeral storage covers the writable layer of the container's filesystem, container logs, and emptyDir volumes (unless backed by a medium other than the default). Kubernetes can set requests and limits on ephemeral storage just like CPU and memory.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ephemeral-demo
  namespace: tutorial-pod-resources
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
        ephemeral-storage: "100Mi"
      limits:
        cpu: "200m"
        memory: "128Mi"
        ephemeral-storage: "200Mi"
EOF
```

```bash
kubectl wait --for=condition=Ready pod/ephemeral-demo -n tutorial-pod-resources --timeout=60s
kubectl get pod ephemeral-demo -n tutorial-pod-resources \
  -o jsonpath='{.spec.containers[0].resources.requests.ephemeral-storage}'
```

Ephemeral storage limits work differently from memory limits. When a container exceeds its ephemeral-storage limit, the kubelet evicts the pod (not the kernel OOM killer). This is a pod-level eviction, not a container restart. The eviction shows up as a pod event, and the pod's status shows the eviction reason.

Ephemeral storage matters most when containers write large temporary files, generate extensive logs, or use emptyDir volumes for scratch space. In many cases you won't need to set it, but when you do, being explicit prevents surprise evictions.

## Step 11: In-Place Pod Resize (Brief Overview)

Starting in Kubernetes v1.27 (alpha) and reaching beta in v1.33, Kubernetes supports changing a running pod's CPU and memory resources without recreating the pod. This feature is still evolving, and kind cluster support depends on the Kubernetes version and feature gate configuration.

The concept is straightforward: instead of deleting and recreating a pod to change its resources, you patch the pod's `spec.containers[*].resources` directly:

```bash
# Conceptual example (may not work on all kind clusters)
kubectl patch pod <pod-name> -n <namespace> --subresource resize \
  -p '{"spec":{"containers":[{"name":"app","resources":{"requests":{"cpu":"300m"},"limits":{"cpu":"300m"}}}]}}'
```

The pod's `status.resize` field tracks whether the resize was accepted (`InProgress`, `Proposed`, `Infeasible`). A container's `resources` in the spec shows the desired state, and `status.containerStatuses[*].allocatedResources` shows what was actually granted.

This is a lower-priority topic for CKA prep. The key points are: it exists, it avoids pod recreation, and it requires feature gate support in the cluster. If you want to experiment, check your kind cluster's Kubernetes version with `kubectl version` and consult the Kubernetes documentation for the current state of the feature.

## Cleanup

Remove everything created during the tutorial:

```bash
kubectl delete namespace tutorial-pod-resources
```

This deletes all pods, LimitRanges, and ResourceQuotas in the namespace.

---

## Reference Commands

### Imperative Approaches

```bash
# Create a pod with resource requests and limits
kubectl run my-pod --image=nginx:1.25 \
  --requests='cpu=250m,memory=128Mi' \
  --limits='cpu=500m,memory=256Mi' \
  -n <namespace>

# Update resources on an existing pod (requires recreating the pod in practice)
# kubectl set resources is designed for controllers (Deployments), not bare pods
kubectl set resources deployment <name> \
  --requests='cpu=200m,memory=128Mi' \
  --limits='cpu=400m,memory=256Mi'

# Generate YAML without creating (for customization)
kubectl run my-pod --image=nginx:1.25 \
  --requests='cpu=250m,memory=128Mi' \
  --limits='cpu=500m,memory=256Mi' \
  --dry-run=client -o yaml
```

For anything beyond single-container pods, declarative YAML is the practical path. The imperative `kubectl run` command only creates single-container pods, and `kubectl set resources` targets Deployments, not bare pods.

### Declarative Template

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example
  namespace: example-ns
spec:
  containers:
  - name: main
    image: nginx:1.25
    resources:
      requests:
        cpu: "250m"
        memory: "128Mi"
        ephemeral-storage: "100Mi"
      limits:
        cpu: "500m"
        memory: "256Mi"
        ephemeral-storage: "200Mi"
  - name: sidecar
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
      limits:
        cpu: "200m"
        memory: "128Mi"
```

### Checking Resources and QoS

```bash
# QoS class
kubectl get pod <name> -n <ns> -o jsonpath='{.status.qosClass}'

# All resource fields for first container
kubectl get pod <name> -n <ns> -o jsonpath='{.spec.containers[0].resources}'

# CPU request specifically
kubectl get pod <name> -n <ns> -o jsonpath='{.spec.containers[0].resources.requests.cpu}'

# Check if OOMKilled
kubectl get pod <name> -n <ns> \
  -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'

# Exit code (137 = OOMKilled)
kubectl get pod <name> -n <ns> \
  -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'

# Restart count
kubectl get pod <name> -n <ns> \
  -o jsonpath='{.status.containerStatuses[0].restartCount}'

# ResourceQuota usage
kubectl describe resourcequota <name> -n <ns>

# LimitRange details
kubectl describe limitrange <name> -n <ns>

# Events for a pod (scheduling failures, admission errors)
kubectl describe pod <name> -n <ns> | grep -A 10 "Events:"
```

---

## Resource Units Cheat Sheet

### CPU

| Expression | Millicores | Meaning |
|------------|------------|---------|
| `1` | 1000m | 1 full CPU core |
| `0.5` | 500m | Half a core |
| `500m` | 500m | Half a core |
| `250m` | 250m | Quarter of a core |
| `100m` | 100m | One-tenth of a core |
| `2` | 2000m | 2 full CPU cores |

### Memory

| Expression | Bytes | Notes |
|------------|-------|-------|
| `128Mi` | 134,217,728 (128 x 1,048,576) | Binary mebibyte, preferred |
| `128M` | 128,000,000 (128 x 1,000,000) | Decimal megabyte, ~4.7% less |
| `1Gi` | 1,073,741,824 (1 x 1024^3) | Binary gibibyte, preferred |
| `1G` | 1,000,000,000 (1 x 1000^3) | Decimal gigabyte, ~7.4% less |
| `256Ki` | 262,144 (256 x 1024) | Binary kibibyte |
| `256K` | 256,000 (256 x 1000) | Decimal kilobyte, ~2.4% less |

**Rule of thumb:** Always use Mi and Gi. The decimal equivalents are smaller than they look, and the mismatch has caused real production OOMKills.

---

## QoS Class Decision Table

| QoS Class | Rule | Eviction Priority | When to Use |
|-----------|------|-------------------|-------------|
| **Guaranteed** | Every container has requests == limits for both CPU and memory. No field missing. | Last to be evicted | Critical workloads that must survive node pressure: databases, stateful services, payment processors |
| **Burstable** | At least one container has a request or limit, but the pod doesn't meet the Guaranteed criteria | Evicted after BestEffort | Most workloads: web servers, APIs, background workers that benefit from bursting |
| **BestEffort** | No container has any CPU or memory requests or limits | First to be evicted | Batch jobs, development pods, workloads that are truly disposable |

### Common Gotchas

- Setting only `limits` (no `requests`) produces Guaranteed, because Kubernetes auto-fills `requests` = `limits`.
- Setting `requests` on one resource but not the other (e.g., `requests.cpu` but no `requests.memory`) produces Burstable.
- In a multi-container pod, ALL containers must independently satisfy the Guaranteed criteria. One container without resources makes the whole pod Burstable or BestEffort.

---

## Diagnostic Workflow for Resource Issues

### Pod is Pending

```bash
kubectl describe pod <name> -n <ns>
# Look at Events for FailedScheduling
# Message will say "Insufficient cpu" or "Insufficient memory"
# and report how many nodes were tried
```

**Fix:** Reduce the pod's requests, add nodes, or free capacity by removing other pods.

### Pod is OOMKilled

```bash
# Check the termination reason
kubectl get pod <name> -n <ns> \
  -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
# Should show: OOMKilled

# Check exit code
kubectl get pod <name> -n <ns> \
  -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
# Should show: 137

# Check current memory limit
kubectl get pod <name> -n <ns> \
  -o jsonpath='{.spec.containers[0].resources.limits.memory}'
```

**Fix:** Increase the memory limit to accommodate the container's actual working set, or fix the application's memory leak.

### Pod is Rejected at Admission

The `kubectl apply` or `kubectl create` command itself returns an error. Common causes:

- **LimitRange violation:** Container's request or limit exceeds the LimitRange max or is below the min. Error message names the LimitRange and the violated constraint.
- **ResourceQuota exhausted:** Pod would push the namespace's total usage over the quota. Error message names the quota and shows the exceeded resource.
- **Missing required fields:** ResourceQuota constrains a resource (like `requests.cpu`) but the pod doesn't specify it. Error says `must specify requests.cpu`.

```bash
# Check LimitRange in the namespace
kubectl describe limitrange -n <ns>

# Check ResourceQuota in the namespace
kubectl describe resourcequota -n <ns>
```

### Init Container Resource Accounting

When a pod has init containers, the effective pod requests are calculated as the maximum of: (a) the largest single init container's request for each resource, and (b) the sum of all regular container requests for each resource. The scheduler uses whichever is larger. This means a single init container with a large memory request can increase the pod's effective memory request beyond what the regular containers sum to. Keep this in mind when diagnosing why a pod with seemingly small regular container requests won't schedule.
