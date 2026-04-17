# RBAC Homework Assignment

A complete, self-contained practice package for Kubernetes RBAC (Roles and RoleBindings), built for CKA exam prep. Everything runs on a rootless kind cluster with containerd and nerdctl. No external infrastructure is required beyond the cluster itself.

## Files

| File | Contents |
|------|----------|
| `README.md` | This file. Overview and workflow. |
| `rbac-tutorial.md` | Complete end-to-end walkthrough: create a real user with a signed certificate, add her to kubeconfig as `jane@kind-kind`, give her a Role and RoleBinding, verify everything works. Includes a Reference Commands section at the end that serves as a quick-lookup for the exercises. |
| `rbac-homework.md` | 15 progressive exercises, from "give alice read access to pods" to full multi-team, multi-namespace, `resourceNames`-restricted production scenarios. |
| `rbac-homework-answers.md` | Full solutions for all 15 exercises, including both imperative and declarative approaches, and explanations of what was broken in each debugging exercise. |

## Recommended Workflow

Start with the tutorial. It is the only place in this package where you will actually create a real user with a real certificate and a real kubeconfig context. Doing this once builds the mental model for how Kubernetes authentication actually works, and it connects the RBAC objects (Role, RoleBinding) to the identity machinery underneath them. You only need to do this once, not for every exercise.

After the tutorial, move to `rbac-homework.md` and work through the exercises in order. Levels 1 through 5 are progressively harder. The exercises use `kubectl auth can-i ... --as=USER` for verification instead of real certificates, because creating a new cert for each exercise would be tedious and would not teach anything new. Skip to the answer key only after you have attempted an exercise and its verification block yourself.

Each exercise is self-contained. You can do them in any order, since each one uses its own namespace (`ex-1-1`, `ex-1-2`, etc.) and its own user name. The tutorial uses `tutorial-rbac` as its namespace and `jane` as its user, so nothing in the tutorial will collide with the homework.

## Difficulty Progression

- **Level 1 (exercises 1.1 to 1.3):** single resource, single verb set, single user, single namespace. The goal is to internalize the four-object mental model (Role + RoleBinding, plus ClusterRole and ClusterRoleBinding for later) and the basic YAML shape.
- **Level 2 (exercises 2.1 to 2.3):** mixed verbs on the same resource, or multiple resource types in the same Role. This is where you start combining rules and grouping resources by (apiGroup, verbs).
- **Level 3 (exercises 3.1 to 3.3):** debugging. Each exercise has one broken configuration that applies successfully but does not work. You find and fix the single issue. These cover the three most common silent failures: wrong API group, wrong role reference name, and invalid verbs.
- **Level 4 (exercises 4.1 to 4.3):** multi-namespace and multi-subject scenarios. Dev/prod splits, three-team setups, group subjects, and ServiceAccount subjects all appear here.
- **Level 5 (exercises 5.1 to 5.3):** multi-issue debugging and `resourceNames` restrictions. These test whether you can hold several RBAC concepts in your head at once.

## Prerequisites

A running kind cluster created with rootless nerdctl as the provider. If you do not have one:

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

Kubernetes resources assumed already familiar from your CKA progress: Pods, Deployments, Services, ConfigMaps, Secrets, DaemonSets, ReplicaSets, Namespaces. No other resource types appear in these exercises.

You should also have finished Sections 1 through 6 of the Mumshad CKA course plus Section 7 up through KubeConfig. The tutorial assumes you understand what a kubeconfig is and how contexts work. ClusterRoles and ClusterRoleBindings appear in the tutorial's reference material and in one exercise (4.1), so you do not need deep familiarity yet, but a basic awareness that they exist is helpful.

Tools required: `kubectl`, `kind`, `nerdctl`, `openssl`. All four should already be on your Ubuntu dev machine.

## Estimated Time

- **Tutorial:** 45 to 60 minutes if you are new to certificate signing, 25 to 30 minutes if you have done something like it before.
- **Homework Level 1:** 15 to 20 minutes total.
- **Homework Level 2:** 20 to 30 minutes total.
- **Homework Level 3:** 30 to 45 minutes total. Debugging takes longer than building from scratch, which is the point.
- **Homework Level 4:** 45 to 60 minutes total.
- **Homework Level 5:** 45 to 75 minutes total.

Total budget: roughly three to five hours of focused work across one or two sessions. That matches the daily study block expected for S7 (Security) in the CKA plan.

## What This Covers vs What It Does Not

**Covers:** Role, RoleBinding, ClusterRole (referenced, bound via RoleBinding), subjects of all three kinds (User, Group, ServiceAccount), all standard verbs, the `resourceNames` field, API groups, and the common debugging paths.

**Does not cover:** ClusterRoleBinding for cluster-wide access, aggregated ClusterRoles, admission webhooks, OIDC-based authentication, or anything involving the CertificateSigningRequest resource. Those are adjacent topics for a later session.
