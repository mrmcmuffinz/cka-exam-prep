# RBAC (Cluster-Scoped) Homework Answers

Solutions for all 15 exercises.

-----

## Exercise 1.1 Solution

```bash
kubectl create clusterrole node-reader --verb=get,list,watch --resource=nodes
```

Or declaratively.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
EOF
```

-----

## Exercise 1.2 Solution

```bash
kubectl create clusterrolebinding alice-node-reader --clusterrole=node-reader --user=alice
```

-----

## Exercise 1.3 Solution

```bash
kubectl auth can-i list nodes --as=alice    # yes
kubectl auth can-i create nodes --as=alice  # no
kubectl auth can-i delete nodes --as=alice  # no
```

The ClusterRole only grants get, list, watch, not create or delete.

-----

## Exercise 2.1 Solution

```bash
kubectl create clusterrole namespace-manager --verb=get,list,create,delete --resource=namespaces
kubectl create clusterrolebinding charlie-namespace-manager --clusterrole=namespace-manager --user=charlie
```

-----

## Exercise 2.2 Solution

```bash
kubectl create clusterrole pv-viewer --verb=get,list,watch --resource=persistentvolumes
kubectl create clusterrolebinding diana-pv-viewer --clusterrole=pv-viewer --user=diana
```

-----

## Exercise 2.3 Solution

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: storage-admin
rules:
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
EOF

kubectl create clusterrolebinding eric-storage-admin --clusterrole=storage-admin --user=eric
```

Note: storageclasses are in the storage.k8s.io API group.

-----

## Exercise 3.1 Solution

The issue is the resource name. It should be "nodes" (plural) not "node".

```bash
kubectl delete clusterrole ex-3-1-role

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ex-3-1-role
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list"]
EOF

kubectl create clusterrolebinding ex-3-1-binding --clusterrole=ex-3-1-role --user=fiona
```

-----

## Exercise 3.2 Solution

The RoleBinding references roleRef.kind: Role but the role is a ClusterRole.

```bash
kubectl delete rolebinding ex-3-2-binding -n ex-3-2

cat <<EOF | kubectl apply -f -
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
  kind: ClusterRole
  name: ex-3-2-role
  apiGroup: rbac.authorization.k8s.io
EOF
```

-----

## Exercise 3.3 Solution

The URL is "/health" but should be "/healthz".

```bash
kubectl delete clusterrole ex-3-3-role

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ex-3-3-role
rules:
- nonResourceURLs: ["/healthz"]
  verbs: ["get"]
EOF

kubectl create clusterrolebinding ex-3-3-binding --clusterrole=ex-3-3-role --user=hannah
```

-----

## Exercise 4.1 Solution

```bash
kubectl create rolebinding ian-edit -n ex-4-1 --clusterrole=edit --user=ian
```

Ian can edit in ex-4-1 but not in other namespaces.

-----

## Exercise 4.2 Solution

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: custom-viewer
  labels:
    rbac.authorization.k8s.io/aggregate-to-view: "true"
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
EOF
```

The view ClusterRole now includes configmaps permissions from aggregation.

-----

## Exercise 4.3 Solution

```bash
kubectl create serviceaccount cluster-monitor -n ex-4-3
kubectl create clusterrolebinding ex-4-3-binding --clusterrole=view --serviceaccount=ex-4-3:cluster-monitor
```

-----

## Exercise 5.1 Solution

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-operator
rules:
# View all resources
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
# Manage namespaces
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["create", "delete"]
# View nodes
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
# Manage RBAC
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["clusterroles", "clusterrolebindings"]
  verbs: ["create", "delete", "get", "list", "watch"]
EOF
```

-----

## Exercise 5.2 Solution

RBAC diagnostic workflow.

1. Check what user has access to.
```bash
kubectl auth can-i --list --as=<user>
```

2. Check specific permission.
```bash
kubectl auth can-i <verb> <resource> --as=<user>
kubectl auth can-i <verb> <resource> --as=<user> -n <namespace>
```

3. Find bindings for user.
```bash
kubectl get rolebindings,clusterrolebindings -A -o json | jq '.items[] | select(.subjects[]?.name=="<user>")'
```

4. Check role rules.
```bash
kubectl describe role <role> -n <namespace>
kubectl describe clusterrole <clusterrole>
```

5. Common issues: wrong resource name (plural), wrong API group, Role vs ClusterRole mismatch, missing binding.

-----

## Exercise 5.3 Solution

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-reader
rules:
# Core resources
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets", "namespaces", "nodes", "persistentvolumes", "persistentvolumeclaims"]
  verbs: ["get", "list", "watch"]
# Apps
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "daemonsets", "statefulsets"]
  verbs: ["get", "list", "watch"]
# Networking
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["get", "list", "watch"]
# RBAC (read-only)
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
  verbs: ["get", "list", "watch"]
EOF

kubectl create clusterrolebinding cluster-reader-binding --clusterrole=cluster-reader --user=reader-test
```

-----

## Common Mistakes

1. Using singular resource names (node instead of nodes)
2. Confusing ClusterRoleBinding with RoleBinding
3. Wrong API group (storageclasses are in storage.k8s.io, not core)
4. ClusterRole + RoleBinding only grants namespace-scoped access
5. Forgetting namespace in service account references
6. Non-resource URLs must exactly match (including leading slash)

-----

## RBAC Verification Commands

| Task | Command |
|------|---------|
| Check permission | `kubectl auth can-i <verb> <resource>` |
| Check as user | `kubectl auth can-i <verb> <resource> --as=<user>` |
| Check in namespace | `kubectl auth can-i <verb> <resource> -n <ns> --as=<user>` |
| List all permissions | `kubectl auth can-i --list --as=<user>` |
| Check all namespaces | `kubectl auth can-i <verb> <resource> --all-namespaces --as=<user>` |
