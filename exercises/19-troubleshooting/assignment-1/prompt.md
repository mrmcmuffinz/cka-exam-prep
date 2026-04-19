I need you to create a comprehensive Kubernetes homework assignment to help me practice **Application Troubleshooting**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed all other topic assignments
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers application-layer troubleshooting: pod failure states, crash diagnosis, resource exhaustion, configuration issues, volume failures, and service problems. This is a capstone assignment that combines failures from multiple topic areas. Control plane, node, and network troubleshooting are covered in assignments 2, 3, and 4.

**In scope for this assignment:**

*Pod Failure States*
- CrashLoopBackOff: container crashing repeatedly
- ImagePullBackOff: cannot pull container image
- ErrImagePull: image pull error
- CreateContainerError: container creation failed
- Pending: cannot be scheduled
- Terminating: stuck during deletion

*Crash Diagnosis from Logs and Events*
- kubectl logs <pod>: current container logs
- kubectl logs <pod> --previous: previous crash logs
- kubectl describe pod <pod>: events and state
- kubectl get events: cluster events
- Interpreting exit codes

*Resource Exhaustion*
- OOMKilled: out of memory
- CPU throttling symptoms
- Eviction due to node pressure
- kubectl top pods: resource usage
- metrics-server verification

*Incorrect Commands, Arguments, or Environment*
- Wrong command causing immediate crash
- Missing environment variables
- Environment variable typos
- Command vs args confusion

*Missing or Misconfigured ConfigMaps/Secrets*
- ConfigMap not found
- Secret not found
- Key not found in ConfigMap/Secret
- Wrong mount path
- Volume mount vs environment variable

*Volume Mount Failures*
- PVC not bound
- Wrong access mode
- Path not existing in container
- Permission issues
- ConfigMap/Secret mount failures

*Service Selector Mismatches*
- Empty endpoints
- Wrong selector labels
- Pods not ready
- Service in wrong namespace

**Out of scope (covered in other assignments, do not include):**

- Control plane failures (exercises/19-19-troubleshooting/assignment-2)
- Node and kubelet issues (exercises/19-19-troubleshooting/assignment-3)
- Network and DNS issues (exercises/19-19-troubleshooting/assignment-4)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: troubleshooting-tutorial.md
   - Explain troubleshooting methodology
   - Walk through each failure state
   - Show diagnostic commands
   - Demonstrate log analysis
   - Show resource monitoring
   - Use tutorial-troubleshooting namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: troubleshooting-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)
   - All exercises are debugging exercises (broken configurations to fix)
   - Exercise headings are bare (### Exercise 1.1, etc.)

   **Level 1 (Exercises 1.1-1.3): Single Failure Diagnosis**
   - Pod crashing due to wrong command
   - Pod pending due to missing PVC
   - Service with empty endpoints

   **Level 2 (Exercises 2.1-2.3): Configuration Issues**
   - Missing ConfigMap causing crash
   - Wrong Secret key reference
   - Environment variable typo

   **Level 3 (Exercises 3.1-3.3): Resource and Image Issues**
   - OOMKilled diagnosis
   - ImagePullBackOff diagnosis
   - Resource quota blocking pod

   **Level 4 (Exercises 4.1-4.3): Multi-Factor Failures**
   - Two issues in same pod
   - Deployment with cascading failures
   - Service + pod configuration issues

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Multi-tier application with multiple failures
   - Full application debugging scenario
   - Production incident simulation

3. **Answer Key File**
   - Create the answer key: troubleshooting-homework-answers.md
   - Full diagnostic workflow for each exercise
   - Explain what to check first, second, etc.
   - Common mistakes in diagnosis
   - Troubleshooting flowcharts

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Application Troubleshooting assignment
   - Prerequisites: all other topic assignments
   - Estimated time commitment: 6-8 hours
   - Cluster requirements: multi-node kind cluster
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Multi-node kind cluster
- metrics-server installed
- Various broken configurations to debug

RESOURCE GATE:
All CKA resources are in scope (generation order 35):
- All Kubernetes resources
- All troubleshooting commands

CROSS-DOMAIN NOTE:
These exercises intentionally combine failures from multiple topic areas. A single exercise might have:
- Broken Deployment configuration
- Wrong Service selector
- Missing ConfigMap
The learner must diagnose all issues to fully fix the scenario.

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-troubleshooting`.
- ALL exercise headings are bare (no descriptive titles).
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - All previous topic assignments

- **Follow-up assignments:**
  - exercises/19-19-troubleshooting/assignment-2: Control plane troubleshooting
  - exercises/19-19-troubleshooting/assignment-3: Node troubleshooting
  - exercises/19-19-troubleshooting/assignment-4: Network troubleshooting

COURSE MATERIAL REFERENCE:
- S14 (Lectures 285-288): Application failure
- All other course sections (cross-domain)
