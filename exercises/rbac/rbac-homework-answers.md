# RBAC Homework: Answer Key

Solutions for all 15 exercises in `rbac-homework.md`. Each answer shows both an imperative approach (where practical) and a declarative approach. For debugging exercises (3.1 through 3.3 and 5.1), the explanation comes first and the corrected YAML follows.

---

## Level 1: Single-Concept Tasks

### Exercise 1.1 Solution

**Imperative:**

```bash
kubectl -n ex-1-1 create role pod-reader \
  --verb=get,list,watch \
  --resource=pods

kubectl -n ex-1-1 create rolebinding alice-pod-reader \
  --role=pod-reader \
  --user=alice
```

**Declarative:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: ex-1-1
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: alice-pod-reader
  namespace: ex-1-1
subjects:
  - kind: User
    name: alice
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

---

### Exercise 1.2 Solution

**Imperative:**

```bash
kubectl -n ex-1-2 create role deployment-creator \
  --verb=create \
  --resource=deployments

kubectl -n ex-1-2 create rolebinding bob-deployment-creator \
  --role=deployment-creator \
  --user=bob
```

**Declarative:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployment-creator
  namespace: ex-1-2
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: bob-deployment-creator
  namespace: ex-1-2
subjects:
  - kind: User
    name: bob
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: deployment-creator
  apiGroup: rbac.authorization.k8s.io
```

Note that `deployments` lives in the `apps` API group, not the core group. The imperative form handles this for you automatically.

---

### Exercise 1.3 Solution

**Imperative:**

```bash
kubectl -n ex-1-3 create role cm-reader \
  --verb=get,list,watch \
  --resource=configmaps

kubectl -n ex-1-3 create rolebinding carol-cm-reader \
  --role=cm-reader \
  --user=carol
```

**Declarative:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cm-reader
  namespace: ex-1-3
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: carol-cm-reader
  namespace: ex-1-3
subjects:
  - kind: User
    name: carol
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: cm-reader
  apiGroup: rbac.authorization.k8s.io
```

---

## Level 2: Multi-Concept Tasks

### Exercise 2.1 Solution

This is where declarative becomes the cleaner option, because the imperative form cannot easily produce a Role with two different rules having different verbs.

**Declarative:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployment-admin-pod-reader
  namespace: ex-2-1
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["pods", "services"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: dave-deployment-admin
  namespace: ex-2-1
subjects:
  - kind: User
    name: dave
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: deployment-admin-pod-reader
  apiGroup: rbac.authorization.k8s.io
```

**Hybrid imperative approach:** You can generate the Role as YAML with `kubectl create role ... --dry-run=client -o yaml > role.yaml` and then hand-edit a second rule into it. For the exam this is sometimes faster than typing the full YAML from scratch.

---

### Exercise 2.2 Solution

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cm-admin-secret-reader
  namespace: ex-2-2
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: eve-cm-admin
  namespace: ex-2-2
subjects:
  - kind: User
    name: eve
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: cm-admin-secret-reader
  apiGroup: rbac.authorization.k8s.io
```

Both rules use `apiGroups: [""]` because ConfigMaps and Secrets are both core resources. You could combine them into a single rule only if the verbs were identical, which they are not here.

---

### Exercise 2.3 Solution

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: workload-operator
  namespace: ex-2-3
rules:
  - apiGroups: ["apps"]
    resources: ["deployments", "daemonsets", "replicasets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["pods", "services"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: frank-workload-operator
  namespace: ex-2-3
subjects:
  - kind: User
    name: frank
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: workload-operator
  apiGroup: rbac.authorization.k8s.io
```

Because all three workload resources (deployments, daemonsets, replicasets) share the same API group and the same verbs, they collapse into a single rule with a list of resources. That is the cleanest pattern: group resources by (apiGroup, verbs) tuple.

---

## Level 3: Debugging Broken Configurations

### Exercise 3.1 Solution

**What was wrong:** The Role has `apiGroups: [""]` (core API group) for the `deployments` resource. Deployments live in the `apps` API group, not core. The RBAC system silently ignores rules that reference non-existent (group, resource) combinations, which is why grace's request is denied with no useful error.

**Fix:** Change `apiGroups: [""]` to `apiGroups: ["apps"]`.

**Corrected Role:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployment-reader
  namespace: ex-3-1
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch"]
```

You can fix it in place with:

```bash
kubectl -n ex-3-1 patch role deployment-reader \
  --type='json' \
  -p='[{"op":"replace","path":"/rules/0/apiGroups","value":["apps"]}]'
```

**How to catch this in the wild:** When `kubectl auth can-i` returns no for an operation you think is granted, the first thing to check is whether `apiGroups` matches what `kubectl api-resources` reports for that resource.

---

### Exercise 3.2 Solution

**What was wrong:** The Role is named `pod-reader` (check `metadata.name`) but the RoleBinding's `roleRef.name` is `pod-viewer`. Kubernetes will apply both objects without complaint because there is no referential integrity check at apply time. The binding then silently points at a non-existent Role, so henry's permission check always fails.

**Fix:** Change the RoleBinding's `roleRef.name` from `pod-viewer` to `pod-reader`.

But `roleRef` is immutable, so you cannot edit it in place. Delete and recreate the binding:

```bash
kubectl -n ex-3-2 delete rolebinding henry-pod-reader

kubectl -n ex-3-2 create rolebinding henry-pod-reader \
  --role=pod-reader \
  --user=henry
```

Or declaratively, reapply with the corrected YAML after deleting.

**Corrected RoleBinding:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: henry-pod-reader
  namespace: ex-3-2
subjects:
  - kind: User
    name: henry
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

**How to catch this in the wild:** Run `kubectl describe rolebinding NAME -n NS` and look at the `Role` line at the top. If it references a Role that does not exist, `kubectl get role THAT_NAME -n NS` will return `NotFound`.

---

### Exercise 3.3 Solution

**What was wrong:** The Role uses `verbs: ["read", "view"]`. These are not valid RBAC verbs. The valid verbs for a readable resource are `get`, `list`, and `watch`. "Read" and "view" are things people say in English but Kubernetes does not recognize them.

**Fix:** Replace `verbs: ["read", "view"]` with `verbs: ["get", "list", "watch"]`.

**Corrected Role:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: service-reader
  namespace: ex-3-3
rules:
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "watch"]
```

In place:

```bash
kubectl -n ex-3-3 patch role service-reader \
  --type='json' \
  -p='[{"op":"replace","path":"/rules/0/verbs","value":["get","list","watch"]}]'
```

**The full list of valid verbs:** `get`, `list`, `watch`, `create`, `update`, `patch`, `delete`, `deletecollection`. There are also rare specialized verbs like `impersonate`, `bind`, and `escalate`.

**How to catch this in the wild:** Kubernetes does not validate verb names on Role apply, so typos slip through. `kubectl auth can-i list services --as=ivy` returns no, and there is no error message pointing at the cause. The way to check is to look at the Role's rules directly and verify every verb against the known-good list.

---

## Level 4: Complex Real-World Scenarios

### Exercise 4.1 Solution

Two reasonable approaches. The cleanest is to use a single ClusterRole (reusable permission template) and bind it twice with different RoleBindings.

**Approach A: ClusterRole + two RoleBindings.**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-admin
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps", "secrets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-reader
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps", "secrets"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: jack-admin
  namespace: ex-4-1-dev
subjects:
  - kind: User
    name: jack
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: namespace-admin
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: jack-reader
  namespace: ex-4-1-prod
subjects:
  - kind: User
    name: jack
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: namespace-reader
  apiGroup: rbac.authorization.k8s.io
```

The key insight is that a RoleBinding pointing at a ClusterRole only grants those permissions in the RoleBinding's namespace, not cluster-wide. This is the "reusable permission template" pattern. Using a RoleBinding (not a ClusterRoleBinding) is what keeps the scope namespaced.

**Approach B: two separate Roles per namespace.** Works too, but you end up with duplicate rule definitions in two different namespaces. Fine for simple cases, worse for maintenance as the number of namespaces grows.

**Why Approach A is preferred for production:** When you update the permission set, you edit one ClusterRole and every namespace that binds it picks up the change. This also matches the built-in Kubernetes roles pattern (view, edit, admin, cluster-admin are all ClusterRoles that are designed to be bound per-namespace).

---

### Exercise 4.2 Solution

Three users, three namespaces, with one cross-namespace read permission for liam. The cleanest approach is one Role per namespace.

```yaml
# kate: full control in frontend only
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: frontend-admin
  namespace: ex-4-2-frontend
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["services", "configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: kate-frontend-admin
  namespace: ex-4-2-frontend
subjects:
  - kind: User
    name: kate
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: frontend-admin
  apiGroup: rbac.authorization.k8s.io
---
# liam: full control in backend, services read-only in frontend
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: backend-admin
  namespace: ex-4-2-backend
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["services", "configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: liam-backend-admin
  namespace: ex-4-2-backend
subjects:
  - kind: User
    name: liam
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: backend-admin
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: service-viewer
  namespace: ex-4-2-frontend
rules:
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: liam-frontend-service-viewer
  namespace: ex-4-2-frontend
subjects:
  - kind: User
    name: liam
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: service-viewer
  apiGroup: rbac.authorization.k8s.io
---
# mia: full control in data, including secrets
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: data-admin
  namespace: ex-4-2-data
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["services", "configmaps", "secrets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: mia-data-admin
  namespace: ex-4-2-data
subjects:
  - kind: User
    name: mia
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: data-admin
  apiGroup: rbac.authorization.k8s.io
```

**Pattern to recognize:** Liam has a primary Role in his own namespace and a small, targeted secondary Role in the namespace he needs limited access to. This is the standard pattern for "this team also needs to see X in that other namespace." You grant the full role where they work, and a minimum-necessary role where they need visibility.

---

### Exercise 4.3 Solution

Two bindings, one to a group subject and one to a ServiceAccount subject, both against the same namespace.

```yaml
# Group-based read access
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: namespace-viewer
  namespace: ex-4-3
rules:
  - apiGroups: [""]
    resources: ["pods", "services"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: auditors-viewer
  namespace: ex-4-3
subjects:
  - kind: Group
    name: auditors
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: namespace-viewer
  apiGroup: rbac.authorization.k8s.io
---
# ServiceAccount-based deploy access
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ci-deployer
  namespace: ex-4-3
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["pods", "services"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ci-runner-deployer
  namespace: ex-4-3
subjects:
  - kind: ServiceAccount
    name: ci-runner
    namespace: ex-4-3
roleRef:
  kind: Role
  name: ci-deployer
  apiGroup: rbac.authorization.k8s.io
```

**Subject kind differences to internalize:**

- `kind: User` and `kind: Group` take `apiGroup: rbac.authorization.k8s.io`.
- `kind: ServiceAccount` takes no `apiGroup` (ServiceAccounts are core resources) and requires a `namespace` field because ServiceAccounts are namespaced objects.
- A ServiceAccount's identity string is `system:serviceaccount:NAMESPACE:NAME`. That is what you put in `--as=` for impersonation tests.
- Groups are asserted by the authenticator, not stored anywhere. A certificate with `/O=auditors` in its subject is treated as belonging to group `auditors`. For impersonation you supply the group with `--as-group=auditors` alongside a `--as=` user.

---

## Level 5: Advanced Debugging and Comprehensive Tasks

### Exercise 5.1 Solution

Three problems, each subtle enough that Kubernetes applied the whole thing without complaint.

**Problem 1: Resource name is singular, not plural.** The rule says `resources: ["deployment"]`. RBAC resource names are plural, always. It should be `deployments`.

**Problem 2: API group is `"core"` instead of `""`.** The pod rule uses `apiGroups: ["core"]`. The core API group is represented as the empty string `""`, not the word `"core"`. This is counterintuitive but it is how Kubernetes encodes it.

**Problem 3: Subject kind is `user` (lowercase) instead of `User`.** The RoleBinding has `kind: user`. RBAC subject kinds are case-sensitive and must be `User`, `Group`, or `ServiceAccount` with that exact capitalization. Lowercase `user` silently fails to match any real subject.

**Corrected YAML:**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-manager
  namespace: ex-5-1
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: olivia-app-manager
  namespace: ex-5-1
subjects:
  - kind: User
    name: olivia
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: app-manager
  apiGroup: rbac.authorization.k8s.io
```

Reapply with `kubectl apply -f`. The Role updates in place (rules are mutable). The RoleBinding, however, has an immutable `roleRef`, but since you are not changing `roleRef`, only `subjects`, the apply will succeed. If you had also needed to change `roleRef`, you would have had to delete and recreate.

**Lesson:** The three most common silent-failure modes in RBAC are all demonstrated in this one exercise: singular resource names, the `"core"` vs `""` confusion, and case-sensitive subject kinds.

---

### Exercise 5.2 Solution

The prod tier is the interesting part. `resourceNames` restricts a rule to specific named objects, but only for verbs that target individual objects. You cannot use `resourceNames` with `list` or `watch` in a way that filters the collection, because those verbs return all objects by design. The workaround, when you genuinely need both "can list all" and "can only modify one," is to split into two rules.

For this exercise peter does not need to list, only `get`, `update`, and `patch` a specific deployment. So a single rule with `resourceNames: ["app"]` and verbs `get, update, patch` works cleanly.

```yaml
# dev: full control
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: dev-admin
  namespace: ex-5-2-dev
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: peter-dev-admin
  namespace: ex-5-2-dev
subjects:
  - kind: User
    name: peter
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: dev-admin
  apiGroup: rbac.authorization.k8s.io
---
# staging: deployment admin, pod read-only
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: staging-deploy-admin
  namespace: ex-5-2-staging
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: peter-staging-deploy-admin
  namespace: ex-5-2-staging
subjects:
  - kind: User
    name: peter
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: staging-deploy-admin
  apiGroup: rbac.authorization.k8s.io
---
# prod: resourceNames restriction on "app" only
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: prod-app-patcher
  namespace: ex-5-2-prod
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    resourceNames: ["app"]
    verbs: ["get", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: peter-prod-app-patcher
  namespace: ex-5-2-prod
subjects:
  - kind: User
    name: peter
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: prod-app-patcher
  apiGroup: rbac.authorization.k8s.io
```

**What to notice:**

- The prod rule omits `list` and `watch` entirely. This means peter cannot run `kubectl get deployments -n ex-5-2-prod` to see a list. But he can `kubectl get deployment app -n ex-5-2-prod` because that is a `get` against a single named object. The verification block only tests per-object access, which matches the intent.
- If the exercise had required peter to also see the list of deployments in prod while still being restricted to modifying only `app`, you would add a second rule without `resourceNames` granting only `list` and `watch` broadly.
- `resourceNames` is always a list. A single resource name still gets wrapped: `resourceNames: ["app"]`.
- `create` fundamentally cannot be scoped by `resourceNames` because at create time the object does not exist yet and has no name to match against. Kubernetes will accept the YAML with `resourceNames` and `create` both present, but the `create` verb will just never apply. The rule for prod correctly omits `create` entirely.

---

### Exercise 5.3 Solution

Six RBAC objects total: one Role and one RoleBinding per team for their primary namespace, plus two small cross-namespace Roles and RoleBindings for riley's and sam's read-only service visibility.

```yaml
# quinn: full control in db namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: db-admin
  namespace: ex-5-3-db
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["services", "configmaps", "secrets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: quinn-db-admin
  namespace: ex-5-3-db
subjects:
  - kind: User
    name: quinn
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: db-admin
  apiGroup: rbac.authorization.k8s.io
---
# riley: full control in api namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: api-admin
  namespace: ex-5-3-api
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["services", "configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: riley-api-admin
  namespace: ex-5-3-api
subjects:
  - kind: User
    name: riley
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: api-admin
  apiGroup: rbac.authorization.k8s.io
---
# riley: read services in db namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: service-viewer
  namespace: ex-5-3-db
rules:
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: riley-db-service-viewer
  namespace: ex-5-3-db
subjects:
  - kind: User
    name: riley
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: service-viewer
  apiGroup: rbac.authorization.k8s.io
---
# sam: full control in web namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: web-admin
  namespace: ex-5-3-web
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["services", "configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: sam-web-admin
  namespace: ex-5-3-web
subjects:
  - kind: User
    name: sam
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: web-admin
  apiGroup: rbac.authorization.k8s.io
---
# sam: read services in api namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: service-viewer
  namespace: ex-5-3-api
rules:
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: sam-api-service-viewer
  namespace: ex-5-3-api
subjects:
  - kind: User
    name: sam
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: service-viewer
  apiGroup: rbac.authorization.k8s.io
```

**Notice:** The `service-viewer` Role is defined twice, once in `ex-5-3-db` and once in `ex-5-3-api`. They are separate objects because Roles are namespace-scoped. If this duplication bothers you, a ClusterRole named `service-viewer` bound by two RoleBindings into each target namespace would be the refactor. For a three-team setup either approach is fine, but the ClusterRole pattern scales better as more teams need the same read-only template.

---

## Common Patterns Worth Memorizing

**The read-only pattern.** Verbs are always `get, list, watch`. No exceptions. "Read" and "view" are not valid.

**The full-control pattern.** Verbs are `get, list, watch, create, update, patch, delete`. Memorize this seven-verb set. For many exam questions it is the right answer. `deletecollection` is rarely needed and can be omitted unless the question specifically requires it.

**The admin-in-one-ns, read-in-another pattern.** Two separate RoleBindings, two separate Roles (or one ClusterRole bound twice). This is the bread-and-butter of real-world RBAC.

**The ClusterRole-bound-via-RoleBinding trick.** When you want the same permission template in many namespaces, define it once as a ClusterRole. Then bind it with RoleBindings (not ClusterRoleBindings) in each target namespace. The RoleBinding scopes the permission to its own namespace, even though the underlying role is cluster-wide.

**The ServiceAccount subject.** `kind: ServiceAccount`, no `apiGroup`, `name` is the SA's name, and `namespace` is required. For impersonation the user string is `system:serviceaccount:NAMESPACE:SA_NAME`.

## Mistakes to Avoid

Forgetting that `apiGroups: [""]` (empty string) is the core group. Writing `"core"` or `"v1"` is the same as writing a non-existent group.

Using singular resource names. It is `deployments` not `deployment`, `pods` not `pod`.

Writing `kind: user` or `kind: group` instead of `User` or `Group`. Case matters.

Trying to edit `roleRef` on an existing RoleBinding. You cannot. Delete and recreate.

Using `resourceNames` with `list` or `watch` and expecting it to filter the collection. It does not work that way. Split the rule.

Putting the wrong API group for deployments. Deployments are in `apps`, not core.

Naming the Role and the `roleRef.name` differently. Kubernetes will not warn you. The binding will silently point at nothing.

## Verification Commands Cheat Sheet

```bash
# Direct yes/no check as a user
kubectl auth can-i VERB RESOURCE -n NAMESPACE --as=USER

# Check as a user AND a group
kubectl auth can-i VERB RESOURCE -n NAMESPACE --as=USER --as-group=GROUP

# Check as a ServiceAccount
kubectl auth can-i VERB RESOURCE -n NAMESPACE \
  --as=system:serviceaccount:NAMESPACE:SA_NAME

# Check a specific named object
kubectl auth can-i VERB RESOURCE/NAME -n NAMESPACE --as=USER

# Dump everything a subject can do in a namespace
kubectl auth can-i --list -n NAMESPACE --as=USER

# Inspect objects
kubectl get role ROLE -n NS -o yaml
kubectl describe rolebinding BINDING -n NS
kubectl get rolebinding -n NS

# Who has access to this resource?
kubectl describe rolebinding -n NS       # scan all bindings in the namespace
kubectl get rolebinding -A -o wide       # across all namespaces
```

When in doubt during the exam, `kubectl auth can-i --list -n NS --as=USER` is the fastest way to see the full picture of what a user can actually do. It reports every resource and verb combination the authorization layer would allow, not what you think you configured.
