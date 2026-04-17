# Base Template: Kubernetes Homework Assignment Generator

## Purpose

This document defines the structural conventions, exercise format, difficulty
progression, and formatting rules that every homework assignment must follow. The
homework generator skill reads this template alongside the assignment-specific
prompt.md to produce consistent, high-quality output across all topics.

---

## Output Files

Every assignment produces exactly four Markdown files in the assignment directory.

### 1. README.md

The assignment's own overview. It must include:

- **Assignment title and series position** (if part of a series)
- **Brief description** of what the assignment covers (2-3 sentences)
- **Prerequisites:** which assignments or knowledge the learner should have first
- **Estimated time:** realistic estimate for tutorial + all exercises (typically 4-8 hours)
- **Recommended workflow:** tutorial first, then homework, then compare with answers
- **Difficulty level progression:** one-sentence description of each level
- **Cluster requirements:** single-node or multi-node kind, any special setup
- **Files in this directory:** list of all five files with one-line descriptions

### 2. <topic>-tutorial.md

A standalone tutorial teaching one complete real-world workflow from start to finish.

**Structure:**

- **Introduction:** What the topic is, why it matters for CKA, and what the tutorial
  will build (2-3 paragraphs)
- **Prerequisites section:** What needs to be running before starting (kind cluster,
  any special configuration)
- **Setup:** Create the tutorial namespace (`tutorial-<topic>`) and any baseline
  resources needed
- **Walkthrough:** Step-by-step construction of a real use case, with every command
  shown and every output explained. Include BOTH imperative (kubectl create/run) AND
  declarative (YAML) approaches where applicable. When only declarative is practical,
  say so explicitly and explain why.
- **Spec field explanations:** When introducing a new Kubernetes object for the first
  time, explain all spec fields: what each does, valid values, how to determine the
  right value for your use case
- **Verification:** Show how to verify the setup works (kubectl get, describe, logs,
  exec, etc.)
- **Cleanup:** Delete the tutorial namespace and any cluster-scoped resources created
- **Reference Commands section:** Quick-reference table at the end with imperative and
  declarative examples for the most common operations covered. This serves as a cheat
  sheet while doing exercises.

**Tutorial conventions:**

- Use namespace `tutorial-<topic>` for all tutorial resources
- Do not reuse any resource names that exercises will use
- If creating users or certificates is relevant, make the procedure work specifically
  for kind clusters with nerdctl
- Use the `user@cluster` naming convention for kubeconfig contexts (for example,
  `jane@kind-kind`)
- Leverage kind's existing kubeconfig setup when possible (do not manually extract CA
  certs unless building from scratch is the point of the exercise)
- Show real command output where it helps understanding
- Use narrative paragraph flow to explain concepts between commands, not bare
  bullet-point lists

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

Complete solutions for all 15 exercises.

**Structure:**

- **Solutions for all exercises** in order, using heading format "Exercise X.Y Solution"
- **Both imperative and declarative approaches** where applicable
- **For debugging exercises:** explain what was wrong and why, including how to
  diagnose the issue from kubectl output
- **Common Mistakes section** at the end listing the most frequent errors for this topic
- **Verification Commands Cheat Sheet** at the end with a quick-reference table

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

1. **Numbered heading only:** `### Exercise X.Y` with no descriptive title or subtitle
2. **Objective statement:** Clear description of the goal without telegraphing the
   solution (especially critical for debugging exercises)
3. **Setup commands:** Complete, copy-paste ready, no placeholders. Creates the
   namespace and any required baseline resources. For debugging exercises, the setup
   includes the broken configuration.
4. **Task description:** What the learner needs to do, stated as the desired end state
5. **Verification commands:** Specific commands with expected results (yes/no answers
   or exact expected output). Not vague instructions like "check if it works."

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

### Cluster

All assignments assume a kind cluster running rootless containerd via nerdctl.

**Single-node cluster creation:**
```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

**Multi-node cluster creation (1 control-plane, 3 workers):**
```bash
cat <<EOF | KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
EOF
```

The prompt.md specifies whether the assignment needs single-node or multi-node.

### Container images

Always use explicit version tags. Never use `:latest`. Common images used across
assignments:

- `nginx:1.25`
- `busybox:1.36`
- `alpine:3.20`
- `redis:7.2`
- `httpd:2.4`
- `curlimages/curl:8.5.0`

### Tools

- `kubectl` is the primary tool for all exercises
- `nerdctl` for container operations outside the cluster (rarely needed)
- `base64 -w0` for encoding Secret values (not `base64 | tr -d '\n'`)
- `openssl` for certificate operations in RBAC/TLS exercises

### Topic-specific environment needs

Some topics require additional cluster configuration. These are specified in the
prompt.md under "Environment requirements" and "Topic-specific conventions."
Examples:

- **Network Policies:** Requires a CNI that supports NetworkPolicy (Calico). The
  tutorial must include installation instructions since kind's default CNI (kindnet)
  does not support NetworkPolicy.
- **Ingress:** Requires an Ingress controller (nginx-ingress). The tutorial must
  include installation instructions.
- **Storage:** May need a StorageClass provisioner configured. kind includes a default
  `standard` StorageClass with the `rancher.io/local-path` provisioner.
- **RBAC:** Requires user certificate creation workflow specific to kind.
- **Metrics:** Requires metrics-server installation for `kubectl top` exercises.

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

- No conflicts between tutorial and exercises (different namespaces, different
  resource names, different user names)
- All commands must be copy-paste ready with no manual substitution
- Verification commands produce specific expected outputs, not vague "check if
  it works" instructions
- Exercises build practical muscle memory for the CKA exam, not just test knowledge
- The tutorial teaches one complete real-world workflow, not a disconnected series
  of examples
- Debugging exercises have realistic failure modes (things that actually go wrong
  in practice), not contrived typos
- Level progression is genuine: Level 1 exercises should be completable in under
  5 minutes, Level 5 exercises should take 15-20 minutes
- The answer key explains the "why" behind solutions, not just the "what"
