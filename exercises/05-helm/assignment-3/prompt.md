I need you to create a comprehensive Kubernetes homework assignment to help me practice **Helm Templates and Debugging**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed 05-helm/assignment-1 and assignment-2
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers template rendering, debugging installations, Helm hooks, chart dependencies, and best practices. Chart installation and lifecycle management are assumed from assignments 1 and 2.

**In scope for this assignment:**

*Template Rendering*
- helm template: render without installing
- Rendering to stdout or file
- Validating rendered output
- Debugging template issues
- Using --debug with install/upgrade

*Debugging Chart Installations*
- helm install --debug --dry-run
- Understanding error messages
- Template rendering errors
- Values validation errors
- Resource creation failures

*Helm Hooks*
- pre-install: run before resources created
- post-install: run after resources created
- pre-upgrade, post-upgrade
- pre-delete, post-delete
- Hook weight and deletion policy
- Common hook use cases (migrations, notifications)

*Chart Dependencies*
- dependencies in Chart.yaml
- helm dependency update
- helm dependency build
- Condition and tags for optional dependencies
- Subcharts and values passing

*Helm Secrets and Sensitive Data*
- Secrets in values files
- Using --set for secrets
- Secrets and revision history
- Best practices for sensitive values
- helm-secrets plugin (conceptual)

*Helm Best Practices*
- Naming conventions
- Chart versioning
- Values documentation
- Resource labels and annotations
- Chart testing

**Out of scope (covered in other assignments, do not include):**

- Repository management (exercises/05-05-helm/assignment-1)
- Basic installation (exercises/05-05-helm/assignment-1)
- Upgrade and rollback (exercises/05-05-helm/assignment-2)
- Chart authoring (not in CKA scope)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: helm-tutorial.md (section 3)
   - Demonstrate helm template usage
   - Show debugging techniques
   - Explain Helm hooks with examples
   - Show dependency management
   - Discuss secrets handling
   - Cover best practices
   - Use tutorial-helm namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: helm-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Template Rendering**
   - Render chart templates locally
   - Compare rendered output with different values
   - Validate rendered manifests

   **Level 2 (Exercises 2.1-2.3): Debugging**
   - Debug installation failure
   - Use --dry-run effectively
   - Diagnose template errors

   **Level 3 (Exercises 3.1-3.3): Debugging Complex Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: template syntax error, hook failure, dependency missing

   **Level 4 (Exercises 4.1-4.3): Advanced Features**
   - Understand chart with hooks
   - Manage chart dependencies
   - Handle secrets in values

   **Level 5 (Exercises 5.1-5.3): Production Scenarios**
   - Exercise 5.1: Debug complex chart installation
   - Exercise 5.2: Audit chart for best practices
   - Exercise 5.3: Create Helm usage documentation for team

3. **Answer Key File**
   - Create the answer key: helm-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Template syntax errors in values
     - Hook not running (wrong annotation)
     - Dependencies not updated
     - Secrets visible in history
     - Not using --dry-run before production
   - Debugging commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Helm Templates and Debugging assignment
   - Prerequisites: 05-helm/assignment-1, assignment-2
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- Helm CLI installed
- Charts with various features for testing

RESOURCE GATE:
All CKA resources are in scope (generation order 31):
- All Kubernetes resources
- Helm template and debugging operations

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-helm`.
- Debugging exercise headings are bare.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/05-05-helm/assignment-1: Helm basics
  - exercises/05-05-helm/assignment-2: Helm lifecycle

- **Follow-up assignments:**
  - exercises/06-06-kustomize/assignment-1: Alternative manifest management

COURSE MATERIAL REFERENCE:
- S12 (Lectures 252-262): Helm templates, debugging
