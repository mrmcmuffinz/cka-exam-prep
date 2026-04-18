# Next-Session Prompt

This file contains a ready-to-use prompt for starting a new Claude Code session to continue Phase 4 content generation on this repository. Copy the block between the `=== BEGIN PROMPT ===` and `=== END PROMPT ===` markers and paste it as the first message in a new session.

**When to use this:** whenever a prior session finishes a block of Phase 4 work and context is getting tight. The prompt orients the new assistant without needing you to re-explain the project.

**When to update this:** after every completed Phase 4 assignment, bump the "Current state" section of the prompt so the next assistant knows what is already done.

---

=== BEGIN PROMPT ===

I am Abe (cab.abraham@gmail.com), a platform engineer studying for the CKA (Certified Kubernetes Administrator) exam. You are helping me continue work on the `/workspaces/cka-exam-prep` repository, which contains hands-on homework assignments for CKA exam prep built by a two-skill generation pipeline (`cka-prompt-builder` scopes topics and writes prompts; `k8s-homework-generator` produces four content files per assignment).

We are mid-way through a large remediation effort captured in `docs/remediation-plan.md`. Your job this session is to continue Phase 4 content generation from where the last session left off.

**Essential reading before you write anything (takes about 5 minutes):**

1. `docs/session-handoff.md` — the authoritative resume guide; explains current state, next-task priority queue, model recommendations, pre-commit checklist.
2. `docs/remediation-plan.md` — task-level status and the progress log.
3. `.claude/skills/k8s-homework-generator/references/base-template.md` — the content quality gates. Every file you generate must satisfy every hard gate.
4. `exercises/jobs-and-cronjobs/assignment-1/` or `exercises/pod-security/assignment-1/` — skim one as a reference for what the quality bar looks like in practice.

**Current state as of 2026-04-18 (update this block in `next-session-prompt.md` after each session):**

- Phases 1, 2, 3 complete.
- Phase 4 is in progress. **8 of approximately 19 assignments content-complete:**
  - `exercises/jobs-and-cronjobs/assignment-1/` (closes curriculum gap G2)
  - `exercises/pod-security/assignment-1/` (closes curriculum gap G6)
  - `exercises/rbac/assignment-2/` (closes P4.1)
  - `exercises/statefulsets/assignment-1/` (closes curriculum gap G5)
  - `exercises/troubleshooting/assignment-2/` (closes P4.4)
  - `exercises/autoscaling/assignment-1/` (closes curriculum gap G1)
  - `exercises/admission-controllers/assignment-1/` (closes curriculum gap G3; P3.6 complete)
  - `exercises/troubleshooting/assignment-4/` (closes P4.5; E4 fully resolved)
- All five new-topic curriculum gaps (G1, G2, G3, G5, G6) resolved. All stub READMEs (P4.1, P4.4, P4.5) regenerated.
- Surgical fixes complete: P4.6 (`cluster-lifecycle/assignment-1` homework), P4.7 (`crds-and-operators/assignment-1` Level 1 rewritten as build-or-fix), P4.8 (`troubleshooting/assignment-1` Exercise 1.2 single-failure simplification).
- Kubernetes target version for all content: **v1.35** (per the CKA curriculum document on github.com/cncf/curriculum).
- Component pins verified against upstream docs on 2026-04-18 and recorded in `docs/cluster-setup.md` version matrix.

**What I need from you this session:**

1. **Pick the next Phase 4 task from the priority queue in `docs/session-handoff.md`.** Top choices: thin regens (security-contexts P4.2 — three assignments; storage P4.3 — three assignments) or the ingress controller swap (P4.9-P4.13 — five assignments with per-controller installs). All curriculum gaps are closed and all surgical fixes are done; remaining work is quality uplift on existing thin-content assignments. Tell me which one you plan to generate and confirm you have read the four essential documents before writing anything.

2. **Generate the four content files** (`README.md`, `<topic>-tutorial.md`, `<topic>-homework.md`, `<topic>-homework-answers.md`) that satisfy every hard gate in `base-template.md`. Use the 9-section canonical README shape, narrative paragraph flow in the tutorial, 15 build-or-fix exercises with RBAC-style verification, three-stage debugging answers for Level 3 and Level 5, and a Common Mistakes section with three or more entries.

3. **Verify every external component version against upstream documentation.** Per decision D7 in the remediation plan, do not pin versions from general knowledge. Fetch the project's official releases page or compatibility matrix and cite the date of verification.

4. **Update documentation in the same commit as the content work:**
   - `docs/remediation-plan.md` task status to Complete with today's date; add a progress-log entry.
   - `docs/audit-findings.md` finding status if this assignment resolves or partially resolves a finding.
   - `docs/cluster-setup.md` version matrix if a new external component got pinned.
   - `docs/next-session-prompt.md` (this file) "Current state" block so the next session knows what was done.
   - `CLAUDE.md` and `README.md` content-state lines if they still say "prompt in place, content pending" for an assignment that is now content-complete.

5. **Commit with a clear message** following the pattern used in recent commits: `feat: Phase 4 - generate <topic>/<assignment> content` as the title, followed by a summary paragraph, sources consulted, and the `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` trailer.

**Hard constraints I care about, distilled:**

- No em dashes anywhere (use commas, periods, or parentheses).
- No general-knowledge version pins (always verify against upstream).
- No reading-only exercises ("document your findings," "list and describe").
- No `grep -q ... && echo SUCCESS` verification patterns.
- No duplicated YAML in answers (display block plus `kubectl apply -f - <<EOF` heredoc of the same config).
- Container images always have explicit tags, never `:latest`.
- Cluster setup is referenced by anchor to `docs/cluster-setup.md`, never inlined in an assignment README.

**Model and context for this session:** use Claude Opus 4.7 with the 1M context variant (`claude-opus-4-7[1m]`). One full Phase 4 assignment budgets roughly 20-30% of a 1M context window (upstream doc fetches, reading the prompt and quality-bar reference, writing four files, doc sync). Plan for 2-3 assignments this session at most. For smaller targeted fixes (single-level homework regeneration, technique weaving), Sonnet 4.6 at 200k is sufficient.

**Before you write anything:** tell me which assignment you picked and confirm you have read the four essential documents. After that, proceed without further confirmation.

=== END PROMPT ===

---

## How to use this file

1. Copy the prompt block between the markers.
2. Open a new Claude Code session on this repository.
3. Paste the prompt as your first message.
4. The assistant should respond by naming the assignment it plans to tackle and confirming it has read the orientation docs. If it starts generating content without that confirmation, stop it and point at this file.

## Maintenance

After each session, the assistant should:

- Update the "Current state" block in the prompt above (increment the completed-assignments count, add the new assignment name).
- Leave the rest of the prompt unchanged unless the process itself needs updating.

If the priority queue in `docs/session-handoff.md` becomes empty (all Phase 4 assignments complete), the prompt's "next task" section should be rewritten to shift to Phase 5 (technique weaving) or Phase 6 (verification and housekeeping).
