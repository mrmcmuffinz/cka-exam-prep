I need you to create a comprehensive Kubernetes homework assignment to help me practice **Operators and Controllers**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed 15-crds-and-operators/assignment-1 and assignment-2
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers the operator pattern, installing existing operators, operator lifecycle management, and troubleshooting operator installations. CRD creation (assignment-1) and custom resource management (assignment-2) are assumed knowledge. Writing custom controllers in Go is NOT in CKA scope.

**In scope for this assignment:**

*Custom Controller Concept*
- Watch-reconcile loop pattern
- How controllers observe cluster state
- How controllers drive toward desired state
- Informers and work queues (conceptual)
- Kubernetes built-in controllers as examples (Deployment controller, ReplicaSet controller)

*Operator Pattern Overview*
- What operators are: controllers + CRDs for domain-specific automation
- Operator as "human operator knowledge encoded in software"
- Examples: database operators, certificate operators, monitoring operators
- When operators are useful vs. when they are overkill
- OperatorHub and community operators

*Installing Existing Operators*
- Installing operators via kubectl apply (YAML manifests)
- Installing operators via Helm charts
- Installing operators via OLM (Operator Lifecycle Manager) (conceptual)
- Common operator installation patterns
- Verifying operator deployment

*Operator Lifecycle*
- Operator deployment: watching for custom resources
- How operators respond to CR creation, update, deletion
- Operator upgrades: CRD compatibility, data migration
- Uninstalling operators: order of operations (CRs first, then CRD, then operator)

*Troubleshooting Operator Installations*
- Operator pod not starting: image pull issues, RBAC problems
- Operator not reconciling: missing CRD, wrong permissions
- Custom resources stuck: operator not watching, schema mismatch
- Operator logs for debugging
- Common operator failure patterns

*Operator Best Practices*
- When to use an operator vs. manual management
- Evaluating operator maturity and maintenance
- Operator permissions and security
- Testing operators in non-production first

**Out of scope (covered in other assignments, do not include):**

- CRD creation (exercises/15-15-crds-and-operators/assignment-1)
- Custom resource CRUD (exercises/15-15-crds-and-operators/assignment-2)
- Writing custom controllers in Go (not in CKA scope)
- Admission webhooks (not in CKA scope)
- Helm in depth (exercises/05-helm/)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: crds-and-operators-tutorial.md (section 3)
   - Explain the controller and operator patterns
   - Walk through installing a simple operator (e.g., a sample operator or well-known lightweight operator)
   - Show operator lifecycle: deploy, create CR, observe reconciliation
   - Demonstrate troubleshooting operator issues
   - Explain best practices for operator adoption
   - Use tutorial-crds namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: crds-and-operators-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Understanding Controllers**
   - Identify built-in controllers and their functions
   - Trace a Deployment controller reconciliation
   - Observe controller manager logs

   **Level 2 (Exercises 2.1-2.3): Installing Operators**
   - Install a simple operator from manifests
   - Verify operator deployment and CRD creation
   - Create a custom resource and observe operator behavior

   **Level 3 (Exercises 3.1-3.3): Debugging Operator Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: operator pod failing, CR not reconciled, operator missing RBAC

   **Level 4 (Exercises 4.1-4.3): Operator Lifecycle**
   - Upgrade an operator to a new version
   - Clean up operator installation (proper order)
   - Document operator dependencies

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Exercise 5.1: Evaluate and install an operator for a use case
   - Exercise 5.2: Debug complex operator failure
   - Exercise 5.3: Design operator adoption strategy for organization

3. **Answer Key File**
   - Create the answer key: crds-and-operators-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Deleting CRD before custom resources (orphans them)
     - Operator RBAC too restrictive
     - Version mismatch between operator and CRD
     - Not checking operator logs when troubleshooting
     - Installing operators without understanding their permissions
   - Operator troubleshooting cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Operators and Controllers assignment
   - Prerequisites: 15-crds-and-operators/assignment-1, assignment-2
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster
   - Note about operator image requirements
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- Network access to pull operator images
- kubectl client

RESOURCE GATE:
All CKA resources are in scope (generation order 13, after pre-Networking assignments):
- CustomResourceDefinitions, custom resources
- Deployments, Pods, Services
- RBAC resources
- ConfigMaps, Secrets
- Namespaces

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
  - exercises/15-15-crds-and-operators/assignment-2: Custom resources and RBAC

- **Follow-up assignments:**
  - exercises/05-05-helm/assignment-1: Helm (operators often installed via Helm)
  - exercises/19-19-troubleshooting/assignment-1: Application troubleshooting

COURSE MATERIAL REFERENCE:
- S7 (Lectures 184-187): CRDs, custom controllers, operator framework
