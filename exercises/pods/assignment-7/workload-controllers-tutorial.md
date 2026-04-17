# Workload Controllers Tutorial

**Assignment 7: ReplicaSets, Deployments, and DaemonSets**

This tutorial walks through the three core workload controllers in the order a CKA candidate should learn them: ReplicaSets (the primitive), Deployments (the workhorse), and DaemonSets (the per-node specialist). Work through each section in order in your multi-node kind cluster.

---

## Setup

Create the tutorial namespace and verify your cluster has multiple nodes:

```bash
kubectl create namespace tutorial-workload-controllers
kubectl get nodes
# Expected: 1 control-plane + 3 workers (kind-worker, kind-worker2, kind-worker3)
```

All resources in this tutorial use the namespace `tutorial-workload-controllers`. Most commands include `-n tutorial-workload-controllers` explicitly so you can copy-paste them directly.

---

## Part 1: Why Controllers?

If you create a bare pod (a pod with no controller managing it) and that pod crashes, gets evicted, or the node it runs on goes down, the pod is gone. Nothing recreates it. Bare pods are fine for one-off debugging, but production workloads need self-healing: if a pod disappears, something should notice and create a replacement.

That "something" is a controller. Controllers implement a reconciliation loop: they continuously compare the desired state (how many pods should exist, on which nodes, with what template) against the actual state (how many pods actually exist right now) and take corrective action to close any gap. If a pod dies, the controller creates a new one. If there are too many pods, the controller deletes the extras. If a node is added to the cluster, a DaemonSet controller notices and schedules a pod onto it.

The three controllers in this tutorial form a hierarchy. ReplicaSets are the base primitive that maintains a set of identical pod replicas. Deployments sit on top of ReplicaSets, adding rolling update and rollback capabilities. DaemonSets are a separate primitive that ensures one pod per node rather than a fixed replica count.

Every controller's core data structure is the same: a **selector** (which pods does this controller own?) and a **template** (what should new pods look like?). The selector uses label matching, and the template is a complete pod spec embedded inside the controller spec. If you can build a pod spec from Assignments 1 through 6, you can build a controller template.

---

## Part 2: ReplicaSets

A ReplicaSet ensures that a specified number of pod replicas are running at any time. If pods die, it creates replacements. If there are too many, it kills the extras. ReplicaSets are rarely created directly in production (Deployments create them for you), but understanding them is essential because they are the underlying mechanism that Deployments rely on, and the CKA exam can test them.

### 2.1 Creating a ReplicaSet from YAML

```bash
cat <<'EOF' | kubectl apply -n tutorial-workload-controllers -f -
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: tut-rs-web
  labels:
    app: tut-rs-web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: tut-rs-web
  template:
    metadata:
      labels:
        app: tut-rs-web
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
EOF
```

Let's break down the spec fields:

- **replicas:** The desired number of pod replicas. The controller will create or delete pods to maintain this count.
- **selector:** Defines which pods this ReplicaSet manages. Uses `matchLabels` (exact key-value match) or `matchExpressions` (more complex matching). The selector is effectively immutable after creation.
- **template:** The pod spec used to create new pods. The `metadata.labels` inside the template **must match** the selector. If they don't, the API server rejects the ReplicaSet.

Inspect the result:

```bash
kubectl get replicaset tut-rs-web -n tutorial-workload-controllers
kubectl get pods -n tutorial-workload-controllers -l app=tut-rs-web
```

Notice the pod names. Each pod is named with the ReplicaSet name plus a random 5-character suffix (e.g., `tut-rs-web-x7k2p`). This naming convention tells you at a glance which controller owns which pods.

### 2.2 The Selector-Matches-Template-Labels Contract

The selector and template labels must agree. Try creating a ReplicaSet where they don't match:

```bash
cat <<'EOF' | kubectl apply -n tutorial-workload-controllers -f - 2>&1
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: tut-rs-mismatch
spec:
  replicas: 2
  selector:
    matchLabels:
      app: tut-rs-mismatch
  template:
    metadata:
      labels:
        app: something-else
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
EOF
```

The API server rejects this with an error like: `selector does not match template labels`. This validation prevents you from creating a controller that would immediately lose track of its own pods.

### 2.3 Pod Adoption

ReplicaSets match on selectors, not on "being a descendant." This means a ReplicaSet can adopt pre-existing pods whose labels happen to match its selector. Create a bare pod with matching labels:

```bash
kubectl run tut-rs-orphan --image=nginx:1.25 -n tutorial-workload-controllers \
  --labels="app=tut-rs-web" --restart=Always
```

Now check the ReplicaSet's pod count:

```bash
kubectl get rs tut-rs-web -n tutorial-workload-controllers
```

The DESIRED count is still 3, but CURRENT may briefly be 4 (the original 3 plus the orphan). The ReplicaSet's reconciliation loop detects that there are more pods matching its selector than desired, so it terminates one of them (possibly the orphan, possibly one of its original pods, the choice is not deterministic). After a few seconds, the count returns to 3.

### 2.4 Scaling

Scale the ReplicaSet imperatively:

```bash
kubectl scale rs tut-rs-web --replicas=5 -n tutorial-workload-controllers
kubectl get pods -n tutorial-workload-controllers -l app=tut-rs-web
```

You should see 5 pods. Scale back down:

```bash
kubectl scale rs tut-rs-web --replicas=2 -n tutorial-workload-controllers
kubectl get pods -n tutorial-workload-controllers -l app=tut-rs-web
```

Three pods are terminated to bring the count to 2.

### 2.5 Deletion and Cascade Behavior

By default, deleting a ReplicaSet also deletes all the pods it manages (cascade deletion). You can prevent this with `--cascade=orphan`, which deletes the ReplicaSet but leaves the pods running as bare pods with no controller:

```bash
# First, see what pods exist
kubectl get pods -n tutorial-workload-controllers -l app=tut-rs-web

# Delete the ReplicaSet but keep the pods
kubectl delete rs tut-rs-web -n tutorial-workload-controllers --cascade=orphan

# Pods still exist, but they are now bare pods (no ownerReferences)
kubectl get pods -n tutorial-workload-controllers -l app=tut-rs-web
kubectl get pods -n tutorial-workload-controllers -l app=tut-rs-web \
  -o jsonpath='{.items[0].metadata.ownerReferences}' ; echo
# Should be empty or missing
```

Clean up the orphaned pods:

```bash
kubectl delete pods -n tutorial-workload-controllers -l app=tut-rs-web
```

### 2.6 Why You Almost Never Create ReplicaSets Directly

ReplicaSets have no concept of updates. If you change the pod template (say, update the image tag), the ReplicaSet does not replace existing pods. It only uses the template when creating new pods. Existing pods keep running with the old spec. To get new pods with the updated template, you would need to manually delete the old pods and let the ReplicaSet recreate them.

Deployments solve this problem by creating a new ReplicaSet for each template change and orchestrating a controlled transition from old to new. This is why Deployments are the standard way to run stateless workloads, and direct ReplicaSet creation is rare.

---

## Part 3: Deployments

Deployments are the workhorse controller for stateless applications. They manage ReplicaSets, which in turn manage pods. The key capability a Deployment adds beyond a ReplicaSet is **controlled rollouts**: when you change the pod template, the Deployment creates a new ReplicaSet with the updated template, scales it up while scaling the old ReplicaSet down, and tracks revision history so you can roll back.

### 3.1 Creating a Deployment Imperatively

The fastest way to create a Deployment (critical for the CKA exam under time pressure):

```bash
kubectl create deployment tut-deploy-web --image=nginx:1.25 --replicas=3 \
  -n tutorial-workload-controllers
```

Inspect what was created:

```bash
kubectl get deployment tut-deploy-web -n tutorial-workload-controllers
kubectl get replicaset -n tutorial-workload-controllers
kubectl get pods -n tutorial-workload-controllers
```

Notice the hierarchy: the Deployment created one ReplicaSet, which created 3 pods. The ReplicaSet name includes a hash suffix (e.g., `tut-deploy-web-7d4f8b6c9`). This hash is derived from the pod template, so a different template produces a different ReplicaSet name.

### 3.2 Inspecting the Ownership Chain

Kubernetes tracks controller ownership through `ownerReferences` in each object's metadata. Let's trace the chain from pod to Deployment:

```bash
# Get a pod name
POD=$(kubectl get pods -n tutorial-workload-controllers -l app=tut-deploy-web \
  -o jsonpath='{.items[0].metadata.name}')

# Check the pod's owner (should be a ReplicaSet)
kubectl get pod $POD -n tutorial-workload-controllers \
  -o jsonpath='{.metadata.ownerReferences[0].kind} {.metadata.ownerReferences[0].name}' ; echo

# Get the ReplicaSet name
RS=$(kubectl get pod $POD -n tutorial-workload-controllers \
  -o jsonpath='{.metadata.ownerReferences[0].name}')

# Check the ReplicaSet's owner (should be a Deployment)
kubectl get rs $RS -n tutorial-workload-controllers \
  -o jsonpath='{.metadata.ownerReferences[0].kind} {.metadata.ownerReferences[0].name}' ; echo
```

This ownership chain is how garbage collection works: deleting the Deployment cascades to its ReplicaSets, which cascades to their pods.

### 3.3 Rolling Updates with kubectl set image

Trigger a rolling update by changing the container image:

```bash
kubectl set image deployment/tut-deploy-web nginx=nginx:1.26-alpine \
  -n tutorial-workload-controllers
```

Watch the rollout progress:

```bash
kubectl rollout status deployment/tut-deploy-web -n tutorial-workload-controllers
```

This command blocks until the rollout completes. While it runs, in another terminal you can watch pods being created and terminated:

```bash
kubectl get pods -n tutorial-workload-controllers -l app=tut-deploy-web -w
```

After the rollout completes, inspect the ReplicaSets:

```bash
kubectl get rs -n tutorial-workload-controllers
```

You should see two ReplicaSets: the old one (scaled to 0 replicas) and the new one (scaled to 3 replicas). The Deployment keeps the old ReplicaSet around for rollback purposes.

### 3.4 Rollout History

View the revision history:

```bash
kubectl rollout history deployment/tut-deploy-web -n tutorial-workload-controllers
```

This shows revision numbers. To see what changed in a specific revision:

```bash
kubectl rollout history deployment/tut-deploy-web -n tutorial-workload-controllers --revision=2
```

The `revisionHistoryLimit` field in the Deployment spec controls how many old ReplicaSets are kept. The default is 10. Setting it to 0 means old ReplicaSets are garbage collected immediately, which makes rollback impossible.

### 3.5 Rolling Back

Roll back to the previous revision:

```bash
kubectl rollout undo deployment/tut-deploy-web -n tutorial-workload-controllers
```

Verify the rollback:

```bash
kubectl rollout status deployment/tut-deploy-web -n tutorial-workload-controllers
kubectl get pods -n tutorial-workload-controllers -l app=tut-deploy-web \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'
```

The image should be back to `nginx:1.25`. Notice that the rollback created a new revision number in the history (it doesn't revert the revision counter).

To roll back to a specific revision (not just the previous one):

```bash
# First, do another image change so we have multiple revisions
kubectl set image deployment/tut-deploy-web nginx=nginx:1.26-alpine \
  -n tutorial-workload-controllers
kubectl rollout status deployment/tut-deploy-web -n tutorial-workload-controllers

# Check history
kubectl rollout history deployment/tut-deploy-web -n tutorial-workload-controllers

# Roll back to a specific revision
kubectl rollout undo deployment/tut-deploy-web -n tutorial-workload-controllers --to-revision=1
kubectl rollout status deployment/tut-deploy-web -n tutorial-workload-controllers
```

### 3.6 RollingUpdate Strategy: maxSurge and maxUnavailable

The default update strategy is `RollingUpdate` with `maxSurge: 25%` and `maxUnavailable: 25%`. These fields control the pace of the rollout:

- **maxSurge:** How many pods above the desired count can exist during the rollout. With 4 replicas and maxSurge of 1, the rollout can have at most 5 pods at any point.
- **maxUnavailable:** How many pods below the desired count can be unavailable during the rollout. With 4 replicas and maxUnavailable of 0, the rollout must always have at least 4 Ready pods.

Create a Deployment with explicit rollout parameters:

```bash
cat <<'EOF' | kubectl apply -n tutorial-workload-controllers -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tut-deploy-controlled
spec:
  replicas: 4
  selector:
    matchLabels:
      app: tut-deploy-controlled
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: tut-deploy-controlled
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
EOF
```

Wait for all 4 replicas to be Ready, then trigger an update:

```bash
kubectl rollout status deployment/tut-deploy-controlled -n tutorial-workload-controllers
kubectl set image deployment/tut-deploy-controlled nginx=nginx:1.26-alpine \
  -n tutorial-workload-controllers
```

With `maxUnavailable: 0`, the rollout will never drop below 4 Ready pods. It creates 1 new pod (maxSurge allows 5 total), waits for it to become Ready, then terminates 1 old pod. It repeats this one-at-a-time process until all pods are updated.

On a kind cluster, the rollout may complete so quickly that you don't see the transient states. This is normal for lightweight images. In production with heavier applications, readiness probes, and external dependencies, these transient states are clearly visible and the strategy parameters matter a great deal.

### 3.7 Failing Rollouts

Not every rollout succeeds. If the new pod template has a problem (bad image tag, crashing container, failing readiness probe), the rollout gets stuck. Let's see this in action:

```bash
kubectl set image deployment/tut-deploy-controlled nginx=nginx:1.99-does-not-exist \
  -n tutorial-workload-controllers
```

Watch the rollout status:

```bash
kubectl rollout status deployment/tut-deploy-controlled -n tutorial-workload-controllers --timeout=30s
```

This will time out. Check what's happening:

```bash
kubectl get pods -n tutorial-workload-controllers -l app=tut-deploy-controlled
kubectl describe deployment tut-deploy-controlled -n tutorial-workload-controllers
```

You'll see that the new pod is stuck in `ImagePullBackOff` or `ErrImagePull`. The old ReplicaSet is still serving with its pods (because maxUnavailable is 0, the Deployment never terminated any old pods before verifying the new ones were Ready). This is the beauty of rolling updates: a bad rollout doesn't take down the existing service.

The `progressDeadlineSeconds` field (default 600, i.e. 10 minutes) controls how long the Deployment controller waits before marking the rollout as failed in the Deployment's conditions. A "failed" rollout doesn't auto-rollback; it just marks the condition. You need to explicitly roll back:

```bash
kubectl rollout undo deployment/tut-deploy-controlled -n tutorial-workload-controllers
kubectl rollout status deployment/tut-deploy-controlled -n tutorial-workload-controllers
```

The Deployment returns to a healthy state using the previous revision's template.

### 3.8 Recreate Strategy

The `Recreate` strategy is the alternative to `RollingUpdate`. It terminates all existing pods before creating new ones. This means a brief period of zero availability, but it guarantees no overlap between old and new versions. This is useful for workloads that cannot tolerate two versions running simultaneously, like database migrations or singleton workers.

```bash
cat <<'EOF' | kubectl apply -n tutorial-workload-controllers -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tut-deploy-recreate
spec:
  replicas: 3
  selector:
    matchLabels:
      app: tut-deploy-recreate
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: tut-deploy-recreate
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
EOF
```

Wait for it to be ready, then update:

```bash
kubectl rollout status deployment/tut-deploy-recreate -n tutorial-workload-controllers
kubectl set image deployment/tut-deploy-recreate nginx=nginx:1.26-alpine \
  -n tutorial-workload-controllers
```

If you watch the pods, you'll see all 3 old pods terminate before any new pods are created:

```bash
kubectl get pods -n tutorial-workload-controllers -l app=tut-deploy-recreate -w
```

### 3.9 Declarative Workflow

Everything above used imperative commands. For the declarative approach, you edit YAML and apply it. Here is the full cycle:

```bash
cat <<'EOF' > /tmp/tut-deploy-declarative.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tut-deploy-declarative
  namespace: tutorial-workload-controllers
spec:
  replicas: 3
  selector:
    matchLabels:
      app: tut-deploy-declarative
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: tut-deploy-declarative
    spec:
      containers:
        - name: web
          image: nginx:1.25
          ports:
            - containerPort: 80
EOF

kubectl apply -f /tmp/tut-deploy-declarative.yaml
kubectl rollout status deployment/tut-deploy-declarative -n tutorial-workload-controllers
```

To trigger a rollout declaratively, edit the file and apply again:

```bash
sed -i 's|nginx:1.25|nginx:1.26-alpine|' /tmp/tut-deploy-declarative.yaml
kubectl apply -f /tmp/tut-deploy-declarative.yaml
kubectl rollout status deployment/tut-deploy-declarative -n tutorial-workload-controllers
```

Check the rollout history:

```bash
kubectl rollout history deployment/tut-deploy-declarative -n tutorial-workload-controllers
```

### 3.10 Rollout Triggers and Non-Triggers

A rollout is triggered when the **pod template** changes. This includes changes to container images, environment variables, resource limits, labels on the template, and any other field inside `.spec.template`. Changes to fields outside the template (like `.spec.replicas` or `.spec.strategy`) do not trigger a rollout. Scaling changes replicas without creating a new ReplicaSet.

One common pitfall: using the `latest` tag. If your Deployment already specifies `image: myapp:latest` and you apply the same YAML again, the template hasn't changed from the Deployment's perspective, so no rollout happens, even if the image behind the `latest` tag has been updated in the registry. This is why pinned tags (like `nginx:1.25`) are strongly recommended.

### 3.11 Selector Immutability

The Deployment's `.spec.selector` is effectively immutable after creation. If you try to change it with `kubectl apply`, the API server rejects the update. The workaround is to delete the Deployment and recreate it with the new selector. The template labels (`.spec.template.metadata.labels`) can have additional labels beyond what the selector requires, but the selector labels must always be present in the template.

### 3.12 Garbage Collection

Delete the controlled Deployment and watch the cascade:

```bash
kubectl get rs -n tutorial-workload-controllers -l app=tut-deploy-controlled
kubectl get pods -n tutorial-workload-controllers -l app=tut-deploy-controlled
kubectl delete deployment tut-deploy-controlled -n tutorial-workload-controllers
# After a few seconds:
kubectl get rs -n tutorial-workload-controllers -l app=tut-deploy-controlled
kubectl get pods -n tutorial-workload-controllers -l app=tut-deploy-controlled
```

Both the ReplicaSets and the pods are gone. This is the default cascade behavior. The `--cascade=orphan` flag prevents this, leaving the ReplicaSets (and their pods) as orphans.

---

## Part 4: DaemonSets

A DaemonSet ensures that exactly one copy of a pod runs on every node in the cluster (or on a selected subset of nodes). When a new node joins the cluster, the DaemonSet controller automatically schedules a pod onto it. When a node is removed, the pod is garbage collected. This makes DaemonSets the right tool for per-node workloads like log collectors, metrics exporters, network plugins, and storage agents.

### 4.1 Creating a Basic DaemonSet

```bash
cat <<'EOF' | kubectl apply -n tutorial-workload-controllers -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: tut-ds-logger
spec:
  selector:
    matchLabels:
      app: tut-ds-logger
  template:
    metadata:
      labels:
        app: tut-ds-logger
    spec:
      containers:
        - name: logger
          image: busybox:1.36
          command: ["sh", "-c", "while true; do echo \"$(date) running on $(hostname)\"; sleep 30; done"]
EOF
```

Check where the pods were placed:

```bash
kubectl get pods -n tutorial-workload-controllers -l app=tut-ds-logger -o wide
```

You should see one pod on each of the three worker nodes, but none on the control-plane node. The control-plane node has a taint (`node-role.kubernetes.io/control-plane:NoSchedule`) that prevents regular workloads from being scheduled there.

### 4.2 DaemonSet Status Fields

Inspect the DaemonSet status:

```bash
kubectl get ds tut-ds-logger -n tutorial-workload-controllers
```

The output shows: DESIRED (how many pods should exist, one per eligible node), CURRENT (how many pods exist), READY (how many pods are passing readiness checks), UP-TO-DATE (how many pods match the current template), AVAILABLE (how many pods have been ready long enough), and NODE SELECTOR (if any node selector is specified).

For more detail:

```bash
kubectl describe ds tut-ds-logger -n tutorial-workload-controllers
```

### 4.3 Node Selection with nodeSelector

You can restrict a DaemonSet to only some nodes using a `nodeSelector` on the pod template. Label one worker node and create a targeted DaemonSet:

```bash
kubectl label node kind-worker workload=logging
```

```bash
cat <<'EOF' | kubectl apply -n tutorial-workload-controllers -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: tut-ds-targeted
spec:
  selector:
    matchLabels:
      app: tut-ds-targeted
  template:
    metadata:
      labels:
        app: tut-ds-targeted
    spec:
      nodeSelector:
        workload: logging
      containers:
        - name: logger
          image: busybox:1.36
          command: ["sh", "-c", "while true; do echo targeted logger on $(hostname); sleep 30; done"]
EOF
```

```bash
kubectl get pods -n tutorial-workload-controllers -l app=tut-ds-targeted -o wide
```

Only `kind-worker` should have a pod. Now label another node and watch the DaemonSet respond:

```bash
kubectl label node kind-worker2 workload=logging
kubectl get pods -n tutorial-workload-controllers -l app=tut-ds-targeted -o wide
```

A second pod appears on `kind-worker2`. Remove the label from `kind-worker` and the pod is evicted:

```bash
kubectl label node kind-worker workload-
kubectl get pods -n tutorial-workload-controllers -l app=tut-ds-targeted -o wide
```

Clean up labels:

```bash
kubectl label node kind-worker2 workload-
```

### 4.4 Taints, Tolerations, and the Control-Plane

The default DaemonSet doesn't run on the control-plane because of the `node-role.kubernetes.io/control-plane:NoSchedule` taint. Cluster-critical agents (like CNI plugins and log collectors) need to run on every node, including the control-plane. They achieve this by adding a toleration for the control-plane taint.

First, verify the control-plane taint:

```bash
kubectl describe node kind-control-plane | grep -A5 Taints
```

Now create a DaemonSet that tolerates the control-plane taint:

```bash
cat <<'EOF' | kubectl apply -n tutorial-workload-controllers -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: tut-ds-everywhere
spec:
  selector:
    matchLabels:
      app: tut-ds-everywhere
  template:
    metadata:
      labels:
        app: tut-ds-everywhere
    spec:
      tolerations:
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      containers:
        - name: agent
          image: busybox:1.36
          command: ["sh", "-c", "while true; do echo cluster-agent on $(hostname); sleep 60; done"]
EOF
```

```bash
kubectl get pods -n tutorial-workload-controllers -l app=tut-ds-everywhere -o wide
```

Now you should see 4 pods: one on each worker plus one on the control-plane node. This is the pattern used by real cluster agents. Some agents go even further and tolerate **all** taints so they run on every node regardless of what custom taints exist:

```yaml
tolerations:
  - operator: Exists
```

This tolerates any taint on any node.

### 4.5 Taint-Based Pod Eviction

Add a taint to a worker node and observe the DaemonSet behavior:

```bash
kubectl taint nodes kind-worker3 maintenance=true:NoSchedule
kubectl get pods -n tutorial-workload-controllers -l app=tut-ds-logger -o wide
```

The `tut-ds-logger` DaemonSet does not tolerate this taint, so the pod on `kind-worker3` is not evicted (NoSchedule only prevents new pods from being scheduled; it doesn't evict existing pods). However, if you use `NoExecute` instead:

```bash
kubectl taint nodes kind-worker3 maintenance=true:NoSchedule-
kubectl taint nodes kind-worker3 maintenance=true:NoExecute
kubectl get pods -n tutorial-workload-controllers -l app=tut-ds-logger -o wide
```

Now the pod on `kind-worker3` is evicted because the DaemonSet doesn't have a toleration for the `NoExecute` taint.

Remove the taint and watch the pod return:

```bash
kubectl taint nodes kind-worker3 maintenance=true:NoExecute-
kubectl get pods -n tutorial-workload-controllers -l app=tut-ds-logger -o wide
```

### 4.6 DaemonSet Update Strategies

DaemonSets support two update strategies:

**RollingUpdate (default):** When the template changes, the DaemonSet controller updates pods one node at a time. The `maxUnavailable` field controls how many nodes can have their pods down simultaneously during the update (default is 1).

```bash
kubectl set image ds/tut-ds-logger logger=busybox:1.37 -n tutorial-workload-controllers
kubectl rollout status ds/tut-ds-logger -n tutorial-workload-controllers
```

**OnDelete:** Pods are only updated when you manually delete them. The controller creates a replacement with the new template only when an old pod is removed. This gives you full control over the rollout pace and is used in environments where uncontrolled updates are unacceptable.

To set OnDelete, you would include this in the DaemonSet spec:

```yaml
updateStrategy:
  type: OnDelete
```

With OnDelete, after changing the template, you would delete pods one at a time on each node and let the DaemonSet recreate them.

### 4.7 DaemonSet Rollout History

Like Deployments, DaemonSets support rollout history and undo:

```bash
kubectl rollout history ds/tut-ds-logger -n tutorial-workload-controllers
kubectl rollout undo ds/tut-ds-logger -n tutorial-workload-controllers
kubectl rollout status ds/tut-ds-logger -n tutorial-workload-controllers
```

In practice, DaemonSet rollbacks are less common than Deployment rollbacks, but the commands work identically.

---

## Part 5: Cross-Controller Concepts

### 5.1 Labels and Selectors as Glue

Labels and selectors are the fundamental mechanism that connects controllers to pods. Every controller finds "its" pods by querying the API for pods matching its selector. This has a crucial implication: if two controllers have overlapping selectors (they both match the same labels), they will both try to manage the same pods. The controllers will fight, each trying to reconcile toward its own desired state, creating and deleting pods in an unstable loop.

Good label hygiene prevents this. Each controller in a namespace should have a unique selector that matches only its own pods. The simplest pattern is to give each controller a unique `app` label value:

```yaml
# Controller A
selector:
  matchLabels:
    app: frontend
# Controller B
selector:
  matchLabels:
    app: backend
```

If you need to group controllers for organizational purposes, use additional labels that aren't part of any selector:

```yaml
template:
  metadata:
    labels:
      app: frontend        # Used by the selector
      team: platform        # Organizational, not selected on
      version: v2           # Informational, not selected on
```

### 5.2 The Controller Reconciliation Loop

All three controllers operate on the same core loop:

1. Observe current state (count pods matching the selector)
2. Compare against desired state (replicas count or node set)
3. Take corrective action (create pods if too few, delete if too many)
4. Repeat

This is a declarative model. You don't tell the controller "create 3 pods." You tell it "the desired state is 3 replicas" and it figures out what actions are needed. If you manually delete a pod, the controller creates a replacement. If you manually create a pod with matching labels, the controller may delete it if the count exceeds the desired state.

---

## Tutorial Cleanup

Remove all tutorial resources:

```bash
kubectl delete namespace tutorial-workload-controllers
```

Remove any node labels applied during the tutorial:

```bash
kubectl label node kind-worker workload- 2>/dev/null
kubectl label node kind-worker2 workload- 2>/dev/null
```

Verify no tutorial taints remain:

```bash
kubectl describe nodes | grep -A2 Taints
```

---

## Reference: Controller Comparison Table

| Aspect | ReplicaSet | Deployment | DaemonSet |
|--------|-----------|------------|-----------|
| **Purpose** | Maintain a fixed number of identical pod replicas | Manage stateless application rollouts and rollbacks | Run exactly one pod per node (or per selected node) |
| **Typical use case** | Rarely used directly; created by Deployments | Web servers, API servers, stateless microservices | Log collectors, metrics agents, CNI plugins, storage drivers |
| **What it manages** | Pods (directly) | ReplicaSet(s), which manage pods | Pods (directly, one per node) |
| **Scaling** | `kubectl scale rs` or edit replicas field | `kubectl scale deployment` or edit replicas field | Automatic: scales with the number of eligible nodes |
| **Update strategy** | None (template changes don't affect existing pods) | RollingUpdate (default) or Recreate | RollingUpdate (default) or OnDelete |
| **RollingUpdate fields** | N/A | maxSurge, maxUnavailable | maxUnavailable, maxSurge (v1.31+) |
| **Rollback** | N/A | `kubectl rollout undo` with revision history | `kubectl rollout undo` |
| **When to use** | Almost never directly; understand for CKA exam | Default choice for stateless workloads | Per-node infrastructure agents |

---

## Reference: Rollout Commands Cheat Sheet

All commands work for both Deployments and DaemonSets.

```bash
# Watch a rollout in progress
kubectl rollout status deployment/<name> -n <ns>

# View rollout history (all revisions)
kubectl rollout history deployment/<name> -n <ns>

# View details of a specific revision
kubectl rollout history deployment/<name> -n <ns> --revision=<N>

# Roll back to the previous revision
kubectl rollout undo deployment/<name> -n <ns>

# Roll back to a specific revision
kubectl rollout undo deployment/<name> -n <ns> --to-revision=<N>

# Pause a rollout (useful for canary-style inspection)
kubectl rollout pause deployment/<name> -n <ns>

# Resume a paused rollout
kubectl rollout resume deployment/<name> -n <ns>

# Restart a rollout (triggers a fresh rollout with no spec change)
kubectl rollout restart deployment/<name> -n <ns>
```

Important distinction: `kubectl rollout restart` bumps a template annotation to trigger a new rollout using the current template (useful when you want pods recreated without changing the spec). `kubectl rollout undo` reverts the template to a previous revision. These are different operations.

---

## Reference: Imperative and Declarative Quick Reference

### ReplicaSets

```bash
# Create (YAML only, no imperative shortcut for ReplicaSets)
kubectl apply -f replicaset.yaml

# Scale
kubectl scale rs <name> --replicas=<N> -n <ns>

# Delete (with cascade)
kubectl delete rs <name> -n <ns>

# Delete (orphan pods)
kubectl delete rs <name> -n <ns> --cascade=orphan
```

### Deployments

```bash
# Create imperatively
kubectl create deployment <name> --image=<image> --replicas=<N> -n <ns>

# Scale
kubectl scale deployment <name> --replicas=<N> -n <ns>

# Update image (triggers rollout)
kubectl set image deployment/<name> <container>=<image> -n <ns>

# Edit live (triggers rollout if template changes)
kubectl edit deployment <name> -n <ns>

# Generate YAML (dry run)
kubectl create deployment <name> --image=<image> --replicas=<N> \
  --dry-run=client -o yaml > deployment.yaml
```

### DaemonSets

```bash
# Create (YAML only, no imperative shortcut for DaemonSets)
kubectl apply -f daemonset.yaml

# Update image (triggers rollout with RollingUpdate strategy)
kubectl set image ds/<name> <container>=<image> -n <ns>

# Generate base YAML (create a Deployment dry-run and convert)
kubectl create deployment temp --image=<image> --dry-run=client -o yaml | \
  sed 's/kind: Deployment/kind: DaemonSet/' > ds-base.yaml
# Note: this produces a starting point that needs manual editing
# (remove replicas, change strategy to updateStrategy, adjust selector)
```

---

## Reference: Label Hygiene

**Rule 1:** The selector's labels must be a subset of the template's labels. The template can have extra labels, but it must include everything the selector matches on.

**Rule 2:** Each controller's selector should be unique within the namespace. If two controllers select the same labels, they will fight over the pods.

**Rule 3:** The selector is immutable after creation. You cannot change it with `kubectl apply`. To change a selector, delete the controller and recreate it.

**Rule 4:** Template labels can be modified (they are not immutable like the selector), but changing the selector-matched labels in the template without changing the selector will break the controller (the selector no longer matches the template, and the API server rejects the update).

**Common pattern for multiple controllers in one namespace:**

```yaml
# Frontend Deployment
selector:
  matchLabels:
    app: myapp
    component: frontend

# Backend Deployment
selector:
  matchLabels:
    app: myapp
    component: backend

# Logging DaemonSet
selector:
  matchLabels:
    app: myapp
    component: logging
```

Each controller has a unique `component` value, so their selectors never overlap.

---

## Reference: Diagnostic Workflow for Stuck Rollouts

When a Deployment rollout isn't progressing, work through this sequence:

```bash
# 1. Check rollout status (is it stuck?)
kubectl rollout status deployment/<name> -n <ns> --timeout=10s

# 2. Describe the Deployment (check conditions and events)
kubectl describe deployment <name> -n <ns>
# Look for: Progressing condition, Available condition, events about scaling

# 3. Check the ReplicaSets (is the new one scaling up?)
kubectl get rs -n <ns> -l <selector-label>
# The new RS should be scaling up; the old RS should be scaling down

# 4. Check the pods (what state are the new pods in?)
kubectl get pods -n <ns> -l <selector-label>
# Look for: ImagePullBackOff, CrashLoopBackOff, Pending, not Ready

# 5. Describe a failing pod (get the specific error)
kubectl describe pod <failing-pod> -n <ns>
# Look for: Events section, especially Failed/Warning events

# 6. Check pod logs if it started but is unhealthy
kubectl logs <pod-name> -n <ns>

# Common root causes:
# - ImagePullBackOff: bad image tag or registry auth issue
# - CrashLoopBackOff: container starts and immediately crashes
# - Readiness probe failure: container is running but probe fails, so
#   the pod never becomes Ready and the rollout can't progress
# - Resource shortage: pod can't be scheduled (check Pending status)
# - Selector mismatch: new pods aren't selected by the Deployment
#   (extremely rare, usually caught at validation time)
```
