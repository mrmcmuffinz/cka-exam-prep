# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a CKA (Certified Kubernetes Administrator) exam prep repository containing
hands-on homework assignments. Each assignment consists of a tutorial, a set of 15
progressive exercises, and a complete answer key. The material complements the Mumshad
Mannambeth Udemy CKA course and KodeKloud labs.

## Key Files

- `cka-homework-plan.md` is the master plan. It maps every CKA exam competency to an
  assignment, tracks what has been generated, and defines the generation sequence. Read
  this first when deciding what to work on next.
- `README.md` is the public-facing repo overview for learners.
- `docs/audit-findings.md` and `docs/remediation-plan.md` capture the ongoing audit and
  the phased plan for improving the assignment corpus. Read these when deciding what
  work remains and in what sequence.
- `docs/cluster-setup.md` is the single source of truth for kind cluster configurations
  and the component version matrix. Assignment READMEs and tutorials reference sections
  of this document by anchor rather than inlining cluster commands.
- `LICENSE` is Apache 2.0.

## Skills

Two skills in `.claude/skills/` support the assignment generation pipeline.

### cka-prompt-builder

Produces topic-level README.md files (scoping how many assignments a topic needs) and
assignment-level prompt.md files (detailed specs for each assignment). It knows the CKA
exam curriculum, the Mumshad course structure, and what assignments already exist. Use
it when the user asks to scope out a topic or build a prompt for a specific assignment.

Reference files in `.claude/skills/cka-prompt-builder/references/`:
- `cka-curriculum.md` has the five CKA domains, their competencies, and exam weights.
  Kept current against `github.com/cncf/curriculum` (v1.35 as of 2026-04-18).
- `course-section-map.md` maps Mumshad course sections (S1-S18) to CKA competencies.
- `assignment-registry.md` tracks every existing and planned assignment with its scope,
  deferrals, and cross-references. Update this file after generating a new prompt.

### k8s-homework-generator

Takes a `prompt.md` and produces four content files (README.md, tutorial, homework,
answers). It encodes all structural conventions: difficulty levels, anti-spoiler rules,
exercise format, environment assumptions.

Reference file in `.claude/skills/k8s-homework-generator/references/`:
- `base-template.md` has the full structural contract for assignment output with hard
  gates on README shape, narrative prose, resource documentation, debugging answer
  structure, Common Mistakes section, verification form, and exercise task types.

### How to Invoke Skills

Skills are invoked using the `/` prefix in Claude Code:

- `/cka-prompt-builder` - Scope a topic or build a prompt for an assignment
- `/k8s-homework-generator` - Generate the four content files from a prompt

Example workflow:
```
User: "Scope out the Network Policies topic"
→ /cka-prompt-builder reads references, produces exercises/network-policies/README.md

User: "Generate prompt for Network Policies assignment 1"
→ /cka-prompt-builder produces exercises/network-policies/assignment-1/prompt.md

User: "Generate the assignment from that prompt"
→ /k8s-homework-generator produces the 4 content files
```

### Generation Workflow

1. User asks to scope out a topic (for example, "scope out Network Policies").
2. The `cka-prompt-builder` skill reads its reference files and produces a topic-level
   `README.md` at `exercises/<topic>/README.md` that determines how many assignments
   the topic needs and what each covers at a high level.
3. User reviews and approves the scoping.
4. User asks for a prompt for a specific assignment (for example, "generate the prompt
   for Network Policies assignment 1").
5. The `cka-prompt-builder` skill produces a `prompt.md` in the target directory.
6. User reviews and approves the prompt.
7. The `k8s-homework-generator` skill reads the prompt.md and `base-template.md`, then
   produces four files in the same directory.
8. Update `assignment-registry.md` to reflect the new assignment's status.

## Directory Structure

```
exercises/                          All homework assignments (content state as of 2026-04-18)
  pods/assignment-1/ through 7/     Pod-focused series (content complete)
  rbac/assignment-1/ and 2/         RBAC namespace- and cluster-scoped (content complete)
  tls-and-certificates/1-3          K8s PKI, cert creation, Certificates API (content complete)
  security-contexts/1-3             runAsUser, capabilities, seccomp (content complete)
  cluster-lifecycle/1-3             kubeadm, upgrades, etcd (content complete, Phase 4 regen scheduled)
  helm/1-3                          Chart install, upgrade, rollback, templates (content complete)
  kustomize/1-3                     Overlays, patches, transformers (content complete)
  crds-and-operators/1-3            CRDs, custom resources, operators (content complete)
  services/1-3                      ClusterIP, NodePort, LoadBalancer, patterns (content complete)
  ingress-and-gateway-api/1-5       Ingress v1 and Gateway API (1-3 content complete, 4-5 pending; all restructured per D8)
  coredns/1-3                       DNS, CoreDNS config, debugging (content complete)
  network-policies/1-3              Ingress/egress rules, debugging (content complete)
  storage/1-3                       PV, PVC, StorageClass (content complete, Phase 4 regen scheduled)
  troubleshooting/1-4               Cross-domain capstone series (content complete, Phase 4 regen scheduled for /2 and /4)
  jobs-and-cronjobs/1               Batch workloads (prompt in place, content pending)
  autoscaling/1                     HPA, VPA, in-place pod resize (prompt in place, content pending)
  statefulsets/1                    Stateful workloads (prompt in place, content pending)
  admission-controllers/1           Built-ins and ValidatingAdmissionPolicy (prompt in place, content pending)
  pod-security/1                    Pod Security Standards and PSA (prompt in place, content pending)

.claude/skills/                     Claude Code skills for assignment generation
docs/                               Audit, remediation plan, cluster setup recipes
```

Each topic directory contains a topic-level `README.md` that scopes the number of
assignments and what each covers. Each assignment subdirectory contains five files:
`prompt.md` (the generation input), `README.md` (assignment overview for the learner),
`<topic>-tutorial.md`, `<topic>-homework.md`, `<topic>-homework-answers.md`. New
topics scoped in Phase 3 currently have only `README.md` and `prompt.md`; the four
content files are produced in Phase 4 of the remediation plan.

## Environment

- Kind cluster with rootless containerd via nerdctl (not Docker)
- Exam target Kubernetes version: v1.35 (per `CKA_Curriculum_v1.35.pdf`)
- Single-node cluster for most topics; multi-node (1 control-plane, 3 workers) for
  scheduling, controllers, networking, and troubleshooting
- All cluster creation commands and component install commands are documented in
  `docs/cluster-setup.md` with pinned versions verified against upstream
  documentation

## Common Tasks

- **Find the next piece of work**: Read `docs/remediation-plan.md` for phase-level
  status and task-level detail, or `cka-homework-plan.md` for the high-level
  coverage matrix.
- **Scope a new topic**: Use `/cka-prompt-builder` with the topic name.
- **Generate an assignment**: First create the prompt (if not present), then run
  `/k8s-homework-generator`.
- **Update the registry**: After generating, edit
  `.claude/skills/cka-prompt-builder/references/assignment-registry.md`.
- **Test an assignment**: Create the required cluster per `docs/cluster-setup.md`.
- **Verify an external component version**: Fetch the project's official releases
  page or documentation; do not rely on general knowledge (per `docs/remediation-plan.md`
  decision D7).

## Conventions

- No em dashes anywhere. Use commas, periods, or parentheses.
- Narrative paragraph flow in prose, not stacked single-sentence bullets.
- All Markdown, no other document formats.
- Container images use explicit version tags, never `:latest`.
- `base64 -w0` for Secret encoding.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern (for example, `ex-3-2`).
- Tutorial namespaces follow `tutorial-<topic>` pattern.
- Debugging exercise headings are bare (`### Exercise 3.1`) with no descriptive titles
  that would hint at the problem.
- Full file replacements when updating, never patches or diffs.
- **Resource gates** constrain which Kubernetes objects exercises can reference. Early
  assignments (before Networking) use explicit allowlists. Later assignments have access
  to all CKA resources. This prevents exercises from assuming knowledge the learner
  doesn't yet have.

## Existing Content and Quality Bar

The pod series (assignments 1-7) and RBAC assignment-1 were generated before the skills
existed, using standalone prompts. They follow the conventions the skills now encode
and are the reference quality bar: `pods/assignment-1` is named in `base-template.md`
as the canonical reference for README shape, tutorial narrative style, and answer-key
debugging structure. Do not regenerate these through the skills.

Other assignments across the 13 skill-generated topics (cluster-lifecycle, tls-and-
certificates, security-contexts, crds-and-operators, storage, services, coredns,
network-policies, ingress-and-gateway-api, helm, kustomize, rbac/2, troubleshooting)
are generated content that may be regenerated against the stricter hard gates added
in Phase 2. The `docs/remediation-plan.md` Phase 4 task list specifies which
assignments are queued for regeneration.

## Generation Sequence

The original `cka-homework-plan.md` Generation Sequence is now historical; all 38
assignments from the original scope are generated. The current plan of work is driven
by `docs/remediation-plan.md`. Phase 4 covers regeneration of under-delivering
existing assignments plus content generation for the five new topics and ingress
assignments 4-5.
