# CKA Exam Prep

Hands-on practice material for the Certified Kubernetes Administrator (CKA) exam, organized as a series of topic-focused assignments. Each assignment consists of a tutorial that teaches a topic end-to-end, a homework set with 15 progressive exercises, and a complete answer key. The material is designed to complement Mumshad Mannambeth's Udemy CKA course and the integrated KodeKloud labs, not replace them. The course videos teach concepts, the KodeKloud labs drill exam-style tasks, and the content in this repository provides additional deliberate practice on a cluster the learner controls.

## Context

The CKA exam is performance-based rather than multiple-choice. It gives the candidate a live Kubernetes cluster and a set of tasks to complete within two hours, with kubernetes.io/docs as the only permitted reference. Passing requires fluency with kubectl at the keyboard, not just conceptual understanding. The exercises in this repository are built to develop that fluency through repetition on a local kind cluster, with a focus on the kinds of tasks the exam actually tests (constructing pods and controllers, diagnosing failures from events and logs, configuring scheduling and resources, and recovering from broken configurations under time pressure).

All content assumes a kind cluster running rootless containerd via nerdctl. A single-node cluster is sufficient for most topics, but assignments covering scheduling, controllers, networking, and troubleshooting require a multi-node cluster (1 control-plane plus 3 workers). Setup instructions for the multi-node cluster live in the first assignment that needs them.

## CKA Exam Coverage

The assignments in this repository are organized to cover all five CKA exam domains. The `cka-homework-plan.md` file at the repo root contains the full competency coverage matrix, generation sequence, and status tracking. The summary below shows which exercise directories map to each domain.

| Domain | Weight | Exercise Directories |
|---|---|---|
| Cluster Architecture, Installation & Configuration | 25% | rbac, cluster-lifecycle, helm, kustomize, crds-and-operators |
| Workloads & Scheduling | 15% | pods (assignments 1-7) |
| Services & Networking | 20% | services, ingress-and-gateway-api, coredns, network-policies |
| Storage | 10% | storage |
| Troubleshooting | 30% | troubleshooting (assignments 1-4) |

## Repository Layout

```
cka-exam-prep/
├── CLAUDE.md                          # Claude Code project context
├── README.md                          # This file
├── LICENSE                            # Apache 2.0
├── cka-homework-plan.md               # Master plan: coverage matrix, generation sequence
│
├── skills/                            # Claude Code skills for assignment generation
│   ├── cka-prompt-builder/            # Builds scoped prompt.md files for new topics
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── cka-curriculum.md      # Official CKA domains and competencies
│   │       ├── course-section-map.md  # Mumshad course sections mapped to competencies
│   │       └── assignment-registry.md # Scope and status of all assignments
│   │
│   └── k8s-homework-generator/        # Generates tutorial, homework, and answers from a prompt
│       ├── SKILL.md
│       └── references/
│           └── base-template.md       # Structural conventions for all assignments
│
└── exercises/
    ├── pods/                          # Pod-focused series (Assignments 1-7) ✓
    │   ├── assignment-1/              # Pod Fundamentals
    │   ├── assignment-2/              # Pod Configuration Injection
    │   ├── assignment-3/              # Pod Health and Observability
    │   ├── assignment-4/              # Pod Scheduling and Placement
    │   ├── assignment-5/              # Pod Resources and QoS
    │   ├── assignment-6/              # Multi-Container Patterns
    │   └── assignment-7/              # Workload Controllers
    │
    ├── rbac/                          # RBAC, namespace-scoped ✓
    │
    ├── cluster-lifecycle/             # kubeadm, upgrades, etcd backup/restore
    ├── helm/                          # Chart install, upgrade, rollback, values
    ├── kustomize/                     # Overlays, patches, transformers, components
    ├── crds-and-operators/            # CRDs, custom resources, operator pattern
    ├── services/                      # ClusterIP, NodePort, LoadBalancer, endpoints
    ├── ingress-and-gateway-api/       # Ingress controllers, Gateway API resources
    ├── coredns/                       # DNS resolution, CoreDNS config, debugging
    ├── network-policies/              # Ingress/egress rules, namespace isolation
    ├── storage/                       # PV, PVC, StorageClass, dynamic provisioning
    │
    └── troubleshooting/               # Cross-domain capstone series
        ├── assignment-1/              # Application failures
        ├── assignment-2/              # Control plane failures
        ├── assignment-3/              # Node and kubelet failures
        └── assignment-4/              # Network and service failures
```

Directories marked with ✓ contain completed assignments. The remaining directories have planned assignments that are generated progressively as the corresponding course sections are studied.

Each assignment directory contains five files:

- `prompt.md` is the prompt used to generate the assignment content. Keeping it alongside the output makes the material reproducible and makes it obvious what was in scope (and what was deliberately deferred to later assignments).
- `README.md` is the assignment's own overview, covering prerequisites, estimated time commitment, and the recommended workflow specific to that topic.
- `<topic>-tutorial.md` is a step-by-step walkthrough teaching the topic with worked examples. This is where concepts are introduced and the reference tables live.
- `<topic>-homework.md` contains 15 progressive exercises organized into five difficulty levels (three exercises per level). Exercise headings are intentionally bare (no descriptive titles) so that debugging exercises don't leak hints about what's broken.
- `<topic>-homework-answers.md` contains complete solutions with explanations, including a common-mistakes section and a verification commands cheat sheet.

The `rbac/` directory predates the series structure and lives flat rather than under an `assignment-N/` subdirectory. It covers namespace-scoped RBAC; a future cluster-scoped RBAC assignment will likely extend that area.

## Assignment Generation

New assignments are generated using two Claude Code skills in the `skills/` directory. The `cka-prompt-builder` skill produces a scoped `prompt.md` for a topic by consulting the CKA curriculum, the Mumshad course structure, and the registry of existing assignments. The `k8s-homework-generator` skill takes that prompt and produces the four content files (README, tutorial, homework, answers) following the structural conventions documented in its base template.

The generation sequence is tied to the daily study plan. As each course section is completed, the corresponding assignments become available for generation. The `cka-homework-plan.md` file documents the full sequence and dependencies. Troubleshooting assignments are generated last because they are cross-domain capstones that combine failure modes from multiple topic areas.

For details on the generation workflow, see `CLAUDE.md`.

## Recommended Study Progression

The pod series is designed to be worked through in order. Each assignment builds on the pod spec concepts from earlier assignments and explicitly declares what it assumes and what it defers. Attempting Assignment 4 (Scheduling) without Assignment 1 (Pod Fundamentals) will still work mechanically but misses the point, which is deliberate practice of a full skill stack.

The RBAC material is independent of the pod series and can be worked through at any point after Assignment 1, since it requires only the ability to create pods for testing service account permissions.

1. **Assignment 1: Pod Fundamentals** establishes the pod spec, single and multi-container mechanics, commands and arguments, environment variables from literals, restart policy, image pull policy, and basic init containers. Everything later builds on this.
2. **Assignment 2: Pod Configuration Injection** adds ConfigMaps and Secrets, consumed as environment variables, volume mounts, and projected volumes, along with the downward API.
3. **Assignment 3: Pod Health and Observability** covers liveness, readiness, and startup probes, lifecycle hooks, termination behavior, and the diagnostic workflow for unhealthy pods.
4. **Assignment 4: Pod Scheduling and Placement** introduces the multi-node kind cluster (required from this point on for some exercises) and teaches nodeSelector, node affinity, pod affinity and anti-affinity, taints and tolerations, topology spread, and priority classes.
5. **Assignment 5: Pod Resources and QoS** covers CPU and memory requests and limits, QoS class assignment, OOMKill and throttling behavior, and namespace-level controls via LimitRange and ResourceQuota.
6. **Assignment 6: Multi-Container Patterns** teaches the sidecar, ambassador, and adapter patterns, along with native sidecars (init containers with restartPolicy: Always) and shared process namespace.
7. **Assignment 7: Workload Controllers** transitions from pods to the controllers that manage them: ReplicaSets, Deployments (including rollouts, rollbacks, and strategies), and DaemonSets.

**RBAC (namespace-scoped)** covers Roles and RoleBindings, service accounts, and the common patterns for granting scoped permissions within a namespace. A future assignment will cover cluster-scoped RBAC with ClusterRoles and ClusterRoleBindings.

After the pod series, the remaining assignments can be worked in any order that follows the generation sequence, since each is self-contained with its own tutorial. The troubleshooting series should be done last as it draws on concepts from all other topics.

## How to Work Through an Assignment

Each assignment follows the same three-phase workflow, which mirrors how the content is structured across its files.

First, read the tutorial end-to-end with a cluster open in a terminal. The tutorial teaches one or more worked examples from start to finish, and the real value comes from actually running the commands as you read rather than just reading them. Every tutorial uses a dedicated namespace (typically `tutorial-<topic>`) so it won't conflict with the homework exercises, which live in their own per-exercise namespaces. Clean up the tutorial namespace before moving to homework.

Second, work through the homework without looking at the answers. The 15 exercises are organized into five levels: Levels 1 and 2 build basic and multi-concept fluency, Level 3 is debugging broken configurations, Level 4 is realistic production-style build tasks, and Level 5 is advanced debugging and comprehensive tasks. Each exercise is self-contained with its own setup commands and its own verification commands. Debugging exercises (Levels 3 and 5) include the broken YAML in the setup so you don't have to type it; your job is to identify and fix the problem from the symptoms.

Third, compare your solutions to the answer key. The answers file is not just a reference for correct commands; the common-mistakes section captures the specific traps that this topic tends to produce, and the verification cheat sheet is meant to be skimmed and internalized. For debugging exercises, the answer key explains not just what was broken but how you would have diagnosed it from kubectl output, which is the actual exam skill.

## Conventions

The assignments use a consistent set of conventions to keep the material predictable across topics.

**Namespace isolation.** Every exercise uses its own namespace, typically named `ex-<level>-<exercise>` (for example, `ex-3-2` for the second exercise of Level 3). Tutorial content uses `tutorial-<topic>`. This prevents accidental interaction between exercises and makes cleanup straightforward.

**No latest tags.** Container images always use explicit version tags (`nginx:1.25`, `busybox:1.36`, `alpine:3.20`). The `latest` tag is explicitly avoided because it breaks rollout demonstrations and creates reproducibility problems across runs.

**Imperative and declarative both, honestly labeled.** Where imperative kubectl commands are realistic, they are shown alongside the declarative YAML. Where they are not (for instance, configuring probes, projected volumes, or affinity rules), the tutorial is explicit that declarative is the only practical path, usually by way of `kubectl run --dry-run=client -o yaml` followed by editing.

**Anti-spoiler debugging exercises.** Exercise headings in the homework files are bare (for example, `### Exercise 3.1`) rather than titled (`### Exercise 3.1: The pod with the wrong node selector`). This prevents the heading from leaking hints about the problem. Objective statements are written to describe the desired end state rather than the nature of the bug.

**base64 encoding.** When Secret values need base64 encoding, the assignments use `base64 -w0` (one step, no line wrapping) rather than `base64 | tr -d '\n'`. The latter is more error-prone and produces the same result by a longer path.

**No em dashes anywhere.** The content uses commas, periods, or parentheses instead. This is a stylistic preference that carries through the prompts and outputs consistently.

**Prose over fragmented bullets.** Explanatory sections use narrative paragraphs rather than stacked single-sentence declarations. Bullet lists appear where lists genuinely belong (verification commands, field references, failure modes to check) and not where prose would read better.

## Prerequisites

The material assumes a working local Kubernetes cluster created with kind using the rootless nerdctl provider, a current kubectl client, and familiarity with basic Linux shell usage. Specific Kubernetes version requirements are noted in individual assignment READMEs where they matter (notably, native sidecars in Assignment 6 require Kubernetes 1.29 or later).

The cluster setup command for a single-node kind cluster is:

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

The multi-node setup required from Assignment 4 onward uses a kind config file and is documented in `exercises/pods/assignment-4/README.md`.

## License

This repository is licensed under the Apache License, Version 2.0. See the `LICENSE` file for the full text. The prompts, tutorials, homework exercises, and answer keys are all covered by this license, which means they can be reused, modified, and redistributed (including for commercial purposes) with attribution. If you use this material to build your own study resources or teach others, a link back is appreciated but not required.
