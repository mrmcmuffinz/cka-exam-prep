# Base Template: Kubernetes Homework Assignment Generator

## Purpose

This document defines the structural conventions, exercise format, difficulty
progression, and formatting rules that every homework assignment must follow. The
homework generator skill reads this template alongside the assignment-specific
prompt.md to produce consistent, high-quality output across all topics.

---

## Directory Structure

Each topic has a topic-level README at `exercises/<topic>/README.md` that scopes the
number of assignments and what each one covers. This file is produced by the
`cka-prompt-builder` skill and must exist before any assignment content is generated.
The homework generator does not produce or modify the topic README.

Each assignment within a topic lives in `exercises/<topic>/assignment-N/` and contains
the five files described below.

## Output Files

Every assignment produces exactly four Markdown files in the assignment directory.
(The fifth file, prompt.md, is the input produced by the prompt builder, not by
this generator.)

### 1. README.md

The assignment's own overview. The canonical shape below is modeled on
`exercises/pods/assignment-1/README.md`, which is the reference quality bar for
the entire corpus. Every assignment README must follow this shape. Narrative
prose, not stacked bullet lists, is the default. Tables appear only where they
genuinely help (the Files section, the version matrix reference) and never
instead of explanation.

**Canonical shape (in order):**

1. **Title** (H1) naming the assignment and its series position in prose (not
   a metadata header block). One introductory paragraph of 3-5 sentences that
   explains what the assignment covers, what comes before it, and what comes
   after it in the series.
2. **Files** (H2) with a small table listing the five files and a one-line
   description each (`README.md`, `prompt.md`, `<topic>-tutorial.md`,
   `<topic>-homework.md`, `<topic>-homework-answers.md`).
3. **Recommended Workflow** (H2) as one or two paragraphs of narrative prose
   explaining how to move through the material. No numbered steps if a short
   paragraph suffices.
4. **Difficulty Progression** (H2) as a paragraph describing what each level
   tests. Do not use a table unless the descriptions would be longer than the
   paragraph equivalent. Level 1 and Level 2 build construction fluency, Level
   3 is debugging, Level 4 is realistic build tasks, Level 5 is advanced
   debugging or comprehensive scenarios. Anti-spoiler conventions apply to
   Levels 3 and 5.
5. **Prerequisites** (H2) as a short paragraph (not a bullet list) stating
   which prior assignments and course sections are assumed, and linking to the
   cluster setup document.
6. **Cluster Requirements** (H2) as a one-paragraph reference to the
   appropriate section of `docs/cluster-setup.md` by anchor link. Do not
   inline the cluster creation command in the assignment README. If the
   assignment needs additional setup beyond the named cluster profile
   (metrics-server, MetalLB, Gateway API CRDs, a specific ingress controller),
   link to those sections too.
7. **Estimated Time Commitment** (H2) as a paragraph with realistic per-level
   guidance. Do not reduce this to a table.
8. **Scope Boundary and What Comes Next** (H2) as a paragraph stating what
   this assignment deliberately does not cover and which adjacent assignments
   pick those topics up. This is the primary defense against scope drift.
9. **Key Takeaways After Completing This Assignment** (H2) as a paragraph
   describing the concrete skills the learner should own by the end. Must be
   specific enough that a reader can use it to self-assess readiness.

The README must not inline cluster creation commands, metallb install
manifests, Calico install manifests, ingress controller installs, or any
other long setup block that belongs in `docs/cluster-setup.md`. The README
references setup sections by anchor link.

### 2. <topic>-tutorial.md

A standalone tutorial teaching one complete real-world workflow from start to
finish. The reference quality bar is
`exercises/pods/assignment-1/pod-fundamentals-tutorial.md`. New tutorials must
match that level of narrative depth, not the terser reference-card style found
in some of the earlier skill-generated output.

**Structure:**

- **Introduction:** Two to three paragraphs of narrative prose explaining what
  the topic is, why it matters for CKA, and what complete worked example the
  tutorial will build. Do not start with a feature list.
- **Prerequisites section:** Short paragraph naming which `docs/cluster-setup.md`
  section applies plus any additional setup (CRDs, ingress controller, metrics-
  server, etc.). Do not inline long kubectl install blocks in the tutorial;
  reference the cluster setup document by anchor.
- **Setup:** Create the tutorial namespace (`tutorial-<topic>`) and any
  baseline resources needed.
- **Walkthrough:** Step-by-step construction of a real use case, with every
  command shown and every meaningful output explained. Include both imperative
  (kubectl create/run) and declarative (YAML) approaches where applicable.
  When only declarative is practical, say so explicitly and explain why.
- **Spec field documentation (hard gate).** When introducing a Kubernetes
  resource type for the first time, the tutorial must enumerate its spec
  fields covering: (a) what each field does, (b) valid values or value
  ranges, (c) the default when the field is omitted, and (d) the failure
  mode or observable symptom when the field is misconfigured. The
  "failure-mode-when-misconfigured" part is the most common omission in
  skill-generated output and is explicitly required. Pod tutorial examples
  of this done well: the `restartPolicy` table (values and behavior), the
  `imagePullPolicy` explanation tying defaults to the tag, the downward API
  `fieldPath` note about `metadata.labels['key']` vs `metadata.labels.key`.
- **Verification:** Show how to verify the setup works (kubectl get, describe,
  logs, exec).
- **Cleanup:** Delete the tutorial namespace and any cluster-scoped resources
  created.
- **Reference Commands section:** Quick-reference tables at the end covering
  the most common operations, organized so learners can skim for the command
  they need mid-exercise.

**Tutorial narrative style (hard gate):**

Tutorials must use narrative paragraph flow as the default. Bullet lists are
permitted for genuine enumerations (spec field references, command variants,
verification checklists) but are not permitted as a substitute for explanation.
A tutorial built out of stacked one-sentence paragraphs fails this gate.
Compare `pods/assignment-1` (narrative, explains why each choice is made)
against some of the earlier skill-generated tutorials that list facts without
explaining tradeoffs. The narrative version is the target.

**Tutorial conventions:**

- Use namespace `tutorial-<topic>` for all tutorial resources.
- Do not reuse any resource names that exercises will use.
- If creating users or certificates is relevant, make the procedure work
  specifically for kind clusters with nerdctl.
- Use the `user@cluster` naming convention for kubeconfig contexts (for
  example, `jane@kind-kind`).
- Leverage kind's existing kubeconfig setup when possible (do not manually
  extract CA certs unless building from scratch is the point of the
  exercise).
- Show real command output where it helps understanding.
- Explain defaults and defaults-by-omission explicitly; this is where many of
  the exam's gotchas live.

### 3. <topic>-homework.md

Contains 15 progressive exercises organized into five difficulty levels.

**Structure:**

- **Brief introduction** referencing the tutorial file as preparation
- **Exercise setup commands section** at the top (if any global setup is needed beyond
  per-exercise setup)
- **Level 1 through Level 5** sections, each containing three exercises
- **Cleanup section** at the end (delete all exercise namespaces)
- **Key Takeaways section** summarizing the most important concepts practiced

### 4. <topic>-homework-answers.md

Complete solutions for all 15 exercises. The reference quality bar is
`exercises/pods/assignment-1/pod-fundamentals-homework-answers.md`, which
explains diagnostic reasoning (not just solutions) for every debugging exercise.

**Structure:**

- **Solutions for all exercises** in order, using heading format
  `## Exercise X.Y Solution`.
- **Both imperative and declarative approaches** where applicable. Show each
  form once; do not duplicate the same YAML inline as display and again inside
  a `kubectl apply -f - <<EOF` heredoc. Pick one canonical form per solution.
- **Debugging-exercise answer structure (hard gate).** For every Level 3 and
  Level 5 debugging exercise, the answer must follow a three-stage structure:
    1. **Diagnosis:** the exact sequence of kubectl commands a learner should
       run to identify the bug, plus what output to look for at each step.
       This teaches the exam skill (reading `kubectl describe` output,
       finding events, interpreting exit codes) rather than just stating the
       answer.
    2. **What the bug is and why it happens:** a narrative explanation of
       the underlying cause, not just "change X to Y." The exam tests
       diagnostic reasoning, and the answer key must model that reasoning.
    3. **The fix:** the corrected configuration with any concrete commands
       needed to apply it.
  A debugging answer that only shows the fixed YAML and a one-line "the image
  tag was wrong" explanation fails this gate.
- **Common Mistakes section (hard gate).** Required at the end of every
  answers file with at least three entries specific to this assignment's
  topic. Each entry names the mistake, explains why it is common (often
  tying back to a non-obvious default or a misleading error message), and
  states the correction. The reference for this section is
  `pods/assignment-1` Common Mistakes (seven substantive entries covering
  command-vs-args, restartPolicy with init containers, `:latest` tags,
  container name uniqueness, `emptyDir` lifetime, downward API label syntax,
  and keeping a pod alive for inspection). An answers file without a
  Common Mistakes section, or with fewer than three entries, fails this gate.
- **Verification Commands Cheat Sheet** at the end with a quick-reference
  table organized by use case (status, deep inspection, logs, exec, useful
  jsonpath one-liners).

---

## Exercise Structure

### Difficulty Levels

**Level 1: Basic single-concept tasks (3 exercises)**

Single resource type with basic configuration. Single namespace. Straightforward
verification (2-3 checks). The learner applies one concept from the tutorial.

Example: "Create a PersistentVolumeClaim requesting 1Gi of storage with ReadWriteOnce
access mode."

**Level 2: Multi-concept tasks (3 exercises)**

Multiple resource types or combined configurations. Still single namespace. More
verification checks (4-6 checks). The learner combines two or three concepts.

Example: "Create a PersistentVolume and a PersistentVolumeClaim that binds to it, then
create a pod that mounts the claim and writes data to it."

**Level 3: Debugging broken configurations (3 exercises)**

Given broken YAML or configurations that fail in specific ways. Single clear issue to
find and fix. The learner must identify the problem from symptoms and apply the fix.

Example: "This PVC should bind to the PV but is stuck in Pending. Find and fix the
issue."

**Level 4: Complex real-world scenarios (3 exercises)**

Multiple namespaces, multiple resources, or realistic production patterns. 8+
verification checks across different dimensions. The learner builds a complete,
working configuration from requirements.

Example: "Create a storage setup for a three-tier application where the database pod
uses a PersistentVolume with Retain policy, the app pod uses a PVC with a specific
StorageClass, and a reporting pod mounts the same data as read-only."

**Level 5: Advanced debugging and comprehensive tasks (3 exercises)**

Multiple broken issues in one config (2-3 problems to find and fix), or very complex
multi-resource scenarios, or edge cases and gotchas. 10+ verification checks. The
learner demonstrates deep understanding of how components interact.

Example: "This multi-component storage setup has several issues preventing the
application from starting. Find and fix whatever is needed so the application runs
correctly."

### Exercise Components

Every exercise must include:

1. **Numbered heading only:** `### Exercise X.Y` with no descriptive title or
   subtitle.
2. **Objective statement:** Clear description of the goal without telegraphing
   the solution (especially critical for debugging exercises).
3. **Setup commands:** Complete, copy-paste ready, no placeholders. Creates
   the namespace and any required baseline resources. For debugging exercises,
   the setup includes the broken configuration.
4. **Task description:** What the learner needs to do, stated as the desired
   end state.
5. **Verification commands:** See the verification rules below.

### Exercise task types (hard gate)

Every exercise task must be a build-or-fix task: create a resource, modify a
resource, diagnose and repair a configuration. Reading-only tasks ("list and
describe all CRDs in the cluster," "for each manifest, identify the component
name and document your findings") are not permitted. They do not build the
muscle memory the CKA exam tests and they do not have a verifiable end state.

If a reading task would be valuable pedagogically, place it in the tutorial,
not the homework. The homework exercises are practice reps, not reading
comprehension. Exercises that start with verbs like "document," "identify,"
"list and describe," "for each X, note Y" fail this gate.

### Verification rules (hard gate)

Verification commands must produce specific expected outputs so the learner
knows unambiguously whether the task is complete. The reference is the RBAC
assignment's `kubectl auth can-i --as=USER` pattern, where every check has an
`# expect: yes` or `# expect: no` comment.

Required:

- Each verification command is followed by the expected output, either inline
  as a comment (`# Expected: ...`) or on the line below.
- Expected outputs are specific values (phase `Running`, exit code `0`, the
  literal string `hello world`, a label `tier=backend`), not instructions
  to "check if it works."
- For `kubectl auth can-i` checks, the expected result is `# expect: yes` or
  `# expect: no`.
- For `kubectl get ... -o jsonpath=...`, the expected exact string is shown.
- For connectivity tests (`kubectl exec ... -- curl ...`), a specific
  success criterion is named (HTTP 200, a response body substring, or a
  time-out behavior).

Prohibited:

- `grep -q "X" && echo "SUCCESS" || echo "FAILED"` chains. They check only
  for string presence and output "SUCCESS" even when the test is meaningless.
- `timeout N kubectl exec ... || echo "BLOCKED"` for testing expected
  denials. The `||` fires on any non-zero exit (pod missing, exec error,
  CNI flake), not just the intended denial. Use `!` with explicit exit code
  checks, or verify denial by observing the resulting empty endpoint, or
  use `kubectl auth can-i` where applicable.
- Vague instructions like "check if it works," "verify the pod is healthy,"
  or "make sure everything is running."

### Namespace Convention

- Each exercise gets its own namespace: `ex-<level>-<exercise>` (for example,
  `ex-3-2` for the second exercise of Level 3)
- Tutorial uses `tutorial-<topic>`
- No namespace reuse across exercises

### Resource Naming

- Use different user names, resource names, and identifiers per exercise
- Common user names for RBAC-related exercises: alice, bob, charlie, diana, eric,
  fiona, george, hannah, ian, jane, karl, luna, marco, nina, olivia
- Resource names should be descriptive but not hint at the bug in debugging exercises

---

## Anti-Spoiler Rules

These rules apply to debugging exercises (Levels 3 and 5) and are critical for the
learning value of the exercises.

**Exercise headings must NOT contain descriptive titles:**

- BAD: "Exercise 3.1: The PVC that won't bind"
- BAD: "Exercise 3.2: Wrong access mode"
- GOOD: "Exercise 3.1"

**Objective lines must NOT reveal the number or type of issues:**

- BAD: "Fix three separate issues so that the pod can access storage"
- BAD: "The RoleBinding references the wrong Role"
- GOOD: "Fix the broken configuration so that the pod can access its storage"
- GOOD: "The configuration above has one or more problems. Find and fix whatever
  is needed so that..."

**Task descriptions state the desired end state, not the location or count of bugs.**

Section-level headings like "Level 3: Debugging Broken Configurations" are acceptable
as navigation. Per-exercise hints about what or where the problem is are not.

Level 4 and Level 5 non-debugging exercises CAN describe what to build in their
objectives, since that is the task, not a spoiler.

---

## Environment

### Cluster setup

All assignments assume a kind cluster running rootless containerd via nerdctl.
The authoritative setup document is `docs/cluster-setup.md` at the repository
root. Every assignment README and tutorial references that document by anchor
rather than inlining cluster creation commands. When this skill needs to
produce a cluster creation block for a tutorial (because the tutorial teaches
a step that is cluster-specific), the skill reads the relevant section of
`docs/cluster-setup.md` and links to it rather than rewriting it.

Sections in `docs/cluster-setup.md` that the skill may reference:

- `#single-node-kind-cluster` for most assignments
- `#multi-node-kind-cluster` for scheduling, workload controllers, services,
  troubleshooting
- `#multi-node-with-calico-networkpolicy-support` for network-policies and
  network troubleshooting
- `#metallb-for-loadbalancer-services` for service assignments using
  LoadBalancer type
- `#metrics-server` for autoscaling and troubleshooting
- `#gateway-api-crds` for Gateway API assignments

The prompt.md for each assignment specifies which cluster profile applies.

### Container images

Always use explicit version tags. Never use `:latest`. When picking an image
tag, confirm the tag exists in the upstream registry and prefer a tag that is
compatible with the target Kubernetes version. Common tested images:

- `nginx:1.27`
- `busybox:1.36`
- `alpine:3.20`
- `redis:7.2`
- `httpd:2.4`
- `curlimages/curl:8.5.0`

### Tools

- `kubectl` is the primary tool for all exercises.
- `nerdctl` for container operations outside the cluster (rarely needed).
- `base64 -w0` for encoding Secret values (not `base64 | tr -d '\n'`).
- `openssl` for certificate operations in RBAC/TLS exercises.

### Topic-specific environment needs

Some topics require additional cluster configuration beyond the base kind
cluster. The prompt.md specifies which extras apply. Common cases (with the
authoritative install instructions in `docs/cluster-setup.md`):

- **Network Policies:** Calico (section `#multi-node-with-calico-...`).
- **Services with LoadBalancer:** MetalLB (section `#metallb-for-...`).
- **Gateway API:** Gateway API CRDs, plus a specific Gateway API
  implementation per assignment (section `#gateway-api-crds` plus the
  per-assignment controller install in the tutorial file).
- **Ingress v1:** A controller such as Traefik or HAProxy Ingress. The
  per-assignment tutorial documents the install for that specific
  controller; `docs/cluster-setup.md` lists which controller is pinned to
  which assignment.
- **Metrics:** metrics-server (section `#metrics-server`).
- **Storage:** kind's built-in `rancher.io/local-path` provisioner is
  sufficient for most assignments; no extra install needed.
- **RBAC:** User certificate creation using kind's embedded CA. The
  procedure is documented in the RBAC tutorials, not in `docs/cluster-setup.md`,
  because it is a per-assignment teaching topic rather than a setup step.

---

## Resource Gate

The prompt.md specifies which Kubernetes resources exercises are permitted to use.
This prevents exercises from referencing objects the learner has not yet encountered.

**Early assignments (generation order 1-3):** The prompt lists permitted resources
explicitly.

**Later assignments (generation order 4+):** "All CKA resources are in scope" or a
specific list if the topic warrants it.

The generator must not introduce resources outside the gate, even if they would make
an exercise more elegant. If a resource is needed but gated out, restructure the
exercise to work within the constraint.

---

## Formatting Rules

These rules apply to all four output files.

- **No em dashes anywhere.** Use commas, periods, or parentheses instead.
- **Narrative paragraph flow** in prose explanations. Do not stack single-sentence
  declarations as separate paragraphs. Group related ideas into paragraphs.
- **Markdown only.** No HTML tags, no embedded images, no PDFs.
- **Fenced code blocks** for all commands and YAML. Use appropriate language tags
  (```bash, ```yaml, ```text).
- **Self-contained files.** Each file can be read independently. Cross-references
  between files use relative descriptions ("see the tutorial file in this directory")
  not hyperlinks.
- **No em dashes.** (Repeated intentionally because this is easy to forget.)
- **Full replacement files.** When updating an existing assignment, replace the
  entire file rather than patching.
- **Copy-paste ready commands.** No placeholders like `<your-namespace>` or
  `$NAMESPACE`. Every command should work exactly as written.

---

## Quality Standards

These are the hard gates the `k8s-homework-generator` skill must satisfy before
finalizing any assignment. An assignment that fails any of these must not be
delivered as complete.

**Structural gates:**
- All four output files are present and non-empty.
- No resource-name, user-name, or namespace conflicts between tutorial and
  exercises.
- All commands are copy-paste ready with no placeholders.
- Container images use explicit version tags (never `:latest`) and the tags
  are verified to exist in the upstream registry.
- Exercise namespaces are unique across all 15 exercises (`ex-1-1` through
  `ex-5-3`). Tutorial namespace is `tutorial-<topic>`.
- Different user and resource names per exercise; no reuse across exercises.

**README gates (see Output Files section 1):**
- README follows the canonical 9-section shape.
- Cluster setup is referenced by anchor to `docs/cluster-setup.md`, not
  inlined.
- Prose is narrative; no metadata header block substitutes for a proper
  introduction.

**Tutorial gates (see Output Files section 2):**
- Tutorial uses narrative paragraph flow, not stacked one-sentence
  paragraphs or bullet-only exposition.
- Every new resource type has spec fields documented with valid values,
  defaults, and failure modes when misconfigured.
- Imperative and declarative forms shown together where both are realistic;
  an explicit explanation given when only one form is practical.

**Homework gates (see Output Files section 3, Exercise Structure):**
- Every exercise is a build-or-fix task; no reading-only tasks.
- Debugging exercises (Levels 3 and 5) have bare headings and objectives
  that do not telegraph the bug count or type.
- Verification commands produce specific expected outputs (RBAC-style
  `# expect: yes/no`, exact jsonpath values, or named success criteria).
- No `grep -q ... && echo SUCCESS` pipelines. No `timeout N ... || echo BLOCKED`
  denial tests.
- Resources used fall within the prompt.md's resource gate.

**Answer key gates (see Output Files section 4):**
- Every Level 3 and Level 5 debugging exercise answer has the three-stage
  structure: diagnosis (commands plus what to look for), bug explanation
  (what and why), fix (corrected config and how to apply).
- Common Mistakes section exists at the end with three or more
  topic-specific entries, each naming a common error and explaining why it
  happens.
- No duplication of the same YAML as both a display block and a
  `kubectl apply -f - <<EOF` heredoc; pick one canonical form per solution.
- Verification Commands Cheat Sheet present.

**Formatting gates (see Formatting Rules):**
- No em dashes anywhere.
- Full replacement files on any update (never patches or diffs).
- Fenced code blocks use the correct language tag.

**Quality standards:**
- Exercises build practical muscle memory for the CKA exam, not just test
  knowledge.
- The tutorial teaches one complete real-world workflow, not a disconnected
  series of examples.
- Debugging exercises have realistic failure modes, not contrived typos.
- Level progression is genuine: Level 1 under 5 minutes, Level 5 15-20
  minutes.
- The answer key explains the "why" behind solutions, not just the "what."
