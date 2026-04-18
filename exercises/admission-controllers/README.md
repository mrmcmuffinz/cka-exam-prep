# Admission Controllers

**CKA Domain:** Workloads & Scheduling (15%) and Cluster Architecture (25%)
**Competencies covered:** Configure Pod admission and scheduling (admission controllers, validating and mutating), understand the request flow from authentication through authorization to admission

---

## Rationale for Number of Assignments

Admission controllers run after the API server authenticates and authorizes a request but before the object is persisted to etcd. They can mutate the incoming object (MutatingAdmissionWebhook and built-ins like DefaultStorageClass) or reject it (ValidatingAdmissionWebhook, ValidatingAdmissionPolicy, and built-ins like ResourceQuota and LimitRanger). The CKA-relevant surface covers the request flow, the common built-in admission controllers and what each enforces, the `--enable-admission-plugins` API server flag, the `ValidatingAdmissionPolicy` resource (CEL-based, graduated to GA in Kubernetes 1.30), and diagnostic patterns for admission errors. Writing custom admission webhooks is deep territory that is not practical within an exam-prep assignment. The material totals roughly 8 focused subtopics, which fits a single well-scoped assignment concentrated on built-ins and `ValidatingAdmissionPolicy` (which is the exam-relevant extension mechanism since it requires no webhook server).

---

## Assignment Summary

| Assignment | Description | Prerequisites |
|---|---|---|
| assignment-1 | Admission Controllers and ValidatingAdmissionPolicy | Request flow (authentication, authorization, admission, persistence), common built-in admission controllers (NamespaceLifecycle, LimitRanger, ResourceQuota, ServiceAccount, DefaultStorageClass, MutatingAdmissionWebhook, ValidatingAdmissionWebhook), checking enabled plugins on the API server, ValidatingAdmissionPolicy spec (validations field with CEL expressions, paramKind, matchConstraints), ValidatingAdmissionPolicyBinding (policy-to-resource binding), `warn` and `audit` enforcement actions, diagnostic workflow for admission errors (forbidden, denied, error messages in events) | pods/assignment-1 (pod fundamentals), rbac/assignment-1 (for testing with different subjects) |

## Scope Boundaries

This topic covers the admission phase of the request flow. The following related areas are handled by other topics.

- **Authentication** (who you are): covered in `tls-and-certificates/` for certificates and `rbac/assignment-1` for service account tokens
- **Authorization** (what you can do): covered in `rbac/`
- **Pod Security Admission** (a specific admission controller for pod security enforcement): covered in `pod-security/`
- **LimitRange and ResourceQuota** (admission controllers for resource constraints, enforced through the admission flow): covered in `pods/assignment-5`
- **Custom admission webhook implementation** (writing your own webhook server in Go or similar): out of CKA scope

## Cluster Requirements

Single-node kind cluster is sufficient. kind's kubeadm-provisioned API server has the default admission plugins enabled. `ValidatingAdmissionPolicy` requires Kubernetes 1.30 or later; kind v0.31.0 with `kindest/node:v1.35.0` satisfies this. See `docs/cluster-setup.md#single-node-kind-cluster`.

## Recommended Order

Complete `pods/assignment-1` for pod spec fundamentals and `rbac/assignment-1` for RBAC verification techniques before this topic. Admission controllers are best understood in the context of the full request flow, so the RBAC material (authorization phase) reinforces where admission fits in the sequence.

---

## Current Status

Topic scoped on 2026-04-18 as part of Phase 3 of `docs/remediation-plan.md`. Content generation is tracked under Phase 4 of the remediation plan. The `prompt.md` for assignment-1 lives in this directory alongside this README.
