# Prompt: Pod Security Standards and Pod Security Admission (assignment-1)

## Header

- **Series:** Pod Security (1 of 1)
- **CKA domain:** Workloads & Scheduling (15%)
- **Competencies covered:** Configure Pod admission (Pod Security Standards, Pod Security Admission)
- **Course sections referenced:** S7 (lectures 175-178, security contexts); new material per the 2025 CKA curriculum refresh that added PSA
- **Prerequisites:** `pods/assignment-1`, `security-contexts/assignment-1`, `security-contexts/assignment-3`

## Scope declaration

### In scope for this assignment

*Pod Security Standards (PSS) profiles*
- Three profiles: Privileged, Baseline, Restricted
- What each profile permits and restricts (the full list of fields PSS governs lives in the Kubernetes documentation; the tutorial must summarize the major ones at a glance)
- How Privileged is a no-op, Baseline blocks clearly insecure settings, Restricted enforces hardened defaults
- When each profile is appropriate (Privileged for infrastructure namespaces, Baseline for shared developer namespaces, Restricted for multi-tenant or production namespaces)

*Pod Security Admission (PSA) controller*
- PSA is a built-in admission plugin, enabled by default in modern Kubernetes
- Enforcement operates at namespace scope via labels
- Three modes: `enforce` (rejects violators), `audit` (logs to audit log), `warn` (emits a client warning)
- Modes can be combined on one namespace (enforce baseline, warn restricted, for example)

*Label family*
- `pod-security.kubernetes.io/enforce: <profile>`
- `pod-security.kubernetes.io/audit: <profile>`
- `pod-security.kubernetes.io/warn: <profile>`
- `pod-security.kubernetes.io/enforce-version: <version>` (pin to a specific Kubernetes version; defaults to `latest`)
- `pod-security.kubernetes.io/audit-version` and `pod-security.kubernetes.io/warn-version`
- Why pinning versions matters (PSS definitions evolve with Kubernetes releases)

*Interaction with `securityContext`*
- PSA evaluates the pod's `securityContext` and `containers[].securityContext` against the namespace profile
- A pod that passes Baseline may still fail Restricted; the learner must understand both levels
- The `restricted` profile requires `runAsNonRoot: true`, `seccompProfile.type: RuntimeDefault`, and `allowPrivilegeEscalation: false` among other constraints

*Applying PSA to namespaces*
- Label a namespace with `kubectl label namespace <ns> pod-security.kubernetes.io/enforce=<profile>`
- Observe rejection when creating a non-compliant pod in an enforced namespace
- Observe warnings emitted when creating a pod that violates the `warn` level but not the `enforce` level
- Observe nothing visible (except audit events) when a pod violates the `audit` level

*Diagnostic workflow*
- Reading `kubectl apply` rejection messages that cite PodSecurity
- Example: `pods "foo" is forbidden: violates PodSecurity "baseline:latest": host namespaces (hostNetwork=true)`
- Using `warn` mode to preview the impact of tightening enforcement without breaking existing workloads
- Exemptions at cluster level via API server admission config (conceptual; not hands-on since kind makes this cumbersome)

### Out of scope (covered in other assignments, do not include)

- `securityContext` fields themselves (runAsUser, capabilities, readOnlyRootFilesystem, seccomp): covered in the `security-contexts/` series
- General admission controller mechanics: covered in `admission-controllers/`
- RBAC for who can label namespaces: covered in `rbac/`
- Network-level security (NetworkPolicy): covered in `network-policies/`
- PodSecurityPolicy (removed in Kubernetes 1.25): do not cover; PSA is its replacement

## Environment requirements

- Single-node kind cluster per `docs/cluster-setup.md#single-node-kind-cluster`
- `kindest/node:v1.35.0` (PSA is enabled by default on all recent versions)
- No special CNI or storage needed

## Resource gate

All CKA resources are in scope. The assignment uses Namespaces (with PSA labels), Pods with various `securityContext` configurations, and Deployments as wrappers for some exercises.

## Topic-specific conventions

- Every exercise that tests enforcement must include both a compliant and a non-compliant pod spec so the learner can compare the success and failure paths directly.
- Debugging exercises should surface the exact error message text that PSA emits and teach the learner to extract the relevant fields from that message.
- The tutorial must include a worked example of the `warn` mode being used as a staging tool: label the namespace to warn on restricted, observe the warnings, then decide whether to flip to enforce.
- Exercises should vary the profile across namespaces (some baseline, some restricted) so the learner builds intuition for when each applies.
- Cleanup must remove the PSA labels from namespaces before deleting them (mostly for explicitness since namespace deletion removes the labels anyway).

## Cross-references

**Prerequisites (must be completed first):**
- `exercises/pods/assignment-1`: pod spec fundamentals
- `exercises/security-contexts/assignment-1`: runAsUser, runAsNonRoot, fsGroup
- `exercises/security-contexts/assignment-3`: readOnlyRootFilesystem, seccomp

**Adjacent topics:**
- `exercises/admission-controllers/`: PSA is one admission controller among many
- `exercises/security-contexts/`: the fields PSA enforces
- `exercises/rbac/`: who can bypass PSA enforcement or label namespaces

**Forward references:**
- `exercises/troubleshooting/assignment-1`: application-layer troubleshooting includes PSA rejections as a failure category
