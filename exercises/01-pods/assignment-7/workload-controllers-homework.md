# Workload Controllers Homework

**Assignment 7: ReplicaSets, Deployments, and DaemonSets**

This homework contains 15 exercises progressing from basic controller operations through production-realistic builds and advanced debugging. Complete the tutorial (`workload-controllers-tutorial.md`) before starting these exercises.

All exercises assume a multi-node kind cluster with 1 control-plane node and 3 worker nodes (`kind-worker`, `kind-worker2`, `kind-worker3`).

---

## Pre-Exercise Setup

Verify your cluster is ready:

```bash
kubectl get nodes
# Expected output: 4 nodes (1 control-plane, 3 workers), all Ready
```

Optional global cleanup if you have leftover resources from the tutorial or prior exercises:

```bash
kubectl delete namespace tutorial-workload-controllers 2>/dev/null
for ns in ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 \
           ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3; do
  kubectl delete namespace "$ns" 2>/dev/null
done
```

---

## Level 1: Basic Single-Concept Tasks

### Exercise 1.1

**Objective:** Create a Deployment and verify its pod management.

**Setup:**

```bash
kubectl create namespace ex-1-1
```

**Task:** Create a Deployment named `web` in namespace `ex-1-1` with 3 replicas of `nginx:1.25`. The container should be named `nginx` and expose port 80.

**Verification:**

```bash
# 1. Deployment exists with 3 ready replicas
kubectl get deployment web -n ex-1-1 -o jsonpath='{.status.readyReplicas}' ; echo
# Expected: 3

# 2. Exactly 3 pods are Running
kubectl get pods -n ex-1-1 -l app=web --no-headers | wc -l
# Expected: 3

# 3. A ReplicaSet was created by the Deployment
kubectl get rs -n ex-1-1 -l app=web --no-headers | wc -l
# Expected: 1
```

---

### Exercise 1.2

**Objective:** Scale an existing Deployment using the imperative command.

**Setup:**

```bash
kubectl create namespace ex-1-2
kubectl create deployment scaler -n ex-1-2 --image=nginx:1.25 --replicas=2
kubectl rollout status deployment/scaler -n ex-1-2
```

**Task:** Scale the `scaler` Deployment in namespace `ex-1-2` from 2 replicas to 5 replicas using `kubectl scale`.

**Verification:**

```bash
# 1. Deployment has 5 ready replicas
kubectl get deployment scaler -n ex-1-2 -o jsonpath='{.status.readyReplicas}' ; echo
# Expected: 5

# 2. Exactly 5 pods are Running
kubectl get pods -n ex-1-2 -l app=scaler --no-headers | wc -l
# Expected: 5
```

---

### Exercise 1.3

**Objective:** Create a DaemonSet that runs on every worker node.

**Setup:**

```bash
kubectl create namespace ex-1-3
```

**Task:** Create a DaemonSet named `node-reporter` in namespace `ex-1-3`. It should run a `busybox:1.36` container named `reporter` that executes the command `sh -c "while true; do echo reporting from $(hostname); sleep 10; done"`. It should run on all worker nodes but not on the control-plane node.

**Verification:**

```bash
# 1. DaemonSet shows 3 desired pods (one per worker node)
kubectl get ds node-reporter -n ex-1-3 -o jsonpath='{.status.desiredNumberScheduled}' ; echo
# Expected: 3

# 2. All 3 pods are Ready
kubectl get ds node-reporter -n ex-1-3 -o jsonpath='{.status.numberReady}' ; echo
# Expected: 3

# 3. Pods are distributed across all three worker nodes
kubectl get pods -n ex-1-3 -l app=node-reporter -o wide --no-headers | awk '{print $7}' | sort
# Expected: kind-worker, kind-worker2, kind-worker3 (one pod per worker)
```

---

## Level 2: Multi-Concept Tasks

### Exercise 2.1

**Objective:** Perform a rolling update and rollback on a Deployment.

**Setup:**

```bash
kubectl create namespace ex-2-1
kubectl create deployment roller -n ex-2-1 --image=nginx:1.25 --replicas=3
kubectl rollout status deployment/roller -n ex-2-1
```

**Task:** Update the `roller` Deployment's container image to `nginx:1.26-alpine`, verify the rollout completes, then roll back to the original image.

**Verification:**

```bash
# 1. After rollback, all pods are running nginx:1.25
kubectl get pods -n ex-2-1 -l app=roller \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'
# Expected: nginx:1.25 (three times)

# 2. Rollout history shows at least 2 revisions
kubectl rollout history deployment/roller -n ex-2-1 | grep -c "^[0-9]"
# Expected: 2 or more

# 3. Current rollout status is complete
kubectl rollout status deployment/roller -n ex-2-1
# Expected: successfully rolled out

# 4. Two ReplicaSets exist (one active, one scaled to 0)
kubectl get rs -n ex-2-1 -l app=roller --no-headers | wc -l
# Expected: 2
```

---

### Exercise 2.2

**Objective:** Create a DaemonSet with targeted node selection and demonstrate dynamic pod placement.

**Setup:**

```bash
kubectl create namespace ex-2-2
```

**Task:**

1. Create a DaemonSet named `targeted-agent` in namespace `ex-2-2` that runs a `busybox:1.36` container named `agent` executing `sh -c "while true; do echo agent on $(hostname); sleep 30; done"`. The DaemonSet's pod template should include a `nodeSelector` requiring the label `role=monitored`.
2. Label `kind-worker` and `kind-worker2` with `role=monitored`.
3. Verify that pods appear on those two nodes only.
4. Remove the label from `kind-worker` and verify the pod is evicted from that node.

**Verification:**

```bash
# 1. After labeling two nodes: DaemonSet desires 2 pods
kubectl get ds targeted-agent -n ex-2-2 -o jsonpath='{.status.desiredNumberScheduled}' ; echo
# Expected: 2

# 2. After removing the label from kind-worker: DaemonSet desires 1 pod
kubectl get ds targeted-agent -n ex-2-2 -o jsonpath='{.status.desiredNumberScheduled}' ; echo
# Expected: 1

# 3. Remaining pod is on kind-worker2
kubectl get pods -n ex-2-2 -l app=targeted-agent -o wide --no-headers | awk '{print $7}'
# Expected: kind-worker2

# 4. DaemonSet is fully available
kubectl get ds targeted-agent -n ex-2-2 -o jsonpath='{.status.numberAvailable}' ; echo
# Expected: 1
```

**Cleanup (node labels):**

```bash
kubectl label node kind-worker role- 2>/dev/null
kubectl label node kind-worker2 role- 2>/dev/null
```

---

### Exercise 2.3

**Objective:** Create a Deployment with explicit RollingUpdate parameters and verify rollout behavior.

**Setup:**

```bash
kubectl create namespace ex-2-3
```

**Task:** Create a Deployment named `controlled-roll` in namespace `ex-2-3` with 4 replicas of `nginx:1.25` (container named `nginx`). Configure the strategy as `RollingUpdate` with `maxSurge: 1` and `maxUnavailable: 0`. After it is ready, update the image to `nginx:1.26-alpine` and verify the rollout completes without ever dropping below 4 ready replicas.

**Verification:**

```bash
# 1. Deployment has correct strategy settings
kubectl get deployment controlled-roll -n ex-2-3 \
  -o jsonpath='{.spec.strategy.type}' ; echo
# Expected: RollingUpdate

kubectl get deployment controlled-roll -n ex-2-3 \
  -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}' ; echo
# Expected: 1

kubectl get deployment controlled-roll -n ex-2-3 \
  -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}' ; echo
# Expected: 0

# 2. After rollout: all 4 pods run the new image
kubectl get pods -n ex-2-3 -l app=controlled-roll \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'
# Expected: nginx:1.26-alpine (four times)

# 3. Rollout completed successfully
kubectl rollout status deployment/controlled-roll -n ex-2-3
# Expected: successfully rolled out

# 4. Exactly 4 ready replicas
kubectl get deployment controlled-roll -n ex-2-3 -o jsonpath='{.status.readyReplicas}' ; echo
# Expected: 4
```

---

## Level 3: Debugging Broken Configurations

### Exercise 3.1

**Objective:** Fix the broken Deployment so it has 3 Ready pods.

**Setup:**

```bash
kubectl create namespace ex-3-1
cat <<'EOF' | kubectl apply -n ex-3-1 -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-deploy
spec:
  replicas: 3
  selector:
    matchLabels:
      app: broken-deploy
      tier: frontend
  template:
    metadata:
      labels:
        app: broken-deploy
    spec:
      containers:
        - name: web
          image: nginx:1.25
EOF
```

**Task:** The setup above has a problem. Diagnose why the Deployment is not creating pods and fix it so there are 3 Running pods.

**Verification:**

```bash
# 1. Deployment has 3 ready replicas
kubectl get deployment broken-deploy -n ex-3-1 -o jsonpath='{.status.readyReplicas}' ; echo
# Expected: 3

# 2. All 3 pods are Running
kubectl get pods -n ex-3-1 -l app=broken-deploy --field-selector=status.phase=Running --no-headers | wc -l
# Expected: 3
```

---

### Exercise 3.2

**Objective:** Fix the Deployment so its rollout completes successfully and all 3 pods are Ready and running the updated image.

**Setup:**

```bash
kubectl create namespace ex-3-2
kubectl create deployment stuck-rollout -n ex-3-2 --image=nginx:1.25 --replicas=3
kubectl rollout status deployment/stuck-rollout -n ex-3-2
kubectl set image deployment/stuck-rollout nginx=nginx:1.99-nonexistent -n ex-3-2
```

**Task:** The Deployment's rollout is stuck. Diagnose the problem, fix it, and ensure all 3 pods are Ready and running an updated (non-original) nginx image.

**Verification:**

```bash
# 1. Rollout is complete
kubectl rollout status deployment/stuck-rollout -n ex-3-2
# Expected: successfully rolled out

# 2. All 3 pods are Ready
kubectl get deployment stuck-rollout -n ex-3-2 -o jsonpath='{.status.readyReplicas}' ; echo
# Expected: 3

# 3. Pods are running a valid, updated image (not nginx:1.25 and not nginx:1.99-nonexistent)
kubectl get pods -n ex-3-2 -l app=stuck-rollout \
  -o jsonpath='{.items[0].spec.containers[0].image}' ; echo
# Expected: a valid nginx tag like nginx:1.26-alpine
```

---

### Exercise 3.3

**Objective:** Fix the DaemonSet so it runs a pod on every worker node.

**Setup:**

```bash
kubectl create namespace ex-3-3
cat <<'EOF' | kubectl apply -n ex-3-3 -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: broken-ds
spec:
  selector:
    matchLabels:
      app: broken-ds
  template:
    metadata:
      labels:
        app: broken-ds
    spec:
      nodeSelector:
        disk-type: nvme
      containers:
        - name: agent
          image: busybox:1.36
          command: ["sh", "-c", "while true; do echo agent running; sleep 30; done"]
EOF
```

**Task:** The DaemonSet above is not scheduling pods on any worker node. Diagnose why and fix it so there is one pod Running on each of the three worker nodes.

**Verification:**

```bash
# 1. DaemonSet desires 3 pods
kubectl get ds broken-ds -n ex-3-3 -o jsonpath='{.status.desiredNumberScheduled}' ; echo
# Expected: 3

# 2. All 3 pods are Ready
kubectl get ds broken-ds -n ex-3-3 -o jsonpath='{.status.numberReady}' ; echo
# Expected: 3

# 3. Pods are on the three worker nodes
kubectl get pods -n ex-3-3 -l app=broken-ds -o wide --no-headers | awk '{print $7}' | sort
# Expected: kind-worker, kind-worker2, kind-worker3
```

---

## Level 4: Production-Realistic Scenarios

### Exercise 4.1

**Objective:** Build a production-style Deployment with rolling update configuration, perform an update, and roll back.

**Setup:**

```bash
kubectl create namespace ex-4-1
```

**Task:** Create a Deployment named `prod-web` in namespace `ex-4-1` with the following configuration:

- 3 replicas
- Container named `web` running `nginx:1.25`, exposing port 80
- Labels on the template following the convention: `app: prod-web`, `version: v1`
- Selector matching on `app: prod-web` only (so the version label can change with updates)
- RollingUpdate strategy with `maxSurge: 1` and `maxUnavailable: 0`
- A readiness probe: HTTP GET on port 80 path `/`, `initialDelaySeconds: 2`, `periodSeconds: 5`

After the Deployment is fully ready, update the image to `nginx:1.26-alpine` and change the `version` label to `v2`. Verify the rollout completes. Then roll back to the original revision and verify.

**Verification:**

```bash
# 1. After initial creation: 3 ready replicas
kubectl get deployment prod-web -n ex-4-1 -o jsonpath='{.status.readyReplicas}' ; echo
# Expected: 3

# 2. Strategy is correct
kubectl get deployment prod-web -n ex-4-1 \
  -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge} {.spec.strategy.rollingUpdate.maxUnavailable}' ; echo
# Expected: 1 0

# 3. After update: all pods run nginx:1.26-alpine
kubectl get pods -n ex-4-1 -l app=prod-web \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'
# Expected: nginx:1.26-alpine (three times)

# 4. After update: template version label is v2
kubectl get deployment prod-web -n ex-4-1 \
  -o jsonpath='{.spec.template.metadata.labels.version}' ; echo
# Expected: v2

# 5. After rollback: all pods run nginx:1.25
kubectl get pods -n ex-4-1 -l app=prod-web \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'
# Expected: nginx:1.25 (three times)

# 6. After rollback: template version label is v1
kubectl get deployment prod-web -n ex-4-1 \
  -o jsonpath='{.spec.template.metadata.labels.version}' ; echo
# Expected: v1

# 7. Rollout history has at least 3 revisions
kubectl rollout history deployment/prod-web -n ex-4-1 | grep -c "^[0-9]"
# Expected: 3 or more

# 8. Readiness probe is configured
kubectl get deployment prod-web -n ex-4-1 \
  -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.port}' ; echo
# Expected: 80
```

---

### Exercise 4.2

**Objective:** Build a DaemonSet that runs on every node in the cluster, including the control-plane.

**Setup:**

```bash
kubectl create namespace ex-4-2
```

**Task:** Create a DaemonSet named `cluster-agent` in namespace `ex-4-2` with the following configuration:

- Container named `agent` running `busybox:1.36`
- Command: `sh -c "while true; do echo cluster-agent on $(hostname); sleep 60; done"`
- Labels: `app: cluster-agent`, `component: monitoring`
- Selector matching on both `app: cluster-agent` and `component: monitoring`
- Tolerates the control-plane taint so it runs on all 4 nodes
- Resource requests: `cpu: 10m`, `memory: 16Mi`
- Resource limits: `cpu: 50m`, `memory: 32Mi`

**Verification:**

```bash
# 1. DaemonSet desires 4 pods (all nodes including control-plane)
kubectl get ds cluster-agent -n ex-4-2 -o jsonpath='{.status.desiredNumberScheduled}' ; echo
# Expected: 4

# 2. All 4 pods are Ready
kubectl get ds cluster-agent -n ex-4-2 -o jsonpath='{.status.numberReady}' ; echo
# Expected: 4

# 3. One pod is on the control-plane node
kubectl get pods -n ex-4-2 -l app=cluster-agent -o wide --no-headers | grep control-plane | wc -l
# Expected: 1

# 4. Resource requests are set
kubectl get ds cluster-agent -n ex-4-2 \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' ; echo
# Expected: 10m

# 5. Resource limits are set
kubectl get ds cluster-agent -n ex-4-2 \
  -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' ; echo
# Expected: 32Mi

# 6. Pods are distributed across all 4 nodes
kubectl get pods -n ex-4-2 -l app=cluster-agent -o wide --no-headers | awk '{print $7}' | sort
# Expected: kind-control-plane, kind-worker, kind-worker2, kind-worker3

# 7. Component label is present on pods
kubectl get pods -n ex-4-2 -l component=monitoring --no-headers | wc -l
# Expected: 4

# 8. Toleration for control-plane is present
kubectl get ds cluster-agent -n ex-4-2 \
  -o jsonpath='{.spec.template.spec.tolerations[0].key}' ; echo
# Expected: node-role.kubernetes.io/control-plane
```

---

### Exercise 4.3

**Objective:** Build two independent Deployments in the same namespace with correct label hygiene.

**Setup:**

```bash
kubectl create namespace ex-4-3
```

**Task:** Create two Deployments in namespace `ex-4-3`:

1. **frontend:** 3 replicas, container named `web` running `nginx:1.25` on port 80. Labels: `app: myapp`, `component: frontend`. Selector matches on `app: myapp`, `component: frontend`.
2. **backend:** 2 replicas, container named `api` running `nginx:1.26-alpine` on port 8080. Labels: `app: myapp`, `component: backend`. Selector matches on `app: myapp`, `component: backend`.

The two Deployments share the `app: myapp` label for organizational grouping, but their selectors are distinct because of the `component` label. Neither controller should interfere with the other's pods.

**Verification:**

```bash
# 1. Frontend has 3 ready replicas
kubectl get deployment frontend -n ex-4-3 -o jsonpath='{.status.readyReplicas}' ; echo
# Expected: 3

# 2. Backend has 2 ready replicas
kubectl get deployment backend -n ex-4-3 -o jsonpath='{.status.readyReplicas}' ; echo
# Expected: 2

# 3. Total pods in namespace: 5
kubectl get pods -n ex-4-3 --no-headers | wc -l
# Expected: 5

# 4. Frontend pods have component=frontend label
kubectl get pods -n ex-4-3 -l component=frontend --no-headers | wc -l
# Expected: 3

# 5. Backend pods have component=backend label
kubectl get pods -n ex-4-3 -l component=backend --no-headers | wc -l
# Expected: 2

# 6. Selecting by app=myapp returns all 5 pods
kubectl get pods -n ex-4-3 -l app=myapp --no-headers | wc -l
# Expected: 5

# 7. Frontend selector does not match backend pods
kubectl get pods -n ex-4-3 -l app=myapp,component=frontend --no-headers | wc -l
# Expected: 3

# 8. Backend selector does not match frontend pods
kubectl get pods -n ex-4-3 -l app=myapp,component=backend --no-headers | wc -l
# Expected: 2
```

---

## Level 5: Advanced Debugging and Comprehensive Tasks

### Exercise 5.1

**Objective:** Fix all issues with the Deployment so it has 3 Ready pods, a successful rollout history of at least two revisions, and the ability to roll back.

**Setup:**

```bash
kubectl create namespace ex-5-1
cat <<'EOF' | kubectl apply -n ex-5-1 -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: complex-deploy
spec:
  replicas: 3
  revisionHistoryLimit: 0
  selector:
    matchLabels:
      app: complex-deploy
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: complex-deploy
    spec:
      containers:
        - name: web
          image: nginx:1.25
          readinessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 2
            periodSeconds: 3
            failureThreshold: 2
EOF
```

**Task:** The Deployment above has one or more problems. Diagnose and fix whatever is needed so that the Deployment has 3 Ready pods, you can perform a rolling update (change the image to `nginx:1.26-alpine`), the rollout succeeds, and you can then roll back to the original image.

**Verification:**

```bash
# 1. After fixes: 3 ready replicas
kubectl get deployment complex-deploy -n ex-5-1 -o jsonpath='{.status.readyReplicas}' ; echo
# Expected: 3

# 2. After rollout to nginx:1.26-alpine: all pods updated
kubectl get pods -n ex-5-1 -l app=complex-deploy \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'
# Expected: nginx:1.26-alpine (three times)

# 3. After rollback: all pods back to nginx:1.25
kubectl get pods -n ex-5-1 -l app=complex-deploy \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'
# Expected: nginx:1.25 (three times)

# 4. Rollout history has multiple revisions
kubectl rollout history deployment/complex-deploy -n ex-5-1 | grep -c "^[0-9]"
# Expected: 2 or more

# 5. At least one old ReplicaSet is retained
kubectl get rs -n ex-5-1 -l app=complex-deploy --no-headers | wc -l
# Expected: 2 or more
```

---

### Exercise 5.2

**Objective:** Fix whatever is needed so that the DaemonSet runs exactly one pod on every worker node and all pods are Ready.

**Setup:**

```bash
kubectl create namespace ex-5-2
kubectl taint nodes kind-worker2 dedicated=gpu:NoSchedule
kubectl label node kind-worker3 zone=us-east-1a
cat <<'EOF' | kubectl apply -n ex-5-2 -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: complex-ds
spec:
  selector:
    matchLabels:
      app: complex-ds
  template:
    metadata:
      labels:
        app: complex-ds
    spec:
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: zone
                    operator: In
                    values:
                      - us-east-1a
      containers:
        - name: monitor
          image: busybox:1.36
          command: ["sh", "-c", "while true; do echo monitor on $(hostname); sleep 30; done"]
EOF
```

**Task:** The DaemonSet and cluster above have one or more problems preventing the DaemonSet from running on all three worker nodes. Find and fix everything needed so the DaemonSet runs exactly one pod on each of the three worker nodes (but not on the control-plane). All pods must be Ready.

**Verification:**

```bash
# 1. DaemonSet desires exactly 3 pods
kubectl get ds complex-ds -n ex-5-2 -o jsonpath='{.status.desiredNumberScheduled}' ; echo
# Expected: 3

# 2. All 3 pods are Ready
kubectl get ds complex-ds -n ex-5-2 -o jsonpath='{.status.numberReady}' ; echo
# Expected: 3

# 3. Pods are on the three worker nodes
kubectl get pods -n ex-5-2 -l app=complex-ds -o wide --no-headers | awk '{print $7}' | sort
# Expected: kind-worker, kind-worker2, kind-worker3

# 4. No pod on the control-plane
kubectl get pods -n ex-5-2 -l app=complex-ds -o wide --no-headers | grep control-plane | wc -l
# Expected: 0
```

**Cleanup (node state):**

```bash
kubectl taint nodes kind-worker2 dedicated=gpu:NoSchedule- 2>/dev/null
kubectl label node kind-worker3 zone- 2>/dev/null
```

---

### Exercise 5.3

**Objective:** Build a complete application topology with three independent controllers that do not interfere with each other, perform a rolling update on one, roll it back, and verify the others were unaffected.

**Setup:**

```bash
kubectl create namespace ex-5-3
```

**Task:** Create the following three controllers in namespace `ex-5-3`:

1. A Deployment named `fe` with 3 replicas, container `web` running `nginx:1.25` on port 80, RollingUpdate strategy with `maxSurge: 1` and `maxUnavailable: 0`. Labels: `app: stack`, `component: frontend`. Selector: `app: stack`, `component: frontend`.

2. A Deployment named `be` with 2 replicas, container `api` running `nginx:1.26-alpine` on port 8080, Recreate strategy. Labels: `app: stack`, `component: backend`. Selector: `app: stack`, `component: backend`.

3. A DaemonSet named `log-collector` with container `logger` running `busybox:1.36` executing `sh -c "while true; do echo log-collector on $(hostname); sleep 30; done"`. Labels: `app: stack`, `component: logging`. Selector: `app: stack`, `component: logging`. Should run on all worker nodes only (not the control-plane).

After all three controllers are ready, perform a rolling update on `fe` by changing its image to `nginx:1.26-alpine`. Verify the rollout completes. Then roll back `fe` to the original image. Verify the rollback, and confirm that `be` and `log-collector` were completely unaffected throughout.

**Verification:**

```bash
# 1. Frontend has 3 ready replicas
kubectl get deployment fe -n ex-5-3 -o jsonpath='{.status.readyReplicas}' ; echo
# Expected: 3

# 2. Backend has 2 ready replicas
kubectl get deployment be -n ex-5-3 -o jsonpath='{.status.readyReplicas}' ; echo
# Expected: 2

# 3. DaemonSet has 3 ready pods (one per worker)
kubectl get ds log-collector -n ex-5-3 -o jsonpath='{.status.numberReady}' ; echo
# Expected: 3

# 4. After rollback: frontend pods run nginx:1.25
kubectl get pods -n ex-5-3 -l component=frontend \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'
# Expected: nginx:1.25 (three times)

# 5. Backend pods still run original image (unaffected)
kubectl get pods -n ex-5-3 -l component=backend \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'
# Expected: nginx:1.26-alpine (two times)

# 6. DaemonSet pods still run busybox:1.36 (unaffected)
kubectl get pods -n ex-5-3 -l component=logging \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'
# Expected: busybox:1.36 (three times)

# 7. Frontend rollout history has at least 3 revisions
kubectl rollout history deployment/fe -n ex-5-3 | grep -c "^[0-9]"
# Expected: 3 or more

# 8. Backend rollout history has exactly 1 revision (it was never updated)
kubectl rollout history deployment/be -n ex-5-3 | grep -c "^[0-9]"
# Expected: 1

# 9. Total pods in namespace: 8 (3 frontend + 2 backend + 3 daemonset)
kubectl get pods -n ex-5-3 --no-headers | wc -l
# Expected: 8

# 10. No controller accidentally manages another's pods
kubectl get pods -n ex-5-3 -l app=stack,component=frontend --no-headers | wc -l
# Expected: 3
kubectl get pods -n ex-5-3 -l app=stack,component=backend --no-headers | wc -l
# Expected: 2
kubectl get pods -n ex-5-3 -l app=stack,component=logging --no-headers | wc -l
# Expected: 3
```

---

## Cleanup

Remove all exercise namespaces:

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 \
           ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3; do
  kubectl delete namespace "$ns" 2>/dev/null
done
```

Remove any custom node labels and taints:

```bash
kubectl label node kind-worker role- workload- 2>/dev/null
kubectl label node kind-worker2 role- workload- 2>/dev/null
kubectl label node kind-worker3 zone- 2>/dev/null
kubectl taint nodes kind-worker2 dedicated=gpu:NoSchedule- 2>/dev/null
kubectl taint nodes kind-worker3 maintenance=true:NoExecute- 2>/dev/null
```

Verify clean state:

```bash
kubectl get nodes --show-labels
kubectl describe nodes | grep -A3 Taints
```

---

## Key Takeaways

**The controller reconciliation loop** is the central concept. Every controller continuously compares desired state against actual state and takes corrective action. If a pod dies, the controller creates a replacement. If there are too many pods, the controller deletes extras. This loop is what makes Kubernetes self-healing.

**The selector-template label contract** is the most common source of controller configuration errors. The selector's labels must be present in the template's labels, or the API server rejects the resource. But the template can have additional labels beyond what the selector requires.

**RollingUpdate field semantics** control how aggressive a rollout is. `maxSurge` sets how many extra pods can exist during the rollout (above the desired count). `maxUnavailable` sets how many pods can be unavailable (below the desired count). With `maxSurge: 1` and `maxUnavailable: 0`, the rollout proceeds one pod at a time with zero downtime. With `maxUnavailable: 100%`, the rollout effectively becomes a Recreate.

**Rollout history and undo** give you the ability to revert a bad deployment. `kubectl rollout undo` reverts to the previous revision. `kubectl rollout undo --to-revision=N` reverts to a specific revision. The `revisionHistoryLimit` field controls how many old ReplicaSets are retained; setting it to 0 makes rollback impossible.

**DaemonSet node-targeting patterns** combine nodeSelector, node affinity, and tolerations to control where DaemonSet pods run. The most common real-world pattern is a DaemonSet that tolerates all taints to run on every node, including the control-plane.

**The controller-ownership chain** (Deployment -> ReplicaSet -> Pod) is tracked through `ownerReferences` in each object's metadata. Deleting an owner cascades to its children by default. The `--cascade=orphan` flag prevents this cascade.
