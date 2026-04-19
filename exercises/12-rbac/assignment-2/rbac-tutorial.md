# RBAC Tutorial, Part 2: Cluster-Scoped Permissions and Reusable Templates

Assignment 1 covered the namespace-scoped half of RBAC: you built a Role, bound it to `jane` with a RoleBinding, and verified that her permissions only applied inside the `tutorial-rbac` namespace. This tutorial picks up where that one left off. It teaches what you need to model permissions on cluster-scoped resources (nodes, PersistentVolumes, namespaces, StorageClasses, the RBAC objects themselves), how to reuse a single ClusterRole across many namespaces with RoleBindings, how the control plane composes permissions through ClusterRole aggregation, what the four default user-facing ClusterRoles (`cluster-admin`, `admin`, `edit`, `view`) grant and withhold, how to grant access to non-resource URLs like `/healthz`, and how the API server prevents privilege escalation by requiring a user to either already hold the permissions they want to grant, or hold the explicit `escalate` or `bind` verbs.

The tutorial runs in a single namespace called `tutorial-rbac` and uses two protagonists: `aria`, a platform operator who will accumulate cluster-wide permissions through the tutorial, and `brian`, a namespace operator who shows how a single ClusterRole can serve both cluster-wide and namespaced use. Throughout the tutorial, verification uses `kubectl auth can-i --as=USER` rather than full certificate-based impersonation, because Assignment 1 already taught certificate creation and repeating it here would bury the RBAC content. The `--as` flag uses the same authorization code path the API server runs for a real authenticated identity, so the yes/no answers match what a certificate-authenticated session would see.

## Prerequisites

You need a running kind cluster. The authoritative creation command is in `docs/cluster-setup.md#single-node-kind-cluster`. Verify your current context points at it:

```bash
kubectl config current-context
```

Expected: `kind-kind`.

Confirm your admin context has `impersonate` rights (it does by default in a fresh kind cluster, because the default kubeconfig user is in the `system:masters` group bound to `cluster-admin`):

```bash
kubectl auth can-i impersonate users
```

Expected: `yes`.

Create the tutorial namespace. Everything created inside the cluster scope in this tutorial lives at cluster scope, but a namespace is still useful because some examples use namespaced resources to demonstrate scope boundaries.

```bash
kubectl create namespace tutorial-rbac
```

## Step 1: Understand the Scope Matrix

The four RBAC kinds form a two-by-two matrix: Role and ClusterRole on the vertical (permission scope), RoleBinding and ClusterRoleBinding on the horizontal (effective scope). You saw the namespace-scoped column in Assignment 1. This tutorial fills in the right column and the interesting diagonal cell.

A **Role** is always namespace-scoped. It can only grant permissions on namespaced resources (pods, services, configmaps, deployments, and so on). Bound by a RoleBinding, the permissions apply only inside the RoleBinding's namespace. A Role cannot grant access to cluster-scoped resources no matter how it is bound.

A **ClusterRole** is cluster-scoped. It can grant permissions on cluster-scoped resources (nodes, PersistentVolumes, namespaces themselves, StorageClasses, IngressClasses, PriorityClasses, ClusterRoles, ClusterRoleBindings), on non-resource URL endpoints (`/healthz`, `/metrics`, `/api`, `/apis`), and on namespaced resources (pods, services, configmaps, and so on). The effective scope depends on how it is bound.

A **RoleBinding** is namespace-scoped. It can reference a Role in the same namespace, or it can reference a ClusterRole and bind its permissions only inside the RoleBinding's namespace. That second form is the "ClusterRole as reusable template" pattern and is heavily used in production clusters.

A **ClusterRoleBinding** is cluster-scoped. It can only reference a ClusterRole. The permissions apply cluster-wide, across every namespace for namespaced resources, and at the cluster scope for cluster-scoped resources and non-resource URLs.

Two consequences of this matrix that repeatedly catch learners:

Rules in a Role or ClusterRole that mention cluster-scoped resources (`nodes`, `persistentvolumes`, `namespaces`) only produce real permissions when the ClusterRole is bound via a ClusterRoleBinding. A RoleBinding that references a ClusterRole silently discards the cluster-scoped portion; only the namespaced parts survive, scoped to the RoleBinding's namespace. This is the failure mode behind the most common "I granted node access but the user still cannot list nodes" ticket.

Rules that use `nonResourceURLs` only take effect when the ClusterRole is bound via a ClusterRoleBinding. The underlying reason is the same: non-resource URLs are not namespaced, so binding them in a namespace produces no effective permission.

## Step 2: Build a Platform-Reader ClusterRole for aria

Give `aria` read-only access to cluster state: nodes, namespaces, and PersistentVolumes. These are three of the resources platform engineers look at most often, and they all live at cluster scope.

### Imperative form

The `kubectl create clusterrole` subcommand knows how to build a ClusterRole from `--verb` and `--resource` flags. Resources for cluster-scoped objects look the same as for namespaced ones, so you do not need anything special:

```bash
kubectl create clusterrole platform-reader \
  --verb=get,list,watch \
  --resource=nodes,namespaces,persistentvolumes
```

Verify the ClusterRole was created:

```bash
kubectl get clusterrole platform-reader
```

Expected: one row with AGE a few seconds old.

Inspect the rules it produced:

```bash
kubectl get clusterrole platform-reader -o yaml
```

You will see a single `rules[0]` entry with `apiGroups: [""]`, `resources: [nodes, namespaces, persistentvolumes]`, and `verbs: [get, list, watch]`. All three resources happen to live in the core API group, so they collapse into one rule. If you had mixed in `storageclasses` (which lives in `storage.k8s.io`), the imperative form would generate two rules.

### Declarative form

The same permissions as YAML:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-reader
rules:
  - apiGroups: [""]
    resources: ["nodes", "namespaces", "persistentvolumes"]
    verbs: ["get", "list", "watch"]
```

ClusterRole spec fields relevant to this tutorial:

The `metadata.name` is how ClusterRoleBindings reference the role. ClusterRoles are cluster-scoped, so `metadata.namespace` does nothing on a ClusterRole; omit it. Setting it silently does not constrain scope.

The `rules` field is a list; each element is one rule triple of `apiGroups`, `resources`, `verbs`, optionally extended by `resourceNames` and `nonResourceURLs`. Default when omitted: no permissions at all. A ClusterRole with an empty `rules` list is valid and simply grants nothing.

The `apiGroups` field is a list of API group strings. The empty string `""` is the core group (pods, services, nodes, namespaces, persistentvolumes). Named groups are written as they appear in `kubectl api-resources`: `apps`, `batch`, `rbac.authorization.k8s.io`, `storage.k8s.io`, and so on. Default when omitted: the field is required for resource-based rules (rules without `nonResourceURLs`). Failure mode when wrong: the rule silently matches no resources and the RBAC evaluator returns no permission, with no warning.

The `resources` field is a list of plural, lowercase resource names exactly as they appear in the URL. It is `nodes`, never `Node` or `node`. Default when omitted: the field is required for resource-based rules. Failure mode when the name is wrong (singular, mixed case, or non-existent): the rule silently matches no resources.

The `verbs` field is a list. The recognized verbs are `get`, `list`, `watch`, `create`, `update`, `patch`, `delete`, `deletecollection`, and the rare `impersonate`, `bind`, `escalate`. You can use `"*"` to mean all of them. Default when omitted: the field is required. Failure mode when misspelled: typos like `"read"`, `"view"`, or `"edit"` apply successfully (Kubernetes does not validate verbs against a closed list at admission time) and silently match no requests, so `kubectl auth can-i` always returns no.

The `resourceNames` field is an optional list restricting a rule to specific named objects. It works with verbs that target a single object (`get`, `update`, `patch`, `delete`, and subresource verbs like `pods/exec`). It does not meaningfully scope `list` or `watch`, and it cannot be used with top-level `create` or `deletecollection`. For a cluster-scoped resource like a Node, `resourceNames` identifies a specific node by its name. Default when omitted: all objects of the given kind are in scope. Failure mode when using `create` with `resourceNames`: the rule applies but the `create` verb never grants access, because at create time the name is not known.

The `nonResourceURLs` field is an optional list of URL prefixes used for endpoints that are not Kubernetes API resources, like `/healthz` and `/metrics`. Values are treated as literal paths, except a trailing `*` acts as a suffix glob (`/healthz/*` matches `/healthz/etcd` and `/healthz/ping`). Default when omitted: no non-resource URL access is granted. Failure mode when used in a Role or bound via a RoleBinding: silently ineffective, because non-resource URLs are themselves not namespaced.

## Step 3: Bind the ClusterRole Cluster-Wide with a ClusterRoleBinding

The ClusterRole exists but grants nothing yet. Attach it to `aria` cluster-wide:

```bash
kubectl create clusterrolebinding aria-platform-reader \
  --clusterrole=platform-reader \
  --user=aria
```

Verify:

```bash
kubectl get clusterrolebinding aria-platform-reader
```

Now confirm authorization works cluster-wide:

```bash
kubectl auth can-i list nodes --as=aria                           # expect: yes
kubectl auth can-i list namespaces --as=aria                      # expect: yes
kubectl auth can-i get pv --as=aria                               # expect: yes
kubectl auth can-i list pods --all-namespaces --as=aria           # expect: no
kubectl auth can-i delete nodes --as=aria                         # expect: no
```

The last two answers show both boundaries of what you granted: aria can read the three resource types you named but nothing else, and she cannot write to any of them.

### Declarative ClusterRoleBinding

The equivalent YAML:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: aria-platform-reader
subjects:
  - kind: User
    name: aria
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: platform-reader
  apiGroup: rbac.authorization.k8s.io
```

ClusterRoleBinding spec fields relevant to this tutorial:

The `metadata.name` is only used for `kubectl get` and deletion; it has no effect on authorization. ClusterRoleBindings are cluster-scoped, so `metadata.namespace` is not set; setting it produces a validation error.

The `subjects` field is a list of one or more subjects being granted the role. Each subject has `kind` (one of `User`, `Group`, `ServiceAccount`, case-sensitive), `name`, and an `apiGroup`. For `User` and `Group`, `apiGroup` must be `rbac.authorization.k8s.io`. For `ServiceAccount`, `apiGroup` is empty (or omitted) because ServiceAccounts are core resources, and `namespace` is required because ServiceAccounts are namespaced. Default when omitted: the binding grants nothing, but the object still applies.

The `roleRef` field names the role being granted. Its three subfields (`kind`, `name`, `apiGroup`) are all required and the whole field is immutable after creation. For a ClusterRoleBinding, `kind` must be `ClusterRole` (a ClusterRoleBinding cannot reference a Role); the API server rejects the binding at apply time if `kind: Role` is used. For a RoleBinding, `kind` can be either `Role` or `ClusterRole`. Failure mode when `roleRef.kind` is misspelled: the binding is rejected at apply with a validation error (this is one of the few RBAC mistakes the API server catches immediately). Failure mode when `roleRef.name` does not match an existing role: the binding applies successfully and silently grants nothing, because the binding points at a non-existent role.

## Step 4: Reuse platform-reader as a Namespaced Permission with a RoleBinding

The most interesting cell in the scope matrix is the diagonal: ClusterRole bound via RoleBinding. The permissions from the ClusterRole apply only inside the RoleBinding's namespace, and only for the namespaced subset of the ClusterRole's rules.

Create a second user `brian` who should have the same read access as aria, but only in `tutorial-rbac`:

```bash
kubectl create rolebinding brian-platform-reader \
  --clusterrole=platform-reader \
  --user=brian \
  --namespace=tutorial-rbac
```

Verify what brian can see:

```bash
kubectl auth can-i list pods -n tutorial-rbac --as=brian            # expect: no  (pods not in platform-reader)
kubectl auth can-i list namespaces --as=brian                       # expect: no  (cluster-scoped, RoleBinding cannot grant)
kubectl auth can-i get namespace/tutorial-rbac --as=brian           # expect: no  (same reason)
kubectl auth can-i list nodes --as=brian                            # expect: no  (cluster-scoped)
kubectl auth can-i list pv --as=brian                               # expect: no  (cluster-scoped)
```

Every check returns no. This is the silent-failure mode the scope matrix predicts: the ClusterRole rules reference only cluster-scoped resources, and a RoleBinding cannot grant cluster-scoped access regardless of which ClusterRole it references. The RoleBinding applied without error, and nothing in the output explains why the permissions are empty.

To make the diagonal useful, the ClusterRole must include rules on namespaced resources. Extend the ClusterRole to also grant read access to configmaps:

```bash
kubectl patch clusterrole platform-reader --type='json' \
  -p='[{"op":"add","path":"/rules/-","value":{"apiGroups":[""],"resources":["configmaps"],"verbs":["get","list","watch"]}}]'
```

Now retest. Brian inherits configmap read access only inside `tutorial-rbac`; aria inherits it cluster-wide:

```bash
kubectl auth can-i list configmaps -n tutorial-rbac --as=brian      # expect: yes
kubectl auth can-i list configmaps -n default --as=brian            # expect: no
kubectl auth can-i list configmaps --all-namespaces --as=aria       # expect: yes
```

The same ClusterRole serves both use cases. This is why production clusters often define a small set of ClusterRoles (`monitoring-reader`, `app-operator`, `secrets-manager`) and bind them per-namespace with RoleBindings for team-scoped access while occasionally binding one of them cluster-wide for platform roles.

## Step 5: Grant Access to Non-Resource URLs

Some useful API server endpoints are not Kubernetes resources. `/healthz`, `/livez`, and `/readyz` are the health probes; `/metrics` exports Prometheus metrics; `/version` reports build information. Access to these is granted through `nonResourceURLs` rules.

Add a rule to platform-reader that allows aria to hit the health endpoints:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-reader
rules:
  - apiGroups: [""]
    resources: ["nodes", "namespaces", "persistentvolumes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch"]
  - nonResourceURLs: ["/healthz", "/livez", "/readyz", "/healthz/*"]
    verbs: ["get"]
```

Apply it:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-reader
rules:
  - apiGroups: [""]
    resources: ["nodes", "namespaces", "persistentvolumes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch"]
  - nonResourceURLs: ["/healthz", "/livez", "/readyz", "/healthz/*"]
    verbs: ["get"]
EOF
```

Verify cluster-wide access for aria:

```bash
kubectl auth can-i get /healthz --as=aria         # expect: yes
kubectl auth can-i get /livez --as=aria           # expect: yes
kubectl auth can-i get /metrics --as=aria         # expect: no (not granted)
```

Now verify that brian (bound via RoleBinding) still does not get non-resource URL access, even though his binding references the same ClusterRole:

```bash
kubectl auth can-i get /healthz --as=brian        # expect: no
```

This is the second consequence of the scope matrix: non-resource URLs are not namespaced, so a RoleBinding that references a ClusterRole containing `nonResourceURLs` rules silently drops them. Only aria's ClusterRoleBinding reaches those rules.

The `*` suffix glob in the rule (`/healthz/*`) matches subpaths like `/healthz/etcd` and `/healthz/ping`. It is a suffix glob, not a general-purpose wildcard; `*/healthz` would not match anything useful.

## Step 6: Aggregate ClusterRoles

Aggregation lets you build a composite ClusterRole out of many source ClusterRoles selected by labels. The composite's `rules` field is owned by the control plane: if you write rules there, they get overwritten on the next reconciliation. You only write the `aggregationRule`.

The four default user-facing ClusterRoles (`cluster-admin`, `admin`, `edit`, `view`) are all aggregation targets. Kubernetes ships with source ClusterRoles that pre-populate them. To extend any of them, create a new ClusterRole with the right label.

Confirm that the `view` ClusterRole is aggregated:

```bash
kubectl get clusterrole view -o jsonpath='{.aggregationRule}'
```

Expected (formatted): `{"clusterRoleSelectors":[{"matchLabels":{"rbac.authorization.k8s.io/aggregate-to-view":"true"}}]}`.

Now add priorityclasses read access to the `view` role by creating a new ClusterRole with the aggregation label:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: view-priorityclasses
  labels:
    rbac.authorization.k8s.io/aggregate-to-view: "true"
rules:
  - apiGroups: ["scheduling.k8s.io"]
    resources: ["priorityclasses"]
    verbs: ["get", "list", "watch"]
```

Apply it:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: view-priorityclasses
  labels:
    rbac.authorization.k8s.io/aggregate-to-view: "true"
rules:
  - apiGroups: ["scheduling.k8s.io"]
    resources: ["priorityclasses"]
    verbs: ["get", "list", "watch"]
EOF
```

Wait a second for the aggregation controller to run, then verify the composite picked up the new rule:

```bash
kubectl get clusterrole view -o yaml | grep -A2 priorityclasses
```

Expected: a rule block with `apiGroups: [scheduling.k8s.io]`, `resources: [priorityclasses]`, `verbs: [get, list, watch]` now present in the `view` ClusterRole's rendered rules.

Bind the built-in `view` ClusterRole to a test user and confirm the aggregated permission applies:

```bash
kubectl create clusterrolebinding chandra-view --clusterrole=view --user=chandra
kubectl auth can-i list priorityclasses --as=chandra     # expect: yes
```

Aggregation field walkthrough:

The `aggregationRule` field is a structure with one subfield: `clusterRoleSelectors`, a list of `matchLabels` or `matchExpressions` selectors. Default when omitted: the ClusterRole is not an aggregation target and its `rules` are authoritative. Failure mode when set wrong: selectors with no matches produce an empty `rules` list on the target after reconciliation, meaning the composite ClusterRole grants nothing even if you also wrote rules manually (the control plane overwrites them).

The aggregation label keys follow the pattern `rbac.authorization.k8s.io/aggregate-to-<name>`. For the four built-in targets, the names are `admin`, `edit`, `view`, and `cluster-admin`. You can create your own aggregation target with any label name you want by setting the target's `clusterRoleSelectors` accordingly (for example, `rbac.example.com/aggregate-to-monitoring: "true"`).

## Step 7: Tour the Default ClusterRoles

Kubernetes ships a set of ClusterRoles the API server bootstraps on startup. They fall into two categories: the four user-facing roles (no `system:` prefix) and the system roles used by control-plane components (every one starts with `system:`).

### The four user-facing roles

The four user-facing ClusterRoles are designed for you to reference in RoleBindings and ClusterRoleBindings without modifying them.

**`cluster-admin`**. Allows any action on any resource. The default binding is the `cluster-admin` ClusterRoleBinding that targets the `system:masters` group. When used in a ClusterRoleBinding, it gives full control cluster-wide. When used in a RoleBinding, it gives full control only inside the RoleBinding's namespace, including the ability to delete that namespace itself.

**`admin`**. Intended to be granted per-namespace with a RoleBinding. Allows read and write to most resources in the namespace, including creating Roles and RoleBindings. It does not allow write access to the namespace object itself, nor to ResourceQuotas, nor to EndpointSlices.

**`edit`**. Also intended to be granted per-namespace with a RoleBinding. Allows read and write to most objects in the namespace but not to Roles or RoleBindings. One subtlety: `edit` does allow access to Secrets and the ability to run pods as any ServiceAccount in the namespace, which is an indirect privilege-escalation path. Treat `edit` as nearly equivalent to namespace-admin for security purposes.

**`view`**. Read-only access to most objects in the namespace. Deliberately does not include Secrets, because reading Secrets in a namespace would leak ServiceAccount tokens and thereby any permission those ServiceAccounts hold. `view` also does not permit reading Roles or RoleBindings.

Verify the defaults exist and read their descriptions directly:

```bash
kubectl get clusterroles cluster-admin admin edit view
kubectl describe clusterrole view | head -20
```

### System-prefixed roles and the `system:masters` group

All default ClusterRoles managed by the control plane carry the label `kubernetes.io/bootstrapping=rbac-defaults`, and most of them use the `system:` prefix. Examples worth knowing:

`system:kube-scheduler` is bound to the `system:kube-scheduler` user and grants the scheduler the rights it needs to read pods and write bindings.

`system:kube-controller-manager` is bound to the `system:kube-controller-manager` user and grants the controller manager access across the resources its built-in controllers need.

`system:monitoring` grants read access to the control-plane monitoring endpoints (`/healthz`, `/livez`, `/readyz`, `/metrics`) and is bound to the `system:monitoring` group.

`system:basic-user` and `system:discovery` are bound to `system:authenticated` and allow any authenticated user to read basic identity information and API discovery data.

Modifying any `system:`-prefixed role carries real risk because the control plane auto-reconciles them on API server startup (enabled by default when RBAC is active). You can turn reconciliation off for a single role by setting the `rbac.authorization.kubernetes.io/autoupdate: "false"` annotation on it, but you rarely want to.

The `system:masters` group is the bootstrap group. It has no backing ClusterRoleBinding in the default set (it is bound implicitly through the `cluster-admin` ClusterRoleBinding's `system:masters` subject). Your kind cluster's default admin kubeconfig authenticates as the group, which is why your session can impersonate anyone. In real clusters, membership in `system:masters` is tightly controlled.

## Step 8: Privilege Escalation Prevention

The API server enforces two rules even when RBAC would otherwise allow a role-creation or binding-creation action. These rules apply even to admin users, with narrow named exceptions.

**Rule 1: role creation or update.** You can only create or update a Role or ClusterRole if you already hold every permission the role will grant, at the same scope. If you want to grant someone the ability to create arbitrary roles without personally holding those permissions, grant them the `escalate` verb on `roles` or `clusterroles` in `rbac.authorization.k8s.io`.

**Rule 2: binding creation or update.** You can only create or update a RoleBinding or ClusterRoleBinding that references a role whose permissions you already hold, at the same scope. If you want to grant someone the ability to bind a specific role to other subjects without personally holding its permissions, grant them the `bind` verb on that specific role (the rule can be scoped with `resourceNames` to a named role).

Demonstrate the rules:

```bash
kubectl create serviceaccount role-delegate -n tutorial-rbac
```

Create a ClusterRole that allows the delegate to manage RoleBindings and to bind only the `view` ClusterRole:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: view-binder
rules:
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["rolebindings"]
    verbs: ["create", "get", "list", "watch", "delete"]
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["clusterroles"]
    verbs: ["bind"]
    resourceNames: ["view"]
```

Apply it and bind it to the role-delegate service account in `tutorial-rbac`:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: view-binder
rules:
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["rolebindings"]
    verbs: ["create", "get", "list", "watch", "delete"]
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["clusterroles"]
    verbs: ["bind"]
    resourceNames: ["view"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: delegate-view-binder
  namespace: tutorial-rbac
subjects:
  - kind: ServiceAccount
    name: role-delegate
    namespace: tutorial-rbac
roleRef:
  kind: ClusterRole
  name: view-binder
  apiGroup: rbac.authorization.k8s.io
EOF
```

Now check what the delegate can do:

```bash
kubectl auth can-i create rolebindings -n tutorial-rbac \
  --as=system:serviceaccount:tutorial-rbac:role-delegate        # expect: yes
kubectl auth can-i bind clusterroles/view \
  --as=system:serviceaccount:tutorial-rbac:role-delegate        # expect: yes
kubectl auth can-i bind clusterroles/admin \
  --as=system:serviceaccount:tutorial-rbac:role-delegate        # expect: no
```

The delegate can create RoleBindings and can reference the `view` ClusterRole in them, but cannot bind `admin` even though it has RoleBinding create rights. The `bind` verb scoped with `resourceNames: ["view"]` is what makes the API server permit the first binding and deny the second.

If the `view-binder` ClusterRole lacked the `bind` rule entirely, the delegate would only be able to create RoleBindings whose referenced role holds permissions the delegate already has (which would be empty in this case, so effectively none).

## Step 9: ServiceAccount Subjects at Cluster Scope

A service account can be the subject of a ClusterRoleBinding. The identity string Kubernetes authenticates it as is `system:serviceaccount:<namespace>:<name>`, and the subject in the binding must explicitly include the namespace because ServiceAccounts are themselves namespaced.

Create a service account that will hold cluster-wide read access:

```bash
kubectl create serviceaccount cluster-observer -n tutorial-rbac
```

Bind the built-in `view` ClusterRole to it cluster-wide:

```bash
kubectl create clusterrolebinding cluster-observer-view \
  --clusterrole=view \
  --serviceaccount=tutorial-rbac:cluster-observer
```

The declarative equivalent:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-observer-view
subjects:
  - kind: ServiceAccount
    name: cluster-observer
    namespace: tutorial-rbac
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: rbac.authorization.k8s.io
```

Verify:

```bash
kubectl auth can-i list pods --all-namespaces \
  --as=system:serviceaccount:tutorial-rbac:cluster-observer      # expect: yes
kubectl auth can-i list nodes \
  --as=system:serviceaccount:tutorial-rbac:cluster-observer      # expect: yes
kubectl auth can-i get secrets --all-namespaces \
  --as=system:serviceaccount:tutorial-rbac:cluster-observer      # expect: no
```

The last answer is no because `view` does not permit Secrets access, exactly as the default-roles section described.

Two broader group subjects are useful to remember. The group `system:serviceaccounts:<namespace>` contains every service account in one namespace; the group `system:serviceaccounts` contains every service account in the cluster. Granting a ClusterRole to either of these is common in older clusters but is usually considered too permissive today; prefer binding to a specific service account.

## Step 10: Clean Up

When you are finished with the tutorial, delete everything created:

```bash
kubectl delete clusterrolebinding aria-platform-reader chandra-view cluster-observer-view
kubectl delete clusterrole platform-reader view-priorityclasses view-binder
kubectl delete namespace tutorial-rbac
```

The namespace delete cascades through brian's RoleBinding, the role-delegate RoleBinding, and the cluster-observer ServiceAccount. The other cluster-scoped objects must be deleted explicitly because namespace delete does not touch cluster-scoped resources.

## Reference Commands

Keep this section open while working through the homework.

### Imperative cluster-scoped RBAC

```bash
# Create a ClusterRole
kubectl create clusterrole NAME \
  --verb=get,list,watch \
  --resource=nodes,namespaces

# Create a ClusterRole with non-resource URLs
kubectl create clusterrole NAME \
  --verb=get \
  --non-resource-url=/healthz,/livez

# Create a ClusterRole with an aggregation rule
kubectl create clusterrole NAME \
  --aggregation-rule="rbac.example.com/aggregate-to-monitoring=true"

# Bind a ClusterRole cluster-wide
kubectl create clusterrolebinding NAME \
  --clusterrole=CLUSTERROLE \
  --user=USER

# Bind a ClusterRole to a service account cluster-wide
kubectl create clusterrolebinding NAME \
  --clusterrole=CLUSTERROLE \
  --serviceaccount=NAMESPACE:SA_NAME

# Bind a ClusterRole inside a namespace (reusable-template pattern)
kubectl create rolebinding NAME \
  --clusterrole=CLUSTERROLE \
  --user=USER \
  --namespace=NS
```

### Declarative templates

ClusterRole for cluster-scoped resources:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ROLE_NAME
rules:
  - apiGroups: [""]
    resources: ["nodes", "namespaces", "persistentvolumes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
```

ClusterRoleBinding:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: BINDING_NAME
subjects:
  - kind: User
    name: USERNAME
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: ROLE_NAME
  apiGroup: rbac.authorization.k8s.io
```

Aggregated ClusterRole (target):

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: composite-role
aggregationRule:
  clusterRoleSelectors:
    - matchLabels:
        rbac.example.com/aggregate-to-composite: "true"
rules: []
```

Source ClusterRole that contributes to the target:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: source-role
  labels:
    rbac.example.com/aggregate-to-composite: "true"
rules:
  - apiGroups: ["example.com"]
    resources: ["widgets"]
    verbs: ["get", "list", "watch"]
```

### Cluster-scoped resource reference

| Resource | apiGroup | Notes |
|---|---|---|
| nodes | `""` | Cluster-scoped. |
| namespaces | `""` | Cluster-scoped. Write access to the namespace object is admin-only. |
| persistentvolumes | `""` | Cluster-scoped. |
| storageclasses | `"storage.k8s.io"` | Cluster-scoped. |
| ingressclasses | `"networking.k8s.io"` | Cluster-scoped. |
| priorityclasses | `"scheduling.k8s.io"` | Cluster-scoped. |
| clusterroles, clusterrolebindings | `"rbac.authorization.k8s.io"` | Cluster-scoped. Requires `escalate` or `bind` to modify when you lack the underlying permissions. |
| customresourcedefinitions | `"apiextensions.k8s.io"` | Cluster-scoped. |
| certificatesigningrequests | `"certificates.k8s.io"` | Cluster-scoped. |

### Debugging commands

```bash
# List every permission a user has
kubectl auth can-i --list --as=USER

# Check one permission as a user
kubectl auth can-i VERB RESOURCE --as=USER

# Check one permission as a service account
kubectl auth can-i VERB RESOURCE --as=system:serviceaccount:NS:NAME

# Check permission on a non-resource URL
kubectl auth can-i get /healthz --as=USER

# Inspect the effective rules of an aggregated ClusterRole
kubectl get clusterrole NAME -o yaml

# List all ClusterRoleBindings referencing a specific subject
kubectl get clusterrolebindings -o json \
  | jq '.items[] | select(.subjects[]?.name=="USER") | .metadata.name'
```

The `--as-group=` flag pairs with `--as=` when testing group-based permissions, and `--as=system:serviceaccount:NS:NAME` is the only way to test service-account access without deploying a pod.
