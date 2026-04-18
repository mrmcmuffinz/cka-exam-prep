# Session Handoff Guide

This document explains how to continue the remediation work across Claude Code sessions. It is intended for the repo maintainer (Abe) or any future assistant resuming Phase 4 content generation.

**Last updated:** 2026-04-18 (after Phase 4 assignments 1-7 of ~19 complete)

---

## Current state

As of 2026-04-18:

| Phase | Status | Notes |
|---|---|---|
| 1. Infrastructure fixes | Complete | typo, version pins, worktree dir, tmux commit |
| 2. Skill asset strengthening | Complete | base-template.md, SKILL.md, cluster-setup.md, registry refresh |
| 3. Topic scoping | Complete | 5 new topic READMEs + prompts; ingress restructured to 5 assignments with updated prompts |
| 4. Content generation | In progress | 7 of ~19 assignments done: `jobs-and-cronjobs/assignment-1`, `pod-security/assignment-1`, `rbac/assignment-2`, `statefulsets/assignment-1`, `troubleshooting/assignment-2`, `autoscaling/assignment-1`, `admission-controllers/assignment-1` |
| 5. Technique weaving | Not started | kubectl debug, port-forward, scheduler profiles |
| 6. Verification and housekeeping | Not started | cross-reference audit, final consistency sweep |

---

## How to resume in a new session

### Step 1: Read these documents in order

1. `docs/README.md` — orientation and phase status
2. `docs/remediation-plan.md` — current task-level status; progress log shows what was done and when
3. `docs/audit-findings.md` — per-finding resolution status
4. `docs/cluster-setup.md` — single source of truth for cluster recipes and version matrix
5. `CLAUDE.md` — project context for Claude Code
6. `.claude/skills/k8s-homework-generator/references/base-template.md` — content quality gates
7. `.claude/skills/cka-prompt-builder/references/cka-curriculum.md` — current CKA exam context

### Step 2: Identify the next task

Look at `docs/remediation-plan.md` Phase 4. Tasks that are `Not started` are ready. The current completed and priority queue looks like:

**Complete as of 2026-04-18:**
- P3.6 fully: all five new-topic assignments content complete
- P4.1: `rbac/assignment-2` content
- P4.4: `troubleshooting/assignment-2` content

**Recommended next-up priority order (any can be done independently):**

1. **Stub-to-full regenerations** (highest visual impact per assignment)
   - `troubleshooting/assignment-4` (P4.5; last stub)

2. **Surgical fixes** (cheap, high value)
   - `troubleshooting/assignment-1` Exercise 1.2 single-exercise fix (P4.8)
   - `crds-and-operators/assignment-1` Level 1 only (P4.7)
   - `cluster-lifecycle/assignment-1` homework only (P4.6)

3. **Thin regenerations** (quality uplift)
   - `security-contexts/assignment-1`, `-2`, `-3` (P4.2)
   - `storage/assignment-1`, `-2`, `-3` (P4.3)

4. **Ingress controller swap** (P4.9 through P4.13; largest per-assignment)

3. **Regenerate thin existing** (quality uplift; existing content works but does not meet new gates)
   - `security-contexts/assignment-1,2,3` (P4.2)
   - `storage/assignment-1,2,3` (P4.3)
   - `cluster-lifecycle/assignment-1` homework only (P4.6)
   - `crds-and-operators/assignment-1` Level 1 only (P4.7)
   - `troubleshooting/assignment-1` Exercise 1.2 only (P4.8)

4. **Ingress controller swap** (largest per-assignment; new controllers per D8)
   - `ingress-and-gateway-api/assignment-1` with Traefik (P4.9)
   - `ingress-and-gateway-api/assignment-2` with HAProxy Ingress (P4.10)
   - `ingress-and-gateway-api/assignment-3` with Envoy Gateway (P4.11)
   - `ingress-and-gateway-api/assignment-4` with NGINX Gateway Fabric (P4.12)
   - `ingress-and-gateway-api/assignment-5` with Ingress2Gateway migration (P4.13)

### Step 3: Follow the generation workflow

For each Phase 4 content task:

1. Read the assignment's `prompt.md` (already in place from Phase 3 or pre-existing).
2. Verify any external component version used by the assignment against upstream documentation (per decision D7). Do not trust general knowledge.
3. Write the four content files (`README.md`, `<topic>-tutorial.md`, `<topic>-homework.md`, `<topic>-homework-answers.md`) matching the canonical shape and hard gates in `base-template.md`.
4. Use `jobs-and-cronjobs/assignment-1` or `pod-security/assignment-1` as the reference quality bar.
5. Update `docs/remediation-plan.md`: mark the task Complete with date; add a progress-log entry.
6. Commit with a clear message.

### Step 4: Keep documentation synchronized as you go

Do not defer doc updates to the end. In the same commit as each content-generation task, update:

- `docs/remediation-plan.md` — task status and progress log
- `docs/audit-findings.md` — any finding whose status now changes (for example, E1 moves from "Partially resolved" closer to "Resolved" as more regenerations complete)
- `cka-homework-plan.md` — only if the high-level status summary changes
- `.claude/skills/cka-prompt-builder/references/assignment-registry.md` — only if the scope summary of an assignment needs updating

---

## Model and context recommendations

### Recommended setup

**For full content generation** (one complete assignment per session, four files of substantial depth):

- **Model:** Claude Opus 4.7 (`claude-opus-4-7`) with the 1M context variant (`claude-opus-4-7[1m]`)
- **Context usage per assignment:** roughly 14% of a 1M context window
- **Assignments per session:** 2 is comfortable, 3 is possible but leaves little room for course correction

The 1M context variant is the right call because a good content assignment runs 2,000 to 3,000 lines across the four files, plus you need to keep the prompt, base template, and reference quality-bar example in context while writing. The 200k-token variant is too small for this.

**For smaller targeted fixes** (regenerate a single homework section, fix a Level 1 in an existing assignment):

- **Model:** Claude Sonnet 4.6 (`claude-sonnet-4-6`) with the 200k context is sufficient
- **Fixes per session:** several small fixes fit comfortably in 200k context

Use Sonnet 4.6 for Phase 5 technique-weaving (`kubectl debug`, `kubectl port-forward`, scheduler profiles) since those are small additions to existing tutorials. Use Opus 4.7 1M for net-new assignments and full regenerations.

### Context budgeting rule of thumb

In my experience generating the two completed Phase 4 assignments today:

- Reading the prompt, base-template, and an existing assignment as quality-bar reference: ~5-8% of 1M context
- Web-fetching upstream docs for API verification: ~3-5%
- Writing four content files: ~10-14%
- Documentation updates and commit preparation: ~1-2%
- **Total per full assignment: 20-30% of 1M context**

Starting fresh, you can plan for 3 full assignments per session. Starting part-way through a context, reduce accordingly.

### When to start a fresh session

Start a new session when:

- Remaining context budget is below about 20% of a full 1M window
- You have just committed work and the next task is independent
- The handoff point is natural (all artifacts committed, plan updated, no dangling state)

Do not push through context exhaustion; the quality of later work degrades and mistakes become harder to catch. Err on the side of committing cleanly and starting fresh.

---

## Reference quality bar

When generating new Phase 4 content, read one of the completed reference assignments first so the style is fresh in context. Both of these demonstrate the full set of Phase 2 hard gates:

- `exercises/pods/assignment-1/` — the hand-crafted original; the narrative bar for tutorials
- `exercises/rbac/assignment-1/` — hand-crafted; the narrative bar for RBAC and subject-oriented topics
- `exercises/jobs-and-cronjobs/assignment-1/` — skill-generated under the new hard gates; workload-controller topic
- `exercises/pod-security/assignment-1/` — skill-generated under the new hard gates; admission-style topic
- `exercises/rbac/assignment-2/` — skill-generated under the new hard gates; cluster-scoped authorization topic; demonstrates the three-stage debugging structure on silent-failure RBAC bugs
- `exercises/statefulsets/assignment-1/` — skill-generated under the new hard gates; workload-controller topic with rich tutorial narrative on scope-matrix failures and staged rollouts
- `exercises/troubleshooting/assignment-2/` — skill-generated under the new hard gates; all-debug troubleshooting topic with kind-specific inside-the-node workflows, the canonical reference for a "15 debug exercises" shape
- `exercises/autoscaling/assignment-1/` — skill-generated under the new hard gates; mixes build, debug, and design exercises around a controller that depends on a live observable signal (metrics-server)

Pick whichever is most shape-adjacent to the assignment being generated. For ingress assignments, read a networking-style reference. For RBAC-style authorization or admission topics, `rbac/assignment-2` is the current Phase 4 exemplar. For workload-controller topics, `jobs-and-cronjobs/assignment-1` and `statefulsets/assignment-1` are the nearest shape. For autoscaling or other controller topics depending on metrics-server, `autoscaling/assignment-1` is the reference. For troubleshooting-heavy topics (troubleshooting/assignment-4, any future all-debug assignment), `troubleshooting/assignment-2` is the shape.

---

## Checklist before committing a Phase 4 assignment

Tick every item before marking a task Complete.

**File presence:**
- [ ] `README.md` exists and follows the 9-section canonical shape
- [ ] `<topic>-tutorial.md` exists and uses narrative paragraph flow
- [ ] `<topic>-homework.md` exists with exactly 15 exercises (3 per level, 5 levels)
- [ ] `<topic>-homework-answers.md` exists with a solution per exercise
- [ ] `prompt.md` still exists (input, do not delete)

**README gates:**
- [ ] References `docs/cluster-setup.md` by anchor, does not inline cluster commands
- [ ] Narrative prose, no metadata header block

**Tutorial gates:**
- [ ] Every new resource type has spec fields, valid values, defaults, and failure modes documented
- [ ] Imperative and declarative forms shown where both apply

**Homework gates:**
- [ ] Every exercise is a build-or-fix task (no reading-only tasks)
- [ ] Debugging exercises have bare headings (`### Exercise 3.1`, not `### Exercise 3.1: The PVC Binding Bug`)
- [ ] Verification uses `# Expected:` comments with specific values (RBAC style)
- [ ] No `grep -q ... && echo SUCCESS` pipelines
- [ ] No `timeout ... || echo BLOCKED` denial tests
- [ ] Each exercise uses a unique `ex-<level>-<exercise>` namespace

**Answer key gates:**
- [ ] Every Level 3 and Level 5 debugging answer has the three-stage structure: Diagnosis, What the bug is and why, Fix
- [ ] Common Mistakes section has three or more topic-specific entries
- [ ] No duplicated YAML (display block + heredoc of the same config)
- [ ] Verification Commands Cheat Sheet present

**External pins:**
- [ ] Every external component version used in the assignment was verified against upstream documentation during the session (not relied on from general knowledge)
- [ ] If the assignment introduced a new pinned component, `docs/cluster-setup.md` version matrix was updated

**Documentation sync:**
- [ ] `docs/remediation-plan.md` task status updated to Complete with date
- [ ] `docs/remediation-plan.md` progress log has a new entry for this assignment
- [ ] If the assignment closes or partially resolves an audit finding, `docs/audit-findings.md` status was updated

---

## Summary

Six assignments complete out of roughly 19 in Phase 4. Each full assignment takes 20-30% of a 1M context window, so plan on 2-3 assignments per session with Opus 4.7 1M. Smaller fixes (Phase 5 technique weaving, targeted homework-only regenerations) fit comfortably on Sonnet 4.6 at 200k.

The reference quality bar is set by `jobs-and-cronjobs/assignment-1`, `pod-security/assignment-1`, `rbac/assignment-2`, `statefulsets/assignment-1`, `troubleshooting/assignment-2`, and `autoscaling/assignment-1`. Future Phase 4 output must meet the same bar.

Doc sync is not optional: update `remediation-plan.md` and `audit-findings.md` in the same commit as each content task to avoid the drift that required the 2026-04-18 doc-sync pass.
