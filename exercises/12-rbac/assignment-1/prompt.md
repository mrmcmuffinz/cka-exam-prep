I need you to create a comprehensive Kubernetes homework assignment to help me practice **RBAC (Namespace-Scoped)**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S7 (through RBAC and Service Accounts)
- I have completed pods/assignment-1 (pod fundamentals)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers namespace-scoped RBAC: Roles, RoleBindings, service accounts, user certificate creation for kind clusters, kubeconfig context conventions, and permission verification. Cluster-scoped RBAC (ClusterRoles, ClusterRoleBindings) is covered in assignment-2 and MUST NOT appear here except as a brief forward reference.

**In scope for this assignment:**

*Roles*
- Role structure: apiVersion rbac.authorization.k8s.io/v1, kind Role
- metadata: name, namespace
- rules: apiGroups, resources, verbs, resourceNames
- Common verbs: get, list, watch, create, update, patch, delete
- apiGroups: core (""), apps, batch, etc.
- resourceNames for fine-grained access to specific objects

*RoleBindings*
- RoleBinding structure: metadata, subjects, roleRef
- subjects: User, Group, ServiceAccount (kind, name, namespace for SA)
- roleRef: kind (Role), name, apiGroup
- Binding a Role to multiple subjects
- RoleBinding is namespace-scoped (affects only the binding's namespace)

*Service Accounts*
- ServiceAccount resources in namespaces
- Default service account per namespace
- Creating custom service accounts
- Service account tokens (automatic and manual)
- Pods running as specific service accounts
- Service account vs user accounts

*User Certificate Creation for Kind*
- Generating user private key with openssl
- Creating CSR for the user
- Signing CSR with kind cluster CA
- Creating kubeconfig entries for the user
- Subject CN becomes username, O becomes group

*kubeconfig Context Conventions*
- Context structure: cluster, user, namespace
- user@cluster naming convention
- Switching contexts with kubectl config use-context
- Setting namespace in context
- Current context verification

*kubectl auth can-i*
- Verifying own permissions: kubectl auth can-i <verb> <resource>
- Verifying as another user: kubectl auth can-i --as <user>
- Verifying as service account: kubectl auth can-i --as system:serviceaccount:<ns>:<name>
- Verifying in specific namespace: -n <namespace>
- Listing all permissions: kubectl auth can-i --list

*Permission Design Patterns*
- Read-only access pattern (get, list, watch)
- Developer access pattern (create, update, delete on some resources)
- Operator access pattern (full access to namespace)
- Least privilege principle
- Avoiding broad permissions

**Out of scope (covered in other assignments, do not include):**

- ClusterRoles and ClusterRoleBindings (exercises/rbac/assignment-2)
- Cluster-scoped resources (nodes, PersistentVolumes, namespaces) (exercises/rbac/assignment-2)
- Aggregated ClusterRoles (exercises/rbac/assignment-2)
- RBAC for custom resources (exercises/crds-and-operators/assignment-2)
- TLS certificate management in depth (exercises/tls-and-certificates/)
- Certificates API (exercises/tls-and-certificates/assignment-2)
- Network Policies (exercises/network-policies/)
- Admission controllers

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: rbac-tutorial.md
   - Explain RBAC concepts: authentication vs authorization
   - Walk through Role creation
   - Walk through RoleBinding creation
   - Demonstrate service account creation and usage
   - Show user certificate creation for kind cluster
   - Demonstrate kubeconfig management
   - Show permission verification with kubectl auth can-i
   - Use tutorial-rbac namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: rbac-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)
   - Each exercise is self-contained with setup commands and verification commands
   - Every exercise uses its own namespace: ex-1-1, ex-1-2, etc.

   **Level 1 (Exercises 1.1-1.3): Basic Role and RoleBinding**
   - Create a Role with specific permissions
   - Create a RoleBinding for a service account
   - Verify permissions with kubectl auth can-i

   **Level 2 (Exercises 2.1-2.3): Service Accounts and Pods**
   - Create service account and assign to pod
   - Create Role for pod operations
   - Bind role to service account

   **Level 3 (Exercises 3.1-3.3): Debugging RBAC Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: permission denied, wrong resource in role, role not bound

   **Level 4 (Exercises 4.1-4.3): Users and kubeconfig**
   - Create user certificate for kind cluster
   - Configure kubeconfig for user
   - Grant user namespace-scoped access

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Exercise 5.1: Multi-user access with different roles
   - Exercise 5.2: Debug complex permission denied scenario
   - Exercise 5.3: Design RBAC strategy for development team

3. **Answer Key File**
   - Create the answer key: rbac-homework-answers.md
   - Full solutions for all 15 exercises with explanations
   - For debugging exercises, explain diagnostic workflow
   - Common mistakes section covering:
     - Wrong apiGroups (core resources use "" not "core")
     - RoleBinding referencing non-existent Role
     - Wrong subject kind (User vs ServiceAccount)
     - Forgetting namespace in service account subject
     - Role allows resource but not verb
   - RBAC verification commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of RBAC (namespace-scoped) assignment
   - Prerequisites: pods/assignment-1
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster
   - Note about user certificate creation
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- openssl for certificate generation
- Access to kind cluster CA (for signing user certs)
- kubectl client

RESOURCE GATE:
This assignment uses resources available early in the series:
- Pods (for testing service account access)
- Roles, RoleBindings
- ServiceAccounts
- Namespaces
- Do NOT use: Services, Deployments, PersistentVolumes, NetworkPolicies, ClusterRoles, ClusterRoleBindings

KIND CLUSTER SETUP:
Single-node kind cluster is sufficient:
```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

User certificates can be signed using kind's CA, which is accessible at:
```bash
nerdctl exec kind-control-plane cat /etc/kubernetes/pki/ca.crt
nerdctl exec kind-control-plane cat /etc/kubernetes/pki/ca.key
```

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-rbac`.
- Debugging exercise headings are bare.
- Container images use explicit version tags.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/pods/assignment-1: Pod fundamentals

- **Follow-up assignments:**
  - exercises/rbac/assignment-2: Cluster-scoped RBAC
  - exercises/tls-and-certificates/assignment-1: TLS fundamentals (certificate creation)
  - exercises/crds-and-operators/assignment-2: RBAC for custom resources

COURSE MATERIAL REFERENCE:
- S7 (Lectures 143-145): Security primitives, authentication
- S7 (Lectures 160-168): API groups, authorization, RBAC
- S7 (Lectures 169-171): Service accounts
