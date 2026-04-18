# RBAC (Cluster-Scoped) Homework Answers

Complete solutions for all 15 exercises. Every Level 3 and Level 5 debugging answer follows the three-stage structure: Diagnosis (the exact commands a learner should run and what output to read), What the bug is and why (the underlying cause), and Fix (the corrected configuration). Solutions show a single canonical form per exercise; imperative vs declarative is called out where both are reasonable.

---

## Exercise 1.1 Solution

### Imperative

```bash
kubectl create clusterrole node-viewer --verb=get,list,watch --resource=nodes
kubectl create clusterrolebinding alice-node-viewer \
  --clusterrole=node-viewer \
  --user=alice
```

### Declarative

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-viewer
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: alice-node-viewer
subjects:
  - kind: User
    name: alice
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: node-viewer
  apiGroup: rbac.authorization.k8s.io
```

Nodes live in the core API group (apiGroup `""`). The ClusterRoleBinding grants the permission cluster-wide, which is required because Nodes are themselves cluster-scoped.

---

## Exercise 1.2 Solution

```bash
kubectl create clusterrole namespace-lifecycle \
  --verb=get,list,watch,create,delete \
  --resource=namespaces
kubectl create clusterrolebinding bob-namespace-lifecycle \
  --clusterrole=namespace-lifecycle \
  --user=bob
```

Namespaces are core-group, cluster-scoped resources. The rule omits `update` and `patch`, so `bob` cannot change labels or annotations on existing namespaces; he can only create new namespaces and delete existing ones. That matches the task as stated and matches the verification expectations.

---

## Exercise 1.3 Solution

```bash
kubectl create clusterrolebinding charlie-view --clusterrole=view --user=charlie
```

`view` is a default built-in ClusterRole that ships with Kubernetes. It grants read-only access to most objects in a namespace but deliberately omits Secrets, because reading Secrets is equivalent to reading ServiceAccount tokens and thereby every permission those ServiceAccounts hold. The verification block confirms both behaviors: `charlie` can list pods cluster-wide but cannot list Secrets.

---

## Exercise 2.1 Solution

```bash
kubectl create clusterrole pv-manager \
  --verb=get,list,watch,create,update,patch,delete \
  --resource=persistentvolumes
kubectl create clusterrolebinding diana-pv-manager \
  --clusterrole=pv-manager \
  --user=diana
```

PersistentVolumes live in the core API group and are cluster-scoped, so they require a ClusterRoleBinding. The seven-verb set (`get, list, watch, create, update, patch, delete`) is the standard "full control" grant. PersistentVolumeClaims, which are namespaced, are not included because the requirement is scoped to PVs only; `kubectl auth can-i list persistentvolumeclaims --all-namespaces --as=diana` correctly returns no.

---

## Exercise 2.2 Solution

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: storageclass-admin
rules:
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

```bash
kubectl create clusterrolebinding eric-storageclass-admin \
  --clusterrole=storageclass-admin \
  --user=eric
```

The subtle point is the API group. StorageClasses are not in the core group; they live in `storage.k8s.io`. The imperative form (`kubectl create clusterrole storageclass-admin --verb=... --resource=storageclasses`) knows this and writes the correct group automatically; the declarative form is shown above so the group is visible. Getting the group wrong (for example, using `apiGroups: [""]`) is the failure mode of Exercise 3.1.

---

## Exercise 2.3 Solution

```bash
kubectl create clusterrole priorityclass-viewer \
  --verb=get,list,watch \
  --resource=priorityclasses
kubectl create clusterrolebinding fiona-priorityclass-viewer \
  --clusterrole=priorityclass-viewer \
  --user=fiona
```

PriorityClasses live in `scheduling.k8s.io`. As with StorageClasses, the imperative form fills the API group in automatically. The verification block specifically tests `get priorityclass/system-cluster-critical`, one of the two default PriorityClasses Kubernetes ships, to confirm read access is granted.

---

## Exercise 3.1 Solution

### Diagnosis

Confirm the permission is missing as reported:

```bash
kubectl auth can-i list storageclasses --as=george
```

Expected output: `no`.

List the bindings for `george` to confirm at least one binding applies:

```bash
kubectl get clusterrolebindings -o json \
  | jq -r '.items[] | select(.subjects[]?.name=="george") | .metadata.name'
```

Expected: `george-storageclass-reader`. A binding is present, so the problem is not that `george` is unbound.

Inspect the referenced ClusterRole:

```bash
kubectl get clusterrole ex-3-1-storageclass-reader -o yaml
```

Look at the `rules[0].apiGroups` field. It reads `[""]`. Now check what group StorageClasses actually live in:

```bash
kubectl api-resources | grep -i storageclass
```

The output shows `storageclasses` with `APIVERSION: storage.k8s.io/v1`. The rule says core (empty string); the actual API group is `storage.k8s.io`. RBAC matches rules by (apiGroup, resource) tuple, so a rule for (core, storageclasses) matches nothing that actually exists and grants nothing.

### What the bug is and why it happens

The ClusterRole has `apiGroups: [""]` (the core API group) for the `storageclasses` resource. StorageClasses live in the `storage.k8s.io` API group, not the core group. RBAC silently ignores rules that reference non-existent (group, resource) combinations; there is no "invalid group" validation at apply time. The binding applied, the ClusterRole applied, but the effective permission set is empty because the (group, resource) pair matches nothing.

This is the cluster-scoped cousin of the "deployments live in `apps`, not core" mistake from Assignment 1. Anything outside the core group needs its group named explicitly: `storageclasses` in `storage.k8s.io`, `priorityclasses` in `scheduling.k8s.io`, `ingressclasses` in `networking.k8s.io`, `clusterroles` and `clusterrolebindings` in `rbac.authorization.k8s.io`, and so on.

### Fix

Patch the ClusterRole in place to set the correct API group:

```bash
kubectl patch clusterrole ex-3-1-storageclass-reader --type='json' \
  -p='[{"op":"replace","path":"/rules/0/apiGroups","value":["storage.k8s.io"]}]'
```

Or reapply the corrected ClusterRole:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ex-3-1-storageclass-reader
rules:
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
```

Re-run the verification; `kubectl auth can-i list storageclasses --as=george` returns `yes`.

---

## Exercise 3.2 Solution

### Diagnosis

Start with the permission check:

```bash
kubectl auth can-i list nodes --as=hannah
```

Expected: `no`.

List every binding that applies to `hannah`:

```bash
kubectl get rolebindings -A -o json \
  | jq -r '.items[] | select(.subjects[]?.name=="hannah") | "\(.metadata.namespace)/\(.metadata.name) -> \(.roleRef.kind)/\(.roleRef.name)"'
kubectl get clusterrolebindings -o json \
  | jq -r '.items[] | select(.subjects[]?.name=="hannah") | .metadata.name + " -> " + .roleRef.kind + "/" + .roleRef.name'
```

Output shows one RoleBinding in namespace `ex-3-2` pointing at `ClusterRole/ex-3-2-node-viewer`, and no ClusterRoleBinding anywhere. The RoleBinding applied cleanly, and the ClusterRole it references genuinely grants `get/list/watch` on nodes.

Check the ClusterRole rules to make sure they are correct:

```bash
kubectl get clusterrole ex-3-2-node-viewer -o yaml
```

The rules look fine: `apiGroups: [""]`, `resources: ["nodes"]`, `verbs: ["get", "list", "watch"]`.

So the ClusterRole is correct and a binding exists. The remaining question is whether the binding's scope matches the resource's scope. Nodes are cluster-scoped. A RoleBinding is namespace-scoped even when it references a ClusterRole; it can only grant the ClusterRole's namespaced portion to resources inside its own namespace. It cannot grant access to cluster-scoped resources like Nodes at all.

### What the bug is and why it happens

The binding is a RoleBinding instead of a ClusterRoleBinding. A RoleBinding that references a ClusterRole grants the ClusterRole's permissions only inside the RoleBinding's namespace, and only for the namespaced subset of the rules. When the ClusterRole's rules name cluster-scoped resources like Nodes, those rules are silently dropped: there is no concept of "nodes inside namespace ex-3-2" for the RoleBinding to grant. The apply-time validation does not catch this mismatch because the RoleBinding is structurally valid; only authorization-time evaluation reveals the empty effective permission.

This is the most common silent failure in cluster-scoped RBAC. Anything in the rules that references a cluster-scoped resource (`nodes`, `persistentvolumes`, `namespaces`, `storageclasses`, `priorityclasses`, `clusterroles`, `clusterrolebindings`) requires a ClusterRoleBinding to take effect.

### Fix

A RoleBinding's `roleRef` is immutable and its scope cannot be changed after creation, so the RoleBinding must be deleted and replaced with a ClusterRoleBinding:

```bash
kubectl -n ex-3-2 delete rolebinding hannah-node-viewer
kubectl create clusterrolebinding hannah-node-viewer \
  --clusterrole=ex-3-2-node-viewer \
  --user=hannah
```

Or declaratively:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: hannah-node-viewer
subjects:
  - kind: User
    name: hannah
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: ex-3-2-node-viewer
  apiGroup: rbac.authorization.k8s.io
```

Re-run `kubectl auth can-i list nodes --as=hannah`; the answer is now `yes`.

---

## Exercise 3.3 Solution

### Diagnosis

Start with the permission check:

```bash
kubectl auth can-i get /healthz --as=ian
```

Expected: `no`.

Inspect the ClusterRole to verify the rule is actually about `/healthz`:

```bash
kubectl get clusterrole ex-3-3-health-checker -o yaml
```

The rule looks correct: `nonResourceURLs: ["/healthz", "/healthz/*"]` with `verbs: ["get"]`. So the ClusterRole itself is fine.

Look for the binding:

```bash
kubectl get rolebindings -A -o json \
  | jq -r '.items[] | select(.subjects[]?.name=="ian") | "\(.metadata.namespace)/\(.metadata.name) -> \(.roleRef.kind)/\(.roleRef.name)"'
kubectl get clusterrolebindings -o json \
  | jq -r '.items[] | select(.subjects[]?.name=="ian") | .metadata.name + " -> " + .roleRef.kind + "/" + .roleRef.name'
```

One RoleBinding in `ex-3-3`, no ClusterRoleBinding. The binding is namespace-scoped. Non-resource URLs are not themselves namespaced, so a RoleBinding (which grants only inside a specific namespace) cannot produce a valid authorization for a non-resource URL request no matter which ClusterRole it references.

### What the bug is and why it happens

Non-resource URLs are not Kubernetes resources and are not namespaced. The Kubernetes documentation spells this out directly: a `nonResourceURLs` rule "must be in a ClusterRole bound with a ClusterRoleBinding to be effective." The RoleBinding in `ex-3-3` references the right ClusterRole with the right rule, but the namespace-scoped binding cannot grant access to an endpoint that has no namespace. The rule is silently discarded during authorization, which is why `kubectl auth can-i get /healthz --as=ian` returns no even though the ClusterRole exists and the rule is spelled correctly.

The same pattern applies to `/metrics`, `/livez`, `/readyz`, `/api`, `/apis`, and any other non-resource URL you might want to grant: the binding must be cluster-scoped.

### Fix

Delete the RoleBinding and create a ClusterRoleBinding in its place:

```bash
kubectl -n ex-3-3 delete rolebinding ian-health-checker
kubectl create clusterrolebinding ian-health-checker \
  --clusterrole=ex-3-3-health-checker \
  --user=ian
```

Re-run the verification; `kubectl auth can-i get /healthz --as=ian` and `kubectl auth can-i get /healthz/etcd --as=ian` both return `yes`, while `kubectl auth can-i get /metrics --as=ian` correctly stays `no` because the ClusterRole does not list `/metrics`.

---

## Exercise 4.1 Solution

```bash
kubectl -n ex-4-1 create rolebinding karl-edit \
  --clusterrole=edit \
  --user=karl
```

This is the ClusterRole-with-RoleBinding pattern in its simplest form. The built-in `edit` ClusterRole grants read and write access to most namespaced resources; binding it with a RoleBinding (not a ClusterRoleBinding) restricts the grant to a single namespace. The verification block proves the scope: `karl` can do the full set of write operations in `ex-4-1` but has no access in any other namespace, and cannot reach cluster-scoped resources like Nodes. The fact that `edit` allows reading Secrets is confirmed by the `get secrets -n ex-4-1` check returning `yes`, which is the security trade-off of the default `edit` role.

---

## Exercise 4.2 Solution

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: view-storageclasses
  labels:
    rbac.authorization.k8s.io/aggregate-to-view: "true"
rules:
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
```

Then bind `view` cluster-wide to luna:

```bash
kubectl create clusterrolebinding luna-view --clusterrole=view --user=luna
```

Aggregation matches by label. The built-in `view` ClusterRole's `aggregationRule.clusterRoleSelectors` includes a `matchLabels` rule for `rbac.authorization.k8s.io/aggregate-to-view: "true"`. Any ClusterRole that carries that label contributes its rules to `view` on the next reconciliation pass. The control plane overwrites `view`'s `rules` field automatically; you never edit `view` directly.

A visible side effect of aggregation is that `kubectl get clusterrole view -o yaml` now shows a rule for `storageclasses` inside the composite's rendered rules, even though the rule text lives in the `view-storageclasses` source ClusterRole. If you delete `view-storageclasses`, the aggregation controller removes the corresponding rule from `view` on the next pass.

---

## Exercise 4.3 Solution

```bash
kubectl create clusterrolebinding metric-scraper-view \
  --clusterrole=view \
  --serviceaccount=ex-4-3:metric-scraper
```

The imperative `--serviceaccount=NS:NAME` flag expands into the correct subject form for a service account. The equivalent YAML makes the structure explicit:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: metric-scraper-view
subjects:
  - kind: ServiceAccount
    name: metric-scraper
    namespace: ex-4-3
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
```

Three fields matter on a ServiceAccount subject. `kind: ServiceAccount` is case-sensitive. `namespace: ex-4-3` is required because ServiceAccounts are namespaced. The `apiGroup` field is omitted (or empty) because ServiceAccounts are core resources, not RBAC resources; writing `apiGroup: rbac.authorization.k8s.io` on a ServiceAccount subject is a common mistake that makes the binding fail silently.

The authenticated identity of the service account is `system:serviceaccount:ex-4-3:metric-scraper`, which is what `kubectl auth can-i --as=` must use for verification.

---

## Exercise 5.1 Solution

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-operator
rules:
  # Read access to every resource in every API group, cluster-wide.
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]
  # Manage namespaces (lifecycle control).
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get", "list", "watch", "create", "delete"]
  # Read nodes explicitly (already covered by the wildcard rule, but left here
  # as a reminder that this is the resource the platform role cares about).
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
  # Delegate the admin ClusterRole only, using the `bind` verb.
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["rolebindings"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["clusterroles"]
    verbs: ["bind"]
    resourceNames: ["admin"]
```

```bash
kubectl create clusterrolebinding nina-cluster-operator \
  --clusterrole=cluster-operator \
  --user=nina
```

The design hinges on the `bind` verb. The rule `verbs: ["bind"]` on `clusterroles` with `resourceNames: ["admin"]` is the API server's mechanism for delegating the ability to grant a role. When `nina` attempts to create a RoleBinding whose `roleRef` is `admin`, the API server's binding creation check passes even though `nina` does not personally hold `admin`'s permissions, because she has been explicitly granted `bind` on that specific ClusterRole. The check fails for `edit` or `cluster-admin` because the `resourceNames` list only contains `admin`.

The first rule, `apiGroups: ["*"], resources: ["*"], verbs: ["get", "list", "watch"]`, is the cluster-wide read-everything grant. It is broad on purpose: a platform operator needs to inspect any resource without an allow-list that grows whenever a new CRD appears. The verification block confirms this includes Secrets, which is a real concern for a cluster-operator role; in production you would weigh whether platform visibility is worth Secret read access, and if not, explicitly subtract Secrets with a subsequent targeted ClusterRole bound to a higher-privilege group only.

The rule separately granting `create` and `delete` on namespaces is not redundant with the read-everything rule; the wildcard rule only grants read verbs, so write access to namespaces needs its own explicit rule.

---

## Exercise 5.2 Solution

### Diagnosis

Start with the permission checks:

```bash
kubectl auth can-i list clusterroles --as=olivia
kubectl auth can-i list nodes --as=olivia
```

Both return `no`. Look at the ClusterRole definition:

```bash
kubectl get clusterrole ex-5-2-cluster-support -o yaml
```

The first rule says `apiGroups: ["rbac"]` for `clusterroles`. Check the real API group:

```bash
kubectl api-resources | grep -i clusterrole
```

Output: `clusterroles ... APIVERSION: rbac.authorization.k8s.io/v1`. The rule names the wrong group (`rbac` instead of `rbac.authorization.k8s.io`), so it matches nothing.

The second rule says `resources: ["node"]` (singular). Check the canonical resource name:

```bash
kubectl api-resources | grep -i '^node'
```

The resource is `nodes` (plural). Singular-resource mistakes always fail silently in RBAC.

Look at the ClusterRoleBinding's subjects:

```bash
kubectl get clusterrolebinding olivia-cluster-support -o yaml
```

The `subjects[0].kind` field is `user`, lowercase. Subject kinds are case-sensitive; valid values are `User`, `Group`, and `ServiceAccount` with that exact capitalization.

That is three problems in one manifest, each applied without an error message, each producing a silent authorization failure.

### What the bug is and why it happens

The config has three silent-failure bugs, and each fits a pattern the CKA exam repeatedly tests.

First, `apiGroups: ["rbac"]` is a guess rather than a lookup. The full group name is `rbac.authorization.k8s.io`, which is what `kubectl api-resources` reports and what the RBAC evaluator matches against. The short form `rbac` matches nothing.

Second, `resources: ["node"]` is the singular form. RBAC resource names are always plural, lowercase, and exactly as they appear in the URL. `kubectl api-resources` confirms the canonical form every time.

Third, `kind: user` is lowercase. The API server accepts it at apply time (Kubernetes does not validate this field against a closed enum at admission), and the RBAC evaluator then fails to match it against the `User` subject kind. Case-sensitive kinds are a frequent source of silent failures because the apply path never warns.

These three bugs are independent; fixing any one alone will not make `olivia` functional. All three must be corrected.

### Fix

Patch the ClusterRole's rules and the ClusterRoleBinding's subject kind. The ClusterRoleBinding's `roleRef` is immutable, but `subjects` is mutable, so the fix can be applied in place.

The simplest approach is to reapply the corrected manifest:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ex-5-2-cluster-support
rules:
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["clusterroles"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: olivia-cluster-support
subjects:
  - kind: User
    name: olivia
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: ex-5-2-cluster-support
  apiGroup: rbac.authorization.k8s.io
```

`kubectl apply -f` with the corrected manifest updates the ClusterRole's rules and the ClusterRoleBinding's subjects, since neither change touches `roleRef`. Re-run the verification; all expected-yes checks return yes and the expected-no checks remain no.

---

## Exercise 5.3 Solution

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-reader
rules:
  - apiGroups: [""]
    resources:
      - pods
      - services
      - configmaps
      - namespaces
      - nodes
      - persistentvolumes
      - persistentvolumeclaims
      - events
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "daemonsets", "statefulsets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses", "networkpolicies"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
    verbs: ["get", "list", "watch"]
```

```bash
kubectl create clusterrolebinding priya-cluster-reader \
  --clusterrole=cluster-reader \
  --user=priya
```

The design groups rules by API group because resources in the same group can share a rule when the verbs match. The core group alone covers eight resources, which is why it has the longest resource list. Five additional rules cover the non-core groups (`apps`, `batch`, `networking.k8s.io`, `storage.k8s.io`, `rbac.authorization.k8s.io`).

Three design constraints are worth calling out. First, `secrets` is deliberately absent from the core-group rule. Including it would let `priya` read every ServiceAccount token in every namespace, effectively escalating to the union of every ServiceAccount's permissions. Second, no rule contains the `*` wildcard on resources, apiGroups, or verbs. A wildcard would grant access to any future resource type automatically, which is exactly the drift-prone behavior the `cluster-admin`-avoidance requirement is trying to prevent. Third, the verb set is restricted to the read triplet (`get`, `list`, `watch`); no `update`, `patch`, `create`, `delete`, or `deletecollection` appears anywhere. A real audit role needs only reads.

The verification block confirms the shape: broad read access across namespaces and cluster-scoped resources, no Secrets, no writes.

---

## Common Mistakes

Treating `"rbac"` as the API group for `clusterroles` or `rolebindings`. The full group name is `rbac.authorization.k8s.io`, which is what `kubectl api-resources` reports and what the RBAC evaluator matches against. Short-form guesses match nothing, and the binding silently grants no permissions with no error at apply time. When in doubt, run `kubectl api-resources | grep -E '^(resourcename|resource-name)'` and read the APIVERSION column: the part before the slash is the API group (or empty for core).

Binding a ClusterRole with a RoleBinding when cluster-scoped access was required. RoleBindings grant permissions only inside one namespace, no matter which ClusterRole they reference. Rules that name cluster-scoped resources (`nodes`, `namespaces`, `persistentvolumes`, `storageclasses`, `priorityclasses`, `ingressclasses`, `clusterroles`, `clusterrolebindings`) are silently discarded in that case, producing an empty effective permission set. The same applies to `nonResourceURLs` rules: they are not namespaced, so they only take effect when bound cluster-wide. When a binding does not seem to work, first ask: is the referenced resource cluster-scoped or is it a non-resource URL? If yes, the binding must be a ClusterRoleBinding.

Writing `apiGroup: rbac.authorization.k8s.io` on a `ServiceAccount` subject. ServiceAccounts are core resources, not RBAC resources; the correct form omits `apiGroup` (or sets it to the empty string). Writing the RBAC API group there makes the subject resolution fail silently. The `kind: User` and `kind: Group` subjects do require `apiGroup: rbac.authorization.k8s.io`; the three kinds are not symmetric in their apiGroup rules.

Expecting a ClusterRoleBinding's `roleRef.kind` to accept `Role`. It cannot; a ClusterRoleBinding can only reference a ClusterRole. This mistake is one of the few the API server catches at apply time (with a validation error), unlike most RBAC mistakes which apply silently. The converse is allowed: a RoleBinding's `roleRef.kind` may be either `Role` or `ClusterRole`, and the latter is the reusable-template pattern demonstrated in Exercise 4.1.

Trying to scope `create` or `list` with `resourceNames`. The `resourceNames` field restricts a rule to specific named objects for verbs that target individual objects (`get`, `update`, `patch`, `delete`, and subresource verbs like `pods/exec`). It does not meaningfully constrain `list` or `watch` (those verbs return collections by nature) and it cannot be applied to `create` at all (the object name is not known at create time). Kubernetes accepts a rule with `resourceNames` and `create` together without a warning; the rule simply never grants create access. If the requirement is "allow listing all of X but only updating one specific named X," write two rules.

Editing the `rules` field of an aggregated ClusterRole directly. The control plane owns the `rules` field on any ClusterRole with an `aggregationRule`. Any rules you write there get overwritten on the next reconciliation pass. To add permissions to an aggregated target, create a new ClusterRole with the correct `rbac.authorization.k8s.io/aggregate-to-<name>` label; that source role's rules are composed into the target automatically.

Forgetting that `edit` can read Secrets. The default `edit` ClusterRole grants access to Secrets in a namespace, which is a deliberate design choice (it also lets you read ServiceAccount tokens). Treating `edit` as a safe mid-tier grant is a frequent security mistake: it is nearly equivalent to namespace-admin, because with Secret access and the ability to run pods as any ServiceAccount in the namespace, the holder can acquire every permission any ServiceAccount in the namespace has. Grant `edit` only where you would be comfortable granting namespace-admin.

Relying on general knowledge to decide which default ClusterRole grants what. The four user-facing defaults (`cluster-admin`, `admin`, `edit`, `view`) are aggregation targets whose effective rules depend on what source ClusterRoles the cluster has installed. The safest approach before relying on one is `kubectl describe clusterrole NAME`, which prints the rendered rules after aggregation; `kubectl get clusterrole NAME -o yaml` shows the `aggregationRule` and lets you see which selectors are in play.

---

## Verification Commands Cheat Sheet

```bash
# Direct yes/no check as a user
kubectl auth can-i VERB RESOURCE --as=USER

# Check as a user in a specific namespace (for ClusterRole-bound-via-RoleBinding tests)
kubectl auth can-i VERB RESOURCE -n NAMESPACE --as=USER

# Check as a ServiceAccount (the identity string is system:serviceaccount:NS:NAME)
kubectl auth can-i VERB RESOURCE --as=system:serviceaccount:NAMESPACE:NAME

# Check access on a non-resource URL
kubectl auth can-i get /healthz --as=USER

# Dump every permission a subject has (the fastest way to see the whole picture)
kubectl auth can-i --list --as=USER
kubectl auth can-i --list --as=system:serviceaccount:NAMESPACE:NAME

# Check access cluster-wide (for cluster-scoped resources and --all-namespaces)
kubectl auth can-i list pods --all-namespaces --as=USER
kubectl auth can-i list nodes --as=USER

# Find all bindings that apply to a subject
kubectl get clusterrolebindings -o json \
  | jq -r '.items[] | select(.subjects[]?.name=="USER") | .metadata.name'
kubectl get rolebindings -A -o json \
  | jq -r '.items[] | select(.subjects[]?.name=="USER") | "\(.metadata.namespace)/\(.metadata.name)"'

# Inspect a ClusterRole (including any aggregation rule and composed rules)
kubectl get clusterrole NAME -o yaml
kubectl describe clusterrole NAME

# Confirm the API group and resource name for a resource (resolves group mistakes fast)
kubectl api-resources | grep -i RESOURCENAME

# Verify a specific ClusterRoleBinding's target
kubectl get clusterrolebinding NAME -o yaml
kubectl describe clusterrolebinding NAME
```

When a permission check unexpectedly returns no, run `kubectl auth can-i --list --as=USER` first. If the resource is missing from the list entirely, the problem is probably the API group or the resource name (Exercise 3.1 and Exercise 5.2 failure modes). If the resource is listed at namespace scope but not at cluster scope, the problem is likely a RoleBinding where a ClusterRoleBinding was needed (Exercise 3.2 and Exercise 3.3 failure modes). The `--list` form combined with `kubectl api-resources` covers most real-world RBAC debugging without needing to inspect individual RoleBinding objects.
