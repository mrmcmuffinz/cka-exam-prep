# Pod Resources and QoS: Homework Exercises

This file contains 15 exercises covering Kubernetes resource requests, limits, QoS classes, OOMKill behavior, CPU throttling, LimitRange, and ResourceQuota. Work through the tutorial (`pod-resources-qos-tutorial.md`) before attempting these. The tutorial's Reference Commands and Diagnostic Workflow sections are designed to help you while working on exercises.

Each exercise uses its own namespace to prevent LimitRange and ResourceQuota interference. Setup commands are copy-paste ready. For debugging exercises, the broken configuration is provided in the setup; your job is to diagnose and fix it.

## Pre-Flight Checks

Verify your cluster is running and check node capacity:

```bash
# Cluster should be healthy
kubectl get nodes

# Check allocatable resources (you'll need these values for some exercises)
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
CPU:.status.allocatable.cpu,\
MEM:.status.allocatable.memory

# Optional: clean up any leftover namespaces from previous attempts
# kubectl delete namespace -l assignment=pod-resources-qos
```

Note your nodes' allocatable CPU and memory values. Some exercises create pods with deliberately large requests, and the exact values needed depend on your cluster's capacity.

---

## Level 1: Basic Single-Concept Tasks

### Exercise 1.1

**Objective:** Create a pod with no resource declarations and verify its QoS class.

**Setup:**

```bash
kubectl create namespace ex-1-1
```

**Task:**

Create a pod named `bare-pod` in namespace `ex-1-1` using the `nginx:1.25` image. Do not set any CPU or memory requests or limits.

**Verification:**

```bash
# 1. Pod should be Running
kubectl get pod bare-pod -n ex-1-1

# 2. QoS class should be BestEffort
kubectl get pod bare-pod -n ex-1-1 -o jsonpath='{.status.qosClass}'

# 3. Resources field should be empty
kubectl get pod bare-pod -n ex-1-1 -o jsonpath='{.spec.containers[0].resources}'
```

**Cleanup:**

```bash
kubectl delete namespace ex-1-1
```

---

### Exercise 1.2

**Objective:** Create a pod with a memory request and a memory limit, verify its QoS class.

**Setup:**

```bash
kubectl create namespace ex-1-2
```

**Task:**

Create a pod named `mem-pod` in namespace `ex-1-2` using the `nginx:1.25` image. Set a memory request of `128Mi` and a memory limit of `256Mi`. Do not set any CPU requests or limits.

**Verification:**

```bash
# 1. Pod should be Running
kubectl get pod mem-pod -n ex-1-2

# 2. QoS class should be Burstable
kubectl get pod mem-pod -n ex-1-2 -o jsonpath='{.status.qosClass}'

# 3. Memory request should be 128Mi
kubectl get pod mem-pod -n ex-1-2 -o jsonpath='{.spec.containers[0].resources.requests.memory}'
```

**Cleanup:**

```bash
kubectl delete namespace ex-1-2
```

---

### Exercise 1.3

**Objective:** Create a pod with CPU requests and limits where requests equal limits, and verify the resulting QoS class.

**Setup:**

```bash
kubectl create namespace ex-1-3
```

**Task:**

Create a pod named `cpu-equal` in namespace `ex-1-3` using the `nginx:1.25` image. Set CPU request of `250m` and CPU limit of `250m`. Also set memory request of `128Mi` and memory limit of `128Mi`.

**Verification:**

```bash
# 1. Pod should be Running
kubectl get pod cpu-equal -n ex-1-3

# 2. QoS class should be Guaranteed
kubectl get pod cpu-equal -n ex-1-3 -o jsonpath='{.status.qosClass}'

# 3. CPU request should equal CPU limit
kubectl get pod cpu-equal -n ex-1-3 \
  -o jsonpath='request={.spec.containers[0].resources.requests.cpu} limit={.spec.containers[0].resources.limits.cpu}'
```

**Cleanup:**

```bash
kubectl delete namespace ex-1-3
```

---

## Level 2: Multi-Concept Tasks

### Exercise 2.1

**Objective:** Create a pod that achieves Guaranteed QoS using the limits-only shortcut, and verify that Kubernetes auto-populated the requests.

**Setup:**

```bash
kubectl create namespace ex-2-1
```

**Task:**

Create a pod named `limits-only` in namespace `ex-2-1` using the `nginx:1.25` image. Set ONLY limits (no explicit requests): CPU limit of `500m` and memory limit of `256Mi`. After creation, verify that requests were automatically set equal to the limits.

**Verification:**

```bash
# 1. Pod should be Running
kubectl get pod limits-only -n ex-2-1

# 2. QoS class should be Guaranteed
kubectl get pod limits-only -n ex-2-1 -o jsonpath='{.status.qosClass}'

# 3. CPU request should be 500m (auto-filled)
kubectl get pod limits-only -n ex-2-1 -o jsonpath='{.spec.containers[0].resources.requests.cpu}'

# 4. Memory request should be 256Mi (auto-filled)
kubectl get pod limits-only -n ex-2-1 -o jsonpath='{.spec.containers[0].resources.requests.memory}'

# 5. Full resources block showing both requests and limits
kubectl get pod limits-only -n ex-2-1 -o jsonpath='{.spec.containers[0].resources}'
```

**Cleanup:**

```bash
kubectl delete namespace ex-2-1
```

---

### Exercise 2.2

**Objective:** Create a two-container pod and reason about which containers contribute to the pod's QoS class.

**Setup:**

```bash
kubectl create namespace ex-2-2
```

**Task:**

Create a pod named `mixed-qos` in namespace `ex-2-2` with two containers:

- Container `main`: image `nginx:1.25`, requests and limits both set to `cpu: 200m` and `memory: 128Mi` (Guaranteed-eligible by itself)
- Container `helper`: image `busybox:1.36`, command `["sh", "-c", "sleep 3600"]`, no resource fields at all

After creation, check the pod's QoS class and explain which container caused the assignment.

**Verification:**

```bash
# 1. Pod should be Running
kubectl get pod mixed-qos -n ex-2-2

# 2. QoS class (what is it and why?)
kubectl get pod mixed-qos -n ex-2-2 -o jsonpath='{.status.qosClass}'

# 3. Container 'main' has resources
kubectl get pod mixed-qos -n ex-2-2 -o jsonpath='{.spec.containers[0].resources}'

# 4. Container 'helper' has no resources
kubectl get pod mixed-qos -n ex-2-2 -o jsonpath='{.spec.containers[1].resources}'
```

**Cleanup:**

```bash
kubectl delete namespace ex-2-2
```

---

### Exercise 2.3

**Objective:** Create a pod with CPU, memory, AND ephemeral-storage requests and limits.

**Setup:**

```bash
kubectl create namespace ex-2-3
```

**Task:**

Create a pod named `triple-resource` in namespace `ex-2-3` using the `nginx:1.25` image with the following resources:

- CPU: request `100m`, limit `200m`
- Memory: request `64Mi`, limit `128Mi`
- Ephemeral storage: request `50Mi`, limit `100Mi`

Verify all six resource fields are set and check the QoS class.

**Verification:**

```bash
# 1. Pod should be Running
kubectl get pod triple-resource -n ex-2-3

# 2. QoS class
kubectl get pod triple-resource -n ex-2-3 -o jsonpath='{.status.qosClass}'

# 3. CPU request
kubectl get pod triple-resource -n ex-2-3 -o jsonpath='{.spec.containers[0].resources.requests.cpu}'

# 4. Memory limit
kubectl get pod triple-resource -n ex-2-3 -o jsonpath='{.spec.containers[0].resources.limits.memory}'

# 5. Ephemeral-storage request
kubectl get pod triple-resource -n ex-2-3 \
  -o jsonpath='{.spec.containers[0].resources.requests.ephemeral-storage}'

# 6. Ephemeral-storage limit
kubectl get pod triple-resource -n ex-2-3 \
  -o jsonpath='{.spec.containers[0].resources.limits.ephemeral-storage}'
```

**Cleanup:**

```bash
kubectl delete namespace ex-2-3
```

---

## Level 3: Debugging Broken Configurations

### Exercise 3.1

**Objective:** The setup below creates a broken pod. Fix it so it reaches Running state and remains Running with restartCount 0 for at least 60 seconds.

**Setup:**

```bash
kubectl create namespace ex-3-1

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
        memory: "32Mi"
      limits:
        memory: "64Mi"
EOF
```

Wait 15 seconds, then begin diagnosing:

```bash
sleep 15
kubectl get pod broken-app -n ex-3-1
kubectl describe pod broken-app -n ex-3-1
```

**Task:**

Diagnose why the pod is not staying in Running state. Fix the configuration so that the pod runs successfully for at least 60 seconds without restarting. You will need to delete and recreate the pod with corrected values.

**Verification:**

```bash
# 1. Pod should be Running
kubectl get pod broken-app -n ex-3-1

# 2. restartCount should be 0
kubectl get pod broken-app -n ex-3-1 -o jsonpath='{.status.containerStatuses[0].restartCount}'

# 3. Wait 60 seconds and confirm it's still Running with restartCount 0
sleep 60
kubectl get pod broken-app -n ex-3-1
kubectl get pod broken-app -n ex-3-1 -o jsonpath='{.status.containerStatuses[0].restartCount}'
```

**Cleanup:**

```bash
kubectl delete namespace ex-3-1
```

---

### Exercise 3.2

**Objective:** The setup below creates a namespace with a LimitRange and attempts to create a pod. Fix whatever is needed so that the pod is accepted and reaches Running state.

**Setup:**

```bash
kubectl create namespace ex-3-2

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: strict-limits
  namespace: ex-3-2
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
        cpu: "2"
        memory: "1Gi"
EOF
```

**Task:**

If the pod was rejected, read the error message carefully. If the pod was accepted but is in a bad state, diagnose with `kubectl describe`. Fix whatever is wrong so that the pod reaches Running state and complies with the namespace's LimitRange.

**Verification:**

```bash
# 1. Pod should be Running
kubectl get pod policy-app -n ex-3-2

# 2. Pod's resource limits should not exceed the LimitRange max
kubectl get pod policy-app -n ex-3-2 \
  -o jsonpath='cpu-limit={.spec.containers[0].resources.limits.cpu} mem-limit={.spec.containers[0].resources.limits.memory}'

# 3. LimitRange should still be in place
kubectl describe limitrange strict-limits -n ex-3-2
```

**Cleanup:**

```bash
kubectl delete namespace ex-3-2
```

---

### Exercise 3.3

**Objective:** The setup below creates a namespace with a ResourceQuota and attempts to create a pod. Fix whatever is needed so that the pod is accepted and reaches Running state.

**Setup:**

```bash
kubectl create namespace ex-3-3

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: ex-3-3
spec:
  hard:
    requests.cpu: "500m"
    requests.memory: "256Mi"
    limits.cpu: "1"
    limits.memory: "512Mi"
    pods: "5"
EOF

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
EOF
```

**Task:**

If the pod was rejected, read the error message carefully. Fix whatever is needed so the pod is accepted and reaches Running state within the namespace's quota.

**Verification:**

```bash
# 1. Pod should be Running
kubectl get pod team-app -n ex-3-3

# 2. ResourceQuota should show usage
kubectl describe resourcequota team-quota -n ex-3-3

# 3. Pod should have both requests AND limits
kubectl get pod team-app -n ex-3-3 -o jsonpath='{.spec.containers[0].resources}'
```

**Cleanup:**

```bash
kubectl delete namespace ex-3-3
```

---

## Level 4: Complex Real-World Scenarios

### Exercise 4.1

**Objective:** Configure a namespace with both a LimitRange and a ResourceQuota, then deploy pods with and without explicit resource declarations. Verify both the admission behavior and the defaults applied by LimitRange.

**Setup:**

```bash
kubectl create namespace ex-4-1
```

**Task:**

1. Create a LimitRange named `ns-limits` in `ex-4-1` with:
   - Default limits: `cpu: 400m`, `memory: 256Mi`
   - Default requests: `cpu: 100m`, `memory: 64Mi`
   - Max: `cpu: 1`, `memory: 512Mi`
   - Min: `cpu: 50m`, `memory: 32Mi`

2. Create a ResourceQuota named `ns-quota` in `ex-4-1` with:
   - `requests.cpu: 1`
   - `requests.memory: 512Mi`
   - `limits.cpu: 2`
   - `limits.memory: 1Gi`
   - `pods: 4`

3. Create a pod named `default-pod` using `nginx:1.25` with NO resource fields. Verify the LimitRange defaults were injected and the pod was admitted under the quota.

4. Create a pod named `explicit-pod` using `nginx:1.25` with explicit requests `cpu: 200m, memory: 128Mi` and limits `cpu: 500m, memory: 256Mi`. Verify it was admitted.

5. Check the ResourceQuota to see cumulative usage from both pods.

6. Create a pod named `over-quota-pod` using `nginx:1.25` with requests `cpu: 800m, memory: 256Mi` and limits `cpu: 1, memory: 512Mi`. Observe what happens and explain why.

**Verification:**

```bash
# 1. default-pod should be Running with LimitRange defaults
kubectl get pod default-pod -n ex-4-1
kubectl get pod default-pod -n ex-4-1 -o jsonpath='{.spec.containers[0].resources}'

# 2. explicit-pod should be Running
kubectl get pod explicit-pod -n ex-4-1

# 3. ResourceQuota should show usage from both pods
kubectl describe resourcequota ns-quota -n ex-4-1

# 4. default-pod QoS class
kubectl get pod default-pod -n ex-4-1 -o jsonpath='{.status.qosClass}'

# 5. explicit-pod QoS class
kubectl get pod explicit-pod -n ex-4-1 -o jsonpath='{.status.qosClass}'

# 6. over-quota-pod should fail
kubectl get pod over-quota-pod -n ex-4-1 2>/dev/null || echo "Pod does not exist (rejected at admission)"

# 7. ResourceQuota usage should still show only 2 pods
kubectl describe resourcequota ns-quota -n ex-4-1

# 8. Verify LimitRange is still in effect
kubectl describe limitrange ns-limits -n ex-4-1
```

**Cleanup:**

```bash
kubectl delete namespace ex-4-1
```

---

### Exercise 4.2

**Objective:** Size a pod's resources to match a specific workload profile and achieve the appropriate QoS class.

**Setup:**

```bash
kubectl create namespace ex-4-2
```

**Task:**

You are given the following workload requirements:

- The container's steady-state memory working set is approximately 400Mi. Under burst conditions (occasional spikes), it may reach 600Mi.
- The container needs 250m CPU during normal operation and can burst to 500m during peak load.
- The workload is a production API server that should survive node memory pressure events.

Create a pod named `api-server` in namespace `ex-4-2` using the `nginx:1.25` image. Set the requests and limits to match these requirements. Choose the QoS class that best fits a production workload that needs to survive node pressure.

**Verification:**

```bash
# 1. Pod should be Running
kubectl get pod api-server -n ex-4-2

# 2. Memory request should reflect steady-state usage
kubectl get pod api-server -n ex-4-2 -o jsonpath='{.spec.containers[0].resources.requests.memory}'

# 3. Memory limit should accommodate burst
kubectl get pod api-server -n ex-4-2 -o jsonpath='{.spec.containers[0].resources.limits.memory}'

# 4. CPU request should reflect steady-state
kubectl get pod api-server -n ex-4-2 -o jsonpath='{.spec.containers[0].resources.requests.cpu}'

# 5. CPU limit should accommodate burst
kubectl get pod api-server -n ex-4-2 -o jsonpath='{.spec.containers[0].resources.limits.cpu}'

# 6. QoS class should be appropriate for production (what did you choose and why?)
kubectl get pod api-server -n ex-4-2 -o jsonpath='{.status.qosClass}'
```

**Cleanup:**

```bash
kubectl delete namespace ex-4-2
```

---

### Exercise 4.3

**Objective:** Create a multi-container pod with different resource profiles for each container. Verify the pod's effective resource footprint and QoS class.

**Setup:**

```bash
kubectl create namespace ex-4-3
```

**Task:**

Create a pod named `multi-profile` in namespace `ex-4-3` with two containers:

- Container `web` (image `nginx:1.25`): This is the main service. It needs `cpu: 200m, memory: 256Mi` requested, with limits of `cpu: 500m, memory: 512Mi`.
- Container `log-shipper` (image `busybox:1.36`, command `["sh", "-c", "sleep 3600"]`): This is a lightweight helper. It needs `cpu: 50m, memory: 32Mi` requested, with limits of `cpu: 100m, memory: 64Mi`.

After creation, calculate and verify:
- The pod's total CPU request (sum of all containers' CPU requests)
- The pod's total memory request (sum of all containers' memory requests)
- The pod's QoS class

**Verification:**

```bash
# 1. Pod should be Running
kubectl get pod multi-profile -n ex-4-3

# 2. Container 'web' CPU request
kubectl get pod multi-profile -n ex-4-3 -o jsonpath='{.spec.containers[0].resources.requests.cpu}'

# 3. Container 'log-shipper' CPU request
kubectl get pod multi-profile -n ex-4-3 -o jsonpath='{.spec.containers[1].resources.requests.cpu}'

# 4. Container 'web' memory limit
kubectl get pod multi-profile -n ex-4-3 -o jsonpath='{.spec.containers[0].resources.limits.memory}'

# 5. Container 'log-shipper' memory limit
kubectl get pod multi-profile -n ex-4-3 -o jsonpath='{.spec.containers[1].resources.limits.memory}'

# 6. QoS class
kubectl get pod multi-profile -n ex-4-3 -o jsonpath='{.status.qosClass}'

# 7. All resources for all containers
kubectl get pod multi-profile -n ex-4-3 \
  -o jsonpath='{range .spec.containers[*]}{.name}: requests={.resources.requests} limits={.resources.limits}{"\n"}{end}'

# 8. Pod-level effective request = sum of container requests
#    CPU: 200m + 50m = 250m
#    Memory: 256Mi + 32Mi = 288Mi
```

**Cleanup:**

```bash
kubectl delete namespace ex-4-3
```

---

## Level 5: Advanced Debugging and Comprehensive Tasks

### Exercise 5.1

**Objective:** The setup below creates a namespace with a LimitRange, a ResourceQuota, and a pod. The pod is not running. The setup has one or more problems across the LimitRange, ResourceQuota, and pod spec. Find and fix whatever is needed so the pod reaches Running state and complies with the namespace policies.

**Setup:**

```bash
kubectl create namespace ex-5-1

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
      cpu: "2"
      memory: "1Gi"
    defaultRequest:
      cpu: "500m"
      memory: "256Mi"
    max:
      cpu: "1"
      memory: "512Mi"
    min:
      cpu: "50m"
      memory: "32Mi"
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: ex-5-1
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "1Gi"
    limits.cpu: "4"
    limits.memory: "2Gi"
    pods: "5"
EOF

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

**Task:**

Diagnose why the pod cannot be created or is not running. There may be interacting problems between the LimitRange, ResourceQuota, and pod spec. Fix all issues so the pod reaches Running state. The fixed pod should still use LimitRange defaults where appropriate.

**Verification:**

```bash
# 1. LimitRange should be internally consistent (defaults within min/max)
kubectl describe limitrange team-limits -n ex-5-1

# 2. Pod should be Running
kubectl get pod team-app -n ex-5-1

# 3. Pod's resources should comply with LimitRange bounds
kubectl get pod team-app -n ex-5-1 -o jsonpath='{.spec.containers[0].resources}'

# 4. ResourceQuota should show usage
kubectl describe resourcequota team-quota -n ex-5-1

# 5. QoS class
kubectl get pod team-app -n ex-5-1 -o jsonpath='{.status.qosClass}'

# 6. All resource values should be between LimitRange min and max
kubectl get pod team-app -n ex-5-1 \
  -o jsonpath='cpu-req={.spec.containers[0].resources.requests.cpu} cpu-lim={.spec.containers[0].resources.limits.cpu} mem-req={.spec.containers[0].resources.requests.memory} mem-lim={.spec.containers[0].resources.limits.memory}'

# 7. Pod should have no OOMKill or error status
kubectl get pod team-app -n ex-5-1 -o jsonpath='{.status.phase}'

# 8. ResourceQuota used pods should be 1
kubectl get resourcequota team-quota -n ex-5-1 -o jsonpath='{.status.used.pods}'

# 9. No FailedScheduling events
kubectl describe pod team-app -n ex-5-1 | grep -c "FailedScheduling" || true

# 10. LimitRange max should be >= default for all resources
kubectl describe limitrange team-limits -n ex-5-1
```

**Cleanup:**

```bash
kubectl delete namespace ex-5-1
```

---

### Exercise 5.2

**Objective:** The setup below creates a namespace with a ResourceQuota, some existing pods consuming quota, and a new pod that fails. Diagnose all the problems preventing the new pod from running and fix them. The existing pods should remain untouched.

**Setup:**

```bash
kubectl create namespace ex-5-2

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: ex-5-2
spec:
  hard:
    requests.cpu: "1"
    requests.memory: "512Mi"
    limits.cpu: "2"
    limits.memory: "1Gi"
    pods: "4"
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: existing-1
  namespace: ex-5-2
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        cpu: "300m"
        memory: "200Mi"
      limits:
        cpu: "600m"
        memory: "400Mi"
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: existing-2
  namespace: ex-5-2
spec:
  containers:
  - name: app
    image: nginx:1.25
    resources:
      requests:
        cpu: "300m"
        memory: "200Mi"
      limits:
        cpu: "600m"
        memory: "400Mi"
EOF

# Wait for existing pods to be running
kubectl wait --for=condition=Ready pod/existing-1 -n ex-5-2 --timeout=60s
kubectl wait --for=condition=Ready pod/existing-2 -n ex-5-2 --timeout=60s

# Now attempt the new pod
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
        cpu: "500m"
        memory: "200Mi"
      limits:
        cpu: "1"
        memory: "400Mi"
EOF
```

**Task:**

The `new-app` pod cannot be created. Diagnose why, considering the existing pods and the quota. Fix the `new-app` pod spec (not the existing pods or the quota) so it can be admitted and reaches Running state. The fix must keep the pod functional with reasonable resources, not just set everything to zero.

**Verification:**

```bash
# 1. existing-1 and existing-2 should still be Running
kubectl get pods existing-1 existing-2 -n ex-5-2

# 2. new-app should be Running
kubectl get pod new-app -n ex-5-2

# 3. ResourceQuota usage should show 3 pods
kubectl describe resourcequota dev-quota -n ex-5-2

# 4. Total requests.cpu should not exceed 1 (1000m)
kubectl describe resourcequota dev-quota -n ex-5-2

# 5. new-app should have reasonable resources (not zero)
kubectl get pod new-app -n ex-5-2 -o jsonpath='{.spec.containers[0].resources}'

# 6. All three pods should be Running
kubectl get pods -n ex-5-2

# 7. new-app QoS class
kubectl get pod new-app -n ex-5-2 -o jsonpath='{.status.qosClass}'

# 8. Total limits.cpu should not exceed 2 (2000m)
kubectl describe resourcequota dev-quota -n ex-5-2

# 9. Total limits.memory should not exceed 1Gi
kubectl describe resourcequota dev-quota -n ex-5-2

# 10. new-app should have both requests and limits
kubectl get pod new-app -n ex-5-2 -o jsonpath='{.spec.containers[0].resources.requests}'
kubectl get pod new-app -n ex-5-2 -o jsonpath='{.spec.containers[0].resources.limits}'
```

**Cleanup:**

```bash
kubectl delete namespace ex-5-2
```

---

### Exercise 5.3

**Objective:** Configure a complete multi-tenant namespace with resource governance and deploy a three-tier application pod that complies with the policies.

**Setup:**

```bash
kubectl create namespace ex-5-3
```

**Task:**

This exercise has three parts:

**Part A: Namespace Policies**

1. Create a LimitRange named `tenant-limits` in `ex-5-3` with:
   - Default limits: `cpu: 300m`, `memory: 256Mi`
   - Default requests: `cpu: 100m`, `memory: 64Mi`
   - Max per container: `cpu: 2`, `memory: 4Gi`
   - Min per container: `cpu: 25m`, `memory: 16Mi`

2. Create a ResourceQuota named `tenant-quota` in `ex-5-3` with:
   - `requests.cpu: 2`
   - `requests.memory: 2Gi`
   - `limits.cpu: 4`
   - `limits.memory: 8Gi`
   - `pods: 10`

**Part B: Three-Tier Application Pod**

Create a pod named `three-tier` with three containers:

- Container `frontend` (image `nginx:1.25`):
  - Handles user traffic, moderate resource needs
  - CPU: request `200m`, limit `400m`
  - Memory: request `128Mi`, limit `256Mi`

- Container `backend` (image `busybox:1.36`, command `["sh", "-c", "sleep 3600"]`):
  - Handles business logic, heavier resource needs
  - CPU: request `500m`, limit `1`
  - Memory: request `512Mi`, limit `1Gi`

- Container `cache` (image `busybox:1.36`, command `["sh", "-c", "sleep 3600"]`):
  - In-memory cache, needs reliable memory
  - CPU: request `100m`, limit `200m`
  - Memory: request `256Mi`, limit `512Mi`

**Part C: Verification**

After deploying, verify that all containers comply with the LimitRange, the total resource usage fits within the ResourceQuota, and the pod is Running.

**Verification:**

```bash
# 1. LimitRange should be created
kubectl describe limitrange tenant-limits -n ex-5-3

# 2. ResourceQuota should be created
kubectl describe resourcequota tenant-quota -n ex-5-3

# 3. Pod should be Running
kubectl get pod three-tier -n ex-5-3

# 4. QoS class
kubectl get pod three-tier -n ex-5-3 -o jsonpath='{.status.qosClass}'

# 5. Each container's resources
kubectl get pod three-tier -n ex-5-3 \
  -o jsonpath='{range .spec.containers[*]}{.name}: requests={.resources.requests} limits={.resources.limits}{"\n"}{end}'

# 6. Total CPU request (200m + 500m + 100m = 800m, within quota of 2)
# 7. Total memory request (128Mi + 512Mi + 256Mi = 896Mi, within quota of 2Gi)
# 8. Total CPU limit (400m + 1000m + 200m = 1600m, within quota of 4)
# 9. Total memory limit (256Mi + 1Gi + 512Mi = 1792Mi, within quota of 8Gi)
kubectl describe resourcequota tenant-quota -n ex-5-3

# 10. All container limits within LimitRange max (cpu <= 2, memory <= 4Gi)
kubectl get pod three-tier -n ex-5-3 -o jsonpath='{.spec.containers[*].resources.limits}'

# 11. All container requests within LimitRange min (cpu >= 25m, memory >= 16Mi)
kubectl get pod three-tier -n ex-5-3 -o jsonpath='{.spec.containers[*].resources.requests}'

# 12. Pod status should be Running with no restarts
kubectl get pod three-tier -n ex-5-3
```

**Cleanup:**

```bash
kubectl delete namespace ex-5-3
```

---

## Final Cleanup

Remove all exercise namespaces:

```bash
for ns in ex-{1-1,1-2,1-3,2-1,2-2,2-3,3-1,3-2,3-3,4-1,4-2,4-3,5-1,5-2,5-3}; do
  kubectl delete namespace "$ns" --ignore-not-found
done
```

---

## Key Takeaways

**Requests vs. Limits:** Requests are scheduling reservations; they tell the scheduler how much capacity to reserve on a node. Limits are runtime caps enforced by the kernel via cgroups. A pod's requests determine WHERE it runs, and its limits determine what happens when it misbehaves.

**QoS Classes:** Three classes exist, determined entirely by the presence and equality of requests and limits. Guaranteed requires every container to have requests == limits for both CPU and memory, with no field missing. Burstable means at least one container has a request or limit but the pod doesn't qualify as Guaranteed. BestEffort means no container has any requests or limits at all.

**OOMKilled vs. Throttled:** Memory limits are enforced by killing. When a container exceeds its memory limit, the kernel OOM killer terminates the process (exit code 137). CPU limits are enforced by throttling. When a container tries to use more CPU than its limit, the kernel simply gives it fewer cycles per scheduling period. The container runs slower but is never killed for CPU overuse.

**LimitRange and ResourceQuota:** LimitRange operates on individual containers, providing defaults for pods that don't specify resources and enforcing min/max bounds on pods that do. ResourceQuota operates on the entire namespace, capping total resource consumption across all pods. When ResourceQuota constrains a resource, every pod must explicitly declare that resource (or a LimitRange must inject defaults). The two work together: LimitRange fills in the gaps, ResourceQuota enforces the ceiling.

**Admission Flow:** When a pod is created, the admission controllers process it in this order: LimitRange defaults are injected (if any fields are missing), then LimitRange bounds are checked (are the values within min/max?), then ResourceQuota is checked (does the namespace have room?). If any check fails, the pod is rejected before it ever reaches the scheduler.
