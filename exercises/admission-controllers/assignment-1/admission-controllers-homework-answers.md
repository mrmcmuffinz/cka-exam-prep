# Admission Controllers Homework Answers

Complete solutions for all 15 exercises. Level 3 and the Level 5 debug exercise (5.2) use the three-stage structure (Diagnosis, What the bug is and why, Fix). Build and design exercises show the canonical policy/binding YAML with commentary on the key choices.

---

## Exercise 1.1 Solution

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: ex-1-1-image-prefix
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
      message: "Images must come from registry.example.com/"
      reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: ex-1-1-image-prefix-binding
spec:
  policyName: ex-1-1-image-prefix
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ex-1-1
```

The validation uses CEL's `all()` macro to require every container to satisfy the prefix condition. The `kubernetes.io/metadata.name` label on the binding's namespaceSelector is the standard way to scope to a specific namespace; Kubernetes automatically sets that label on every namespace.

---

## Exercise 1.2 Solution

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: ex-1-2-replica-cap
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: ["apps"]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["deployments"]
  validations:
    - expression: "object.spec.replicas <= 5"
      message: "Replicas must not exceed 5"
      reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: ex-1-2-replica-cap-binding
spec:
  policyName: ex-1-2-replica-cap
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ex-1-2
```

The `apps` API group is the key change from Exercise 1.1; Deployments are not in the core group. If you forget this, the policy applies but never matches any request; `kubectl get validatingadmissionpolicy ex-1-2-replica-cap` shows the policy exists but `kubectl create deployment big --replicas=10` succeeds because the admission layer finds no matching rule.

---

## Exercise 1.3 Solution

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: ex-1-3-team-label
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "has(object.metadata.labels) && 'team' in object.metadata.labels"
      message: "Every pod must have a team label"
      reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: ex-1-3-team-label-binding
spec:
  policyName: ex-1-3-team-label
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ex-1-3
```

CEL's `has()` is necessary because `object.metadata.labels` can be nil (when the object has no labels at all); `'team' in object.metadata.labels` would throw a runtime error on nil. Under `failurePolicy: Fail` that error becomes a denial with a cryptic message. The `has()` short-circuit keeps errors out of the expression.

---

## Exercise 2.1 Solution

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: ex-2-1-warn-bare-images
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "object.spec.containers.all(c, c.image.contains(':'))"
      message: "Container images should have an explicit tag"
      reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: ex-2-1-warn-binding
spec:
  policyName: ex-2-1-warn-bare-images
  validationActions: ["Warn"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ex-2-1
```

`validationActions: ["Warn"]` without `Deny` means the pod is created and kubectl prints the message as a warning. This is the right action while a new policy is rolling out; it surfaces what would be rejected without interrupting workloads. Once confidence is established, switch to `Deny`.

Note that the CEL check `c.image.contains(':')` is a quick heuristic. A real-world policy would check for `:latest` explicitly (which still contains a colon), or use a regex like `c.image.matches('.*:[^:]+$')` to require a non-empty tag. The exercise uses the simpler form to stay readable.

---

## Exercise 2.2 Solution

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: ex-2-2-privileged-block
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "object.spec.containers.all(c, !has(c.securityContext) || !has(c.securityContext.privileged) || c.securityContext.privileged != true)"
      message: "Containers must not be privileged"
      reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: ex-2-2-privileged-binding
spec:
  policyName: ex-2-2-privileged-block
  validationActions: ["Deny", "Audit"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ex-2-2
```

The validation covers every container (not just the first) and uses `has()` guards so that containers without any `securityContext` are accepted. The two-action binding (`Deny` plus `Audit`) rejects the request and also records an annotation on the API server's audit entry; the user sees a denial, and the audit pipeline has a record.

The policy exercise here was written with a single expression for brevity. A cleaner production style uses one validation per concern, each with its own specific message.

---

## Exercise 2.3 Solution

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: ex-2-3-multi
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
      message: "Images must come from registry.example.com/"
      reason: Invalid
    - expression: "has(object.metadata.labels) && 'env' in object.metadata.labels && object.metadata.labels['env'].matches('^(dev|staging|prod)$')"
      message: "env label must be dev, staging, or prod"
      reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: ex-2-3-multi-binding
spec:
  policyName: ex-2-3-multi
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ex-2-3
```

Multi-validation policies evaluate each validation in order. The first failing validation stops evaluation and produces the error; subsequent validations are not checked. This is why the verification shows the image error when both validations would fail.

---

## Exercise 3.1 Solution

### Diagnosis

Inspect the policy to understand what it is targeting:

```bash
kubectl get validatingadmissionpolicy ex-3-1-no-host-network \
  -o jsonpath='{.spec.matchConstraints.resourceRules[0].apiGroups[0]}:{.spec.matchConstraints.resourceRules[0].resources[0]}{"\n"}'
```

Expected: `apps:pods`. That is wrong. Pods live in the core API group (`""`), not `apps`.

Confirm by trying to create a hostNetwork pod and observing it is accepted:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: diagnostic-hn
  namespace: ex-3-1
spec:
  hostNetwork: true
  containers:
    - name: nginx
      image: nginx:1.27
EOF
```

The pod applies without error; the admission layer did not find a matching policy because the policy is looking for pods in the `apps` API group, and no such combination exists.

### What the bug is and why it happens

The policy's `matchConstraints.resourceRules[0].apiGroups` is `["apps"]` instead of `[""]` (core). Pods live in the core group; `apps` is for Deployments, ReplicaSets, StatefulSets, and DaemonSets. The (apiGroup, resource) tuple `(apps, pods)` does not match any real request, so the policy is inert.

This is a close cousin of the RBAC mistake where someone writes `apiGroups: [""]` for Deployments. The right apiGroup for any resource is what `kubectl api-resources` reports in the `APIVERSION` column (everything before the `/` is the group; bare `v1` means core, which is written as `""`).

### Fix

Patch the policy:

```bash
kubectl patch validatingadmissionpolicy ex-3-1-no-host-network --type=json \
  --patch '[{"op":"replace","path":"/spec/matchConstraints/resourceRules/0/apiGroups","value":[""]}]'
```

Delete the test pod and retest; a hostNetwork pod is now rejected, and a regular pod is accepted.

```bash
kubectl delete pod diagnostic-hn -n ex-3-1
```

---

## Exercise 3.2 Solution

### Diagnosis

Check whether the binding is pointing at the right policy name:

```bash
kubectl get validatingadmissionpolicybinding ex-3-2-label-req-binding \
  -o jsonpath='{.spec.policyName}{"\n"}'
```

Expected: `ex-3-2-label-requirement`. The actual policy is named `ex-3-2-label-req` (without `-uirement`). The binding references a policy that does not exist.

Confirm the policy exists under the real name:

```bash
kubectl get validatingadmissionpolicy
```

Expected: a row for `ex-3-2-label-req` but no row for `ex-3-2-label-requirement`.

### What the bug is and why it happens

The binding's `spec.policyName` is `ex-3-2-label-requirement` but the policy's `metadata.name` is `ex-3-2-label-req`. The name mismatch means the binding references no real policy. Unlike RBAC, there is no referential integrity validation at apply time for admission bindings; the binding applies silently and is inert.

Typos in policy names are among the most common real failures. A policy that is "not firing" usually has a binding pointing somewhere slightly off.

### Fix

Patch the binding to reference the correct policy name:

```bash
kubectl patch validatingadmissionpolicybinding ex-3-2-label-req-binding --type=merge \
  --patch '{"spec":{"policyName":"ex-3-2-label-req"}}'
```

Retest; pods without a `cost-center` label are now rejected.

---

## Exercise 3.3 Solution

### Diagnosis

Check the policy's resource rules:

```bash
kubectl get validatingadmissionpolicy ex-3-3-replica-cap \
  -o jsonpath='{.spec.matchConstraints.resourceRules[0].apiGroups[0]}:{.spec.matchConstraints.resourceRules[0].resources[0]}{"\n"}'
```

Expected: `:deployments`. The `apiGroups` is `[""]` (core), but Deployments live in the `apps` API group.

Confirm the policy is inert by creating a big deployment and watching it succeed:

```bash
kubectl create deployment diagnostic-big -n ex-3-3 --image=nginx:1.27 --replicas=10
kubectl delete deployment diagnostic-big -n ex-3-3
```

### What the bug is and why it happens

The policy's `matchConstraints.resourceRules[0].apiGroups` is `[""]` (core) instead of `["apps"]`. Deployments are in the `apps` API group; no (core, deployments) combination exists in the request stream, so the policy never matches. The shape of the bug is the same class as Exercise 3.1 but with the opposite mistake: 3.1 used `apps` where `""` was right; 3.3 uses `""` where `apps` is right.

### Fix

Patch the policy:

```bash
kubectl patch validatingadmissionpolicy ex-3-3-replica-cap --type=json \
  --patch '[{"op":"replace","path":"/spec/matchConstraints/resourceRules/0/apiGroups","value":["apps"]}]'
```

Retest; deployments with more than 3 replicas are now rejected.

---

## Exercise 4.1 Solution

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: ex-4-1-param-cap
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
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: caps-small
  namespace: ex-4-1
data:
  maxReplicas: "3"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: caps-large
  namespace: ex-4-1
data:
  maxReplicas: "15"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: ex-4-1-param-cap-small
spec:
  policyName: ex-4-1-param-cap
  validationActions: ["Deny"]
  paramRef:
    name: caps-small
    namespace: ex-4-1
    parameterNotFoundAction: Deny
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ex-4-1
    objectSelector:
      matchLabels:
        tier: small
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: ex-4-1-param-cap-large
spec:
  policyName: ex-4-1-param-cap
  validationActions: ["Deny"]
  paramRef:
    name: caps-large
    namespace: ex-4-1
    parameterNotFoundAction: Deny
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ex-4-1
    objectSelector:
      matchLabels:
        tier: large
```

The same policy is bound twice with different parameters and different `objectSelector` label filters. The `tier=small` binding reads the `caps-small` ConfigMap (max 3 replicas); the `tier=large` binding reads `caps-large` (max 15 replicas). A Deployment labeled `tier=small` is rejected at 10 replicas; a Deployment labeled `tier=large` passes at 10 replicas because the large binding uses the looser cap.

The `parameterNotFoundAction: Deny` is defensive: if someone deletes the referenced ConfigMap, admission rejects everything (safer) rather than accepting everything (dangerous).

---

## Exercise 4.2 Solution

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: ex-4-2-sa-immutable
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: ["apps"]
        apiVersions: ["v1"]
        operations: ["UPDATE"]
        resources: ["deployments"]
  validations:
    - expression: "object.spec.template.spec.serviceAccountName == oldObject.spec.template.spec.serviceAccountName"
      message: "serviceAccountName is immutable"
      reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: ex-4-2-sa-binding
spec:
  policyName: ex-4-2-sa-immutable
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ex-4-2
```

The policy matches only `UPDATE` (not `CREATE`), which is why `object.spec.template.spec.serviceAccountName` can be set at create time without rejection. On UPDATE, `oldObject` holds the resource state before the update; `object` holds the proposed state. The validation requires equality between the two.

The admission layer exposes `oldObject` only for UPDATE and DELETE operations. For a policy that should validate a field across updates, always match on UPDATE explicitly. A policy that matches both CREATE and UPDATE using `oldObject` would fail on CREATE because `oldObject` would be nil, which under `failurePolicy: Fail` would reject every create.

---

## Exercise 4.3 Solution

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: ex-4-3-dynamic-msg
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "object.spec.containers.all(c, c.image.contains(':'))"
      messageExpression: "'First untagged container: ' + object.spec.containers.filter(c, !c.image.contains(':'))[0].name"
      reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: ex-4-3-dynamic-binding
spec:
  policyName: ex-4-3-dynamic-msg
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ex-4-3
```

`messageExpression` is an alternative to the static `message` field. It evaluates a CEL expression to produce the error message string. Here it filters containers whose image does not contain a colon, takes the first such container, and returns the container's name as part of the error. The operator who sees the error in kubectl output knows which container to fix without opening the pod spec.

`messageExpression` has one practical constraint: it runs only when the `expression` evaluates to false. If you rely on `messageExpression` to compute a value that itself can fail (for example, indexing `[0]` on an empty list), make sure the `expression` guarantees the list is non-empty. In this case, the expression `all(c, c.image.contains(':'))` returns false only when at least one container does not contain a colon, so the `filter(...)[0]` in `messageExpression` is safe.

---

## Exercise 5.1 Solution

Four policies (or fewer, if concerns can be combined). One reasonable decomposition:

```yaml
# Policy 1: images from registry.example.com/
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: ex-5-1-image-registry
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
      message: "Images must come from registry.example.com/"
      reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: ex-5-1-image-registry-binding
spec:
  policyName: ex-5-1-image-registry
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ex-5-1
---
# Policy 2: required labels (team and env)
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: ex-5-1-labels
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "has(object.metadata.labels) && 'team' in object.metadata.labels"
      message: "team label is required"
      reason: Invalid
    - expression: "has(object.metadata.labels) && 'env' in object.metadata.labels && object.metadata.labels['env'].matches('^(dev|staging|prod)$')"
      message: "env label must be dev, staging, or prod"
      reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: ex-5-1-labels-binding
spec:
  policyName: ex-5-1-labels
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ex-5-1
---
# Policy 3: no host namespaces
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: ex-5-1-no-host-ns
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "!(has(object.spec.hostNetwork) && object.spec.hostNetwork == true)"
      message: "hostNetwork is not allowed"
      reason: Invalid
    - expression: "!(has(object.spec.hostPID) && object.spec.hostPID == true)"
      message: "hostPID is not allowed"
      reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: ex-5-1-no-host-ns-binding
spec:
  policyName: ex-5-1-no-host-ns
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ex-5-1
---
# Policy 4: no runAsUser=0
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: ex-5-1-no-root
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "object.spec.containers.all(c, !has(c.securityContext) || !has(c.securityContext.runAsUser) || c.securityContext.runAsUser != 0)"
      message: "containers must not run as root (runAsUser=0)"
      reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: ex-5-1-no-root-binding
spec:
  policyName: ex-5-1-no-root
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ex-5-1
```

Four policies is the cleanest decomposition because it lets each concern have its own name, its own evolution, and its own status when something goes wrong. A single monster policy with every validation in one array is also valid but makes individual overrides harder: if the "no-root" rule needs to be relaxed for a specific namespace in the future, a separate policy is easier to bind differently than a shared validation inside a larger policy.

---

## Exercise 5.2 Solution

### Diagnosis

Inspect the policy's matchConstraints:

```bash
kubectl get validatingadmissionpolicy ex-5-2-guardrail -o yaml
```

Read three fields:

- `spec.matchConstraints.resourceRules[0].resources`: value is `["pod"]` (singular). That is wrong; RBAC and admission rules use plural resource names.
- `spec.matchConstraints.resourceRules[0].operations`: value is `["CREATE"]` only. UPDATEs are not covered.
- `spec.validations[0].expression`: `object.spec.containers[0].image.startsWith(...)`. This only checks the first container; a multi-container pod can smuggle a bad image in containers[1].

And the binding:

```bash
kubectl get validatingadmissionpolicybinding ex-5-2-guardrail-binding \
  -o jsonpath='{range .spec.validationActions[*]}{.}{"\n"}{end}'
```

Value: `Audit`. The binding records policy decisions to the audit log but does not deny the request. Non-conforming pods are accepted.

Also note the policy's `failurePolicy: Ignore` means any CEL evaluation error is treated as a pass. This is not one of the three problems the exercise asks about, but it is worth fixing to `Fail` as defense in depth.

### What the bug is and why it happens

Three problems, each independent, each applies cleanly:

1. `resources: ["pod"]` is the singular form; the admission layer does not match a resource name against the singular. RBAC has the same rule: resource names are plural.
2. `operations: ["CREATE"]` omits UPDATE; a pod mutation that changes the image after creation (unusual in pods but possible on the template level for workload controllers) is not validated.
3. `validationActions: ["Audit"]` records without denying. The pod is created; only an audit-log consumer notices.
4. (Bonus) `failurePolicy: Ignore` silently accepts validation errors. Under `Fail` the CEL bug on first-container-only would have produced at least a cryptic rejection; under `Ignore` the evaluation errors (if any) silently pass.

### Fix

Apply a corrected policy and binding:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: ex-5-2-guardrail
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
      message: "Images must come from registry.example.com/"
      reason: Invalid
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: ex-5-2-guardrail-binding
spec:
  policyName: ex-5-2-guardrail
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ex-5-2
```

Reapply with `kubectl apply -f`. The policy and binding update in place; any subsequent request is evaluated with the corrected configuration.

---

## Exercise 5.3 Solution

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: ex-5-3-prod
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
    - expression: "!(object.metadata.name.startsWith('prod-')) || object.spec.replicas >= int(params.data.minReplicas)"
      messageExpression: "'prod-* deployment ' + object.metadata.name + ' needs at least ' + params.data.minReplicas + ' replicas'"
      reason: Invalid
    - expression: "!(object.metadata.name.startsWith('prod-')) || object.spec.template.spec.containers.all(c, c.image.startsWith('registry.example.com/'))"
      message: "prod-* deployments must use registry.example.com/ images"
      reason: Invalid
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ex-5-3-params
  namespace: ex-5-3
data:
  minReplicas: "3"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: ex-5-3-prod-binding
spec:
  policyName: ex-5-3-prod
  validationActions: ["Deny"]
  paramRef:
    name: ex-5-3-params
    namespace: ex-5-3
    parameterNotFoundAction: Deny
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: ex-5-3
```

Both validations use a short-circuit pattern: `!(object.metadata.name.startsWith('prod-'))` returns true for non-prod Deployments, making the whole expression true, so the validation passes without checking the other conditions. Only prod-prefixed Deployments reach the interesting part of the expression. This pattern is the idiomatic way to make a policy scope-aware based on object properties without having to scope the binding by label (which is not always possible when the property is part of the name).

The threshold of 3 comes from `params.data.minReplicas` because the requirement was "the minimum replica count must come from a ConfigMap parameter, not a hardcoded literal." Changing the threshold in production is now a single patch on the ConfigMap; the policy itself does not need editing.

---

## Common Mistakes

Writing `resources: ["pod"]` or `resources: ["deployment"]` in singular. Admission resource names are plural, always. The policy applies, but never matches any real request, because the admission layer's resource-name match is exact.

Writing `apiGroups: [""]` for Deployments or `apiGroups: ["apps"]` for Pods. The API group is part of the (group, resource) tuple the admission layer matches against. Pods are in the core group (empty string); Deployments, ReplicaSets, StatefulSets, and DaemonSets are in `apps`. Mixing the two up produces an inert policy.

Matching only `CREATE` when `UPDATE` also matters. A policy that only runs at create time does not catch subsequent modifications through `kubectl edit`, `kubectl patch`, or a controller that reconciles the object. Always include `UPDATE` in `operations` unless there is a specific reason not to.

Setting `validationActions: ["Audit"]` and expecting the policy to reject anything. `Audit` is the silent-record action; the user sees nothing. Combine `["Deny", "Audit"]` when a denial should also be logged; use `["Warn"]` during rollouts when you want visible warnings without blocking.

Writing a CEL expression that reads an optional field without `has()` guarding. When the field is unset the expression throws at evaluation time. Under `failurePolicy: Fail` every such error becomes a cryptic denial; under `Ignore` every such error silently passes. `has(object.spec.X) && object.spec.X == Y` is the safe form.

Pointing the binding's `policyName` at a nonexistent policy name. Kubernetes does not validate referential integrity on binding apply; the binding exists but never fires. When a policy seems inert, the first thing to check is that `spec.policyName` in the binding exactly matches `metadata.name` on the policy.

Relying on `oldObject` in a validation that also matches `CREATE`. On CREATE the `oldObject` is nil; any read throws at evaluation time, and the policy reliably rejects every create. Match only `UPDATE` (and optionally `DELETE`) when using `oldObject` in CEL.

Forgetting that policy and binding objects are cluster-scoped. Namespace delete does not remove them. The cleanup block at the bottom of every exercise in this assignment explicitly deletes the relevant policies and bindings; production operators should keep the same discipline.

---

## Verification Commands Cheat Sheet

```bash
# List policies and bindings
kubectl get validatingadmissionpolicies
kubectl get validatingadmissionpolicybindings

# Inspect a specific one
kubectl describe validatingadmissionpolicy NAME
kubectl describe validatingadmissionpolicybinding NAME

# Show the binding's referenced policy and actions
kubectl get validatingadmissionpolicybinding NAME \
  -o jsonpath='{.spec.policyName}:{.spec.validationActions}{"\n"}'

# Show the policy's matchConstraints
kubectl get validatingadmissionpolicy NAME \
  -o jsonpath='{.spec.matchConstraints.resourceRules[0].apiGroups}:{.spec.matchConstraints.resourceRules[0].resources}:{.spec.matchConstraints.resourceRules[0].operations}{"\n"}'

# Show the expression list
kubectl get validatingadmissionpolicy NAME \
  -o jsonpath='{range .spec.validations[*]}{.expression}{"\n"}{end}'

# Test a policy is scoped to a specific namespace via namespaceSelector
kubectl get validatingadmissionpolicybinding NAME \
  -o jsonpath='{.spec.matchResources.namespaceSelector}{"\n"}'

# Read the API server's admission plugin flags (inside the node)
nerdctl exec kind-control-plane \
  grep -E 'enable-admission-plugins|disable-admission-plugins' \
    /etc/kubernetes/manifests/kube-apiserver.yaml

# Patch a policy's apiGroups (common fix for group-mismatch bugs)
kubectl patch validatingadmissionpolicy NAME --type=json \
  --patch '[{"op":"replace","path":"/spec/matchConstraints/resourceRules/0/apiGroups","value":["apps"]}]'

# Patch a binding's policyName (common fix for name-mismatch bugs)
kubectl patch validatingadmissionpolicybinding NAME --type=merge \
  --patch '{"spec":{"policyName":"CORRECT_NAME"}}'
```

The single most useful diagnostic command is reading kubectl's own error message. Admission denials name the policy and binding explicitly in the string (`ValidatingAdmissionPolicy 'X' with binding 'Y' denied request: ...`), which tells you exactly which configuration to inspect next. The only failure mode that does not produce a clear error is a policy that has no effect at all; for that, check first whether the binding's `policyName` matches the policy's name, then whether the `matchConstraints` matches the request's (group, resource, operation) tuple, then whether the `namespaceSelector` matches the request's namespace.
