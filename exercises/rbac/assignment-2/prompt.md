I need you to create a comprehensive Kubernetes homework assignment to help me practice **RBAC (Cluster-Scoped)**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S7 (through RBAC)
- I have completed rbac/assignment-1 (namespace-scoped RBAC)
- I have completed tls-and-certificates/assignment-2 (certificate-based authentication)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers cluster-scoped RBAC: ClusterRoles, ClusterRoleBindings, cluster-scoped resources, aggregated ClusterRoles, and the pattern of using ClusterRole with RoleBinding. Namespace-scoped RBAC (Roles, RoleBindings) is assumed knowledge from assignment-1. Authentication via certificates is assumed from tls-and-certificates/assignment-2.

**In scope for this assignment:**

*ClusterRoles*
- ClusterRole structure (same as Role but no namespace field)
- Permissions on cluster-scoped resources (nodes, namespaces, PersistentVolumes, clusterroles, clusterrolebindings)
- Permissions on non-resource URLs (/healthz, /api, /apis, /metrics)
- ClusterRoles that can be bound namespace-scoped or cluster-scoped

*ClusterRoleBindings*
- ClusterRoleBinding structure
- Binding ClusterRole to subjects (users, groups, service accounts)
- Effect: cluster-wide permissions
- subjects field: kind, name, namespace (for service accounts)

*Cluster-Scoped Resources*
- nodes: read node status, labels, conditions
- namespaces: create, delete namespaces
- persistentvolumes: provision, manage cluster storage
- clusterroles and clusterrolebindings: RBAC self-management
- storageclasses, ingressclasses, priorityclasses

*Aggregated ClusterRoles*
- aggregationRule.clusterRoleSelectors
- How aggregation combines permissions from matching ClusterRoles
- Built-in aggregated roles: admin, edit, view
- Creating custom aggregated ClusterRoles

*Default ClusterRoles*
- cluster-admin: full cluster access
- admin: namespace admin (when bound with RoleBinding)
- edit: read-write most resources
- view: read-only access
- system: prefixed roles for system components
- When to use built-in roles vs custom

*ClusterRole with RoleBinding Pattern*
- Using ClusterRole as permission definition
- RoleBinding grants it in specific namespace only
- Use case: reusable role definitions
- Why this is different from ClusterRoleBinding

*Service Account Permissions at Cluster Scope*
- Service accounts in ClusterRoleBindings
- Cross-namespace service account references
- Service accounts with cluster-wide access
- Security implications

*kubectl auth can-i at Cluster Scope*
- kubectl auth can-i --list for all permissions
- kubectl auth can-i with --all-namespaces
- Testing non-resource URLs
- kubectl auth can-i --as for impersonation

**Out of scope (covered in other assignments, do not include):**

- Roles and RoleBindings (exercises/rbac/assignment-1)
- User certificate creation (exercises/tls-and-certificates/assignment-1 and assignment-2)
- kubeconfig management (exercises/tls-and-certificates/assignment-2)
- RBAC for custom resources (exercises/crds-and-operators/assignment-2)
- Admission controllers

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: rbac-tutorial.md (section 2, appending to assignment-1 tutorial)
   - Explain the difference between ClusterRole/ClusterRoleBinding and Role/RoleBinding
   - Walk through ClusterRole creation for cluster-scoped resources
   - Demonstrate ClusterRoleBinding
   - Show aggregated ClusterRoles
   - Demonstrate ClusterRole + RoleBinding pattern
   - Explain default ClusterRoles and when to use them
   - Use tutorial-rbac namespace where applicable

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: rbac-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)
   - Each exercise is self-contained with setup commands and verification commands
   - Every exercise uses its own namespace where applicable

   **Level 1 (Exercises 1.1-1.3): ClusterRole Basics**
   - Create ClusterRole with cluster-scoped resource permissions
   - Create ClusterRoleBinding for a user
   - Verify cluster-wide permissions with kubectl auth can-i

   **Level 2 (Exercises 2.1-2.3): Cluster-Scoped Resources**
   - Grant permissions on nodes
   - Grant permissions on namespaces
   - Grant permissions on PersistentVolumes

   **Level 3 (Exercises 3.1-3.3): Debugging RBAC Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: wrong resource name, missing cluster-scoped binding, non-resource URL access denied

   **Level 4 (Exercises 4.1-4.3): Advanced Patterns**
   - ClusterRole + RoleBinding for namespace-scoped grant
   - Aggregated ClusterRole
   - Service account with cluster-wide access

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Exercise 5.1: Design RBAC for cluster operator role
   - Exercise 5.2: Debug complex permission denied scenario
   - Exercise 5.3: Implement least-privilege cluster access strategy

3. **Answer Key File**
   - Create the answer key: rbac-homework-answers.md
   - Full solutions for all 15 exercises with explanations
   - Common mistakes section covering:
     - Confusing ClusterRoleBinding with RoleBinding for cluster access
     - ClusterRole + RoleBinding only works namespace-scoped
     - Forgetting non-resource URLs need explicit rules
     - Service account namespace in ClusterRoleBinding subjects
     - Aggregated roles not updating when source roles change
   - RBAC verification commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of RBAC (Cluster-Scoped) assignment
   - Prerequisites: rbac/assignment-1, tls-and-certificates/assignment-2
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- Users created with certificates (from tls-and-certificates assignment)
- kubectl client

RESOURCE GATE:
This assignment uses resources through generation order 7:
- ClusterRoles, ClusterRoleBindings
- Roles, RoleBindings (assumed knowledge)
- ServiceAccounts
- Namespaces
- Nodes (read access for exercises)
- Do NOT use: Services, Ingress, PersistentVolumes (beyond RBAC rules), NetworkPolicies

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-rbac`.
- Debugging exercise headings are bare.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/rbac/assignment-1: Namespace-scoped RBAC fundamentals
  - exercises/tls-and-certificates/assignment-2: Certificate-based authentication

- **Follow-up assignments:**
  - exercises/crds-and-operators/assignment-2: RBAC for custom resources

COURSE MATERIAL REFERENCE:
- S7 (Lectures 160-168): API groups, authorization, RBAC (Roles, ClusterRoles, bindings)
- S7 (Lectures 169-171): Service accounts
