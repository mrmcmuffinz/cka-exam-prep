# RBAC (Cluster-Scoped) Tutorial

This tutorial covers cluster-scoped RBAC: ClusterRoles for cluster-wide permissions, ClusterRoleBindings for cluster-wide binding, and the pattern of using ClusterRole with RoleBinding for reusable namespace-scoped permissions.

## Prerequisites

Working kind cluster with kubectl configured.

```bash
kubectl get nodes
```

Create the tutorial namespace.

```bash
kubectl create namespace tutorial-rbac
```

## Part 1: ClusterRole vs Role

The key difference between ClusterRole and Role is scope.

**Role:** Namespace-scoped. Grants permissions within a single namespace.

**ClusterRole:** Cluster-scoped. Can grant permissions on cluster-scoped resources (nodes, namespaces, PVs) or across all namespaces.

## Part 2: Creating ClusterRoles

### ClusterRole for Cluster-Scoped Resources

Grant permission to view nodes.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-viewer
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
EOF
```

### ClusterRole for Namespace-Scoped Resources

ClusterRole can also define permissions on namespace-scoped resources, to be applied either cluster-wide or per-namespace.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
EOF
```

## Part 3: ClusterRoleBindings

ClusterRoleBinding grants permissions cluster-wide.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-node-viewers
subjects:
- kind: User
  name: alice
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: node-viewer
  apiGroup: rbac.authorization.k8s.io
EOF
```

Now alice can view nodes cluster-wide.

## Part 4: ClusterRole + RoleBinding Pattern

A powerful pattern: define permissions in a ClusterRole, but bind with RoleBinding for namespace-specific access.

Bind the pod-reader ClusterRole to user bob in a specific namespace.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: tutorial-rbac
subjects:
- kind: User
  name: bob
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

Bob can read pods only in tutorial-rbac namespace, not cluster-wide. The ClusterRole is reusable across namespaces.

## Part 5: Cluster-Scoped Resources

Resources that exist at cluster level (not in any namespace).

Common cluster-scoped resources: nodes, namespaces, persistentvolumes (PVs), clusterroles, clusterrolebindings, storageclasses, ingressclasses.

Example: Grant permission to manage namespaces.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-admin
rules:
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list", "watch", "create", "delete"]
EOF
```

## Part 6: Non-Resource URLs

Some cluster endpoints are not resources but URLs. Grant access with non-resource rules.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: health-checker
rules:
- nonResourceURLs: ["/healthz", "/readyz", "/livez"]
  verbs: ["get"]
EOF
```

## Part 7: Aggregated ClusterRoles

Aggregation combines permissions from multiple ClusterRoles automatically.

The built-in admin, edit, and view roles are aggregated. Create a ClusterRole that contributes to them.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: custom-resource-viewer
  labels:
    rbac.authorization.k8s.io/aggregate-to-view: "true"
rules:
- apiGroups: ["example.com"]
  resources: ["widgets"]
  verbs: ["get", "list", "watch"]
EOF
```

This ClusterRole's permissions are automatically added to the built-in view ClusterRole.

## Part 8: Default ClusterRoles

Kubernetes provides default ClusterRoles.

**cluster-admin:** Full cluster access.
**admin:** Full access within a namespace (when bound with RoleBinding).
**edit:** Read-write access to most resources.
**view:** Read-only access.

Check default roles.

```bash
kubectl get clusterroles | grep -E "^(cluster-admin|admin|edit|view)$"
```

## Part 9: Service Accounts at Cluster Scope

Service accounts can be bound to ClusterRoles.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cluster-viewer
  namespace: tutorial-rbac
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-viewer-binding
subjects:
- kind: ServiceAccount
  name: cluster-viewer
  namespace: tutorial-rbac
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
EOF
```

This service account can view resources in all namespaces.

## Part 10: Checking Permissions

### For Current User

```bash
kubectl auth can-i list nodes
kubectl auth can-i create namespaces
```

### For Another User

```bash
kubectl auth can-i list nodes --as=alice
kubectl auth can-i get pods --as=bob -n tutorial-rbac
```

### List All Permissions

```bash
kubectl auth can-i --list --as=alice
kubectl auth can-i --list --as=bob -n tutorial-rbac
```

## Cleanup

```bash
kubectl delete clusterrole node-viewer pod-reader namespace-admin health-checker custom-resource-viewer
kubectl delete clusterrolebinding cluster-node-viewers cluster-viewer-binding
kubectl delete namespace tutorial-rbac
```

## Reference Commands

| Task | Command |
|------|---------|
| Create ClusterRole | `kubectl create clusterrole <name> --verb=get,list --resource=nodes` |
| Create ClusterRoleBinding | `kubectl create clusterrolebinding <name> --clusterrole=<role> --user=<user>` |
| Bind ClusterRole per namespace | `kubectl create rolebinding <name> -n <ns> --clusterrole=<role> --user=<user>` |
| Check permission | `kubectl auth can-i <verb> <resource>` |
| Check as user | `kubectl auth can-i <verb> <resource> --as=<user>` |
| List all permissions | `kubectl auth can-i --list` |
| List ClusterRoles | `kubectl get clusterroles` |
| Describe ClusterRole | `kubectl describe clusterrole <name>` |
