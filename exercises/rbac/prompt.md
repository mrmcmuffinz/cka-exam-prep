I need you to create a comprehensive Kubernetes homework assignment to help me practice **Pod Fundamentals**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S6 (Core Concepts, Scheduling, Logging & Monitoring, Application Lifecycle Management, Cluster Maintenance, Security through KubeConfig)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment is intentionally narrow. It covers pod construction fundamentals only. It is the first in a planned series of pod-focused assignments. Other pod topics will get their own dedicated assignments later and MUST NOT appear here.

**In scope for this assignment:**
- Pod spec structure and required fields
- Single-container pod construction (imperative and declarative)
- Multi-container pods (basic mechanics, not full sidecar/ambassador/adapter patterns)
- Container commands and arguments (command vs args, Docker ENTRYPOINT/CMD equivalence)
- Environment variables as literal values
- Environment variables via downward API (fieldRef, resourceFieldRef)
- Restart policy (Always, OnFailure, Never) and its effect on pod behavior
- Image pull policy (Always, IfNotPresent, Never)
- Labels and annotations on pods
- Basic init containers (sequential execution, blocking main containers, init container failures)
- Pod phases and container statuses (Pending, Running, Succeeded, Failed, Unknown; Waiting/Running/Terminated)
- kubectl describe and kubectl logs for pod inspection

**Out of scope (covered in later assignments, do not include):**
- ConfigMaps or Secrets as env vars or volume mounts (Assignment 2: Pod Configuration Injection)
- Liveness, readiness, or startup probes (Assignment 3: Pod Health and Observability)
- Lifecycle hooks (postStart, preStop) (Assignment 3)
- terminationGracePeriodSeconds tuning (Assignment 3)
- Node selectors, node affinity, taints, tolerations, topology spread (Assignment 4: Pod Scheduling)
- Resource requests and limits, QoS classes (Assignment 5: Pod Resources and QoS)
- Advanced multi-container patterns (sidecar, ambassador, adapter), shared process namespace, native sidecars with restartPolicy: Always (Assignment 6: Multi-Container Patterns)
- ReplicaSets, Deployments, DaemonSets (Assignment 7: Workload Controllers)
- Any storage volumes beyond emptyDir for inter-container file sharing

emptyDir is permitted ONLY when needed to demonstrate multi-container file sharing in Level 4 or Level 5. Do not introduce PersistentVolumes, hostPath, or any other volume types.

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: pod-fundamentals-tutorial.md
   - Complete step-by-step tutorial showing how to build and inspect pods end-to-end
   - Include BOTH imperative (kubectl run, kubectl create) AND declarative (YAML) approaches
   - Show the imperative-to-declarative workflow explicitly: generate YAML with `--dry-run=client -o yaml`, then edit and apply
   - Explain every spec field when introducing it: what it does, what values are valid, how Kubernetes uses it, and when you'd change it from the default
   - Cover pod phases and container statuses with real examples (show a Pending pod, a Running pod, a CrashLoopBackOff pod, a Completed pod)
   - Demonstrate multi-container pod construction with an emptyDir for inter-container communication, with clear explanation that emptyDir is the only volume type in scope for this assignment
   - Show init container behavior: a pod where the init container succeeds (main starts), and a pod where the init container fails (main never starts, pod stays in Init:CrashLoopBackOff)
   - Show kubectl describe output and walk through the Events section, Conditions, and container statuses
   - Show kubectl logs variants: current container, previous container (--previous), specific container in a multi-container pod (-c), following logs (-f)
   - Tutorial should use its own namespace (tutorial-pod-fundamentals) and resource names that don't conflict with exercises
   - Tutorial should be a complete, functional workflow from start to finish

2. **Progressive Exercises (15 total)**

   **Level 1 (3 exercises): Basic single-concept tasks**
   - Single-container pod construction with one focused requirement (just a command, or just env vars, or just a specific restartPolicy)
   - Straightforward verification (2-3 checks)
   - Examples: "Create a pod named web that runs nginx:1.25 in namespace ex-1-1", "Create a pod that runs `echo hello` and exits, using restartPolicy Never", "Create a pod with two environment variables set to literal values"

   **Level 2 (3 exercises): Multi-concept tasks**
   - Combine 2-3 pod spec concepts in a single pod
   - Still single pod, single namespace, but more fields to get right
   - More verification checks (4-6 checks)
   - Examples: "Create a pod with custom command and args, specific restartPolicy, and a set of labels", "Create a multi-container pod where both containers share an emptyDir and have different commands", "Create a pod with env vars sourced from the downward API (pod name, namespace, node name)"

   **Level 3 (3 exercises): Debugging broken configurations**
   - Given broken pod YAML that fails in specific ways
   - Single clear issue per exercise (wrong image tag, wrong command syntax, command/args confusion, invalid restartPolicy value, malformed env var, init container that never succeeds, etc.)
   - Must identify the problem from pod status, events, or logs and fix it
   - Mix failure types across the three exercises: at least one "pod never starts" failure (Pending, ImagePullBackOff, Init failure) and at least one "pod starts but misbehaves" failure (CrashLoopBackOff, wrong output, exits immediately)
   - The broken YAML must be provided in the setup commands so the learner doesn't have to type it

   **Level 4 (3 exercises): Complex real-world scenarios**
   - Multi-container pods with meaningful coordination (init container prepares data, main container consumes it via emptyDir)
   - OR pods that combine downward API, custom commands, multiple containers, and specific restart behavior
   - OR realistic patterns like "a pod that runs a one-shot data loader as an init container, then runs a long-lived process as the main container, with all container logs accessible via kubectl logs"
   - 8+ verification checks covering multiple aspects of the pod
   - These are build tasks, not debugging tasks; the objective can describe what to build

   **Level 5 (3 exercises): Advanced debugging and comprehensive tasks**
   - Multiple issues in one pod spec (2-3 problems to find and fix), mixing failure modes from across the scope (e.g., one image issue AND one command issue AND one init container issue)
   - OR complex multi-container pods with subtle coordination bugs (init container writes to wrong path, main container reads from empty volume)
   - OR edge cases: a pod that looks correct but has a field value that causes unexpected behavior (restartPolicy interaction with init container failures, command vs args swapped)
   - Requires deep understanding of pod lifecycle and container interaction
   - 10+ verification checks

3. **Exercise Structure**
   - Each exercise must include:
     - Numbered heading ONLY (e.g., "### Exercise 3.1") with NO descriptive title or subtitle
     - Clear objective statement that describes the goal without telegraphing the solution
     - Complete setup commands (copy-paste ready, no placeholders)
     - Specific task description
     - Verification commands with expected results (yes/no answers where possible, or specific expected output)
   - Use unique namespaces per exercise (ex-1-1, ex-1-2, etc.)
   - Use different pod names per exercise where multiple pods exist in the learner's workflow
   - Setup commands should create the namespace and any broken resources for debugging exercises
   - Debugging exercises should provide the broken YAML via a heredoc in the setup so the learner can apply it directly

4. **Anti-Spoiler Requirements (CRITICAL for debugging exercises)**
   - Exercise headings must NOT contain descriptive titles that hint at the problem
     - BAD: "Exercise 3.1: The pod that will not start"
     - BAD: "Exercise 3.2: The command that runs the wrong thing"
     - BAD: "Exercise 5.1: Three problems in one pod"
     - GOOD: "Exercise 3.1"
   - Objective lines must NOT reveal the number or type of issues
     - BAD: "Fix the two separate issues so that the pod runs correctly"
     - BAD: "There is a problem with the init container"
     - GOOD: "Fix the broken pod so that it reaches Running state and produces the expected output"
     - GOOD: "The pod above has one or more problems. Find and fix whatever is needed so that..."
   - Task descriptions should state the desired end state, not the number or location of bugs
   - Section-level headings like "Level 3: Debugging Broken Configurations" are acceptable as navigation; per-exercise hints are not
   - Level 4 build exercises CAN describe what to build in their objectives (that's the task, not a spoiler)

5. **Resource Constraints**
   - Only use Kubernetes resources I've already learned and that are in scope for this assignment
   - In-scope resources: Pods, Namespaces, and emptyDir volumes (emptyDir only when multi-container file sharing is required)
   - Do NOT use ConfigMaps, Secrets, Services, Deployments, ReplicaSets, DaemonSets, PersistentVolumes, or any scheduling primitives (nodeSelector, affinity, taints, tolerations)
   - Do NOT use probes or lifecycle hooks
   - Do NOT use resource requests or limits
   - Container images should be small and fast: `busybox`, `alpine`, `nginx:1.25`, `nginx:1.25-alpine` are preferred. Use specific tags, never `latest`.

6. **File Format**
   - Output FOUR separate Markdown files:
     - `README.md` - Overview of all files and how to use them
     - `pod-fundamentals-tutorial.md` - Complete tutorial
     - `pod-fundamentals-homework.md` - 15 progressive exercises only
     - `pod-fundamentals-homework-answers.md` - Complete solutions
   - Use proper Markdown syntax with fenced code blocks and language tags (bash, yaml)
   - Each file should be self-contained
   - README.md should include:
     - Brief description of what each file contains
     - Recommended workflow (tutorial → homework → answers)
     - Difficulty level progression explanation
     - Prerequisites needed (kind cluster with nerdctl, CKA sections completed)
     - Estimated time commitment
     - A note that this is Assignment 1 in a pod series, with a brief list of the other planned assignments so the learner knows what's coming
   - homework.md should include:
     - Brief introduction referencing the tutorial file
     - Exercise setup commands section at the start (cluster verification, optional global cleanup)
     - All 15 exercises organized by difficulty level
     - Cleanup section at the end (per-namespace and full)
     - "Key Takeaways" section summarizing important concepts
   - tutorial.md should teach ONE complete real-world workflow end-to-end (recommend: build a small multi-container pod that demonstrates init containers, commands/args, env vars via downward API, and inspect it thoroughly)
     - Include a "Reference Commands" section at the end with imperative and declarative examples
     - Include a "Pod Phases and Container Statuses" reference table
     - This serves as a quick reference while doing exercises
   - answers.md should include solutions for all 15 exercises
     - Answer key headings should use "Exercise X.Y Solution" format (no descriptive titles needed, since answers don't spoil)

7. **Answer Key Requirements**
   - File: pod-fundamentals-homework-answers.md
   - Include complete solutions for all exercises
   - Show both imperative and declarative approaches where both are reasonable; for multi-container or init-container pods, declarative is the only realistic approach and that should be stated
   - For debugging exercises, explain what was wrong, why it caused the observed failure, and how you'd diagnose it from kubectl output (describe, logs, get pod -o yaml)
   - Include a "Common Mistakes" section covering:
     - command vs args confusion (Docker ENTRYPOINT/CMD mapping)
     - restartPolicy interaction with init container failures
     - Why `latest` tags cause reproducibility problems
     - Why multi-container pods need unique container names
     - emptyDir lifetime (tied to pod, not container)
   - Include a "Verification Commands Cheat Sheet" with the most useful kubectl commands for pod inspection

8. **Quality Standards**
   - No conflicts between tutorial and exercises (different namespaces, pod names)
   - All commands must be copy-paste ready with no manual substitution required
   - Verification commands should be specific (check phase, check container count, check env var value, check log output) not vague ("check if it works")
   - Exercises should build practical muscle memory for the CKA performance exam
   - Tutorial should teach ONE complete real-world workflow end-to-end
   - No em dashes anywhere in output (use commas, periods, or parentheses)
   - Use narrative paragraph flow in prose explanations, not stacked single-sentence declarations
   - Full replacement files, no patches or diffs

Please create the homework assignment for Pod Fundamentals.
Generate all four files: README.md, pod-fundamentals-tutorial.md, pod-fundamentals-homework.md, and pod-fundamentals-homework-answers.md