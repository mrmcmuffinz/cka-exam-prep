# Repository Audit Findings

**Audit date:** 2026-04-18
**Scope:** Full repository (infrastructure, skills, all 40 assignments across 14 topics)
**Method:** Read the infrastructure files (`CLAUDE.md`, `README.md`, `cka-homework-plan.md`,
devcontainer files, both `SKILL.md` files, all three reference files), all 14 topic-level
READMEs, both hand-crafted series (pods 1-7 and rbac/assignment-1) in depth, and
representative assignments from each of the 13 skill-generated topics.

---

## Context and Assumptions

The following assumptions shaped the audit. All were confirmed by the repo owner.

1. The primary consumer is the repo owner (Abe), who is the first user.
2. The open-source release is planned. Quality bar raised accordingly (future contributors
   will read this material).
3. The two-skill pipeline (`cka-prompt-builder` and `k8s-homework-generator`) is the intended
   tooling and stays.
4. The hand-crafted pod series (assignments 1-7) and `rbac/assignment-1` are the intended
   quality bar; everything else should aspire to match.
5. Recent batch-merge commits indicate the current state is the "completed" state, not a
   work-in-progress snapshot.
6. The preferred fix path is skill-based automation, with manual edits accepted for
   typos or infra files.
7. The `tmux` addition in `.devcontainer/Dockerfile` was for experimenting with Claude Code
   sub-agents. Not a priority; small change; fine to commit as-is.

---

## 1. Organization

### What is working

- Top-level layout is clean: `skills/`, `exercises/`, `cka-homework-plan.md`, `README.md`,
  `CLAUDE.md` are all where you would expect.
- Five-file assignment contract (`prompt.md`, `README.md`, `<topic>-tutorial.md`,
  `<topic>-homework.md`, `<topic>-homework-answers.md`) is consistent across all 40
  assignment directories.
- Topic-level READMEs exist for every topic and document rationale, scope boundaries,
  cluster requirements, and recommended order.
- The two-skill pipeline is well-designed in principle: scoping precedes generation, the
  registry is meant to prevent overlap, resource gates enforce curricular order, and
  `base-template.md` defines a real structural contract.

### Issues

**O1. Inconsistent assignment-level README formats.**
The pod series alone uses three different shapes:
- Narrative prose: assignments 1, 2, 3
- Metadata header block with table-heavy format: assignments 4, 7
- Mixed: assignments 5, 6

Skill-generated topics then diverge again: `helm/*`, `kustomize/*` follow a narrative
style, while `rbac/assignment-2`, `storage/*`, `security-contexts/*`, `troubleshooting/2`,
and `troubleshooting/4` are terse stubs.

A learner flipping between topics hits a different document shape each time.

**O2. Bug in `pods/assignment-6/README.md` line 3.**
Says `Series: CKA Pod-Focused Assignments (6 of 6)`. Should be `(6 of 7)` because there
are 7 pod assignments (assignment-7 exists).

**O3. Only three of the seven pod assignments use the `Series:` metadata header.**
Assignments 4, 6, 7 use it. The other four do not. No convention is chosen.

**O4. `assignment-registry.md` is stale.**
Contains 39 occurrences of "Planned" for assignments that now exist
(cluster-lifecycle/1-3, tls/1-3, rbac/2, security-contexts/1-3, crds/1-3, storage/1-3,
services/1-3, coredns/1-3, network-policies/1-3, ingress/1-3, helm/1-3, kustomize/1-3,
troubleshooting/1-4).

The `cka-homework-plan.md` Status Summary says `Completed: 8 (pods 1-7, rbac/assignment-1)`
which is also stale. The CLAUDE.md skill workflow step 8 instructs the generator to
"update `assignment-registry.md` to reflect the new assignment's status" but this did
not happen for the batch-merged assignments.

**O5. Unused scaffolding.**
`.claude/worktrees/` exists and is empty. `settings.local.json` allow-lists `git worktree`
commands. Either the worktree workflow should be documented or the directory removed.

**O6. Uncommitted `.devcontainer/Dockerfile` change.**
Adds `tmux`. Small, intentional, fine to commit.

---

## 2. Usability

### What is working

- Copy-paste-ready setup in every exercise (namespace + manifest + verification).
- Namespace isolation (`ex-<level>-<exercise>`) is consistent across all assignments.
- Global cleanup loops are included at the top and bottom of most homework files.
- `kubectl auth can-i --as=USER` in RBAC is a smart simplification for exercises.
- Anti-spoiler conventions (bare `### Exercise X.Y` headings, objectives phrased as
  desired end state) are mostly followed.

### Issues

**U1. Setup boilerplate is duplicated ~65 times.**
`KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster` appears in 63 files. The
multi-node kind config block is inlined dozens of times. Calico install is inlined in
six files. metallb install is inlined in service READMEs. If Kubernetes versions bump
or a URL changes, every file needs an update.

**U2. Calico version drift.**
- `v3.27.0` in `network-policies/assignment-1` and `/assignment-2` tutorials
- `v3.26.1` in `troubleshooting/assignment-4` README and `network-policies/assignment-3`
  homework answers

Different exercises may exhibit different behavior because of CNI version differences.

**U3. Unpinned `ingress-nginx/main` URL.**
Three files in `exercises/ingress-and-gateway-api/assignment-1/` apply
`https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml`.
The `main` branch can move unpredictably.

**U4. Verification commands vary in rigor.**
Four observed patterns:
- Best (RBAC style): `kubectl auth can-i delete pods -n ex-1-1 --as=alice         # expect: no`
- Good (pods style): specific jsonpath with explicit expected value
- Problematic (cluster-lifecycle style): `... | grep -q "4" && echo "Manifest count: SUCCESS" || echo "Manifest count: FAILED"`
  checks presence, not correctness; "SUCCESS" can appear when the test is meaningless.
- Fragile (network-policies style): `timeout 3 kubectl exec ... || echo "BLOCKED"`
  fires on any non-zero exit, not just the timeout case.

**U5. Some exercises are not exam-realistic.**
The CKA is performance-based: "create X, fix Y, verify Z." Several skill-generated
exercises drift into "read and document":
- `cluster-lifecycle/assignment-1` Exercise 1.1: "For each manifest, identify ... Document
  your findings." This is reading, not practice.
- `crds-and-operators/assignment-1` Exercise 1.2: "List and describe CRDs in the cluster"
  is trivially easy and does not build a skill.

**U6. `troubleshooting/assignment-1` Exercise 1.2 has ambiguous scope.**
Setup creates a pod referencing a missing PVC and a command that reads a non-existent
file. Objective says "stuck in Pending" (PVC issue), but the answer key fixes both. The
exercise is labeled Level 1 "single, clear failure" but actually has two.

**U7. `storage/assignment-1` answer key duplicates every YAML block twice.**
Once for display, once inside a `kubectl apply -f - <<EOF` heredoc. Two sources of truth
diverge over time. Pod series answers (e.g., 3.1) show one canonical form.

**U8. Cluster-lifecycle is conceptually awkward given Kind's kubeadm abstraction.**
Kind abstracts kubeadm, so the exercises are all "exec into the container and look at
files." Reasonable as exposure but does not build the muscle memory the CKA exam tests.
The prompt and README acknowledge this honestly, but the topic under-delivers on its
domain regardless.

---

## 3. Explainability

### What is working

- Hand-crafted pod and rbac tutorials are genuinely excellent.
  `pods/assignment-1/pod-fundamentals-tutorial.md` walks through defaults
  (`restartPolicy: Always`, `imagePullPolicy: IfNotPresent`, `terminationGracePeriodSeconds: 30`)
  and explains why `command: ["sh", "-c"]` is necessary for `&&` to work.
- `base-template.md` encodes the right conventions: narrative flow, anti-spoiler headings,
  specific expected outputs, `base64 -w0`, explicit tags.
- Scope declarations in prompts are disciplined: in-scope vs. out-of-scope lists with
  forward references.
- `pods/assignment-1` answer key explains diagnostic workflow, not just solutions. The
  "Common Mistakes" section is exam-grade material.

### Issues

**E1. Large quality gap between hand-crafted and skill-generated content.**
Compare `rbac/assignment-1/rbac-tutorial.md` (narrative, builds mental model of auth vs
authz, explains CN/O certificate convention) against `rbac/assignment-2/rbac-tutorial.md`
(short facts, bullet-heavy, reads like a reference card). The base-template's "narrative
paragraph flow" rule is not being enforced by the generator.

**E2. Skill-generated answer keys explain what, not why.**
`troubleshooting/assignment-1` Exercise 1.1 answer: "The command has a syntax error:
`daemon off` should be `daemon off;` (missing semicolon)." That is the fix but not the
diagnosis. The pod/assignment-1 answer for exercise 3.2 (identical class of bug, wrong
`command` structure) walks through `kubectl get pod`, `kubectl describe`, and explains
why the runtime tries to exec a literal binary. That reasoning is what an exam candidate
needs to internalize.

**E3. Tutorials often skip the "why behind the default."**
Skill-generated tutorials list fields and types; they rarely explain what happens if you
do not set the field. Example: `security-contexts/assignment-1` homework asks you to use
`runAsNonRoot` but the tutorial does not explain what error Kubernetes surfaces when a
container image has UID 0 and `runAsNonRoot: true` is set (it is
`CreateContainerConfigError`).

**E4. Some skill-generated READMEs are reference stubs.**
`troubleshooting/assignment-2` and `/assignment-4` READMEs are roughly 30 lines each,
with no recommended workflow, no explanation of what makes control-plane troubleshooting
different from application troubleshooting, no motivation for the Kind-specific caveats.
This is insufficient given Troubleshooting is 30% of the exam.

**E5. Common Mistakes sections are inconsistent.**
Pod/assignment-1 has seven deeply-reasoned common mistakes (command vs args, restartPolicy
with init containers, `:latest` tags, and so on). Storage/assignment-1 and several others
have none or one-liners.

**E6. Downward API label syntax not reinforced.**
The pod tutorial teaches `metadata.labels['key']` works and `metadata.labels.key` does not.
Only the pod series covers this gotcha. If the pattern reappears in later assignments, the
corresponding tutorials should reinforce it.

**E7. Cross-references are frozen at generation time.**
Many assignments reference other assignments by path. Those paths now exist, but the
reference was written when the target was planned. Backward references to prerequisites
should be verified.

---

## 4. CKA Curriculum Coverage Gaps

The registry, plan, and assignment scope boundaries reference topics that are deferred
but never picked up by another assignment. Grep evidence was collected to confirm each gap.

### High priority

**G1. Workload autoscaling (HPA, VPA, in-place pod resize).**
- Domain 2 competency #3 in `cka-curriculum.md`.
- `pods/assignment-5/prompt.md` line 45 explicitly defers HPA and VPA elsewhere, but
  nothing else in the repo practices them.
- `exercises/pods/README.md` line 36 claims Assignment 5 covers "autoscaling (HPA, VPA)"
  which contradicts the prompt. Documentation and content disagree.
- In-place pod resize (Kubernetes 1.33 feature, on the curriculum) is mentioned but not
  practiced.

**G2. Jobs and CronJobs.**
- Zero assignments have `kind: Job` or `kind: CronJob` (confirmed by grep).
- `pods/assignment-7` README lists them as "natural next topics" but no assignment covers
  them.
- Backoff limits, completions, parallelism, schedule, and history limits are not practiced.

**G3. Admission controllers.**
- `cka-curriculum.md` Domain 2 competency #5 lists validating and mutating admission
  controllers.
- Only two files mention them (forward-reference stubs in `pods/assignment-3/README.md`
  and `pods/assignment-4/README.md`). Neither practices `ValidatingAdmissionPolicy`,
  `MutatingWebhookConfiguration`, or `ValidatingWebhookConfiguration`.
- CEL-based `ValidatingAdmissionPolicy` (GA in 1.30) is not covered.

**G4. `kubectl debug` and ephemeral containers.**
- No mentions anywhere in the repo.
- `kubectl debug` is the modern technique for attaching a debug container to a running
  pod or a node; CKA expects familiarity.

### Medium priority

**G5. StatefulSets.**
- Zero files have `kind: StatefulSet` (confirmed by grep).
- `exercises/storage/README.md` line 29 explicitly says "not currently in scope for CKA
  assignments, may be added if exam coverage warrants it."
- StatefulSets appear on the CKA exam regularly (stable identity, `volumeClaimTemplates`,
  headless service, ordered deployment, PDB interaction).

**G6. Pod Security Standards and Pod Security Admission.**
- Explicitly deferred in `exercises/security-contexts/assignment-2/prompt.md` line 59 and
  `assignment-3/prompt.md` line 65 as "not in current CKA scope."
- The 2025 CKA curriculum update moved PSA into testing scope. Namespace-level
  `pod-security.kubernetes.io/enforce: baseline|restricted` labels and the relationship
  between PSS and `securityContext` are testable.

### Low priority

**G7. `kubectl port-forward` and `kubectl proxy`.**
- Only one file mentions `port-forward` (a passing reference in a TLS answer key).
- Exam-pressure techniques for testing connectivity without NodePort/LoadBalancer friction.

**G8. Custom scheduler profiles and multiple schedulers.**
- `course-section-map.md` lists S3 lectures 77-81 as covering these.
- `pods/assignment-4` covers scheduling mechanisms but does not practice writing a
  scheduler profile or running a second scheduler instance.

### Not gaps (verified covered)

RBAC, TLS, networking, storage (PV/PVC/SC), Ingress, Gateway API, CoreDNS, NetworkPolicy,
Helm, Kustomize, CRDs, operators, probes, ConfigMaps, Secrets, scheduling (affinity,
taints, tolerations, topology spread, priority), resources/QoS/LimitRange/ResourceQuota,
multi-container patterns including native sidecars, kubeadm concepts, etcd backup/restore,
HA (conceptually, limited by kind), application/control-plane/node/network troubleshooting,
all have dedicated assignments.

---

## Grep evidence for gaps

| Gap | Search | Result |
|---|---|---|
| G1 HPA/autoscaling | `HPA\|HorizontalPodAutoscaler\|autoscaling/v\|kubectl autoscale` in pods/5 | Only line 45 of prompt.md, which defers |
| G2 Jobs/CronJobs | `kind: Job\|kind: CronJob` | 3 files mention, 0 practice |
| G3 Admission | `admission controller\|ValidatingAdmission\|MutatingAdmission\|AdmissionPolicy` | 2 files, both forward-ref stubs |
| G4 kubectl debug | `kubectl debug\|ephemeral container\|ephemeralContainer` | 0 files |
| G5 StatefulSets | `kind: StatefulSet` | 0 files |
| G6 PSA | `Pod Security Standard\|PodSecurity admission\|pod-security.kubernetes.io` | 3 files, all deferrals |
| G7 port-forward | `port-forward` | 1 file (passing reference) |

---

## External Dependency Notes

The audit checked external component version compatibility against upstream documentation
on 2026-04-18. The following notes are useful context for future maintenance.

**Kubernetes target version: v1.35.** Confirmed against `github.com/cncf/curriculum`,
which publishes the curriculum as `CKA_Curriculum_v1.35.pdf`. Kubernetes 1.35.3 is the
current stable patch (released 2026-03-19). Supported versions are 1.33, 1.34, and 1.35.

**Ingress-nginx is being retired.** The project README states that best-effort maintenance
continues until March 2026, after which updates and security patches cease. Per the
January 2026 Kubernetes Steering and Security Response Committee statement, the
intended successor InGate also never progressed far enough and is retired as well.
Official migration recommendation: move to Gateway API or to an actively maintained
Ingress controller. A migration tool (`Ingress2Gateway`) was released in March 2026.

**CKA exam documentation set reflects the transition.** The Linux Foundation "resources
allowed" page lists `gateway-api.sigs.k8s.io/` as a dedicated permitted URL for the
CKA exam but has removed the NGINX Ingress Controller documentation (which now appears
only on the CKS allowed-resources list). Third-party candidate exam reports from 2026
confirm that migration from Ingress to Gateway API is explicit exam content. This drives
the ingress-and-gateway-api topic restructure documented in `remediation-plan.md` under
decision D8 and tasks P3.10-P3.15 / P4.9-P4.13.

**Calico v3.31.5** (released 2026-04-15) is the current v3.31 patch. Supports K8s
1.32-1.35. The repo pins this version across three install URLs.

**Kind v0.31.0** (released 2025-12-18) ships `kindest/node:v1.35.0` as the default and
also supports images for K8s 1.31-1.34. Users running the exercises should ensure their
kind binary is v0.31.0 or later to access the 1.35 node image.

---

## Summary

The bones of the repository are strong. The pod series and `rbac/assignment-1` set a high
quality bar that the skill-generated content does not consistently meet. Closing the
content-quality gap is the highest-leverage work, followed by adding five new topics to
close CKA curriculum gaps, and then by consolidating duplicated setup boilerplate and
pinning versions.

The remediation plan in `remediation-plan.md` sequences this work.
