# Pod Scheduling and Placement: Answer Key

**Assignment 4 in the CKA Pod Fundamentals Series**

---

## Level 1 Solutions

### Exercise 1.1 Solution

Create the pod with a nodeSelector targeting the labeled node:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ssd-pod
  namespace: ex-1-1
spec:
  nodeSelector:
    ex-1-1/disktype: ssd
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f ssd-pod.yaml
```

The pod schedules on `scheduling-lab-worker2` because that is the only node with the label `ex-1-1/disktype=ssd`. nodeSelector performs an exact key-value match: all key-value pairs in the selector must be present on the node.

---

### Exercise 1.2 Solution

Create the pod with nodeName to bypass the scheduler:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pinned-pod
  namespace: ex-1-2
spec:
  nodeName: scheduling-lab-worker3
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f pinned-pod.yaml
```

The pod goes directly to `scheduling-lab-worker3` without scheduler involvement. No FailedScheduling events will appear because the scheduler never evaluated this pod. This is the key behavioral difference from nodeSelector: nodeName binds the pod to the node at the API level. If the node were unreachable, the pod would simply fail with no scheduler diagnostic events.

---

### Exercise 1.3 Solution

Create the pod with both a toleration and a nodeSelector:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
  namespace: ex-1-3
spec:
  nodeSelector:
    kubernetes.io/hostname: scheduling-lab-worker
  tolerations:
    - key: ex-1-3/gpu
      operator: Equal
      value: "true"
      effect: NoSchedule
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f gpu-pod.yaml
```

The toleration allows the pod past the `ex-1-3/gpu=true:NoSchedule` taint, and the nodeSelector directs it to `scheduling-lab-worker`. Without the toleration, the pod would stay Pending with a FailedScheduling event indicating an untolerated taint. Without the nodeSelector, the pod could land on any worker (the toleration allows but does not attract).

---

## Level 2 Solutions

### Exercise 2.1 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: zone-disk-pod
  namespace: ex-2-1
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: ex-2-1/zone
                operator: In
                values:
                  - us-east-1a
                  - us-east-1b
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 50
          preference:
            matchExpressions:
              - key: ex-2-1/disktype
                operator: In
                values:
                  - ssd
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f zone-disk-pod.yaml
```

The required affinity restricts the pod to nodes with `ex-2-1/zone` in `[us-east-1a, us-east-1b]`, which means `scheduling-lab-worker` or `scheduling-lab-worker2`. The preferred affinity with weight 50 gives `scheduling-lab-worker` a scoring bonus because it also has `ex-2-1/disktype=ssd`. The scheduler will likely place the pod on `scheduling-lab-worker`, but `scheduling-lab-worker2` is also a valid outcome (the preference is soft).

The key structural point: `requiredDuringSchedulingIgnoredDuringExecution` and `preferredDuringSchedulingIgnoredDuringExecution` are siblings at the same level under `nodeAffinity`. Required controls filtering, preferred controls scoring.

---

### Exercise 2.2 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ml-worker
  namespace: ex-2-2
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: ex-2-2/dedicated
                operator: Exists
  tolerations:
    - key: ex-2-2/dedicated
      operator: Equal
      value: ml
      effect: NoSchedule
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f ml-worker.yaml
```

This implements the dedicated-node pattern. The `Exists` operator matches any node that has the `ex-2-2/dedicated` label key, regardless of value. Only `scheduling-lab-worker3` has this label. The toleration matches the `ex-2-2/dedicated=ml:NoSchedule` taint on that node. Together, the affinity directs the pod to the dedicated node, and the toleration lets it through the taint.

Note: `operator: Exists` must not have a `values` field. If you accidentally include one, it is silently ignored, which can mask bugs.

---

### Exercise 2.3 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: exclusion-pod
  namespace: ex-2-3
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: ex-2-3/tier
                operator: NotIn
                values:
                  - frontend
              - key: ex-2-3/region
                operator: In
                values:
                  - us-east
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f exclusion-pod.yaml
```

The two matchExpressions are ANDed: both must be true for a node to pass. `scheduling-lab-worker` fails because its tier is `frontend` (NotIn rejects it). `scheduling-lab-worker2` passes (tier=backend, region=us-east). `scheduling-lab-worker3` passes (tier=backend, region=us-east). The control-plane fails due to its taint. The pod lands on either worker2 or worker3.

This demonstrates node anti-affinity through the NotIn operator. You can also achieve label-key-level exclusion with `DoesNotExist`, which would exclude any node that has the key at all.

---

## Level 3 Solutions

### Exercise 3.1 Solution

**The problem:** The nodeSelector specifies `ex-3-1/env: prod`, but the node was labeled with `ex-3-1/env=production`. The label value does not match. The FailedScheduling event will say something like `3 node(s) didn't match Pod's node affinity/selector`.

**Diagnosis:**

```bash
# See the pod is Pending
kubectl get pod broken-selector -n ex-3-1

# Read the FailedScheduling event
kubectl describe pod broken-selector -n ex-3-1

# Check what label the node actually has
kubectl get node scheduling-lab-worker2 -o jsonpath='{.metadata.labels.ex-3-1\/env}'
echo
# Output: production
```

The node has `production`, the pod asks for `prod`. These are not the same string.

**Fix:** Delete the broken pod and recreate it with the correct label value:

```bash
kubectl delete pod broken-selector -n ex-3-1

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-selector
  namespace: ex-3-1
spec:
  nodeSelector:
    ex-3-1/env: production
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
EOF
```

Alternatively, you could change the node label to match the pod's selector (`kubectl label nodes scheduling-lab-worker2 ex-3-1/env=prod --overwrite`), but fixing the pod spec is the cleaner approach since `production` is the intended label value.

---

### Exercise 3.2 Solution

**The problem:** The node has the taint `ex-3-2/workload=batch:NoSchedule`, but the pod's toleration specifies `effect: PreferNoSchedule`. The effect does not match. A toleration must match the taint's effect exactly (or omit the effect field to match all effects). `PreferNoSchedule` does not tolerate `NoSchedule`.

**Diagnosis:**

```bash
# See the pod is Pending
kubectl get pod broken-toleration -n ex-3-2

# Read the FailedScheduling event
kubectl describe pod broken-toleration -n ex-3-2
# The event will mention "1 node(s) had untolerated taint {ex-3-2/workload: batch}"

# Check the taint on the node
kubectl get node scheduling-lab-worker3 -o jsonpath='{.spec.taints}' | python3 -m json.tool
# Shows effect: NoSchedule

# Check the pod's toleration
kubectl get pod broken-toleration -n ex-3-2 -o jsonpath='{.spec.tolerations}' | python3 -m json.tool
# Shows effect: PreferNoSchedule
```

**Fix:** Delete the broken pod and recreate with the correct effect:

```bash
kubectl delete pod broken-toleration -n ex-3-2

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
      effect: NoSchedule
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
EOF
```

---

### Exercise 3.3 Solution

**The problem:** The pods use `preferredDuringSchedulingIgnoredDuringExecution` for pod anti-affinity instead of `requiredDuringSchedulingIgnoredDuringExecution`. Preferred anti-affinity is a soft hint: the scheduler tries to avoid co-locating pods but will do so if it is convenient. With a low weight of 1, the scheduler may ignore the preference entirely and stack pods on the same node. When all three pods are submitted simultaneously (in one YAML), the scheduler processes them quickly and may not enforce the preference strongly.

**Diagnosis:**

```bash
# Check if pods share nodes
kubectl get pods -n ex-3-3 -l app=ex-3-3-spread -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.nodeName}{"\n"}{end}'

# Count unique nodes
kubectl get pods -n ex-3-3 -l app=ex-3-3-spread -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | wc -l
# If less than 3, pods are stacking
```

Note: In some cases, the scheduler may actually spread the pods even with preferred anti-affinity, especially if the cluster is lightly loaded. The issue is that the behavior is not guaranteed. For reliable spread, required anti-affinity is needed.

**Fix:** Delete all three pods and recreate them with `requiredDuringSchedulingIgnoredDuringExecution`:

```bash
kubectl delete pods -n ex-3-3 -l app=ex-3-3-spread

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
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
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
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
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
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app: ex-3-3-spread
          topologyKey: kubernetes.io/hostname
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
EOF
```

All three pods are now guaranteed to land on different nodes.

---

## Level 4 Solutions

### Exercise 4.1 Solution

**Pod 1: infra-agent (dedicated to the reserved node)**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: infra-agent
  namespace: ex-4-1
spec:
  nodeSelector:
    ex-4-1/reserved: infra
  tolerations:
    - key: ex-4-1/reserved
      operator: Equal
      value: infra
      effect: NoSchedule
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

**Pod 2: app-web (general workload, no special scheduling)**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-web
  namespace: ex-4-1
spec:
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f infra-agent.yaml
kubectl apply -f app-web.yaml
```

`infra-agent` runs on `scheduling-lab-worker` because the nodeSelector directs it there and the toleration lets it past the taint. `app-web` has no toleration for the infra taint, so it cannot land on `scheduling-lab-worker`. It schedules on either `scheduling-lab-worker2` or `scheduling-lab-worker3`.

This is the complete dedicated-node pattern: the taint repels general workloads, the label attracts the dedicated workload, and the toleration bridges the taint.

---

### Exercise 4.2 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: replica-1
  namespace: ex-4-2
  labels:
    app: ex-4-2-stateful
spec:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels:
          app: ex-4-2-stateful
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: replica-2
  namespace: ex-4-2
  labels:
    app: ex-4-2-stateful
spec:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels:
          app: ex-4-2-stateful
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: replica-3
  namespace: ex-4-2
  labels:
    app: ex-4-2-stateful
spec:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels:
          app: ex-4-2-stateful
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f replicas.yaml
```

With 3 pods and 3 worker nodes, maxSkew 1 produces a 1-1-1 distribution. Each pod lands on a different worker. The `labelSelector` must match the pods' own labels so the scheduler counts them correctly. The `topologyKey: kubernetes.io/hostname` treats each node as its own topology domain.

Note: `whenUnsatisfiable: DoNotSchedule` makes this a hard constraint. If you used `ScheduleAnyway`, the scheduler would prefer balanced distribution but not guarantee it.

---

### Exercise 4.3 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: frontend-server
  namespace: ex-4-3
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app: ex-4-3-cache
          topologyKey: kubernetes.io/hostname
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f frontend-server.yaml
```

The pod affinity with `topologyKey: kubernetes.io/hostname` means "schedule on a node where there is already a running pod matching `app=ex-4-3-cache`." Since the `cache-server` pod is already running on one of the workers, the `frontend-server` will land on the same node.

The labelSelector matches against pod labels (not node labels). The topologyKey defines "same" as "same value of the `kubernetes.io/hostname` label," which means the same node.

---

## Level 5 Solutions

### Exercise 5.1 Solution

**The problem:** The pod has a toleration for `ex-5-1/sensitive=true` with effect `PreferNoSchedule`, but the actual taint on `scheduling-lab-worker2` has effect `NoSchedule`. The toleration's effect does not match the taint's effect, so the pod cannot schedule on `scheduling-lab-worker2`.

Meanwhile, `scheduling-lab-worker3` also has `ex-5-1/zone=secure` but does not have `ex-5-1/storage=fast`, so the node affinity (which requires both labels) correctly excludes it. The only viable node is `scheduling-lab-worker2`, but the wrong toleration effect blocks it.

**Diagnosis:**

```bash
kubectl describe pod secure-data-pod -n ex-5-1
# FailedScheduling event shows untolerated taint on worker2

kubectl get node scheduling-lab-worker2 -o jsonpath='{.spec.taints}' | python3 -m json.tool
# Effect is NoSchedule

kubectl get pod secure-data-pod -n ex-5-1 -o jsonpath='{.spec.tolerations}' | python3 -m json.tool
# Effect says PreferNoSchedule
```

**Fix:**

```bash
kubectl delete pod secure-data-pod -n ex-5-1

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
      effect: NoSchedule
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
EOF
```

The fix changes the toleration effect from `PreferNoSchedule` to `NoSchedule` to match the actual taint.

---

### Exercise 5.2 Solution

**There are two problems in this setup.**

**Problem 1 (worker-pod-a):** The toleration uses `operator: Exists` but also includes `value: gpu`. When operator is `Exists`, the value field is silently ignored, so this is not technically an error that prevents scheduling. However, the YAML is misleading. In this case, `operator: Exists` actually makes the toleration match any taint with key `ex-5-2/pool` regardless of value, which is fine here since the taint value is `gpu`. The real question is whether `worker-pod-a` can schedule. With `operator: Exists`, it can. But the YAML will cause a validation error in recent Kubernetes versions because specifying a value with Exists is invalid. The fix is to remove the value field.

**Diagnosis for worker-pod-a:**

```bash
kubectl describe pod worker-pod-a -n ex-5-2
# Check if it has a validation error or FailedScheduling event
```

**Problem 2 (worker-pod-b):** The pod anti-affinity uses `topologyKey: ex-5-2/pool`. This topologyKey means "treat nodes with the same value of `ex-5-2/pool` as one topology domain." Since `scheduling-lab-worker2` and `scheduling-lab-worker3` both have `ex-5-2/pool=general`, they are in the same domain. The pod anti-affinity says "do not schedule in a domain where a matching pod already exists." But `worker-pod-b` matches its own labelSelector (`app: ex-5-2-worker`) and is the first pod with that label, so there should not be a conflict from anti-affinity itself.

The deeper issue is that `worker-pod-b` will check for pods matching `app: ex-5-2-worker` in the `general` pool domain. If `worker-pod-b` is the only pod with that label, the anti-affinity is satisfied. But when trying to schedule, it also sees the anti-affinity topologyKey `ex-5-2/pool` and evaluates whether there is a matching pod in the same domain. Since `worker-pod-b` has not been scheduled yet, there is no existing pod to conflict with. The anti-affinity may not cause a problem for a single pod.

The actual issue is more subtle: if `worker-pod-a` fails to schedule due to the invalid `value` field on the `Exists` operator, both pods may be stuck. Even if `worker-pod-a` does schedule, the anti-affinity on `worker-pod-b` with a custom topologyKey is fragile and would fail if a second `ex-5-2-worker` pod were added.

**Fix for worker-pod-a:** Remove the `value` field from the toleration (operator Exists should not have a value):

```bash
kubectl delete pod worker-pod-a -n ex-5-2

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
      effect: NoSchedule
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
EOF
```

**Fix for worker-pod-b:** Remove or simplify the pod anti-affinity. Since the intent is just "schedule on a general node" and the nodeSelector already handles that, the anti-affinity is unnecessary and the custom topologyKey is fragile. Remove it:

```bash
kubectl delete pod worker-pod-b -n ex-5-2

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: worker-pod-b
  namespace: ex-5-2
  labels:
    app: ex-5-2-worker
spec:
  nodeSelector:
    ex-5-2/pool: general
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
EOF
```

If you want to keep the anti-affinity (to prevent multiple worker-pod instances from stacking), fix the topologyKey to use `kubernetes.io/hostname` instead of `ex-5-2/pool`:

```yaml
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app: ex-5-2-worker
          topologyKey: kubernetes.io/hostname
```

---

### Exercise 5.3 Solution

**Pod 1: system-critical**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: system-critical
  namespace: ex-5-3
spec:
  priorityClassName: ex-5-3-high
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: ex-5-3/tier
                operator: In
                values:
                  - premium
  tolerations:
    - key: ex-5-3/critical
      operator: Equal
      value: "true"
      effect: NoExecute
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

This pod targets `scheduling-lab-worker3` (the only premium-tier node), tolerates the NoExecute taint, and runs at high priority. Note: the taint effect is `NoExecute`, which is stricter than `NoSchedule`. The toleration must match `NoExecute` exactly. Without a `tolerationSeconds` field, the pod can remain on the node indefinitely.

**Pod 2: app-zone-a**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-zone-a
  namespace: ex-5-3
spec:
  priorityClassName: ex-5-3-low
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: ex-5-3/zone
                operator: In
                values:
                  - zone-a
              - key: ex-5-3/tier
                operator: In
                values:
                  - standard
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

This pod requires both `zone-a` AND `tier=standard`. `scheduling-lab-worker` has both labels. `scheduling-lab-worker3` has `zone-a` but `tier=premium` (and also the NoExecute taint), so it is excluded by both the affinity and the taint.

**Pod 3: app-zone-b**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-zone-b
  namespace: ex-5-3
spec:
  priorityClassName: ex-5-3-low
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: ex-5-3/zone
                operator: In
                values:
                  - zone-b
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

Only `scheduling-lab-worker2` has `zone-b`.

```bash
kubectl apply -f system-critical.yaml
kubectl apply -f app-zone-a.yaml
kubectl apply -f app-zone-b.yaml
```

Result: `system-critical` on worker3, `app-zone-a` on worker, `app-zone-b` on worker2. Each workload is constrained to exactly one eligible node by the combination of zone labels, tier labels, taints, and priority classes.

---

## Common Mistakes

### Toleration without Node Affinity

Adding a toleration to a pod allows it to schedule on a tainted node, but it does not require the pod to go there. Without a matching nodeSelector or node affinity, the pod could land on any untainted node. This defeats the purpose of the dedicated-node pattern because the workload wanders to general-purpose nodes while the reserved node sits empty.

**Example of the mistake:** A node is tainted with `dedicated=ml:NoSchedule` and labeled `dedicated=ml`. You add a toleration for `dedicated=ml:NoSchedule` to the pod but forget the nodeSelector. The pod schedules on an untainted worker node instead.

### Node Affinity without Toleration

The opposite mistake: using nodeSelector or node affinity to target a tainted node without adding a toleration. The affinity correctly identifies the node, but the taint blocks the pod. The FailedScheduling event will report both "didn't match affinity" for other nodes and "untolerated taint" for the target node.

### Preferred Where Required Was Intended

Using `preferredDuringSchedulingIgnoredDuringExecution` when the placement is actually mandatory. Preferred is a scoring hint; it never prevents scheduling. If the preferred nodes are under load, the pod quietly lands somewhere else. This is especially dangerous with pod anti-affinity: preferred anti-affinity may not spread pods at all when the cluster is lightly loaded and all nodes look equally good to the scorer.

### topologyKey Referencing a Nonexistent Label

If the `topologyKey` in a pod affinity, pod anti-affinity, or topology spread constraint refers to a label that does not exist on any node, the behavior is undefined. For required constraints, no topology domains can be formed, so the constraint cannot be satisfied and the pod stays Pending. For preferred constraints, the rule is silently ignored. This is a subtle bug because the YAML validates successfully and the pod might appear to work (for preferred) while not actually spreading or co-locating at all.

### Operator Exists with a Value Field

When using `operator: Exists` in a matchExpression (node affinity) or in a toleration, the `values` or `value` field is silently ignored. The expression matches any node that has the key. This can be confusing because you might intend to match a specific value but accidentally wrote `Exists` instead of `Equal` or `In`. Recent Kubernetes versions may reject a toleration with both `operator: Exists` and a `value`, but older versions silently ignore the value.

### tolerationSeconds on Non-NoExecute Tolerations

The `tolerationSeconds` field only has meaning when the toleration's effect is `NoExecute`. On `NoSchedule` and `PreferNoSchedule` tolerations, it is silently ignored. This can lead to confusion if you set a tolerationSeconds thinking it creates a timeout for a NoSchedule taint.

### Forgetting the Control-Plane Taint

The control-plane node has a built-in taint `node-role.kubernetes.io/control-plane:NoSchedule`. When reading FailedScheduling messages, one of the "untolerated taint" counts will almost always refer to this taint. This is expected behavior, not a bug. Do not add a toleration for the control-plane taint to your application pods unless you specifically intend to run workloads on the control-plane.

### Misunderstanding IgnoredDuringExecution

The "IgnoredDuringExecution" suffix on both node affinity and pod affinity types means that these rules are evaluated only at scheduling time. Once a pod is running on a node, changing that node's labels or removing pods that satisfied a pod affinity rule will not cause the already-running pod to be evicted or rescheduled. The pod stays where it is until it is deleted.

This means you cannot "fix" a running pod's placement by changing node labels. You must delete and recreate the pod.

### nodeName Failures are Silent

When you use `nodeName` to schedule a pod, the scheduler is completely bypassed. If the named node does not exist, is unreachable, or lacks the resources to run the pod, there will be no FailedScheduling event. The pod will be stuck in Pending with no diagnostic information. Always prefer nodeSelector or node affinity over nodeName for anything beyond debugging.

---

## Verification Commands Cheat Sheet

### Node Inspection

```bash
# All node labels (wide output)
kubectl get nodes --show-labels

# Specific label on one node (escape the / in jsonpath)
kubectl get node <node> -o jsonpath='{.metadata.labels.kubernetes\.io\/hostname}'

# All taints on one node (structured output)
kubectl get node <node> -o jsonpath='{.spec.taints}' | python3 -m json.tool

# Taints across all nodes
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.taints}{"\n"}{end}'

# Node conditions and allocatable resources
kubectl describe node <node> | grep -A10 "Conditions:"
kubectl describe node <node> | grep -A10 "Allocatable:"
```

### Pod Placement

```bash
# Pod status with node placement
kubectl get pods -n <namespace> -o wide

# Node name for a specific pod
kubectl get pod <pod> -n <namespace> -o jsonpath='{.spec.nodeName}'

# Pod labels
kubectl get pod <pod> -n <namespace> -o jsonpath='{.metadata.labels}'

# Pod tolerations
kubectl get pod <pod> -n <namespace> -o jsonpath='{.spec.tolerations}' | python3 -m json.tool

# Pod affinity configuration
kubectl get pod <pod> -n <namespace> -o jsonpath='{.spec.affinity}' | python3 -m json.tool

# Pod priority class and priority value
kubectl get pod <pod> -n <namespace> -o jsonpath='class={.spec.priorityClassName}, value={.spec.priority}'

# Topology spread constraints
kubectl get pod <pod> -n <namespace> -o jsonpath='{.spec.topologySpreadConstraints}' | python3 -m json.tool
```

### Scheduling Events

```bash
# All events for a pod (look at the bottom for scheduling events)
kubectl describe pod <pod> -n <namespace>

# FailedScheduling events only
kubectl get events -n <namespace> --field-selector reason=FailedScheduling

# All events in a namespace, sorted by time
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Multi-Pod Spread Verification

```bash
# Show which node each pod in a label group is on
kubectl get pods -n <namespace> -l <label> -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.nodeName}{"\n"}{end}'

# Count unique nodes (should match pod count for full spread)
kubectl get pods -n <namespace> -l <label> -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | wc -l
```

### Quick Checks

```bash
# Is this pod Pending?
kubectl get pod <pod> -n <namespace> -o jsonpath='{.status.phase}'

# What is the pod's nodeSelector?
kubectl get pod <pod> -n <namespace> -o jsonpath='{.spec.nodeSelector}'

# Does this pod have a nodeName set?
kubectl get pod <pod> -n <namespace> -o jsonpath='{.spec.nodeName}'

# Container started? (check logs)
kubectl logs <pod> -n <namespace>
```
