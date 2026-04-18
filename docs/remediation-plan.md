# Remediation Plan

**Created:** 2026-04-18
**Last updated:** 2026-04-18 (Phase 4 in progress: 4 of ~19 assignments content-complete)
**Companion document:** `audit-findings.md`

This plan addresses the findings from the audit. Every task has an explicit
status field that should be updated as work progresses. The task IDs match
the finding IDs in `audit-findings.md` (O for organization, U for usability,
E for explainability, G for curriculum gap) so that evidence can be cross-
referenced quickly.

---

## Status key

| Status | Meaning |
|---|---|
| Not started | No work has begun. |
| In progress | Work is underway. |
| Complete | Change is merged and verified. |
| Blocked | Waiting on a decision or upstream change. |
| Deferred | Explicitly postponed. Include a note on why and when to revisit. |

---

## Key decisions

These decisions shape the plan and should be preserved for future reference.

**D1. Skill-first fix approach.**
Assignment content fixes go through the two skills (`cka-prompt-builder` and
`k8s-homework-generator`) rather than being hand-edited across many output files.
Infra-level fixes (typos, URL pins, commits, registry refreshes) can be done
directly. The `base-template.md` and `SKILL.md` files are updated first so that
regeneration produces the improved quality bar.

**D2. Gap topics become new top-level directories.**
Jobs/CronJobs, autoscaling, StatefulSets, admission controllers, and Pod Security
go into new `exercises/<topic>/` directories rather than extending existing
series. Rationale: open-sourcing benefits from clear topic boundaries, and the
existing pod series stays at its established seven assignments.

**D3. Consistent pattern across the board.**
Every assignment-level README adopts the pod/assignment-1 narrative style. Every
tutorial targets the richness of the pod/assignment-1 tutorial. Every answer key
includes a diagnostic workflow for debugging exercises and a Common Mistakes
section with three or more entries. These become hard gates in the skill.

**D4. Small-technique weaving over new assignments for cross-cutting tools.**
`kubectl debug`, `kubectl port-forward`, and scheduler profiles are added to
existing tutorials rather than given dedicated assignments. They are exam
techniques, not standalone topics.

**D5. `tmux` Dockerfile change commits as-is.**
Small, intentional, harmless. Not a priority to expand further.

**D6. Kubernetes version target is v1.35.**
Confirmed against `github.com/cncf/curriculum` (document listed as
`CKA_Curriculum_v1.35.pdf`). This drives all version pin choices for cluster
components. Component versions must support K8s 1.35 at minimum. Verification
was done against upstream project documentation (not from general knowledge).

**D7. Verification path for third-party component pins.**
When pinning any external component version, verify the version supports the
target Kubernetes version by consulting the component's official documentation
(its README, releases page, or compatibility matrix). Do not pin based on
general knowledge. If the documentation is unavailable, flag the gap rather
than guess.

**D8. Ingress and Gateway API topic restructured for 2026 reality.**
The `exercises/ingress-and-gateway-api/` topic expands from 3 assignments to 5
and adopts a controller-diversity approach. Rationale: the CKA exam allowed
documentation set as of 2026 lists `gateway-api.sigs.k8s.io/` as a dedicated
URL but has removed the NGINX Ingress Controller documentation (now CKS-only).
The Kubernetes project officially recommends Gateway API over the frozen
Ingress API. The 2026 candidate exam reports confirm migration from Ingress to
Gateway API is explicit exam content. The ingress-nginx project retires in
March 2026. The new structure gives learners exposure to multiple controllers
per API, aligning practice with the "API is universal across implementations"
lesson:

| # | API | Controller | Focus |
|---|---|---|---|
| 1 | Ingress v1 | Traefik | Ingress API fundamentals |
| 2 | Ingress v1 | HAProxy Ingress | Advanced Ingress and TLS |
| 3 | Gateway API | Envoy Gateway | Gateway API fundamentals |
| 4 | Gateway API | NGINX Gateway Fabric | Advanced Gateway API routing |
| 5 | Both | Ingress2Gateway CLI | Migration from Ingress to Gateway API |

Sources consulted: `kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/`,
`kubernetes.io/blog/2026/01/29/ingress-nginx-statement/`,
`gateway-api.sigs.k8s.io/implementations/`,
`docs.linuxfoundation.org/tc-docs/certification/certification-resources-allowed`.

---

## Phase 1: Infrastructure fixes

Direct edits; skill pipeline not involved.

| ID | Task | Status | Notes |
|---|---|---|---|
| P1.1 | Fix `pods/assignment-6/README.md` line 3: `(6 of 6)` to `(6 of 7)` (ref O2) | Complete | Fixed 2026-04-18. |
| P1.2 | Commit the `tmux` addition in `.devcontainer/Dockerfile` (ref O6) | Complete | Committed 2026-04-18 in the Phase 1 batch. |
| P1.3 | Pin `ingress-nginx/main` to a release tag in three files under `exercises/ingress-and-gateway-api/assignment-1/` (ref U3) | Complete | Initially pinned to `controller-v1.11.2`, corrected on 2026-04-18 to `controller-v1.15.1` after verifying against the ingress-nginx README (latest v1.15.x, supports K8s 1.31-1.35 per the project's compatibility table). The `deploy/static/provider/kind/deploy.yaml` path was verified to exist at that tag. |
| P1.4 | Align Calico version across three install URLs (ref U2) | Complete | Initially standardized on `v3.27.0`, corrected on 2026-04-18 to `v3.31.5` after verifying against the Calico documentation (v3.31 tested against K8s 1.32-1.35; v3.31.5 released 2026-04-15). The `manifests/calico.yaml` path was verified to exist at that tag. |
| P1.5 | Decide on `.claude/worktrees/` (ref O5) | Complete | Removed the empty untracked directory on 2026-04-18. `settings.local.json` keeps the `git worktree *` permission so the workflow is available when needed; git will recreate the directory if `git worktree add` places a worktree there. |

---

## Phase 2: Strengthen the skill assets

These edits raise the quality bar before any regeneration happens.

| ID | Task | Status | Notes |
|---|---|---|---|
| P2.1 | Update `base-template.md` to require narrative prose (with pod/assignment-1 tutorial as the canonical reference) (ref E1, E3) | Complete | 2026-04-18. Tutorial section rewritten with explicit narrative requirement and pod/assignment-1 named as reference. |
| P2.2 | Update `base-template.md` to require, for every new resource type introduced in a tutorial: spec fields, valid values, defaults, failure modes when misconfigured (ref E3) | Complete | 2026-04-18. Marked as hard gate in tutorial section and Quality Standards. |
| P2.3 | Update `base-template.md` to require answer keys for debugging exercises to have a 3-stage structure: diagnostic commands + what to look for, the bug identification, why it happens (ref E2) | Complete | 2026-04-18. Answer key section now specifies 3-stage structure as a hard gate. |
| P2.4 | Update `base-template.md` to require a "Common Mistakes" section with three or more entries per assignment (ref E5) | Complete | 2026-04-18. Required with minimum 3 entries as a hard gate. |
| P2.5 | Update `base-template.md` verification rules to mandate RBAC-style `# expect: yes/no` or specific exact output, prohibit `grep -q ... && echo SUCCESS \|\| echo FAILED` chains (ref U4) | Complete | 2026-04-18. New "Verification rules" subsection added with required forms and prohibited patterns. |
| P2.6 | Define the canonical assignment-level README shape in `base-template.md` (pick pod/assignment-1 narrative style) (ref O1, O3) | Complete | 2026-04-18. 9-section canonical shape defined in base-template.md section 1. |
| P2.7 | Update `k8s-homework-generator/SKILL.md` Quality Checks section to enforce all of the above as hard gates (ref E1-E5, U4) | Complete | 2026-04-18. Quality Checks replaced with a checklist of hard gates organized by output file. |
| P2.8 | Add a "no reading-only tasks" rule to the homework generator skill (ref U5) | Complete | 2026-04-18. New "Exercise task types" subsection added to base-template.md. |
| P2.9 | Add `docs/cluster-setup.md` with named sections (single-node, multi-node, multi-node-with-calico, multi-node-with-ingress, multi-node-with-metallb). Pin all versions there. (ref U1) | Complete | 2026-04-18. Created with all current-verified pins: kind v0.31.0, kindest/node v1.35.0, Calico v3.31.5, MetalLB v0.15.3, metrics-server v0.8.1, Gateway API v1.5.1. |
| P2.10 | Teach `k8s-homework-generator/SKILL.md` to reference `docs/cluster-setup.md` by anchor instead of inlining setup in every README (ref U1) | Complete | 2026-04-18. Environment section of base-template.md now references `docs/cluster-setup.md` anchors. |
| P2.11 | Refresh `.claude/skills/cka-prompt-builder/references/assignment-registry.md` to reflect actual completion status for all 38 existing assignments (ref O4) | Complete | 2026-04-18. Consolidated the "Completed" and "Planned" sections into a single "Assignments" section with a Status Summary noting all 38 exist; "Planned scope" renamed to "Scope". |
| P2.12 | Refresh `cka-homework-plan.md` Status Summary and Generation Sequence to reflect reality (ref O4) | Complete | 2026-04-18. Status Summary now lists 38 generated plus 7 planned (ingress expansion + new topics). Generation Sequence section marked historical. |
| P2.13 | Fix the documentation contradiction in `exercises/pods/README.md` line 36: remove the HPA/VPA claim (or update once G1 is closed) (ref O1, G1) | Complete | 2026-04-18. HPA/VPA removed from the Assignment 5 row; Scope Boundaries section updated with forward references to the planned `autoscaling/`, `jobs-and-cronjobs/`, and `statefulsets/` topics. |

---

## Phase 3: Scope and generate gap topics

Use `cka-prompt-builder` to produce topic-level READMEs and prompts, then
`k8s-homework-generator` to produce content.

| ID | Task | Status | Notes |
|---|---|---|---|
| P3.1 | Scope new topic `exercises/jobs-and-cronjobs/` (ref G2) | Not started | Decide assignment count (likely 1). |
| P3.2 | Scope new topic `exercises/autoscaling/` (ref G1) | Not started | Likely 1 or 2 assignments (HPA, VPA, in-place resize, metrics-server depth). |
| P3.3 | Scope new topic `exercises/statefulsets/` (ref G5) | Not started | Likely 1 assignment. |
| P3.4 | Scope new topic `exercises/admission-controllers/` (ref G3) | Not started | Cover validating webhooks, mutating webhooks, and `ValidatingAdmissionPolicy` (CEL). |
| P3.5 | Scope new topic `exercises/pod-security/` (ref G6) | Not started | Pod Security Standards and Pod Security Admission. |
| P3.6 | Generate all assignments for the five new topics | In progress | `jobs-and-cronjobs/assignment-1` content complete 2026-04-18. `pod-security/assignment-1` content complete 2026-04-18. `statefulsets/assignment-1` content complete 2026-04-18. `autoscaling/assignment-1` and `admission-controllers/assignment-1` pending. |
| P3.7 | Update `cka-homework-plan.md` to include the five new topics in the coverage matrix and generation sequence (ref O4) | Not started | |
| P3.8 | Update `exercises/security-contexts/README.md` line 28 and `security-contexts/assignment-2/prompt.md` line 59 and `assignment-3/prompt.md` line 65 to point forward to `exercises/pod-security/` (ref G6) | Not started | |
| P3.9 | Update `exercises/storage/README.md` line 29 to point forward to `exercises/statefulsets/` (ref G5) | Not started | |
| P3.10 | Update `exercises/ingress-and-gateway-api/README.md` to reflect the 5-assignment multi-controller structure per D8 | Not started | Topic README produced by `cka-prompt-builder`. |
| P3.11 | Update `exercises/ingress-and-gateway-api/assignment-1/prompt.md` to specify Traefik, Ingress API fundamentals | Not started | |
| P3.12 | Update `exercises/ingress-and-gateway-api/assignment-2/prompt.md` to specify HAProxy Ingress, advanced Ingress + TLS | Not started | |
| P3.13 | Update `exercises/ingress-and-gateway-api/assignment-3/prompt.md` to specify Envoy Gateway, Gateway API fundamentals (rename from "Gateway API" to reflect fundamentals scope) | Not started | |
| P3.14 | Create `exercises/ingress-and-gateway-api/assignment-4/prompt.md` for NGINX Gateway Fabric, advanced Gateway API routing | Not started | New assignment directory. |
| P3.15 | Create `exercises/ingress-and-gateway-api/assignment-5/prompt.md` for Ingress2Gateway migration | Not started | New assignment directory. |

---

## Phase 4: Regenerate thin existing assignments

With the improved skill in place, rerun the generator on the assignments that most
under-deliver against the quality bar.

| ID | Task | Status | Notes |
|---|---|---|---|
| P4.1 | Regenerate `rbac/assignment-2` (tutorial thin; README stub) (ref E1, E4) | Complete | 2026-04-18. Regenerated all four content files under the Phase 2 hard gates. README uses the 9-section canonical shape; tutorial is narrative with per-field spec documentation (valid values, defaults, failure modes) for ClusterRole, ClusterRoleBinding, aggregationRule, subjects, roleRef, and nonResourceURLs; homework has 15 build-or-fix exercises with RBAC-style `# expect: yes/no` verification; answers use the three-stage structure for all Level 3 and Level 5 debugging exercises and include a Common Mistakes section with 8 entries. RBAC API facts verified against `kubernetes.io/docs/reference/access-authn-authz/rbac/` (raw markdown fetched from `github.com/kubernetes/website`). |
| P4.2 | Regenerate `security-contexts/assignment-1`, `-2`, `-3` (tutorials thin) (ref E1, E3) | Not started | |
| P4.3 | Regenerate `storage/assignment-1`, `-2`, `-3` (answer keys duplicate YAML; tutorials thin) (ref E1, U7) | Not started | |
| P4.4 | Regenerate `troubleshooting/assignment-2` (README stub) (ref E4) | Not started | |
| P4.5 | Regenerate `troubleshooting/assignment-4` (README stub) (ref E4) | Not started | |
| P4.6 | Regenerate `cluster-lifecycle/assignment-1` homework to replace reading-only exercises with build-or-fix tasks (ref U5, U8) | Not started | Acknowledge kind's kubeadm abstraction in the topic README explicitly. |
| P4.7 | Regenerate `crds-and-operators/assignment-1` Level 1 exercises to remove trivially-easy tasks (ref U5) | Not started | |
| P4.8 | Regenerate `troubleshooting/assignment-1` Exercise 1.2 with a single clear failure at Level 1 (ref U6) | Not started | Move the dual-failure scenario to Level 4 or 5 if retained. |
| P4.9 | Regenerate `ingress-and-gateway-api/assignment-1` content files for Traefik | Not started | Existing `controller-v1.15.1` pin becomes obsolete here. Depends on P3.11. |
| P4.10 | Regenerate `ingress-and-gateway-api/assignment-2` content files for HAProxy Ingress | Not started | Depends on P3.12. |
| P4.11 | Regenerate `ingress-and-gateway-api/assignment-3` content files for Envoy Gateway | Not started | Depends on P3.13. |
| P4.12 | Generate `ingress-and-gateway-api/assignment-4` content files for NGINX Gateway Fabric | Not started | Depends on P3.14. |
| P4.13 | Generate `ingress-and-gateway-api/assignment-5` content files for Ingress2Gateway migration | Not started | Depends on P3.15. |

---

## Phase 5: Technique weaving into existing tutorials

Small updates to existing files rather than new assignments.

| ID | Task | Status | Notes |
|---|---|---|---|
| P5.1 | Add `kubectl debug` coverage to `troubleshooting/assignment-1/troubleshooting-tutorial.md` and `/assignment-3/troubleshooting-tutorial.md` (ref G4) | Not started | Cover `kubectl debug pod/X --image=...` and `kubectl debug node/Y -it --image=...`. |
| P5.2 | Add `kubectl port-forward` as a connectivity-test technique to `services/assignment-1/services-tutorial.md` (ref G7) | Not started | |
| P5.3 | Add scheduler-profile and multiple-schedulers material to `pods/assignment-4/pod-scheduling-tutorial.md` (ref G8) | Not started | Alternatively, acknowledge it as a known thin area if out of scope. |

---

## Phase 6: Verification and housekeeping

After all content work is done, verify consistency and update supporting material.

| ID | Task | Status | Notes |
|---|---|---|---|
| P6.1 | Grep for `6 of 6` and similar series counters across all READMEs to confirm no lingering bugs (ref O2) | Not started | |
| P6.2 | Verify every cross-reference (`exercises/X/assignment-Y`) points to a real path (ref E7) | Not started | Quick script over all .md files. |
| P6.3 | Audit final assignment-level READMEs for the canonical shape defined in P2.6 (ref O1) | Not started | |
| P6.4 | Audit final tutorial files against the E3 standard (every new resource has fields, valid values, defaults, failure modes) (ref E3) | Not started | |
| P6.5 | Audit final answer keys against the P2.3 structure (ref E2) | Not started | |
| P6.6 | Update the `cka-homework-plan.md` coverage matrix to include the five new topics and reflect final assignment counts (ref O4) | Not started | |
| P6.7 | Update `docs/audit-findings.md` to reflect resolved findings (strike through or mark resolved with date) | Not started | |

---

## Progress log

Record notable progress events here with date. Keep entries short.

| Date | Event |
|---|---|
| 2026-04-18 | Audit and plan produced. All tasks at "Not started". |
| 2026-04-18 | Phase 1 complete (P1.1-P1.5). Infrastructure fixes applied: typo corrected, tmux commit made, `ingress-nginx` pinned to `controller-v1.11.2`, Calico standardized at `v3.27.0`, empty `.claude/worktrees/` removed. |
| 2026-04-18 | Version pins corrected after verifying against upstream documentation. K8s 1.35 is the exam target (confirmed by `CKA_Curriculum_v1.35.pdf` in github.com/cncf/curriculum). `ingress-nginx` re-pinned to `controller-v1.15.1`, Calico re-pinned to `v3.31.5`, `cka-curriculum.md` reference file updated from "v1.34+" to "v1.35". |
| 2026-04-18 | Ingress topic restructured to 5 assignments with controller diversity per D8. Research confirmed CKA exam allowed docs include `gateway-api.sigs.k8s.io/` but dropped the NGINX Ingress Controller URL (now CKS-only). `cka-curriculum.md` Domain 3 entries for Gateway API and Ingress updated to reflect the 2026 reality (retirement, migration tool, Gateway-API-first recommendation, conformant implementations list). Plan tasks P3.10-P3.15 and P4.9-P4.13 added. |
| 2026-04-18 | Phase 2 complete (P2.1-P2.13). `base-template.md` and `k8s-homework-generator/SKILL.md` rewritten with hard gates: canonical 9-section README shape, narrative prose requirement, resource field documentation, debugging 3-stage answer structure, Common Mistakes with 3+ entries, RBAC-style verification, prohibition of reading-only tasks and fragile pipes. `docs/cluster-setup.md` created as single source of truth for cluster recipes with all pins verified against upstream (kind v0.31.0, kindest/node v1.35.0, Calico v3.31.5, MetalLB v0.15.3, metrics-server v0.8.1, Gateway API v1.5.1). MetalLB pin updated in services/1 and /2 from v0.13.12 to v0.15.3; metrics-server pin in troubleshooting/1 changed from `releases/latest` to `v0.8.1`. `assignment-registry.md` and `cka-homework-plan.md` refreshed to reflect current state. `pods/README.md` HPA/VPA contradiction fixed. Ready for Phase 3 scoping of new topics. |
| 2026-04-18 | Phase 3 complete (P3.1-P3.5, P3.7-P3.15; P3.6 content generation consolidated into Phase 4). Five new topic READMEs and assignment-1 prompts produced for the gap topics: `jobs-and-cronjobs/` (1 assignment), `autoscaling/` (1 assignment covering HPA v2, in-place pod resize, VPA concepts, metrics-server), `statefulsets/` (1 assignment), `admission-controllers/` (1 assignment covering built-ins plus ValidatingAdmissionPolicy CEL), `pod-security/` (1 assignment covering PSS and PSA). Ingress-and-gateway-api restructured from 3 to 5 assignments with verified per-assignment controller pins: Traefik v3.6.13 (assignment-1), HAProxy Ingress v3.2.6 (assignment-2), Envoy Gateway v1.7.2 (assignment-3), NGINX Gateway Fabric v2.5.1 (assignment-4), Ingress2Gateway CLI v1.0.0 (assignment-5). Forward references updated in security-contexts and storage READMEs and prompts. Coverage matrix in `cka-homework-plan.md` updated. Ten prompts in place ready for Phase 4 content generation: 5 new-topic prompts and 5 ingress prompts (3 updated, 2 new). |
| 2026-04-18 | Documentation sync. `docs/audit-findings.md` extended with per-finding resolution status lines (Resolved, Partially resolved, Pending) citing the phase or commit that addresses each finding. `docs/README.md` extended with `cluster-setup.md` entry and a phase-completion dashboard. Main `README.md` coverage matrix updated to include the five new topics and the ingress expansion; Repository Layout rewritten with accurate paths (`.claude/skills/` instead of `skills/`) and current topic content state. `CLAUDE.md` updated to reference `.claude/skills/`, note the v1.35 exam target, describe docs directory, reflect content-complete vs content-pending state, and replace the stale Generation Sequence narrative with a pointer to `docs/remediation-plan.md`. |
| 2026-04-18 | Phase 4 started. `jobs-and-cronjobs/assignment-1` content generated (README, tutorial, homework, answers) as the first full assignment under the new quality gates. Job and CronJob API facts verified against `kubernetes.io/docs` (backoffLimit default 6, successfulJobsHistoryLimit default 3, failedJobsHistoryLimit default 1, restartPolicy must be OnFailure or Never, timeZone stable since 1.27). Applies the canonical 9-section README shape, narrative tutorial prose with per-field documentation including defaults and failure modes, RBAC-style verification, three-stage debugging answer structure, and Common Mistakes with six entries. Ready as a reference quality bar for remaining Phase 4 assignments. |
| 2026-04-18 | `pod-security/assignment-1` content generated (README, tutorial, homework, answers) closing curriculum gap G6. Pod Security Standards (Privileged, Baseline, Restricted) and Pod Security Admission (enforce, audit, warn modes; label family; version pinning) verified against `kubernetes.io/docs/concepts/security/pod-security-admission/` and `kubernetes.io/docs/concepts/security/pod-security-standards/`. Tutorial explicitly demonstrates the enforce-only-applies-to-pods gotcha (Deployment accepted but pods rejected by ReplicaSet). Homework Level 5 Exercise 5.3 uses the `runAsNonRoot: true` + `runAsUser: 0` contradiction as the subtle-bug debug scenario. Reference implementation of the new quality gates on an admission-controller-style topic (different shape from the workload-controller topic in jobs-and-cronjobs). |
| 2026-04-18 | Session handoff artifacts added. `docs/session-handoff.md` documents the resume workflow (essential reading order, priority queue for remaining Phase 4 work, model and context recommendations, pre-commit checklist). `docs/next-session-prompt.md` contains a copy-paste-ready prompt to start a new Claude Code session, with a "Current state" block that the next session must update after each completed assignment. `CLAUDE.md` and `README.md` directory-structure blocks updated so `jobs-and-cronjobs/1` and `pod-security/1` are tagged "content complete" rather than "content pending." Two full Phase 4 assignments content-complete; approximately 17 remain. |
| 2026-04-18 | `rbac/assignment-2` (cluster-scoped RBAC) regenerated under the new quality gates, closing P4.1 and partially addressing E1 (tutorial thin) and E4 (README stub). Tutorial walks through ClusterRole creation and binding cluster-wide, the ClusterRole-plus-RoleBinding pattern for namespace-scoped reuse, non-resource URLs with scope gotcha, aggregation semantics (`rbac.authorization.k8s.io/aggregate-to-*`), default user-facing ClusterRoles with security caveats around `edit` and Secrets, privilege-escalation prevention via the `bind` and `escalate` verbs, and ServiceAccount subjects at cluster scope. Homework exercises include three realistic silent-failure debug scenarios (wrong API group for `storageclasses`; RoleBinding where ClusterRoleBinding was needed for Nodes; non-resource URL rule bound via RoleBinding) plus a three-bug Level 5 scenario (`apiGroups: ["rbac"]`, `resources: ["node"]`, `kind: user`). Answers include full three-stage debugging structure and an 8-entry Common Mistakes section covering cluster-scoped-specific failure modes. Three Phase 4 assignments content-complete; approximately 16 remain. |
| 2026-04-18 | `statefulsets/assignment-1` content generated (README, tutorial, homework, answers), closing curriculum gap G5 and partially addressing P3.6. StatefulSet API facts verified against `kubernetes.io/docs/concepts/workloads/controllers/statefulset.md` (raw markdown fetched from `github.com/kubernetes/website`). Key verified items: `apiVersion: apps/v1`, headless Service requirement (`clusterIP: None`) with the silent-failure mode when omitted or when `serviceName` mismatches, `spec.serviceName` immutability, `volumeClaimTemplates` immutability, PVC naming `<claim>-<sts>-<ordinal>`, `podManagementPolicy` (OrderedReady default vs Parallel), `updateStrategy.rollingUpdate.partition` for staged rollouts, `updateStrategy.rollingUpdate.maxUnavailable` Beta and default-enabled in v1.35 (per the feature-gates table), `OnDelete` strategy, `persistentVolumeClaimRetentionPolicy` behind the `StatefulSetAutoDeletePVC` feature gate with `Retain`/`Retain` defaults, ControllerRevision-backed rollback, and the "Forced rollback" recovery pattern for stuck `OrderedReady` rollouts. Homework includes three realistic silent-failure debug scenarios (non-existent StorageClass; Service not headless; `serviceName` mismatch), a multi-bug Level 5 scenario combining all three, and a canary-plus-rollback Level 5 scenario. Four Phase 4 assignments content-complete; approximately 15 remain. |
