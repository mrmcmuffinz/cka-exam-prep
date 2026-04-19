# Prompt: Admission Controllers and ValidatingAdmissionPolicy (assignment-1)

## Header

- **Series:** Admission Controllers (1 of 1)
- **CKA domain:** Workloads & Scheduling (15%) and Cluster Architecture (25%)
- **Competencies covered:** Configure Pod admission and scheduling (admission controllers, validating and mutating); understand request flow from authentication through authorization to admission
- **Course sections referenced:** S3 (lectures 82-87, admission controllers), S7 (security primitives)
- **Prerequisites:** `01-pods/assignment-1` (pod spec fundamentals), `12-rbac/assignment-1` (for testing with different subjects)

## Scope declaration

### In scope for this assignment

*Request flow context*
- The four-stage API server request flow: authentication, authorization, admission, persistence
- Where admission fits (after auth+authz, before write to etcd)
- The two admission phases: mutating (can modify the object) and validating (can only accept or reject)
- Order: mutating admission, then validating admission

*Common built-in admission controllers*
- `NamespaceLifecycle` (blocks resource creation in terminating namespaces)
- `LimitRanger` (applies default resource limits, rejects resources exceeding LimitRange bounds)
- `ResourceQuota` (rejects resources that would exceed a namespace's ResourceQuota)
- `ServiceAccount` (injects a default ServiceAccount if the pod does not specify one)
- `DefaultStorageClass` (sets the default StorageClass on PVCs that omit `storageClassName`)
- `MutatingAdmissionWebhook` and `ValidatingAdmissionWebhook` (call external webhook servers)
- `PodSecurity` (enforces Pod Security Standards; covered in depth in `pod-security/`)

*Checking enabled admission controllers in kind*
- Reading the kube-apiserver static pod manifest at `/etc/kubernetes/manifests/kube-apiserver.yaml`
- The `--enable-admission-plugins` and `--disable-admission-plugins` flags
- Observing default-enabled plugins via `kube-apiserver -h | grep admission`

*ValidatingAdmissionPolicy (CEL-based, GA in Kubernetes 1.30)*
- `apiVersion: admissionregistration.k8s.io/v1`, `kind: ValidatingAdmissionPolicy`
- `spec.matchConstraints` (which resources the policy applies to)
- `spec.validations` (CEL expressions that must return true)
- `spec.failurePolicy` (Fail or Ignore)
- `spec.paramKind` (reference to a parameter resource)
- `ValidatingAdmissionPolicyBinding` (binds a policy to a namespace selector and optional params)
- Enforcement actions via `spec.validationActions`: Deny, Warn, Audit

*Writing CEL expressions for common validations*
- Reading `object.spec.X` and `params.Y`
- Simple predicates like "container image must start with `example.com/`"
- Numeric comparisons like "replicas must be <= 10"
- String functions like `startsWith`, `contains`, `matches` (regex)

*Diagnostic workflow for admission errors*
- Reading `kubectl apply` error messages that reference admission plugins
- Example: `Error from server (Forbidden): pods "foo" is forbidden: violates PodSecurity ...`
- Example: `Error from server: admission webhook "X" denied the request: ...`
- Example: `Error from server: ValidatingAdmissionPolicy 'Y' with binding 'Z' denied request: ...`
- Reading API server audit events for admission traces (when audit logging is configured)

### Out of scope (covered in other assignments, do not include)

- Authentication mechanisms (certificates, tokens): covered in `tls-and-certificates/` and `rbac/`
- Authorization mechanisms (RBAC, ABAC): covered in `rbac/`
- Pod Security Standards and Pod Security Admission specifically: covered in `pod-security/`
- LimitRange and ResourceQuota resource specs: covered in `01-pods/assignment-5` (their admission enforcement is a single talking point here)
- Writing custom admission webhook servers (Go or otherwise): out of CKA scope
- Dynamic admission webhook configuration: in scope conceptually but do not deep-dive webhook authentication/signing; the assignment focuses on ValidatingAdmissionPolicy since it does not require a webhook server

## Environment requirements

- Single-node kind cluster per `docs/cluster-setup.md#single-node-kind-cluster`
- `kindest/node:v1.35.0` image (Kubernetes 1.35) because `ValidatingAdmissionPolicy` is GA only in 1.30+
- No special CNI, storage, or ingress components needed

## Resource gate

All CKA resources are in scope. The assignment uses ValidatingAdmissionPolicy, ValidatingAdmissionPolicyBinding, Namespaces, Pods, Deployments, and ServiceAccounts. ConfigMaps or Secrets may appear as target resources for policy validation exercises.

## Topic-specific conventions

- Every CEL expression used in exercises must be small enough to read in one screenful. Do not introduce long chained expressions or custom functions.
- The tutorial must show at least one mutating behavior (DefaultStorageClass adding a field, ServiceAccount admission) and at least one validating behavior (ResourceQuota rejection). Seeing both kinds of admission is essential for the mental model.
- Demonstrate the `Warn` and `Audit` enforcement actions as well as `Deny`. Warn shows up in `kubectl` output as a warning, Deny causes a hard rejection.
- Debugging exercises must show the error message the learner would see in `kubectl apply` output, and tie the message back to the admission plugin or policy that produced it.
- Do not require setting up a webhook server. Webhook admission is covered conceptually only; hands-on focuses on built-ins and `ValidatingAdmissionPolicy`.
- Cleanup must explicitly delete ValidatingAdmissionPolicy and ValidatingAdmissionPolicyBinding resources (they are cluster-scoped and persist across namespaces).

## Cross-references

**Prerequisites (must be completed first):**
- `exercises/01-01-pods/assignment-1`: pod spec fundamentals
- `exercises/12-12-rbac/assignment-1`: `kubectl auth can-i --as=USER` for testing admission decisions under different identities

**Adjacent topics:**
- `exercises/14-pod-security/`: Pod Security Admission, which is a specific admission controller
- `exercises/12-12-rbac/assignment-2`: cluster-scoped RBAC (some admission-related resources are cluster-scoped)

**Forward references:**
- `exercises/19-19-troubleshooting/assignment-1`: application troubleshooting includes admission denials as a failure category (pod never creates because admission rejects it)
