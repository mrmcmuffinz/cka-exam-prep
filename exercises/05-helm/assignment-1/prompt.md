I need you to create a comprehensive Kubernetes homework assignment to help me practice **Helm Basics**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the core Kubernetes topics
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers Helm architecture, chart repositories, installing charts, values customization, and inspecting charts. Lifecycle management (upgrade, rollback) is covered in assignment-2. Templates and debugging are covered in assignment-3.

**In scope for this assignment:**

*Helm Architecture and Concepts*
- What Helm is: package manager for Kubernetes
- Charts: packaged Kubernetes resources
- Releases: installed instances of charts
- Revisions: versions of a release
- Helm client (no server component since Helm 3)

*Chart Repositories*
- Adding repositories: helm repo add
- Listing repositories: helm repo list
- Searching repositories: helm search repo
- Updating repository index: helm repo update
- Removing repositories: helm repo remove
- Artifact Hub for discovering charts

*Installing Charts*
- helm install <release-name> <chart>
- Installing from repository: helm install nginx bitnami/nginx
- Installing from local directory
- Installing from URL
- Specifying namespace: --namespace, --create-namespace
- Release naming conventions

*Values Customization*
- Default values in charts
- Overriding with --set: helm install --set key=value
- Multiple --set flags
- Nested values: --set parent.child=value
- Array values: --set servers[0]=host1
- Understanding value precedence

*Inspecting Charts*
- helm show chart: chart metadata
- helm show values: default values
- helm show readme: chart README
- helm show all: everything
- Understanding chart structure

*Listing and Managing Releases*
- helm list: show installed releases
- helm list --all-namespaces
- helm status <release>: release status and notes
- helm get values <release>: current values
- helm get manifest <release>: rendered manifests

**Out of scope (covered in other assignments, do not include):**

- helm upgrade (exercises/05-05-helm/assignment-2)
- helm rollback (exercises/05-05-helm/assignment-2)
- Values files (exercises/05-05-helm/assignment-2)
- helm template (exercises/05-05-helm/assignment-3)
- Helm hooks (exercises/05-05-helm/assignment-3)
- Chart authoring (not in CKA scope)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: helm-tutorial.md
   - Explain Helm architecture and concepts
   - Walk through repository management
   - Demonstrate chart installation
   - Show values customization with --set
   - Show chart inspection commands
   - Use tutorial-helm namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: helm-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Repository Management**
   - Add a chart repository
   - Search for charts
   - Update repository index

   **Level 2 (Exercises 2.1-2.3): Chart Installation**
   - Install a chart with default values
   - Install with custom namespace
   - List and status installed releases

   **Level 3 (Exercises 3.1-3.3): Debugging Installation Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: wrong chart name, namespace issue, values error

   **Level 4 (Exercises 4.1-4.3): Values Customization**
   - Install with --set values
   - Configure nested values
   - Inspect chart values and customize

   **Level 5 (Exercises 5.1-5.3): Complex Installations**
   - Exercise 5.1: Install multi-component application
   - Exercise 5.2: Debug installation with wrong values
   - Exercise 5.3: Document installation for team

3. **Answer Key File**
   - Create the answer key: helm-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Repository not updated before search
     - Release name conflicts
     - Wrong --set syntax
     - Namespace not existing
     - Chart not found in repository
   - Helm commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Helm Basics assignment
   - Prerequisites: none specific
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster
   - Helm installation instructions
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- Helm CLI installed
- Internet access for repository operations

RESOURCE GATE:
All CKA resources are in scope (generation order 29):
- All Kubernetes resources (Helm creates them)
- Helm-specific operations

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-helm`.
- Debugging exercise headings are bare.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - General Kubernetes familiarity

- **Follow-up assignments:**
  - exercises/05-05-helm/assignment-2: Helm lifecycle management
  - exercises/05-05-helm/assignment-3: Helm templates and debugging

COURSE MATERIAL REFERENCE:
- S12 (Lectures 252-262): Helm introduction, charts, values, lifecycle management
