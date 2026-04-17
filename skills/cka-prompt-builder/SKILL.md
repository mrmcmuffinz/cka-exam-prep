---
name: cka-prompt-builder
description: >
  Use this skill whenever the user asks to create, build, draft, or generate a homework
  prompt for a CKA exam topic, or to scope out how many assignments a topic needs. This
  includes requests like "build me a prompt for Network Policies," "scope out the Storage
  topic," "how many assignments does Networking need," "what should the Storage assignment
  cover," "generate the next assignment prompt," or any reference to creating scoped
  prompts for the cka-exam-prep exercise series. Also trigger when the user asks which
  assignment to generate next, what topics are remaining, or how a CKA competency maps
  to an assignment. This skill produces topic-level README.md files (scoping) and
  assignment-level prompt.md files (detailed specs) that the k8s-homework-generator
  skill later consumes. Always read this skill before writing any README.md or prompt.md
  file or advising on assignment scoping.
---

# CKA Prompt Builder

## What This Skill Does

This skill handles two related tasks in the assignment generation pipeline:

1. **Topic scoping:** Produces a topic-level `README.md` at `exercises/<topic>/README.md`
   that determines how many assignments a topic needs and describes what each one covers
   at a high level.

2. **Prompt writing:** Produces detailed `prompt.md` files for individual assignments
   within a topic, specifying exact subtopics, resource gates, and exercise conventions.

The prompt builder does the domain-knowledge work: it knows the CKA exam curriculum,
understands which course sections feed each topic, tracks what other assignments already
exist, and decomposes broad topics into focused, non-overlapping scopes. The user does
not need deep expertise in a topic to get a well-scoped prompt. They just need to know
the topic area and optionally which subtopics they want emphasized.

## When to Use

Trigger this skill when the user:

- Asks to scope out a topic ("how many assignments does Networking need")
- Asks to create or generate a prompt for a specific CKA topic
- Asks what the next assignment to generate should be
- Asks how to decompose a broad topic into assignment-sized pieces
- Asks which CKA competencies are not yet covered
- Wants to review or adjust the scope of a planned assignment before generating it
- References the assignment registry, coverage matrix, or generation sequence

## Reference Files

Read these before producing any topic README or prompt:

| File | Purpose | When to Read |
|---|---|---|
| `references/cka-curriculum.md` | Official CKA domains, competencies, and weights | Always |
| `references/course-section-map.md` | Maps Mumshad course sections to CKA competencies | Always |
| `references/assignment-registry.md` | Tracks all existing and planned assignments with scope | Always |

## Two-Step Output

### Step 1: Topic README (scoping)

The topic README lives at `exercises/<topic>/README.md` and is the authoritative
document for how a topic is decomposed into assignments. It must be produced (or
confirmed to exist) before any prompt.md is written for that topic.

The topic README must contain:

1. **Topic title and CKA domain mapping** with the specific competencies covered
2. **Rationale for the number of assignments** explaining why the topic warrants
   one, two, or more assignments. The rationale should reference the subtopic count,
   the breadth of the CKA competencies involved, and whether natural breakpoints
   exist in the material.
3. **Assignment summary table** listing each assignment with a short description of
   what it covers and its prerequisites
4. **Scope boundaries** stating what is explicitly not covered by this topic and
   which other topic handles it
5. **Cluster requirements** noting whether assignments in this topic need single-node
   or multi-node kind clusters, any special configuration (CNI, ingress controller, etc.)
6. **Recommended order** if assignments within the topic build on each other

**Sizing guidance for the decomposition:**

- Each assignment produces 15 exercises across five difficulty levels (3 per level).
- Each distinct subtopic should map to at least 2-3 exercises.
- A topic with 8-15 distinct subtopics fits naturally into one assignment.
- A topic with 16-25 subtopics should split into two assignments.
- A topic with 25+ subtopics should split into three or more assignments.
- Natural breakpoints matter more than raw subtopic counts. If a topic has 14
  subtopics but half are conceptually independent from the other half, two focused
  assignments are better than one sprawling one.
- When in doubt, prefer fewer, denser assignments over many thin ones.

### Step 2: Assignment Prompt (detailed spec)

The prompt lives at `exercises/<topic>/assignment-N/prompt.md` and defines exactly
what a single assignment should cover. The prompt builder writes this only after the
topic README exists and the number of assignments has been determined.

The prompt.md must contain:

1. **Header block** with assignment metadata (series name, assignment number, prerequisites,
   CKA domain and competencies covered, course sections referenced)

2. **Scope declaration** with two clearly separated sections:
   - "In scope for this assignment" listing every subtopic, concept, and kubectl skill
     that exercises should cover, organized by logical grouping
   - "Out of scope" listing related topics explicitly deferred to other assignments,
     with forward references to which assignment covers them

3. **Environment requirements** specifying whether the assignment needs a single-node or
   multi-node kind cluster, any special kind configuration, and any tools beyond kubectl

4. **Resource gate** listing which Kubernetes resource types exercises are permitted to
   use. For assignments early in the course, this is a restricted list. For assignments
   after the Networking section, this is "all CKA resources."

5. **Topic-specific conventions** capturing anything unique to this topic that the
   homework generator needs to know (for example, RBAC assignments need user/certificate
   creation instructions for kind clusters, Storage assignments need StorageClass
   provisioner setup, Networking assignments need a CNI that supports NetworkPolicy)

6. **Cross-references** with backward references to prerequisites ("this assignment
   assumes the learner has completed...") and forward references to future assignments
   ("the following topics are deferred to...")

## Prompt Construction Process

When building a topic README or prompt, follow these steps:

1. Read all three reference files to understand the current state of the assignment corpus.

2. Identify which CKA competencies the requested topic covers by consulting
   `cka-curriculum.md`.

3. Check `assignment-registry.md` to see what adjacent assignments already cover. This
   prevents overlap. If a subtopic is already covered elsewhere, defer it explicitly
   with a cross-reference.

4. Consult `course-section-map.md` to identify which Mumshad course sections and lectures
   feed this topic. This helps calibrate the depth and ensures the prompt references
   concepts the learner has actually studied.

5. **For topic READMEs:** Enumerate all subtopics for the topic, count them, identify
   natural breakpoints, and determine the number of assignments. Write the topic README
   with the rationale and assignment summary.

6. **For prompts:** Decompose the assignment's portion of the topic into subtopics at
   exercise granularity. Each subtopic should map to at least 2-3 exercises across the
   five difficulty levels.

7. Determine the resource gate. If the assignment unlocks before the Networking section
   (generation order 1-6 in the homework plan), list permitted resources explicitly. If
   it unlocks after, state "all CKA resources are in scope."

8. Write the file following the output contract above.

9. After writing, update `assignment-registry.md` to reflect any new information.

## Quality Checks

Before finalizing a topic README, verify:

- The subtopic count justifies the proposed number of assignments
- The assignment summary table accounts for all CKA competencies the topic covers
- Scope boundaries clearly state what is not covered and where it lives
- No overlap with other topic READMEs

Before finalizing a prompt, verify:

- The topic README exists and the prompt is consistent with its assignment summary
- Every CKA competency listed in the header block has at least one matching subtopic
  in the scope declaration
- No subtopic overlaps with an existing assignment's scope (check the registry)
- The resource gate is consistent with the assignment's position in the generation sequence
- Forward and backward references point to real assignments that exist or are planned
- The scope is large enough for 15 exercises across five levels but not so large that
  it would require more than one assignment
- Topic-specific conventions include everything the homework generator would need to
  know that is not in the base template (environment setup, special tools, gotchas)

## Conventions

- No em dashes anywhere. Use commas, periods, or parentheses.
- Narrative paragraph flow in prose sections, not stacked single-sentence declarations.
- Use the same topic slug for directory names and file prefixes (for example,
  "network-policies" in both the directory path and the file names).
- Subtopic lists in the scope declaration should be grouped logically and use italicized
  group headers, matching the format established in the pod series prompts.
