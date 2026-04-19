# CRDs and Operators Homework Answers: Custom Resources and RBAC

This file contains complete solutions for all 15 exercises on custom resources and RBAC.

---

## Exercise 1.1 Solution

**Task:** Create an Application custom resource.

```yaml
apiVersion: apps.example.com/v1
kind: Application
metadata:
  name: web-frontend
  namespace: ex-1-1
spec:
  name: Frontend Service
  version: "2.0.0"
  replicas: 3
  environment: prod
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: apps.example.com/v1
kind: Application
metadata:
  name: web-frontend
  namespace: ex-1-1
spec:
  name: Frontend Service
  version: "2.0.0"
  replicas: 3
  environment: prod
EOF
```

**Explanation:** Custom resources use the CRD's group/version as apiVersion and the CRD's kind. The spec fields must match the schema defined in the CRD.

---

## Exercise 1.2 Solution

**Task:** List and describe applications.

```bash
# List all applications
kubectl get applications -n ex-1-2

# List using short name
kubectl get app -n ex-1-2

# Describe api-server
kubectl describe application api-server -n ex-1-2

# Get worker version
kubectl get application worker -n ex-1-2 -o jsonpath='{.spec.version}'
```

**Explanation:** Custom resources support all standard kubectl operations. Short names defined in the CRD can be used interchangeably with the full name.

---

## Exercise 1.3 Solution

**Task:** Update and delete applications.

Update using apply:

```bash
kubectl apply -f - <<EOF
apiVersion: apps.example.com/v1
kind: Application
metadata:
  name: myapp
  namespace: ex-1-3
spec:
  name: My Application
  version: "1.1.0"
  replicas: 4
EOF
```

Or update using patch:

```bash
kubectl patch application myapp -n ex-1-3 --type=merge -p '{"spec":{"version":"1.1.0","replicas":4}}'
```

Delete:

```bash
kubectl delete application myapp -n ex-1-3
```

**Explanation:** Both apply and patch can update resources. Delete removes the resource from the cluster.

---

## Exercise 2.1 Solution

**Task:** Create applications in different namespaces.

```bash
kubectl apply -f - <<EOF
apiVersion: apps.example.com/v1
kind: Application
metadata:
  name: feature-branch
  namespace: ex-2-1-dev
spec:
  name: Feature Branch
  version: "0.0.1"
  replicas: 1
  environment: dev
---
apiVersion: apps.example.com/v1
kind: Application
metadata:
  name: release
  namespace: ex-2-1-prod
spec:
  name: Release
  version: "1.0.0"
  replicas: 3
  environment: prod
EOF
```

List across namespaces:

```bash
kubectl get app --all-namespaces
```

**Explanation:** Namespaced resources exist within specific namespaces. Use --all-namespaces to list across all namespaces.

---

## Exercise 2.2 Solution

**Task:** Discover custom resources.

```bash
# Find applications resource
kubectl api-resources --api-group=apps.example.com

# Verify details
kubectl api-resources --api-group=apps.example.com -o wide
```

**Explanation:** api-resources shows all registered resources. The --api-group flag filters to a specific API group.

---

## Exercise 2.3 Solution

**Task:** Use short names and categories.

```bash
# Using short names
kubectl get app demo -n ex-2-3
kubectl get apps demo -n ex-2-3

# Check 'all' category
kubectl get all -n ex-2-3
```

**Explanation:** Short names and categories are defined in the CRD's spec.names section. Categories like "all" make resources appear in kubectl get all.

---

## Exercise 3.1 Solution

**Problem:** Two validation errors:
1. replicas: 15 exceeds maximum of 10
2. environment: "production" is not in enum (valid values: dev, staging, prod)

**Fix:**

```bash
kubectl apply -f - <<EOF
apiVersion: apps.example.com/v1
kind: Application
metadata:
  name: invalid-app
  namespace: ex-3-1
spec:
  name: Invalid Application
  version: "1.0.0"
  replicas: 10
  environment: prod
EOF
```

**Explanation:** Changed replicas from 15 to 10 (maximum allowed) and environment from "production" to "prod" (valid enum value).

---

## Exercise 3.2 Solution

**Task:** Create RBAC for read-only access.

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-reader
  namespace: ex-3-2
rules:
- apiGroups: ["apps.example.com"]
  resources: ["applications"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-viewer-binding
  namespace: ex-3-2
subjects:
- kind: ServiceAccount
  name: app-viewer
  namespace: ex-3-2
roleRef:
  kind: Role
  name: app-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Explanation:** The apiGroups must be the full CRD group "apps.example.com", not just "apps". The resources must be the plural name "applications".

---

## Exercise 3.3 Solution

**Task:** Find resource in correct namespace.

```bash
# Find across all namespaces
kubectl get applications --all-namespaces | grep prod-api

# Get from correct namespace
kubectl get application prod-api -n ex-3-3
```

**Explanation:** When a resource is not found, check if you are looking in the correct namespace. Use --all-namespaces to search everywhere.

---

## Exercise 4.1 Solution

**Task:** Create Role and RoleBinding for app manager.

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: application-manager
  namespace: ex-4-1
rules:
- apiGroups: ["apps.example.com"]
  resources: ["applications"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: ["apps.example.com"]
  resources: ["applications/status"]
  verbs: ["get", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-manager-binding
  namespace: ex-4-1
subjects:
- kind: ServiceAccount
  name: app-manager
  namespace: ex-4-1
roleRef:
  kind: Role
  name: application-manager
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Explanation:** Status subresource requires separate rules with "applications/status" as the resource. This allows updating status without being able to modify spec.

---

## Exercise 4.2 Solution

**Task:** Create RoleBinding for deployer.

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deployer-binding
  namespace: ex-4-2
subjects:
- kind: ServiceAccount
  name: deployer
  namespace: ex-4-2
roleRef:
  kind: Role
  name: app-deployer
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Explanation:** The RoleBinding connects the service account (subject) to the Role (roleRef). The service account can only perform actions allowed by the Role.

---

## Exercise 4.3 Solution

**Task:** Test all verbs with kubectl auth can-i.

Results:
- get: yes (allowed by role)
- list: yes (allowed by role)
- watch: no (not in role)
- create: no (not in role)
- update: no (not in role)
- patch: no (not in role)
- delete: no (not in role)

**Explanation:** kubectl auth can-i tests permissions without performing the action. The --as flag impersonates a service account.

---

## Exercise 5.1 Solution

**Task:** Create multi-user access.

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
  namespace: ex-5-1
rules:
- apiGroups: ["apps.example.com"]
  resources: ["applications"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: operator-role
  namespace: ex-5-1
rules:
- apiGroups: ["apps.example.com"]
  resources: ["applications"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: admin-role
  namespace: ex-5-1
rules:
- apiGroups: ["apps.example.com"]
  resources: ["applications"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: ex-5-1
subjects:
- kind: ServiceAccount
  name: developer
  namespace: ex-5-1
roleRef:
  kind: Role
  name: developer-role
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: operator-binding
  namespace: ex-5-1
subjects:
- kind: ServiceAccount
  name: operator
  namespace: ex-5-1
roleRef:
  kind: Role
  name: operator-role
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: admin-binding
  namespace: ex-5-1
subjects:
- kind: ServiceAccount
  name: admin
  namespace: ex-5-1
roleRef:
  kind: Role
  name: admin-role
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Explanation:** Each access level has its own Role with progressively more verbs. RoleBindings connect each service account to its appropriate Role.

---

## Exercise 5.2 Solution

**Problem:** Two issues with the Role:
1. apiGroups is "apps" but should be "apps.example.com"
2. resources is "application" but should be "applications" (plural)

**Fix:**

```bash
kubectl delete role broken-role -n ex-5-2

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: broken-role
  namespace: ex-5-2
rules:
- apiGroups: ["apps.example.com"]
  resources: ["applications"]
  verbs: ["get", "list", "create"]
EOF
```

**Explanation:** RBAC rules must use the exact API group from the CRD and the plural resource name. These are common mistakes when setting up RBAC for custom resources.

---

## Exercise 5.3 Solution

**Task:** Create RBAC for a controller.

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: controller-role
  namespace: ex-5-3
rules:
# Watch applications (not update spec)
- apiGroups: ["apps.example.com"]
  resources: ["applications"]
  verbs: ["get", "list", "watch"]
# Update status only
- apiGroups: ["apps.example.com"]
  resources: ["applications/status"]
  verbs: ["get", "update", "patch"]
# Create events
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create", "patch"]
# Read configmaps
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: controller-binding
  namespace: ex-5-3
subjects:
- kind: ServiceAccount
  name: controller
  namespace: ex-5-3
roleRef:
  kind: Role
  name: controller-role
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Explanation:** This implements least-privilege access for a controller:
- Watch applications to react to changes
- Update only status (not spec) via the status subresource
- Create events for observability
- Read configmaps for configuration

The controller cannot modify the application spec, only the status.

---

## Common Mistakes

### Wrong apiGroups in Role (must match CRD group)

For custom resources, use the full CRD group like "apps.example.com", not abbreviated names like "apps".

### Wrong resources name (must use plural)

RBAC resources field uses the plural name from the CRD's spec.names.plural, like "applications" not "application".

### Trying to get cluster-scoped resource in namespace

Cluster-scoped resources (scope: Cluster in CRD) do not use namespaces. Do not use -n flag with them.

### Custom resource validation failures

Custom resources are validated against the CRD schema. Check enum values, numeric ranges, and required fields.

### Missing RBAC for status subresource

If the CRD has a status subresource enabled, you need separate RBAC rules for "resources/status" to allow updating status.

---

## Custom Resource Commands Cheat Sheet

| Task | Command |
|------|---------|
| Create resource | `kubectl apply -f <file>` |
| List resources | `kubectl get <resource> -n <namespace>` |
| List all namespaces | `kubectl get <resource> --all-namespaces` |
| Describe resource | `kubectl describe <resource> <name> -n <namespace>` |
| Get as YAML | `kubectl get <resource> <name> -o yaml` |
| Update resource | `kubectl apply -f <file>` |
| Patch resource | `kubectl patch <resource> <name> --type=merge -p '<json>'` |
| Delete resource | `kubectl delete <resource> <name> -n <namespace>` |
| Check permissions | `kubectl auth can-i <verb> <resource> -n <namespace>` |
| Check permissions as SA | `kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<ns>:<sa>` |
| Find API resources | `kubectl api-resources --api-group=<group>` |
