# Pod Security

**CKA Domain:** Workloads & Scheduling (15%)
**Competencies covered:** Configure Pod admission (Pod Security Standards, Pod Security Admission controller, namespace-level enforcement of security baselines)

---

## Rationale for Number of Assignments

The Pod Security Standards (PSS) define three profiles, Privileged, Baseline, and Restricted, that describe the security posture of a pod at progressively stricter levels. The Pod Security Admission (PSA) controller is the built-in admission plugin that enforces those profiles at namespace scope using labels. The CKA curriculum added PSA to scope with the 2025 curriculum refresh. The material covers the three profile levels, the PSA modes (enforce, audit, warn), the label family under `pod-security.kubernetes.io/`, pinned versions via `-version` labels, the interaction with `securityContext` on the pod spec, diagnostic workflow for rejected or audited pods, and namespace-level exemptions. The material totals roughly 8 focused subtopics and fits a single well-scoped assignment. Splitting is unwarranted since the three profiles, the three modes, and the label family form a tight conceptual unit.

---

## Assignment Summary

| Assignment | Description | Prerequisites |
|---|---|---|
| assignment-1 | Pod Security Standards and Pod Security Admission | Three PSS profiles (Privileged, Baseline, Restricted) and what each permits, three PSA modes (enforce, audit, warn) and how to combine them, `pod-security.kubernetes.io/{enforce,audit,warn}` labels, version pinning with `-version` labels, relationship between PSA and `securityContext`, reading admission rejection messages, audit annotations visible in kube-apiserver audit events, namespace-level exemptions via the API server config | pods/assignment-1, security-contexts/assignment-1 (pod-level securityContext concepts), security-contexts/assignment-3 (readOnlyRootFilesystem, seccomp) |

## Scope Boundaries

This topic covers namespace-level security enforcement through Pod Security Admission. The following related areas are handled by other topics.

- **Pod and container `securityContext` fields** (runAsUser, capabilities, readOnlyRootFilesystem, seccomp): covered in the `security-contexts/` series
- **RBAC** (who can apply pod-security labels to namespaces, who can bypass enforcement): covered in `rbac/`
- **Admission controllers in general** (how PSA fits into the broader admission pipeline): covered in `admission-controllers/`
- **NetworkPolicy** (network-level security, distinct from pod-level security): covered in `network-policies/`

## Cluster Requirements

Single-node kind cluster is sufficient. PSA is built into kube-apiserver and enabled by default in recent Kubernetes releases. No extra controller install is needed. See `docs/cluster-setup.md#single-node-kind-cluster`.

## Recommended Order

Complete the `security-contexts/` series first so that the `securityContext` fields PSA enforces are familiar. `admission-controllers/` is a useful prerequisite for the mental model of how PSA fits in the request flow, but is not strictly required since this topic focuses on practical PSA use rather than admission mechanics in general.

---

## Current Status

Topic scoped on 2026-04-18 as part of Phase 3 of `docs/remediation-plan.md`. Content generation is tracked under Phase 4 of the remediation plan. The `prompt.md` for assignment-1 lives in this directory alongside this README.
