# Session Handoff Guide

This document explains how to continue the remediation work across Claude Code sessions. It is intended for the repo maintainer (Abe) or any future assistant resuming Phase 4 content generation.

**Last updated:** 2026-04-19 (Phase 6 complete: all verification and housekeeping audits passed. Phases 1-6 all closed. Remediation plan complete.)

---

## Current state

As of 2026-04-18:

| Phase | Status | Notes |
|---|---|---|
| 1. Infrastructure fixes | Complete | typo, version pins, worktree dir, tmux commit |
| 2. Skill asset strengthening | Complete | base-template.md, SKILL.md, cluster-setup.md, registry refresh |
| 3. Topic scoping | Complete | 5 new topic READMEs + prompts; ingress restructured to 5 assignments with updated prompts |
| 4. Content generation | Complete | All 19 full-assignment regens done plus 3 surgical regens. security-contexts/1-3, storage/1-3, ingress/1-5 closed under P4.2, P4.3, and P4.9-P4.13 on 2026-04-18 alongside the earlier completions |
| 5. Technique weaving | Complete | kubectl debug (ephemeral containers, node debugging), kubectl port-forward (services/pods), scheduler profiles (acknowledged in pods/4) |
| 6. Verification and housekeeping | Complete | series counters verified, cross-references validated, READMEs/tutorials/answers audited, coverage matrix confirmed, audit-findings closed |

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

Look at `docs/remediation-plan.md` Phase 5 or Phase 6. Tasks that are `Not started` are ready. Phase 4 is fully closed; the priority queue looks like:

**All Phase 4 tasks complete as of 2026-04-18:**
- P3.6 fully: all five new-topic assignments content complete
- P4.1: `12-rbac/assignment-2` content
- P4.2: `13-security-contexts/assignment-1`, `-2`, `-3` content
- P4.3: `07-storage/assignment-1`, `-2`, `-3` content (U7 duplicated-YAML finding resolved)
- P4.4: `19-troubleshooting/assignment-2` content
- P4.5: `19-troubleshooting/assignment-4` content
- P4.6: `17-cluster-lifecycle/assignment-1` homework regen
- P4.7: `15-crds-and-operators/assignment-1` Level 1 regen
- P4.8: `19-troubleshooting/assignment-1` Exercise 1.2 single-failure fix
- P4.9: `11-ingress-and-gateway-api/assignment-1` content with Traefik v3.6.13
- P4.10: `11-ingress-and-gateway-api/assignment-2` content with HAProxy Ingress v3.2.6
- P4.11: `11-ingress-and-gateway-api/assignment-3` content with Envoy Gateway v1.7.2
- P4.12: `11-ingress-and-gateway-api/assignment-4` content with NGINX Gateway Fabric v2.5.1 (new)
- P4.13: `11-ingress-and-gateway-api/assignment-5` content with Ingress2Gateway CLI v1.0.0 (new)

**All phases complete.** No remaining remediation work. The repository is in its final audited state with 45 content-complete assignments across 17 topics. (already in progress)

### Step 3: Follow the task-appropriate workflow

**For a Phase 6 audit task:**

1. Run the audit (grep, glob, or targeted reads) and produce a list of discrepancies with file-and-line citations.
2. Fix small ones inline; flag any that require larger work by opening a follow-up task in `docs/remediation-plan.md`.
3. Update the task status and the relevant audit-finding status.
4. Commit with a clear message naming the audit that ran and the discrepancies found.

### Step 4: Keep documentation synchronized as you go

Do not defer doc updates to the end. In the same commit as each task, update:

- `docs/remediation-plan.md` — task status and progress log
- `docs/audit-findings.md` — any finding whose status changes (Phase 5 closes G4, G7, G8; Phase 6 closes E6 and E7 once audits confirm no fixes are needed)
- `cka-homework-plan.md` — only if the high-level status summary changes
- `.claude/skills/cka-prompt-builder/references/assignment-registry.md` — only if the scope summary of an assignment needs updating

---

## Model and context recommendations

### Recommended setup

**For Phase 5 technique weaving and Phase 6 audits** (the remaining work):

- **Model:** Claude Sonnet 4.6 (`claude-sonnet-4-6`) with the 200k context is sufficient for any Phase 5 weave or any single Phase 6 audit.
- **Tasks per session:** one Phase 5 weave per session; multiple Phase 6 audits per session if they surface few fixes.

**For historical reference only — full content generation** (no longer required now that Phase 4 is closed):

- **Model:** Claude Opus 4.7 (`claude-opus-4-7`) with the 1M context variant (`claude-opus-4-7[1m]`)
- **Context usage per assignment:** roughly 14% of a 1M context window
- **Assignments per session:** 2 is comfortable, 3 is possible but leaves little room for course correction

Use Opus 4.7 1M only if an audit uncovers a full-assignment regeneration requirement, which should not occur under the current plan.

### Context budgeting rule of thumb (historical)

Observed from generating the 19 completed Phase 4 assignments:

- Reading the prompt, base-template, and an existing assignment as quality-bar reference: ~5-8% of 1M context
- Web-fetching upstream docs for API verification: ~3-5%
- Writing four content files: ~10-14%
- Documentation updates and commit preparation: ~1-2%
- **Total per full assignment: 20-30% of 1M context**

Starting fresh, you can plan for 2-3 full assignments per session. Surgical fixes (P4.6-style homework-only regens, single-exercise rewrites) are much cheaper (5-10% each) and several can fit alongside a full regen.

### When to start a fresh session

Start a new session when:

- Remaining context budget is below about 20% of a full 1M window
- You have just committed work and the next task is independent
- The handoff point is natural (all artifacts committed, plan updated, no dangling state)

Do not push through context exhaustion; the quality of later work degrades and mistakes become harder to catch. Err on the side of committing cleanly and starting fresh.

---

## Reference quality bar

When generating any new content (Phase 5 weaving or Phase 6 audits), read one of the reference assignments first so the style is fresh in context. All of these demonstrate the full set of Phase 2 hard gates:

**Hand-crafted originals (canonical references):**
- `exercises/01-01-pods/assignment-1/` — narrative bar for tutorials; defaults and failure modes taught in prose
- `exercises/12-12-rbac/assignment-1/` — subject-oriented topic; narrative bar for auth-vs-authz

**Phase 4 skill-generated (all 19 meet the same bar):**
- Workload controllers: `jobs-and-cronjobs/1`, `statefulsets/1`
- Autoscaling: `autoscaling/1` (metrics-server-dependent signal)
- Admission: `admission-controllers/1` (CEL + ValidatingAdmissionPolicy), `pod-security/1` (PSA)
- RBAC: `rbac/2` (cluster-scoped)
- Security contexts: `security-contexts/1` (identity), `/2` (capabilities), `/3` (seccomp + read-only root)
- Storage: `storage/1` (PVs), `/2` (PVCs + binding), `/3` (StorageClasses + dynamic provisioning)
- Ingress and Gateway API: `ingress-and-gateway-api/1` (Traefik), `/2` (HAProxy + TLS), `/3` (Envoy Gateway), `/4` (NGINX Gateway Fabric), `/5` (migration)
- Troubleshooting: `troubleshooting/2` (control plane), `/4` (network)

Pick whichever is most shape-adjacent. For the Phase 5 `kubectl debug` weave, `19-troubleshooting/assignment-2` is the nearest shape for ephemeral-container workflows. For the Phase 5 `port-forward` weave, `08-services/assignment-1` is the target itself.

---

## Checklist before committing a Phase 4-style assignment (historical; preserved for reference)

Tick every item before marking any full-assignment regeneration task Complete. Phase 4 is closed, but the same checklist governs any hypothetical future regeneration surfaced by Phase 6 audits.

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

All six phases are complete. The remediation plan is closed.

- **45 content-complete assignments** across 17 topics
- **19 full-assignment regens** under the Phase 2 quality gates plus 3 surgical regens
- **5 new topics** (jobs-and-cronjobs, autoscaling, statefulsets, admission-controllers, pod-security) closing curriculum gaps G1, G2, G3, G5, G6
- **Ingress expansion** from 3 to 5 assignments with controller diversity (Traefik, HAProxy Ingress, Envoy Gateway, NGINX Gateway Fabric, Ingress2Gateway CLI)
- **Technique weaving** for kubectl debug, kubectl port-forward, and scheduler profiles (G4, G7, G8)
- **Phase 6 verification** confirmed: series counters correct, cross-references valid, READMEs/tutorials/answers meet quality gates

The reference quality bar is set by the 19 skill-generated Phase 4 assignments plus the two hand-crafted originals (`01-pods/assignment-1`, `12-rbac/assignment-1`). Any future content work must meet the same bar.

For future maintenance, continue the practice of updating `remediation-plan.md` and `audit-findings.md` in the same commit as any content changes.
