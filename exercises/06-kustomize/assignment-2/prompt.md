I need you to create a comprehensive Kubernetes homework assignment to help me practice **Patches and Transformers**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed 06-kustomize/assignment-1 (Kustomize Fundamentals)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers strategic merge patches, JSON 6902 patches, inline patches, image transformers, and ConfigMap/Secret generators. Basic kustomization is assumed from assignment-1. Overlays and components are covered in assignment-3.

**In scope for this assignment:**

*Strategic Merge Patches*
- patchesStrategicMerge in kustomization.yaml
- Patch file format (partial resource definition)
- Merging behavior for different fields
- Deleting fields with null or $patch: delete
- List field behavior

*JSON 6902 Patches*
- patchesJson6902 in kustomization.yaml
- Target specification (group, version, kind, name)
- Operation types: add, remove, replace, move, copy, test
- Path syntax with JSON Pointer
- When to use JSON 6902 vs strategic merge

*Inline Patches*
- patches field in kustomization.yaml
- Combining target and patch inline
- Patch content directly in kustomization.yaml
- Cleaner for small patches

*Image Transformers*
- images field in kustomization.yaml
- Changing image name
- Changing image tag
- Changing image digest
- newName, newTag, digest fields

*ConfigMap and Secret Generators*
- configMapGenerator in kustomization.yaml
- secretGenerator in kustomization.yaml
- From literals
- From files
- From env files
- Behavior: create, replace, merge

*Patch Targets and Selectors*
- Targeting by name
- Targeting by label selector
- Targeting by annotation selector
- Applying same patch to multiple resources

**Out of scope (covered in other assignments, do not include):**

- Basic kustomization.yaml (exercises/06-06-kustomize/assignment-1)
- Common transformers (exercises/06-06-kustomize/assignment-1)
- Overlays (exercises/06-06-kustomize/assignment-3)
- Components (exercises/06-06-kustomize/assignment-3)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: kustomize-tutorial.md (section 2)
   - Explain strategic merge patches
   - Demonstrate JSON 6902 patches
   - Show inline patches
   - Demonstrate image transformers
   - Show ConfigMap/Secret generators
   - Use tutorial-kustomize namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: kustomize-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Strategic Merge Patches**
   - Create patch to modify replicas
   - Create patch to add environment variable
   - Create patch to modify resources

   **Level 2 (Exercises 2.1-2.3): JSON 6902 and Images**
   - Create JSON 6902 patch
   - Change container image with transformer
   - Change image tag only

   **Level 3 (Exercises 3.1-3.3): Debugging Patch Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: patch not applying, wrong target, JSON path error

   **Level 4 (Exercises 4.1-4.3): Generators**
   - Create ConfigMap from literals
   - Create Secret from file
   - Use generator behavior options

   **Level 5 (Exercises 5.1-5.3): Complex Patching**
   - Exercise 5.1: Multiple patches on same resource
   - Exercise 5.2: Debug complex patch chain
   - Exercise 5.3: Design patch strategy for application

3. **Answer Key File**
   - Create the answer key: kustomize-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Strategic merge not merging lists as expected
     - JSON 6902 path wrong
     - Target not matching resource
     - Generator hash suffix unexpected
     - Patch file syntax errors
   - Patch types comparison cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Patches and Transformers assignment
   - Prerequisites: 06-kustomize/assignment-1
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- kubectl with kustomize support
- Directory structure for kustomization

RESOURCE GATE:
All CKA resources are in scope (generation order 33):
- All Kubernetes resources
- Kustomize patch operations

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-kustomize`.
- Debugging exercise headings are bare.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/06-06-kustomize/assignment-1: Kustomize fundamentals

- **Follow-up assignments:**
  - exercises/06-06-kustomize/assignment-3: Overlays and components

COURSE MATERIAL REFERENCE:
- S13 (Lectures 263-284): Kustomize patches, transformers, generators
