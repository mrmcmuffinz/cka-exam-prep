# Admission Controllers and ValidatingAdmissionPolicy Tutorial

The API server handles every incoming request through four phases: authentication (confirming who the caller is), authorization (deciding whether the action is permitted for that caller), admission (optionally mutating the object and then validating it), and persistence (writing the final object to etcd). This tutorial focuses on the third phase. It shows the built-in admission controllers kubeadm enables by default, how to read and modify the enabled set through the API server's static pod manifest, a mutating and a validating built-in in action, and finally how to write a `ValidatingAdmissionPolicy` with CEL (the webhook-free extension mechanism that stabilized in Kubernetes 1.30).

The tutorial uses a namespace called `tutorial-admission` for most exercises and shows every CEL expression in a size that fits on one screen.

## Prerequisites

A single-node kind cluster running Kubernetes 1.35 per `docs/cluster-setup.md#single-node-kind-cluster`. Verify:

```bash
kubectl config current-context       # expect: kind-kind
kubectl version --short              # expect: Client and Server Version v1.35.x
kubectl api-resources | grep -i validatingadmissionpolicy
```

Expected from the last command: two rows, `validatingadmissionpolicies` (policies) and `validatingadmissionpolicybindings` (bindings), both in the `admissionregistration.k8s.io/v1` API group.

Create the tutorial namespace:

```bash
kubectl create namespace tutorial-admission
```

## Step 1: The Request Flow

Every write request to the API server flows through four phases in a strict order:

1. **Authentication**. The request carries credentials (a client certificate, a bearer token, or an OIDC ID token). The API server identifies the caller as a user, a group, or a ServiceAccount. A failed authentication returns `401 Unauthorized`.

2. **Authorization**. The API server consults the configured authorization modules (typically Node and RBAC) to decide whether the identified caller is allowed to perform the requested verb on the requested resource. A denial returns `403 Forbidden`.

3. **Admission**. The admission plugins run in two sub-phases. Mutating admission controllers run first; they can modify the object. Validating admission controllers run second; they can only accept or reject. A rejection returns an error (usually `403 Forbidden` or `400 Bad Request` with a specific message). The list of active admission controllers is configured at API server startup.

4. **Persistence**. If all prior phases pass, the final mutated-and-validated object is written to etcd and the API server returns `201 Created` or `200 OK`.

Admission is the only phase in which the cluster operator can plug in custom logic without modifying the API server itself (beyond RBAC rules, which live in the authorization phase). Everything this tutorial covers is about that plugin surface.

Read the admission plugins active on the API server:

```bash
nerdctl exec kind-control-plane \
  grep -E 'enable-admission-plugins|disable-admission-plugins' \
    /etc/kubernetes/manifests/kube-apiserver.yaml
```

Expected: a line `--enable-admission-plugins=NodeRestriction` (the single plugin kubeadm explicitly enables on top of the default set). The default-enabled plugins in 1.35 include `CertificateApproval`, `CertificateSigning`, `CertificateSubjectRestriction`, `DefaultIngressClass`, `DefaultStorageClass`, `DefaultTolerationSeconds`, `LimitRanger`, `MutatingAdmissionWebhook`, `NamespaceLifecycle`, `PersistentVolumeClaimResize`, `PodSecurity`, `Priority`, `ResourceQuota`, `RuntimeClass`, `ServiceAccount`, `StorageObjectInUseProtection`, `TaintNodesByCondition`, `ValidatingAdmissionPolicy`, and `ValidatingAdmissionWebhook`. That default set is established by the API server binary itself; kubeadm adds `NodeRestriction` because it is not default-enabled upstream.

View the full list the API server recognizes (either enabled or disable-able):

```bash
nerdctl exec kind-control-plane \
  kube-apiserver -h 2>&1 \
  | grep -A20 'enable-admission-plugins' \
  | head -30
```

Expected: the help text listing every admission plugin name the API server knows about, with a note of which are default-enabled.

## Step 2: A Mutating Admission Controller in Action

The `DefaultStorageClass` admission controller adds a `storageClassName` to any `PersistentVolumeClaim` that does not specify one, using the cluster's default StorageClass. This is a mutation: the object the user applied is modified before it reaches etcd.

Create a PVC with no `storageClassName`:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: demo-pvc
  namespace: tutorial-admission
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 128Mi
EOF
```

Check what actually got persisted:

```bash
kubectl get pvc demo-pvc -n tutorial-admission \
  -o jsonpath='{.spec.storageClassName}{"\n"}'
```

Expected output: `standard` (the kind default StorageClass). The YAML you applied did not include that field; the `DefaultStorageClass` admission controller set it during the mutating phase.

The `ServiceAccount` admission controller performs a similar mutation for pods: if a pod specification omits `spec.serviceAccountName`, the controller sets it to `default`. Observe:

```bash
kubectl run mut-demo -n tutorial-admission \
  --image=nginx:1.27 --restart=Never
kubectl get pod mut-demo -n tutorial-admission \
  -o jsonpath='{.spec.serviceAccountName}{"\n"}'
```

Expected: `default`. The pod spec did not set a service account; admission added one.

Clean up the demo objects:

```bash
kubectl delete pvc demo-pvc -n tutorial-admission
kubectl delete pod mut-demo -n tutorial-admission
```

## Step 3: A Validating Admission Controller in Action

The `ResourceQuota` admission controller rejects requests that would exceed a namespace quota. Create a tight quota and observe the rejection:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: cpu-quota
  namespace: tutorial-admission
spec:
  hard:
    requests.cpu: "100m"
EOF
```

Try to create a pod that requests more CPU than the quota allows:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: quota-violator
  namespace: tutorial-admission
spec:
  containers:
    - name: app
      image: nginx:1.27
      resources:
        requests:
          cpu: 500m
EOF
```

Expected output: `Error from server (Forbidden): pods "quota-violator" is forbidden: exceeded quota: cpu-quota, requested: requests.cpu=500m, used: requests.cpu=0, limited: requests.cpu=100m`. The error message names the admission controller (`exceeded quota`) and the specific object (`cpu-quota`) that rejected the request.

No pod was created; nothing was persisted to etcd. This is the core contract of a validating admission controller: reject or accept, never modify.

Clean up:

```bash
kubectl delete resourcequota cpu-quota -n tutorial-admission
```

## Step 4: Modifying the Enabled Plugin Set

Admission controllers are enabled through the API server's command-line flags. In a kubeadm cluster, those flags live in the static pod manifest at `/etc/kubernetes/manifests/kube-apiserver.yaml`. Editing the manifest triggers kubelet to reconcile the change and restart the API server within seconds.

The patterns are:

`--enable-admission-plugins=X,Y,Z`: enables the listed plugins in addition to the default-enabled set.

`--disable-admission-plugins=A,B`: disables the listed plugins, even if they are default-enabled.

Read the current values:

```bash
nerdctl exec kind-control-plane \
  grep -E 'enable-admission-plugins|disable-admission-plugins' \
    /etc/kubernetes/manifests/kube-apiserver.yaml
```

To demonstrate temporarily disabling a plugin, disable `DefaultStorageClass` and observe that new PVCs no longer get a default class. The exercise is destructive at cluster scope; do not do it on a cluster you care about, and revert at the end of this tutorial.

Do not run the following edit step unless you are prepared to revert. Skip to Step 5 if you prefer reading over acting.

```bash
nerdctl exec kind-control-plane bash -c '
  cp /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/apiserver.yaml.bak
  sed -i "s|--enable-admission-plugins=NodeRestriction|--enable-admission-plugins=NodeRestriction\n    - --disable-admission-plugins=DefaultStorageClass|" \
    /etc/kubernetes/manifests/kube-apiserver.yaml
'
# Wait for the API server to restart:
sleep 15
kubectl get nodes
```

Now apply a PVC without a storage class and observe that the field stays unset:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: no-class
  namespace: tutorial-admission
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 128Mi
EOF

kubectl get pvc no-class -n tutorial-admission \
  -o jsonpath='{.spec.storageClassName}{"\n"}'
```

Expected output: empty string (the PVC has no StorageClass). Without `DefaultStorageClass` admission the PVC stays in `Pending` forever because no provisioner claims it.

Revert the change:

```bash
nerdctl exec kind-control-plane \
  cp /tmp/apiserver.yaml.bak /etc/kubernetes/manifests/kube-apiserver.yaml
sleep 15
kubectl get nodes
kubectl delete pvc no-class -n tutorial-admission
```

The spec-field documentation above illustrates the only meaningful pattern for plugin configuration: choose which of the recognized plugin names to enable or disable, put the resulting string in the API server flag, and let kubelet reconcile the restart. The plugin implementations themselves are compiled into the API server and not configurable beyond the on/off toggle and their per-plugin resource configuration (such as `ResourceQuota` consuming `ResourceQuota` objects in namespaces).

## Step 5: Your First ValidatingAdmissionPolicy

`ValidatingAdmissionPolicy` (stable since Kubernetes 1.30) is the webhook-free way to add custom validation without writing an external server. The policy defines CEL expressions that must evaluate to true for a request to be admitted; the binding connects the policy to the resources it should apply to and sets the enforcement action.

Build a policy that requires every pod in a specific namespace to have container images starting with `registry.example.com/`. First the policy:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: image-registry-policy
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "object.spec.containers.all(c, c.image.startsWith('registry.example.com/'))"
      message: "All container images must come from registry.example.com/"
      reason: Invalid
```

Apply it:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: image-registry-policy
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "object.spec.containers.all(c, c.image.startsWith('registry.example.com/'))"
      message: "All container images must come from registry.example.com/"
      reason: Invalid
EOF
```

A policy without a binding has no effect. The binding is the second half:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: image-registry-binding
spec:
  policyName: image-registry-policy
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: tutorial-admission
EOF
```

The `namespaceSelector` uses the well-known `kubernetes.io/metadata.name` label (which Kubernetes automatically adds to every namespace with the namespace's own name) to scope the binding to exactly the `tutorial-admission` namespace.

Test the policy. Try to create a pod with an nginx image (which does not match the `registry.example.com/` prefix):

```bash
kubectl run rejected -n tutorial-admission \
  --image=nginx:1.27 --restart=Never
```

Expected output: `Error from server: ValidatingAdmissionPolicy 'image-registry-policy' with binding 'image-registry-binding' denied request: All container images must come from registry.example.com/`. The error names both the policy and the binding that produced the denial.

A pod with a matching image would be accepted (kind does not have such an image locally, so this is a thought experiment; in a real cluster you would push an image to `registry.example.com/nginx:1.27` first).

Remove the binding and try again:

```bash
kubectl delete validatingadmissionpolicybinding image-registry-binding

kubectl run accepted -n tutorial-admission \
  --image=nginx:1.27 --restart=Never

kubectl delete pod accepted -n tutorial-admission
```

Expected: the pod is created successfully. The policy still exists, but with no binding it has no effect.

ValidatingAdmissionPolicy spec fields relevant to this tutorial:

`spec.failurePolicy`. `Fail` (the default for `ValidatingAdmissionPolicy`) rejects the request if a CEL expression errors at evaluation time (for example, if `object.spec.replicas` is nil for a resource that does not have replicas). `Ignore` treats the error as a pass. Pick `Fail` for policies that enforce security properties; pick `Ignore` for policies where a best-effort check is acceptable.

`spec.matchConstraints.resourceRules`. A list of rules, each with `apiGroups`, `apiVersions`, `operations`, and `resources`. The policy applies when the incoming request matches at least one rule. Operations include `CREATE`, `UPDATE`, `DELETE`, `CONNECT`, and `*`. The resource list uses plural lowercase names (the same names kubectl and RBAC use), and the empty API group `""` refers to the core group (pods, services, configmaps, secrets, and so on).

`spec.validations`. A list of CEL expression/message/reason triples. Every expression must evaluate to true for the request to be admitted; the first false result produces the error. `expression` is a CEL expression, `message` is the static error text, `messageExpression` is an alternative that computes a dynamic error from CEL (useful for including object names or values in the error), and `reason` is a structured reason like `Invalid`, `Forbidden`, or `Unauthorized` that appears in the API error response.

ValidatingAdmissionPolicyBinding spec fields:

`spec.policyName`. The name of the `ValidatingAdmissionPolicy` to bind. A binding that references a nonexistent policy applies silently (the binding object exists; the policy never fires) and does not fail at apply time.

`spec.validationActions`. A subset of `Deny`, `Warn`, `Audit`. `Deny` rejects the request if any validation fails; `Warn` returns the request as a success with a warning that kubectl prints; `Audit` records an annotation on the resulting admission audit entry but is otherwise silent. Multiple actions can be combined (for example, `[Deny, Audit]` denies the request and also records the denial to audit logs).

`spec.matchResources`. Optional additional scoping beyond the policy's own `matchConstraints`. Commonly used subfields are `namespaceSelector` (labels on the namespace) and `objectSelector` (labels on the object itself).

`spec.paramRef`. Optional reference to a parameter resource (defined by the policy's `paramKind`). Allows the same policy to be bound with different parameters for different namespaces.

## Step 6: Multi-Validation Policy

A single policy can have multiple validations. Every one must pass for the request to be admitted. Update the image-registry policy to also require a `team` label on every pod:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: image-registry-policy
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "object.spec.containers.all(c, c.image.startsWith('registry.example.com/'))"
      message: "All container images must come from registry.example.com/"
      reason: Invalid
    - expression: "has(object.metadata.labels) && 'team' in object.metadata.labels"
      message: "Every pod must have a team label"
      reason: Invalid
EOF
```

Re-create the binding:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: image-registry-binding
spec:
  policyName: image-registry-policy
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: tutorial-admission
EOF
```

Test each failure mode in turn:

```bash
# No team label, and nginx image (two violations; the first one fails):
kubectl run check-1 -n tutorial-admission --image=nginx:1.27 --restart=Never
# Expected: denied with "All container images must come from registry.example.com/".

# team label present, still the wrong image:
kubectl run check-2 -n tutorial-admission --image=nginx:1.27 --restart=Never \
  --labels=team=alpha
# Expected: denied with "All container images must come from registry.example.com/".

# Correct image shape (fictional), team label missing:
kubectl run check-3 -n tutorial-admission --image=registry.example.com/nginx:1.27 --restart=Never
# Expected: denied with "Every pod must have a team label".
```

The ordering of validations is the ordering in the spec; the first failure produces the error. CEL's `has()` function is the safe way to check for label existence; reading `object.metadata.labels['team']` directly when labels is empty would raise a runtime error, which under `failurePolicy: Fail` becomes a denial without a clear message.

## Step 7: Warn and Audit Enforcement Actions

`validationActions` can include `Warn` and `Audit` alongside or instead of `Deny`. `Warn` is the most user-visible: the request succeeds, but the client sees a warning in its output. `Audit` is silent to the client but annotates the admission audit entry, which shows up in the API server's audit log when one is configured.

Update the binding to use `Warn` only:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: image-registry-binding
spec:
  policyName: image-registry-policy
  validationActions: ["Warn"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: tutorial-admission
EOF
```

Repeat the earlier test:

```bash
kubectl run warned -n tutorial-admission --image=nginx:1.27 --restart=Never
```

Expected output: `Warning: Validation failed: All container images must come from registry.example.com/` followed by `Warning: Validation failed: Every pod must have a team label`, and then `pod/warned created`. The pod exists; kubectl printed warnings because the binding's action is `Warn` rather than `Deny`. This is useful for rolling out a new policy: observe the warnings for a few days, confirm that no production workloads are hitting them, then switch to `Deny`.

Audit works the same way but the output is recorded to the API server's audit log. On a kind cluster without an audit-policy configuration there is nothing observable to the learner, but the mechanism is the same; production clusters with a central log pipeline use `Audit` for compliance reporting.

Clean up the warned pod:

```bash
kubectl delete pod warned -n tutorial-admission
```

## Step 8: Policies with Parameters

Some policies want to be reusable across environments with different thresholds. `paramKind` on the policy names the parameter resource; `paramRef` on the binding supplies the actual parameters. The parameter is an arbitrary Kubernetes resource (often a ConfigMap or a CRD); the CEL expression reads it through `params`.

Build a policy that enforces a replica cap on Deployments where the cap comes from a `ConfigMap` named by the binding:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: replica-cap-policy
spec:
  failurePolicy: Fail
  paramKind:
    apiVersion: v1
    kind: ConfigMap
  matchConstraints:
    resourceRules:
      - apiGroups: ["apps"]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["deployments"]
  validations:
    - expression: "object.spec.replicas <= int(params.data.maxReplicas)"
      messageExpression: "'Deployment replicas (' + string(object.spec.replicas) + ') exceed the cap (' + params.data.maxReplicas + ')'"
      reason: Invalid
EOF
```

Create the parameter ConfigMap:

```bash
kubectl create configmap replica-cap-params \
  --from-literal=maxReplicas=3 \
  -n tutorial-admission
```

Create the binding that references both the policy and the parameter:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: replica-cap-binding
spec:
  policyName: replica-cap-policy
  validationActions: ["Deny"]
  paramRef:
    name: replica-cap-params
    namespace: tutorial-admission
    parameterNotFoundAction: Deny
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: tutorial-admission
EOF
```

Test the policy:

```bash
kubectl create deployment small -n tutorial-admission --image=nginx:1.27 --replicas=2
# Expected: deployment/small created (replicas=2 is <= 3).

kubectl create deployment big -n tutorial-admission --image=nginx:1.27 --replicas=10
# Expected: error citing "Deployment replicas (10) exceed the cap (3)".
```

Change the ConfigMap's threshold and retest:

```bash
kubectl patch configmap replica-cap-params -n tutorial-admission \
  --type=merge --patch '{"data":{"maxReplicas":"15"}}'

kubectl create deployment big -n tutorial-admission --image=nginx:1.27 --replicas=10
# Expected: deployment/big created (10 <= 15 now).
kubectl delete deployment big -n tutorial-admission
```

`paramRef.parameterNotFoundAction` controls what happens if the parameter resource does not exist. `Deny` rejects the request (safer); `Allow` accepts it.

`messageExpression` on the validation produced the dynamic error with the actual replica count and cap. This is more useful than a static `message` when an operator needs to see the specific values that caused the denial.

## Step 9: Diagnosing Admission Errors

When a request is denied, the error message identifies the responsible admission controller or policy by name. The diagnostic workflow is: read the error, search for the named plugin or policy, confirm the expected configuration exists, adjust as needed.

Common signatures:

- `pods "X" is forbidden: exceeded quota: Y, requested: ..., used: ..., limited: ...` → the `ResourceQuota` built-in admission controller. The quota name is `Y`.
- `pods "X" is forbidden: violates PodSecurity "restricted:latest": ...` → the `PodSecurity` built-in admission controller. The Pod Security Standard the namespace enforces is named.
- `admission webhook "W" denied the request: ...` → a dynamic admission webhook named `W`. Inspect `kubectl get validatingwebhookconfigurations` or `kubectl get mutatingwebhookconfigurations` to find its configuration.
- `ValidatingAdmissionPolicy 'P' with binding 'B' denied request: ...` → a `ValidatingAdmissionPolicy` named `P` with a binding named `B`.

List admission policies and bindings:

```bash
kubectl get validatingadmissionpolicies
kubectl get validatingadmissionpolicybindings
```

Inspect a specific one:

```bash
kubectl describe validatingadmissionpolicy image-registry-policy
kubectl describe validatingadmissionpolicybinding image-registry-binding
```

If a policy is in place but not firing, check three things in order: the binding exists and references the policy by correct name; the binding's `matchResources` actually matches the namespace or object in question; the policy's `matchConstraints` actually matches the resource type and operation.

## Step 10: Clean Up

Delete the policies and bindings (they are cluster-scoped; namespace delete does not remove them):

```bash
kubectl delete validatingadmissionpolicybinding image-registry-binding replica-cap-binding --ignore-not-found
kubectl delete validatingadmissionpolicy image-registry-policy replica-cap-policy --ignore-not-found
kubectl delete namespace tutorial-admission
```

## Reference Commands

### Inspect the enabled admission plugins

```bash
nerdctl exec kind-control-plane \
  grep -E 'enable-admission-plugins|disable-admission-plugins' \
    /etc/kubernetes/manifests/kube-apiserver.yaml

nerdctl exec kind-control-plane \
  kube-apiserver -h 2>&1 | grep -A20 'enable-admission-plugins' | head -30
```

### Create ValidatingAdmissionPolicy objects

```bash
# List existing policies and bindings
kubectl get validatingadmissionpolicies
kubectl get validatingadmissionpolicybindings

# Inspect a specific one
kubectl describe validatingadmissionpolicy NAME
kubectl describe validatingadmissionpolicybinding NAME

# Delete cluster-scoped ones explicitly (namespace delete does not cascade)
kubectl delete validatingadmissionpolicy NAME
kubectl delete validatingadmissionpolicybinding NAME
```

### Policy spec template

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: POLICY_NAME
spec:
  failurePolicy: Fail
  paramKind:                          # optional
    apiVersion: v1
    kind: ConfigMap
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "CEL_EXPRESSION"
      message: "error message"
      messageExpression: "dynamic CEL message"   # alternative to message
      reason: Invalid
```

### Binding spec template

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: BINDING_NAME
spec:
  policyName: POLICY_NAME
  validationActions: ["Deny"]         # or ["Warn"], ["Audit"], or a subset
  paramRef:                           # required only if the policy has paramKind
    name: PARAM_RESOURCE_NAME
    namespace: PARAM_RESOURCE_NAMESPACE
    parameterNotFoundAction: Deny
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: TARGET_NAMESPACE
```

### Common CEL patterns

```
# All container images start with a prefix:
object.spec.containers.all(c, c.image.startsWith('registry.example.com/'))

# Replica count cap (Deployment or StatefulSet):
object.spec.replicas <= int(params.data.maxReplicas)

# Required label present:
has(object.metadata.labels) && 'team' in object.metadata.labels

# Label value matches a regex:
object.metadata.labels['env'].matches('^(dev|staging|prod)$')

# On UPDATE only: a specific field cannot change:
request.operation == 'UPDATE' ? object.spec.serviceAccountName == oldObject.spec.serviceAccountName : true
```

### Diagnostic signatures

| Error starts with | Source |
|---|---|
| `pods "X" is forbidden: exceeded quota: Y` | `ResourceQuota` admission controller |
| `pods "X" is forbidden: violates PodSecurity` | `PodSecurity` admission controller |
| `admission webhook "W" denied the request` | Dynamic admission webhook `W` |
| `ValidatingAdmissionPolicy 'P' with binding 'B' denied request` | `ValidatingAdmissionPolicy` named `P` |
| `X "Y" is forbidden: unable to validate against any ...` | `PodSecurity` failure on missing labels |
