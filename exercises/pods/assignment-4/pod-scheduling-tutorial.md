# Pod Scheduling and Placement: Tutorial

**Assignment 4 in the CKA Pod Fundamentals Series**

This tutorial walks through every scheduling mechanism you need for the CKA exam, in the order a learner should encounter them. Each section introduces a mechanism, explains how the scheduler uses it, shows a success case where a pod lands on the expected node, and shows a failure case where a pod stays Pending so you can practice reading the FailedScheduling event.

Work through this tutorial from start to finish before attempting the exercises. Type along rather than just reading. The tutorial uses its own namespace (`tutorial-pod-scheduling`), its own node label prefix (`tutorial/`), and its own resource names, so nothing here conflicts with the exercises.

---

## Table of Contents

1. [Cluster Setup](#1-cluster-setup)
2. [How the Scheduler Works](#2-how-the-scheduler-works)
3. [Manual Scheduling with nodeName](#3-manual-scheduling-with-nodename)
4. [Node Labels and nodeSelector](#4-node-labels-and-nodeselector)
5. [Node Affinity](#5-node-affinity)
6. [Pod Affinity and Pod Anti-Affinity](#6-pod-affinity-and-pod-anti-affinity)
7. [Taints and Tolerations](#7-taints-and-tolerations)
8. [Topology Spread Constraints](#8-topology-spread-constraints)
9. [Priority Classes](#9-priority-classes)
10. [Reading FailedScheduling Events](#10-reading-failedscheduling-events)
11. [Dedicated-Node Pattern](#11-dedicated-node-pattern)
12. [Scheduling Mechanism Decision Table](#12-scheduling-mechanism-decision-table)
13. [Reference Commands](#13-reference-commands)
14. [Tutorial Cleanup](#14-tutorial-cleanup)

---

## 1. Cluster Setup

This tutorial requires a multi-node kind cluster. If you have not already created one, follow the instructions in `README.md`. You need 1 control-plane node and 3 worker nodes.

Verify your cluster:

```bash
kubectl get nodes
```

You should see four nodes:

```
NAME                           STATUS   ROLES           AGE   VERSION
scheduling-lab-control-plane   Ready    control-plane   ...   ...
scheduling-lab-worker          Ready    <none>          ...   ...
scheduling-lab-worker2         Ready    <none>          ...   ...
scheduling-lab-worker3         Ready    <none>          ...   ...
```

Create the tutorial namespace:

```bash
kubectl create namespace tutorial-pod-scheduling
```

Throughout this tutorial, every kubectl command that operates on namespaced resources uses `-n tutorial-pod-scheduling` explicitly.

---

## 2. How the Scheduler Works

When you create a pod without specifying a `nodeName`, the Kubernetes scheduler (kube-scheduler) decides which node to place it on. The scheduler runs a two-phase process for every unscheduled pod.

**Phase 1: Filtering (Predicates).** The scheduler eliminates nodes that cannot run the pod. Reasons a node gets filtered out include: the node has a taint the pod does not tolerate, the node does not match the pod's nodeSelector or required node affinity, the node does not have enough CPU or memory to satisfy the pod's resource requests, and the node is marked unschedulable. After filtering, the scheduler has a list of feasible nodes.

**Phase 2: Scoring (Priorities).** The scheduler ranks the feasible nodes by desirability. Scoring factors include: how well the node matches the pod's preferred node affinity (and the weights assigned to each preference), how evenly pods are spread across nodes, and how much free capacity the node has. The node with the highest score wins.

If no nodes survive filtering, the pod stays in the `Pending` state and the scheduler records a `FailedScheduling` event on the pod. This event message is your primary diagnostic tool.

**What Pending means.** A pod in Pending state has been accepted by the API server but has not been assigned to a node. The most common reason is that no node satisfies the pod's scheduling constraints. The second most common reason is that the pod's resource requests exceed available capacity on all nodes.

You can always check why a pod is Pending:

```bash
kubectl describe pod <pod-name> -n <namespace>
```

Look at the `Events` section at the bottom of the output. A `FailedScheduling` event will tell you exactly which constraints failed and on how many nodes.

---

## 3. Manual Scheduling with nodeName

The simplest way to place a pod on a specific node is to set the `nodeName` field in the pod spec. This bypasses the scheduler entirely: the API server sends the pod directly to the named kubelet.

### When to Use nodeName

Manual scheduling with nodeName is appropriate for debugging (testing whether a specific node can run a pod at all), for understanding how static pods work (which always target a specific node), and for one-off diagnostic pods. It is not appropriate for production workloads because it bypasses all scheduler logic: no resource checking, no affinity evaluation, no preemption, and no FailedScheduling events if something goes wrong. If the named node does not exist or is unreachable, the pod simply fails silently.

### Success Case

```yaml
# Save as tutorial-nodename-success.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-nodename-success
  namespace: tutorial-pod-scheduling
spec:
  nodeName: scheduling-lab-worker
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f tutorial-nodename-success.yaml
kubectl get pod tutorial-nodename-success -n tutorial-pod-scheduling -o wide
```

The pod should show `Running` on `scheduling-lab-worker`. Notice that the NODE column confirms placement.

### Failure Case

```yaml
# Save as tutorial-nodename-fail.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-nodename-fail
  namespace: tutorial-pod-scheduling
spec:
  nodeName: nonexistent-node
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f tutorial-nodename-fail.yaml
kubectl get pod tutorial-nodename-fail -n tutorial-pod-scheduling
```

The pod will stay `Pending` indefinitely, but notice: there is no `FailedScheduling` event in `kubectl describe pod`. The scheduler was never involved. This is the key diagnostic difference between nodeName failures and scheduler failures.

```bash
kubectl describe pod tutorial-nodename-fail -n tutorial-pod-scheduling
```

You will see `Status: Pending` and `Node: nonexistent-node`, but no Events from the scheduler. The pod is bound to a node that does not exist, and nothing will fix it short of deleting and recreating the pod.

Clean up the failure case:

```bash
kubectl delete pod tutorial-nodename-fail -n tutorial-pod-scheduling
```

---

## 4. Node Labels and nodeSelector

### Understanding Node Labels

Every node in Kubernetes has labels, which are key-value pairs attached to the node object. Some labels are added automatically (well-known labels), and you can add custom labels for your own scheduling logic.

View all labels on your nodes:

```bash
kubectl get nodes --show-labels
```

The output is wide and hard to read. To see labels for a specific node in a cleaner format:

```bash
kubectl describe node scheduling-lab-worker | head -20
```

Look for the `Labels:` section. You will see well-known labels like:

- `kubernetes.io/hostname` -- the node's hostname (always present, set automatically)
- `kubernetes.io/os` -- the operating system (e.g., `linux`)
- `kubernetes.io/arch` -- the CPU architecture (e.g., `amd64`, `arm64`)
- `node-role.kubernetes.io/control-plane` -- present on control-plane nodes only

### Adding Custom Labels

Add a custom label to a node imperatively:

```bash
kubectl label nodes scheduling-lab-worker tutorial/disktype=ssd
```

Verify:

```bash
kubectl get node scheduling-lab-worker --show-labels | grep tutorial
```

Or more precisely with jsonpath:

```bash
kubectl get node scheduling-lab-worker -o jsonpath='{.metadata.labels.tutorial\/disktype}'
echo  # newline
```

Output: `ssd`

### nodeSelector

The `nodeSelector` field in a pod spec is the simplest scheduling constraint. It is a hard match: the pod will only be scheduled on a node whose labels contain every key-value pair in the nodeSelector. If no node matches, the pod stays Pending.

#### Success Case

```yaml
# Save as tutorial-nodeselector-success.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-nodeselector-success
  namespace: tutorial-pod-scheduling
spec:
  nodeSelector:
    tutorial/disktype: ssd
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f tutorial-nodeselector-success.yaml
kubectl get pod tutorial-nodeselector-success -n tutorial-pod-scheduling -o wide
```

The pod should be Running on `scheduling-lab-worker` (the only node with `tutorial/disktype=ssd`).

#### Failure Case

```yaml
# Save as tutorial-nodeselector-fail.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-nodeselector-fail
  namespace: tutorial-pod-scheduling
spec:
  nodeSelector:
    tutorial/disktype: nvme
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f tutorial-nodeselector-fail.yaml
kubectl get pod tutorial-nodeselector-fail -n tutorial-pod-scheduling
```

The pod stays `Pending`. Now inspect the event:

```bash
kubectl describe pod tutorial-nodeselector-fail -n tutorial-pod-scheduling
```

In the Events section, you will see a `FailedScheduling` event with a message like:

```
0/4 nodes are available: 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }, 3 node(s) didn't match Pod's node affinity/selector.
```

This message tells you: out of 4 total nodes, 3 workers did not match the nodeSelector (none have `tutorial/disktype=nvme`), and 1 control-plane node was excluded because of its taint.

#### Limitations of nodeSelector

nodeSelector only supports exact key-value equality. You cannot express "schedule on nodes where zone is us-east-1a OR us-east-1b" or "schedule on any node that has a gpu label, regardless of value." For these, you need node affinity.

Clean up the failure case:

```bash
kubectl delete pod tutorial-nodeselector-fail -n tutorial-pod-scheduling
```

---

## 5. Node Affinity

Node affinity is the more expressive successor to nodeSelector. It supports set-based operators (`In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt`, `Lt`) and distinguishes between hard requirements and soft preferences.

### Node Affinity Types

**`requiredDuringSchedulingIgnoredDuringExecution`** (hard): The pod will not be scheduled unless a node matches. Equivalent to nodeSelector but with richer operators. If no node matches, the pod stays Pending.

**`preferredDuringSchedulingIgnoredDuringExecution`** (soft): The scheduler prefers nodes that match but will schedule the pod on a non-matching node if necessary. Each preference has a `weight` (1-100); the scheduler adds the weight to the node's score for each satisfied preference.

**The "IgnoredDuringExecution" suffix** means that affinity rules are evaluated only at scheduling time. Once a pod is placed on a node, changing that node's labels will not cause the pod to be evicted or rescheduled. This is an important behavioral detail for the exam: if you label a node after a pod is already running, the pod does not move.

### matchExpressions Structure

Node affinity uses `matchExpressions`, which is a list of conditions. Each expression has three fields:

- `key`: the label key to match against
- `operator`: one of `In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt`, `Lt`
- `values`: a list of values (required for `In`, `NotIn`, `Gt`, `Lt`; must be omitted for `Exists` and `DoesNotExist`)

All expressions within a single `nodeSelectorTerms` entry are ANDed together (all must match). Multiple `nodeSelectorTerms` entries are ORed (any one term matching is sufficient).

### Operators

| Operator | Meaning | Values field |
|----------|---------|-------------|
| `In` | Label value is in the provided list | Required, one or more values |
| `NotIn` | Label value is not in the provided list | Required, one or more values |
| `Exists` | Label key exists, any value | Must be omitted |
| `DoesNotExist` | Label key does not exist | Must be omitted |
| `Gt` | Label value (parsed as integer) is greater than the provided value | Required, exactly one value |
| `Lt` | Label value (parsed as integer) is less than the provided value | Required, exactly one value |

**Common pitfall with Exists:** The `Exists` operator ignores the `values` field entirely. If you accidentally include `values: ["anything"]`, it does not cause an error but the value is silently ignored. The expression matches any node that has the key, regardless of value.

### Success Case: Required Node Affinity

First, add labels to two nodes to simulate availability zones:

```bash
kubectl label nodes scheduling-lab-worker tutorial/zone=us-east-1a
kubectl label nodes scheduling-lab-worker2 tutorial/zone=us-east-1b
```

Now create a pod that requires a node in either zone:

```yaml
# Save as tutorial-affinity-required.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-affinity-required
  namespace: tutorial-pod-scheduling
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: tutorial/zone
                operator: In
                values:
                  - us-east-1a
                  - us-east-1b
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f tutorial-affinity-required.yaml
kubectl get pod tutorial-affinity-required -n tutorial-pod-scheduling -o wide
```

The pod should be Running on either `scheduling-lab-worker` or `scheduling-lab-worker2` (both have matching zone labels). It will not land on `scheduling-lab-worker3` (no zone label) or the control-plane.

### Success Case: Preferred Node Affinity

```yaml
# Save as tutorial-affinity-preferred.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-affinity-preferred
  namespace: tutorial-pod-scheduling
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 80
          preference:
            matchExpressions:
              - key: tutorial/disktype
                operator: In
                values:
                  - ssd
        - weight: 20
          preference:
            matchExpressions:
              - key: tutorial/zone
                operator: In
                values:
                  - us-east-1b
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f tutorial-affinity-preferred.yaml
kubectl get pod tutorial-affinity-preferred -n tutorial-pod-scheduling -o wide
```

The scheduler prefers `scheduling-lab-worker` (which has `tutorial/disktype=ssd`, weight 80) over `scheduling-lab-worker2` (which has `tutorial/zone=us-east-1b`, weight 20). But if `scheduling-lab-worker` were under heavy resource pressure, the scheduler could place the pod on any other worker. Preferred is a preference, not a guarantee.

### Failure Case: Required Affinity with No Matching Nodes

```yaml
# Save as tutorial-affinity-fail.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-affinity-fail
  namespace: tutorial-pod-scheduling
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: tutorial/zone
                operator: In
                values:
                  - eu-west-1a
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f tutorial-affinity-fail.yaml
kubectl get pod tutorial-affinity-fail -n tutorial-pod-scheduling
```

The pod stays Pending. Check the event:

```bash
kubectl describe pod tutorial-affinity-fail -n tutorial-pod-scheduling
```

The FailedScheduling message will indicate that worker nodes did not match the pod's node affinity and the control-plane had an untolerated taint. No node has `tutorial/zone=eu-west-1a`.

Clean up:

```bash
kubectl delete pod tutorial-affinity-fail -n tutorial-pod-scheduling
```

### Node Anti-Affinity

Kubernetes does not have a separate "node anti-affinity" resource. Instead, you express anti-affinity using `NotIn` or `DoesNotExist` operators in a node affinity rule. For example, "do not schedule on nodes in zone us-east-1a" becomes a required node affinity with `operator: NotIn, values: [us-east-1a]` on the `tutorial/zone` key.

### Imperative Workflow for Node Affinity

Node affinity cannot be set imperatively with `kubectl run`. The standard workflow is to generate a skeleton and edit it:

```bash
kubectl run my-pod --image=busybox:1.36 --dry-run=client -o yaml \
  --command -- sh -c "echo started; sleep 3600" > pod.yaml
# Then edit pod.yaml to add the affinity block
```

This generate-then-edit pattern applies to node affinity, pod affinity, tolerations, and topology spread constraints. These are all declarative-only in practice.

---

## 6. Pod Affinity and Pod Anti-Affinity

While node affinity controls which nodes a pod can land on based on node labels, pod affinity controls placement based on which other pods are already running. Pod affinity says "schedule me near pods with label X" and pod anti-affinity says "schedule me away from pods with label X."

### Key Concepts

**topologyKey:** Pod affinity and anti-affinity require a `topologyKey`, which is a node label key that defines the "topology domain." Common values are:

- `kubernetes.io/hostname` -- each node is its own domain (per-node placement)
- `topology.kubernetes.io/zone` -- each availability zone is a domain (per-zone placement)

The topologyKey must actually exist as a label on the nodes. If you reference a topologyKey that no node has, the affinity rule silently does nothing (for preferred) or prevents scheduling entirely (for required, since no topology domains exist to satisfy the constraint). This is a common subtle bug.

**labelSelector:** Specifies which pods the rule refers to. Uses standard `matchLabels` or `matchExpressions`, matching against pod labels (not node labels).

### Pod Affinity: Co-locate with Another Pod

This pattern is common for latency-sensitive workloads: "run the frontend on the same node as the cache."

First, create a "cache" pod on any worker node:

```yaml
# Save as tutorial-cache-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-cache
  namespace: tutorial-pod-scheduling
  labels:
    app: tutorial-cache
spec:
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f tutorial-cache-pod.yaml
```

Wait for it to be Running and note which node it landed on:

```bash
kubectl get pod tutorial-cache -n tutorial-pod-scheduling -o wide
```

Now create a "frontend" pod that must be co-located on the same node:

```yaml
# Save as tutorial-podaffinity-colocate.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-frontend
  namespace: tutorial-pod-scheduling
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app: tutorial-cache
          topologyKey: kubernetes.io/hostname
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f tutorial-podaffinity-colocate.yaml
kubectl get pod tutorial-frontend -n tutorial-pod-scheduling -o wide
```

The frontend pod should be on the same node as the cache pod. The `topologyKey: kubernetes.io/hostname` means "same node" because each node has a unique hostname label.

### Pod Anti-Affinity: Spread Pods Across Nodes

This pattern is the opposite: "make sure no two pods with the same label land on the same node." It is commonly used for high-availability deployments.

Create three pods that must each land on a different node. We will create them one at a time so you can watch placement:

```yaml
# Save as tutorial-spread-1.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-spread-1
  namespace: tutorial-pod-scheduling
  labels:
    app: tutorial-spread
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app: tutorial-spread
          topologyKey: kubernetes.io/hostname
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f tutorial-spread-1.yaml
kubectl get pod tutorial-spread-1 -n tutorial-pod-scheduling -o wide
```

The first pod lands on any worker. Now create the second (same YAML, change the name to `tutorial-spread-2`):

```yaml
# Save as tutorial-spread-2.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-spread-2
  namespace: tutorial-pod-scheduling
  labels:
    app: tutorial-spread
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app: tutorial-spread
          topologyKey: kubernetes.io/hostname
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f tutorial-spread-2.yaml
kubectl get pods -n tutorial-pod-scheduling -l app=tutorial-spread -o wide
```

The second pod lands on a different worker than the first. Create the third (`tutorial-spread-3`, identical YAML with name changed):

```yaml
# Save as tutorial-spread-3.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-spread-3
  namespace: tutorial-pod-scheduling
  labels:
    app: tutorial-spread
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app: tutorial-spread
          topologyKey: kubernetes.io/hostname
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f tutorial-spread-3.yaml
kubectl get pods -n tutorial-pod-scheduling -l app=tutorial-spread -o wide
```

All three pods should be on different worker nodes. If you tried to create a fourth pod with the same anti-affinity rule, it would stay Pending because all three workers are occupied.

### Failure Case: Pod Affinity with No Matching Pods

```yaml
# Save as tutorial-podaffinity-fail.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-podaffinity-fail
  namespace: tutorial-pod-scheduling
spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app: nonexistent-app
          topologyKey: kubernetes.io/hostname
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f tutorial-podaffinity-fail.yaml
kubectl get pod tutorial-podaffinity-fail -n tutorial-pod-scheduling
```

The pod stays Pending because no running pod has the label `app=nonexistent-app`. The FailedScheduling event will report that no nodes matched the pod affinity rules.

Clean up:

```bash
kubectl delete pod tutorial-podaffinity-fail -n tutorial-pod-scheduling
```

---

## 7. Taints and Tolerations

Taints and tolerations work together to control which pods can be scheduled on which nodes, but they work in the opposite direction from affinity. A taint on a node repels pods. A toleration on a pod allows it to be scheduled on a tainted node (but does not require it).

This asymmetry is critical: **tolerations allow, they do not attract.** A pod with a toleration for a node's taint can still be scheduled on an untainted node. To ensure a pod runs only on a specific tainted node, you must combine the toleration with nodeSelector or node affinity.

### Taint Effects

| Effect | Behavior |
|--------|----------|
| `NoSchedule` | New pods without a matching toleration will not be scheduled on this node. Existing pods are unaffected. |
| `PreferNoSchedule` | The scheduler tries to avoid placing pods without a matching toleration, but will do so if no other node is available. Soft version of NoSchedule. |
| `NoExecute` | New pods without a matching toleration will not be scheduled, AND existing pods without a matching toleration will be evicted. Tolerations can include `tolerationSeconds` to delay eviction. |

### Adding and Removing Taints

Add a taint to a node:

```bash
kubectl taint nodes scheduling-lab-worker2 tutorial/special=true:NoSchedule
```

This adds a taint with key `tutorial/special`, value `true`, and effect `NoSchedule`.

View taints on a node:

```bash
kubectl describe node scheduling-lab-worker2 | grep -A5 Taints
```

Or with jsonpath:

```bash
kubectl get node scheduling-lab-worker2 -o jsonpath='{.spec.taints}' | python3 -m json.tool
```

Remove a taint (note the `-` at the end):

```bash
kubectl taint nodes scheduling-lab-worker2 tutorial/special=true:NoSchedule-
```

### Toleration Matching Semantics

A toleration matches a taint when:

- The `key` matches
- The `effect` matches (or the toleration's `effect` is empty, matching all effects)
- Either: `operator: Equal` and the `value` matches, OR `operator: Exists` (matches any value for the key)

**Common pitfall with operator Exists:** When using `operator: Exists`, the `value` field must be omitted. If you include a value, it is silently ignored. The toleration matches any taint with the specified key and effect, regardless of value.

**tolerationSeconds:** Only meaningful with effect `NoExecute`. Specifies how long an existing pod can remain on the node after the taint is applied before being evicted. Has no effect on `NoSchedule` or `PreferNoSchedule` taints.

### Success and Failure Case

First, add a taint:

```bash
kubectl taint nodes scheduling-lab-worker2 tutorial/special=true:NoSchedule
```

Try to schedule a pod on that node without a toleration:

```yaml
# Save as tutorial-taint-fail.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-taint-fail
  namespace: tutorial-pod-scheduling
spec:
  nodeSelector:
    kubernetes.io/hostname: scheduling-lab-worker2
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f tutorial-taint-fail.yaml
kubectl get pod tutorial-taint-fail -n tutorial-pod-scheduling
```

The pod stays Pending. Check the event:

```bash
kubectl describe pod tutorial-taint-fail -n tutorial-pod-scheduling
```

The FailedScheduling message will say something like: `0/4 nodes are available: 1 node(s) had untolerated taint {tutorial/special: true}, 2 node(s) didn't match Pod's node affinity/selector, 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }`.

Now delete that pod and create one with a toleration:

```bash
kubectl delete pod tutorial-taint-fail -n tutorial-pod-scheduling
```

```yaml
# Save as tutorial-taint-success.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-taint-success
  namespace: tutorial-pod-scheduling
spec:
  nodeSelector:
    kubernetes.io/hostname: scheduling-lab-worker2
  tolerations:
    - key: tutorial/special
      operator: Equal
      value: "true"
      effect: NoSchedule
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f tutorial-taint-success.yaml
kubectl get pod tutorial-taint-success -n tutorial-pod-scheduling -o wide
```

The pod schedules on `scheduling-lab-worker2`. The toleration allows it past the taint, and the nodeSelector directs it to that specific node.

### The Built-in Control-Plane Taint

The control-plane node has a built-in taint: `node-role.kubernetes.io/control-plane:NoSchedule`. This is why regular workloads never land on the control-plane. To schedule a pod on the control-plane (rare, but sometimes needed for system tools), you would need a toleration for this taint.

Clean up the taint:

```bash
kubectl taint nodes scheduling-lab-worker2 tutorial/special=true:NoSchedule-
```

---

## 8. Topology Spread Constraints

Topology spread constraints provide more fine-grained control over how pods are distributed across topology domains than pod anti-affinity. While pod anti-affinity is all-or-nothing (either two pods can or cannot be in the same domain), topology spread allows bounded imbalance: "the difference between the most-loaded and least-loaded domain should be at most N."

### Key Fields

| Field | Purpose | Valid Values |
|-------|---------|-------------|
| `maxSkew` | Maximum allowed difference in pod count between the most-loaded and least-loaded topology domain | Integer >= 1 |
| `topologyKey` | Node label key defining the topology domain | Any node label key (e.g., `kubernetes.io/hostname`) |
| `whenUnsatisfiable` | What to do if the constraint cannot be satisfied | `DoNotSchedule` (hard) or `ScheduleAnyway` (soft) |
| `labelSelector` | Which pods count toward the spread calculation | Standard label selector |

### How It Differs from Pod Anti-Affinity

Pod anti-affinity with `topologyKey: kubernetes.io/hostname` says "no two matching pods on the same node, period." If you have 3 nodes and 4 pods, the fourth pod stays Pending.

Topology spread with `maxSkew: 1` and `topologyKey: kubernetes.io/hostname` says "the busiest and emptiest nodes should differ by at most 1 pod." With 3 nodes and 4 pods, the fourth pod can schedule because a 2-1-1 distribution has a skew of 1. The fifth pod could also schedule (2-2-1 still has skew 1). Only when placement would create skew > 1 does the constraint block scheduling.

### Demonstration

Create three pods with topology spread:

```yaml
# Save as tutorial-topospread.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-topo-1
  namespace: tutorial-pod-scheduling
  labels:
    app: tutorial-topo
spec:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels:
          app: tutorial-topo
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-topo-2
  namespace: tutorial-pod-scheduling
  labels:
    app: tutorial-topo
spec:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels:
          app: tutorial-topo
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-topo-3
  namespace: tutorial-pod-scheduling
  labels:
    app: tutorial-topo
spec:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels:
          app: tutorial-topo
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f tutorial-topospread.yaml
kubectl get pods -n tutorial-pod-scheduling -l app=tutorial-topo -o wide
```

With 3 pods and 3 workers (and maxSkew 1), each worker should get exactly one pod, producing a perfectly balanced 1-1-1 distribution. The key difference from anti-affinity: if you added a fourth pod with the same constraint, it could still schedule (creating a 2-1-1 distribution, which has skew 1). With anti-affinity, the fourth pod would stay Pending.

---

## 9. Priority Classes

Priority classes let you assign relative importance to pods. When the cluster is under resource pressure and a higher-priority pod cannot be scheduled, the scheduler may preempt (evict) lower-priority pods to make room.

### Creating a PriorityClass

```yaml
# Save as tutorial-priorityclasses.yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: tutorial-low
value: 100
globalDefault: false
description: "Low priority for tutorial workloads"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: tutorial-high
value: 1000
globalDefault: false
description: "High priority for tutorial workloads"
```

```bash
kubectl apply -f tutorial-priorityclasses.yaml
```

PriorityClasses are cluster-scoped (not namespaced). The `value` field determines priority: higher numbers mean higher priority. The `globalDefault` field should be `false` for custom classes (only one PriorityClass in a cluster should be the global default).

### Assigning Priority to Pods

```yaml
# Save as tutorial-priority-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-priority-low
  namespace: tutorial-pod-scheduling
spec:
  priorityClassName: tutorial-low
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-priority-high
  namespace: tutorial-pod-scheduling
spec:
  priorityClassName: tutorial-high
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f tutorial-priority-pod.yaml
kubectl get pods -n tutorial-pod-scheduling -o custom-columns=NAME:.metadata.name,PRIORITY:.spec.priority,NODE:.spec.nodeName
```

Both pods will be Running. The priority value is visible in the pod spec.

### Preemption Behavior

In a kind cluster with minimal resource pressure, preemption is unlikely to trigger. Here is what happens conceptually: if the high-priority pod cannot be scheduled because all nodes are full, the scheduler looks for lower-priority pods it can evict. It selects the set of evictions that frees the least resources while making room for the high-priority pod, evicts those pods, and then schedules the high-priority pod.

Preemption respects PodDisruptionBudgets (if they exist) and prefers to evict pods on nodes that already have other lower-priority pods. In practice on the CKA exam, you are more likely to be asked to create PriorityClasses and assign them than to debug preemption behavior.

### Custom Schedulers

The Mumshad course covers custom schedulers and scheduler profile configuration. These are out of scope for this assignment. Know that they exist: you can run multiple schedulers in a cluster and assign pods to a specific scheduler via the `schedulerName` field in the pod spec. For the CKA exam, the default scheduler is sufficient.

---

## 10. Reading FailedScheduling Events

The FailedScheduling event is your primary diagnostic tool when a pod is stuck in Pending. Here is how to read the message format, with annotated examples.

### How to See the Event

```bash
kubectl describe pod <pod-name> -n <namespace>
```

Scroll to the `Events` section at the bottom. Look for events with `Type: Warning` and `Reason: FailedScheduling`.

You can also use:

```bash
kubectl get events -n <namespace> --field-selector reason=FailedScheduling
```

### Message Format

A typical FailedScheduling message looks like:

```
0/4 nodes are available: 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }, 
2 node(s) didn't match Pod's node affinity/selector, 1 node(s) had untolerated taint {special: true}.
```

Breaking this down:

- `0/4 nodes are available:` -- Zero out of four total nodes passed filtering. The pod cannot be scheduled.
- `1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }` -- The control-plane node was excluded because the pod lacks a toleration for the control-plane taint.
- `2 node(s) didn't match Pod's node affinity/selector` -- Two worker nodes did not satisfy the pod's nodeSelector or node affinity requirements.
- `1 node(s) had untolerated taint {special: true}` -- One worker node had a taint that the pod does not tolerate.

### Common Message Patterns

**nodeSelector or node affinity mismatch:**
```
0/4 nodes are available: 3 node(s) didn't match Pod's node affinity/selector, 
1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }.
```
All three workers failed the label match. Check your nodeSelector labels or node affinity expressions against the actual node labels.

**Taint with no matching toleration:**
```
0/4 nodes are available: 1 node(s) had untolerated taint {dedicated: ml}, 
1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }, 
2 node(s) didn't match Pod's node affinity/selector.
```
One worker has a taint the pod does not tolerate. Check `kubectl describe node` for taints, and compare against the pod's tolerations.

**Pod affinity not satisfied:**
```
0/4 nodes are available: 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }, 
3 node(s) didn't match pod affinity rules.
```
No worker node has a running pod that matches the pod affinity's labelSelector in the specified topologyKey domain.

**Insufficient resources (less common in kind clusters):**
```
0/4 nodes are available: 3 Insufficient cpu, 1 node(s) had untolerated taint 
{node-role.kubernetes.io/control-plane: }.
```
The pod's resource requests exceed available capacity on all workers.

### Diagnostic Workflow

When you see a Pending pod, follow this sequence:

1. `kubectl get pod <name> -n <namespace>` to confirm the pod is Pending.
2. `kubectl describe pod <name> -n <namespace>` to read the FailedScheduling event.
3. Parse the message to identify which constraint(s) failed.
4. Inspect the nodes: `kubectl get nodes --show-labels` for labels, `kubectl describe node <name>` for taints.
5. Compare the node state against the pod's scheduling requirements (nodeSelector, affinity, tolerations).
6. Fix either the pod spec or the node configuration and reapply.

---

## 11. Dedicated-Node Pattern

The dedicated-node pattern is a common production pattern that combines taints, tolerations, and node affinity (or nodeSelector) to reserve a node exclusively for a specific workload. Understanding this pattern is important for the CKA exam.

The pattern has three parts:

1. **Taint the node** so that ordinary pods are repelled.
2. **Add a toleration** to the workload pods so they can schedule on the tainted node.
3. **Add nodeSelector or node affinity** to the workload pods so they are directed to the tainted node and do not wander to untainted nodes.

Without part 3, the toleration lets the pod schedule on the tainted node, but the pod could also land on any untainted node. The toleration is a pass, not a magnet. Without part 2, the node affinity directs the pod to the correct node, but the taint blocks it.

### Demonstration

Set up a dedicated ML node:

```bash
kubectl label nodes scheduling-lab-worker3 tutorial/dedicated=ml
kubectl taint nodes scheduling-lab-worker3 tutorial/dedicated=ml:NoSchedule
```

Create a pod that uses the full pattern:

```yaml
# Save as tutorial-dedicated-node.yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-dedicated-ml
  namespace: tutorial-pod-scheduling
spec:
  nodeSelector:
    tutorial/dedicated: ml
  tolerations:
    - key: tutorial/dedicated
      operator: Equal
      value: ml
      effect: NoSchedule
  containers:
    - name: sleeper
      image: busybox:1.36
      command: ["sh", "-c", "echo started; sleep 3600"]
```

```bash
kubectl apply -f tutorial-dedicated-node.yaml
kubectl get pod tutorial-dedicated-ml -n tutorial-pod-scheduling -o wide
```

The pod runs on `scheduling-lab-worker3`. A regular pod without the toleration and nodeSelector cannot land there, and this pod cannot land on a non-dedicated node.

Clean up:

```bash
kubectl label nodes scheduling-lab-worker3 tutorial/dedicated-
kubectl taint nodes scheduling-lab-worker3 tutorial/dedicated=ml:NoSchedule-
```

---

## 12. Scheduling Mechanism Decision Table

| Mechanism | Use When | Hard or Soft | Controls |
|-----------|----------|-------------|----------|
| `nodeName` | Debugging, static pods, one-off placement | Hard (bypasses scheduler) | Exact node |
| `nodeSelector` | Simple label-based placement, one or two labels | Hard only | Node labels (equality) |
| Node affinity (required) | Complex label matching, set-based operators, multiple terms | Hard | Node labels (set-based) |
| Node affinity (preferred) | "Best effort" placement hints with weights | Soft | Node labels (set-based) |
| Pod affinity (required) | Must co-locate with another pod | Hard | Pod labels + topology domain |
| Pod affinity (preferred) | Prefer co-location with another pod | Soft | Pod labels + topology domain |
| Pod anti-affinity (required) | Must not co-locate with another pod (all-or-nothing) | Hard | Pod labels + topology domain |
| Pod anti-affinity (preferred) | Prefer separation from another pod | Soft | Pod labels + topology domain |
| Taints + Tolerations | Repel workloads from a node; reserve nodes for specific use | Hard (NoSchedule) or Soft (PreferNoSchedule) | Node taints |
| Topology spread | Distribute pods evenly across domains with bounded skew | Hard (DoNotSchedule) or Soft (ScheduleAnyway) | Pod labels + topology domain |
| Priority classes | Preempt lower-priority pods when cluster is full | N/A (affects preemption, not filtering) | Pod priority |

---

## 13. Reference Commands

### Node Labels

```bash
# List all labels on all nodes
kubectl get nodes --show-labels

# Get a specific label value
kubectl get node <node> -o jsonpath='{.metadata.labels.kubernetes\.io\/hostname}'

# Add a label
kubectl label nodes <node> key=value

# Change an existing label (requires --overwrite)
kubectl label nodes <node> key=newvalue --overwrite

# Remove a label (note the - suffix)
kubectl label nodes <node> key-
```

### Node Taints

```bash
# View taints on a node
kubectl describe node <node> | grep -A5 Taints

# Get taints as JSON
kubectl get node <node> -o jsonpath='{.spec.taints}'

# Add a taint
kubectl taint nodes <node> key=value:NoSchedule

# Remove a taint (note the - suffix, must match key=value:effect exactly)
kubectl taint nodes <node> key=value:NoSchedule-
```

### Pod Placement

```bash
# See which node each pod is on
kubectl get pods -n <namespace> -o wide

# Get the node name for a specific pod
kubectl get pod <pod> -n <namespace> -o jsonpath='{.spec.nodeName}'

# See scheduling events for a pod
kubectl describe pod <pod> -n <namespace>

# Filter events by reason
kubectl get events -n <namespace> --field-selector reason=FailedScheduling
```

### Generating YAML Skeletons

```bash
# Generate a pod skeleton (then add affinity, tolerations, etc. manually)
kubectl run my-pod --image=busybox:1.36 --dry-run=client -o yaml \
  --command -- sh -c "echo started; sleep 3600" > pod.yaml
```

---

## 14. Tutorial Cleanup

Remove all tutorial resources, node labels, and taints:

```bash
# Delete the tutorial namespace (removes all pods in it)
kubectl delete namespace tutorial-pod-scheduling

# Remove tutorial node labels
kubectl label nodes scheduling-lab-worker tutorial/disktype-
kubectl label nodes scheduling-lab-worker tutorial/zone-
kubectl label nodes scheduling-lab-worker2 tutorial/zone-
kubectl label nodes scheduling-lab-worker3 tutorial/dedicated-

# Remove tutorial taints (safe to run even if already removed)
kubectl taint nodes scheduling-lab-worker2 tutorial/special=true:NoSchedule- 2>/dev/null || true
kubectl taint nodes scheduling-lab-worker3 tutorial/dedicated=ml:NoSchedule- 2>/dev/null || true

# Delete tutorial PriorityClasses
kubectl delete priorityclass tutorial-low tutorial-high 2>/dev/null || true
```

You can verify the cleanup:

```bash
kubectl get nodes --show-labels | grep tutorial
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.taints}{"\n"}{end}'
```

The first command should produce no output. The second should show only the control-plane taint on the control-plane node.
