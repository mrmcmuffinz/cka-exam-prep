# CRDs and Operators Assignment 3: Operators and Controllers

This assignment covers the operator pattern, installing existing operators, operator lifecycle management, and troubleshooting operator installations. CRD creation (assignment-1) and custom resource management (assignment-2) are assumed knowledge.

## Prerequisites

Before starting this assignment, you should have completed:

- exercises/crds-and-operators/assignment-1 (CRD creation)
- exercises/crds-and-operators/assignment-2 (Custom resources and RBAC)

## Estimated Time

4-6 hours for tutorial and all exercises.

## Cluster Requirements

This assignment uses a single-node kind cluster. Some exercises require network access to pull operator images.

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

## What You Will Learn

This assignment teaches the operator pattern and lifecycle:

- **Controller pattern** with watch-reconcile loops
- **Operator pattern** combining controllers with CRDs
- **Installing operators** from manifests or Helm
- **Operator lifecycle** including upgrades and uninstallation
- **Troubleshooting** operator installation and reconciliation issues

## Difficulty Progression

**Level 1 (Understanding Controllers):** Identify built-in controllers, trace reconciliation, view controller logs.

**Level 2 (Installing Operators):** Install operators from manifests, verify deployment, create custom resources.

**Level 3 (Debugging Issues):** Diagnose operator pod failures, RBAC problems, reconciliation issues.

**Level 4 (Operator Lifecycle):** Upgrade operators, clean up installations properly.

**Level 5 (Complex Scenarios):** Evaluate operators, debug complex failures, design adoption strategy.

## Recommended Workflow

1. Read the tutorial file to understand operators and controllers
2. Complete the exercises in order, as later exercises build on earlier concepts
3. Try each exercise before checking the answer key
4. Compare your solutions with the answer key to learn alternative approaches

## Files in This Directory

| File | Description |
|------|-------------|
| `prompt.md` | The generation prompt used to create this assignment |
| `README.md` | This overview file |
| `crds-and-operators-tutorial.md` | Step-by-step tutorial on operators and controllers |
| `crds-and-operators-homework.md` | 15 progressive exercises |
| `crds-and-operators-homework-answers.md` | Complete solutions with explanations |
