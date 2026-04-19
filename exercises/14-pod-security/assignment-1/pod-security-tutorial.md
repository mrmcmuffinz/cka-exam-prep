# Pod Security Tutorial

This tutorial walks through Pod Security Standards (PSS) and Pod Security Admission (PSA) from label application to policy violation. It starts with an unlabeled namespace (implicit Privileged), adds Baseline enforcement, watches a non-compliant pod get rejected, and progresses to Restricted with a correctly-hardened `securityContext`. Along the way, every label and field is introduced with its valid values and the observable behavior when it is misconfigured.

All tutorial resources go into a dedicated namespace called `tutorial-pod-security` so nothing collides with the homework exercises.

## Prerequisites

Verify the cluster.

```bash
kubectl get nodes
```

Verify PSA is enabled. It is a built-in kube-apiserver admission plugin, enabled by default since Kubernetes 1.25. Check by reading the API server's arguments.

```bash
nerdctl exec kind-control-plane cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -E "admission|PodSecurity" | head
```

You should see either no explicit reference to PodSecurity (meaning it is in the default-enabled set) or an `--enable-admission-plugins` flag containing `PodSecurity`. Either is fine.

Create the tutorial namespace and set it as the default for this shell.

```bash
kubectl create namespace tutorial-pod-security
kubectl config set-context --current --namespace=tutorial-pod-security
```

## Part 1: Implicit Privileged, Explicit Labels

A namespace without any `pod-security.kubernetes.io/` labels defaults to the Privileged profile across all three enforcement modes. Privileged is the permissive policy; any valid pod is accepted.

Prove this by applying a pod that would fail Restricted but passes Privileged.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: privileged-allowed
spec:
  containers:
  - name: app
    image: nginx:1.25
    securityContext:
      privileged: true
EOF

kubectl get pod privileged-allowed
```

The pod is accepted (STATUS Running or Pending briefly). `privileged: true` would never pass Baseline or Restricted, but Privileged does not restrict it.

Delete it.

```bash
kubectl delete pod privileged-allowed
```

## Part 2: The Three Profiles at a Glance

PSS defines three profiles, each a superset of the restrictions of the previous one:

- **Privileged**: no restrictions. The implicit default when no labels are present. Use in infrastructure namespaces (kube-system and similar) that need broad capabilities.
- **Baseline**: blocks known privilege escalations. No `privileged: true`, no host namespaces (`hostNetwork`, `hostPID`, `hostIPC`), no `hostPath` volumes, no dangerous capabilities in `capabilities.add`, and `seccompProfile.type` must be `RuntimeDefault` or `Localhost` if set. Does NOT require `runAsNonRoot`. Use for shared developer namespaces.
- **Restricted**: all Baseline restrictions plus hardening. Pods must set `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, drop ALL capabilities, and set `seccompProfile.type` to `RuntimeDefault` or `Localhost`. Volume types are limited to `configMap`, `csi`, `downwardAPI`, `emptyDir`, and `ephemeral`. Use for multi-tenant or production namespaces.

The authoritative definitions for every field in every profile live at https://kubernetes.io/docs/concepts/security/pod-security-standards/. The tutorial focuses on the handful of fields learners hit most often.

## Part 3: Three Modes

PSA applies each profile via one or more modes, each set as a separate label:

- **enforce**: violations cause the pod to be rejected at admission time. The pod never reaches the scheduler. The `kubectl apply` or equivalent returns an error message.
- **audit**: violations are logged in the cluster's audit log but the pod is allowed to run. Useful for observing violations without breaking workloads.
- **warn**: violations produce a user-facing warning in the `kubectl apply` output but the pod is allowed. Useful for staging a future tightening.

A namespace can combine all three. A common pattern for a migration is "enforce: baseline, warn: restricted" meaning "Baseline violations fail hard, Restricted violations show as warnings but do not block anything." That lets you discover which workloads would break under Restricted before switching to enforce: restricted.

## Part 4: Label a Namespace for Baseline Enforcement

Apply the Baseline enforce label.

```bash
kubectl label namespace tutorial-pod-security pod-security.kubernetes.io/enforce=baseline
```

Try applying the privileged pod again.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: privileged-blocked
spec:
  containers:
  - name: app
    image: nginx:1.25
    securityContext:
      privileged: true
EOF
```

You will see an error of the form:

```
Error from server (Forbidden): error when creating "STDIN":
pods "privileged-blocked" is forbidden: violates PodSecurity "baseline:latest":
privileged (container "app" must not set securityContext.privileged=true)
```

The rejection message names the profile and version (`baseline:latest`), names the violated control (`privileged`), names which container violated it (`container "app"`), and describes the fix (`must not set securityContext.privileged=true`). Reading this format is half the diagnostic skill for PSA.

## Part 5: A Baseline-Compliant Pod

Apply a pod that satisfies Baseline (no privileged, no host namespaces, no hostPath, no forbidden capabilities).

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: baseline-ok
spec:
  containers:
  - name: app
    image: nginx:1.25
    ports:
    - containerPort: 80
EOF

kubectl get pod baseline-ok
```

Notice Baseline did NOT require `runAsNonRoot: true`; nginx running as root is fine at Baseline. Baseline's rule set is the blocks list, not the hardening list.

Clean up.

```bash
kubectl delete pod baseline-ok
```

## Part 6: Tighten to Restricted

Change the namespace label to enforce Restricted and retry the same pod.

```bash
kubectl label namespace tutorial-pod-security pod-security.kubernetes.io/enforce=restricted --overwrite

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: restricted-fail
spec:
  containers:
  - name: app
    image: nginx:1.25
EOF
```

You will see a rejection listing multiple violations:

```
Error from server (Forbidden): error when creating "STDIN":
pods "restricted-fail" is forbidden: violates PodSecurity "restricted:latest":
allowPrivilegeEscalation != false (container "app" must set
securityContext.allowPrivilegeEscalation=false),
unrestricted capabilities (container "app" must set
securityContext.capabilities.drop=["ALL"]),
runAsNonRoot != true (pod or container "app" must set
securityContext.runAsNonRoot=true), seccompProfile (pod or container "app"
must set securityContext.seccompProfile.type to "RuntimeDefault" or
"Localhost")
```

Four violations in one rejection. Each must be fixed to get the pod accepted.

## Part 7: A Restricted-Compliant Pod

Build a pod that satisfies Restricted. Note nginx's base image runs as root by default, so we switch to `nginxinc/nginx-unprivileged:1.25` which runs as UID 101. For this tutorial, any non-root image or an explicit `runAsUser` works.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: restricted-ok
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginxinc/nginx-unprivileged:1.25
    ports:
    - containerPort: 8080
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF

kubectl get pod restricted-ok
```

The pod is accepted and runs. Every Restricted requirement is satisfied: `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]`, `seccompProfile.type: RuntimeDefault`.

Pod-level and container-level `securityContext` compose: the pod-level settings are defaults, and container-level settings override them. In the example above, `runAsNonRoot` and `seccompProfile` are set at the pod level (inherited by every container), and container-specific settings are set at the container level.

Clean up.

```bash
kubectl delete pod restricted-ok
```

## Part 8: Warn Mode as a Staging Tool

Drop enforce back to Baseline and add a warn at Restricted.

```bash
kubectl label namespace tutorial-pod-security pod-security.kubernetes.io/enforce=baseline --overwrite
kubectl label namespace tutorial-pod-security pod-security.kubernetes.io/warn=restricted --overwrite
```

Re-apply the Baseline-compliant nginx pod.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: warn-demo
spec:
  containers:
  - name: app
    image: nginx:1.25
EOF
```

The pod is accepted (Baseline passes), but `kubectl` emits a `Warning:` line for each Restricted violation:

```
Warning: would violate PodSecurity "restricted:latest": allowPrivilegeEscalation != false ...
pod/warn-demo created
```

Warnings do not block anything but they surface everything you would have to change to tighten to Restricted. This is the normal migration pattern: enforce the current baseline, warn at the next level, migrate workloads one at a time until the warnings stop, then flip enforce to that level.

Clean up.

```bash
kubectl delete pod warn-demo
```

## Part 9: Audit Mode

Audit mode is like warn mode except the violation record lands in the cluster's audit log instead of the user's kubectl output. Audit logging is not enabled on kind by default (it requires an API server config) and inspecting the audit trail is out of scope here. Conceptually, use audit mode when you want monitoring/alerting tooling to consume violations rather than users to see them.

```bash
kubectl label namespace tutorial-pod-security pod-security.kubernetes.io/audit=restricted --overwrite
```

The label applies successfully; new violating pods produce audit events (invisible in this tutorial but visible in a production cluster with audit logging configured).

## Part 10: Version Pinning

Every mode label accepts a companion `-version` label that pins the policy to a specific Kubernetes release. The value is a version string like `v1.30` or `v1.35`, or the literal `latest`.

Without a version label, PSA uses the policy definitions from the current cluster's Kubernetes version (equivalent to `latest`). PSS definitions can tighten across releases (new fields get added to the blocks list, existing fields get narrowed), so `latest` means "I accept silent tightening on cluster upgrade."

Pin to a specific version when you need stable behavior across cluster upgrades.

```bash
kubectl label namespace tutorial-pod-security \
  pod-security.kubernetes.io/enforce-version=v1.30 \
  --overwrite
```

Now enforce uses the v1.30 Baseline definition, even if the cluster is at 1.35. This is useful in regulated environments where policy change control has to lag behind cluster upgrades.

To return to tracking the cluster version, set the version label to `latest` or remove it.

```bash
kubectl label namespace tutorial-pod-security pod-security.kubernetes.io/enforce-version-
# the trailing dash removes the label
```

## Part 11: PSA Enforces on Pods, Not Workload Resources

One gotcha catches almost every learner at least once. PSA's `enforce` mode only validates against Pod objects, not against the workload resources (Deployment, StatefulSet, Job, ReplicaSet, DaemonSet) that create pods. That means you can `kubectl apply` a Deployment whose pod template violates enforcement and get a success message, only to discover that the Deployment's pods are never created and show a rejection in the Deployment controller's events.

Prove it. Tighten enforce to Restricted.

```bash
kubectl label namespace tutorial-pod-security pod-security.kubernetes.io/enforce=restricted --overwrite

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: will-not-create-pods
spec:
  replicas: 2
  selector:
    matchLabels:
      app: will-not
  template:
    metadata:
      labels:
        app: will-not
    spec:
      containers:
      - name: app
        image: nginx:1.25
EOF
```

The Deployment is accepted. But:

```bash
kubectl get deployment will-not-create-pods
# READY 0/2

kubectl describe replicaset -l app=will-not
# Events: FailedCreate reason: violates PodSecurity "restricted:latest" ...
```

The Deployment's ReplicaSet tries to create pods, each attempt is rejected by PSA, and the `FailedCreate` event accumulates in the ReplicaSet. The Deployment's READY count stays at 0.

Audit and warn modes compensate for this by evaluating workload resources too (not just pods), which is why they are useful for previewing enforce: their visibility extends to the Deployment itself.

Clean up.

```bash
kubectl delete deployment will-not-create-pods
```

## Part 12: Exemptions (Conceptual)

The API server's admission configuration file can exempt specific usernames, runtime classes, or namespaces from PSA enforcement. Exemptions are a cluster-level setting rather than a namespace label, so they require editing the API server configuration, which is cumbersome in kind. The relevant fact for the exam is that exemptions exist and are configured in the `AdmissionConfiguration` resource under `plugins[].name: PodSecurity`.

A typical use case: the controller manager's service account creates DaemonSet pods for kube-system workloads that require privileged access. Exempting either the kube-system namespace or the controller-manager service account lets those workloads bypass PSA.

## Part 13: Cleanup

Delete the tutorial namespace to remove everything you created.

```bash
kubectl config set-context --current --namespace=default
kubectl delete namespace tutorial-pod-security
```

## Reference Commands

### Apply PSA labels to a namespace

```bash
# enforce mode (hard rejection)
kubectl label namespace NS pod-security.kubernetes.io/enforce=<level>

# audit mode (log only)
kubectl label namespace NS pod-security.kubernetes.io/audit=<level>

# warn mode (user warning)
kubectl label namespace NS pod-security.kubernetes.io/warn=<level>

# pin a mode to a specific version
kubectl label namespace NS pod-security.kubernetes.io/enforce-version=v1.35

# remove a label (trailing dash)
kubectl label namespace NS pod-security.kubernetes.io/enforce-

# change (requires --overwrite)
kubectl label namespace NS pod-security.kubernetes.io/enforce=restricted --overwrite
```

### PSS profile quick reference

| Profile | Controls Applied |
|---|---|
| **Privileged** | No restrictions (default when no labels are set) |
| **Baseline** | Blocks: `privileged: true`, host namespaces, `hostPath` volumes, dangerous capabilities in `capabilities.add`, `hostPort`, unsafe sysctls. Requires `seccompProfile.type` to be `RuntimeDefault` or `Localhost` if set. Does NOT require `runAsNonRoot`. |
| **Restricted** | Baseline plus: `runAsNonRoot: true` required, `allowPrivilegeEscalation: false` required, `capabilities.drop: ["ALL"]` required, `seccompProfile.type` must be set to `RuntimeDefault` or `Localhost`. Only these volume types: `configMap`, `csi`, `downwardAPI`, `emptyDir`, `ephemeral`. |

### Restricted-compliant pod spec template

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: <uid>            # optional but recommended
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: NAME
    image: IMAGE
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
```

### Inspection

```bash
# namespace labels
kubectl get namespace NS --show-labels

# specific PSA label
kubectl get namespace NS -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'; echo

# the rejection message from a failing pod
kubectl apply -f pod.yaml
# Error message is self-describing; read the profile, control, and fix instruction

# ReplicaSet events when a Deployment's pods are being rejected
kubectl describe rs -l <selector>
```

## Where to Go Next

Work through `pod-security-homework.md` starting at Level 1. The reference table above is the fastest way to look up what Baseline or Restricted requires while you work.
