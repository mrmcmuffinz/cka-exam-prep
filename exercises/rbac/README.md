# RBAC

**CKA Domain:** Cluster Architecture, Installation & Configuration (25%)
**Competencies covered:** Manage role-based access control (RBAC)

---

## Why Two Assignments

RBAC in Kubernetes operates at two distinct scopes: namespace-scoped (Roles and
RoleBindings) and cluster-scoped (ClusterRoles and ClusterRoleBindings). While the
underlying mechanics are similar (a role defines permissions, a binding grants them
to a subject), the resources involved, the verification patterns, and the real-world
use cases differ enough that combining them into one assignment would either rush
cluster-scoped material or make the assignment too large for 15 exercises.

Assignment 1 establishes the fundamentals: how roles and bindings work, how to create
users in a kind cluster, and how to verify permissions. Assignment 2 builds on that
foundation to cover cluster-scoped resources (nodes, PersistentVolumes, namespaces
themselves), aggregated ClusterRoles, the default ClusterRoles (cluster-admin, admin,
edit, view), and the pattern of using a ClusterRole with a RoleBinding for
cross-namespace permission reuse.

---

## Assignments

| Assignment | Title | Covers | Prerequisites |
|---|---|---|---|
| assignment-1 | RBAC (namespace-scoped) | Roles, RoleBindings, service accounts, user cert creation for kind, kubeconfig contexts, kubectl auth can-i | pods/assignment-1 |
| assignment-2 | RBAC (cluster-scoped) | ClusterRoles, ClusterRoleBindings, cluster-scoped resources, aggregated ClusterRoles, default ClusterRoles, ClusterRole + RoleBinding pattern | assignment-1 |

## Scope Boundaries

This topic covers authorization via RBAC. The following related areas are handled by
other topics:

- **Authentication** (TLS certificates, Certificates API, kubeconfig management): covered in `tls-and-certificates/`
- **Security contexts** (what containers can do at runtime): covered in `security-contexts/`
- **Network Policies** (network-level access control between pods): covered in `network-policies/`
- **RBAC for custom resources**: covered in `crds-and-operators/`
- **Admission controllers** (validating and mutating): covered in the pod series (pods/assignment-4 area, via the Mumshad course scheduling section)

## Cluster Requirements

Both assignments use a single-node kind cluster. User certificate creation uses kind's
existing CA and kubeconfig infrastructure.

## Recommended Order

Complete assignment-1 before assignment-2. Cluster-scoped RBAC builds directly on the
namespace-scoped fundamentals.
