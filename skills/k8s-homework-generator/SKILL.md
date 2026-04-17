---
name: k8s-homework-generator
description: >
  Use this skill whenever the user asks to generate, create, or build a Kubernetes
  homework assignment from a prompt. This includes requests like "generate the
  assignment from this prompt," "create the homework files," "build the tutorial and
  exercises for Network Policies," or any reference to producing the four-file
  assignment output (README, tutorial, homework, answers). Also trigger when the user
  asks to regenerate or update an existing assignment's content files. This skill
  reads a prompt.md file (produced by the cka-prompt-builder skill) and generates the
  four deliverable files in the same directory. Always read this skill and its base
  template before generating any assignment files.
---

# Kubernetes Homework Generator

## What This Skill Does

This skill takes a scoped prompt (a `prompt.md` file) and produces four structured
files that together form a complete homework assignment for CKA exam preparation.
The prompt defines what to cover. This skill defines how to structure, format, and
present that content.

## When to Use

Trigger this skill when the user:

- Asks to generate assignment files from an existing prompt.md
- Asks to create a tutorial, homework, or answer key for a Kubernetes topic
- Asks to regenerate or update the content files for an existing assignment
- References the base template, exercise structure, or four-file output format
- Provides a prompt (inline or as a file) and wants the assignment content produced

## Reference Files

Read this before generating any assignment:

| File | Purpose | When to Read |
|---|---|---|
| `references/base-template.md` | Structural conventions, exercise format, difficulty levels, environment setup, formatting rules | Always |

## Input

The generator expects a `prompt.md` file in the target assignment directory. This file
is produced by the `cka-prompt-builder` skill and contains:

- Assignment metadata (series, number, prerequisites, CKA domain)
- Scope declaration (in-scope subtopics, out-of-scope deferrals)
- Environment requirements (single-node vs multi-node kind cluster)
- Resource gate (which Kubernetes objects exercises may use)
- Topic-specific conventions
- Cross-references to other assignments

If no prompt.md exists, ask the user to run the prompt builder first or provide the
scope inline.

## Output Contract

The generator produces four files in the same directory as the prompt.md:

| File | Purpose |
|---|---|
| `README.md` | Assignment overview, prerequisites, estimated time, recommended workflow |
| `<topic>-tutorial.md` | Step-by-step tutorial teaching one complete real-world workflow |
| `<topic>-homework.md` | 15 progressive exercises across five difficulty levels |
| `<topic>-homework-answers.md` | Complete solutions with explanations |

The `<topic>` slug must match the directory name (for example, `network-policies`
produces `network-policies-tutorial.md`).

## Generation Process

1. Read the base template from `references/base-template.md` to load all structural
   conventions.

2. Read the prompt.md for this assignment to understand scope, resource gate, and
   topic-specific conventions.

3. Generate the four files in this order:
   - README.md (quick to produce, establishes context)
   - Tutorial (teaches the topic, creates the reference material for exercises)
   - Homework (15 exercises, must not conflict with tutorial resources)
   - Answers (solutions for all 15 exercises, common mistakes, cheat sheet)

4. Write all four files to the assignment directory (for example,
   `exercises/network-policies/assignment-1/`).

## Quality Checks

Before finalizing output, verify:

- All four files are present and non-empty
- Tutorial uses its own namespace (`tutorial-<topic>`) and resource names that
  do not conflict with any exercise
- Every exercise has setup commands, task description, and verification commands
- Debugging exercises (Levels 3 and 5) have anti-spoiler headings (no descriptive
  titles, no bug count in objectives)
- No exercise uses Kubernetes resources outside the prompt's resource gate
- All container images use explicit version tags (no `:latest`)
- No em dashes anywhere in any file
- Verification commands produce specific expected outputs (yes/no answers),
  not vague instructions like "check if it works"
- Exercise namespaces are unique across all 15 exercises (ex-1-1 through ex-5-3)
- Different user/resource names per exercise (no reuse of alice, bob, etc. across exercises)

## Conventions

All conventions are documented in detail in `references/base-template.md`. The key
points are summarized here for quick reference:

- **Difficulty levels:** 5 levels, 3 exercises each, progressive complexity
- **Anti-spoiler:** Bare exercise headings, no bug counts in objectives
- **Environment:** kind cluster with rootless nerdctl (not Docker)
- **Encoding:** `base64 -w0` for Secrets
- **Images:** Explicit version tags, never `:latest`
- **Formatting:** No em dashes, narrative prose over bullet stacks, Markdown only
- **Namespaces:** `tutorial-<topic>` for tutorial, `ex-<level>-<exercise>` for homework
- **File format:** Markdown with fenced code blocks, self-contained per file
