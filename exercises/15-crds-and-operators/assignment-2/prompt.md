I need you to create a comprehensive Kubernetes homework assignment to help me practice **Custom Resources and RBAC**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed 15-crds-and-operators/assignment-1 (CRD creation)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers creating and managing custom resources, RBAC permissions for custom resources, and kubectl integration. CRD definition is assumed knowledge from assignment-1. Operators and controllers are covered in assignment-3.

**In scope for this assignment:**

*Custom Resource CRUD Operations*
- Creating custom resources with kubectl apply
- Getting custom resources: kubectl get <kind>
- Describing custom resources: kubectl describe <kind>
- Updating custom resources
- Deleting custom resources
- Custom resource validation against CRD schema

*Custom Resource Namespacing*
- Namespaced custom resources (scope: Namespaced in CRD)
- Cluster-scoped custom resources (scope: Cluster in CRD)
- When to use each scope
- Namespace field in namespaced resources

*RBAC for Custom Resources*
- Roles referencing custom resource types
- apiGroups field: using the CRD's group
- resources field: using the CRD's plural name
- verbs: get, list, watch, create, update, patch, delete
- ClusterRoles for cluster-scoped resources
- Service account permissions for custom resources

*Custom Resource Discovery*
- kubectl api-resources to list all resources including custom
- kubectl api-versions to list API groups
- kubectl explain for custom resource fields (if CRD has descriptions)
- Finding custom resources in a cluster

*Custom Resource Categories and Short Names*
- shortNames in CRD spec (e.g., sv for ServerVersion)
- categories for grouping (e.g., all for kubectl get all)
- Using short names in kubectl commands

*kubectl Integration*
- kubectl get <plural> for listing
- kubectl get <singular> <name> for specific resource
- kubectl get <shortname> using short names
- Output formats: -o yaml, -o json, -o wide
- Custom printer columns appearing in kubectl get output
- kubectl edit for modifying custom resources

**Out of scope (covered in other assignments, do not include):**

- CRD creation and schema definition (exercises/15-15-crds-and-operators/assignment-1)
- CRD versioning (exercises/15-15-crds-and-operators/assignment-1)
- Operators and controllers (exercises/15-15-crds-and-operators/assignment-3)
- RBAC fundamentals (exercises/12-12-rbac/assignment-1)
- ClusterRoles for built-in resources (exercises/12-12-rbac/assignment-2)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: crds-and-operators-tutorial.md (section 2)
   - Demonstrate CRUD operations on custom resources
   - Explain namespaced vs cluster-scoped resources
   - Show how to configure RBAC for custom resources
   - Demonstrate kubectl integration (short names, categories)
   - Use tutorial-crds namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: crds-and-operators-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Basic Custom Resource Operations**
   - Create a custom resource instance
   - List and describe custom resources
   - Update and delete custom resources

   **Level 2 (Exercises 2.1-2.3): Namespacing and Discovery**
   - Create namespaced custom resources in different namespaces
   - Use kubectl api-resources to find custom resources
   - Use short names to access custom resources

   **Level 3 (Exercises 3.1-3.3): Debugging Custom Resource Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: resource fails validation, RBAC blocks access, resource not found in namespace

   **Level 4 (Exercises 4.1-4.3): RBAC for Custom Resources**
   - Create Role allowing specific verbs on custom resources
   - Bind role to a service account
   - Test permissions with kubectl auth can-i

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Exercise 5.1: Set up multi-user access to custom resources
   - Exercise 5.2: Debug permission denied for custom resource operations
   - Exercise 5.3: Design RBAC strategy for custom resource lifecycle

3. **Answer Key File**
   - Create the answer key: crds-and-operators-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Wrong apiGroups in Role (must match CRD group)
     - Wrong resources name (must use plural)
     - Trying to get cluster-scoped resource in namespace
     - Custom resource validation failures
     - Missing RBAC for status subresource
   - Custom resource commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Custom Resources and RBAC assignment
   - Prerequisites: 15-crds-and-operators/assignment-1, 12-rbac/assignment-1
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- CRDs created in assignment-1 or tutorial
- kubectl client

RESOURCE GATE:
This assignment uses a restricted resource gate (generation order 12):
- CustomResourceDefinitions
- Custom resources (instances of CRDs)
- Roles, RoleBindings, ClusterRoles, ClusterRoleBindings
- ServiceAccounts
- Namespaces
- Do NOT use: Services, Ingress, PersistentVolumes, NetworkPolicies

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-crds`.
- Debugging exercise headings are bare.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/15-15-crds-and-operators/assignment-1: CRD creation
  - exercises/12-12-rbac/assignment-1: RBAC fundamentals (helpful)

- **Follow-up assignments:**
  - exercises/15-15-crds-and-operators/assignment-3: Operators and controllers

COURSE MATERIAL REFERENCE:
- S7 (Lectures 160-168): RBAC
- S7 (Lectures 184-187): CRDs and custom resources
