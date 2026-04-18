I need you to create a comprehensive Kubernetes homework assignment to help me practice **Pod Fundamentals**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S2 (Introduction and Core Concepts through lecture 32)
- This is my first homework assignment in the CKA exam prep series
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment is intentionally narrow. It covers pod construction fundamentals only. It is the first in a planned series of seven pod-focused assignments. Other pod topics will get their own dedicated assignments later and MUST NOT appear here.

**In scope for this assignment:**

*Pod Spec Structure*
- apiVersion: v1, kind: Pod, metadata, spec structure
- Required fields: name, containers
- Pod naming conventions and DNS-safe names

*Single-Container Pod Construction*
- Imperative creation with kubectl run
- Declarative creation with YAML
- Generating YAML with --dry-run=client -o yaml
- Container spec: name, image, command, args

*Multi-Container Pods*
- Basic mechanics of multiple containers in one pod
- Shared network namespace (localhost communication)
- Shared storage via emptyDir (introduction only)
- Container naming within multi-container pods

*Container Commands and Arguments*
- command field (overrides Docker ENTRYPOINT)
- args field (overrides Docker CMD)
- How command and args interact
- Shell form vs exec form considerations

*Environment Variables*
- Literal values via env.name and env.value
- Downward API via fieldRef (pod name, namespace, node name, pod IP)
- Downward API via resourceFieldRef (requests, limits) (conceptual only, no resource limits yet)

*Restart Policy*
- Always (default): restarts on any exit
- OnFailure: restarts only on non-zero exit
- Never: no restarts
- Interaction with pod phase and container state

*Image Pull Policy*
- Always: always pull from registry
- IfNotPresent: use local if available
- Never: only use local images
- How tag affects default policy (:latest vs specific tag)

*Labels and Annotations*
- Adding labels to pods
- Adding annotations to pods
- Label syntax and conventions
- When to use labels vs annotations

*Basic Init Containers*
- Init container concept: runs before main containers
- Sequential execution of multiple init containers
- Init container failure blocks main container start
- Common use cases: setup, waiting for dependencies

*Pod Phases and Container Statuses*
- Pod phases: Pending, Running, Succeeded, Failed, Unknown
- Container states: Waiting, Running, Terminated
- Container state reasons: ContainerCreating, CrashLoopBackOff, Completed, Error
- How restart policy affects phase transitions

*Pod Inspection*
- kubectl describe pod for events and status
- kubectl logs for container output
- kubectl logs --previous for crashed container logs
- kubectl logs -c for specific container in multi-container pod

**Out of scope (covered in later assignments, do not include):**

- ConfigMaps or Secrets as env vars or volume mounts (Assignment 2: Pod Configuration Injection)
- Liveness, readiness, or startup probes (Assignment 3: Pod Health and Observability)
- Lifecycle hooks (postStart, preStop) (Assignment 3)
- terminationGracePeriodSeconds tuning (Assignment 3)
- Node selectors, node affinity, taints, tolerations, topology spread (Assignment 4: Pod Scheduling)
- Resource requests and limits, QoS classes (Assignment 5: Pod Resources and QoS)
- Advanced multi-container patterns (sidecar, ambassador, adapter), shared process namespace, native sidecars (Assignment 6: Multi-Container Patterns)
- ReplicaSets, Deployments, DaemonSets (Assignment 7: Workload Controllers)
- Security contexts (runAsUser, capabilities) (security-contexts assignments)
- Any storage volumes beyond emptyDir for inter-container file sharing

emptyDir is permitted ONLY when needed to demonstrate multi-container file sharing. Do not introduce PersistentVolumes, hostPath, or any other volume types.

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: pods-tutorial.md
   - Complete step-by-step tutorial showing how to build and inspect pods end-to-end
   - Include BOTH imperative (kubectl run) AND declarative (YAML) approaches
   - Show the imperative-to-declarative workflow: generate YAML with --dry-run=client -o yaml
   - Explain every spec field when introducing it
   - Cover pod phases and container statuses with real examples
   - Demonstrate multi-container pod construction with emptyDir
   - Show init container behavior (success and failure scenarios)
   - Show kubectl describe and kubectl logs usage
   - Use tutorial-pods namespace
   - Include cleanup commands

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: pods-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)
   - Each exercise is self-contained with setup commands and verification commands
   - Every exercise uses its own namespace: ex-1-1, ex-1-2, etc.

   **Level 1 (Exercises 1.1-1.3): Basic Pod Creation**
   - Create single-container pods imperatively and declaratively
   - Verify pod creation and inspect basic configuration
   - Test connectivity from within the pod

   **Level 2 (Exercises 2.1-2.3): Commands, Args, and Environment**
   - Configure custom commands and arguments
   - Set environment variables (literal and downward API)
   - Configure different restart policies

   **Level 3 (Exercises 3.1-3.3): Debugging Broken Pods**
   - Three debugging exercises with broken pod configurations
   - Exercise headings are bare (### Exercise 3.1) with no descriptive titles
   - Scenarios: wrong image tag, command syntax error, init container failure

   **Level 4 (Exercises 4.1-4.3): Multi-Container and Init Containers**
   - Create multi-container pods with shared emptyDir
   - Configure init containers for setup tasks
   - Combine multiple concepts in one pod

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Exercise 5.1: Complex multi-container pod with init containers
   - Exercise 5.2: Debug pod with multiple issues
   - Exercise 5.3: Design pod for specific requirements

3. **Answer Key File**
   - Create the answer key: pods-homework-answers.md
   - Full solutions for all 15 exercises with explanations
   - For debugging exercises, explain diagnostic workflow
   - Common mistakes section covering:
     - command vs args confusion (Docker ENTRYPOINT/CMD mapping)
     - restartPolicy interaction with pod phases
     - Why :latest tags cause reproducibility problems
     - Multi-container pods need unique container names
     - emptyDir lifetime tied to pod
   - Verification commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of the Pod Fundamentals assignment
   - Prerequisites: kind cluster with nerdctl
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster
   - Recommended workflow: tutorial, homework, answers
   - Note that this is Assignment 1 in a 7-assignment pod series

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- No special CNI requirements
- kubectl client

RESOURCE GATE:
This assignment uses a restricted resource gate (first assignment in series):
- Pods
- Namespaces
- emptyDir volumes (for multi-container file sharing only)
- Do NOT use: ConfigMaps, Secrets, Services, Deployments, ReplicaSets, PersistentVolumes, NetworkPolicies

KIND CLUSTER SETUP:
Single-node kind cluster is sufficient:
```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

CONVENTIONS:
- No em dashes anywhere in generated content. Use commas, periods, or parentheses.
- Narrative paragraph flow in prose sections, not stacked single-sentence bullet points.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-pods`.
- Debugging exercise headings are bare (### Exercise 3.1) with no descriptive titles.
- Container images use explicit version tags: nginx:1.25, busybox:1.36, alpine:3.19
- Full file replacements when generating, never patches or diffs.

CROSS-REFERENCES:
- **Prerequisites:** None (first assignment)

- **Follow-up assignments:**
  - exercises/pods/assignment-2: Pod Configuration Injection (ConfigMaps, Secrets)
  - exercises/pods/assignment-3: Pod Health and Observability (probes, hooks)
  - exercises/pods/assignment-4: Pod Scheduling and Placement
  - exercises/pods/assignment-5: Pod Resources and QoS
  - exercises/pods/assignment-6: Multi-Container Patterns
  - exercises/pods/assignment-7: Workload Controllers

COURSE MATERIAL REFERENCE:
This assignment aligns with Mumshad CKA course sections:
- S2 (Lectures 18-32): Pods, ReplicaSets, Deployments (pod fundamentals only, controllers deferred to assignment-7)
