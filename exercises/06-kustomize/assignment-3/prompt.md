I need you to create a comprehensive Kubernetes homework assignment to help me practice **Overlays and Components**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed kustomize/assignment-1 and assignment-2
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers base and overlay directory structure, environment-specific configurations, components for reusable partials, kustomization composition, and best practices. Basic kustomization and patches are assumed from assignments 1 and 2.

**In scope for this assignment:**

*Base and Overlay Directory Structure*
- Base directory: common resources
- Overlay directories: environment-specific customizations
- Overlay referencing base with resources field
- Standard structure: base/, overlays/dev/, overlays/staging/, overlays/prod/

*Environment-Specific Configurations*
- dev overlay: more replicas, debug logging
- staging overlay: production-like but smaller
- prod overlay: full resources, production settings
- Layering patches across environments

*Components*
- kind: Component
- Reusable partial configurations
- components field in kustomization.yaml
- Use cases: observability sidecar, security settings
- Component vs overlay distinction

*Kustomization Composition*
- Combining bases and overlays
- Multiple bases in single kustomization
- Overlay building on overlay
- Resource name conflicts and resolution

*Namespace Transformers*
- Setting namespace in overlay
- Overriding base namespace
- Namespace per environment

*Kustomize Best Practices*
- Directory organization
- Naming conventions
- Documentation
- Version control considerations
- When to use overlays vs patches

**Out of scope (covered in other assignments, do not include):**

- Basic kustomization.yaml (exercises/kustomize/assignment-1)
- Patches and generators (exercises/kustomize/assignment-2)
- GitOps workflows (not in CKA scope)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: kustomize-tutorial.md (section 3)
   - Explain base/overlay structure
   - Demonstrate environment-specific overlays
   - Show component usage
   - Explain composition patterns
   - Cover best practices
   - Use tutorial-kustomize namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: kustomize-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Base and Overlays**
   - Create base kustomization
   - Create dev overlay
   - Build and compare outputs

   **Level 2 (Exercises 2.1-2.3): Environment Configurations**
   - Create prod overlay with different values
   - Configure namespace per environment
   - Layer patches in overlay

   **Level 3 (Exercises 3.1-3.3): Debugging Overlay Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: base path wrong, patch not applying, namespace conflict

   **Level 4 (Exercises 4.1-4.3): Components**
   - Create reusable component
   - Include component in overlay
   - Combine component with patches

   **Level 5 (Exercises 5.1-5.3): Complete Application Structure**
   - Exercise 5.1: Design multi-environment structure
   - Exercise 5.2: Debug complex overlay chain
   - Exercise 5.3: Create production-ready kustomization

3. **Answer Key File**
   - Create the answer key: kustomize-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Relative path from overlay wrong
     - Patch in overlay not finding resource
     - Component not being included
     - Namespace transformer conflicts
     - Resource duplication
   - Overlay structure cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Overlays and Components assignment
   - Prerequisites: kustomize/assignment-1, assignment-2
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- kubectl with kustomize support
- Multi-directory structure for overlays

RESOURCE GATE:
All CKA resources are in scope (generation order 34):
- All Kubernetes resources
- Kustomize overlay operations

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-kustomize`.
- Debugging exercise headings are bare.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/kustomize/assignment-1: Kustomize fundamentals
  - exercises/kustomize/assignment-2: Patches and transformers

- **Follow-up assignments:**
  - exercises/helm/assignment-1: Alternative manifest management

COURSE MATERIAL REFERENCE:
- S13 (Lectures 263-284): Kustomize overlays, components, best practices
