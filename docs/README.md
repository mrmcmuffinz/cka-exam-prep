# Docs

This directory captures planning and audit material that supports the work of
improving the cka-exam-prep repository. It is intended for the repo maintainer
(and, once open-sourced, future contributors) to understand why changes are
being made and to track progress against a coherent plan.

## Files

| File | Purpose |
|---|---|
| `README.md` | This index. |
| `audit-findings.md` | Full audit of the repository across organization, usability, explainability, and CKA curriculum coverage. Captures the evidence behind each finding with file paths and line numbers. |
| `remediation-plan.md` | Phased plan for addressing the audit findings. Every task has an explicit status that is updated as work progresses. Includes the key decisions made during planning. |

## Origin

These documents were produced on 2026-04-18 as the output of an end-to-end
audit of the repository. The audit read the infrastructure files (devcontainer,
skills, reference files), all 14 topic-level READMEs, both hand-crafted series
(pods 1-7 and rbac/assignment-1) in depth, and representative assignments from
each of the 13 skill-generated topics. The conversation that produced this
plan is preserved in the two documents below in enough detail to resume work
in a later session without losing context.

## How to use this

1. Read `audit-findings.md` to understand the current state of the repository
   and the gaps that were identified.
2. Read `remediation-plan.md` to see the sequence of work and current progress.
3. When a task is started, update its status in the plan to `In progress`.
4. When a task is complete, update its status to `Complete` and (where useful)
   add a short note about how it was resolved.
5. If new issues are discovered during remediation, add them to the relevant
   section of `audit-findings.md` and extend the plan accordingly.
