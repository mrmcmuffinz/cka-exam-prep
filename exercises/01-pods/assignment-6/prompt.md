I need you to create a comprehensive Kubernetes homework assignment to help me practice **Multi-Container Patterns**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S6 (Core Concepts, Scheduling, Logging & Monitoring, Application Lifecycle Management, Cluster Maintenance, Security through KubeConfig)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment is the sixth in a planned series of pod-focused assignments. It covers the established design patterns for running multiple containers in a single pod, when each pattern applies, and the pod-level features that make them work (shared volumes, shared process namespace, native sidecars). Pod construction fundamentals (Assignment 1), configuration injection (Assignment 2), health/observability (Assignment 3), scheduling (Assignment 4), and resources/QoS (Assignment 5) are assumed knowledge. This is the last pod-focused assignment before controllers.

**Prior knowledge from Assignment 1 (do not re-teach):**
Assignment 1 covered the mechanics of multi-container pods (how to write two containers in a spec, unique container names, kubectl exec -c selection, kubectl logs -c selection, emptyDir for inter-container file sharing) and basic init containers (sequential execution, blocking main containers, init failure semantics). This assignment builds on that foundation to teach the patterns, not the mechanics.

**In scope for this assignment:**
- The three classical multi-container patterns (from Brendan Burns' "Designing Distributed Systems"):
  - Sidecar: a helper container that augments the main application (log shippers, metric exporters, config reloaders, cert renewers, proxy caches)
  - Ambassador: a proxy container that brokers connections from the main container to external services (service mesh sidecars, database connection pool proxies, authentication proxies)
  - Adapter: a container that transforms the main container's output into a different format (metrics format converters, log format normalizers)
- How to choose between patterns, and how to recognize an anti-pattern where separate pods would be better
- Init containers revisited as a pattern: sequential prerequisites (wait for a dependency, pre-seed a volume, run a migration, fetch configuration from an external source)
- Multiple init containers with ordering dependencies (they run sequentially in the order declared; one failure blocks all subsequent ones)
- Native sidecars (init containers with restartPolicy: Always): the modern pattern introduced in Kubernetes 1.28 (alpha) / 1.29 (beta) / 1.33 (stable) where a "sidecar" is declared as an init container with restartPolicy: Always, causing it to start before regular containers (like a normal init container) but continue running alongside them (unlike a normal init container). This solves the long-standing problem of sidecar shutdown ordering and sidecar-dependent main containers.
- The difference between classical sidecars (regular container alongside main) and native sidecars (init container with restartPolicy: Always): lifecycle ordering (native sidecars start before main, shut down after main), impact on pod Ready state, impact on job completion (native sidecars allow jobs to complete when the main container exits, classical sidecars prevent job completion because the sidecar keeps running)
- Shared volumes between containers in a pod (emptyDir is the primary vehicle): mount points, read-only vs read-write mounts, how writes from one container become visible to others
- emptyDir.medium: Memory vs default (disk): memory-backed emptyDir is tmpfs, counts against memory limit, faster but volatile
- Shared process namespace (spec.shareProcessNamespace: true): enables containers in a pod to see each other's processes (useful for debugging sidecars, sending signals between containers), trade-offs (reduced isolation, PID 1 becomes a shared concept)
- Inter-container coordination via file-based signals in a shared volume (a common pattern, especially for init containers producing output that main containers consume)
- Container-level security contexts affecting what sidecars can do (mentioned briefly; deep security is a later topic)
- Debugging multi-container pods: kubectl logs -c, kubectl exec -c, kubectl describe pod (showing per-container status and events), kubectl get pod -o yaml for per-container state
- The decision framework: "should this be a sidecar or a separate pod?" (shared lifecycle, shared network/storage, strong coupling argue for sidecar; independent scaling, different lifecycle, weak coupling argue for separate pods)

**Out of scope (covered in other assignments, do not include):**
- Pod spec fundamentals, commands/args, restart policy for the pod, image pull policy, basic init container mechanics (Assignment 1: Pod Fundamentals)
- ConfigMaps and Secrets as configuration sources (Assignment 2: Pod Configuration Injection). If a sidecar or init container needs configuration, use an inline command argument or env var literal; do not introduce ConfigMaps/Secrets here.
- Probes, lifecycle hooks, terminationGracePeriodSeconds (Assignment 3: Pod Health and Observability). If an exercise benefits from a probe to verify sidecar readiness, reference Assignment 3 briefly but do not build the exercise around probe tuning.
- Scheduling mechanisms (Assignment 4: Pod Scheduling)
- Resource requests and limits, QoS classes (Assignment 5: Pod Resources and QoS). If an exercise has multiple containers, note that their requests sum for scheduling purposes but do not make the exercise about QoS configuration.
- ReplicaSets, Deployments, DaemonSets, Services, Jobs, CronJobs (Assignment 7 and beyond). The native sidecar pattern is especially useful with Jobs, but since Jobs aren't covered yet, mention the Job + native sidecar benefit conceptually in the tutorial without building Job-based exercises.
- PersistentVolumes, hostPath, configMap/secret-as-volume (volume types beyond emptyDir are out of scope; emptyDir is the only shared-storage primitive in this assignment)
- Service mesh implementations (Istio, Linkerd). The ambassador pattern is taught in its classical form, not as service-mesh-specific practice.
- Security contexts beyond runAsUser/runAsGroup/fsGroup if they become necessary for shared-volume file permissions. Mention briefly; do not go deep.

Exercises should use lightweight, predictable containers. Favor busybox and alpine for helper containers. Use nginx:1.25 when a realistic long-lived HTTP server is needed. For log-shipper style sidecars, a simple shell loop reading a file and echoing to stdout is more instructive (and debuggable) than a real log-shipping agent. Keep the infrastructure simple so the pattern is the lesson, not the tooling.

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: multi-container-patterns-tutorial.md
   - Begin with a decision framework section: "Should this be a multi-container pod or separate pods?" with concrete criteria and examples
   - Complete step-by-step tutorial building up through the patterns in this order: init containers for prerequisites, classical sidecars, ambassadors, adapters, native sidecars, shared process namespace
   - Include declarative YAML throughout; be explicit that multi-container pods are declarative-only in practice (no reasonable imperative path)
   - Explain every new field when introducing it: shareProcessNamespace, init container restartPolicy: Always, emptyDir.medium, volumeMounts.readOnly
   - For the init container pattern, demonstrate a realistic example: an init container that waits for a file to exist in a shared volume (where the learner manually creates it), then the main container starts once the file appears. Show that init failures block main containers, and show multiple init containers running sequentially.
   - For the classical sidecar pattern, build a working example: a main nginx container that writes access logs to a shared emptyDir volume, and a sidecar busybox container that tails those logs and echoes them to its own stdout (so `kubectl logs -c sidecar` shows the access log stream, decoupled from nginx stdout). This is the canonical log-shipper-sidecar example. Then show how you would extend it to ship logs somewhere real (conceptually, without actually building the shipper).
   - For the ambassador pattern, build a working example: a main container that talks to "localhost:6379" for a cache, and an ambassador container running a small proxy (a simple nc-based relay or a busybox script) that the main container sees as its local cache. This teaches the "pretend the outside world is local" principle without requiring a real external service.
   - For the adapter pattern, build a working example: a main container producing output in one format (e.g., plain text status in a file), and an adapter container that reads that file and exposes it in a different format (e.g., JSON on stdout). Keep the transformation trivial; the point is the pattern.
   - For native sidecars, build the classical sidecar example from earlier and convert it to a native sidecar (move the sidecar to initContainers with restartPolicy: Always). Show the difference in behavior: native sidecar starts before main, and if the main container exits, the native sidecar is terminated (whereas a classical sidecar would keep running and prevent pod completion). Note explicitly when this matters (with Jobs, which are out of scope for this assignment; mention conceptually).
   - Demonstrate shared process namespace: create a pod with two containers and shareProcessNamespace: true, show `kubectl exec -c containerA -- ps -ef` listing processes from both containers. Demonstrate the security tradeoff: with shared PID namespace, any container can signal any other container's processes.
   - Show the debugging workflow for multi-container pods: how to identify which container is failing, how to tail logs from each container, how to exec into a specific container, how to read per-container state from kubectl get pod -o yaml
   - Tutorial should use its own namespace (tutorial-multi-container) and resource names that don't conflict with exercises.
   - Tutorial should be a complete, functional workflow from start to finish

2. **Progressive Exercises (15 total)**

   **Level 1 (3 exercises): Basic single-concept tasks**
   - One pattern applied once, minimum viable example
   - Straightforward verification (2-3 checks)
   - Examples: "Create a pod with one init container that writes 'ready' to /shared/status in an emptyDir, and a main container that cats /shared/status and exits", "Create a pod with a main nginx container and a sidecar busybox container that writes a timestamp every 5 seconds to a shared file; verify logs from both containers are separately accessible", "Create a pod with two containers where shareProcessNamespace is true and verify from one container that you can see the other container's process"

   **Level 2 (3 exercises): Multi-concept tasks**
   - Combine two patterns in one pod, or use multiple init containers with ordering, or combine shared storage with specific mount options
   - More verification checks (4-6 checks)
   - Examples: "Create a pod with three sequential init containers (each writes a different file to a shared volume) and a main container that reads all three files and exits 0 only if all three are present", "Create a pod with a classical sidecar pattern where the sidecar has a read-only mount of the shared volume and the main container has a read-write mount; verify the sidecar cannot write", "Create a pod with an adapter sidecar that transforms the main container's output, and verify the transformed output is visible via kubectl logs on the adapter container"

   **Level 3 (3 exercises): Debugging broken configurations**
   - Given broken multi-container pod YAML that fails in specific ways
   - Single clear issue per exercise. Mix failure types across the three exercises:
     - At least one "init container failure blocks main container" failure (init exits nonzero, or init never terminates, or init ordering is wrong so a later init needs output from an earlier init that didn't produce it)
     - At least one "shared volume mount mismatch" failure (two containers mount the same volume at different paths and can't find each other's files, or one container's mountPath overlaps with a pre-existing directory in the image and shadows it, or readOnly mount prevents writes the container expects to make)
     - At least one "container coordination failure" failure (sidecar container crashes and takes down the pod pattern's value, ambassador container listening on wrong port so main container's "localhost" connection fails, adapter container reading from wrong file path)
   - Must identify the problem from per-container logs, events, or container states
   - The broken YAML must be provided in the setup commands

   **Level 4 (3 exercises): Complex real-world scenarios**
   - Realistic production-style multi-container compositions:
     - A log-shipper sidecar pattern: main nginx container writes access logs to an emptyDir, sidecar tails the logs and prints them to stdout in a transformed format (simulated log shipping); verify the log content appears correctly in the sidecar's output
     - An ambassador pattern with a concrete protocol proxy: main container connects to "localhost:8080" expecting a simple HTTP-ish service, ambassador listens on 8080 and "proxies" to a simulated backend (a file-backed response via busybox)
     - A native sidecar conversion: start from a classical sidecar pod and convert it to a native sidecar; verify the lifecycle difference (native sidecar starts first, appears in initContainers in kubectl output, has restartPolicy Always)
   - 8+ verification checks covering multiple aspects (each container's state, shared volume contents, inter-container communication, lifecycle ordering)
   - These are build tasks, not debugging tasks; the objective can describe what to build

   **Level 5 (3 exercises): Advanced debugging and comprehensive tasks**
   - Multiple issues in one multi-container pod (2-3 problems across init containers, sidecars, shared volumes, and container startup ordering)
   - Subtle issues: init container that succeeds but writes to the wrong path in the shared volume (so the main container never sees the expected file), native sidecar without restartPolicy: Always (behaves as a normal init container that blocks main startup forever), classical sidecar that crashes repeatedly but pod restartPolicy is Always so the pod never enters a clean Ready state, shareProcessNamespace missing when the use case assumed it, two containers with the same name (rejected at admission), adapter reading from stdin when the main container writes to a file
   - OR a comprehensive build task: "Build a pod that represents a realistic observability stack for a web application: main nginx container, a log-forwarder sidecar (tails access logs, prints to stdout), a metrics-adapter sidecar (reads nginx status page content from a shared file and formats it as JSON on stdout), and an init container that seeds an index.html with a timestamp marker. Use native sidecars for the forwarders so the pod can eventually complete cleanly if the main exits."
   - Requires deep understanding of container lifecycle, volume sharing, and pattern selection
   - 10+ verification checks

3. **Exercise Structure**
   - Each exercise must include:
     - Numbered heading ONLY (e.g., "### Exercise 3.1") with NO descriptive title or subtitle
     - Clear objective statement that describes the goal without telegraphing the solution
     - Complete setup commands (copy-paste ready, no placeholders)
     - Specific task description
     - Verification commands with expected results (specific expected output: container states, log content from each container, file contents in the shared volume, process visibility across containers)
   - Use unique namespaces per exercise (ex-1-1, ex-1-2, etc.)
   - Use distinct pod names and distinct container names per exercise
   - Setup commands should create the namespace and any broken resources for debugging exercises
   - Debugging exercises should provide the broken YAML via a heredoc
   - For exercises that depend on observing timing (init container sequence, sidecar startup ordering), state the wait time explicitly

4. **Anti-Spoiler Requirements (CRITICAL for debugging exercises)**
   - Exercise headings must NOT contain descriptive titles that hint at the problem
     - BAD: "Exercise 3.1: The init container that writes to the wrong path"
     - BAD: "Exercise 3.2: The ambassador listening on the wrong port"
     - BAD: "Exercise 5.1: Three init container issues"
     - GOOD: "Exercise 3.1"
   - Objective lines must NOT reveal the number or type of issues
     - BAD: "Fix the init container path so the main container can start"
     - BAD: "There is an issue with the shared volume mount"
     - GOOD: "Fix the broken pod so all containers reach Running state and the main container's logs show the expected output"
     - GOOD: "The setup above has one or more problems. Find and fix whatever is needed so that..."
   - Task descriptions should state the desired end state, not the number or location of bugs
   - Section-level headings like "Level 3: Debugging Broken Configurations" are acceptable as navigation; per-exercise hints are not
   - Level 4 build exercises CAN describe what to build in their objectives (that's the task, not a spoiler)

5. **Resource Constraints**
   - Only use Kubernetes resources I've already learned and that are in scope for this assignment
   - In-scope resources: Pods, Namespaces, emptyDir volumes (including emptyDir with medium: Memory)
   - Do NOT use ConfigMaps, Secrets, Services, Deployments, ReplicaSets, DaemonSets, PersistentVolumes, Jobs, CronJobs
   - Do NOT use probes or lifecycle hooks (mention readiness-probe-on-sidecars as a technique in the tutorial, do not build exercises around it)
   - Do NOT use scheduling primitives or resource limits (small resource requests permitted only where necessary)
   - Container images should be small and fast: `busybox`, `alpine`, `nginx:1.25`, `nginx:1.25-alpine`. Use specific tags, never `latest`.
   - Use plain shell commands for any helper behavior (busybox `sh -c '...'` is expressive enough for all sidecar/adapter/ambassador examples in this assignment). Avoid introducing language-specific runtimes unless there's a compelling reason.
   - For ambassador examples, `nc` (netcat, present in busybox) is sufficient for simulating a proxy. Simple and debuggable.

6. **File Format**
   - Output FOUR separate Markdown files:
     - `README.md` - Overview of all files and how to use them
     - `multi-container-patterns-tutorial.md` - Complete tutorial
     - `multi-container-patterns-homework.md` - 15 progressive exercises only
     - `multi-container-patterns-homework-answers.md` - Complete solutions
   - Use proper Markdown syntax with fenced code blocks and language tags (bash, yaml)
   - Each file should be self-contained
   - README.md should include:
     - Brief description of what each file contains
     - Recommended workflow (tutorial → homework → answers)
     - Difficulty level progression explanation
     - Prerequisites needed (kind cluster with nerdctl, CKA sections completed, Assignments 1-5 completed; multi-container basics from Assignment 1 are specifically assumed)
     - Estimated time commitment
     - A note that this is Assignment 6 in a pod series, and that after this the series moves on to workload controllers
     - A note on native sidecars requiring Kubernetes 1.29+ (beta) or 1.33+ (stable); kind clusters on recent K8s releases support this, older kind versions may not. Tell the learner how to check their cluster's K8s version and which exercises require native sidecar support.
   - homework.md should include:
     - Brief introduction referencing the tutorial file
     - Exercise setup commands section at the start (cluster verification, K8s version check for native sidecar support, optional global cleanup)
     - All 15 exercises organized by difficulty level
     - Cleanup section at the end (per-namespace and full)
     - "Key Takeaways" section summarizing important concepts, including the pattern selection decision framework, the classical-vs-native sidecar distinction, the role of emptyDir as the shared-medium workhorse, and the debugging toolkit for multi-container pods
   - tutorial.md should teach a cohesive end-to-end progression through the patterns
     - Include a "Reference Commands" section with multi-container-specific kubectl flags (-c for container selection in logs and exec, jsonpath queries for per-container state)
     - Include a "Pattern Selection Decision Tree" showing when to pick each pattern and when to pick separate pods instead
     - Include a "Classical vs Native Sidecar Comparison Table" with lifecycle differences, field placement (containers vs initContainers with restartPolicy: Always), and when to pick each
     - Include a "Debugging Multi-Container Pods" cheat sheet with the command patterns for isolating which container is the problem
     - This serves as a quick reference while doing exercises
   - answers.md should include solutions for all 15 exercises
     - Answer key headings should use "Exercise X.Y Solution" format (no descriptive titles needed, since answers don't spoil)

7. **Answer Key Requirements**
   - File: multi-container-patterns-homework-answers.md
   - Include complete solutions for all exercises
   - Declarative is the only practical approach; do not attempt imperative equivalents for multi-container pods
   - For debugging exercises, explain what was wrong, why it caused the observed failure, and how to diagnose it from kubectl output (per-container logs, per-container exec, describe pod Events, get pod -o yaml for container statuses and init container statuses)
   - Include a "Common Mistakes" section covering:
     - Mounting the same emptyDir at different paths in different containers and then being confused why they don't see each other's files (they do, the paths are just different lenses onto the same volume)
     - Forgetting that emptyDir lifetime is pod-scoped (not container-scoped); a container restart doesn't clear the volume
     - Putting a "native sidecar" in the containers array instead of initContainers array (it's just a classical sidecar then)
     - Putting a classical sidecar in initContainers without restartPolicy: Always (it's a normal init container, blocks main indefinitely if it's long-running)
     - Expecting shareProcessNamespace to apply to only some containers (it's pod-wide; all or none)
     - Making an ambassador listen on a port the main container doesn't actually connect to, or vice versa
     - Ambassador that terminates connections incorrectly (proxies are subtle; if you're doing anything non-trivial, use a real proxy)
     - Adapter that reads from stdin when the main writes to a file, or vice versa
     - Assuming containers in a pod start in declaration order (they don't for regular containers; only init containers have ordering guarantees)
     - Container name collisions across containers and initContainers (rejected at admission; names must be unique across the entire pod)
     - Setting image pull policies that cause unnecessary pulls for sidecars on every restart
   - Include a "Pattern Selection Reference" section: for each pattern, list "use when...", "don't use when...", and "alternative is..."
   - Include a "Verification Commands Cheat Sheet" for multi-container diagnostics: per-container logs, per-container exec, per-container status, init container status, container state transitions

8. **Quality Standards**
   - No conflicts between tutorial and exercises (different namespaces, resource names)
   - All commands must be copy-paste ready with no manual substitution required
   - Verification commands should be specific (check logs of specific container, check file contents in shared volume via exec, check native sidecar presence in initContainers array via jsonpath) not vague ("check if it works")
   - Exercises should build practical muscle memory for the CKA performance exam, where constructing multi-container pods and diagnosing per-container issues under time pressure is a core skill
   - Tutorial should teach the full pattern family end-to-end, not a single workflow; the progression is through patterns, not through one long use case
   - No em dashes anywhere in output (use commas, periods, or parentheses)
   - Use narrative paragraph flow in prose explanations, not stacked single-sentence declarations
   - Full replacement files, no patches or diffs
   - Helper commands inside container specs should be simple shell: `sh -c '...'` with clear inline comments where complex. Avoid multi-line YAML anchors or heredocs inside container commands.

Please create the homework assignment for Multi-Container Patterns.
Generate all four files: README.md, multi-container-patterns-tutorial.md, multi-container-patterns-homework.md, and multi-container-patterns-homework-answers.md
