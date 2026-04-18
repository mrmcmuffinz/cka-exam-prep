# Remediation Plan

**Created:** 2026-04-18
**Last updated:** 2026-04-18 (Phase 1 complete)
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

---

## Phase 1: Infrastructure fixes

Direct edits; skill pipeline not involved.

| ID | Task | Status | Notes |
|---|---|---|---|
| P1.1 | Fix `pods/assignment-6/README.md` line 3: `(6 of 6)` to `(6 of 7)` (ref O2) | Complete | Fixed 2026-04-18. |
| P1.2 | Commit the `tmux` addition in `.devcontainer/Dockerfile` (ref O6) | Complete | Committed 2026-04-18 in the Phase 1 batch. |
| P1.3 | Pin `ingress-nginx/main` to a release tag in three files under `exercises/ingress-and-gateway-api/assignment-1/` (ref U3) | Complete | Pinned to `controller-v1.11.2` across README, tutorial, and answer key on 2026-04-18. |
| P1.4 | Align Calico version across six files (ref U2) | Complete | Only three install URLs existed (confirmed by grep). Standardized on `v3.27.0` by updating `troubleshooting/assignment-4/README.md`. |
| P1.5 | Decide on `.claude/worktrees/` (ref O5) | Complete | Removed the empty untracked directory on 2026-04-18. `settings.local.json` keeps the `git worktree *` permission so the workflow is available when needed; git will recreate the directory if `git worktree add` places a worktree there. |

---

## Phase 2: Strengthen the skill assets

These edits raise the quality bar before any regeneration happens.

| ID | Task | Status | Notes |
|---|---|---|---|
| P2.1 | Update `base-template.md` to require narrative prose (with pod/assignment-1 tutorial as the canonical reference) (ref E1, E3) | Not started | Quote specific passages from pods/assignment-1 as style exemplars. |
| P2.2 | Update `base-template.md` to require, for every new resource type introduced in a tutorial: spec fields, valid values, defaults, failure modes when misconfigured (ref E3) | Not started | Make this a hard gate in the skill quality checks. |
| P2.3 | Update `base-template.md` to require answer keys for debugging exercises to have a 3-stage structure: diagnostic commands + what to look for, the bug identification, why it happens (ref E2) | Not started | Reference pod/assignment-1 answers as the exemplar. |
| P2.4 | Update `base-template.md` to require a "Common Mistakes" section with three or more entries per assignment (ref E5) | Not started | |
| P2.5 | Update `base-template.md` verification rules to mandate RBAC-style `# expect: yes/no` or specific exact output, prohibit `grep -q ... && echo SUCCESS \|\| echo FAILED` chains (ref U4) | Not started | |
| P2.6 | Define the canonical assignment-level README shape in `base-template.md` (pick pod/assignment-1 narrative style) (ref O1, O3) | Not started | Document a single template with a Files table, Recommended Workflow, Difficulty Progression, Prerequisites, Cluster Requirements, Estimated Time, and a series-position line. |
| P2.7 | Update `k8s-homework-generator/SKILL.md` Quality Checks section to enforce all of the above as hard gates (ref E1-E5, U4) | Not started | |
| P2.8 | Add a "no reading-only tasks" rule to the homework generator skill (ref U5) | Not started | Explicitly prohibit "document your findings" and "list and describe" as exercise task descriptions. |
| P2.9 | Add `docs/cluster-setup.md` with named sections (single-node, multi-node, multi-node-with-calico, multi-node-with-ingress, multi-node-with-metallb). Pin all versions there. (ref U1) | Not started | Assignment READMEs reference this document by anchor rather than inlining setup. |
| P2.10 | Teach `k8s-homework-generator/SKILL.md` to reference `docs/cluster-setup.md` by anchor instead of inlining setup in every README (ref U1) | Not started | |
| P2.11 | Refresh `.claude/skills/cka-prompt-builder/references/assignment-registry.md` to reflect actual completion status for all 40 existing assignments (ref O4) | Not started | Strip generation-order fields that no longer matter; keep scope summary and cross-refs. |
| P2.12 | Refresh `cka-homework-plan.md` Status Summary and Generation Sequence to reflect reality (ref O4) | Not started | The Generation Sequence table is historical at this point. |
| P2.13 | Fix the documentation contradiction in `exercises/pods/README.md` line 36: remove the HPA/VPA claim (or update once G1 is closed) (ref O1, G1) | Not started | |

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
| P3.6 | Generate all assignments for the five new topics | Not started | Depends on P3.1-P3.5 and Phase 2 completion. |
| P3.7 | Update `cka-homework-plan.md` to include the five new topics in the coverage matrix and generation sequence (ref O4) | Not started | |
| P3.8 | Update `exercises/security-contexts/README.md` line 28 and `security-contexts/assignment-2/prompt.md` line 59 and `assignment-3/prompt.md` line 65 to point forward to `exercises/pod-security/` (ref G6) | Not started | |
| P3.9 | Update `exercises/storage/README.md` line 29 to point forward to `exercises/statefulsets/` (ref G5) | Not started | |

---

## Phase 4: Regenerate thin existing assignments

With the improved skill in place, rerun the generator on the assignments that most
under-deliver against the quality bar.

| ID | Task | Status | Notes |
|---|---|---|---|
| P4.1 | Regenerate `rbac/assignment-2` (tutorial thin; README stub) (ref E1, E4) | Not started | |
| P4.2 | Regenerate `security-contexts/assignment-1`, `-2`, `-3` (tutorials thin) (ref E1, E3) | Not started | |
| P4.3 | Regenerate `storage/assignment-1`, `-2`, `-3` (answer keys duplicate YAML; tutorials thin) (ref E1, U7) | Not started | |
| P4.4 | Regenerate `troubleshooting/assignment-2` (README stub) (ref E4) | Not started | |
| P4.5 | Regenerate `troubleshooting/assignment-4` (README stub) (ref E4) | Not started | |
| P4.6 | Regenerate `cluster-lifecycle/assignment-1` homework to replace reading-only exercises with build-or-fix tasks (ref U5, U8) | Not started | Acknowledge kind's kubeadm abstraction in the topic README explicitly. |
| P4.7 | Regenerate `crds-and-operators/assignment-1` Level 1 exercises to remove trivially-easy tasks (ref U5) | Not started | |
| P4.8 | Regenerate `troubleshooting/assignment-1` Exercise 1.2 with a single clear failure at Level 1 (ref U6) | Not started | Move the dual-failure scenario to Level 4 or 5 if retained. |

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
