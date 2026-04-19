I need you to create a comprehensive Kubernetes homework assignment to help me practice **Pod Health and Observability**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S6 (Core Concepts, Scheduling, Logging & Monitoring, Application Lifecycle Management, Cluster Maintenance, Security through KubeConfig)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment is the third in a planned series of pod-focused assignments. It covers how Kubernetes determines whether a pod is healthy, how pods signal their state through probes and lifecycle hooks, and how operators inspect pod behavior through logs and events. Pod construction fundamentals (Assignment 1) and configuration injection (Assignment 2) are assumed knowledge. Other pod topics will get their own dedicated assignments later and MUST NOT appear here.

**In scope for this assignment:**
- Liveness probes (exec, httpGet, tcpSocket) and what happens when they fail (container restart)
- Readiness probes (exec, httpGet, tcpSocket) and what happens when they fail (pod removed from Service endpoints; for this assignment, observe the Ready condition, Services are out of scope)
- Startup probes (exec, httpGet, tcpSocket) and their relationship to liveness/readiness probes (startup must succeed before liveness and readiness begin)
- Probe tuning fields: initialDelaySeconds, periodSeconds, timeoutSeconds, successThreshold, failureThreshold
- When to choose each probe type (exec for CLI checks, httpGet for web endpoints, tcpSocket for raw port checks)
- Lifecycle hooks: postStart (runs after container starts, does not block ready state but blocks Running state until complete) and preStop (runs before SIGTERM, blocks termination until complete or grace period expires)
- Lifecycle hook handler types: exec and httpGet (same structure as probes)
- terminationGracePeriodSeconds tuning and how it interacts with preStop hooks and SIGTERM handling
- Pod termination sequence: preStop hook fires, SIGTERM sent, grace period counts down, SIGKILL sent if still running
- Container log inspection: kubectl logs with --previous for crashed containers, --container for multi-container pods, --follow for live tailing, --tail and --since for bounded output, --timestamps for log correlation
- Events as a diagnostic source: kubectl get events, kubectl describe pod showing the Events section, event reasons (FailedScheduling, Unhealthy, BackOff, Killing, Started, Created)
- Pod conditions: PodScheduled, Initialized, ContainersReady, Ready, and how probes affect them
- Container statuses: Waiting (with reasons like ContainerCreating, CrashLoopBackOff, ImagePullBackOff), Running, Terminated (with reasons like Completed, Error, OOMKilled)
- restartCount and last termination state (lastState.terminated) for post-mortem analysis

**Out of scope (covered in other assignments, do not include):**
- Pod spec fundamentals, commands/args, restart policy, image pull policy, labels/annotations (Assignment 1: Pod Fundamentals)
- Init containers (Assignment 1 for basics, Assignment 6 for advanced patterns)
- ConfigMaps and Secrets in any form (Assignment 2: Pod Configuration Injection)
- Node selectors, node affinity, taints, tolerations (Assignment 4: Pod Scheduling)
- Resource requests and limits, QoS classes (Assignment 5: Pod Resources and QoS). Note: OOMKilled is in scope as a diagnostic signal, but configuring resource limits to cause or avoid OOMKilled is not; the learner will observe OOMKilled as an outcome, not tune for it
- Advanced multi-container patterns, native sidecars (Assignment 6)
- ReplicaSets, Deployments, DaemonSets, Services (Assignment 7 and beyond)
- Cluster-level logging aggregation, metrics-server, Prometheus, EFK stack
- NetworkPolicies or any networking behavior beyond what tcpSocket and httpGet probes need

Probe handlers that make HTTP requests should hit endpoints the container itself serves (nginx default page, a simple python http.server, a busybox nc listener). Do not introduce Services, Ingress, or external endpoints. Exec probes should use standard shell tools available in busybox or alpine.

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: pod-health-observability-tutorial.md
   - Complete step-by-step tutorial showing how to configure probes, lifecycle hooks, and diagnose pod health issues end-to-end
   - Include BOTH imperative (kubectl run with flags where possible, though probes generally require YAML) AND declarative (YAML) approaches
   - Be honest that probes and lifecycle hooks are declarative-only in practice; the imperative workflow is "kubectl run --dry-run=client -o yaml, then edit to add probes"
   - Explain every probe field when introducing it: what it does, what values are valid, default values, and how the Kubernetes probe state machine uses it
   - Cover all three probe types (exec, httpGet, tcpSocket) with working examples for each, and cover all three probe purposes (liveness, readiness, startup) with at least one working example each
   - Demonstrate probe failures live: configure a liveness probe that will fail, show the pod restarting, examine restartCount and lastState.terminated
   - Demonstrate readiness probe behavior: configure a readiness probe that starts failing, show the pod transitioning from Ready to NotReady without restarting
   - Demonstrate startup probe behavior: show a container with a slow startup that would be killed by a liveness probe alone, then show the same container with a startup probe protecting it
   - Cover probe tuning with a concrete walkthrough: given a container that takes 10 seconds to start, 500ms per health check, and occasionally hiccups for 2 seconds, calculate appropriate initialDelaySeconds, periodSeconds, timeoutSeconds, and failureThreshold values
   - Demonstrate a postStart hook and a preStop hook with exec handlers
   - Demonstrate terminationGracePeriodSeconds: show a pod with a preStop hook that sleeps, delete the pod, and watch the grace period count down in the Events
   - Show the diagnostic workflow: when a pod is unhealthy, use kubectl describe pod to read Events, kubectl logs to read container output, kubectl logs --previous to read output from a crashed container, and kubectl get pod -o yaml to inspect conditions and container statuses
   - Include a walkthrough of a CrashLoopBackOff scenario: show the progression of Events, the restartCount increasing, and how to read lastState.terminated.exitCode and lastState.terminated.reason
   - Tutorial should use its own namespace (tutorial-pod-health) and resource names that don't conflict with exercises
   - Tutorial should be a complete, functional workflow from start to finish

2. **Progressive Exercises (15 total)**

   **Level 1 (3 exercises): Basic single-concept tasks**
   - One probe OR one lifecycle hook on a single-container pod
   - Straightforward verification (2-3 checks)
   - Examples: "Create a pod running nginx:1.25 with an httpGet liveness probe on port 80 path /", "Create a pod with an exec readiness probe that checks for the existence of /tmp/ready", "Create a pod with a preStop exec hook that writes a message to stdout before termination"

   **Level 2 (3 exercises): Multi-concept tasks**
   - Combine 2-3 health/observability concepts on one pod (e.g., liveness AND readiness probes with different handler types, or a startup probe AND a liveness probe with correct tuning, or a preStop hook AND custom terminationGracePeriodSeconds)
   - Include probe tuning that requires specific field values, not just defaults
   - Still single pod, single namespace
   - More verification checks (4-6 checks)
   - Examples: "Create a pod with a startup probe (initialDelaySeconds 5, failureThreshold 30, periodSeconds 2) and a liveness probe (periodSeconds 10) that protects a slow-starting container", "Create a pod with an httpGet liveness probe and an exec readiness probe, both with non-default tuning values"

   **Level 3 (3 exercises): Debugging broken configurations**
   - Given broken pod YAML that fails in specific ways related to probes, lifecycle hooks, or termination
   - Single clear issue per exercise. Mix failure types across the three exercises:
     - At least one "probe is misconfigured and the pod enters CrashLoopBackOff when it shouldn't" failure (probe hits wrong port, wrong path, exec command that doesn't exist in the container, initialDelaySeconds too short)
     - At least one "probe looks correct but semantics are wrong" failure (liveness probe where a readiness probe is needed, startup probe missing so liveness kills the container during startup, timeoutSeconds longer than periodSeconds)
     - At least one "pod appears healthy but doesn't do what's expected" failure (postStart hook that silently fails, preStop hook that never fires because of wrong handler syntax, termination that's killed abruptly because grace period is too short)
   - Must identify the problem from Events, logs, conditions, or restartCount and fix it
   - The broken YAML must be provided in the setup commands so the learner doesn't have to type it

   **Level 4 (3 exercises): Complex real-world scenarios**
   - Realistic production-style health configuration:
     - A pod running a web server that needs a startup probe (for slow initial startup), a readiness probe (for traffic gating), and a liveness probe (for hang detection), all with appropriate tuning
     - A pod with a preStop hook that performs graceful shutdown (e.g., runs a command that flushes pending work) and a terminationGracePeriodSeconds long enough to accommodate it
     - A multi-container pod where one container is the main application and another has different probe configuration, and the learner must observe both containers' health states independently
   - Each build should exercise probe tuning decisions based on stated container behavior
   - 8+ verification checks covering multiple aspects (probe configuration values, pod conditions, container statuses, Events, restartCount over time)
   - These are build tasks, not debugging tasks; the objective can describe what to build

   **Level 5 (3 exercises): Advanced debugging and comprehensive tasks**
   - Multiple issues in one pod spec (2-3 problems across probes, hooks, and termination)
   - Subtle issues: probe timeout exceeds period (probes overlap and exhaust connections), failureThreshold of 1 making the pod flaky, startup probe that never transitions control to liveness probe because its periodSeconds * failureThreshold is too short, preStop hook that blocks longer than terminationGracePeriodSeconds and gets killed mid-cleanup, httpGet probe without a matching container port
   - OR a comprehensive build task with specific stated requirements for startup time, acceptable hang detection window, and graceful shutdown behavior, where the learner must translate those requirements into correctly-tuned probe and termination fields
   - Requires deep understanding of probe timing, the lifecycle hook sequence, and the pod termination state machine
   - 10+ verification checks

3. **Exercise Structure**
   - Each exercise must include:
     - Numbered heading ONLY (e.g., "### Exercise 3.1") with NO descriptive title or subtitle
     - Clear objective statement that describes the goal without telegraphing the solution
     - Complete setup commands (copy-paste ready, no placeholders)
     - Specific task description
     - Verification commands with expected results (specific expected output, not vague checks)
   - Use unique namespaces per exercise (ex-1-1, ex-1-2, etc.)
   - Use distinct pod names per exercise
   - Setup commands should create the namespace and any broken resources for debugging exercises
   - Debugging exercises should provide the broken YAML via a heredoc in the setup so the learner can apply it directly
   - For exercises that depend on observing failure-over-time (e.g., watching restartCount increase), include a kubectl wait or sleep with clear intent, or instruct the learner to re-run verification after N seconds

4. **Anti-Spoiler Requirements (CRITICAL for debugging exercises)**
   - Exercise headings must NOT contain descriptive titles that hint at the problem
     - BAD: "Exercise 3.1: Liveness probe hits the wrong port"
     - BAD: "Exercise 3.2: Missing startup probe"
     - BAD: "Exercise 5.1: Probe tuning issues"
     - GOOD: "Exercise 3.1"
   - Objective lines must NOT reveal the number or type of issues
     - BAD: "Fix the probe timing so the pod stops crash-looping"
     - BAD: "There is an issue with the preStop hook"
     - GOOD: "Fix the broken pod so it reaches Ready and stays Ready for at least 60 seconds"
     - GOOD: "The setup above has one or more problems. Find and fix whatever is needed so that..."
   - Task descriptions should state the desired end state (e.g., "pod is Running and Ready with restartCount 0 after 2 minutes"), not the number or location of bugs
   - Section-level headings like "Level 3: Debugging Broken Configurations" are acceptable as navigation; per-exercise hints are not
   - Level 4 build exercises CAN describe what to build in their objectives (that's the task, not a spoiler)

5. **Resource Constraints**
   - Only use Kubernetes resources I've already learned and that are in scope for this assignment
   - In-scope resources: Pods, Namespaces
   - Do NOT use ConfigMaps, Secrets, Services, Deployments, ReplicaSets, DaemonSets, PersistentVolumes, or any scheduling primitives (nodeSelector, affinity, taints, tolerations)
   - Do NOT use resource requests or limits
   - Do NOT use init containers unless absolutely necessary for a specific demonstration (prefer single-container pods); Assignment 1 covered init container basics and Assignment 6 will cover advanced patterns
   - Container images should be small and fast: `busybox`, `alpine`, `nginx:1.25`, `nginx:1.25-alpine` are preferred. Use specific tags, never `latest`.
   - For exec probes, use plain shell commands available in busybox or alpine: `test -f /tmp/ready`, `cat /tmp/healthy`, `wget -q -O- http://localhost:8080/health`, `nc -z localhost 8080`
   - For httpGet probes, use endpoints the container naturally serves (nginx serves / on port 80; if you need a custom endpoint, run `python3 -m http.server` or a small busybox httpd, and be explicit about what the endpoint returns)
   - For tcpSocket probes, point at a port the container is actually listening on

6. **File Format**
   - Output FOUR separate Markdown files:
     - `README.md` - Overview of all files and how to use them
     - `pod-health-observability-tutorial.md` - Complete tutorial
     - `pod-health-observability-homework.md` - 15 progressive exercises only
     - `pod-health-observability-homework-answers.md` - Complete solutions
   - Use proper Markdown syntax with fenced code blocks and language tags (bash, yaml)
   - Each file should be self-contained
   - README.md should include:
     - Brief description of what each file contains
     - Recommended workflow (tutorial → homework → answers)
     - Difficulty level progression explanation
     - Prerequisites needed (kind cluster with nerdctl, CKA sections completed, Assignments 1 and 2 completed)
     - Estimated time commitment
     - A note that this is Assignment 3 in a pod series, with a brief list of the other planned assignments so the learner knows what's coming
     - A note that many exercises require observing behavior over time (probes fire on intervals), so expect to wait 30-120 seconds during verification steps
   - homework.md should include:
     - Brief introduction referencing the tutorial file
     - Exercise setup commands section at the start (cluster verification, optional global cleanup)
     - All 15 exercises organized by difficulty level
     - Cleanup section at the end (per-namespace and full)
     - "Key Takeaways" section summarizing important concepts, including probe purpose differences, probe tuning math, the termination sequence, and the diagnostic command toolbox
   - tutorial.md should teach ONE complete real-world workflow end-to-end (recommend: build a web application pod that represents a realistic production configuration, with a startup probe protecting slow initialization, a readiness probe gating traffic, a liveness probe catching hangs, a preStop hook for graceful shutdown, and a tuned terminationGracePeriodSeconds; then deliberately break it three different ways and walk through the diagnosis for each)
     - Include a "Reference Commands" section at the end with imperative and declarative examples
     - Include a "Probe Tuning Decision Table" showing how to choose exec vs httpGet vs tcpSocket and how to calculate initialDelaySeconds, periodSeconds, timeoutSeconds, and failureThreshold from stated container behavior
     - Include a "Pod Termination Sequence" diagram (text or mermaid) showing preStop, SIGTERM, grace period, SIGKILL
     - Include a "Diagnostic Workflow Cheat Sheet" showing the kubectl commands to run when a pod is in each common unhealthy state (Pending, ImagePullBackOff, CrashLoopBackOff, Running but NotReady, OOMKilled)
     - This serves as a quick reference while doing exercises
   - answers.md should include solutions for all 15 exercises
     - Answer key headings should use "Exercise X.Y Solution" format (no descriptive titles needed, since answers don't spoil)

7. **Answer Key Requirements**
   - File: pod-health-observability-homework-answers.md
   - Include complete solutions for all exercises
   - Declarative is the primary approach for this assignment; imperative is shown only for initial pod creation and not for probe/hook configuration
   - For debugging exercises, explain what was wrong, why it caused the observed failure, and how you'd diagnose it from kubectl output (describe, logs, logs --previous, get pod -o yaml to inspect conditions and container statuses)
   - Include a "Common Mistakes" section covering:
     - Using a liveness probe when a readiness probe is needed (or vice versa); liveness restarts, readiness gates traffic
     - initialDelaySeconds too short, causing restart loops during normal startup
     - timeoutSeconds >= periodSeconds causing probe pile-up
     - failureThreshold of 1 making any transient issue fatal
     - Forgetting that startup probe must succeed before liveness/readiness begin
     - preStop hook that exits with non-zero status (it's still honored, but the exit is logged)
     - terminationGracePeriodSeconds shorter than the preStop hook takes
     - Probe handler referencing a port that isn't in the container (for tcpSocket) or a path the container doesn't serve (for httpGet)
     - Using exec probe with a command that's not in the container image
     - Confusing restartPolicy with probe-induced restarts (probes cause container restarts within the pod; restartPolicy governs whether the pod itself restarts containers on exit)
   - Include a "Verification Commands Cheat Sheet" with the most useful kubectl commands for inspecting probe behavior, conditions, events, and termination

8. **Quality Standards**
   - No conflicts between tutorial and exercises (different namespaces, resource names)
   - All commands must be copy-paste ready with no manual substitution required
   - Verification commands should be specific (check probe configuration values via jsonpath, check pod conditions, check restartCount, check Events for specific reasons) not vague ("check if it works")
   - Exercises should build practical muscle memory for the CKA performance exam, where reading probe state from kubectl output and tuning probe fields under time pressure is a core skill
   - Tutorial should teach ONE complete real-world workflow end-to-end
   - No em dashes anywhere in output (use commas, periods, or parentheses)
   - Use narrative paragraph flow in prose explanations, not stacked single-sentence declarations
   - Full replacement files, no patches or diffs
   - Where exercises depend on timing (probes firing, restartCount increasing, grace periods elapsing), state the wait time explicitly and do not expect instant verification

Please create the homework assignment for Pod Health and Observability.
Generate all four files: README.md, pod-health-observability-tutorial.md, pod-health-observability-homework.md, and pod-health-observability-homework-answers.md
