I need you to create a comprehensive Kubernetes homework assignment to help me practice **Helm Lifecycle Management**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed helm/assignment-1 (Helm Basics)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers upgrading releases, values files, rollbacks, release history, and uninstalling releases. Chart installation basics are assumed from assignment-1. Templates and debugging are covered in assignment-3.

**In scope for this assignment:**

*Upgrading Releases*
- helm upgrade <release> <chart>
- Upgrade to new chart version
- Upgrade with changed values
- --install flag for upgrade-or-install
- Atomic upgrades with --atomic
- Dry run with --dry-run

*Values Files*
- Creating values.yaml files
- helm install -f values.yaml
- helm upgrade -f values.yaml
- Multiple values files (later files override)
- Combining -f with --set (--set takes precedence)

*Reusing Values*
- --reuse-values: keep existing values
- --reset-values: use chart defaults
- When to use each option
- Pitfalls of --reuse-values with chart upgrades

*Rolling Back Releases*
- helm rollback <release> <revision>
- Rolling back to previous revision
- Rolling back to specific revision
- What rollback changes (new revision created)
- Rollback limitations

*Release History*
- helm history <release>
- Understanding revision numbers
- Status of each revision
- Description field showing what changed
- Maximum history: --history-max

*Uninstalling Releases*
- helm uninstall <release>
- What gets deleted (all resources)
- --keep-history flag
- Reinstalling after uninstall
- Namespace cleanup

**Out of scope (covered in other assignments, do not include):**

- Repository management (exercises/helm/assignment-1)
- Chart installation basics (exercises/helm/assignment-1)
- helm template (exercises/helm/assignment-3)
- Helm hooks (exercises/helm/assignment-3)
- Chart authoring (not in CKA scope)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: helm-tutorial.md (section 2)
   - Demonstrate upgrade workflow
   - Show values file usage
   - Explain --reuse-values vs --reset-values
   - Walk through rollback process
   - Show release history
   - Demonstrate uninstall
   - Use tutorial-helm namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: helm-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Upgrade Operations**
   - Upgrade release with new values
   - Use --dry-run to preview
   - View release history

   **Level 2 (Exercises 2.1-2.3): Values Files**
   - Create and use values file
   - Override values file with --set
   - Use multiple values files

   **Level 3 (Exercises 3.1-3.3): Debugging Lifecycle Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: upgrade failed, wrong values reused, rollback target wrong

   **Level 4 (Exercises 4.1-4.3): Rollback Operations**
   - Roll back to previous revision
   - Roll back to specific revision
   - Understand rollback creates new revision

   **Level 5 (Exercises 5.1-5.3): Complex Lifecycle**
   - Exercise 5.1: Full lifecycle (install, upgrade, rollback, uninstall)
   - Exercise 5.2: Debug failed upgrade and recover
   - Exercise 5.3: Design upgrade strategy with rollback plan

3. **Answer Key File**
   - Create the answer key: helm-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - --reuse-values with new chart version
     - Rollback to non-existent revision
     - Values file syntax errors
     - Upgrade changing unexpected values
     - Uninstall not cleaning up PVCs
   - Lifecycle commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Helm Lifecycle Management assignment
   - Prerequisites: helm/assignment-1
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- Helm CLI installed
- Releases from assignment-1 or new installations

RESOURCE GATE:
All CKA resources are in scope (generation order 30):
- All Kubernetes resources
- Helm lifecycle operations

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-helm`.
- Debugging exercise headings are bare.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/helm/assignment-1: Helm basics

- **Follow-up assignments:**
  - exercises/helm/assignment-3: Helm templates and debugging

COURSE MATERIAL REFERENCE:
- S12 (Lectures 252-262): Helm lifecycle management
