# Workload Controllers Homework Answers

**Assignment 7: ReplicaSets, Deployments, and DaemonSets**

Complete solutions for all 15 exercises, including diagnostic explanations for debugging exercises.

---

## Exercise 1.1 Solution

**Imperative approach (fastest for CKA):**

```bash
kubectl create deployment web -n ex-1-1 --image=nginx:1.25 --replicas=3 --port=80
kubectl rollout status deployment/web -n ex-1-1
```

**Declarative approach:**

```bash
cat <<'EOF' | kubectl apply -n ex-1-1 -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
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
          image: nginx:1.25
          ports:
            - containerPort: 80
EOF
kubectl rollout status deployment/web -n ex-1-1
```

The imperative `kubectl create deployment` automatically sets the selector to `app: web` and adds the same label to the template. It also names the container after the image by default (`nginx`), which matches the requirement.

---

## Exercise 1.2 Solution

```bash
kubectl scale deployment/scaler -n ex-1-2 --replicas=5
```

Wait a few seconds for the new pods to start:

```bash
kubectl rollout status deployment/scaler -n ex-1-2
```

Scaling does not create a new ReplicaSet or trigger a rollout. It simply adjusts the replicas count on the existing ReplicaSet. You can verify this:

```bash
kubectl get rs -n ex-1-2 -l app=scaler --no-headers | wc -l
# Still 1 ReplicaSet
```

---

## Exercise 1.3 Solution

DaemonSets have no imperative shortcut like `kubectl create daemonset`, so YAML is required:

```bash
cat <<'EOF' | kubectl apply -n ex-1-3 -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-reporter
spec:
  selector:
    matchLabels:
      app: node-reporter
  template:
    metadata:
      labels:
        app: node-reporter
    spec:
      containers:
        - name: reporter
          image: busybox:1.36
          command: ["sh", "-c", "while true; do echo reporting from $(hostname); sleep 10; done"]
EOF
```

The DaemonSet runs on all three worker nodes but not on the control-plane node. The control-plane node has a `node-role.kubernetes.io/control-plane:NoSchedule` taint that the DaemonSet does not tolerate, so the scheduler skips it. No explicit `nodeSelector` is needed to exclude the control-plane; the taint handles it.

**CKA tip:** A quick way to generate a DaemonSet YAML starting point is to create a Deployment dry-run and convert it:

```bash
kubectl create deployment temp --image=busybox:1.36 --dry-run=client -o yaml > ds-base.yaml
```

Then manually change `kind: Deployment` to `kind: DaemonSet`, remove the `replicas` field, remove the `strategy` field, and adjust the spec as needed.

---

## Exercise 2.1 Solution

```bash
# Step 1: Update the image
kubectl set image deployment/roller nginx=nginx:1.26-alpine -n ex-2-1

# Step 2: Verify the rollout completes
kubectl rollout status deployment/roller -n ex-2-1

# Step 3: Check the updated image
kubectl get pods -n ex-2-1 -l app=roller \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'
# Should show nginx:1.26-alpine

# Step 4: Roll back
kubectl rollout undo deployment/roller -n ex-2-1

# Step 5: Verify the rollback
kubectl rollout status deployment/roller -n ex-2-1
kubectl get pods -n ex-2-1 -l app=roller \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'
# Should show nginx:1.25
```

After the rollback, there are two ReplicaSets: the one from revision 1 (now the active one again, scaled back up to 3) and the one from revision 2 (scaled to 0). The rollback itself creates a new revision number; `kubectl rollout history` will show at least revision 2 and 3 (revision 1 was promoted to 3 by the undo).

---

## Exercise 2.2 Solution

**Step 1: Create the DaemonSet:**

```bash
cat <<'EOF' | kubectl apply -n ex-2-2 -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: targeted-agent
spec:
  selector:
    matchLabels:
      app: targeted-agent
  template:
    metadata:
      labels:
        app: targeted-agent
    spec:
      nodeSelector:
        role: monitored
      containers:
        - name: agent
          image: busybox:1.36
          command: ["sh", "-c", "while true; do echo agent on $(hostname); sleep 30; done"]
EOF
```

At this point the DaemonSet desires 0 pods because no nodes have the `role=monitored` label.

**Step 2: Label two nodes:**

```bash
kubectl label node kind-worker role=monitored
kubectl label node kind-worker2 role=monitored
```

Two pods appear, one on each labeled node.

**Step 3: Remove the label from kind-worker:**

```bash
kubectl label node kind-worker role-
```

The pod on `kind-worker` is evicted. Only the pod on `kind-worker2` remains.

**Step 4: Clean up labels:**

```bash
kubectl label node kind-worker2 role-
```

---

## Exercise 2.3 Solution

```bash
cat <<'EOF' | kubectl apply -n ex-2-3 -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: controlled-roll
spec:
  replicas: 4
  selector:
    matchLabels:
      app: controlled-roll
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: controlled-roll
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
EOF
kubectl rollout status deployment/controlled-roll -n ex-2-3
```

Then update the image:

```bash
kubectl set image deployment/controlled-roll nginx=nginx:1.26-alpine -n ex-2-3
kubectl rollout status deployment/controlled-roll -n ex-2-3
```

With `maxUnavailable: 0`, the Deployment always maintains at least 4 Ready pods during the rollout. It creates 1 new pod (up to 5 total due to maxSurge: 1), waits for it to become Ready, then terminates 1 old pod. This repeats until all 4 pods are updated.

**Alternative imperative approach for the initial Deployment:**

```bash
kubectl create deployment controlled-roll -n ex-2-3 --image=nginx:1.25 --replicas=4 \
  --dry-run=client -o yaml > /tmp/controlled-roll.yaml
```

Then edit the YAML to add the strategy fields and `kubectl apply -f /tmp/controlled-roll.yaml`.

---

## Exercise 3.1 Solution

**Diagnosis:**

```bash
kubectl get deployment broken-deploy -n ex-3-1
kubectl describe deployment broken-deploy -n ex-3-1
```

The Deployment shows 0 ready replicas. The setup command itself likely failed or produced a warning. Check the YAML carefully: the selector requires `matchLabels: {app: broken-deploy, tier: frontend}`, but the template only has `labels: {app: broken-deploy}`. The `tier: frontend` label is missing from the template.

This is the selector-matches-template-labels violation. The API server actually rejects this YAML entirely (it returns an error like `selector does not match template labels`), so the Deployment was never created.

**Fix:** Delete and recreate with matching labels. You can either add `tier: frontend` to the template labels, or remove `tier: frontend` from the selector. The simplest fix:

```bash
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
        tier: frontend
    spec:
      containers:
        - name: web
          image: nginx:1.25
EOF
kubectl rollout status deployment/broken-deploy -n ex-3-1
```

**What was wrong:** The selector included `tier: frontend` but the template labels did not. The Kubernetes API server validates that every label in the selector is also present in the template's labels and rejects the resource if they don't match.

**How to diagnose:** The `kubectl apply` command in the setup would have printed an error message about selector not matching template labels. If the Deployment doesn't exist, `kubectl get deployment` returns "not found," which immediately tells you the creation failed.

---

## Exercise 3.2 Solution

**Diagnosis:**

```bash
kubectl rollout status deployment/stuck-rollout -n ex-3-2 --timeout=10s
# Will timeout, indicating the rollout is stuck

kubectl get pods -n ex-3-2 -l app=stuck-rollout
# Shows pods in ImagePullBackOff or ErrImagePull

kubectl describe pod $(kubectl get pods -n ex-3-2 -l app=stuck-rollout \
  --field-selector=status.phase!=Running -o jsonpath='{.items[0].metadata.name}') -n ex-3-2
# Events show: Failed to pull image "nginx:1.99-nonexistent"
```

The rollout is stuck because the image `nginx:1.99-nonexistent` does not exist. The new ReplicaSet's pods can never pull the image, so they never become Ready, and the rollout can't progress.

**Fix:** Set the image to a valid tag:

```bash
kubectl set image deployment/stuck-rollout nginx=nginx:1.26-alpine -n ex-3-2
kubectl rollout status deployment/stuck-rollout -n ex-3-2
```

This triggers a new rollout with a valid image. The Deployment creates another new ReplicaSet, which successfully pulls `nginx:1.26-alpine`, and the old ReplicaSets (both the original and the failed one) scale to 0.

**Alternative fix** (roll back to the original and then update):

```bash
kubectl rollout undo deployment/stuck-rollout -n ex-3-2
kubectl rollout status deployment/stuck-rollout -n ex-3-2
# Now back to nginx:1.25
kubectl set image deployment/stuck-rollout nginx=nginx:1.26-alpine -n ex-3-2
kubectl rollout status deployment/stuck-rollout -n ex-3-2
```

---

## Exercise 3.3 Solution

**Diagnosis:**

```bash
kubectl get ds broken-ds -n ex-3-3
# DESIRED: 0, CURRENT: 0

kubectl describe ds broken-ds -n ex-3-3
# Shows: nodeSelector: disk-type=nvme
```

Check if any nodes have the `disk-type=nvme` label:

```bash
kubectl get nodes --show-labels | grep disk-type
# No output, no nodes have this label
```

The DaemonSet requires `nodeSelector: disk-type: nvme`, but no nodes in the cluster have that label. The DaemonSet calculates 0 eligible nodes, so it desires 0 pods.

**Fix:** Either label the nodes or remove the nodeSelector. The exercise asks for pods on all three worker nodes, so the simplest fix is to remove the nodeSelector:

```bash
kubectl patch ds broken-ds -n ex-3-3 --type=json \
  -p='[{"op": "remove", "path": "/spec/template/spec/nodeSelector"}]'
```

Or replace the entire DaemonSet:

```bash
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
      containers:
        - name: agent
          image: busybox:1.36
          command: ["sh", "-c", "while true; do echo agent running; sleep 30; done"]
EOF
```

**What was wrong:** The `nodeSelector` targeted a label (`disk-type: nvme`) that no node in the kind cluster has. The DaemonSet scheduler only places pods on nodes that match the node selector, so zero pods were created.

**How to diagnose:** `kubectl get ds` showing DESIRED=0 is the key signal. Combined with `kubectl describe ds` showing a nodeSelector, the next step is to check whether any nodes have that label with `kubectl get nodes --show-labels`.

---

## Exercise 4.1 Solution

**Step 1: Create the Deployment with full production config:**

```bash
cat <<'EOF' | kubectl apply -n ex-4-1 -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prod-web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: prod-web
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: prod-web
        version: v1
    spec:
      containers:
        - name: web
          image: nginx:1.25
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 5
EOF
kubectl rollout status deployment/prod-web -n ex-4-1
```

Note that the selector matches on `app: prod-web` only, not on `version`. This allows the `version` label to change with each rollout without conflicting with the selector.

**Step 2: Perform the update:**

The image and label changes must happen in a single template change. Use `kubectl edit` or reapply the YAML with changes:

```bash
cat <<'EOF' | kubectl apply -n ex-4-1 -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prod-web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: prod-web
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: prod-web
        version: v2
    spec:
      containers:
        - name: web
          image: nginx:1.26-alpine
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 5
EOF
kubectl rollout status deployment/prod-web -n ex-4-1
```

**Step 3: Roll back:**

```bash
kubectl rollout undo deployment/prod-web -n ex-4-1
kubectl rollout status deployment/prod-web -n ex-4-1
```

The rollback reverts the entire template, including both the image and the `version` label, back to the revision 1 values.

---

## Exercise 4.2 Solution

```bash
cat <<'EOF' | kubectl apply -n ex-4-2 -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cluster-agent
spec:
  selector:
    matchLabels:
      app: cluster-agent
      component: monitoring
  template:
    metadata:
      labels:
        app: cluster-agent
        component: monitoring
    spec:
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      containers:
        - name: agent
          image: busybox:1.36
          command: ["sh", "-c", "while true; do echo cluster-agent on $(hostname); sleep 60; done"]
          resources:
            requests:
              cpu: 10m
              memory: 16Mi
            limits:
              cpu: 50m
              memory: 32Mi
EOF
```

Wait for all pods to be ready:

```bash
kubectl rollout status ds/cluster-agent -n ex-4-2
```

The key detail is the toleration for the control-plane taint. Without it, the DaemonSet would only run on the 3 worker nodes. With it, the DaemonSet schedules a pod on all 4 nodes (3 workers + 1 control-plane).

---

## Exercise 4.3 Solution

```bash
cat <<'EOF' | kubectl apply -n ex-4-3 -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      component: frontend
  template:
    metadata:
      labels:
        app: myapp
        component: frontend
    spec:
      containers:
        - name: web
          image: nginx:1.25
          ports:
            - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
      component: backend
  template:
    metadata:
      labels:
        app: myapp
        component: backend
    spec:
      containers:
        - name: api
          image: nginx:1.26-alpine
          ports:
            - containerPort: 8080
EOF
kubectl rollout status deployment/frontend -n ex-4-3
kubectl rollout status deployment/backend -n ex-4-3
```

The critical design decision is that both Deployments share the `app: myapp` label (useful for organizational queries like "show me all pods in this application"), but their selectors include the `component` label which makes them distinct. The frontend Deployment only manages pods with `component: frontend`, and the backend Deployment only manages pods with `component: backend`.

This is verified by the label queries in the verification section: selecting by `app=myapp` returns all 5 pods, but selecting by `app=myapp,component=frontend` returns only 3.

---

## Exercise 5.1 Solution

**Diagnosis:**

There are two issues in the Deployment:

1. **`revisionHistoryLimit: 0`:** This means old ReplicaSets are garbage collected immediately after a rollout. With no old ReplicaSets, `kubectl rollout undo` has nothing to revert to. The exercise requires the ability to roll back, so this must be changed to a value of at least 1 (default is 10).

2. **Readiness probe targeting port 8080 and path /healthz:** nginx:1.25 listens on port 80 and serves a default page at `/`. There is no `/healthz` endpoint on port 8080. The readiness probe fails, so the pods never become Ready.

```bash
# Check the pods
kubectl get pods -n ex-5-1 -l app=complex-deploy
# Pods exist but show 0/1 READY

kubectl describe pod $(kubectl get pods -n ex-5-1 -l app=complex-deploy \
  -o jsonpath='{.items[0].metadata.name}') -n ex-5-1
# Events show readiness probe failed: connection refused on port 8080
```

**Fix:** Correct both issues:

```bash
cat <<'EOF' | kubectl apply -n ex-5-1 -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: complex-deploy
spec:
  replicas: 3
  revisionHistoryLimit: 10
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
              path: /
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 3
            failureThreshold: 2
EOF
kubectl rollout status deployment/complex-deploy -n ex-5-1
```

Now perform the rollout and rollback:

```bash
kubectl set image deployment/complex-deploy web=nginx:1.26-alpine -n ex-5-1
kubectl rollout status deployment/complex-deploy -n ex-5-1

kubectl rollout undo deployment/complex-deploy -n ex-5-1
kubectl rollout status deployment/complex-deploy -n ex-5-1
```

**Issue 1 explained:** `revisionHistoryLimit: 0` means the Deployment garbage-collects old ReplicaSets immediately. When you try `kubectl rollout undo`, there is no previous ReplicaSet to revert to, so the undo does nothing (or returns an error about no revision found). Changing this to 10 (the default) retains old ReplicaSets so rollback works.

**Issue 2 explained:** The readiness probe was checking port 8080, but nginx listens on port 80. The path `/healthz` also doesn't exist (nginx returns 200 on `/` by default, not `/healthz`). With the probe failing, pods never reached Ready status, so `readyReplicas` stayed at 0 and any rolling update would stall (with `maxUnavailable: 0`, the rollout needs new pods to become Ready before terminating old ones).

---

## Exercise 5.2 Solution

**Diagnosis:**

There are three issues preventing the DaemonSet from running on all worker nodes:

1. **Node affinity restricts to `zone=us-east-1a`:** The DaemonSet's template includes a `requiredDuringSchedulingIgnoredDuringExecution` node affinity that only allows scheduling on nodes with `zone=us-east-1a`. Only `kind-worker3` has this label (applied in the setup). The other two workers don't match.

2. **`kind-worker2` has a taint `dedicated=gpu:NoSchedule`:** Even if the affinity is removed, this taint prevents scheduling on `kind-worker2` unless the DaemonSet tolerates it.

3. **Control-plane toleration is present but shouldn't be:** The exercise asks for pods on worker nodes only, but the DaemonSet tolerates the control-plane taint. This is not technically "broken" but doesn't match the requirement.

```bash
# Check DaemonSet status
kubectl get ds complex-ds -n ex-5-2
# Likely shows DESIRED: 1 (only kind-worker3 matches the affinity)

# Check the node affinity
kubectl get ds complex-ds -n ex-5-2 -o jsonpath='{.spec.template.spec.affinity}' | python3 -m json.tool

# Check node labels
kubectl get nodes --show-labels | grep zone

# Check taints
kubectl describe node kind-worker2 | grep -A3 Taints
# Shows: dedicated=gpu:NoSchedule
```

**Fix:** Remove the node affinity, add a toleration for the `dedicated=gpu:NoSchedule` taint on kind-worker2, and remove the control-plane toleration:

```bash
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
        - key: dedicated
          operator: Equal
          value: gpu
          effect: NoSchedule
      containers:
        - name: monitor
          image: busybox:1.36
          command: ["sh", "-c", "while true; do echo monitor on $(hostname); sleep 30; done"]
EOF
```

Wait for pods:

```bash
kubectl rollout status ds/complex-ds -n ex-5-2
```

Then clean up the node state:

```bash
kubectl taint nodes kind-worker2 dedicated=gpu:NoSchedule-
kubectl label node kind-worker3 zone-
```

**Issue 1 explained:** The `requiredDuringSchedulingIgnoredDuringExecution` node affinity is a hard constraint. Nodes that don't match are completely excluded. Since only `kind-worker3` had the `zone=us-east-1a` label, the DaemonSet could only schedule on that one node.

**Issue 2 explained:** The `dedicated=gpu:NoSchedule` taint on `kind-worker2` prevents any pod without a matching toleration from being scheduled there. Even after removing the affinity, `kind-worker2` would still reject the DaemonSet's pods.

**Issue 3 explained:** The control-plane toleration was in the original spec. Removing it ensures the DaemonSet doesn't place a pod on the control-plane node, matching the exercise requirement of "worker nodes only."

---

## Exercise 5.3 Solution

**Step 1: Create all three controllers:**

```bash
cat <<'EOF' | kubectl apply -n ex-5-3 -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fe
spec:
  replicas: 3
  selector:
    matchLabels:
      app: stack
      component: frontend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: stack
        component: frontend
    spec:
      containers:
        - name: web
          image: nginx:1.25
          ports:
            - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: be
spec:
  replicas: 2
  selector:
    matchLabels:
      app: stack
      component: backend
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: stack
        component: backend
    spec:
      containers:
        - name: api
          image: nginx:1.26-alpine
          ports:
            - containerPort: 8080
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: log-collector
spec:
  selector:
    matchLabels:
      app: stack
      component: logging
  template:
    metadata:
      labels:
        app: stack
        component: logging
    spec:
      containers:
        - name: logger
          image: busybox:1.36
          command: ["sh", "-c", "while true; do echo log-collector on $(hostname); sleep 30; done"]
EOF
```

Wait for everything to be ready:

```bash
kubectl rollout status deployment/fe -n ex-5-3
kubectl rollout status deployment/be -n ex-5-3
kubectl rollout status ds/log-collector -n ex-5-3
```

**Step 2: Perform a rolling update on `fe`:**

```bash
kubectl set image deployment/fe web=nginx:1.26-alpine -n ex-5-3
kubectl rollout status deployment/fe -n ex-5-3
```

**Step 3: Roll back `fe`:**

```bash
kubectl rollout undo deployment/fe -n ex-5-3
kubectl rollout status deployment/fe -n ex-5-3
```

**Step 4: Verify the other controllers were unaffected:**

```bash
# Backend pods should still be running nginx:1.26-alpine (never changed)
kubectl get pods -n ex-5-3 -l component=backend \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'

# DaemonSet pods should still be running busybox:1.36 (never changed)
kubectl get pods -n ex-5-3 -l component=logging \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'

# Backend rollout history should have exactly 1 revision
kubectl rollout history deployment/be -n ex-5-3

# Total pod count should be 8
kubectl get pods -n ex-5-3 --no-headers | wc -l
```

The key design insight here is label hygiene. All three controllers share the `app: stack` label (useful for queries like "show me all pods in the stack"), but their selectors include the `component` label which makes them completely independent. The frontend Deployment's selector `{app: stack, component: frontend}` never matches a backend or logging pod, so the frontend rollout and rollback only affect frontend pods.

---

## Common Mistakes

### 1. Selector not matching template labels

The most common controller configuration error. The API server validates that every label in the selector is present in the template labels and rejects the resource if they don't match. The error message (`selector does not match template labels`) is clear, but it's easy to introduce when manually editing YAML.

### 2. Trying to change a Deployment's selector

The selector is effectively immutable after creation. If you modify the selector in your YAML and try `kubectl apply`, the API server rejects it with an error about the field being immutable. The workaround is to `kubectl delete` the Deployment and recreate it with the new selector. Use `--cascade=orphan` if you want to keep the existing pods during the transition.

### 3. Using kubectl apply with a label change in the selector

Related to the above. If you're switching from `app: v1` to `app: v2` in the selector, `kubectl apply` fails. You must delete and recreate.

### 4. Setting maxUnavailable to 100%

With `maxUnavailable: 100%`, the Deployment is allowed to terminate all existing pods before new ones are Ready, effectively turning a RollingUpdate into a Recreate. This is rarely intentional and can cause unexpected downtime during rollouts.

### 5. Using the latest tag and expecting rollouts

If your Deployment specifies `image: myapp:latest` and you reapply the same YAML, the template hasn't changed from the Deployment's perspective. No rollout is triggered, even if the actual image behind `latest` was updated in the registry. Always use pinned tags like `nginx:1.25`.

### 6. Expecting kubectl rollout undo to work with revisionHistoryLimit: 0

When `revisionHistoryLimit` is 0, old ReplicaSets are garbage collected immediately after a successful rollout. There is no previous revision to revert to, so `kubectl rollout undo` has nothing to do. Always set `revisionHistoryLimit` to at least 1 if you want rollback capability.

### 7. DaemonSets without tolerations on tainted nodes

The most common DaemonSet debugging scenario. Kind clusters have the control-plane taint by default, and production clusters often have additional taints for dedicated node pools. If a DaemonSet doesn't tolerate a node's taints, it simply doesn't schedule there, with no error or warning on the DaemonSet itself. The only signal is DESIRED being lower than expected.

### 8. Deleting a Deployment with --cascade=orphan and recreating

If you delete a Deployment with `--cascade=orphan`, the pods become bare pods with no controller. If you then create a new Deployment with the same selector, it adopts those orphaned pods. This can lead to unexpected behavior: the "new" Deployment's ReplicaSet sees existing pods matching its selector and may not create new pods from the new template, or it may terminate the orphans and create fresh pods, depending on the template match.

### 9. Confusing kubectl rollout restart with kubectl rollout undo

`kubectl rollout restart` bumps a template annotation (`kubectl.kubernetes.io/restartedAt`) to trigger a fresh rollout using the **current** template. It recreates all pods but doesn't change the spec. `kubectl rollout undo` reverts the template to a **previous** revision. These are different operations with different purposes.

### 10. Scaling and expecting a new template

Scaling a Deployment (changing `replicas`) does not create a new ReplicaSet. The new pods use the same template as the existing pods. Template changes only happen during rollouts (triggered by changes to `.spec.template`).

### 11. Overlapping selectors between controllers

If two Deployments in the same namespace have the same selector (e.g., both select `app: web`), they will fight over the pods. Each controller's reconciliation loop sees the combined pods and tries to scale to its own desired count, creating and deleting pods in an unstable loop. Always use distinct selectors.

---

## Verification Commands Cheat Sheet

### Deployment Status

```bash
# Ready replicas
kubectl get deployment <n> -n <ns> -o jsonpath='{.status.readyReplicas}' ; echo

# Strategy type and parameters
kubectl get deployment <n> -n <ns> -o jsonpath='{.spec.strategy.type}' ; echo
kubectl get deployment <n> -n <ns> \
  -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge} {.spec.strategy.rollingUpdate.maxUnavailable}' ; echo

# Deployment conditions
kubectl get deployment <n> -n <ns> \
  -o jsonpath='{range .status.conditions[*]}{.type}: {.status} ({.reason}){"\n"}{end}'

# Rollout status
kubectl rollout status deployment/<n> -n <ns>

# Rollout history
kubectl rollout history deployment/<n> -n <ns>
kubectl rollout history deployment/<n> -n <ns> --revision=<N>
```

### ReplicaSet Inspection

```bash
# List ReplicaSets for a Deployment
kubectl get rs -n <ns> -l <selector-label>

# Current vs desired replicas per ReplicaSet
kubectl get rs -n <ns> -l <selector-label> \
  -o custom-columns='NAME:.metadata.name,DESIRED:.spec.replicas,CURRENT:.status.replicas,READY:.status.readyReplicas'
```

### DaemonSet Status

```bash
# Full status line
kubectl get ds <n> -n <ns>

# Desired, current, ready counts
kubectl get ds <n> -n <ns> \
  -o jsonpath='desired={.status.desiredNumberScheduled} current={.status.currentNumberScheduled} ready={.status.numberReady}' ; echo

# Which nodes have pods
kubectl get pods -n <ns> -l <selector-label> -o wide --no-headers | awk '{print $7}' | sort
```

### Pod Ownership

```bash
# Pod's ownerReference (shows which controller owns it)
kubectl get pod <pod-name> -n <ns> \
  -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}' ; echo

# All pods with their owners
kubectl get pods -n <ns> -l <selector-label> \
  -o custom-columns='POD:.metadata.name,OWNER:.metadata.ownerReferences[0].name'
```

### Container Images

```bash
# List images for all pods with a label
kubectl get pods -n <ns> -l <selector-label> \
  -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.containers[0].image}{"\n"}{end}'
```

### Node Labels and Taints

```bash
# Show all node labels
kubectl get nodes --show-labels

# Show taints
kubectl describe nodes | grep -A3 Taints

# Check a specific label
kubectl get nodes -l <key>=<value>
```
