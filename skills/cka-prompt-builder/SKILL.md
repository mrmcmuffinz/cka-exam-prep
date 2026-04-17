---
name: cka-prompt-builder
description: >
  Use this skill whenever the user asks to create, build, draft, or generate a homework
  prompt for a CKA exam topic. This includes requests like "build me a prompt for Network
  Policies," "what should the Storage assignment cover," "generate the next assignment
  prompt," "decompose the Helm topic into subtopics," or any reference to creating scoped
  prompts for the cka-exam-prep exercise series. Also trigger when the user asks which
  assignment to generate next, what topics are remaining, or how a CKA competency maps
  to an assignment. This skill produces prompt.md files that the k8s-homework-generator
  skill later consumes to produce the actual tutorial, homework, and answer files. Always
  read this skill before writing any prompt.md file or advising on assignment scoping.
---

# CKA Prompt Builder

## What This Skill Does

This skill produces scoped, detailed prompt files (`prompt.md`) for individual CKA
homework assignments. Each prompt defines exactly what a homework assignment should
cover, what it should exclude, and how it connects to other assignments in the series.

The prompt builder does the domain-knowledge work: it knows the CKA exam curriculum,
understands which course sections feed each topic, tracks what other assignments already
exist, and decomposes broad topics into focused, non-overlapping scopes. The user does
not need deep expertise in a topic to get a well-scoped prompt. They just need to know
the topic area and optionally which subtopics they want emphasized.

## When to Use

Trigger this skill when the user:

- Asks to create or generate a prompt for a specific CKA topic
- Asks what the next assignment to generate should be
- Asks how to decompose a broad topic (like "Networking") into assignment-sized pieces
- Asks which CKA competencies are not yet covered
- Wants to review or adjust the scope of a planned assignment before generating it
- References the assignment registry, coverage matrix, or generation sequence

## Reference Files

Read these before producing any prompt:

| File | Purpose | When to Read |
|---|---|---|
| `references/cka-curriculum.md` | Official CKA domains, competencies, and weights | Always |
| `references/course-section-map.md` | Maps Mumshad course sections to CKA competencies | Always |
| `references/assignment-registry.md` | Tracks all existing and planned assignments with scope | Always |

## Output Contract

The prompt builder produces a single file: `prompt.md`, written to the target assignment
directory (for example, `exercises/network-policies/assignment-1/prompt.md`).

The prompt.md file must contain:

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

When building a prompt, follow these steps:

1. Read all three reference files to understand the current state of the assignment corpus.

2. Identify which CKA competencies the requested topic covers by consulting
   `cka-curriculum.md`.

3. Check `assignment-registry.md` to see what adjacent assignments already cover. This
   prevents overlap. If a subtopic is already covered elsewhere, defer it explicitly in
   the "Out of scope" section with a cross-reference.

4. Consult `course-section-map.md` to identify which Mumshad course sections and lectures
   feed this topic. This helps calibrate the depth and ensures the prompt references
   concepts the learner has actually studied.

5. Decompose the topic into subtopics at the right granularity. Each subtopic should map
   to at least 2-3 exercises across the five difficulty levels. If the decomposition
   yields fewer than 8 distinct subtopics, it is likely too narrow for a standalone
   assignment. If it yields more than 20, consider splitting into multiple assignments.

6. Determine the resource gate. If the assignment unlocks before the Networking section
   (generation order 1-3 in the homework plan), list permitted resources explicitly. If
   it unlocks after, state "all CKA resources are in scope."

7. Write the prompt.md following the output contract above.

8. After writing, update `assignment-registry.md` to reflect the new prompt's scope.

## Quality Checks

Before finalizing a prompt, verify:

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
