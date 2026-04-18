# Assignment 2: RBAC (Cluster-Scoped)

This assignment is the second in the RBAC series for CKA exam preparation. It covers cluster-scoped RBAC: ClusterRoles, ClusterRoleBindings, permissions on cluster-scoped resources, aggregated ClusterRoles, and the pattern of using ClusterRole with RoleBinding. The assignment assumes you have completed rbac/assignment-1 (namespace-scoped RBAC) and tls-and-certificates/assignment-2 (certificate-based authentication).

## File Overview

The assignment is split across four files. `README.md` (this file) provides the overview. `rbac-tutorial.md` covers ClusterRoles, ClusterRoleBindings, cluster-scoped resources, aggregation, and default roles. `rbac-homework.md` contains 15 progressive exercises. `rbac-homework-answers.md` contains complete solutions.

## Difficulty Progression

Level 1: ClusterRole basics and ClusterRoleBindings. Level 2: Permissions on cluster-scoped resources (nodes, namespaces, PVs). Level 3: Debugging RBAC issues. Level 4: Advanced patterns (ClusterRole + RoleBinding, aggregation). Level 5: Complex scenarios designing least-privilege access.

## Prerequisites

Completed rbac/assignment-1 and tls-and-certificates/assignment-2. Single-node kind cluster with users created via certificates.

## Cluster Requirements

Single-node kind cluster.

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

## Estimated Time

Tutorial: 45-60 minutes. Exercises: 4-6 hours.

## Key Takeaways

Create ClusterRoles for cluster-scoped resources, bind ClusterRoles cluster-wide with ClusterRoleBindings, use ClusterRole + RoleBinding pattern for namespace-scoped grants, understand aggregated ClusterRoles, verify permissions with kubectl auth can-i, and apply least-privilege principles.
