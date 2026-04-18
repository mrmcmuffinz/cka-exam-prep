# RBAC (Cluster-Scoped) Homework: 15 Progressive Exercises

These exercises build on the concepts covered in `rbac-tutorial.md`. Before starting, work through the tutorial or at least read its Reference Commands section.

All exercises assume a running single-node kind cluster:

```bash
kubectl config current-context   # should print kind-kind
```

Every exercise has its own namespace (`ex-1-1`, `ex-1-2`, and so on) and its own user. Cluster-scoped objects (ClusterRoles, ClusterRoleBindings, ServiceAccounts at cluster scope) use exercise-specific names so they do not collide. As in Assignment 1, verification uses `kubectl auth can-i --as=USER` and `--as=system:serviceaccount:NS:NAME` for service-account impersonation. Certificate creation is taught in Assignment 1 and is not repeated here.

## Global Setup

Run this once before starting. It creates every exercise namespace:

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 \
          ex-2-1 ex-2-2 ex-2-3 \
          ex-3-1 ex-3-2 ex-3-3 \
          ex-4-1 ex-4-2 ex-4-3 \
          ex-5-1 ex-5-2 ex-5-3; do
  kubectl create namespace $ns
done
```

Per-exercise setup commands follow. Each exercise is self-contained: read the objective, run the setup, solve the task, then run the verification block.

---

## Level 1: ClusterRole Basics

### Exercise 1.1

**Objective:** Give `alice` cluster-wide read-only access to Nodes.

**Setup:**

```bash
# Nodes already exist (kind-control-plane); no extra setup required.
echo "Nodes to read:"
kubectl get nodes -o name
```

**Task:**

Create a ClusterRole named `node-viewer` that permits `get`, `list`, and `watch` on the `nodes` resource. Bind it cluster-wide to user `alice` with a ClusterRoleBinding named `alice-node-viewer`.

**Verification:**

```bash
kubectl auth can-i list nodes --as=alice                                # expect: yes
kubectl auth can-i get nodes/kind-control-plane --as=alice              # expect: yes
kubectl auth can-i watch nodes --as=alice                               # expect: yes
kubectl auth can-i delete nodes --as=alice                              # expect: no
kubectl auth can-i list pods --all-namespaces --as=alice                # expect: no
```

---

### Exercise 1.2

**Objective:** Give `bob` the ability to create and delete Namespaces cluster-wide.

**Setup:**

```bash
# No pre-existing objects needed; bob will create and delete namespaces himself.
echo "Namespaces currently:"
kubectl get ns --no-headers | awk '{print $1}'
```

**Task:**

Create a ClusterRole named `namespace-lifecycle` that permits `get`, `list`, `watch`, `create`, and `delete` on the `namespaces` resource. Bind it cluster-wide to user `bob` with a ClusterRoleBinding named `bob-namespace-lifecycle`.

**Verification:**

```bash
kubectl auth can-i create namespaces --as=bob                            # expect: yes
kubectl auth can-i delete namespaces --as=bob                            # expect: yes
kubectl auth can-i list namespaces --as=bob                              # expect: yes
kubectl auth can-i update namespaces --as=bob                            # expect: no
kubectl auth can-i list pods --all-namespaces --as=bob                   # expect: no
```

---

### Exercise 1.3

**Objective:** Use a default built-in ClusterRole to grant `charlie` cluster-wide read-only access to everything `view` covers.

**Setup:**

```bash
kubectl -n ex-1-3 create deployment app --image=nginx:1.27
kubectl -n ex-1-3 expose deployment app --port=80
```

**Task:**

Without creating a new ClusterRole, bind the built-in `view` ClusterRole cluster-wide to user `charlie` using a ClusterRoleBinding named `charlie-view`. Recall from the tutorial that `view` allows reading most objects but explicitly excludes Secrets.

**Verification:**

```bash
kubectl auth can-i list pods --all-namespaces --as=charlie                # expect: yes
kubectl auth can-i list services --all-namespaces --as=charlie            # expect: yes
kubectl auth can-i get deployments.apps --all-namespaces --as=charlie     # expect: yes
kubectl auth can-i list secrets --all-namespaces --as=charlie             # expect: no
kubectl auth can-i create pods -n ex-1-3 --as=charlie                     # expect: no
```

---

## Level 2: Cluster-Scoped Resources

### Exercise 2.1

**Objective:** Give `diana` the ability to manage PersistentVolumes cluster-wide, including delete.

**Setup:**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: homework-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /tmp/homework-pv
EOF
```

**Task:**

Create a ClusterRole named `pv-manager` that permits `get`, `list`, `watch`, `create`, `update`, `patch`, and `delete` on `persistentvolumes`. Bind it cluster-wide to `diana` with a ClusterRoleBinding named `diana-pv-manager`.

**Verification:**

```bash
kubectl auth can-i list pv --as=diana                                    # expect: yes
kubectl auth can-i get pv/homework-pv --as=diana                         # expect: yes
kubectl auth can-i delete pv --as=diana                                  # expect: yes
kubectl auth can-i create pv --as=diana                                  # expect: yes
kubectl auth can-i list persistentvolumeclaims --all-namespaces --as=diana  # expect: no
```

---

### Exercise 2.2

**Objective:** Give `eric` full control over StorageClasses cluster-wide.

**Setup:**

```bash
# kind provisions a default storageclass at install.
kubectl get storageclass
```

**Task:**

Create a ClusterRole named `storageclass-admin` that permits `get`, `list`, `watch`, `create`, `update`, `patch`, and `delete` on `storageclasses`. StorageClasses live in the `storage.k8s.io` API group; pick the right group when writing the rule. Bind the ClusterRole cluster-wide to `eric` with a ClusterRoleBinding named `eric-storageclass-admin`.

**Verification:**

```bash
kubectl auth can-i list storageclasses --as=eric                         # expect: yes
kubectl auth can-i create storageclasses --as=eric                       # expect: yes
kubectl auth can-i delete storageclasses --as=eric                       # expect: yes
kubectl auth can-i get storageclasses/standard --as=eric                 # expect: yes
kubectl auth can-i list pv --as=eric                                     # expect: no
```

---

### Exercise 2.3

**Objective:** Give `fiona` read-only access to PriorityClasses cluster-wide.

**Setup:**

```bash
# Two system priorityclasses ship by default.
kubectl get priorityclasses
```

**Task:**

Create a ClusterRole named `priorityclass-viewer` that permits `get`, `list`, and `watch` on `priorityclasses` (API group `scheduling.k8s.io`). Bind it cluster-wide to `fiona` with a ClusterRoleBinding named `fiona-priorityclass-viewer`.

**Verification:**

```bash
kubectl auth can-i list priorityclasses --as=fiona                        # expect: yes
kubectl auth can-i get priorityclass/system-cluster-critical --as=fiona   # expect: yes
kubectl auth can-i create priorityclasses --as=fiona                      # expect: no
kubectl auth can-i list storageclasses --as=fiona                         # expect: no
```

---

## Level 3: Debugging Broken Configurations

### Exercise 3.1

**Objective:** Fix the broken configuration so that `george` can list and get StorageClasses cluster-wide.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ex-3-1-storageclass-reader
rules:
  - apiGroups: [""]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: george-storageclass-reader
subjects:
  - kind: User
    name: george
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: ex-3-1-storageclass-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Task:**

The ClusterRole and ClusterRoleBinding above applied without error, but `george` still cannot list StorageClasses. Find and fix the single issue.

**Verification:**

```bash
kubectl auth can-i list storageclasses --as=george                       # expect: yes
kubectl auth can-i get storageclasses/standard --as=george               # expect: yes
kubectl auth can-i create storageclasses --as=george                     # expect: no
```

---

### Exercise 3.2

**Objective:** Fix the broken configuration so that `hannah` can list Nodes cluster-wide.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ex-3-2-node-viewer
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: hannah-node-viewer
  namespace: ex-3-2
subjects:
  - kind: User
    name: hannah
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: ex-3-2-node-viewer
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Task:**

The objects above applied without error, but `hannah` still cannot list Nodes. Identify and correct the single issue.

**Verification:**

```bash
kubectl auth can-i list nodes --as=hannah                                # expect: yes
kubectl auth can-i get nodes/kind-control-plane --as=hannah              # expect: yes
kubectl auth can-i delete nodes --as=hannah                              # expect: no
```

---

### Exercise 3.3

**Objective:** Fix the broken configuration so that `ian` can reach the `/healthz` endpoint on the API server.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ex-3-3-health-checker
rules:
  - nonResourceURLs: ["/healthz", "/healthz/*"]
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ian-health-checker
  namespace: ex-3-3
subjects:
  - kind: User
    name: ian
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: ex-3-3-health-checker
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Task:**

The objects above applied without error, but `ian` cannot access `/healthz`. Identify and correct the single issue.

**Verification:**

```bash
kubectl auth can-i get /healthz --as=ian                                 # expect: yes
kubectl auth can-i get /healthz/etcd --as=ian                            # expect: yes
kubectl auth can-i get /metrics --as=ian                                 # expect: no
```

---

## Level 4: Advanced Patterns

### Exercise 4.1

**Objective:** Grant `karl` namespace-scoped admin-like access in `ex-4-1` only, using a default ClusterRole.

**Setup:**

```bash
kubectl -n ex-4-1 create deployment demo --image=nginx:1.27
kubectl -n ex-4-1 create configmap app-config --from-literal=env=demo
```

**Task:**

Using the built-in `edit` ClusterRole, grant `karl` the ability to create, update, and delete workloads and their supporting objects in namespace `ex-4-1` only. He should have no access in any other namespace. Do not create a new ClusterRole; do not create a ClusterRoleBinding. Use a single RoleBinding named `karl-edit`.

**Verification:**

```bash
kubectl auth can-i create deployments -n ex-4-1 --as=karl                # expect: yes
kubectl auth can-i delete pods -n ex-4-1 --as=karl                       # expect: yes
kubectl auth can-i update configmaps -n ex-4-1 --as=karl                 # expect: yes
kubectl auth can-i get secrets -n ex-4-1 --as=karl                       # expect: yes
kubectl auth can-i create deployments -n ex-4-2 --as=karl                # expect: no
kubectl auth can-i list pods -n default --as=karl                        # expect: no
kubectl auth can-i list nodes --as=karl                                  # expect: no
```

---

### Exercise 4.2

**Objective:** Extend the built-in `view` ClusterRole by aggregating a new source ClusterRole, then bind `view` to `luna` cluster-wide.

**Setup:**

```bash
# Confirm the view ClusterRole already aggregates.
kubectl get clusterrole view -o jsonpath='{.aggregationRule}'
echo
```

**Task:**

Create a ClusterRole named `view-storageclasses` that contributes `get`, `list`, and `watch` on `storageclasses` (API group `storage.k8s.io`) to the built-in `view` ClusterRole through label-based aggregation. Then bind the `view` ClusterRole cluster-wide to `luna` with a ClusterRoleBinding named `luna-view`. After the aggregation controller reconciles (within a second or two), `luna` should be able to list StorageClasses even though `view` did not include them by default.

**Verification:**

```bash
# Aggregation worked: view's rendered rules now include storageclasses.
# Expected: at least one line of output containing the word storageclasses.
kubectl get clusterrole view -o yaml | grep -E '^\s+- storageclasses'

# luna now has the aggregated permission cluster-wide.
kubectl auth can-i list storageclasses --as=luna                          # expect: yes
kubectl auth can-i list pods --all-namespaces --as=luna                   # expect: yes
kubectl auth can-i list secrets --all-namespaces --as=luna                # expect: no
kubectl auth can-i create storageclasses --as=luna                        # expect: no
```

---

### Exercise 4.3

**Objective:** Grant a ServiceAccount cluster-wide read access and verify the identity resolves correctly.

**Setup:**

```bash
kubectl -n ex-4-3 create serviceaccount metric-scraper
kubectl -n ex-4-3 create deployment sample --image=nginx:1.27
```

**Task:**

Create a ClusterRoleBinding named `metric-scraper-view` that grants the built-in `view` ClusterRole to the `metric-scraper` ServiceAccount in namespace `ex-4-3`. The ServiceAccount's authenticated identity is `system:serviceaccount:ex-4-3:metric-scraper`; verification below uses that form.

**Verification:**

```bash
kubectl auth can-i list pods --all-namespaces \
  --as=system:serviceaccount:ex-4-3:metric-scraper                         # expect: yes
kubectl auth can-i list services --all-namespaces \
  --as=system:serviceaccount:ex-4-3:metric-scraper                         # expect: yes
kubectl auth can-i list deployments.apps --all-namespaces \
  --as=system:serviceaccount:ex-4-3:metric-scraper                         # expect: yes
kubectl auth can-i list secrets --all-namespaces \
  --as=system:serviceaccount:ex-4-3:metric-scraper                         # expect: no
kubectl auth can-i create pods -n ex-4-3 \
  --as=system:serviceaccount:ex-4-3:metric-scraper                         # expect: no
```

---

## Level 5: Advanced Debugging and Comprehensive Tasks

### Exercise 5.1

**Objective:** Build a cluster-operator ClusterRole from requirements.

**Setup:**

```bash
# No prebuilt objects; you will design the ClusterRole from scratch.
echo "Namespace ex-5-1 ready."
```

**Task:**

Create a single ClusterRole named `cluster-operator` with the following capabilities:

- Read access (`get`, `list`, `watch`) to every resource in every API group, at cluster scope and across all namespaces.
- Manage (`get`, `list`, `watch`, `create`, `delete`) on `namespaces`.
- Read (`get`, `list`, `watch`) on `nodes`.
- The ability to grant other users access to the built-in `admin` ClusterRole via RoleBinding. The cluster-operator should hold the `bind` verb only on the specific ClusterRole named `admin`; they should not be able to bind any other ClusterRole, and they should not directly hold the permissions that `admin` grants.

Bind the ClusterRole cluster-wide to user `nina` with a ClusterRoleBinding named `nina-cluster-operator`.

**Verification:**

```bash
kubectl auth can-i list nodes --as=nina                                    # expect: yes
kubectl auth can-i list pods --all-namespaces --as=nina                    # expect: yes
kubectl auth can-i get secrets --all-namespaces --as=nina                  # expect: yes
kubectl auth can-i create namespaces --as=nina                             # expect: yes
kubectl auth can-i delete namespaces --as=nina                             # expect: yes
kubectl auth can-i create deployments -n ex-5-1 --as=nina                  # expect: no
kubectl auth can-i bind clusterroles/admin --as=nina                       # expect: yes
kubectl auth can-i bind clusterroles/edit --as=nina                        # expect: no
kubectl auth can-i bind clusterroles/cluster-admin --as=nina               # expect: no
```

---

### Exercise 5.2

**Objective:** Fix the broken configuration so that `olivia` can list and manage ClusterRoles and list Nodes cluster-wide.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ex-5-2-cluster-support
rules:
  - apiGroups: ["rbac"]
    resources: ["clusterroles"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["node"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: olivia-cluster-support
subjects:
  - kind: user
    name: olivia
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: ex-5-2-cluster-support
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Task:**

The objects above applied without error, but `olivia` cannot do any of the things she should be able to. The configuration has one or more problems. Find and fix whatever is needed so that the verification block passes.

Note: to satisfy the ClusterRole create/update privilege-escalation rule, you may need admin credentials when creating a role that grants cluster-scope permissions you yourself do not already hold. In a default kind cluster the current-context user is in `system:masters`, so this is not a blocker; it is worth knowing for real clusters.

**Verification:**

```bash
kubectl auth can-i list clusterroles --as=olivia                            # expect: yes
kubectl auth can-i create clusterroles --as=olivia                          # expect: yes
kubectl auth can-i delete clusterroles --as=olivia                          # expect: yes
kubectl auth can-i list nodes --as=olivia                                   # expect: yes
kubectl auth can-i get nodes/kind-control-plane --as=olivia                 # expect: yes
kubectl auth can-i list pods --all-namespaces --as=olivia                   # expect: no
kubectl auth can-i create pods -n ex-5-2 --as=olivia                        # expect: no
```

---

### Exercise 5.3

**Objective:** Model a least-privilege cluster-reader.

**Setup:**

```bash
kubectl -n ex-5-3 create deployment web --image=nginx:1.27
kubectl -n ex-5-3 create configmap web-config --from-literal=port=80
kubectl -n ex-5-3 create secret generic web-tls --from-literal=key=not-for-reading
```

**Task:**

Create a single ClusterRole named `cluster-reader` that grants read-only access (`get`, `list`, `watch`) across all namespaces to exactly the following resource types, and nothing else:

- Core group (`""`): pods, services, configmaps, namespaces, nodes, persistentvolumes, persistentvolumeclaims, events
- `apps` group: deployments, replicasets, daemonsets, statefulsets
- `batch` group: jobs, cronjobs
- `networking.k8s.io` group: ingresses, networkpolicies
- `storage.k8s.io` group: storageclasses
- `rbac.authorization.k8s.io` group: roles, rolebindings, clusterroles, clusterrolebindings

The role must not grant access to secrets, must not permit any write verb, and must not include the `*` wildcard on resources, apiGroups, or verbs. Then bind it cluster-wide to user `priya` using a ClusterRoleBinding named `priya-cluster-reader`.

**Verification:**

```bash
# Broad read access
kubectl auth can-i list pods --all-namespaces --as=priya                    # expect: yes
kubectl auth can-i list services --all-namespaces --as=priya                # expect: yes
kubectl auth can-i list deployments.apps --all-namespaces --as=priya        # expect: yes
kubectl auth can-i list ingresses.networking.k8s.io --all-namespaces --as=priya  # expect: yes
kubectl auth can-i list storageclasses --as=priya                           # expect: yes
kubectl auth can-i list nodes --as=priya                                    # expect: yes
kubectl auth can-i list clusterroles --as=priya                             # expect: yes

# Secrets are off-limits
kubectl auth can-i list secrets --all-namespaces --as=priya                 # expect: no
kubectl auth can-i get secret/web-tls -n ex-5-3 --as=priya                  # expect: no

# No write verbs
kubectl auth can-i create pods -n ex-5-3 --as=priya                         # expect: no
kubectl auth can-i delete deployments.apps -n ex-5-3 --as=priya             # expect: no
kubectl auth can-i create clusterrolebindings --as=priya                    # expect: no
```

---

## Cleanup

When you finish the homework, tear everything down. Cluster-scoped resources do not get cleaned up by namespace deletion, so they must be removed explicitly.

```bash
# Delete exercise namespaces (cascades to Roles, RoleBindings, SAs, and workloads inside).
for ns in ex-1-1 ex-1-2 ex-1-3 \
          ex-2-1 ex-2-2 ex-2-3 \
          ex-3-1 ex-3-2 ex-3-3 \
          ex-4-1 ex-4-2 ex-4-3 \
          ex-5-1 ex-5-2 ex-5-3; do
  kubectl delete namespace $ns --ignore-not-found
done

# Delete ClusterRoles created by the exercises.
kubectl delete clusterrole --ignore-not-found \
  node-viewer namespace-lifecycle \
  pv-manager storageclass-admin priorityclass-viewer \
  ex-3-1-storageclass-reader ex-3-2-node-viewer ex-3-3-health-checker \
  view-storageclasses \
  cluster-operator ex-5-2-cluster-support cluster-reader

# Delete ClusterRoleBindings created by the exercises.
kubectl delete clusterrolebinding --ignore-not-found \
  alice-node-viewer bob-namespace-lifecycle charlie-view \
  diana-pv-manager eric-storageclass-admin fiona-priorityclass-viewer \
  george-storageclass-reader \
  luna-view metric-scraper-view \
  nina-cluster-operator olivia-cluster-support priya-cluster-reader

# Delete the PersistentVolume created in Exercise 2.1.
kubectl delete pv homework-pv --ignore-not-found
```

---

## Key Takeaways

Cluster-scoped RBAC depends on the same scope matrix you applied in Assignment 1, with two failure modes that appear repeatedly. The first is binding a ClusterRole with a RoleBinding when cluster-wide access was intended: rules that name cluster-scoped resources (nodes, PersistentVolumes, namespaces, StorageClasses) or non-resource URLs (`/healthz`, `/metrics`) are silently dropped, producing an empty effective permission without any error. The second is using the wrong API group: `storageclasses` in `storage.k8s.io`, `priorityclasses` in `scheduling.k8s.io`, `ingressclasses` in `networking.k8s.io`, and `clusterroles` and `clusterrolebindings` all in `rbac.authorization.k8s.io`. The core group (empty string) covers `nodes`, `namespaces`, and `persistentvolumes`, which is a surface that catches learners off guard because `persistentvolumeclaims` is also core but `storageclasses` is not.

Default ClusterRoles remove a lot of repetitive work when used thoughtfully. `view` is the right choice for read-only audit accounts, as long as you remember it deliberately excludes Secrets for security reasons. `edit` approximates namespace-admin but is risky to grant widely because it can read Secrets and run pods as any ServiceAccount, which gives its holder indirect access to every permission any ServiceAccount in the namespace holds. `admin` adds Role and RoleBinding management to `edit` but still does not grant write access to the namespace object itself, nor to ResourceQuotas or EndpointSlices. `cluster-admin` should be treated as the super-user role.

Aggregation is useful when you need to extend a default ClusterRole without modifying it. Create a new ClusterRole with the right `rbac.authorization.k8s.io/aggregate-to-<name>` label, and the control plane composes it into the target's effective rules on the next reconciliation pass. The target's own `rules` field is owned by the control plane; writing rules there is a red flag that the aggregation controller will erase on startup.

The `bind` verb is the right tool when you want to let someone grant a specific role without giving them the role's permissions directly. Scope it with `resourceNames` to a short list of named roles so the delegation stays tight. The `escalate` verb is a broader exception that lets a user construct roles with permissions they themselves do not hold. Use `escalate` sparingly and audit carefully.

When debugging cluster-scoped RBAC the fastest diagnostic is still `kubectl auth can-i --list --as=USER`, which reports every resource and verb the authorization layer would allow for that identity. Pair it with `kubectl get clusterrolebinding -o wide` to find the bindings that apply, and with `kubectl describe clusterrolebinding NAME` to confirm that `roleRef` points at an existing ClusterRole with the expected rules.
