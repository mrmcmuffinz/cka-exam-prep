# RBAC Tutorial: From Zero to a Working Developer Identity

This tutorial walks through a single complete, real-world RBAC workflow from start to finish. By the end, you will have a new user named `jane`, her own client certificate signed by the cluster CA, a kubeconfig context named `jane@kind-kind`, and a Role plus RoleBinding that lets her manage Deployments and read Pods in a namespace called `tutorial-rbac`. Everything runs on a rootless `kind` cluster backed by containerd and nerdctl.

The tutorial uses its own namespace (`tutorial-rbac`) and its own user (`jane`) so it will not collide with anything in the homework exercises.

## Prerequisites

You need a running kind cluster. If you do not have one, create it with:

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

Verify it is up and that `kubectl` points at it:

```bash
kubectl cluster-info --context kind-kind
kubectl config current-context
```

You should see `kind-kind` as the current context.

## Step 1: Understand the RBAC Object Model

Before creating anything, it helps to know what the four RBAC objects actually do.

A **Role** is a namespaced collection of permission rules. Each rule says "on these API groups, for these resources, the following verbs are allowed." Roles only grant permission inside a single namespace, and they never grant anything by themselves. They are inert until something binds them to a subject.

A **RoleBinding** is the object that attaches a Role (or a ClusterRole) to a subject. A subject is a user, a group, or a ServiceAccount. RoleBindings are also namespaced, so they only take effect in the namespace they are created in.

A **ClusterRole** is the cluster-scoped cousin of Role. It can grant permissions on cluster-scoped resources like Nodes and PersistentVolumes, and it can also be used as a reusable permission template that gets bound in many namespaces.

A **ClusterRoleBinding** binds a ClusterRole to a subject across the whole cluster. This is what you use when you genuinely need cluster-wide access.

For this tutorial we will only use Role and RoleBinding. ClusterRole and ClusterRoleBinding come later in the course.

## Step 2: Create the Namespace

Start by creating the namespace the tutorial will use. Imperative first:

```bash
kubectl create namespace tutorial-rbac
```

The declarative equivalent, if you wanted to commit it to Git, is:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tutorial-rbac
```

Verify:

```bash
kubectl get namespace tutorial-rbac
```

You should see the namespace in `Active` status.

## Step 3: Create a Client Certificate for jane

Kubernetes does not have user objects in its API. A "user" is whatever string appears in the `Common Name` (CN) field of a client certificate signed by a CA that the API server trusts, or whatever identity a token maps to. For this tutorial we will use the client certificate path because it is the standard CKA-style approach and it works cleanly with kind.

The kind cluster's CA is stored inside the control-plane container. You do not need to extract it manually because kind has already written a fully functional kubeconfig at `~/.kube/config`, and the CA plus admin client certs are already embedded there. We will only need the CA to sign jane's certificate, so we will pull the CA out of the control-plane container directly.

### 3a: Generate jane's private key and certificate signing request

Create a working directory and generate a 2048-bit RSA private key for jane:

```bash
mkdir -p ~/rbac-tutorial-certs && cd ~/rbac-tutorial-certs
openssl genrsa -out jane.key 2048
```

Now create a certificate signing request (CSR). The CN becomes the username Kubernetes sees, and the O (organization) becomes a group. We will set CN to `jane` and O to `developers`:

```bash
openssl req -new -key jane.key -out jane.csr -subj "/CN=jane/O=developers"
```

You now have `jane.key` (private key, keep secret) and `jane.csr` (the signing request).

### 3b: Pull the CA cert and key out of the kind control-plane

Kind names its control-plane container `kind-control-plane` by default. The CA files live at `/etc/kubernetes/pki/ca.crt` and `/etc/kubernetes/pki/ca.key` inside that container. Copy them out:

```bash
nerdctl cp kind-control-plane:/etc/kubernetes/pki/ca.crt ./ca.crt
nerdctl cp kind-control-plane:/etc/kubernetes/pki/ca.key ./ca.key
```

Verify you have all four files:

```bash
ls -1
```

Expected output: `ca.crt`, `ca.key`, `jane.csr`, `jane.key`.

### 3c: Sign jane's CSR with the cluster CA

Sign jane's CSR with the cluster CA, producing `jane.crt` valid for 365 days:

```bash
openssl x509 -req -in jane.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out jane.crt -days 365
```

Confirm the certificate is readable and has the expected subject:

```bash
openssl x509 -in jane.crt -noout -subject
```

Expected: `subject=CN = jane, O = developers`.

## Step 4: Add jane as a kubeconfig User and Context

Now that jane has a signed certificate, you need to tell `kubectl` about her. A kubeconfig file has three kinds of entries: clusters (API server + CA bundle), users (credentials), and contexts (which cluster + which user + which default namespace).

### 4a: Register jane's credentials

Add jane as a user entry in your kubeconfig. The `--embed-certs=true` flag inlines the cert and key into the kubeconfig file itself, which is easier than managing file paths:

```bash
kubectl config set-credentials jane \
  --client-certificate=$HOME/rbac-tutorial-certs/jane.crt \
  --client-key=$HOME/rbac-tutorial-certs/jane.key \
  --embed-certs=true
```

The `set-credentials` subcommand creates or updates a user entry. The three flags point to jane's signed certificate, her private key, and tell kubectl to embed them rather than reference them by path.

### 4b: Create jane's context

A context ties together a cluster reference, a user reference, and a default namespace. Kind already registered the cluster as `kind-kind` in your kubeconfig, so you only need to reference it:

```bash
kubectl config set-context jane@kind-kind \
  --cluster=kind-kind \
  --user=jane \
  --namespace=tutorial-rbac
```

The `user@cluster` naming convention makes it obvious at a glance who you are and where you are pointing. Verify both entries are present:

```bash
kubectl config get-contexts
```

You should see `jane@kind-kind` listed alongside `kind-kind`.

### 4c: Confirm jane has no permissions yet

Switch to jane's context and try to list pods. She should be rejected:

```bash
kubectl --context=jane@kind-kind get pods
```

Expected: a `Forbidden` error saying `jane` cannot list pods in namespace `tutorial-rbac`. This is the baseline. Authentication works (the cluster knows who she is), but authorization does not grant her anything.

## Step 5: Create the Role

Jane's job is to manage Deployments and read Pods in `tutorial-rbac`. Create a Role that captures exactly that.

### Imperative approach

```bash
kubectl create role deployment-manager \
  --verb=get,list,watch,create,update,patch,delete \
  --resource=deployments \
  --namespace=tutorial-rbac
```

That covers Deployments. Now add a second rule for pods, read-only. You cannot add a second rule to an existing role imperatively in a clean way, so for mixed permissions the declarative approach is usually better. Let's rewrite it declaratively.

### Declarative approach

Delete the imperative role first so we can replace it cleanly:

```bash
kubectl delete role deployment-manager -n tutorial-rbac
```

Now create a file `jane-role.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployment-manager
  namespace: tutorial-rbac
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
```

Field-by-field walkthrough:

- `apiVersion: rbac.authorization.k8s.io/v1` is the stable RBAC API. Always use v1.
- `kind: Role` declares the object type. Role is namespace-scoped.
- `metadata.name` is how the Role is referenced by a RoleBinding later.
- `metadata.namespace` must be set on a Role. Without it you would get the `default` namespace, which is almost never what you want.
- `rules` is a list. Each rule is one `{apiGroups, resources, verbs}` triple.
- `apiGroups: [""]` is the core API group (pods, services, configmaps, secrets, namespaces all live here). The empty string is correct, not a typo. To find the right API group for any resource, run `kubectl api-resources` and look at the `APIVERSION` column, where `v1` means core and anything like `apps/v1` means the `apps` group.
- `apiGroups: ["apps"]` is the group for deployments, daemonsets, replicasets, and statefulsets.
- `resources` is the plural lowercase name as it appears in `kubectl api-resources`. Use `pods`, not `Pod` or `pod`.
- `verbs` are the actions. The common set is `get, list, watch, create, update, patch, delete`. There is also `deletecollection`, which lets you delete many at once, and `impersonate`, `bind`, `escalate` for edge cases. For read-only, use `get, list, watch`. For full control, use all seven.

Apply it:

```bash
kubectl apply -f jane-role.yaml
```

Verify:

```bash
kubectl get role deployment-manager -n tutorial-rbac -o yaml
```

## Step 6: Create the RoleBinding

The Role exists but is not attached to anyone. Bind it to jane.

### Imperative approach

```bash
kubectl create rolebinding jane-deployment-manager \
  --role=deployment-manager \
  --user=jane \
  --namespace=tutorial-rbac
```

### Declarative approach

File `jane-rolebinding.yaml`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: jane-deployment-manager
  namespace: tutorial-rbac
subjects:
  - kind: User
    name: jane
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: deployment-manager
  apiGroup: rbac.authorization.k8s.io
```

Field walkthrough:

- `subjects` is a list of who is being granted access. Each subject has a `kind` (User, Group, or ServiceAccount), a `name`, and an `apiGroup`.
- For `User` and `Group` subjects, `apiGroup` must be `rbac.authorization.k8s.io`. The user name must exactly match the CN on the certificate jane presents.
- For `ServiceAccount` subjects, `apiGroup` is empty (`""`) because ServiceAccounts are core resources, and you also need to specify `namespace`.
- `roleRef` points at the Role or ClusterRole to bind. `kind` is either `Role` or `ClusterRole`, `name` is the role's metadata name, and `apiGroup` is always `rbac.authorization.k8s.io`.
- `roleRef` is immutable after creation. If you need to change which role is bound, you must delete and recreate the binding.

Apply:

```bash
kubectl apply -f jane-rolebinding.yaml
```

## Step 7: Verify jane's Permissions

Use `kubectl auth can-i`, which is the single most useful RBAC debugging tool. It answers yes or no based on the same evaluation the API server would do:

```bash
kubectl --context=jane@kind-kind auth can-i list pods -n tutorial-rbac
kubectl --context=jane@kind-kind auth can-i create deployments -n tutorial-rbac
kubectl --context=jane@kind-kind auth can-i delete pods -n tutorial-rbac
kubectl --context=jane@kind-kind auth can-i list pods -n default
```

Expected: `yes`, `yes`, `no`, `no`. The last two confirm two different boundaries: jane cannot delete pods (only read them) and she has no access outside `tutorial-rbac`.

Now exercise the permissions for real. Create a deployment as jane:

```bash
kubectl --context=jane@kind-kind create deployment nginx --image=nginx -n tutorial-rbac
kubectl --context=jane@kind-kind get pods -n tutorial-rbac
```

Both should succeed. Then try something she should not be able to do:

```bash
kubectl --context=jane@kind-kind delete pod --all -n tutorial-rbac
```

Expected: `Forbidden`. Jane can read pods but cannot delete them.

## Step 8: Clean Up

When you are done with the tutorial:

```bash
kubectl delete namespace tutorial-rbac
kubectl config delete-context jane@kind-kind
kubectl config delete-user jane
rm -rf ~/rbac-tutorial-certs
```

The namespace delete cascades and removes the Role and RoleBinding along with it. The context and user deletes clean out the kubeconfig entries.

## Reference Commands

Keep this section open while you do the exercises.

### Imperative RBAC

```bash
# Create a namespaced Role
kubectl create role NAME \
  --verb=get,list,watch \
  --resource=pods,services \
  --namespace=NS

# Create a ClusterRole (same syntax, no namespace)
kubectl create clusterrole NAME \
  --verb=get,list,watch \
  --resource=nodes

# Bind a Role to a user in a namespace
kubectl create rolebinding NAME \
  --role=ROLE_NAME \
  --user=USER \
  --namespace=NS

# Bind a Role to a group
kubectl create rolebinding NAME \
  --role=ROLE_NAME \
  --group=GROUP \
  --namespace=NS

# Bind a ClusterRole to a user in ONE namespace (common pattern)
kubectl create rolebinding NAME \
  --clusterrole=CLUSTERROLE_NAME \
  --user=USER \
  --namespace=NS

# Bind a ClusterRole cluster-wide
kubectl create clusterrolebinding NAME \
  --clusterrole=CLUSTERROLE_NAME \
  --user=USER

# Create a ServiceAccount
kubectl create serviceaccount NAME -n NS

# Bind a role to a ServiceAccount
kubectl create rolebinding NAME \
  --role=ROLE_NAME \
  --serviceaccount=NS:SA_NAME \
  --namespace=NS
```

### Declarative templates

Role:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ROLE_NAME
  namespace: NS
rules:
  - apiGroups: [""]          # core group for pods, services, configmaps, secrets
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]      # for deployments, daemonsets, replicasets
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

RoleBinding:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: BINDING_NAME
  namespace: NS
subjects:
  - kind: User
    name: USERNAME
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: ROLE_NAME
  apiGroup: rbac.authorization.k8s.io
```

### API group cheat sheet

| Resource | apiGroup value |
|----------|----------------|
| pods, services, configmaps, secrets, namespaces, serviceaccounts | `""` (core) |
| deployments, daemonsets, replicasets, statefulsets | `"apps"` |
| roles, rolebindings, clusterroles, clusterrolebindings | `"rbac.authorization.k8s.io"` |
| jobs, cronjobs | `"batch"` |
| ingresses, networkpolicies | `"networking.k8s.io"` |

When in doubt, run `kubectl api-resources` and read the `APIVERSION` column. A bare `v1` means core (empty string), and anything like `apps/v1` means the prefix is the API group.

### Verbs cheat sheet

| Intent | Verbs |
|--------|-------|
| Read only | `get, list, watch` |
| Full control | `get, list, watch, create, update, patch, delete` |
| Cannot inspect individual objects but can see the list | `list, watch` |
| Can modify but not create or delete | `get, list, watch, update, patch` |

### Debugging commands

```bash
# Can the current user do this?
kubectl auth can-i VERB RESOURCE -n NS

# Can a specific user do this? (requires impersonation rights)
kubectl auth can-i VERB RESOURCE -n NS --as=USER

# Dump everything a user can do
kubectl auth can-i --list -n NS --as=USER

# Inspect a Role or RoleBinding
kubectl get role ROLE_NAME -n NS -o yaml
kubectl describe rolebinding BINDING_NAME -n NS
```

The `--as=USER` flag is gold during the exam. It lets you test another user's permissions from your admin context without switching kubeconfigs.
