# CRDs and Operators

**CKA Domain:** Cluster Architecture, Installation & Configuration (25%)
**Competencies covered:** Understand CRDs and install and configure operators

---

## Rationale for Number of Assignments

Custom Resource Definitions and operators extend Kubernetes with new resource types and automated operational logic. The material encompasses CRD structure and schema definition, custom resource management, RBAC for custom resources, the controller pattern, and operator installation workflows. This produces roughly 16-18 distinct subtopics. The material splits naturally into three focused progressions: CRD authoring and schema design, custom resource operations with RBAC integration, and operator installation with lifecycle management. Each assignment delivers 5-6 subtopics at depth, building from foundational CRD creation through resource management to operational automation via operators.

---

## Assignment Summary

| Assignment | Description | Prerequisites |
|---|---|---|
| assignment-1 | Custom Resource Definitions | CRD spec structure (group, versions, scope, names), CRD schema definition (OpenAPI v3), CRD versioning strategies, creating and applying CRDs, CRD validation rules, CRD status subresources | None |
| assignment-2 | Custom Resources and RBAC | Custom resource CRUD operations, custom resource namespacing vs cluster-scoping, RBAC for custom resources (Roles referencing CR types), custom resource discovery (kubectl api-resources), custom resource categories and short names, kubectl integration | 15-crds-and-operators/assignment-1 |
| assignment-3 | Operators and Controllers | Custom controller concept (watch-reconcile loop), operator pattern overview, installing existing operators, operator lifecycle (install, upgrade, uninstall), troubleshooting operator installations, operator best practices and when to use them | 15-crds-and-operators/assignment-2 |

## Scope Boundaries

This topic covers extending Kubernetes with custom resources and operators. The following related areas are handled by other topics:

- **RBAC fundamentals** (Roles, RoleBindings, ClusterRoles): covered in `rbac/`, with custom resource RBAC introduced in assignment-2 here
- **Helm** (operators are often installed via Helm charts): covered in `helm/`, though assignment-3 covers operator installation generally
- **Admission controllers** (validating/mutating webhooks for custom resources): covered in the pod series scheduling material
- **Writing custom controllers in Go** (not in CKA exam scope): excluded from all assignments

Assignment-1 focuses on CRD authoring. Assignment-2 focuses on custom resource management and permissions. Assignment-3 focuses on consuming operators built by others.

## Cluster Requirements

Single-node kind cluster for all three assignments. Operator installation may require pulling images, but no special cluster configuration is needed. Some operators may expect specific cluster capabilities, which the tutorial should document case-by-case.

## Recommended Order

1. No strict prerequisites for assignment-1, though general Kubernetes resource familiarity is assumed
2. Work through assignments 1, 2, 3 sequentially
3. Assignment-2 assumes understanding of CRD structure from assignment-1
4. Assignment-3 assumes understanding of custom resources from assignment-2
5. Familiarity with RBAC (12-rbac/assignment-1) helps for the custom resource permission exercises in assignment-2
