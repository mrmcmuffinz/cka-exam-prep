# Next-Session Prompt

This file contains a ready-to-use prompt for starting a new Claude Code session to continue the remediation effort on this repository. Copy the block between the `=== BEGIN PROMPT ===` and `=== END PROMPT ===` markers and paste it as the first message in a new session.

**When to use this:** whenever you start a new session to chip away at the remaining Phase 5 or Phase 6 work. The prompt orients the new assistant without needing you to re-explain the project.

**When to update this:** after every completed Phase 5 or Phase 6 task, bump the "Current state" section of the prompt so the next assistant knows what is already done. Once both phases close, rewrite this file into a generic "maintenance-mode" prompt (quality audit, version-pin re-verification, annual curriculum check).

---

=== BEGIN PROMPT ===

I am Abe (cab.abraham@gmail.com), a platform engineer studying for the CKA (Certified Kubernetes Administrator) exam. You are helping me continue work on the `/workspaces/cka-exam-prep` repository, which contains hands-on homework assignments for CKA exam prep built by a two-skill generation pipeline (`cka-prompt-builder` scopes topics and writes prompts; `k8s-homework-generator` produces four content files per assignment).

The large content-generation push (Phase 4) is complete. The remaining work is smaller: Phase 5 (three technique-weaving tasks that inject short content into existing tutorials) and Phase 6 (seven verification and housekeeping tasks). Your job this session is to pick one or more of these and close them out.

**Essential reading before you write anything (takes about 5 minutes):**

1. `docs/session-handoff.md` — the authoritative resume guide; explains current state and the Phase 5/6 priority queue.
2. `docs/remediation-plan.md` — task-level status (Phase 5: P5.1-P5.3; Phase 6: P6.1-P6.7) and the progress log.
3. `.claude/skills/k8s-homework-generator/references/base-template.md` — the content quality gates. Any weaving you add must still satisfy them.
4. One Phase 4 reference assignment that is near your target topic shape, for style reference if you are authoring new prose.

**Current state as of 2026-04-19 (update this block in `next-session-prompt.md` after each session):**

- Phases 1, 2, 3, 4 all complete.
- All 45 assignments content-complete.
- Phase 5 (technique weaving) **not started**:
  - P5.1: `kubectl debug` into `19-troubleshooting/assignment-1` and `/assignment-3` tutorials.
  - P5.2: `kubectl port-forward` into `08-services/assignment-1` tutorial.
  - P5.3: Custom scheduler profiles and multiple schedulers into `01-pods/assignment-4` tutorial (or acknowledge as a known thin area).
- Phase 6 (verification and housekeeping) **not started**:
  - P6.1: Grep for stale `6 of 6` series counters across all READMEs.
  - P6.2: Verify every `exercises/X/assignment-Y` cross-reference points at a real path.
  - P6.3: Audit all assignment-level READMEs against the 9-section canonical shape.
  - P6.4: Audit tutorials against the per-field spec-documentation standard.
  - P6.5: Audit answer keys against the three-stage debugging structure.
  - P6.6: Update `cka-homework-plan.md` coverage matrix to reflect the final assignment counts (already done 2026-04-19 but re-verify during the sweep).
  - P6.7: Final status sweep of `docs/audit-findings.md` (in progress).

**What I need from you this session:**

1. **Pick one or more Phase 5 or Phase 6 tasks and tell me which.** Weaving tasks (P5.1, P5.2, P5.3) are short additions to existing tutorials, typically one to two new sections each. Verification tasks (P6.1, P6.2, P6.3, P6.4, P6.5) are audits that may surface small fixes as they proceed. Either category is appropriate for a single session; both together may fit if the session is long and the audits do not surface many fixes.

2. **Do the work.** For Phase 5, add the new content to the existing tutorial (do not regenerate the whole file). For Phase 6, run the audits, surface any discrepancies with file-and-line citations, and fix the small ones in the same pass.

3. **Update documentation in the same commit as the work:**
   - `docs/remediation-plan.md` task status to Complete with today's date; add a progress-log entry.
   - `docs/audit-findings.md` finding status if the work resolves or partially resolves a finding (Phase 5 closes curriculum gaps G4, G7, G8; Phase 6 closes E6 and E7).
   - `docs/next-session-prompt.md` (this file) "Current state" block so the next session knows what was done.

4. **Commit with a clear message** following the pattern used in recent commits: `feat: Phase 5 - weave <topic> into <tutorial>` or `chore: Phase 6 - <audit-name>` as the title, followed by a summary paragraph and the `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` trailer.

**Hard constraints I care about, distilled:**

- No em dashes anywhere (use commas, periods, or parentheses).
- No general-knowledge version pins (always verify against upstream if pinning something new).
- No reading-only exercises.
- No `grep -q ... && echo SUCCESS` verification patterns.
- No duplicated YAML in answers.
- Container images always have explicit tags, never `:latest`.
- Cluster setup is referenced by anchor to `docs/cluster-setup.md`, never inlined.

**Model and context for this session:** Sonnet 4.6 at 200k context is sufficient for any Phase 5 weaving task or any single Phase 6 audit. Only escalate to Opus 4.7 1M if an audit surfaces a full-assignment regeneration requirement, which should not happen under the current plan.

**Before you write anything:** tell me which task(s) you picked and confirm you have read the four essential documents. After that, proceed without further confirmation.

=== END PROMPT ===

---

## How to use this file

1. Copy the prompt block between the markers.
2. Open a new Claude Code session on this repository.
3. Paste the prompt as your first message.
4. The assistant should respond by naming the task it plans to tackle and confirming it has read the orientation docs. If it starts working without that confirmation, stop it and point at this file.

## Maintenance

After each session, the assistant should:

- Update the "Current state" block in the prompt above to reflect which P5/P6 tasks are now complete.
- Leave the rest of the prompt unchanged unless the workflow itself needs updating.

Once Phases 5 and 6 both close, rewrite this file for maintenance mode: an annual re-verification of component versions against upstream docs, a re-read of the CKA curriculum for changes, and a quality pass on any assignments whose topics have drifted.
