# CRDs and Operators

**CKA Domain:** Cluster Architecture, Installation & Configuration (25%)
**Competencies covered:** Understand CRDs and install and configure operators

---

## Why One Assignment

The CKA tests CRD and operator consumption, not development. The exam expects you to
create CRDs, manage custom resources, and install existing operators, but not to write
custom controllers in Go. This scopes the material to roughly 8-10 exercise areas:
CRD spec construction, custom resource CRUD operations, the operator pattern conceptually,
installing an operator, and RBAC for custom resources. A single assignment covers this
comfortably.

---

## Assignments

| Assignment | Title | Covers | Prerequisites |
|---|---|---|---|
| assignment-1 | CRDs and Operators | CRD spec (group, versions, scope, names, schema), creating/applying CRDs, custom resource CRUD, custom controller concept, operator pattern, installing existing operators, RBAC for custom resources | None |

## Scope Boundaries

This topic covers extending Kubernetes with custom resources and operators. The
following related areas are handled by other topics:

- **RBAC for custom resources** (creating Roles that grant access to custom resource types): introduced here, with RBAC fundamentals in `rbac/`
- **Helm** (operators are often installed via Helm charts): covered in `helm/`
- **Admission controllers** (validating/mutating webhooks for custom resources): covered in the pod series scheduling material

## Cluster Requirements

Single-node kind cluster. Operator installation may require pulling images, but no
special cluster configuration is needed.

## Recommended Order

No strict prerequisites, though familiarity with RBAC (rbac/assignment-1) helps for
the custom resource permission exercises.
