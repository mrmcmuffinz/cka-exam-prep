# Security Contexts

**CKA Domain:** Workloads & Scheduling (15%)
**Competencies covered:** Configure Pod admission and scheduling

---

## Why One Assignment

Security contexts control what a container can do at runtime: which user it runs as,
which Linux capabilities it has, whether it can escalate privileges, and whether its
root filesystem is read-only. The subtopic count is moderate (roughly 10 distinct
areas including pod-level vs container-level settings, capabilities, fsGroup
interaction with volumes, and seccomp profiles), and the concepts are tightly related.
A single assignment provides enough room for basic configuration exercises, multi-layer
scenarios combining pod-level and container-level settings, and debugging exercises
where a misconfigured security context prevents a container from functioning.

---

## Assignments

| Assignment | Title | Covers | Prerequisites |
|---|---|---|---|
| assignment-1 | Security Contexts | Pod-level securityContext (runAsUser, runAsGroup, fsGroup), container-level securityContext (runAsNonRoot, readOnlyRootFilesystem, capabilities, allowPrivilegeEscalation), seccomp profiles, fsGroup interaction with volumes, verification via exec | pods/assignment-1, pods/assignment-2 |

## Scope Boundaries

This topic covers runtime security settings on pods and containers. The following
related areas are handled by other topics:

- **RBAC** (who can create pods with specific security contexts): covered in `rbac/`
- **Network Policies** (network-level security): covered in `network-policies/`
- **Admission controllers** (enforcing security standards at admission time): covered in the pod series scheduling material
- **Pod Security Standards/Admission** (namespace-level enforcement of security baselines): may be added as a future assignment if exam coverage warrants it

## Cluster Requirements

Single-node kind cluster. No special configuration needed. Security context
enforcement is handled by the container runtime, which kind provides out of the box.

## Recommended Order

Complete pods/assignment-1 (pod spec fundamentals) and pods/assignment-2 (volume mounts,
needed for fsGroup exercises) before this assignment.
