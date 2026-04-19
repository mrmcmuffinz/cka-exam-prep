# Admission Controllers Homework: 15 Progressive Exercises

These exercises build on the concepts covered in `admission-controllers-tutorial.md`. The focus is on `ValidatingAdmissionPolicy` with CEL; built-in admission controllers appear only as diagnostic contexts because they are compiled into the API server and cannot be written from YAML.

All exercises assume a single-node kind cluster running Kubernetes 1.35:

```bash
kubectl config current-context    # expect: kind-kind
kubectl version --short           # expect: Server Version v1.35.x
kubectl api-resources | grep -i validatingadmissionpolicy   # expect: 2 rows
```

Every exercise uses its own namespace for any target resources. Policies and bindings are cluster-scoped; each exercise uses distinct policy and binding names with an `ex-N-M-` prefix so they do not collide.

## Global Setup

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 \
          ex-2-1 ex-2-2 ex-2-3 \
          ex-3-1 ex-3-2 ex-3-3 \
          ex-4-1 ex-4-2 ex-4-3 \
          ex-5-1 ex-5-2 ex-5-3; do
  kubectl create namespace $ns
done
```

---

## Level 1: Basics

### Exercise 1.1

**Objective:** Enforce that every pod in `ex-1-1` has at least one container image that starts with `registry.example.com/`.

**Setup:**

No pre-existing objects; build the policy and binding from scratch.

**Task:**

Create a `ValidatingAdmissionPolicy` named `ex-1-1-image-prefix` with `failurePolicy: Fail`, `matchConstraints` targeting pods on CREATE and UPDATE in the core API group, one validation whose expression is `object.spec.containers.all(c, c.image.startsWith('registry.example.com/'))`, message `"Images must come from registry.example.com/"`, and reason `Invalid`. Create a matching `ValidatingAdmissionPolicyBinding` named `ex-1-1-image-prefix-binding` with `policyName: ex-1-1-image-prefix`, `validationActions: ["Deny"]`, and `matchResources.namespaceSelector` set via the `kubernetes.io/metadata.name` label to `ex-1-1`.

**Verification:**

```bash
# A non-conforming pod is rejected:
kubectl run probe-fail -n ex-1-1 --image=nginx:1.27 --restart=Never 2>&1 | head -3
# Expected: a line containing "ValidatingAdmissionPolicy 'ex-1-1-image-prefix' with binding 'ex-1-1-image-prefix-binding' denied request"

# Other namespaces are not affected:
kubectl run probe-allowed -n default --image=nginx:1.27 --restart=Never
# Expected: pod/probe-allowed created
kubectl delete pod probe-allowed -n default

# Policy and binding exist:
kubectl get validatingadmissionpolicy ex-1-1-image-prefix \
  -o jsonpath='{.metadata.name}{"\n"}'
# Expected: ex-1-1-image-prefix

kubectl get validatingadmissionpolicybinding ex-1-1-image-prefix-binding \
  -o jsonpath='{.spec.validationActions[0]}{"\n"}'
# Expected: Deny
```

---

### Exercise 1.2

**Objective:** Reject Deployments in `ex-1-2` that request more than 5 replicas.

**Task:**

Create a `ValidatingAdmissionPolicy` named `ex-1-2-replica-cap` targeting `deployments` in the `apps` API group on CREATE and UPDATE. The validation expression must be `object.spec.replicas <= 5` with message `"Replicas must not exceed 5"` and reason `Invalid`. Create a binding `ex-1-2-replica-cap-binding` with action `Deny`, scoped to the `ex-1-2` namespace via label selector.

**Verification:**

```bash
# A small deployment is accepted:
kubectl create deployment small -n ex-1-2 --image=nginx:1.27 --replicas=3
# Expected: deployment.apps/small created
kubectl delete deployment small -n ex-1-2

# A large deployment is rejected:
kubectl create deployment big -n ex-1-2 --image=nginx:1.27 --replicas=10 2>&1 | head -3
# Expected: error referencing ex-1-2-replica-cap

kubectl get validatingadmissionpolicy ex-1-2-replica-cap \
  -o jsonpath='{.spec.matchConstraints.resourceRules[0].apiGroups[0]}:{.spec.matchConstraints.resourceRules[0].resources[0]}{"\n"}'
# Expected: apps:deployments
```

---

### Exercise 1.3

**Objective:** Require every pod in `ex-1-3` to have a `team` label.

**Task:**

Create a `ValidatingAdmissionPolicy` named `ex-1-3-team-label` with a single validation expression `has(object.metadata.labels) && 'team' in object.metadata.labels`, message `"Every pod must have a team label"`, reason `Invalid`. Create a binding `ex-1-3-team-label-binding` with action `Deny`, scoped to namespace `ex-1-3`.

**Verification:**

```bash
# No label: rejected.
kubectl run no-label -n ex-1-3 --image=nginx:1.27 --restart=Never 2>&1 | head -3
# Expected: error citing ex-1-3-team-label

# With label: accepted.
kubectl run with-label -n ex-1-3 --image=nginx:1.27 --restart=Never --labels=team=platform
# Expected: pod/with-label created
kubectl delete pod with-label -n ex-1-3

kubectl get validatingadmissionpolicy ex-1-3-team-label \
  -o jsonpath='{.spec.validations[0].expression}{"\n"}'
# Expected: the CEL expression using has() and 'team' in object.metadata.labels
```

---

## Level 2: Multi-Concept Tasks

### Exercise 2.1

**Objective:** Use the `Warn` enforcement action so pods are accepted but kubectl prints a warning.

**Task:**

Create a policy `ex-2-1-warn-bare-images` whose validation expression is `object.spec.containers.all(c, c.image.contains(':'))` (pods must not use images with an implicit `:latest` tag). Message: `"Container images should have an explicit tag"`. Create a binding `ex-2-1-warn-binding` with `validationActions: ["Warn"]`, scoped to namespace `ex-2-1`.

**Verification:**

```bash
# A bare image (no tag) triggers a warning but is accepted:
kubectl run warned -n ex-2-1 --image=nginx --restart=Never 2>&1 | head -5
# Expected: lines containing "Warning: ... should have an explicit tag" and "pod/warned created"
kubectl delete pod warned -n ex-2-1

# An explicit tag: no warning.
kubectl run tagged -n ex-2-1 --image=nginx:1.27 --restart=Never 2>&1 | head -5
# Expected: no "Warning:" line; "pod/tagged created"
kubectl delete pod tagged -n ex-2-1

kubectl get validatingadmissionpolicybinding ex-2-1-warn-binding \
  -o jsonpath='{.spec.validationActions[0]}{"\n"}'
# Expected: Warn
```

---

### Exercise 2.2

**Objective:** Combine `Deny` and `Audit` in a single binding so that a rejected request is also recorded in the audit log.

**Task:**

Create a policy `ex-2-2-privileged-block` whose validation expression is `!(has(object.spec.containers[0].securityContext) && has(object.spec.containers[0].securityContext.privileged) && object.spec.containers[0].securityContext.privileged == true)`. Message: `"Containers must not be privileged"`. Create a binding `ex-2-2-privileged-binding` with `validationActions: ["Deny", "Audit"]`, scoped to namespace `ex-2-2`.

**Verification:**

```bash
# A privileged pod is rejected:
cat <<'EOF' | kubectl apply -f - 2>&1 | head -3
apiVersion: v1
kind: Pod
metadata:
  name: priv-pod
  namespace: ex-2-2
spec:
  containers:
    - name: bad
      image: nginx:1.27
      securityContext:
        privileged: true
EOF
# Expected: error citing ex-2-2-privileged-block

# A non-privileged pod is accepted:
kubectl run ok -n ex-2-2 --image=nginx:1.27 --restart=Never
# Expected: pod/ok created
kubectl delete pod ok -n ex-2-2

kubectl get validatingadmissionpolicybinding ex-2-2-privileged-binding \
  -o jsonpath='{range .spec.validationActions[*]}{.}{"\n"}{end}'
# Expected two lines:
# Deny
# Audit
```

---

### Exercise 2.3

**Objective:** Write a policy with two validations that must both pass.

**Task:**

Create a policy `ex-2-3-multi` with two validations:

1. Expression `object.spec.containers.all(c, c.image.startsWith('registry.example.com/'))`; message `"Images must come from registry.example.com/"`; reason `Invalid`.
2. Expression `has(object.metadata.labels) && 'env' in object.metadata.labels && object.metadata.labels['env'].matches('^(dev|staging|prod)$')`; message `"env label must be dev, staging, or prod"`; reason `Invalid`.

Bind it with `ex-2-3-multi-binding`, action `Deny`, scoped to namespace `ex-2-3`.

**Verification:**

```bash
# Missing everything: rejected (first failing validation message).
kubectl run no-env -n ex-2-3 --image=nginx:1.27 --restart=Never 2>&1 | head -3
# Expected: denied, mentioning the image-registry validation.

# Right image, wrong env label:
kubectl run wrong-env -n ex-2-3 --image=registry.example.com/nginx:1.27 \
  --restart=Never --labels=env=testing 2>&1 | head -3
# Expected: denied, mentioning the env-label validation.

# Correct image, correct env label:
kubectl run correct -n ex-2-3 --image=registry.example.com/nginx:1.27 \
  --restart=Never --labels=env=prod 2>&1 | head -3
# Expected: a pod/correct rejection is also possible for other reasons
# (e.g., ImagePullBackOff), but the admission layer accepts it. A line
# reading "pod/correct created" confirms admission passed.
kubectl delete pod correct -n ex-2-3 --ignore-not-found

kubectl get validatingadmissionpolicy ex-2-3-multi \
  -o jsonpath='{range .spec.validations[*]}{.expression}{"\n"}{end}' \
  | wc -l
# Expected: 2  (two validation entries).
```

---

## Level 3: Debugging

### Exercise 3.1

**Objective:** Make the `ex-3-1-no-host-network` policy actually reject pods that set `spec.hostNetwork: true`.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: ex-3-1-no-host-network
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: ["apps"]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "!(has(object.spec.hostNetwork) && object.spec.hostNetwork == true)"
      message: "hostNetwork is not allowed"
      reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: ex-3-1-no-host-network-binding
spec:
  policyName: ex-3-1-no-host-network
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ex-3-1
EOF

sleep 5
```

**Task:**

The policy above applied without error, but it does not actually block hostNetwork pods. Diagnose why and fix the single issue.

**Verification:**

```bash
# A hostNetwork pod is rejected after the fix:
cat <<'EOF' | kubectl apply -f - 2>&1 | head -3
apiVersion: v1
kind: Pod
metadata:
  name: hn-fail
  namespace: ex-3-1
spec:
  hostNetwork: true
  containers:
    - name: nginx
      image: nginx:1.27
EOF
# Expected: error citing ex-3-1-no-host-network

# Regular pods (no hostNetwork) pass:
kubectl run regular -n ex-3-1 --image=nginx:1.27 --restart=Never
# Expected: pod/regular created
kubectl delete pod regular -n ex-3-1
```

---

### Exercise 3.2

**Objective:** Make the `ex-3-2-label-req` policy actually enforce its label rule.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: ex-3-2-label-req
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "has(object.metadata.labels) && 'cost-center' in object.metadata.labels"
      message: "Every pod must have a cost-center label"
      reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: ex-3-2-label-req-binding
spec:
  policyName: ex-3-2-label-requirement
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ex-3-2
EOF

sleep 5
```

**Task:**

After applying the objects above, a pod without the `cost-center` label is still accepted. Diagnose and fix.

**Verification:**

```bash
# A pod without cost-center is now rejected:
kubectl run no-cc -n ex-3-2 --image=nginx:1.27 --restart=Never 2>&1 | head -3
# Expected: error citing ex-3-2-label-req

# A pod with cost-center is accepted:
kubectl run ok -n ex-3-2 --image=nginx:1.27 --restart=Never --labels=cost-center=platform
# Expected: pod/ok created
kubectl delete pod ok -n ex-3-2
```

---

### Exercise 3.3

**Objective:** Make the `ex-3-3-replica-cap` policy actually reject Deployments with more than 3 replicas.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: ex-3-3-replica-cap
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["deployments"]
  validations:
    - expression: "object.spec.replicas <= 3"
      message: "Replicas must not exceed 3"
      reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: ex-3-3-replica-cap-binding
spec:
  policyName: ex-3-3-replica-cap
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ex-3-3
EOF

sleep 5
```

**Task:**

After the setup, a Deployment with 10 replicas is accepted in `ex-3-3`. Diagnose why the policy does not fire and fix the single issue.

**Verification:**

```bash
# Oversized deployment is now rejected:
kubectl create deployment big -n ex-3-3 --image=nginx:1.27 --replicas=10 2>&1 | head -3
# Expected: error citing ex-3-3-replica-cap

# A small deployment is accepted:
kubectl create deployment small -n ex-3-3 --image=nginx:1.27 --replicas=2
# Expected: deployment.apps/small created
kubectl delete deployment small -n ex-3-3
```

---

## Level 4: Complex Real-World Scenarios

### Exercise 4.1

**Objective:** Build a parameter-driven policy that enforces different replica caps in different namespaces.

**Task:**

Create a policy `ex-4-1-param-cap` with `paramKind: { apiVersion: v1, kind: ConfigMap }`, matching `deployments` in the `apps` group on CREATE and UPDATE. The validation expression is `object.spec.replicas <= int(params.data.maxReplicas)` with a `messageExpression` `"'Deployment replicas (' + string(object.spec.replicas) + ') exceed the cap (' + params.data.maxReplicas + ')'"` and reason `Invalid`.

Create two ConfigMaps both named `caps` in namespace `ex-4-1`:

- `caps-small` with `maxReplicas=3`.
- `caps-large` with `maxReplicas=15`.

Create two bindings that each apply to a different label selector on the object (use the Deployment's `tier` label): `ex-4-1-param-cap-small` binds `caps-small` to Deployments labeled `tier=small` in namespace `ex-4-1`; `ex-4-1-param-cap-large` binds `caps-large` to Deployments labeled `tier=large` in namespace `ex-4-1`. Both use action `Deny`.

**Verification:**

```bash
# A small-tier deployment with 2 replicas: allowed.
kubectl create deployment s1 -n ex-4-1 --image=nginx:1.27 --replicas=2
kubectl label deployment s1 -n ex-4-1 tier=small --overwrite
# Expected: both succeed.
kubectl delete deployment s1 -n ex-4-1

# A small-tier deployment with 10 replicas: should be rejected. Use a manifest
# so the label is present at create time (when admission runs):
cat <<'EOF' | kubectl apply -f - 2>&1 | head -3
apiVersion: apps/v1
kind: Deployment
metadata:
  name: s10
  namespace: ex-4-1
  labels:
    tier: small
spec:
  replicas: 10
  selector:
    matchLabels:
      app: s10
  template:
    metadata:
      labels:
        app: s10
        tier: small
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
EOF
# Expected: error citing ex-4-1-param-cap with the dynamic message.

# A large-tier deployment with 10 replicas: allowed.
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: l10
  namespace: ex-4-1
  labels:
    tier: large
spec:
  replicas: 10
  selector:
    matchLabels:
      app: l10
  template:
    metadata:
      labels:
        app: l10
        tier: large
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
EOF
# Expected: deployment.apps/l10 created.
kubectl delete deployment l10 -n ex-4-1
```

---

### Exercise 4.2

**Objective:** Block changes to a Deployment's `spec.serviceAccountName` on UPDATE while allowing it to be set at create time.

**Task:**

Create a policy `ex-4-2-sa-immutable` that matches `deployments` on UPDATE only. The validation expression is `object.spec.template.spec.serviceAccountName == oldObject.spec.template.spec.serviceAccountName`, message `"serviceAccountName is immutable"`, reason `Invalid`. Create binding `ex-4-2-sa-binding`, action `Deny`, scoped to namespace `ex-4-2`.

**Verification:**

```bash
# First create a Deployment with a specific SA:
kubectl create serviceaccount alpha -n ex-4-2
kubectl create serviceaccount beta  -n ex-4-2

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: immutable-sa
  namespace: ex-4-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: immutable-sa
  template:
    metadata:
      labels:
        app: immutable-sa
    spec:
      serviceAccountName: alpha
      containers:
        - name: nginx
          image: nginx:1.27
EOF
kubectl rollout status deployment/immutable-sa -n ex-4-2 --timeout=60s

# Attempt to change the SA via patch: should be rejected.
kubectl patch deployment immutable-sa -n ex-4-2 --type=merge --patch '
spec:
  template:
    spec:
      serviceAccountName: beta
' 2>&1 | head -3
# Expected: error citing ex-4-2-sa-immutable

# A benign patch (label change) should succeed:
kubectl label deployment immutable-sa -n ex-4-2 purpose=demo --overwrite
# Expected: deployment.apps/immutable-sa labeled
```

---

### Exercise 4.3

**Objective:** Use `messageExpression` to produce an error that names the offending container explicitly.

**Task:**

Create a policy `ex-4-3-dynamic-msg` whose validation uses `messageExpression` (not a static `message`). The validation must fail if any container image does not include a colon (no explicit tag). The `messageExpression` should build a string like `"container 'X' uses image 'Y' without an explicit tag"` for the first offending container. The expression can use `object.spec.containers.filter(c, !c.image.contains(':')).all(...)` but a simpler approach is `object.spec.containers.all(c, c.image.contains(':'))` with messageExpression that iterates. For this exercise use:

```yaml
expression: "object.spec.containers.all(c, c.image.contains(':'))"
messageExpression: "'First untagged container: ' + object.spec.containers.filter(c, !c.image.contains(':'))[0].name"
reason: Invalid
```

Create binding `ex-4-3-dynamic-binding`, action `Deny`, scoped to namespace `ex-4-3`.

**Verification:**

```bash
# A pod with two containers, one untagged:
cat <<'EOF' | kubectl apply -f - 2>&1 | head -3
apiVersion: v1
kind: Pod
metadata:
  name: mixed
  namespace: ex-4-3
spec:
  containers:
    - name: good
      image: nginx:1.27
    - name: bad
      image: nginx
EOF
# Expected: error citing ex-4-3-dynamic-msg and containing "First untagged container: bad"

# Fully-tagged pod: accepted.
kubectl run all-good -n ex-4-3 --image=nginx:1.27 --restart=Never
# Expected: pod/all-good created
kubectl delete pod all-good -n ex-4-3
```

---

## Level 5: Advanced

### Exercise 5.1

**Objective:** Design a cluster-guardrail set of policies for a shared platform namespace that enforces four requirements at once.

**Task:**

In namespace `ex-5-1`, enforce all of the following through one or more ValidatingAdmissionPolicies with `validationActions: ["Deny"]`:

1. Every pod must have containers whose images start with `registry.example.com/`.
2. Every pod must have both a `team` label and an `env` label; the `env` value must be one of `dev`, `staging`, `prod`.
3. No pod may set `spec.hostNetwork: true` or `spec.hostPID: true`.
4. No container may run as root (`spec.containers[].securityContext.runAsUser != 0` when set; the policy does not need to enforce that `runAsUser` is set, only that if it is set it is not 0).

Name the policies and bindings with an `ex-5-1-` prefix. All must be scoped to namespace `ex-5-1` via the `kubernetes.io/metadata.name` label selector.

**Verification:**

```bash
# A pod that violates all four: rejected (first-failing validation message).
cat <<'EOF' | kubectl apply -f - 2>&1 | head -3
apiVersion: v1
kind: Pod
metadata:
  name: bad-all
  namespace: ex-5-1
spec:
  hostNetwork: true
  containers:
    - name: nginx
      image: nginx:1.27
      securityContext:
        runAsUser: 0
EOF
# Expected: error citing one of the ex-5-1-* policies.

# A pod that passes all four: accepted.
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: good-all
  namespace: ex-5-1
  labels:
    team: platform
    env: prod
spec:
  containers:
    - name: nginx
      image: registry.example.com/nginx:1.27
      securityContext:
        runAsUser: 1000
EOF
# Expected: pod/good-all created (admission accepts; container may fail to pull, that is fine).
kubectl delete pod good-all -n ex-5-1 --ignore-not-found

# All four policies exist (pattern match):
kubectl get validatingadmissionpolicies -o name | grep -c '^validatingadmissionpolicy.admissionregistration.k8s.io/ex-5-1-'
# Expected: 4 (or the number of policies used to satisfy the four rules).
```

---

### Exercise 5.2

**Objective:** Fix the multiple issues that prevent the `ex-5-2-guardrail` policy from working as intended.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: ex-5-2-guardrail
spec:
  failurePolicy: Ignore
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE"]
        resources: ["pod"]
  validations:
    - expression: "object.spec.containers[0].image.startsWith('registry.example.com/')"
      message: "Images must come from registry.example.com/"
      reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: ex-5-2-guardrail-binding
spec:
  policyName: ex-5-2-guardrail
  validationActions: ["Audit"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ex-5-2
EOF

sleep 5
```

**Task:**

After the setup, pods in `ex-5-2` with images that do not start with `registry.example.com/` are still accepted without any visible warning or denial. The configuration has three independent problems that together prevent the policy from blocking bad pods. Diagnose and fix all three so that:

- The policy covers every container in the pod (not just the first one).
- The policy matches pods on CREATE and UPDATE.
- The binding rejects non-conforming pods (not just audits them).

**Verification:**

```bash
# After the fix, a non-conforming pod is rejected:
kubectl run bad -n ex-5-2 --image=nginx:1.27 --restart=Never 2>&1 | head -3
# Expected: error citing ex-5-2-guardrail

# A multi-container pod where the second container has a bad image is rejected:
cat <<'EOF' | kubectl apply -f - 2>&1 | head -3
apiVersion: v1
kind: Pod
metadata:
  name: multi-bad
  namespace: ex-5-2
spec:
  containers:
    - name: a
      image: registry.example.com/app:1.0
    - name: b
      image: nginx:1.27
EOF
# Expected: error citing ex-5-2-guardrail (b is the offender).

# Checks on the fixed configuration:
kubectl get validatingadmissionpolicy ex-5-2-guardrail \
  -o jsonpath='{.spec.matchConstraints.resourceRules[0].resources[0]}{"\n"}'
# Expected: pods

kubectl get validatingadmissionpolicy ex-5-2-guardrail \
  -o jsonpath='{range .spec.matchConstraints.resourceRules[0].operations[*]}{.}{"\n"}{end}' \
  | sort
# Expected two lines (sorted): CREATE, UPDATE

kubectl get validatingadmissionpolicybinding ex-5-2-guardrail-binding \
  -o jsonpath='{.spec.validationActions[0]}{"\n"}'
# Expected: Deny
```

---

### Exercise 5.3

**Objective:** Author the full chain of objects (Policy, Binding, and parameter ConfigMap) for a production-style requirement in one shot.

**Task:**

In namespace `ex-5-3`, enforce: "Every Deployment whose name starts with `prod-` must have a minimum of 3 replicas and must use an image from `registry.example.com/`." The minimum replica count (3) must come from a ConfigMap parameter, not a hardcoded literal in the policy, so the policy is reusable with a different threshold later.

Create:

1. A policy `ex-5-3-prod` targeting Deployments on CREATE and UPDATE, with `paramKind: { apiVersion: v1, kind: ConfigMap }`, and two validations:
    - Expression `!(object.metadata.name.startsWith('prod-')) || object.spec.replicas >= int(params.data.minReplicas)`; message `"prod-* deployments require at least params.data.minReplicas replicas"`; reason `Invalid`.
    - Expression `!(object.metadata.name.startsWith('prod-')) || object.spec.template.spec.containers.all(c, c.image.startsWith('registry.example.com/'))`; message `"prod-* deployments must use registry.example.com/ images"`; reason `Invalid`.
2. A ConfigMap `ex-5-3-params` in namespace `ex-5-3` with key `minReplicas` and value `3`.
3. A binding `ex-5-3-prod-binding` with `validationActions: ["Deny"]`, `paramRef.name: ex-5-3-params`, `paramRef.namespace: ex-5-3`, `paramRef.parameterNotFoundAction: Deny`, scoped to namespace `ex-5-3`.

Non-`prod-` Deployments should be unaffected.

**Verification:**

```bash
# Non-prod Deployment: allowed (policy short-circuits on name).
kubectl create deployment staging-app -n ex-5-3 --image=nginx:1.27 --replicas=1
# Expected: deployment.apps/staging-app created.
kubectl delete deployment staging-app -n ex-5-3

# prod- with 1 replica: rejected (replica-count validation).
kubectl create deployment prod-web -n ex-5-3 --image=registry.example.com/nginx:1.27 --replicas=1 2>&1 | head -3
# Expected: error citing ex-5-3-prod

# prod- with 5 replicas and wrong image: rejected (image validation).
cat <<'EOF' | kubectl apply -f - 2>&1 | head -3
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prod-api
  namespace: ex-5-3
spec:
  replicas: 5
  selector:
    matchLabels:
      app: prod-api
  template:
    metadata:
      labels:
        app: prod-api
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
EOF
# Expected: error citing ex-5-3-prod image validation.

# prod- with 5 replicas and correct image: accepted.
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prod-ok
  namespace: ex-5-3
spec:
  replicas: 5
  selector:
    matchLabels:
      app: prod-ok
  template:
    metadata:
      labels:
        app: prod-ok
    spec:
      containers:
        - name: nginx
          image: registry.example.com/nginx:1.27
EOF
# Expected: deployment.apps/prod-ok created.
kubectl delete deployment prod-ok -n ex-5-3
```

---

## Cleanup

Delete all namespaces and the cluster-scoped policy/binding resources (the policy and binding resources are cluster-scoped and do not go away when the namespace is deleted):

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 \
          ex-2-1 ex-2-2 ex-2-3 \
          ex-3-1 ex-3-2 ex-3-3 \
          ex-4-1 ex-4-2 ex-4-3 \
          ex-5-1 ex-5-2 ex-5-3; do
  kubectl delete namespace $ns --ignore-not-found
done

# Delete every policy and binding created by the exercises:
kubectl get validatingadmissionpolicies -o name \
  | grep '^validatingadmissionpolicy.admissionregistration.k8s.io/ex-' \
  | xargs -r kubectl delete

kubectl get validatingadmissionpolicybindings -o name \
  | grep '^validatingadmissionpolicybinding.admissionregistration.k8s.io/ex-' \
  | xargs -r kubectl delete
```

---

## Key Takeaways

A `ValidatingAdmissionPolicy` without a `ValidatingAdmissionPolicyBinding` has no effect; the binding is what activates the policy against real resources. Conversely, a binding that references a nonexistent policy also has no effect, and the mismatch applies silently at the API layer (`kubectl apply` accepts both objects). When a policy appears "not to fire," the first thing to check is that the binding's `policyName` exactly matches the policy's `metadata.name`.

The `matchConstraints.resourceRules` on the policy is exact: the `resources` list uses plural lowercase names (`pods`, `deployments`, never `pod` or `Pod`), and the `apiGroups` list is an empty string `""` for core-group resources, not the literal word `"core"`. Getting these wrong produces a policy that compiles and applies but never triggers on real requests.

CEL expressions that read optional fields must check existence first. `object.spec.hostNetwork` when the field is unset yields an error; wrapping with `has(object.spec.hostNetwork) && object.spec.hostNetwork == true` is the safe form. Under `failurePolicy: Fail`, an expression error counts as a denial with a cryptic message; under `failurePolicy: Ignore` it silently passes. The safer gate for security-critical policies is `Fail`, paired with defensive CEL.

`validationActions` is a list, not an exclusive choice. A single binding can be `["Deny", "Audit"]` to both reject the request and record it, `["Warn", "Audit"]` to let the request through with a warning and a record, or `["Deny"]` alone for the common case. `Warn` is the right choice during a rollout when you want to see what the policy would reject without actually rejecting in production.

The `paramKind` plus `paramRef` pattern makes policies reusable across namespaces with different thresholds. The policy references the shape of the parameter (a ConfigMap, a CRD, whatever resource has the fields the CEL expressions read); each binding then points at a specific instance of that resource. `parameterNotFoundAction: Deny` makes the absence of the parameter a denial; `Allow` makes it a pass. Choose `Deny` for security-critical policies.

Error messages from admission controllers and policies are structured; the string that kubectl prints starts with a phrase that identifies the source. `exceeded quota: X` identifies the `ResourceQuota` built-in; `violates PodSecurity` identifies the `PodSecurity` built-in; `ValidatingAdmissionPolicy 'X' with binding 'Y' denied request` identifies a specific custom policy and binding. Memorizing these prefixes turns a five-minute debug into a five-second one: read the error, name the source, inspect the configuration, fix.
