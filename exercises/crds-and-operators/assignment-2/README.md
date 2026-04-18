# CRDs and Operators Assignment 2: Custom Resources and RBAC

This assignment covers creating and managing custom resources, configuring RBAC for custom resources, and kubectl integration with custom resources. CRD creation from assignment-1 is assumed knowledge.

## Prerequisites

Before starting this assignment, you should have completed:

- exercises/crds-and-operators/assignment-1 (CRD creation)
- exercises/rbac/assignment-1 (RBAC fundamentals, helpful but not required)

You should understand how to create CRDs, define schemas, and configure versioning.

## Estimated Time

4-6 hours for tutorial and all exercises.

## Cluster Requirements

This assignment uses a single-node kind cluster with no special configuration required.

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

## What You Will Learn

This assignment teaches custom resource management and RBAC:

- **CRUD operations** for custom resources (create, read, update, delete)
- **Namespaced vs cluster-scoped** custom resources
- **RBAC for custom resources** using Roles and RoleBindings
- **kubectl integration** including short names, categories, and output formats
- **Custom resource discovery** using api-resources and api-versions

## Difficulty Progression

**Level 1 (Basic Operations):** Create, list, describe, update, and delete custom resources.

**Level 2 (Namespacing and Discovery):** Work with namespaced resources, use api-resources, use short names.

**Level 3 (Debugging Issues):** Diagnose validation failures, RBAC blocks, namespace issues.

**Level 4 (RBAC Configuration):** Create Roles for custom resources, bind to service accounts, test permissions.

**Level 5 (Complex Scenarios):** Multi-user access, permission debugging, RBAC strategy design.

## Recommended Workflow

1. Read the tutorial file to understand custom resource operations
2. Complete the exercises in order, as later exercises build on earlier concepts
3. Try each exercise before checking the answer key
4. Compare your solutions with the answer key to learn alternative approaches

## Files in This Directory

| File | Description |
|------|-------------|
| `prompt.md` | The generation prompt used to create this assignment |
| `README.md` | This overview file |
| `crds-and-operators-tutorial.md` | Step-by-step tutorial on custom resources and RBAC |
| `crds-and-operators-homework.md` | 15 progressive exercises |
| `crds-and-operators-homework-answers.md` | Complete solutions with explanations |
