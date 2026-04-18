# RBAC (Cluster-Scoped) Homework

This homework contains 15 exercises for cluster-scoped RBAC. Each exercise is self-contained with setup and verification.

## Setup

```bash
kubectl get nodes
```

Clean up previous exercises.

```bash
for i in 1 2 3 4 5; do
  for j in 1 2 3; do
    kubectl delete namespace ex-${i}-${j} --ignore-not-found --wait=false
    kubectl delete clusterrole ex-${i}-${j}-role --ignore-not-found
    kubectl delete clusterrolebinding ex-${i}-${j}-binding --ignore-not-found
  done
done
```

-----

## Level 1: ClusterRole Basics

### Exercise 1.1

**Objective:** Create a ClusterRole that allows viewing nodes.

**Task:**

Create a ClusterRole named `node-reader` that allows get, list, and watch on nodes.

**Verification:**

```bash
kubectl describe clusterrole node-reader | grep -A5 "Resources"
```

-----

### Exercise 1.2

**Objective:** Create a ClusterRoleBinding for a user.

**Task:**

Bind the node-reader ClusterRole to user `alice` using a ClusterRoleBinding named `alice-node-reader`.

**Verification:**

```bash
kubectl auth can-i list nodes --as=alice
```

-----

### Exercise 1.3

**Objective:** Verify cluster-wide permissions.

**Task:**

Verify that alice can list nodes but cannot create or delete them.

**Verification:**

```bash
kubectl auth can-i list nodes --as=alice
kubectl auth can-i create nodes --as=alice
kubectl auth can-i delete nodes --as=alice
```

-----

## Level 2: Cluster-Scoped Resources

### Exercise 2.1

**Objective:** Grant permissions on namespaces.

**Task:**

Create a ClusterRole named `namespace-manager` that allows get, list, create, and delete on namespaces. Bind it to user `charlie`.

**Verification:**

```bash
kubectl auth can-i create namespaces --as=charlie
kubectl auth can-i delete namespaces --as=charlie
```

-----

### Exercise 2.2

**Objective:** Grant read access to PersistentVolumes.

**Task:**

Create a ClusterRole named `pv-viewer` that allows get, list, and watch on persistentvolumes. Bind it to user `diana`.

**Verification:**

```bash
kubectl auth can-i list persistentvolumes --as=diana
kubectl auth can-i create persistentvolumes --as=diana
```

-----

### Exercise 2.3

**Objective:** Grant access to StorageClasses.

**Task:**

Create a ClusterRole named `storage-admin` that allows full access (get, list, create, update, delete) on storageclasses. Bind it to user `eric`.

**Verification:**

```bash
kubectl auth can-i --list --as=eric | grep storageclasses
```

-----

## Level 3: Debugging RBAC Issues

### Exercise 3.1

**Setup:**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ex-3-1-role
rules:
- apiGroups: [""]
  resources: ["node"]
  verbs: ["get", "list"]
EOF
```

**Objective:**

A user cannot list nodes despite having this ClusterRole bound. Diagnose and fix.

**Verification:**

```bash
kubectl auth can-i list nodes --as=fiona
```

-----

### Exercise 3.2

**Setup:**

```bash
kubectl create namespace ex-3-2

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ex-3-2-role
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ex-3-2-binding
  namespace: ex-3-2
subjects:
- kind: User
  name: george
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: ex-3-2-role
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Objective:**

George cannot list pods in ex-3-2 namespace. Diagnose and fix.

**Verification:**

```bash
kubectl auth can-i list pods --as=george -n ex-3-2
```

-----

### Exercise 3.3

**Setup:**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ex-3-3-role
rules:
- nonResourceURLs: ["/health"]
  verbs: ["get"]
EOF
```

**Objective:**

A user should be able to access /healthz but cannot. Diagnose and fix.

**Verification:**

After binding to user hannah.

```bash
kubectl auth can-i get /healthz --as=hannah
```

-----

## Level 4: Advanced Patterns

### Exercise 4.1

**Objective:** Use ClusterRole + RoleBinding pattern.

**Task:**

Use the built-in `edit` ClusterRole with a RoleBinding to grant user `ian` edit access only in namespace `ex-4-1`.

**Setup:**

```bash
kubectl create namespace ex-4-1
```

**Verification:**

```bash
kubectl auth can-i create pods --as=ian -n ex-4-1
kubectl auth can-i create pods --as=ian -n default
```

-----

### Exercise 4.2

**Objective:** Create an aggregated ClusterRole.

**Task:**

Create a ClusterRole named `custom-viewer` that aggregates to the view role by adding the appropriate label. Grant view access on a custom resource (use configmaps as a stand-in).

**Verification:**

```bash
kubectl describe clusterrole view | grep configmaps
```

-----

### Exercise 4.3

**Objective:** Grant cluster-wide access to a service account.

**Setup:**

```bash
kubectl create namespace ex-4-3
```

**Task:**

Create a ServiceAccount named `cluster-monitor` in namespace ex-4-3. Create a ClusterRoleBinding that grants it the `view` ClusterRole cluster-wide.

**Verification:**

```bash
kubectl auth can-i list pods --all-namespaces --as=system:serviceaccount:ex-4-3:cluster-monitor
```

-----

## Level 5: Complex Scenarios

### Exercise 5.1

**Objective:** Design RBAC for a cluster operator.

**Task:**

Create a ClusterRole named `cluster-operator` that allows: view all resources in any namespace, manage (create/delete) namespaces, view nodes, and manage (create/delete) ClusterRoles and ClusterRoleBindings for RBAC delegation.

**Verification:**

```bash
kubectl describe clusterrole cluster-operator
```

-----

### Exercise 5.2

**Setup:**

A user reports they cannot access resources they should be able to.

**Objective:**

Debug and document the steps to diagnose RBAC permission issues.

**Verification:**

Document the diagnostic workflow using kubectl auth can-i and other commands.

-----

### Exercise 5.3

**Objective:** Implement least-privilege access for a cluster reader.

**Task:**

Create a comprehensive read-only access strategy: a ClusterRole named `cluster-reader` that can read all common resources (pods, services, deployments, configmaps) across all namespaces, read node status, but cannot create, modify, or delete anything.

**Verification:**

```bash
kubectl auth can-i list pods --all-namespaces --as=reader-test
kubectl auth can-i create pods --as=reader-test -n default
```

-----

## Cleanup

```bash
kubectl delete clusterrole node-reader namespace-manager pv-viewer storage-admin ex-3-1-role ex-3-2-role ex-3-3-role custom-viewer cluster-operator cluster-reader --ignore-not-found
kubectl delete clusterrolebinding alice-node-reader charlie-namespace-manager diana-pv-viewer eric-storage-admin ex-4-3-binding --ignore-not-found
for i in 1 2 3 4 5; do
  for j in 1 2 3; do
    kubectl delete namespace ex-${i}-${j} --ignore-not-found --wait=false
  done
done
```

## Key Takeaways

Creating ClusterRoles for cluster-scoped resources, using ClusterRoleBindings for cluster-wide access, the ClusterRole + RoleBinding pattern, aggregated ClusterRoles, service accounts at cluster scope, and debugging RBAC issues with kubectl auth can-i.
