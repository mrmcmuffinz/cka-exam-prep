# Pod Resources and QoS: Homework Answers

Complete solutions for all 15 exercises. For debugging exercises, the diagnosis is as important as the fix. Pay attention to the diagnostic workflow described for each.

---

## Level 1 Solutions

### Exercise 1.1 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: bare-pod
  namespace: ex-1-1
spec:
  containers:
  - name: app
    image: nginx:1.25
```

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: bare-pod
  namespace: ex-1-1
spec:
  containers:
  - name: app
    image: nginx:1.25
EOF
```

**Expected results:**
- QoS class: `BestEffort`
- Resources: `{}` (empty)

**Why BestEffort?** No container in the pod specifies any CPU or memory requests or limits. With zero resource declarations, Kubernetes assigns BestEffort. This pod gets whatever resources are available and is the first to be evicted under node memory pressure.

---

### Exercise 1.2 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mem-pod
  namespace: ex-1-2
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        memory: "128Mi"
      limits:
        memory: "256Mi"
```

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: mem-pod
  namespace: ex-1-2
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        memory: "128Mi"
      limits:
        memory: "256Mi"
EOF
```

**Expected results:**
- QoS class: `Burstable`
- Memory request: `128Mi`

**Why Burstable?** The pod has at least one resource field set (memory request and limit), but it does not qualify as Guaranteed because CPU requests and limits are missing. Guaranteed requires every container to have both CPU and memory requests and limits with requests == limits. Since CPU is unset, it falls to Burstable.

---

### Exercise 1.3 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cpu-equal
  namespace: ex-1-3
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
```

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: cpu-equal
  namespace: ex-1-3
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

**Expected results:**
- QoS class: `Guaranteed`
- CPU request == CPU limit: `250m`

**Why Guaranteed?** Every container (there is only one) has requests equal to limits for both CPU and memory, with no field missing. All four fields are present and the request values match the limit values for both resources.

---

## Level 2 Solutions

### Exercise 2.1 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: limits-only
  namespace: ex-2-1
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      limits:
        cpu: "500m"
        memory: "256Mi"
```

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: limits-only
  namespace: ex-2-1
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      limits:
        cpu: "500m"
        memory: "256Mi"
EOF
```

**Expected results:**
- QoS class: `Guaranteed`
- CPU request: `500m` (auto-filled from limit)
- Memory request: `256Mi` (auto-filled from limit)

**Why Guaranteed?** When you specify only limits without explicit requests, Kubernetes automatically sets requests equal to limits. After this auto-fill, the pod has requests == limits for both CPU and memory on every container, which satisfies the Guaranteed criteria. This is a useful shortcut, but be aware that it means your request (scheduling reservation) equals your limit (hard cap), so the pod cannot burst above its reserved capacity.

---

### Exercise 2.2 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mixed-qos
  namespace: ex-2-2
spec:
  containers:
  - name: main
    image: nginx:1.25
    resources:
      requests:
        cpu: "200m"
        memory: "128Mi"
      limits:
        cpu: "200m"
        memory: "128Mi"
  - name: helper
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: mixed-qos
  namespace: ex-2-2
spec:
  containers:
  - name: main
    image: nginx:1.25
    resources:
      requests:
        cpu: "200m"
        memory: "128Mi"
      limits:
        cpu: "200m"
        memory: "128Mi"
  - name: helper
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
EOF
```

**Expected results:**
- QoS class: `Burstable`
- Container `main`: has resources (requests == limits)
- Container `helper`: `{}` (no resources)

**Why Burstable, not Guaranteed?** For a pod to be Guaranteed, EVERY container must independently have requests == limits for both CPU and memory. The `main` container satisfies this, but the `helper` container has no resource fields at all. One container with no resources prevents the entire pod from being Guaranteed. The pod is not BestEffort either, because at least one container (main) has resource declarations. So it lands in the middle: Burstable.

This is a critical point for multi-container pods. You cannot achieve Guaranteed QoS unless you set matching requests and limits on every single container in the pod, including sidecars and helpers.

---

### Exercise 2.3 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: triple-resource
  namespace: ex-2-3
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
        ephemeral-storage: "50Mi"
      limits:
        cpu: "200m"
        memory: "128Mi"
        ephemeral-storage: "100Mi"
```

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: triple-resource
  namespace: ex-2-3
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
        ephemeral-storage: "50Mi"
      limits:
        cpu: "200m"
        memory: "128Mi"
        ephemeral-storage: "100Mi"
EOF
```

**Expected results:**
- QoS class: `Burstable`
- CPU request: `100m`
- Memory limit: `128Mi`
- Ephemeral-storage request: `50Mi`
- Ephemeral-storage limit: `100Mi`

**Why Burstable?** QoS class is determined ONLY by CPU and memory, not ephemeral-storage. The CPU request (100m) differs from the CPU limit (200m), and the memory request (64Mi) differs from the memory limit (128Mi). Since requests != limits, the pod cannot be Guaranteed. It has at least one resource field set, so it's not BestEffort. Therefore: Burstable.

Note that ephemeral-storage does not factor into QoS class determination at all. Even if ephemeral-storage requests equaled limits, it would not change the QoS class. Only CPU and memory count.

---

## Level 3 Solutions

### Exercise 3.1 Solution

**Diagnosis:**

```bash
kubectl get pod broken-app -n ex-3-1
# STATUS shows OOMKilled or CrashLoopBackOff

kubectl get pod broken-app -n ex-3-1 \
  -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
# Output: OOMKilled

kubectl get pod broken-app -n ex-3-1 \
  -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
# Output: 137
```

**What's wrong:** The pod runs `stress --vm 1 --vm-bytes 200M`, which attempts to allocate 200MB of memory. The memory limit is only `64Mi` (about 67MB). The container immediately exceeds its memory limit and the kernel OOM killer terminates it. It restarts (default restartPolicy is Always), hits the same limit, gets killed again, and enters CrashLoopBackOff.

**How to diagnose from kubectl:** The `OOMKilled` reason in `lastState.terminated` and exit code 137 are the definitive indicators. Then compare the stress command's `--vm-bytes 200M` against the memory limit of `64Mi` to see the mismatch.

**Fix:** Increase the memory limit to accommodate the 200MB allocation. Adding some headroom, 256Mi is a safe choice. The request should also be raised to reflect actual usage.

```bash
kubectl delete pod broken-app -n ex-3-1

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-app
  namespace: ex-3-1
spec:
  containers:
  - name: worker
    image: polinux/stress:1.0.4
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "200M", "--timeout", "120"]
    resources:
      requests:
        memory: "256Mi"
      limits:
        memory: "256Mi"
EOF
```

The key insight: the memory limit must be larger than the container's actual memory usage. `200M` (decimal megabytes) is approximately 191Mi, so a limit of `256Mi` provides comfortable headroom. Setting the limit to exactly `200M` would technically work but leaves no room for the process's own overhead beyond the stress allocation.

---

### Exercise 3.2 Solution

**Diagnosis:**

When you apply the pod YAML, the error message is immediate:

```
Error from server (Forbidden): ... maximum cpu usage per Container is 1, but limit is 2
```

(Or a similar message about memory: `maximum memory usage per Container is 512Mi, but limit is 1Gi`.)

**What's wrong:** The pod requests `limits.cpu: 2` and `limits.memory: 1Gi`, but the LimitRange `strict-limits` sets `max.cpu: 1` and `max.memory: 512Mi`. Both CPU and memory limits exceed the LimitRange maximum.

**How to diagnose:** The error message from `kubectl apply` names the LimitRange and the violated constraint. You can also check the LimitRange directly:

```bash
kubectl describe limitrange strict-limits -n ex-3-2
```

This shows the max values (cpu: 1, memory: 512Mi) that the pod's limits must not exceed.

**Fix:** Reduce the pod's limits to fit within the LimitRange max. The requests are fine (200m CPU, 128Mi memory are within the min/max range).

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: policy-app
  namespace: ex-3-2
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        cpu: "200m"
        memory: "128Mi"
      limits:
        cpu: "1"
        memory: "512Mi"
EOF
```

The limits are now at the maximum allowed by the LimitRange. You could also set them lower; any value between the min and max (and >= the request) is valid.

---

### Exercise 3.3 Solution

**Diagnosis:**

When you apply the pod YAML, the error message is:

```
Error from server (Forbidden): ... must specify limits.cpu, limits.memory
```

**What's wrong:** The ResourceQuota `team-quota` constrains `limits.cpu` and `limits.memory`. When a quota constrains a resource, every pod created in the namespace MUST explicitly specify that resource. The pod only has `requests` (cpu and memory) but no `limits`. The quota admission controller rejects it because the limits fields are required but missing.

**How to diagnose:** The error message from `kubectl apply` explicitly says `must specify limits.cpu, limits.memory`. Check the quota:

```bash
kubectl describe resourcequota team-quota -n ex-3-3
```

This shows that `limits.cpu` and `limits.memory` are constrained, which means every pod must declare them.

**Fix:** Add limits to the pod spec. The limits must fit within the remaining quota capacity.

```bash
kubectl delete pod team-app -n ex-3-3 --ignore-not-found

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: team-app
  namespace: ex-3-3
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

The added limits (500m CPU, 256Mi memory) are within the quota's hard limits (1 CPU, 512Mi memory). The pod now specifies all four resource fields that the quota requires.

---

## Level 4 Solutions

### Exercise 4.1 Solution

**Part 1: LimitRange**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: ns-limits
  namespace: ex-4-1
spec:
  limits:
  - type: Container
    default:
      cpu: "400m"
      memory: "256Mi"
    defaultRequest:
      cpu: "100m"
      memory: "64Mi"
    max:
      cpu: "1"
      memory: "512Mi"
    min:
      cpu: "50m"
      memory: "32Mi"
EOF
```

**Part 2: ResourceQuota**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ns-quota
  namespace: ex-4-1
spec:
  hard:
    requests.cpu: "1"
    requests.memory: "512Mi"
    limits.cpu: "2"
    limits.memory: "1Gi"
    pods: "4"
EOF
```

**Part 3: Pod with no resources (gets LimitRange defaults)**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: default-pod
  namespace: ex-4-1
spec:
  containers:
  - name: app
    image: nginx:1.25
EOF
```

After creation, check the injected resources:

```bash
kubectl get pod default-pod -n ex-4-1 -o jsonpath='{.spec.containers[0].resources}'
```

Expected: `requests.cpu: 100m, requests.memory: 64Mi, limits.cpu: 400m, limits.memory: 256Mi` (the LimitRange defaults). The QoS class is `Burstable` because requests != limits.

**Part 4: Pod with explicit resources**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: explicit-pod
  namespace: ex-4-1
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

**Part 5: Check quota**

```bash
kubectl describe resourcequota ns-quota -n ex-4-1
```

Used should show:
- `requests.cpu: 300m` (100m + 200m)
- `requests.memory: 192Mi` (64Mi + 128Mi)
- `limits.cpu: 900m` (400m + 500m)
- `limits.memory: 512Mi` (256Mi + 256Mi)
- `pods: 2`

**Part 6: Over-quota pod**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: over-quota-pod
  namespace: ex-4-1
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        cpu: "800m"
        memory: "256Mi"
      limits:
        cpu: "1"
        memory: "512Mi"
EOF
```

This fails because `requests.cpu` would become 300m + 800m = 1100m, exceeding the quota of 1 (1000m). The error message specifies which resource was exceeded.

---

### Exercise 4.2 Solution

The workload requirements translate to:

- Memory request: `400Mi` (steady-state working set, used for scheduling)
- Memory limit: `600Mi` (burst ceiling)
- CPU request: `250m` (steady-state)
- CPU limit: `500m` (burst ceiling)

For a production API server that must survive node pressure, you want a QoS class that provides eviction resistance. Guaranteed is the most protective, but it requires requests == limits, which means no bursting. Burstable with high requests provides a good balance: the pod gets strong scheduling priority and eviction resistance proportional to its request, while retaining the ability to burst.

If you choose the exact values above (requests != limits), the QoS class is `Burstable`. This is the pragmatic choice: the pod can burst to handle load spikes without being hard-capped at steady-state levels.

If you strongly need eviction resistance above all else, you could set requests == limits at the burst values (500m CPU, 600Mi memory), achieving `Guaranteed`. The tradeoff is that you reserve burst-level resources even during steady-state operation, wasting cluster capacity.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: api-server
  namespace: ex-4-2
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        cpu: "250m"
        memory: "400Mi"
      limits:
        cpu: "500m"
        memory: "600Mi"
```

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: api-server
  namespace: ex-4-2
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        cpu: "250m"
        memory: "400Mi"
      limits:
        cpu: "500m"
        memory: "600Mi"
EOF
```

**Expected results:**
- QoS class: `Burstable`
- Memory request: `400Mi` (matches steady-state)
- Memory limit: `600Mi` (accommodates burst)
- CPU request: `250m`
- CPU limit: `500m`

Both the Burstable and Guaranteed approaches are defensible here. The important thing is that the learner can articulate the tradeoff between burst headroom and eviction priority.

---

### Exercise 4.3 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-profile
  namespace: ex-4-3
spec:
  containers:
  - name: web
    image: nginx:1.25
    resources:
      requests:
        cpu: "200m"
        memory: "256Mi"
      limits:
        cpu: "500m"
        memory: "512Mi"
  - name: log-shipper
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    resources:
      requests:
        cpu: "50m"
        memory: "32Mi"
      limits:
        cpu: "100m"
        memory: "64Mi"
```

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: multi-profile
  namespace: ex-4-3
spec:
  containers:
  - name: web
    image: nginx:1.25
    resources:
      requests:
        cpu: "200m"
        memory: "256Mi"
      limits:
        cpu: "500m"
        memory: "512Mi"
  - name: log-shipper
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    resources:
      requests:
        cpu: "50m"
        memory: "32Mi"
      limits:
        cpu: "100m"
        memory: "64Mi"
EOF
```

**Expected results:**
- QoS class: `Burstable`
- Pod total CPU request: 200m + 50m = `250m`
- Pod total memory request: 256Mi + 32Mi = `288Mi`
- Pod total CPU limit: 500m + 100m = `600m`
- Pod total memory limit: 512Mi + 64Mi = `576Mi`

**Why Burstable?** Both containers have resource declarations, so it's not BestEffort. For Guaranteed, every container would need requests == limits for both CPU and memory. Container `web` has requests.cpu (200m) != limits.cpu (500m), and container `log-shipper` has requests.cpu (50m) != limits.cpu (100m). Since no container meets the Guaranteed criteria independently, the pod is Burstable.

The pod's effective resource footprint (what the scheduler reserves) is the sum of all container requests. The ResourceQuota also sums across containers when accounting for a pod's usage. This is why right-sizing each container matters: an over-provisioned sidecar wastes quota and cluster capacity.

---

## Level 5 Solutions

### Exercise 5.1 Solution

**Diagnosis:**

When you try to apply the pod, it fails. To understand why, look at the LimitRange first:

```bash
kubectl describe limitrange team-limits -n ex-5-1
```

The LimitRange has:
- `default.cpu: 2`, `default.memory: 1Gi`
- `max.cpu: 1`, `max.memory: 512Mi`

The default CPU limit (2) exceeds the max CPU (1), and the default memory limit (1Gi) exceeds the max memory (512Mi). When the pod is created without explicit resources, the LimitRange tries to inject the defaults (cpu: 2, memory: 1Gi), but then the same LimitRange's max check rejects those defaults. The result is an admission error like:

```
maximum cpu usage per Container is 1, but limit is 2
```

**What's wrong (two problems):**

1. **LimitRange default > max:** The default limits (cpu: 2, memory: 1Gi) exceed the max bounds (cpu: 1, memory: 512Mi). Defaults that violate max are internally inconsistent and cause every pod without explicit resources to be rejected.
2. **Pod has no resources:** The pod relies on LimitRange defaults, which are broken. Even after fixing the LimitRange, the pod would need to be recreated to pick up the corrected defaults.

**Fix:**

Step 1: Fix the LimitRange so defaults are within max bounds:

```bash
kubectl delete limitrange team-limits -n ex-5-1

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: team-limits
  namespace: ex-5-1
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
      cpu: "1"
      memory: "512Mi"
    min:
      cpu: "50m"
      memory: "32Mi"
EOF
```

Step 2: Delete and recreate the pod so it picks up the corrected defaults:

```bash
kubectl delete pod team-app -n ex-5-1 --ignore-not-found

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: team-app
  namespace: ex-5-1
spec:
  containers:
  - name: app
    image: nginx:1.25
EOF
```

The pod now gets the corrected defaults (requests: 200m/128Mi, limits: 500m/256Mi), which are within the max bounds. The ResourceQuota has room for these values. The pod reaches Running state.

---

### Exercise 5.2 Solution

**Diagnosis:**

Check what the existing pods consume:

```bash
kubectl describe resourcequota dev-quota -n ex-5-2
```

Used values (from existing-1 and existing-2):
- `requests.cpu: 600m` (300m + 300m)
- `requests.memory: 400Mi` (200Mi + 200Mi)
- `limits.cpu: 1200m` (600m + 600m)
- `limits.memory: 800Mi` (400Mi + 400Mi)
- `pods: 2`

The new-app requests:
- `requests.cpu: 500m` (would make total 1100m, exceeds quota of 1000m)
- `limits.cpu: 1` (1000m, would make total 2200m, exceeds quota of 2000m)

**What's wrong:** The new-app's CPU requests and CPU limits both push the namespace over quota. The requests.cpu would become 1100m (quota: 1000m), and the limits.cpu would become 2200m (quota: 2000m).

The error message from `kubectl apply` names the exceeded resources.

**Fix:** Reduce new-app's CPU values to fit within remaining quota capacity:

- Remaining requests.cpu: 1000m - 600m = 400m (new pod must be <= 400m)
- Remaining limits.cpu: 2000m - 1200m = 800m (new pod must be <= 800m)
- Remaining requests.memory: 512Mi - 400Mi = 112Mi (new pod must be <= 112Mi)
- Remaining limits.memory: 1Gi - 800Mi = ~224Mi (new pod must be <= ~224Mi)

```bash
kubectl delete pod new-app -n ex-5-2 --ignore-not-found

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: new-app
  namespace: ex-5-2
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        cpu: "200m"
        memory: "100Mi"
      limits:
        cpu: "400m"
        memory: "200Mi"
EOF
```

These values keep new-app functional with reasonable resources while fitting within the remaining quota capacity. The totals after fixing:
- requests.cpu: 800m (within 1000m)
- requests.memory: 500Mi (within 512Mi)
- limits.cpu: 1600m (within 2000m)
- limits.memory: 1000Mi (within 1Gi)
- pods: 3 (within 4)

---

### Exercise 5.3 Solution

**Part A: LimitRange**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: tenant-limits
  namespace: ex-5-3
spec:
  limits:
  - type: Container
    default:
      cpu: "300m"
      memory: "256Mi"
    defaultRequest:
      cpu: "100m"
      memory: "64Mi"
    max:
      cpu: "2"
      memory: "4Gi"
    min:
      cpu: "25m"
      memory: "16Mi"
EOF
```

**Part A: ResourceQuota**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-quota
  namespace: ex-5-3
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "2Gi"
    limits.cpu: "4"
    limits.memory: "8Gi"
    pods: "10"
EOF
```

**Part B: Three-tier pod**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: three-tier
  namespace: ex-5-3
spec:
  containers:
  - name: frontend
    image: nginx:1.25
    resources:
      requests:
        cpu: "200m"
        memory: "128Mi"
      limits:
        cpu: "400m"
        memory: "256Mi"
  - name: backend
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    resources:
      requests:
        cpu: "500m"
        memory: "512Mi"
      limits:
        cpu: "1"
        memory: "1Gi"
  - name: cache
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    resources:
      requests:
        cpu: "100m"
        memory: "256Mi"
      limits:
        cpu: "200m"
        memory: "512Mi"
```

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: three-tier
  namespace: ex-5-3
spec:
  containers:
  - name: frontend
    image: nginx:1.25
    resources:
      requests:
        cpu: "200m"
        memory: "128Mi"
      limits:
        cpu: "400m"
        memory: "256Mi"
  - name: backend
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    resources:
      requests:
        cpu: "500m"
        memory: "512Mi"
      limits:
        cpu: "1"
        memory: "1Gi"
  - name: cache
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    resources:
      requests:
        cpu: "100m"
        memory: "256Mi"
      limits:
        cpu: "200m"
        memory: "512Mi"
EOF
```

**Verification totals:**
- Total CPU request: 200m + 500m + 100m = 800m (within quota of 2)
- Total memory request: 128Mi + 512Mi + 256Mi = 896Mi (within quota of 2Gi)
- Total CPU limit: 400m + 1000m + 200m = 1600m (within quota of 4)
- Total memory limit: 256Mi + 1Gi + 512Mi = 1792Mi (within quota of 8Gi)
- Pods: 1 (within quota of 10)
- QoS class: `Burstable` (requests != limits across all containers)
- All container limits within LimitRange max (max is cpu: 2, memory: 4Gi)
- All container requests within LimitRange min (min is cpu: 25m, memory: 16Mi)

---

## Common Mistakes

**1. Using decimal units (M, G, K) when binary (Mi, Gi, Ki) was intended.** `128M` is 128,000,000 bytes, while `128Mi` is 134,217,728 bytes. That's a ~4.7% difference. For gigabyte-scale values, the gap grows: `1G` is 1,000,000,000 bytes, while `1Gi` is 1,073,741,824 bytes (a ~7.4% difference). Using `M` when you meant `Mi` means your container gets less memory than you think, which can cause OOMKills that are hard to explain.

**2. Setting limits without requests.** This is perfectly valid. Kubernetes auto-fills requests = limits, creating a Guaranteed pod. But it catches people off guard when they later check the pod spec and see requests they never set. Be explicit about both fields if you want clarity.

**3. Setting requests without limits.** Also valid. Creates a Burstable pod. The container is guaranteed its requested amount at scheduling time but can consume memory up to the node's capacity at runtime. This means one misbehaving container can starve its neighbors. On shared clusters, always set memory limits.

**4. Expecting CPU limits to kill the container.** CPU limits cause throttling, not termination. The container runs slower (gets fewer CPU cycles per scheduling period) but is never killed for using too much CPU. Only memory limits trigger the OOM killer. If your pod is slow but not crashing, CPU throttling is a likely cause.

**5. Missing that Guaranteed requires ALL four fields on EVERY container.** The checklist is: requests.cpu, requests.memory, limits.cpu, limits.memory, all set, all matching (request == limit), on every container in the pod. Missing even one field on one container drops the pod to Burstable.

**6. Configuring LimitRange default > max.** If the default limit for a resource exceeds the max for that resource, every pod without explicit resources will be rejected. The LimitRange injects the default, then the same LimitRange rejects it for exceeding the max. This is an internally inconsistent configuration that Kubernetes does not prevent you from creating.

**7. Creating pods without resources in a quota-constrained namespace.** When a ResourceQuota constrains `requests.cpu` (or any other resource), every pod must specify that resource. A pod without the required field is rejected at admission with a clear error message. The fix is either to add the required fields to the pod or to add a LimitRange that provides defaults.

**8. Forgetting that ResourceQuota sums across all pods.** A single pod's resource values might be small, but if other pods already exist in the namespace, the cumulative usage might exceed the quota. Always check `kubectl describe resourcequota` to see current usage before creating new pods.

**9. Using ephemeral-storage limits without understanding what counts.** Ephemeral storage includes the container's writable layer, its log output (stdout/stderr captured by the container runtime), and any emptyDir volumes. If your container writes large temporary files, generates verbose logs, or uses emptyDir as scratch space, all of that counts against the ephemeral-storage limit. Exceeding it causes pod eviction, not just container restart.

**10. Confusing node allocatable with node capacity.** `kubectl describe node` shows both. Capacity is the raw hardware (or in kind's case, the host's resources). Allocatable is capacity minus system reserves (kubelet, kube-reserved, system-reserved). The scheduler uses allocatable, not capacity. On kind clusters, the difference is usually small, but on production clusters with significant system reserves, the gap matters.

---

## Verification Commands Cheat Sheet

```bash
# QoS class
kubectl get pod <n> -n <ns> -o jsonpath='{.status.qosClass}'

# All resources for a container
kubectl get pod <n> -n <ns> -o jsonpath='{.spec.containers[0].resources}'

# Specific resource values
kubectl get pod <n> -n <ns> -o jsonpath='{.spec.containers[0].resources.requests.cpu}'
kubectl get pod <n> -n <ns> -o jsonpath='{.spec.containers[0].resources.limits.memory}'
kubectl get pod <n> -n <ns> -o jsonpath='{.spec.containers[0].resources.requests.ephemeral-storage}'

# OOMKill detection
kubectl get pod <n> -n <ns> \
  -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
# Expected: OOMKilled

kubectl get pod <n> -n <ns> \
  -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
# Expected: 137

# Restart count
kubectl get pod <n> -n <ns> \
  -o jsonpath='{.status.containerStatuses[0].restartCount}'

# Multi-container resource summary
kubectl get pod <n> -n <ns> \
  -o jsonpath='{range .spec.containers[*]}{.name}: req={.resources.requests} lim={.resources.limits}{"\n"}{end}'

# ResourceQuota usage
kubectl describe resourcequota <n> -n <ns>
# Or for specific values:
kubectl get resourcequota <n> -n <ns> -o jsonpath='{.status.used}'

# LimitRange details
kubectl describe limitrange <n> -n <ns>

# Pod events (scheduling failures, admission errors)
kubectl describe pod <n> -n <ns> | grep -A 10 "Events:"

# Node allocatable resources
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
CPU:.status.allocatable.cpu,\
MEM:.status.allocatable.memory

# Detailed node resource info
kubectl describe node <node-name> | grep -A 6 "Allocatable:"
```
