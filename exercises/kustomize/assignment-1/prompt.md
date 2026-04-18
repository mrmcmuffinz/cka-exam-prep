I need you to create a comprehensive Kubernetes homework assignment to help me practice **Kustomize Fundamentals**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the core Kubernetes topics
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers kustomization.yaml structure, resource references, common transformers (namePrefix, nameSuffix, commonLabels, commonAnnotations), and building kustomizations. Patches are covered in assignment-2. Overlays and components are covered in assignment-3.

**In scope for this assignment:**

*kustomization.yaml Structure*
- apiVersion: kustomize.config.k8s.io/v1beta1
- kind: Kustomization
- Purpose: declarative manifest customization
- Kustomize vs Helm comparison

*Resource References*
- resources field: list of files or directories
- Relative paths to manifest files
- Including directories
- Resource ordering

*Managing Directories (Bases)*
- Using bases to reference another kustomization
- Directory structure conventions
- Base reuse across environments

*Common Transformers*
- namePrefix: add prefix to all resource names
- nameSuffix: add suffix to all resource names
- namespace: set namespace for all resources
- commonLabels: add labels to all resources
- commonAnnotations: add annotations to all resources

*Building and Applying Kustomizations*
- kubectl kustomize <directory>: build to stdout
- kubectl apply -k <directory>: build and apply
- kustomize build <directory>: standalone command
- Validating output before applying

**Out of scope (covered in other assignments, do not include):**

- Strategic merge patches (exercises/kustomize/assignment-2)
- JSON 6902 patches (exercises/kustomize/assignment-2)
- ConfigMap/Secret generators (exercises/kustomize/assignment-2)
- Overlays (exercises/kustomize/assignment-3)
- Components (exercises/kustomize/assignment-3)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: kustomize-tutorial.md
   - Explain Kustomize philosophy (template-free)
   - Walk through kustomization.yaml structure
   - Show resource references
   - Demonstrate common transformers
   - Show building and applying
   - Use tutorial-kustomize namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: kustomize-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Basic Kustomization**
   - Create kustomization.yaml with resources
   - Build and view output
   - Apply kustomization to cluster

   **Level 2 (Exercises 2.1-2.3): Common Transformers**
   - Add namePrefix to resources
   - Add commonLabels
   - Set namespace for all resources

   **Level 3 (Exercises 3.1-3.3): Debugging Kustomization Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: resource path wrong, label conflict, namespace override

   **Level 4 (Exercises 4.1-4.3): Multi-Resource Kustomizations**
   - Combine multiple resources
   - Add both labels and annotations
   - Use prefix and suffix together

   **Level 5 (Exercises 5.1-5.3): Application Scenarios**
   - Exercise 5.1: Kustomize multi-service application
   - Exercise 5.2: Debug complex kustomization
   - Exercise 5.3: Design kustomization structure for project

3. **Answer Key File**
   - Create the answer key: kustomize-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Wrong path in resources
     - YAML syntax errors
     - Label key conflicts
     - Namespace not applying to cluster-scoped resources
     - Missing apiVersion/kind
   - Kustomize commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Kustomize Fundamentals assignment
   - Prerequisites: none specific
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- kubectl with kustomize support (built-in)
- Directory for kustomization files

RESOURCE GATE:
All CKA resources are in scope (generation order 32):
- All Kubernetes resources
- Kustomize operations

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-kustomize`.
- Debugging exercise headings are bare.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - General Kubernetes familiarity

- **Follow-up assignments:**
  - exercises/kustomize/assignment-2: Patches and transformers
  - exercises/kustomize/assignment-3: Overlays and components

COURSE MATERIAL REFERENCE:
- S13 (Lectures 263-284): Kustomize basics, transformers
