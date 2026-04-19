# Assignment 1: Pod Security Standards and Pod Security Admission

Pod Security Admission (PSA) is the built-in admission controller that enforces Pod Security Standards (PSS) at namespace scope using labels. This assignment, the only one in its series, covers the three PSS profiles (Privileged, Baseline, Restricted), the three PSA modes (enforce, audit, warn), the `pod-security.kubernetes.io/` label family, version pinning, and the interaction between PSA and the `securityContext` fields the security-contexts series already covered. PSA has been stable since Kubernetes 1.25 and is enabled by default on every modern cluster; the 2025 CKA curriculum update moved it explicitly into exam scope.

## Files

| File | Purpose |
|---|---|
| `prompt.md` | The generation prompt (input to the homework generator skill) |
| `README.md` | This overview |
| `pod-security-tutorial.md` | Step-by-step tutorial teaching PSS, PSA modes, and their interaction with securityContext |
| `pod-security-homework.md` | 15 progressive exercises across five difficulty levels |
| `pod-security-homework-answers.md` | Complete solutions with diagnostic reasoning and common mistakes |

## Recommended Workflow

Work through the tutorial first. It builds a small set of namespaces at each profile level and exercises the three enforcement modes so that what each label does becomes empirical rather than theoretical. The lesson you should internalize from the tutorial is that PSS defines the bar and PSA decides what happens when a pod fails the bar; the labels compose those two decisions per namespace. Once the tutorial is complete, move through the homework in order. Level 3 debugging exercises are where the gotchas live, because PSA errors are specific and the fix is usually a small edit to the pod's `securityContext` rather than a change to the namespace labels.

## Difficulty Progression

Level 1 covers the basics: label a namespace to enforce Baseline, label another to warn Restricted, and observe the different outcomes when a non-compliant pod is applied. Level 2 combines profile levels and modes on the same namespace (enforce Baseline plus warn Restricted, the common "staging to Restricted" pattern) and introduces version pinning. Level 3 is debugging: pods are rejected or warned, and you must identify which PSS requirement fails and fix the `securityContext` to comply, not the namespace label. Level 4 is build tasks for realistic scenarios: a Restricted namespace running a typical application, a Baseline namespace that audits Restricted as an upgrade preview. Level 5 is advanced debugging where several things fail at once or where the violation message is not obvious.

## Prerequisites

Complete the `exercises/13-security-contexts/` series first (at least assignments 1 and 3), because PSA enforces the `securityContext` fields those assignments taught. Complete `exercises/16-16-admission-controllers/assignment-1` for the mental model of where PSA sits in the admission pipeline, though this is not strictly required since PSA-specific exercises can stand alone.

## Cluster Requirements

A single-node kind cluster is sufficient for every exercise. PSA is enabled by default in the kube-apiserver static pod configuration; no extra install is needed. The cluster image must be Kubernetes 1.25 or later (PSA's stability release). `kindest/node:v1.35.0` satisfies this. See `docs/cluster-setup.md#single-node-kind-cluster` for the cluster creation command.

## Estimated Time Commitment

Plan for about 45 to 60 minutes on the tutorial if you work through every command attentively. The 15 exercises together take three to five hours. Levels 1 and 2 each run about 10 to 15 minutes; Level 3 debugging exercises take 15 to 25 minutes each because the PSS violation messages require careful reading; Level 4 runs 20 to 30 minutes per exercise; Level 5 takes 30 to 45 minutes per exercise.

## Scope Boundary and What Comes Next

This assignment covers namespace-level policy enforcement through PSA. The `securityContext` fields PSA evaluates are taught in `exercises/13-security-contexts/`; the broader admission-controller machinery (built-in plugins, `ValidatingAdmissionPolicy`, MutatingWebhook) lives in `exercises/16-admission-controllers/`; network-level security is `exercises/10-network-policies/`; RBAC for who can apply PSA labels or bypass enforcement is `exercises/12-rbac/`. PodSecurityPolicy, the predecessor removed in Kubernetes 1.25, is out of scope; do not reach for it in exercises.

## Key Takeaways After Completing This Assignment

By the time you finish all 15 exercises, you should be able to label a namespace for PSA enforcement at any profile level, combine enforce/audit/warn modes on the same namespace to stage a tightening migration, pin a profile to a specific Kubernetes version so cluster upgrades do not silently change the policy, read a PSA rejection message and identify which PSS requirement failed, write a pod `securityContext` that satisfies the Restricted profile (runAsNonRoot, allowPrivilegeEscalation false, capabilities drop ALL, seccompProfile RuntimeDefault or Localhost), use `warn` mode as a staging tool to preview the impact of tightening enforcement without breaking existing workloads, and diagnose the common case where a Deployment's pods are rejected even though `kubectl apply` on the Deployment itself succeeded (PSA enforces on pods, not on workload resources).
