# CLAUDE.md

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
- `LICENSE` is Apache 2.0.

## Skills

Two skills in `skills/` support the assignment generation pipeline.

### cka-prompt-builder

Produces scoped `prompt.md` files for new assignments. It knows the CKA exam curriculum,
the Mumshad course structure, and what assignments already exist. Use it when the user
asks to build, create, or generate a prompt for a topic.

Reference files in `skills/cka-prompt-builder/references/`:
- `cka-curriculum.md` has the five CKA domains, their competencies, and exam weights.
- `course-section-map.md` maps Mumshad course sections (S1-S18) to CKA competencies.
- `assignment-registry.md` tracks every existing and planned assignment with its scope,
  deferrals, and cross-references. Update this file after generating a new prompt.

### k8s-homework-generator

Takes a `prompt.md` and produces four content files (README.md, tutorial, homework,
answers). It encodes all structural conventions: difficulty levels, anti-spoiler rules,
exercise format, environment assumptions.

Reference file in `skills/k8s-homework-generator/references/`:
- `base-template.md` has the full structural contract for assignment output.

### Generation Workflow

1. User asks for a prompt on a topic (for example, "build a prompt for Network Policies").
2. The `cka-prompt-builder` skill reads its three reference files and produces a
   `prompt.md` in the target directory (for example,
   `exercises/network-policies/assignment-1/prompt.md`).
3. User reviews and approves the prompt.
4. The `k8s-homework-generator` skill reads the prompt.md and `base-template.md`, then
   produces four files in the same directory.
5. Update `assignment-registry.md` to reflect the new assignment's status.

## Directory Structure

```
exercises/                          All homework assignments
  pods/assignment-1/ through 7/     Pod-focused series (complete)
  rbac/assignment-1/                RBAC namespace-scoped (complete)
  rbac/assignment-2/                RBAC cluster-scoped (planned)
  tls-and-certificates/             TLS, PKI, Certificates API (planned)
  security-contexts/                runAsUser, capabilities, seccomp (planned)
  cluster-lifecycle/                kubeadm, upgrades, etcd backup/restore (planned)
  helm/                             Chart install, upgrade, rollback, values (planned)
  kustomize/                        Overlays, patches, transformers, components (planned)
  crds-and-operators/               CRDs, custom resources, operator pattern (planned)
  services/                         ClusterIP, NodePort, LoadBalancer, endpoints (planned)
  ingress-and-gateway-api/          Ingress controllers, Gateway API resources (planned)
  coredns/                          DNS resolution, CoreDNS config, debugging (planned)
  network-policies/                 Ingress/egress rules, namespace isolation (planned)
  storage/                          PV, PVC, StorageClass, dynamic provisioning (planned)
  troubleshooting/assignment-1-4/   Cross-domain capstone series (planned, generate last)
skills/                             Claude Code skills for generation
```

Each assignment directory contains five files: `prompt.md` (the generation input),
`README.md`, `<topic>-tutorial.md`, `<topic>-homework.md`, `<topic>-homework-answers.md`.

## Environment

- Kind cluster with rootless containerd via nerdctl (not Docker)
- Single-node cluster for most topics, multi-node (1 control-plane, 3 workers) for
  scheduling, controllers, networking, and troubleshooting
- `KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster` for cluster creation

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

## Existing Content

The pod series (assignments 1-7) and RBAC assignment-1 were generated before the skills
existed, using standalone prompts. They follow the same conventions the skills encode.
Do not regenerate them through the skills. The assignment registry documents their
scope so new assignments avoid overlap.

## Generation Sequence

The `cka-homework-plan.md` file defines the recommended order for generating remaining
assignments, tied to the daily study plan. Security topics (TLS, cluster-scoped RBAC,
security contexts) are distributed across domains rather than grouped into a single
series. Troubleshooting assignments are generated last because they are cross-domain
capstones.
