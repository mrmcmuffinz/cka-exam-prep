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
| `session-handoff.md` | How to resume work across Claude Code sessions: current status, next-task priority, model and context-size recommendations, reference quality bar, workflow guidance for audit tasks. |
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

As of 2026-04-19:

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
- **Phase 4 (Content generation and regeneration):** Complete as of 2026-04-18. All 19 full-assignment regens are content-complete: `jobs-and-cronjobs/1`, `pod-security/1`, `rbac/2`, `statefulsets/1`, `troubleshooting/2`, `autoscaling/1`, `admission-controllers/1`, `troubleshooting/4`, `security-contexts/1-3`, `storage/1-3`, `ingress-and-gateway-api/1-5`. Three surgical regens complete (P4.6 cluster-lifecycle/1 homework, P4.7 crds-and-operators/1 Level 1, P4.8 troubleshooting/1 Exercise 1.2). All five new-topic curriculum gaps (G1, G2, G3, G5, G6) resolved. All stub READMEs regenerated. U7 duplicated-YAML finding resolved in storage/1-3. Ingress series fully converted to the D8 controller-diversity structure (Traefik, HAProxy Ingress, Envoy Gateway, NGINX Gateway Fabric, Ingress2Gateway CLI).
- **Phase 5 (Technique weaving):** Complete as of 2026-04-19. `kubectl debug` (ephemeral containers and node debugging) weaved into `troubleshooting/assignment-1` and `/assignment-3`. `kubectl port-forward` weaved into `services/assignment-1`. Scheduler profiles and multiple schedulers acknowledged in `pods/assignment-4`. Curriculum gaps G4, G7, G8 resolved.
- **Phase 6 (Verification and housekeeping):** Not started. Seven audit tasks for final consistency.

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
