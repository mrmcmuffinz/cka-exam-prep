# Workload Autoscaling Homework: 15 Progressive Exercises

These exercises build on the concepts covered in `autoscaling-tutorial.md`. Every exercise depends on a working metrics-server; if `kubectl top nodes` fails, fix that before starting any exercise.

All exercises assume the multi-node kind cluster described in `docs/cluster-setup.md#multi-node-kind-cluster` with metrics-server installed per `docs/cluster-setup.md#metrics-server`:

```bash
kubectl config current-context    # expect: kind-kind
kubectl get nodes                 # expect: 4 nodes, all Ready
kubectl top nodes                 # expect: rows with CPU and MEMORY populated
```

Every exercise uses its own namespace (`ex-1-1`, `ex-1-2`, and so on). HPA scale-decisions involve wait periods; do not interrupt a scale-up or scale-down before it completes or the verification will report intermediate state.

## Global Setup

Create the exercise namespaces:

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 \
          ex-2-1 ex-2-2 ex-2-3 \
          ex-3-1 ex-3-2 ex-3-3 \
          ex-4-1 ex-4-2 ex-4-3 \
          ex-5-1 ex-5-2 ex-5-3; do
  kubectl create namespace $ns
done
```

Each exercise's setup block is self-contained. Read the objective, run the setup, solve the task, then run the verification.

---

## Level 1: HPA Basics

### Exercise 1.1

**Objective:** Create a CPU-based HPA on a Deployment so that replicas scale between 1 and 4 based on observed CPU utilization.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: ex-1-1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
              name: http
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 128Mi
EOF

kubectl rollout status deployment/web -n ex-1-1 --timeout=60s
```

**Task:**

Create an HPA named `web-hpa` in namespace `ex-1-1` targeting the `web` Deployment (`apiVersion: apps/v1`, `kind: Deployment`). Scale between `minReplicas: 1` and `maxReplicas: 4`. Use a single CPU-based Resource metric with target `Utilization` set to 50. Use `apiVersion: autoscaling/v2`.

**Verification:**

```bash
# HPA exists and reports the target utilization:
kubectl get hpa web-hpa -n ex-1-1 \
  -o jsonpath='{.spec.metrics[0].resource.target.averageUtilization}{"\n"}'
# Expected: 50

# Wait for the HPA to see metrics at least once:
sleep 30
kubectl get hpa web-hpa -n ex-1-1 -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}{"\n"}'
# Expected: a non-empty number (the first metric observation; may be very low, e.g. 1 or 2).

# Conditions show AbleToScale: True and ScalingActive: True:
kubectl get hpa web-hpa -n ex-1-1 \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status}{"\n"}{end}'
# Expected: AbleToScale=True and ScalingActive=True among the output lines.
```

---

### Exercise 1.2

**Objective:** Create a memory-based HPA.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cache
  namespace: ex-1-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cache
  template:
    metadata:
      labels:
        app: cache
    spec:
      containers:
        - name: redis
          image: redis:7.2
          ports:
            - containerPort: 6379
              name: redis
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
EOF

kubectl rollout status deployment/cache -n ex-1-2 --timeout=60s
```

**Task:**

Create an HPA named `cache-hpa` in namespace `ex-1-2` targeting the `cache` Deployment, scaling from 1 to 5 replicas based on memory utilization with a target of 70 percent. Use `apiVersion: autoscaling/v2` and a single Resource metric on memory.

**Verification:**

```bash
kubectl get hpa cache-hpa -n ex-1-2 \
  -o jsonpath='{.spec.metrics[0].resource.name}:{.spec.metrics[0].resource.target.type}={.spec.metrics[0].resource.target.averageUtilization}{"\n"}'
# Expected: memory:Utilization=70

sleep 30
kubectl get hpa cache-hpa -n ex-1-2 \
  -o jsonpath='{.status.currentMetrics[0].resource.name}{"\n"}'
# Expected: memory

kubectl get hpa cache-hpa -n ex-1-2 \
  -o jsonpath='{.spec.maxReplicas}{"\n"}'
# Expected: 5
```

---

### Exercise 1.3

**Objective:** Create an HPA with a 120-second scale-down stabilization window so the replica count does not drop within two minutes of a metric dip.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: ex-1-3
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 128Mi
EOF

kubectl rollout status deployment/api -n ex-1-3 --timeout=60s
```

**Task:**

Create an HPA named `api-hpa` in namespace `ex-1-3` targeting the `api` Deployment, scaling from 1 to 6 on 60 percent CPU utilization, with a `spec.behavior.scaleDown.stabilizationWindowSeconds` of 120.

**Verification:**

```bash
kubectl get hpa api-hpa -n ex-1-3 \
  -o jsonpath='{.spec.behavior.scaleDown.stabilizationWindowSeconds}{"\n"}'
# Expected: 120

kubectl get hpa api-hpa -n ex-1-3 \
  -o jsonpath='{.spec.minReplicas}/{.spec.maxReplicas}{"\n"}'
# Expected: 1/6

sleep 30
kubectl get hpa api-hpa -n ex-1-3 \
  -o jsonpath='{.status.conditions[?(@.type=="AbleToScale")].status}{"\n"}'
# Expected: True
```

---

## Level 2: Multi-Concept Tasks

### Exercise 2.1

**Objective:** Create an HPA that targets a StatefulSet instead of a Deployment.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: worker-hdr
  namespace: ex-2-1
spec:
  clusterIP: None
  ports:
    - port: 80
      name: http
  selector:
    app: worker
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: worker
  namespace: ex-2-1
spec:
  serviceName: worker-hdr
  replicas: 1
  selector:
    matchLabels:
      app: worker
  template:
    metadata:
      labels:
        app: worker
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 128Mi
EOF

kubectl rollout status statefulset/worker -n ex-2-1 --timeout=120s
```

**Task:**

Create an HPA named `worker-hpa` in namespace `ex-2-1` targeting the `worker` StatefulSet (`apiVersion: apps/v1`, `kind: StatefulSet`), scaling from 1 to 4 on 50 percent CPU utilization.

**Verification:**

```bash
kubectl get hpa worker-hpa -n ex-2-1 \
  -o jsonpath='{.spec.scaleTargetRef.kind}:{.spec.scaleTargetRef.name}{"\n"}'
# Expected: StatefulSet:worker

sleep 30
kubectl get hpa worker-hpa -n ex-2-1 \
  -o jsonpath='{.status.conditions[?(@.type=="ScalingActive")].status}{"\n"}'
# Expected: True
```

---

### Exercise 2.2

**Objective:** Perform an in-place CPU resize on a running pod without triggering a container restart.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: sizer
  namespace: ex-2-2
spec:
  containers:
    - name: app
      image: nginx:1.27
      resources:
        requests:
          cpu: 100m
          memory: 64Mi
        limits:
          cpu: 500m
          memory: 128Mi
      resizePolicy:
        - resourceName: cpu
          restartPolicy: NotRequired
        - resourceName: memory
          restartPolicy: NotRequired
EOF

kubectl wait --for=condition=Ready pod/sizer -n ex-2-2 --timeout=60s

# Capture the initial restart count
kubectl get pod sizer -n ex-2-2 \
  -o jsonpath='{.status.containerStatuses[0].restartCount}{"\n"}' \
  | tee /tmp/ex-2-2-restarts-before.txt
```

**Task:**

Using the `resize` subresource, patch the `sizer` pod to change `resources.requests.cpu` from `100m` to `250m` and `resources.limits.cpu` from `500m` to `750m`. After the patch, the container must not have restarted.

**Verification:**

```bash
kubectl get pod sizer -n ex-2-2 \
  -o jsonpath='{.spec.containers[0].resources.requests.cpu}{"\n"}'
# Expected: 250m

kubectl get pod sizer -n ex-2-2 \
  -o jsonpath='{.spec.containers[0].resources.limits.cpu}{"\n"}'
# Expected: 750m

# Restart count unchanged from setup:
BEFORE=$(cat /tmp/ex-2-2-restarts-before.txt)
AFTER=$(kubectl get pod sizer -n ex-2-2 \
         -o jsonpath='{.status.containerStatuses[0].restartCount}')
echo "Before: $BEFORE, After: $AFTER"
# Expected: Before: 0, After: 0
```

---

### Exercise 2.3

**Objective:** Configure a pod so that a memory resize triggers a container restart, then prove that the restart happened.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: memsizer
  namespace: ex-2-3
spec:
  containers:
    - name: app
      image: nginx:1.27
      resources:
        requests:
          cpu: 100m
          memory: 64Mi
        limits:
          cpu: 500m
          memory: 128Mi
      resizePolicy:
        - resourceName: cpu
          restartPolicy: NotRequired
        - resourceName: memory
          restartPolicy: RestartContainer
EOF

kubectl wait --for=condition=Ready pod/memsizer -n ex-2-3 --timeout=60s
kubectl get pod memsizer -n ex-2-3 \
  -o jsonpath='{.status.containerStatuses[0].restartCount}{"\n"}' \
  | tee /tmp/ex-2-3-restarts-before.txt
```

**Task:**

Using the `resize` subresource, patch the `memsizer` pod so that `resources.requests.memory` becomes `128Mi` and `resources.limits.memory` becomes `256Mi`. Because `memory` has `restartPolicy: RestartContainer`, the container will restart. Wait for the pod to be Ready again.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/memsizer -n ex-2-3 --timeout=60s

kubectl get pod memsizer -n ex-2-3 \
  -o jsonpath='{.spec.containers[0].resources.requests.memory}{"\n"}'
# Expected: 128Mi

# Restart count incremented by 1:
BEFORE=$(cat /tmp/ex-2-3-restarts-before.txt)
AFTER=$(kubectl get pod memsizer -n ex-2-3 \
         -o jsonpath='{.status.containerStatuses[0].restartCount}')
echo "Before: $BEFORE, After: $AFTER"
# Expected: Before: 0, After: 1
```

---

## Level 3: Debugging

### Exercise 3.1

**Objective:** Make the HPA on the `svc` Deployment scale correctly based on CPU utilization.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: svc
  namespace: ex-3-1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: svc
  template:
    metadata:
      labels:
        app: svc
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: svc-hpa
  namespace: ex-3-1
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: svc
  minReplicas: 1
  maxReplicas: 4
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
EOF

sleep 45
```

**Task:**

After the setup, the HPA's TARGETS column shows `<unknown>/50%` indefinitely and the HPA never scales. Diagnose what is preventing the utilization from being computed, fix the root cause, and wait for the HPA to begin reporting a numeric utilization.

**Verification:**

```bash
sleep 45
kubectl get hpa svc-hpa -n ex-3-1 \
  -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}{"\n"}'
# Expected: a non-empty number (utilization has been computed at least once).

kubectl get hpa svc-hpa -n ex-3-1 \
  -o jsonpath='{.status.conditions[?(@.type=="ScalingActive")].status}={.status.conditions[?(@.type=="ScalingActive")].reason}{"\n"}'
# Expected: True=ValidMetricFound (or similar ScalingActive: True condition).
```

---

### Exercise 3.2

**Objective:** Make the HPA on the `api2` Deployment actually scale.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api2
  namespace: ex-3-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api2
  template:
    metadata:
      labels:
        app: api2
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 128Mi
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api2-hpa
  namespace: ex-3-2
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api2-deployment
  minReplicas: 1
  maxReplicas: 4
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
EOF

sleep 30
```

**Task:**

After the setup, the HPA's `AbleToScale` condition reports `False`. Diagnose why, fix the root cause, and wait for the HPA to reach `AbleToScale: True` and `ScalingActive: True`.

**Verification:**

```bash
sleep 30
kubectl get hpa api2-hpa -n ex-3-2 \
  -o jsonpath='{.status.conditions[?(@.type=="AbleToScale")].status}{"\n"}'
# Expected: True

kubectl get hpa api2-hpa -n ex-3-2 \
  -o jsonpath='{.spec.scaleTargetRef.name}{"\n"}'
# Expected: api2  (matching the existing Deployment's name)
```

---

### Exercise 3.3

**Objective:** Make the HPA on the `load` Deployment actually reach `ScalingActive: True`.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: load
  namespace: ex-3-3
spec:
  replicas: 2
  selector:
    matchLabels:
      app: load
  template:
    metadata:
      labels:
        app: load
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          resources:
            requests:
              memory: 64Mi
            limits:
              memory: 128Mi
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: load-hpa
  namespace: ex-3-3
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: load
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
EOF

sleep 45
```

**Task:**

After the setup, the HPA's TARGETS column shows `<unknown>/50%` and `ScalingActive` is `False`. The underlying issue is subtly different from Exercise 3.1. Diagnose the specific reason, fix it, and wait for the HPA to reach `ScalingActive: True`.

**Verification:**

```bash
kubectl rollout status deployment/load -n ex-3-3 --timeout=60s

sleep 45
kubectl get hpa load-hpa -n ex-3-3 \
  -o jsonpath='{.status.conditions[?(@.type=="ScalingActive")].status}{"\n"}'
# Expected: True

kubectl get hpa load-hpa -n ex-3-3 \
  -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}{"\n"}'
# Expected: a non-empty number.

# Confirm the Deployment's pod template now has cpu requests set:
kubectl get deployment load -n ex-3-3 \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}{"\n"}'
# Expected: a non-empty CPU request (e.g., 100m).
```

---

## Level 4: Complex Real-World Scenarios

### Exercise 4.1

**Objective:** Create a multi-metric HPA that scales on whichever of CPU or memory is most under pressure.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi
  namespace: ex-4-1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: multi
  template:
    metadata:
      labels:
        app: multi
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 128Mi
EOF

kubectl rollout status deployment/multi -n ex-4-1 --timeout=60s
```

**Task:**

Create an HPA named `multi-hpa` in namespace `ex-4-1` targeting the `multi` Deployment with these requirements: scale between 2 and 8 replicas; scale on CPU utilization with target 60 percent; also scale on memory utilization with target 75 percent. Both metrics must be present in the same HPA's `metrics` array.

**Verification:**

```bash
# Exactly two metrics in the spec:
kubectl get hpa multi-hpa -n ex-4-1 \
  -o jsonpath='{range .spec.metrics[*]}{.resource.name}={.resource.target.averageUtilization}{"\n"}{end}'
# Expected two lines:
# cpu=60
# memory=75

kubectl get hpa multi-hpa -n ex-4-1 \
  -o jsonpath='{.spec.minReplicas}/{.spec.maxReplicas}{"\n"}'
# Expected: 2/8

sleep 30
kubectl get hpa multi-hpa -n ex-4-1 \
  -o jsonpath='{range .status.currentMetrics[*]}{.resource.name}{"\n"}{end}'
# Expected: cpu and memory each appearing on their own line (confirming both
# metrics are being observed by the HPA).
```

---

### Exercise 4.2

**Objective:** Write an HPA with aggressive scale-up behavior and conservative scale-down behavior, chosen to match a real-world pattern where bursts must be absorbed quickly but drain-down must be slow.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: burst
  namespace: ex-4-2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: burst
  template:
    metadata:
      labels:
        app: burst
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 128Mi
EOF

kubectl rollout status deployment/burst -n ex-4-2 --timeout=60s
```

**Task:**

Create an HPA named `burst-hpa` in namespace `ex-4-2` targeting the `burst` Deployment with these requirements: 2 to 10 replicas; 50 percent CPU utilization target; `scaleUp` with `stabilizationWindowSeconds: 0` and a policy of 100 percent per 15 seconds (doubling); `scaleDown` with `stabilizationWindowSeconds: 300` and a policy of 10 percent per 60 seconds.

**Verification:**

```bash
kubectl get hpa burst-hpa -n ex-4-2 \
  -o jsonpath='{.spec.behavior.scaleUp.stabilizationWindowSeconds}:{.spec.behavior.scaleUp.policies[0].type}:{.spec.behavior.scaleUp.policies[0].value}:{.spec.behavior.scaleUp.policies[0].periodSeconds}{"\n"}'
# Expected: 0:Percent:100:15

kubectl get hpa burst-hpa -n ex-4-2 \
  -o jsonpath='{.spec.behavior.scaleDown.stabilizationWindowSeconds}:{.spec.behavior.scaleDown.policies[0].type}:{.spec.behavior.scaleDown.policies[0].value}:{.spec.behavior.scaleDown.policies[0].periodSeconds}{"\n"}'
# Expected: 300:Percent:10:60

sleep 30
kubectl get hpa burst-hpa -n ex-4-2 \
  -o jsonpath='{.status.conditions[?(@.type=="ScalingActive")].status}{"\n"}'
# Expected: True
```

---

### Exercise 4.3

**Objective:** Combine HPA with in-place resize: let the HPA grow the replica count under load, then in-place resize one of the existing pods to give it more CPU.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: combo
  namespace: ex-4-3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: combo
  template:
    metadata:
      labels:
        app: combo
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 128Mi
          resizePolicy:
            - resourceName: cpu
              restartPolicy: NotRequired
            - resourceName: memory
              restartPolicy: NotRequired
---
apiVersion: v1
kind: Service
metadata:
  name: combo
  namespace: ex-4-3
spec:
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: combo
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: combo-hpa
  namespace: ex-4-3
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: combo
  minReplicas: 1
  maxReplicas: 4
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
EOF

kubectl rollout status deployment/combo -n ex-4-3 --timeout=60s
```

**Task:**

Starting from `minReplicas: 1`, drive the HPA to scale out to at least 2 replicas by generating load against the `combo` Service from a busybox pod running a tight `wget` loop. Once there are two or more `combo` pods running, pick the lowest-ordinal pod (alphabetically, for example `combo-<hash>-<first>`) and perform an in-place CPU resize on it, changing `requests.cpu` from `100m` to `200m` without restarting the container. Stop the load generator afterward.

**Verification:**

```bash
# Pick the lowest-ordinal pod name:
TARGET=$(kubectl get pods -n ex-4-3 -l app=combo \
           -o jsonpath='{.items[0].metadata.name}')
echo "Target pod: $TARGET"

# That pod has the new CPU request:
kubectl get pod $TARGET -n ex-4-3 \
  -o jsonpath='{.spec.containers[0].resources.requests.cpu}{"\n"}'
# Expected: 200m

# And was not restarted:
kubectl get pod $TARGET -n ex-4-3 \
  -o jsonpath='{.status.containerStatuses[0].restartCount}{"\n"}'
# Expected: 0

# HPA saw the scale-up during the run (currentReplicas >= 2 at some point).
# This check reads the current state; the scale-up event is permanent in Events:
kubectl describe hpa combo-hpa -n ex-4-3 | grep -E 'ScalingReplicaSet|New size' | head -3
# Expected: at least one line referencing a scale-up (New size: 2 or higher).
```

---

## Level 5: Advanced

### Exercise 5.1

**Objective:** Design an HPA that meets an explicit service-level agreement: scale up within 15 seconds when CPU crosses 70 percent utilization, and scale down slowly over 5 minutes when CPU drops below 30 percent.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sla
  namespace: ex-5-1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: sla
  template:
    metadata:
      labels:
        app: sla
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 128Mi
EOF

kubectl rollout status deployment/sla -n ex-5-1 --timeout=60s
```

**Task:**

Create an HPA named `sla-hpa` in namespace `ex-5-1` targeting the `sla` Deployment. Requirements:

- Replica bounds: 3 to 30.
- CPU utilization target: 70 percent.
- Scale-up: no stabilization window; a policy that allows the pod count to at least double per 15 seconds (whichever of `Percent: 100` or `Pods: 4` yields more growth should win, via `selectPolicy: Max`).
- Scale-down: 300-second stabilization window; a single policy of `Percent: 20` per 60 seconds.

**Verification:**

```bash
# Bounds:
kubectl get hpa sla-hpa -n ex-5-1 \
  -o jsonpath='{.spec.minReplicas}/{.spec.maxReplicas}={.spec.metrics[0].resource.target.averageUtilization}{"\n"}'
# Expected: 3/30=70

# Scale-up policies:
kubectl get hpa sla-hpa -n ex-5-1 \
  -o jsonpath='{.spec.behavior.scaleUp.stabilizationWindowSeconds}:{.spec.behavior.scaleUp.selectPolicy}{"\n"}'
# Expected: 0:Max

# Scale-up must include both a Percent and a Pods policy:
kubectl get hpa sla-hpa -n ex-5-1 \
  -o jsonpath='{range .spec.behavior.scaleUp.policies[*]}{.type}={.value}/{.periodSeconds}{"\n"}{end}' \
  | sort
# Expected (sorted, two lines):
# Percent=100/15
# Pods=4/15

# Scale-down window and policy:
kubectl get hpa sla-hpa -n ex-5-1 \
  -o jsonpath='{.spec.behavior.scaleDown.stabilizationWindowSeconds}:{.spec.behavior.scaleDown.policies[0].type}={.spec.behavior.scaleDown.policies[0].value}/{.spec.behavior.scaleDown.policies[0].periodSeconds}{"\n"}'
# Expected: 300:Percent=20/60
```

---

### Exercise 5.2

**Objective:** Stop the HPA on the `flap` Deployment from flapping between its minimum and maximum replica counts.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flap
  namespace: ex-5-2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: flap
  template:
    metadata:
      labels:
        app: flap
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 128Mi
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: flap-hpa
  namespace: ex-5-2
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: flap
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0
    scaleDown:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
EOF

kubectl rollout status deployment/flap -n ex-5-2 --timeout=60s
```

**Task:**

The HPA above has a `scaleDown` configuration that will cause flapping under any oscillating load: zero stabilization window, and a policy that allows removing 100 percent of pods (all of them, down to `minReplicas`) in a single 15-second window. Combined with zero-window scale-up, a workload whose load swings above and below 50 percent every 30 to 60 seconds will cause the replica count to oscillate between `minReplicas` and `maxReplicas`.

Modify the `flap-hpa` so that scale-down is conservative: a stabilization window of at least 180 seconds, and a scale-down policy that removes at most 10 percent per 60 seconds. Leave scale-up as-is (zero stabilization; default policy is fine).

**Verification:**

```bash
kubectl get hpa flap-hpa -n ex-5-2 \
  -o jsonpath='{.spec.behavior.scaleDown.stabilizationWindowSeconds}{"\n"}'
# Expected: 180 or larger.

kubectl get hpa flap-hpa -n ex-5-2 \
  -o jsonpath='{.spec.behavior.scaleDown.policies[0].type}={.spec.behavior.scaleDown.policies[0].value}/{.spec.behavior.scaleDown.policies[0].periodSeconds}{"\n"}'
# Expected: Percent=10/60

# Scale-up stabilization remains 0:
kubectl get hpa flap-hpa -n ex-5-2 \
  -o jsonpath='{.spec.behavior.scaleUp.stabilizationWindowSeconds}{"\n"}'
# Expected: 0
```

---

### Exercise 5.3

**Objective:** Author a valid VerticalPodAutoscaler object for the `vpa-target` Deployment that records recommendations without applying them. Do not install the VPA controller; this exercise validates the YAML by `kubectl apply --dry-run=client` against the object.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vpa-target
  namespace: ex-5-3
spec:
  replicas: 2
  selector:
    matchLabels:
      app: vpa-target
  template:
    metadata:
      labels:
        app: vpa-target
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 128Mi
EOF

kubectl rollout status deployment/vpa-target -n ex-5-3 --timeout=60s
```

**Task:**

Create a YAML file `/tmp/ex-5-3-vpa.yaml` containing a `VerticalPodAutoscaler` object with:

- `apiVersion: autoscaling.k8s.io/v1`
- `kind: VerticalPodAutoscaler`
- `metadata.name: vpa-target-vpa`
- `metadata.namespace: ex-5-3`
- `spec.targetRef` pointing at the `vpa-target` Deployment (`apiVersion: apps/v1`, `kind: Deployment`, `name: vpa-target`)
- `spec.updatePolicy.updateMode: "Off"` (observe only, do not apply)
- `spec.resourcePolicy.containerPolicies[0]` with `containerName: "*"`, `minAllowed.cpu: 50m`, `minAllowed.memory: 64Mi`, `maxAllowed.cpu: 2`, `maxAllowed.memory: 1Gi`, `controlledResources: ["cpu", "memory"]`

Verify the YAML is syntactically valid by using `kubectl apply --dry-run=client -f /tmp/ex-5-3-vpa.yaml --validate=false` (the `--validate=false` is needed because the VPA CRD is not installed in the cluster).

**Verification:**

```bash
test -f /tmp/ex-5-3-vpa.yaml && echo "file exists" || echo "file missing"
# Expected: file exists

# Client-side structural validation (does not require VPA CRD):
kubectl apply --dry-run=client --validate=false -f /tmp/ex-5-3-vpa.yaml \
  | head -3
# Expected: a line reading "verticalpodautoscaler.autoscaling.k8s.io/vpa-target-vpa created (dry run)"

# Key fields are present (four separate checks, each prints the matching line):
grep 'apiVersion: autoscaling.k8s.io/v1' /tmp/ex-5-3-vpa.yaml
# Expected: apiVersion: autoscaling.k8s.io/v1

grep 'kind: VerticalPodAutoscaler' /tmp/ex-5-3-vpa.yaml
# Expected: kind: VerticalPodAutoscaler

grep 'updateMode: "Off"' /tmp/ex-5-3-vpa.yaml
# Expected: a line containing updateMode: "Off"

grep 'controlledResources' /tmp/ex-5-3-vpa.yaml
# Expected: a line containing controlledResources
```

---

## Cleanup

Delete the exercise namespaces and any captured files:

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 \
          ex-2-1 ex-2-2 ex-2-3 \
          ex-3-1 ex-3-2 ex-3-3 \
          ex-4-1 ex-4-2 ex-4-3 \
          ex-5-1 ex-5-2 ex-5-3; do
  kubectl delete namespace $ns --ignore-not-found
done

rm -f /tmp/ex-2-2-restarts-before.txt /tmp/ex-2-3-restarts-before.txt \
      /tmp/ex-5-3-vpa.yaml
```

metrics-server is left installed so it is available for future assignments.

---

## Key Takeaways

Every HPA depends on metrics-server being healthy; every HPA that targets CPU or memory utilization requires the target pod's template to set `resources.requests` on the relevant resource. These are the two most common root causes of a non-scaling HPA, and both produce the same visible symptom: the TARGETS column reads `<unknown>/X%` and the HPA never scales. A five-second check on `kubectl top nodes` plus a five-second check on `kubectl get deployment X -o jsonpath='{.spec.template.spec.containers[0].resources}'` narrows the cause before you read the HPA events.

The `spec.scaleTargetRef` on an HPA is exact: a Deployment named `api2-deployment` is not the same target as one named `api2`, and the HPA's `AbleToScale` condition goes `False` with reason `FailedGetScale` when the reference names something that does not exist. This is the third most common HPA mistake, and it applies successfully at the API layer because Kubernetes does not validate referential integrity at apply time for HPA targets.

HPA behavior configuration is two independent halves. `scaleUp` defaults to react-fast (0 stabilization, 100% or 4 pods per 15 seconds, whichever is larger) and `scaleDown` defaults to react-slow (300-second stabilization, 100% per 15 seconds). The defaults suit most workloads. Override `scaleUp` to cap the damage a sudden burst can do; override `scaleDown` to prevent thrashing on oscillating loads. Do not override both aggressively in the same HPA unless you know exactly what pattern you are protecting against.

In-place pod resize changes `resources.requests` and `resources.limits` on a running pod without restarting the container, for resources whose `resizePolicy` is `NotRequired` (which is the default for CPU and memory in 1.33+). Use the `resize` subresource with `kubectl patch ... --subresource=resize`. When `resizePolicy` is `RestartContainer` for a resource (for example, memory), that resource's change restarts the container and increments `restartCount`. Use `NotRequired` when the workload tolerates in-place updates, `RestartContainer` when the process must re-read the new limits at startup.

VPA is treated at concept level on the CKA. Know that it exists outside core Kubernetes, that it has three update modes (`Off` for recommendations only, `Initial` for pod-creation-time only, `Auto` for live pod replacement via eviction or in-place resize), and that VPA conflicts with HPA on the same resource on the same workload. Never give both HPA and VPA control of the same resource (usually CPU) on the same Deployment; HPA lowering pod counts based on utilization and VPA adjusting requests based on usage produce a feedback loop that oscillates without converging.

The HPA diagnostic playbook in one sentence: if the HPA is not doing what you expect, run `kubectl describe hpa <name>` and read the `Conditions` block; `AbleToScale: False` means the target ref is wrong, `ScalingActive: False` means metrics cannot be computed (usually missing requests or metrics-server), `ScalingLimited: True` with `DesiredWithinRange` means the HPA is clamped at `minReplicas` or `maxReplicas`. Everything else is downstream of one of those three conditions.
