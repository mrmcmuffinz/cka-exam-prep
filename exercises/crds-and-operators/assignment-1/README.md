# CRDs and Operators Assignment 1: Custom Resource Definitions

This assignment covers Custom Resource Definitions (CRDs), which extend the Kubernetes API with new resource types. You will learn how to create CRDs, define schemas with OpenAPI validation, configure versioning, and set up status subresources.

## Prerequisites

Before starting this assignment, you should have:

- General familiarity with Kubernetes resources and YAML manifests
- Experience using kubectl to manage resources

## Estimated Time

4-6 hours for tutorial and all exercises.

## Cluster Requirements

This assignment uses a single-node kind cluster with no special configuration required.

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

## What You Will Learn

This assignment teaches CRD structure and configuration:

- **CRD spec structure** including group, versions, scope, and names
- **OpenAPI v3 schema** for validating custom resource fields
- **CRD versioning** with served and storage flags
- **Status subresources** for separating spec from controller-managed status
- **Additional printer columns** for customizing kubectl output

After completing this assignment, you will be ready for assignment-2, which covers creating and managing custom resources.

## Difficulty Progression

**Level 1 (Basic CRD Creation):** Create simple CRDs, list and describe them, verify API registration.

**Level 2 (Schema Definition):** Add typed properties, required fields, nested objects.

**Level 3 (Debugging CRD Issues):** Diagnose invalid name formats, schema errors, missing fields.

**Level 4 (Advanced CRD Features):** Configure status subresources, printer columns, multiple versions.

**Level 5 (Complex Scenarios):** Design CRDs for real use cases, version migration, comprehensive configuration.

## Recommended Workflow

1. Read the tutorial file to understand CRD concepts
2. Complete the exercises in order, as later exercises build on earlier concepts
3. Try each exercise before checking the answer key
4. Compare your solutions with the answer key to learn alternative approaches

## Files in This Directory

| File | Description |
|------|-------------|
| `prompt.md` | The generation prompt used to create this assignment |
| `README.md` | This overview file |
| `crds-and-operators-tutorial.md` | Step-by-step tutorial on Custom Resource Definitions |
| `crds-and-operators-homework.md` | 15 progressive exercises |
| `crds-and-operators-homework-answers.md` | Complete solutions with explanations |
