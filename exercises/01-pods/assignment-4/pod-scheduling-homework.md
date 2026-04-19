# Pod Scheduling and Placement: Homework Exercises

**Assignment 4 in the CKA Pod Fundamentals Series**
**Reference:** Work through `pod-scheduling-tutorial.md` before attempting these exercises.

---

## Prerequisites

- Multi-node kind cluster running (1 control-plane, 3 workers). See `README.md` for setup.
- CKA course sections S1-S6 completed.
- Assignments 1-3 completed.

## Cluster Verification

Before starting, verify your cluster:

```bash
kubectl get nodes
```

You should see four nodes: `scheduling-lab-control-plane`, `scheduling-lab-worker`, `scheduling-lab-worker2`, and `scheduling-lab-worker3`.

## Global Cleanup (Run Before Starting or After a Failed Session)

If you have leftover labels, taints, or namespaces from a previous attempt, run this to reset:

```bash
# Remove all exercise namespaces
for ns in ex-1-{1,2,3} ex-2-{1,2,3} ex-3-{1,2,3} ex-4-{1,2,3} ex-5-{1,2,3}; do
  kubectl delete namespace "$ns" --ignore-not-found
done

# Remove all exercise node labels (safe to run even if not present)
for node in scheduling-lab-worker scheduling-lab-worker2 scheduling-lab-worker3; do
  kubectl label node "$node" ex-1-1/disktype- ex-1-3/gpu- \
    ex-2-1/zone- ex-2-1/disktype- ex-2-2/dedicated- \
    ex-2-3/tier- ex-2-3/region- \
    ex-3-1/env- ex-3-2/workload- ex-3-3/team- \
    ex-4-1/reserved- ex-4-2/spread-group- ex-4-3/cache-group- \
    ex-5-1/zone- ex-5-1/storage- \
    ex-5-2/pool- \
    ex-5-3/zone- ex-5-3/tier- \
    2>/dev/null || true
done

# Remove all exercise taints
for node in scheduling-lab-worker scheduling-lab-worker2 scheduling-lab-worker3; do
  kubectl taint node "$node" \
    ex-1-3/gpu=true:NoSchedule- \
    ex-2-2/dedicated=ml:NoSchedule- \
    ex-3-2/workload=batch:NoSchedule- \
    ex-4-1/reserved=infra:NoSchedule- \
    ex-5-1/sensitive=true:NoSchedule- \
    ex-5-2/pool=gpu:NoSchedule- \
    ex-5-3/critical=true:NoExecute- \
    2>/dev/null || true
done

# Remove exercise PriorityClasses
kubectl delete priorityclass ex-5-3-low ex-5-3-high 2>/dev/null || true
```

---

## Level 1: Basic Single-Concept Tasks

### Exercise 1.1

**Objective:** Use nodeSelector to place a pod on a specific node based on a custom label.

**Setup:**

```bash
kubectl create namespace ex-1-1
kubectl label nodes scheduling-lab-worker2 ex-1-1/disktype=ssd
```

**Task:**

Create a pod named `ssd-pod` in namespace `ex-1-1` with the following requirements:

- Image: `busybox:1.36`
- Command: `sh -c "echo started; sleep 3600"`
- Must run on a node labeled `ex-1-1/disktype=ssd` using nodeSelector

**Verification:**

```bash
# 1. Pod is Running
kubectl get pod ssd-pod -n ex-1-1

# 2. Pod is on scheduling-lab-worker2
kubectl get pod ssd-pod -n ex-1-1 -o jsonpath='{.spec.nodeName}'
echo

# 3. The target node has the expected label
kubectl get node scheduling-lab-worker2 -o jsonpath='{.metadata.labels.ex-1-1\/disktype}'
echo
```

**Cleanup:**

```bash
kubectl delete namespace ex-1-1
kubectl label nodes scheduling-lab-worker2 ex-1-1/disktype-
```

---

### Exercise 1.2

**Objective:** Use nodeName to bypass the scheduler and place a pod on a specific node.

**Setup:**

```bash
kubectl create namespace ex-1-2
```

**Task:**

Create a pod named `pinned-pod` in namespace `ex-1-2` with the following requirements:

- Image: `busybox:1.36`
- Command: `sh -c "echo started; sleep 3600"`
- Must run on `scheduling-lab-worker3` using nodeName (bypassing the scheduler)

**Verification:**

```bash
# 1. Pod is Running
kubectl get pod pinned-pod -n ex-1-2

# 2. Pod is on scheduling-lab-worker3
kubectl get pod pinned-pod -n ex-1-2 -o jsonpath='{.spec.nodeName}'
echo

# 3. No FailedScheduling events (scheduler was bypassed)
kubectl get events -n ex-1-2 --field-selector reason=FailedScheduling
```

**Cleanup:**

```bash
kubectl delete namespace ex-1-2
```

---

### Exercise 1.3

**Objective:** Use a taint and toleration to allow a pod onto a tainted node.

**Setup:**

```bash
kubectl create namespace ex-1-3
kubectl taint nodes scheduling-lab-worker ex-1-3/gpu=true:NoSchedule
```

**Task:**

Create a pod named `gpu-pod` in namespace `ex-1-3` with the following requirements:

- Image: `busybox:1.36`
- Command: `sh -c "echo started; sleep 3600"`
- Must tolerate the taint `ex-1-3/gpu=true:NoSchedule`
- Must use nodeSelector with `kubernetes.io/hostname: scheduling-lab-worker` to target the tainted node specifically

**Verification:**

```bash
# 1. Pod is Running
kubectl get pod gpu-pod -n ex-1-3

# 2. Pod is on scheduling-lab-worker
kubectl get pod gpu-pod -n ex-1-3 -o jsonpath='{.spec.nodeName}'
echo

# 3. The node has the expected taint
kubectl get node scheduling-lab-worker -o jsonpath='{.spec.taints}' | python3 -m json.tool
```

**Cleanup:**

```bash
kubectl delete namespace ex-1-3
kubectl taint nodes scheduling-lab-worker ex-1-3/gpu=true:NoSchedule-
```

---

## Level 2: Multi-Concept Tasks

### Exercise 2.1

**Objective:** Combine required and preferred node affinity on a single pod to express a complex placement preference.

**Setup:**

```bash
kubectl create namespace ex-2-1
kubectl label nodes scheduling-lab-worker ex-2-1/zone=us-east-1a
kubectl label nodes scheduling-lab-worker2 ex-2-1/zone=us-east-1b
kubectl label nodes scheduling-lab-worker ex-2-1/disktype=ssd
```

**Task:**

Create a pod named `zone-disk-pod` in namespace `ex-2-1` with the following requirements:

- Image: `busybox:1.36`
- Command: `sh -c "echo started; sleep 3600"`
- Required node affinity: the node must have label `ex-2-1/zone` with value in the set `[us-east-1a, us-east-1b]`
- Preferred node affinity (weight 50): the node should have label `ex-2-1/disktype` with value `ssd`

The pod must land on one of the two labeled workers. The scheduler should prefer `scheduling-lab-worker` (which has both the zone label and the disktype label), but `scheduling-lab-worker2` is also acceptable.

**Verification:**

```bash
# 1. Pod is Running
kubectl get pod zone-disk-pod -n ex-2-1

# 2. Pod is on either scheduling-lab-worker or scheduling-lab-worker2
kubectl get pod zone-disk-pod -n ex-2-1 -o jsonpath='{.spec.nodeName}'
echo

# 3. The node has a matching zone label
NODE=$(kubectl get pod zone-disk-pod -n ex-2-1 -o jsonpath='{.spec.nodeName}')
kubectl get node "$NODE" -o jsonpath='{.metadata.labels.ex-2-1\/zone}'
echo

# 4. No FailedScheduling events
kubectl get events -n ex-2-1 --field-selector reason=FailedScheduling

# 5. Required affinity is present in pod spec
kubectl get pod zone-disk-pod -n ex-2-1 -o jsonpath='{.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution}'
echo

# 6. Preferred affinity is present in pod spec
kubectl get pod zone-disk-pod -n ex-2-1 -o jsonpath='{.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution}'
echo
```

**Cleanup:**

```bash
kubectl delete namespace ex-2-1
kubectl label nodes scheduling-lab-worker ex-2-1/zone- ex-2-1/disktype-
kubectl label nodes scheduling-lab-worker2 ex-2-1/zone-
```

---

### Exercise 2.2

**Objective:** Implement the dedicated-node pattern by combining a taint, a toleration, and node affinity to reserve a node for a specific workload.

**Setup:**

```bash
kubectl create namespace ex-2-2
kubectl label nodes scheduling-lab-worker3 ex-2-2/dedicated=ml
kubectl taint nodes scheduling-lab-worker3 ex-2-2/dedicated=ml:NoSchedule
```

**Task:**

Create a pod named `ml-worker` in namespace `ex-2-2` with the following requirements:

- Image: `busybox:1.36`
- Command: `sh -c "echo started; sleep 3600"`
- Must tolerate the taint `ex-2-2/dedicated=ml:NoSchedule`
- Must use required node affinity with operator `Exists` on key `ex-2-2/dedicated` (the pod requires any node that has the `ex-2-2/dedicated` label, regardless of value)

The combination ensures: the pod can only land on the dedicated node (affinity), the taint prevents non-dedicated pods from landing there (taint), and the toleration lets this pod through the taint.

**Verification:**

```bash
# 1. Pod is Running
kubectl get pod ml-worker -n ex-2-2

# 2. Pod is on scheduling-lab-worker3
kubectl get pod ml-worker -n ex-2-2 -o jsonpath='{.spec.nodeName}'
echo

# 3. The node has the taint
kubectl get node scheduling-lab-worker3 -o jsonpath='{.spec.taints}' | python3 -m json.tool

# 4. The node has the label
kubectl get node scheduling-lab-worker3 -o jsonpath='{.metadata.labels.ex-2-2\/dedicated}'
echo

# 5. Toleration is present in pod spec
kubectl get pod ml-worker -n ex-2-2 -o jsonpath='{.spec.tolerations}'
echo
```

**Cleanup:**

```bash
kubectl delete namespace ex-2-2
kubectl label nodes scheduling-lab-worker3 ex-2-2/dedicated-
kubectl taint nodes scheduling-lab-worker3 ex-2-2/dedicated=ml:NoSchedule-
```

---

### Exercise 2.3

**Objective:** Use node affinity with the NotIn and DoesNotExist operators to express exclusion constraints.

**Setup:**

```bash
kubectl create namespace ex-2-3
kubectl label nodes scheduling-lab-worker ex-2-3/tier=frontend
kubectl label nodes scheduling-lab-worker2 ex-2-3/tier=backend
kubectl label nodes scheduling-lab-worker3 ex-2-3/tier=backend
kubectl label nodes scheduling-lab-worker ex-2-3/region=us-west
kubectl label nodes scheduling-lab-worker2 ex-2-3/region=us-east
kubectl label nodes scheduling-lab-worker3 ex-2-3/region=us-east
```

**Task:**

Create a pod named `exclusion-pod` in namespace `ex-2-3` with the following requirements:

- Image: `busybox:1.36`
- Command: `sh -c "echo started; sleep 3600"`
- Required node affinity with two matchExpressions (both must be true):
  1. Key `ex-2-3/tier`, operator `NotIn`, values `[frontend]` (exclude frontend nodes)
  2. Key `ex-2-3/region`, operator `In`, values `[us-east]` (must be in us-east)

Only nodes that are both non-frontend and in us-east should be eligible. Based on the labels above, both `scheduling-lab-worker2` and `scheduling-lab-worker3` qualify.

**Verification:**

```bash
# 1. Pod is Running
kubectl get pod exclusion-pod -n ex-2-3

# 2. Pod is on scheduling-lab-worker2 or scheduling-lab-worker3
kubectl get pod exclusion-pod -n ex-2-3 -o jsonpath='{.spec.nodeName}'
echo

# 3. The node's tier is NOT frontend
NODE=$(kubectl get pod exclusion-pod -n ex-2-3 -o jsonpath='{.spec.nodeName}')
kubectl get node "$NODE" -o jsonpath='{.metadata.labels.ex-2-3\/tier}'
echo

# 4. The node's region IS us-east
kubectl get node "$NODE" -o jsonpath='{.metadata.labels.ex-2-3\/region}'
echo
```

**Cleanup:**

```bash
kubectl delete namespace ex-2-3
for node in scheduling-lab-worker scheduling-lab-worker2 scheduling-lab-worker3; do
  kubectl label node "$node" ex-2-3/tier- ex-2-3/region-
done
```

---

## Level 3: Debugging Broken Configurations

### Exercise 3.1

**Objective:** The setup below creates a node label and a pod. The pod should be Running on the labeled node, but it is stuck in Pending. Diagnose the problem from the FailedScheduling event and fix it so the pod reaches Running state.

**Setup:**

```bash
kubectl create namespace ex-3-1
kubectl label nodes scheduling-lab-worker2 ex-3-1/env=production

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-selector
  namespace: ex-3-1
spec:
  nodeSelector:
    ex-3-1/env: prod
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
EOF
```

**Task:**

The pod `broken-selector` should be Running on the node labeled with `ex-3-1/env`. Diagnose why it is Pending and fix the configuration so it reaches Running state.

**Verification:**

```bash
# 1. Pod is Running
kubectl get pod broken-selector -n ex-3-1

# 2. Pod is on scheduling-lab-worker2
kubectl get pod broken-selector -n ex-3-1 -o jsonpath='{.spec.nodeName}'
echo
```

**Cleanup:**

```bash
kubectl delete namespace ex-3-1
kubectl label nodes scheduling-lab-worker2 ex-3-1/env-
```

---

### Exercise 3.2

**Objective:** The setup below taints a node and creates a pod targeting that node. The pod should be Running but is stuck in Pending. Diagnose the problem and fix it so the pod reaches Running state.

**Setup:**

```bash
kubectl create namespace ex-3-2
kubectl label nodes scheduling-lab-worker3 ex-3-2/workload=batch
kubectl taint nodes scheduling-lab-worker3 ex-3-2/workload=batch:NoSchedule

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-toleration
  namespace: ex-3-2
spec:
  nodeSelector:
    ex-3-2/workload: batch
  tolerations:
    - key: ex-3-2/workload
      operator: Equal
      value: batch
      effect: PreferNoSchedule
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
EOF
```

**Task:**

The pod `broken-toleration` should be Running on the node labeled `ex-3-2/workload=batch`. Diagnose why it is Pending and fix the configuration so it reaches Running state.

**Verification:**

```bash
# 1. Pod is Running
kubectl get pod broken-toleration -n ex-3-2

# 2. Pod is on scheduling-lab-worker3
kubectl get pod broken-toleration -n ex-3-2 -o jsonpath='{.spec.nodeName}'
echo

# 3. The taint is still present on the node (don't remove the taint, fix the pod)
kubectl get node scheduling-lab-worker3 -o jsonpath='{.spec.taints}' | python3 -m json.tool
```

**Cleanup:**

```bash
kubectl delete namespace ex-3-2
kubectl label nodes scheduling-lab-worker3 ex-3-2/workload-
kubectl taint nodes scheduling-lab-worker3 ex-3-2/workload=batch:NoSchedule-
```

---

### Exercise 3.3

**Objective:** The setup below creates three pods intended to spread across three worker nodes using pod anti-affinity, so that no two pods land on the same node. However, the pods are not spreading as expected. Diagnose the problem and fix it so all three pods run on different worker nodes.

**Setup:**

```bash
kubectl create namespace ex-3-3
kubectl label nodes scheduling-lab-worker ex-3-3/team=platform
kubectl label nodes scheduling-lab-worker2 ex-3-3/team=platform
kubectl label nodes scheduling-lab-worker3 ex-3-3/team=platform

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: spread-a
  namespace: ex-3-3
  labels:
    app: ex-3-3-spread
spec:
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 1
          podAffinityTerm:
            labelSelector:
              matchLabels:
                app: ex-3-3-spread
            topologyKey: kubernetes.io/hostname
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: spread-b
  namespace: ex-3-3
  labels:
    app: ex-3-3-spread
spec:
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 1
          podAffinityTerm:
            labelSelector:
              matchLabels:
                app: ex-3-3-spread
            topologyKey: kubernetes.io/hostname
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: spread-c
  namespace: ex-3-3
  labels:
    app: ex-3-3-spread
spec:
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 1
          podAffinityTerm:
            labelSelector:
              matchLabels:
                app: ex-3-3-spread
            topologyKey: kubernetes.io/hostname
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
EOF
```

**Task:**

Check whether all three pods (`spread-a`, `spread-b`, `spread-c`) are on different nodes. If any two share a node, determine what is wrong with the scheduling configuration and fix it so that all three pods are guaranteed to run on separate worker nodes.

**Verification:**

```bash
# 1. All three pods are Running
kubectl get pods -n ex-3-3 -l app=ex-3-3-spread

# 2. All three pods are on different nodes
kubectl get pods -n ex-3-3 -l app=ex-3-3-spread -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.nodeName}{"\n"}{end}'

# 3. Verify by counting unique nodes (should be 3)
kubectl get pods -n ex-3-3 -l app=ex-3-3-spread -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | wc -l
```

**Cleanup:**

```bash
kubectl delete namespace ex-3-3
for node in scheduling-lab-worker scheduling-lab-worker2 scheduling-lab-worker3; do
  kubectl label node "$node" ex-3-3/team-
done
```

---

## Level 4: Complex Real-World Scenarios

### Exercise 4.1

**Objective:** Implement a dedicated infrastructure node. One worker node is reserved exclusively for infrastructure workloads. General application pods must not land there, and infrastructure pods must only run there.

**Setup:**

```bash
kubectl create namespace ex-4-1
kubectl label nodes scheduling-lab-worker ex-4-1/reserved=infra
kubectl taint nodes scheduling-lab-worker ex-4-1/reserved=infra:NoSchedule
```

**Task:**

1. Create a pod named `infra-agent` in namespace `ex-4-1` that runs only on the reserved infrastructure node (`scheduling-lab-worker`). It must tolerate the taint and use node affinity or nodeSelector to target the reserved node. Image: `busybox:1.36`, command: `sh -c "echo started; sleep 3600"`.

2. Create a pod named `app-web` in namespace `ex-4-1` that represents a general application workload. It must NOT have any toleration for the infrastructure taint, and it should be schedulable on any non-reserved worker. Image: `busybox:1.36`, command: `sh -c "echo started; sleep 3600"`.

**Verification:**

```bash
# 1. infra-agent is Running
kubectl get pod infra-agent -n ex-4-1

# 2. infra-agent is on scheduling-lab-worker
kubectl get pod infra-agent -n ex-4-1 -o jsonpath='{.spec.nodeName}'
echo

# 3. app-web is Running
kubectl get pod app-web -n ex-4-1

# 4. app-web is NOT on scheduling-lab-worker (it is on worker2 or worker3)
kubectl get pod app-web -n ex-4-1 -o jsonpath='{.spec.nodeName}'
echo

# 5. scheduling-lab-worker has the taint
kubectl get node scheduling-lab-worker -o jsonpath='{.spec.taints}' | python3 -m json.tool

# 6. scheduling-lab-worker has the label
kubectl get node scheduling-lab-worker -o jsonpath='{.metadata.labels.ex-4-1\/reserved}'
echo

# 7. infra-agent has the toleration in its spec
kubectl get pod infra-agent -n ex-4-1 -o jsonpath='{.spec.tolerations}' | python3 -m json.tool

# 8. app-web does NOT have a toleration for ex-4-1/reserved
kubectl get pod app-web -n ex-4-1 -o jsonpath='{.spec.tolerations}'
echo
```

**Cleanup:**

```bash
kubectl delete namespace ex-4-1
kubectl label nodes scheduling-lab-worker ex-4-1/reserved-
kubectl taint nodes scheduling-lab-worker ex-4-1/reserved=infra:NoSchedule-
```

---

### Exercise 4.2

**Objective:** Use topology spread constraints to distribute three pods evenly across all three worker nodes, with maxSkew of 1.

**Setup:**

```bash
kubectl create namespace ex-4-2
```

**Task:**

Create three pods named `replica-1`, `replica-2`, and `replica-3` in namespace `ex-4-2`. All three pods must:

- Have the label `app: ex-4-2-stateful`
- Image: `busybox:1.36`, command: `sh -c "echo started; sleep 3600"`
- Include a topology spread constraint with:
  - `maxSkew: 1`
  - `topologyKey: kubernetes.io/hostname`
  - `whenUnsatisfiable: DoNotSchedule`
  - `labelSelector` matching `app: ex-4-2-stateful`

Each pod should land on a different worker node.

**Verification:**

```bash
# 1. All three pods are Running
kubectl get pods -n ex-4-2 -l app=ex-4-2-stateful

# 2. All three pods are on different nodes
kubectl get pods -n ex-4-2 -l app=ex-4-2-stateful -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.nodeName}{"\n"}{end}'

# 3. Count unique nodes (should be 3)
kubectl get pods -n ex-4-2 -l app=ex-4-2-stateful -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | wc -l

# 4. Topology spread constraint is present in pod specs
kubectl get pod replica-1 -n ex-4-2 -o jsonpath='{.spec.topologySpreadConstraints}'
echo

# 5. No FailedScheduling events
kubectl get events -n ex-4-2 --field-selector reason=FailedScheduling

# 6. Each pod has the correct label
kubectl get pods -n ex-4-2 -l app=ex-4-2-stateful -o jsonpath='{range .items[*]}{.metadata.name}: {.metadata.labels.app}{"\n"}{end}'

# 7. All pods are in Running phase
kubectl get pods -n ex-4-2 -l app=ex-4-2-stateful -o jsonpath='{range .items[*]}{.metadata.name}: {.status.phase}{"\n"}{end}'

# 8. The pods actually started (check logs)
kubectl logs replica-1 -n ex-4-2
```

**Cleanup:**

```bash
kubectl delete namespace ex-4-2
```

---

### Exercise 4.3

**Objective:** Use pod affinity to co-locate a frontend pod on the same node as an existing cache pod for latency optimization.

**Setup:**

```bash
kubectl create namespace ex-4-3

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: cache-server
  namespace: ex-4-3
  labels:
    app: ex-4-3-cache
    role: cache
spec:
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
EOF
```

Wait for the cache pod to be Running and note which node it is on:

```bash
kubectl get pod cache-server -n ex-4-3 -o wide
```

**Task:**

Create a pod named `frontend-server` in namespace `ex-4-3` with the following requirements:

- Image: `busybox:1.36`, command: `sh -c "echo started; sleep 3600"`
- Must use required pod affinity to co-locate on the same node as any pod with label `app=ex-4-3-cache`
- Use `topologyKey: kubernetes.io/hostname`

The frontend pod must land on the exact same node as the cache pod.

**Verification:**

```bash
# 1. Both pods are Running
kubectl get pods -n ex-4-3

# 2. Both pods are on the same node
CACHE_NODE=$(kubectl get pod cache-server -n ex-4-3 -o jsonpath='{.spec.nodeName}')
FRONT_NODE=$(kubectl get pod frontend-server -n ex-4-3 -o jsonpath='{.spec.nodeName}')
echo "cache: $CACHE_NODE, frontend: $FRONT_NODE"

# 3. Nodes match
[ "$CACHE_NODE" = "$FRONT_NODE" ] && echo "PASS: same node" || echo "FAIL: different nodes"

# 4. Pod affinity is in the frontend spec
kubectl get pod frontend-server -n ex-4-3 -o jsonpath='{.spec.affinity.podAffinity}'
echo

# 5. No FailedScheduling events
kubectl get events -n ex-4-3 --field-selector reason=FailedScheduling

# 6. Cache pod has the correct label
kubectl get pod cache-server -n ex-4-3 -o jsonpath='{.metadata.labels.app}'
echo

# 7. Frontend container started
kubectl logs frontend-server -n ex-4-3

# 8. Cache container started
kubectl logs cache-server -n ex-4-3
```

**Cleanup:**

```bash
kubectl delete namespace ex-4-3
```

---

## Level 5: Advanced Debugging and Comprehensive Tasks

### Exercise 5.1

**Objective:** The setup below creates node labels, a taint, and a pod. The pod is intended to run on the node labeled `ex-5-1/zone=secure` that also has an `ex-5-1/storage=fast` label. The pod is not Running as expected. Find and fix whatever is needed so the pod reaches Running state on the correct node.

**Setup:**

```bash
kubectl create namespace ex-5-1
kubectl label nodes scheduling-lab-worker ex-5-1/zone=public
kubectl label nodes scheduling-lab-worker2 ex-5-1/zone=secure ex-5-1/storage=fast
kubectl label nodes scheduling-lab-worker3 ex-5-1/zone=secure
kubectl taint nodes scheduling-lab-worker2 ex-5-1/sensitive=true:NoSchedule

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: secure-data-pod
  namespace: ex-5-1
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: ex-5-1/zone
                operator: In
                values:
                  - secure
              - key: ex-5-1/storage
                operator: In
                values:
                  - fast
  tolerations:
    - key: ex-5-1/sensitive
      operator: Equal
      value: "true"
      effect: PreferNoSchedule
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
EOF
```

**Task:**

The pod `secure-data-pod` is intended to run on `scheduling-lab-worker2`. Diagnose what is preventing it from being scheduled and fix whatever is needed so it reaches Running state on the correct node.

**Verification:**

```bash
# 1. Pod is Running
kubectl get pod secure-data-pod -n ex-5-1

# 2. Pod is on scheduling-lab-worker2
kubectl get pod secure-data-pod -n ex-5-1 -o jsonpath='{.spec.nodeName}'
echo

# 3. No FailedScheduling events remain
kubectl get events -n ex-5-1 --field-selector reason=FailedScheduling

# 4. The taint is still present on the node
kubectl get node scheduling-lab-worker2 -o jsonpath='{.spec.taints}' | python3 -m json.tool
```

**Cleanup:**

```bash
kubectl delete namespace ex-5-1
kubectl label nodes scheduling-lab-worker ex-5-1/zone-
kubectl label nodes scheduling-lab-worker2 ex-5-1/zone- ex-5-1/storage-
kubectl label nodes scheduling-lab-worker3 ex-5-1/zone-
kubectl taint nodes scheduling-lab-worker2 ex-5-1/sensitive=true:NoSchedule-
```

---

### Exercise 5.2

**Objective:** The setup below creates node configuration and two pods. The intent is that `worker-pod-a` runs on the GPU pool node and `worker-pod-b` runs on a non-GPU node. Neither pod is behaving as expected. Find and fix whatever is needed so both pods reach Running state on the correct nodes.

**Setup:**

```bash
kubectl create namespace ex-5-2
kubectl label nodes scheduling-lab-worker ex-5-2/pool=gpu
kubectl label nodes scheduling-lab-worker2 ex-5-2/pool=general
kubectl label nodes scheduling-lab-worker3 ex-5-2/pool=general
kubectl taint nodes scheduling-lab-worker ex-5-2/pool=gpu:NoSchedule

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: worker-pod-a
  namespace: ex-5-2
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: ex-5-2/pool
                operator: In
                values:
                  - gpu
  tolerations:
    - key: ex-5-2/pool
      operator: Exists
      value: gpu
      effect: NoSchedule
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: worker-pod-b
  namespace: ex-5-2
  labels:
    app: ex-5-2-worker
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app: ex-5-2-worker
          topologyKey: ex-5-2/pool
  nodeSelector:
    ex-5-2/pool: general
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
EOF
```

**Task:**

`worker-pod-a` should be Running on `scheduling-lab-worker` (the GPU pool node). `worker-pod-b` should be Running on either `scheduling-lab-worker2` or `scheduling-lab-worker3` (a general pool node). Diagnose what is preventing correct operation and fix whatever is needed.

**Verification:**

```bash
# 1. worker-pod-a is Running
kubectl get pod worker-pod-a -n ex-5-2

# 2. worker-pod-a is on scheduling-lab-worker
kubectl get pod worker-pod-a -n ex-5-2 -o jsonpath='{.spec.nodeName}'
echo

# 3. worker-pod-b is Running
kubectl get pod worker-pod-b -n ex-5-2

# 4. worker-pod-b is on scheduling-lab-worker2 or scheduling-lab-worker3
kubectl get pod worker-pod-b -n ex-5-2 -o jsonpath='{.spec.nodeName}'
echo

# 5. The taint is still on scheduling-lab-worker
kubectl get node scheduling-lab-worker -o jsonpath='{.spec.taints}' | python3 -m json.tool

# 6. No FailedScheduling events remain
kubectl get events -n ex-5-2 --field-selector reason=FailedScheduling
```

**Cleanup:**

```bash
kubectl delete namespace ex-5-2
kubectl label nodes scheduling-lab-worker ex-5-2/pool-
kubectl label nodes scheduling-lab-worker2 ex-5-2/pool-
kubectl label nodes scheduling-lab-worker3 ex-5-2/pool-
kubectl taint nodes scheduling-lab-worker ex-5-2/pool=gpu:NoSchedule-
```

---

### Exercise 5.3

**Objective:** Build a small production topology from scratch. This exercise has specific requirements for three different types of workloads across the cluster.

**Setup:**

```bash
kubectl create namespace ex-5-3
kubectl label nodes scheduling-lab-worker ex-5-3/zone=zone-a ex-5-3/tier=standard
kubectl label nodes scheduling-lab-worker2 ex-5-3/zone=zone-b ex-5-3/tier=standard
kubectl label nodes scheduling-lab-worker3 ex-5-3/zone=zone-a ex-5-3/tier=premium
kubectl taint nodes scheduling-lab-worker3 ex-5-3/critical=true:NoExecute
```

Create two PriorityClasses:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: ex-5-3-low
value: 100
globalDefault: false
description: "Low priority for exercise 5.3"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: ex-5-3-high
value: 10000
globalDefault: false
description: "High priority for exercise 5.3"
EOF
```

**Task:**

Create three pods in namespace `ex-5-3`:

1. **Pod `system-critical`:** Must run on `scheduling-lab-worker3` (the premium-tier node). It must tolerate the `ex-5-3/critical=true:NoExecute` taint and use node affinity to require `ex-5-3/tier=premium`. Assign it the `ex-5-3-high` priority class. Image: `busybox:1.36`, command: `sh -c "echo started; sleep 3600"`.

2. **Pod `app-zone-a`:** Must run on a node in `ex-5-3/zone=zone-a` but NOT on the premium tier node (since the premium tier is tainted and reserved). Use required node affinity to require `ex-5-3/zone=zone-a` AND `ex-5-3/tier` with value in `[standard]`. Assign it the `ex-5-3-low` priority class. Image: `busybox:1.36`, command: `sh -c "echo started; sleep 3600"`.

3. **Pod `app-zone-b`:** Must run on a node in `ex-5-3/zone=zone-b`. Use required node affinity. Assign it the `ex-5-3-low` priority class. Image: `busybox:1.36`, command: `sh -c "echo started; sleep 3600"`.

The result should be: `system-critical` on worker3, `app-zone-a` on worker (the only standard-tier zone-a node), and `app-zone-b` on worker2 (the only zone-b node).

**Verification:**

```bash
# 1. system-critical is Running
kubectl get pod system-critical -n ex-5-3

# 2. system-critical is on scheduling-lab-worker3
kubectl get pod system-critical -n ex-5-3 -o jsonpath='{.spec.nodeName}'
echo

# 3. system-critical has the high priority class
kubectl get pod system-critical -n ex-5-3 -o jsonpath='{.spec.priorityClassName}'
echo

# 4. system-critical has a toleration for the NoExecute taint
kubectl get pod system-critical -n ex-5-3 -o jsonpath='{.spec.tolerations}' | python3 -m json.tool

# 5. app-zone-a is Running on scheduling-lab-worker
kubectl get pod app-zone-a -n ex-5-3 -o jsonpath='{.spec.nodeName}'
echo

# 6. app-zone-a has the low priority class
kubectl get pod app-zone-a -n ex-5-3 -o jsonpath='{.spec.priorityClassName}'
echo

# 7. app-zone-b is Running on scheduling-lab-worker2
kubectl get pod app-zone-b -n ex-5-3 -o jsonpath='{.spec.nodeName}'
echo

# 8. app-zone-b has the low priority class
kubectl get pod app-zone-b -n ex-5-3 -o jsonpath='{.spec.priorityClassName}'
echo

# 9. No FailedScheduling events
kubectl get events -n ex-5-3 --field-selector reason=FailedScheduling

# 10. All three pods started successfully
kubectl logs system-critical -n ex-5-3
kubectl logs app-zone-a -n ex-5-3
kubectl logs app-zone-b -n ex-5-3

# 11. The taint is still present on worker3
kubectl get node scheduling-lab-worker3 -o jsonpath='{.spec.taints}' | python3 -m json.tool
```

**Cleanup:**

```bash
kubectl delete namespace ex-5-3
kubectl label nodes scheduling-lab-worker ex-5-3/zone- ex-5-3/tier-
kubectl label nodes scheduling-lab-worker2 ex-5-3/zone- ex-5-3/tier-
kubectl label nodes scheduling-lab-worker3 ex-5-3/zone- ex-5-3/tier-
kubectl taint nodes scheduling-lab-worker3 ex-5-3/critical=true:NoExecute-
kubectl delete priorityclass ex-5-3-low ex-5-3-high
```

---

## Final Cleanup

After completing all exercises, remove any remaining resources:

```bash
# Delete all exercise namespaces
for ns in ex-1-{1,2,3} ex-2-{1,2,3} ex-3-{1,2,3} ex-4-{1,2,3} ex-5-{1,2,3}; do
  kubectl delete namespace "$ns" --ignore-not-found
done

# Remove all exercise node labels
for node in scheduling-lab-worker scheduling-lab-worker2 scheduling-lab-worker3; do
  kubectl label node "$node" ex-1-1/disktype- ex-1-3/gpu- \
    ex-2-1/zone- ex-2-1/disktype- ex-2-2/dedicated- \
    ex-2-3/tier- ex-2-3/region- \
    ex-3-1/env- ex-3-2/workload- ex-3-3/team- \
    ex-4-1/reserved- ex-4-2/spread-group- ex-4-3/cache-group- \
    ex-5-1/zone- ex-5-1/storage- \
    ex-5-2/pool- \
    ex-5-3/zone- ex-5-3/tier- \
    2>/dev/null || true
done

# Remove all exercise taints
for node in scheduling-lab-worker scheduling-lab-worker2 scheduling-lab-worker3; do
  kubectl taint node "$node" \
    ex-1-3/gpu=true:NoSchedule- \
    ex-2-2/dedicated=ml:NoSchedule- \
    ex-3-2/workload=batch:NoSchedule- \
    ex-4-1/reserved=infra:NoSchedule- \
    ex-5-1/sensitive=true:NoSchedule- \
    ex-5-2/pool=gpu:NoSchedule- \
    ex-5-3/critical=true:NoExecute- \
    2>/dev/null || true
done

# Remove exercise PriorityClasses
kubectl delete priorityclass ex-5-3-low ex-5-3-high 2>/dev/null || true
```

---

## Key Takeaways

**The scheduler decision flow** proceeds in two phases. First, filtering eliminates nodes that cannot run the pod (taints, nodeSelector, required affinity, insufficient resources). Second, scoring ranks the remaining nodes by desirability (preferred affinity weights, topology spread, resource balance). If no node survives filtering, the pod stays Pending and a FailedScheduling event explains why.

**nodeSelector vs node affinity:** nodeSelector is simpler (exact key-value match only) and is appropriate when you need straightforward placement on labeled nodes. Node affinity adds set-based operators (In, NotIn, Exists, DoesNotExist, Gt, Lt), the ability to express OR conditions via multiple nodeSelectorTerms, and the distinction between required (hard) and preferred (soft) constraints. For the CKA exam, know both, but node affinity covers everything nodeSelector does and more.

**Pod affinity vs node affinity:** Node affinity matches against node labels; pod affinity matches against pod labels and uses a topologyKey to define the scope. Use node affinity when you care about node characteristics (zone, hardware type, tier). Use pod affinity when you care about co-locating with or separating from other pods.

**Taints vs affinity:** Taints repel pods from nodes; tolerations are a pass that lets a pod through. Affinity attracts pods to nodes. Taints work in the opposite direction: they are applied to nodes to keep workloads away, while affinity is applied to pods to pull them toward nodes. The dedicated-node pattern combines both: taint the node (repel general workloads) and add affinity to the dedicated workload (attract it to the node) plus a toleration (let it through the taint).

**Required vs preferred:** Required (hard) constraints cause a pod to stay Pending if unsatisfied. Preferred (soft) constraints influence the scheduler's scoring but never prevent scheduling. Use required when placement on the wrong node would be functionally broken. Use preferred when you have a preference but any node will work in a pinch.

**The dedicated-node pattern** is toleration + node affinity (or nodeSelector). The toleration alone is not sufficient because it allows the pod onto the tainted node but does not prevent it from landing on untainted nodes. The affinity alone is not sufficient because the taint blocks the pod even if the labels match. You need both.

**Topology spread vs pod anti-affinity:** Pod anti-affinity is all-or-nothing per topology domain (no two matching pods in the same domain). Topology spread allows bounded imbalance via maxSkew. Use anti-affinity when strict separation is required. Use topology spread when you want even distribution but can tolerate some imbalance (e.g., 4 pods across 3 nodes is fine as 2-1-1).

**Diagnosing Pending pods:** Always start with `kubectl describe pod` and read the FailedScheduling event. The message tells you the total node count, how many failed each constraint, and what the constraint was. Cross-reference against `kubectl get nodes --show-labels` and `kubectl describe node` to verify node state.
