I need you to create a comprehensive Kubernetes homework assignment to help me practice **Custom Resource Definitions**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S7 (through CRDs and operators)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers CRD structure, schema definition, versioning, validation rules, and status subresources. Creating and managing custom resources using CRDs is covered in assignment-2. Operators and controllers are covered in assignment-3.

**In scope for this assignment:**

*CRD Spec Structure*
- apiVersion: apiextensions.k8s.io/v1
- kind: CustomResourceDefinition
- metadata: name follows <plural>.<group> format
- spec.group: API group for the custom resource
- spec.versions: list of supported versions with schema
- spec.scope: Namespaced or Cluster
- spec.names: plural, singular, kind, shortNames, categories

*CRD Schema Definition (OpenAPI v3)*
- spec.versions[].schema.openAPIV3Schema
- type: object, string, integer, boolean, array
- properties: field definitions
- required: mandatory field list
- description: field documentation
- Nested objects and arrays
- Additional properties and patterns

*CRD Versioning Strategies*
- Multiple versions in spec.versions
- served: whether version is available via API
- storage: which version is stored (only one can be true)
- Version compatibility and conversion (conceptual)
- Deprecating versions

*Creating and Applying CRDs*
- kubectl apply -f crd.yaml
- kubectl get crd to list all CRDs
- kubectl describe crd to inspect
- CRD becomes available immediately after creation
- Deleting CRDs (also deletes all custom resources)

*CRD Validation Rules*
- Type validation (built-in)
- Required fields
- Enum values for restricted choices
- Pattern matching with regex
- Minimum/maximum for numbers
- MinLength/maxLength for strings
- Format hints (date-time, email, etc.)

*CRD Status Subresources*
- spec.versions[].subresources.status
- Separating spec from status
- Status updates via /status endpoint
- Why separate status: controller-managed vs user-managed

*CRD Scale and Print Columns*
- spec.versions[].additionalPrinterColumns for kubectl output
- spec.versions[].subresources.scale for HPA integration (conceptual)
- Customizing kubectl get output

**Out of scope (covered in other assignments, do not include):**

- Custom resource CRUD operations (exercises/crds-and-operators/assignment-2)
- RBAC for custom resources (exercises/crds-and-operators/assignment-2)
- Operators and controllers (exercises/crds-and-operators/assignment-3)
- Writing custom controllers in Go (not in CKA scope)
- Admission webhooks for CRDs (not in CKA scope)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: crds-and-operators-tutorial.md
   - Explain what CRDs are and why they extend Kubernetes
   - Walk through creating a simple CRD step by step
   - Explain each section of the CRD spec
   - Demonstrate schema definition with validation
   - Show versioning and status subresources
   - Use tutorial-crds namespace where applicable

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: crds-and-operators-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Basic CRD Creation**
   - Create a simple CRD with minimal schema
   - List and describe the CRD
   - Verify the new API resource is available

   **Level 2 (Exercises 2.1-2.3): Schema Definition**
   - Add typed properties to CRD schema
   - Add required fields and validation
   - Add nested objects to schema

   **Level 3 (Exercises 3.1-3.3): Debugging CRD Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: invalid CRD name format, schema validation error, missing required schema fields

   **Level 4 (Exercises 4.1-4.3): Advanced CRD Features**
   - Configure status subresource
   - Add additional printer columns
   - Configure multiple versions

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Exercise 5.1: Design CRD for a specific use case (e.g., BackupSchedule)
   - Exercise 5.2: Migrate CRD to new version while maintaining compatibility
   - Exercise 5.3: Create comprehensive CRD with all features

3. **Answer Key File**
   - Create the answer key: crds-and-operators-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Wrong CRD name format (must be plural.group)
     - Missing openAPIV3Schema (required in v1)
     - Storage version not set
     - Deleting CRD deletes all custom resources
     - Scope mismatch between CRD and resources
   - CRD reference cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Custom Resource Definitions assignment
   - Prerequisites: general Kubernetes resource understanding
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- kubectl client
- No special configuration needed

RESOURCE GATE:
This assignment uses a restricted resource gate (generation order 11):
- CustomResourceDefinitions
- Namespaces
- Do NOT use: Services, Ingress, PersistentVolumes, NetworkPolicies, custom resources (covered in assignment-2)

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-crds`.
- Debugging exercise headings are bare.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - General Kubernetes resource familiarity

- **Follow-up assignments:**
  - exercises/crds-and-operators/assignment-2: Custom resources and RBAC
  - exercises/crds-and-operators/assignment-3: Operators and controllers

COURSE MATERIAL REFERENCE:
- S7 (Lectures 184-187): CRDs, custom controllers, operator framework
