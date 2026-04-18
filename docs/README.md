# Docs

This directory captures planning and audit material that supports the work of
improving the cka-exam-prep repository. It is intended for the repo maintainer
(and, once open-sourced, future contributors) to understand why changes are
being made and to track progress against a coherent plan.

## Files

| File | Purpose |
|---|---|
| `README.md` | This index. |
| `audit-findings.md` | Full audit of the repository across organization, usability, explainability, and CKA curriculum coverage. Each finding has a status line showing whether it is resolved, partially resolved, or pending. |
| `remediation-plan.md` | Phased plan for addressing the audit findings. Every task has an explicit status that is updated as work progresses. Includes the key decisions made during planning and a progress log. |
| `cluster-setup.md` | Single source of truth for kind cluster configurations and the component version matrix. Every assignment README and tutorial references sections of this document by anchor rather than inlining cluster commands. |
| `session-handoff.md` | How to continue Phase 4 content generation across Claude Code sessions: current status, next-task priority, model and context-size recommendations, reference quality bar, pre-commit checklist. |
| `next-session-prompt.md` | A ready-to-use prompt to start a new Claude Code session. Copy the block between the marker lines and paste as the first message in a fresh session. Update the "Current state" block after each completed assignment. |

## Origin

These documents were produced on 2026-04-18 as the output of an end-to-end
audit of the repository. The audit read the infrastructure files (devcontainer,
skills, reference files), all 14 topic-level READMEs, both hand-crafted series
(pods 1-7 and rbac/assignment-1) in depth, and representative assignments from
each of the 13 skill-generated topics. The conversation that produced this
plan is preserved in the documents above in enough detail to resume work
in a later session without losing context.

## Phase completion status

As of 2026-04-18:

- **Phase 1 (Infrastructure fixes):** Complete.
- **Phase 2 (Skill asset strengthening):** Complete. `base-template.md` and
  `k8s-homework-generator/SKILL.md` now enforce hard gates for README shape,
  narrative prose, resource documentation, debugging answer structure, Common
  Mistakes, verification rigor, and no reading-only tasks.
- **Phase 3 (Scope new topics and expand ingress):** Complete. Five new topic
  READMEs plus one prompt each are in place for `jobs-and-cronjobs/`,
  `autoscaling/`, `statefulsets/`, `admission-controllers/`, and
  `pod-security/`. The `ingress-and-gateway-api/` topic is restructured from
  three to five assignments.
- **Phase 4 (Content generation and regeneration):** In progress. Eight full assignments content-complete (`jobs-and-cronjobs/assignment-1`, `pod-security/assignment-1`, `rbac/assignment-2`, `statefulsets/assignment-1`, `troubleshooting/assignment-2`, `autoscaling/assignment-1`, `admission-controllers/assignment-1`, `troubleshooting/assignment-4`). Three surgical regens complete (P4.6 cluster-lifecycle/assignment-1 homework, P4.7 crds-and-operators/assignment-1 Level 1, P4.8 troubleshooting/assignment-1 Exercise 1.2). All five new-topic curriculum gaps (G1, G2, G3, G5, G6) resolved; all stub READMEs (P4.1, P4.4, P4.5) regenerated. Remaining Phase 4 work: thin regens for `security-contexts/` (P4.2; three assignments) and `storage/` (P4.3; three assignments), plus the ingress controller swap (P4.9 through P4.13; five assignments). See `session-handoff.md` for the priority queue and resume instructions.
- **Phase 5 (Technique weaving):** Not started.
- **Phase 6 (Verification and housekeeping):** Not started.

See `remediation-plan.md` for task-level detail.

## How to use this

1. Read `audit-findings.md` to understand the current state of the repository
   and the gaps that were identified.
2. Read `remediation-plan.md` to see the sequence of work and current progress.
3. When a task is started, update its status in the plan to `In progress`.
4. When a task is complete, update its status to `Complete` and (where useful)
   add a short note about how it was resolved.
5. If new issues are discovered during remediation, add them to the relevant
   section of `audit-findings.md` and extend the plan accordingly.
