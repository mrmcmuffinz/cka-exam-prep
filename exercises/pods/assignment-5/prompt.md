I need you to create a comprehensive Kubernetes homework assignment to help me practice **Pod Resources and QoS**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S6 (Core Concepts, Scheduling, Logging & Monitoring, Application Lifecycle Management, Cluster Maintenance, Security through KubeConfig)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment is the fifth in a planned series of pod-focused assignments. It covers how pods declare their CPU and memory needs, how Kubernetes enforces those declarations at runtime, and how the three Quality of Service classes emerge from the interaction between requests and limits. Pod construction fundamentals (Assignment 1), configuration injection (Assignment 2), health/observability (Assignment 3), and scheduling (Assignment 4) are assumed knowledge. Other pod topics will get their own dedicated assignments later and MUST NOT appear here.

**Multi-node kind cluster assumption:**
This assignment uses the same multi-node kind cluster (1 control-plane, 3 workers) from Assignment 4. If the learner doesn't have it set up, the README should reference Assignment 4's setup instructions. A multi-node cluster is helpful but not strictly required for this assignment; most exercises work on a single node. Flag the few exercises (if any) that benefit from multiple nodes.

**Kind cluster resource reality (CRITICAL to mention in tutorial):**
kind worker nodes report generous allocatable resources (often 8+ CPUs and 16+ GB memory) because they inherit from the host. This means requests that would be unschedulable on a real cluster may schedule fine on kind. When designing exercises that demonstrate unschedulable pods due to insufficient capacity, use deliberately large requests (multi-CPU, multi-GB) or use requests relative to what the cluster actually has. The tutorial must include `kubectl describe node` output interpretation so learners can see their actual allocatable values.

**In scope for this assignment:**
- CPU units: millicores (1000m = 1 CPU), fractional values (0.5 = 500m), what a CPU means in practice (one kernel scheduling slot per scheduling period)
- Memory units: Ki, Mi, Gi (binary) vs K, M, G (decimal), why Mi/Gi are preferred, common sizes
- Resource requests (spec.containers[*].resources.requests): what they mean for scheduling (reserved capacity), what they do NOT guarantee at runtime
- Resource limits (spec.containers[*].resources.limits): what they mean at runtime (hard cap), how CPU limits vs memory limits are enforced differently (CPU is throttled, memory triggers OOMKill)
- The three QoS classes and how they're determined:
  - Guaranteed: every container has requests == limits for both CPU and memory, no field missing
  - Burstable: at least one container has a request, and it's not Guaranteed
  - BestEffort: no container has any requests or limits
- QoS class impact: eviction order under node pressure (BestEffort first, then Burstable, then Guaranteed last)
- OOMKilled behavior: what triggers it (container exceeds memory limit, or node memory pressure with container over its request), how to diagnose it (lastState.terminated.reason=OOMKilled, exitCode 137), restart behavior per restartPolicy
- CPU throttling: unlike OOM, CPU limits cause throttling not killing; how to observe throttling (cgroup cpu.stat metrics, mentioned but not required to inspect in kind)
- Scheduling implications of requests: the scheduler fits pods into nodes based on requests (not limits), so a pod with no requests can land on any node regardless of limits
- Unschedulable pods due to insufficient capacity: how the FailedScheduling event reports "Insufficient cpu" or "Insufficient memory", the diagnostic workflow
- Ephemeral storage requests and limits (spec.containers[*].resources.requests.ephemeral-storage and limits.ephemeral-storage): what counts as ephemeral storage (emptyDir, container logs, writable layers), when it matters, when pods get evicted for exceeding it
- LimitRange basics: per-container default requests and limits applied to pods in a namespace, min/max bounds, maxLimitRequestRatio. LimitRange is namespace-scoped and is the most practical way to enforce resource discipline.
- ResourceQuota basics: namespace-wide caps on total requests.cpu, requests.memory, limits.cpu, limits.memory, pod count; how quota interacts with pod admission (a pod is rejected if it would exceed quota, unless it has both requests AND limits set on all resources constrained by the quota)
- In-place pod resize (the feature where resources can be changed without recreation): mention as introduced in recent Kubernetes versions, note it's still evolving, include a brief example if the kind cluster's K8s version supports it (v1.27+ alpha, v1.33 beta). This is lower priority; do not build heavy exercises around it.

**Out of scope (covered in other assignments, do not include):**
- Pod spec fundamentals, commands/args, restart policy, image pull policy, labels/annotations (Assignment 1: Pod Fundamentals)
- Init containers beyond a brief mention of how their resource requirements factor into pod effective requests (Assignment 1 for basics, Assignment 6 for advanced patterns)
- ConfigMaps and Secrets (Assignment 2: Pod Configuration Injection)
- Probes, lifecycle hooks, termination (Assignment 3: Pod Health and Observability)
- Scheduling mechanisms: nodeSelector, affinity, taints, tolerations, topology spread, priority classes (Assignment 4: Pod Scheduling). Note: resource requests ARE a scheduling input, and the interaction between requests and scheduling is briefly revisited here from a resource perspective, but the scheduling mechanisms themselves are not re-taught.
- Advanced multi-container patterns (Assignment 6)
- ReplicaSets, Deployments, DaemonSets, Services (Assignment 7 and beyond)
- HorizontalPodAutoscaler and VerticalPodAutoscaler (covered elsewhere in the CKA curriculum; these depend on metrics-server and operate on workload controllers, not bare pods)
- metrics-server installation and usage (`kubectl top pod`). Mention it exists and would be the production-grade way to see actual usage, but do not depend on it in exercises since kind doesn't include it by default.
- cgroup internals, kernel scheduler details, container runtime specifics (containerd cpu.cfs_quota_us tuning). Reference them conceptually only.

For exercises that demonstrate OOMKill and CPU throttling, use containers that deliberately allocate memory or burn CPU. Use simple, reproducible tools: `polinux/stress` or `progrium/stress` images are common choices, or plain `busybox` running `dd if=/dev/zero of=/dev/null` for CPU burn and simple shell loops allocating to /dev/shm for memory. Prefer tools that come from trusted images and can be controlled precisely. If using `polinux/stress`, pin to a specific tag.

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: pod-resources-qos-tutorial.md
   - Begin with a "Understanding Your Cluster's Capacity" section that shows how to read `kubectl describe node kind-worker` to find Allocatable CPU and memory, and `kubectl get nodes -o custom-columns=NAME:.metadata.name,CPU:.status.allocatable.cpu,MEM:.status.allocatable.memory` for a quick overview. Emphasize that kind clusters inherit host resources, so capacity numbers may be larger than expected.
   - Complete step-by-step tutorial showing how requests and limits work in practice, starting with the simplest case (no requests or limits) and building up
   - Include BOTH imperative (kubectl run with --requests and --limits flags where available, and kubectl set resources for existing pods) AND declarative (YAML) approaches
   - Be honest that for anything beyond single-container pods, declarative is the practical path
   - Explain every resource field when introducing it: what the units mean, what values are valid, how the scheduler and kubelet use the field
   - Walk through the three QoS classes with worked examples: create a pod in each class, then check the QoS class with `kubectl get pod <name> -o jsonpath='{.status.qosClass}'`, and explain why that class was assigned
   - Demonstrate OOMKilled live: run a pod with a 64Mi memory limit that deliberately allocates 100Mi, show the pod gets OOMKilled, show restartCount increase if restartPolicy allows, show lastState.terminated.reason=OOMKilled and exitCode 137
   - Demonstrate CPU throttling conceptually: run a pod with a CPU limit lower than the work it tries to do, note that it won't be killed but will run slower than requested. Mention that directly observing throttling requires metrics-server or cgroup inspection, which is out of scope; the point is to know the behavior differs from memory.
   - Demonstrate scheduling failure from insufficient capacity: create a pod with a deliberately huge memory request (larger than any node's allocatable), show the Pending state and the FailedScheduling event with "Insufficient memory"
   - Demonstrate LimitRange: create a LimitRange in a namespace with default request/limit values and max bounds, create a pod without any resource fields in that namespace, show the pod gets the defaults applied (inspect with `kubectl get pod -o yaml`), then try to create a pod that violates the max and observe the rejection
   - Demonstrate ResourceQuota: create a ResourceQuota limiting total requests.cpu and pod count in a namespace, create pods up to the quota, then create one more and observe the rejection
   - Demonstrate the quota admission rule that pods need explicit requests/limits when quota constrains those resources, via a pod without requests being rejected when quota is set
   - If the cluster supports it, briefly demonstrate in-place pod resize with a note about version requirements; if not, explain the concept and skip the demo
   - Tutorial should use its own namespace (tutorial-pod-resources) and resource names that don't conflict with exercises. Clean up LimitRange and ResourceQuota at the end.
   - Tutorial should be a complete, functional workflow from start to finish

2. **Progressive Exercises (15 total)**

   **Level 1 (3 exercises): Basic single-concept tasks**
   - One pod, one resource configuration, one verification focus
   - Straightforward verification (2-3 checks)
   - Examples: "Create a pod with a memory request of 128Mi and a memory limit of 256Mi, verify the QoS class is Burstable", "Create a pod with CPU request 250m and CPU limit 500m, no memory settings, verify the QoS class is Burstable", "Create a pod with no resource fields at all, verify the QoS class is BestEffort"

   **Level 2 (3 exercises): Multi-concept tasks**
   - Combine requests AND limits on a pod, or use multiple resource types (CPU + memory + ephemeral-storage), or create a pod that achieves Guaranteed class specifically
   - Include at least one exercise that requires reading the QoS class and explaining (in the verification) which containers contributed to it
   - More verification checks (4-6 checks)
   - Examples: "Create a two-container pod where container A has requests==limits for CPU and memory, container B has no resource fields; verify the pod's QoS class", "Create a pod with requests.cpu 100m, requests.memory 128Mi, limits.cpu 100m, limits.memory 128Mi, and verify it is Guaranteed", "Create a pod with requests.memory 256Mi, limits.memory 512Mi, and ephemeral-storage request 100Mi and limit 200Mi"

   **Level 3 (3 exercises): Debugging broken configurations**
   - Given broken pod/LimitRange/ResourceQuota YAML that fails in specific ways
   - Single clear issue per exercise. Mix failure types across the three exercises:
     - At least one "pod is Pending due to insufficient resources" failure (request too large, or namespace quota exhausted)
     - At least one "pod is being OOMKilled repeatedly" failure (memory limit set too low for what the container actually needs)
     - At least one "pod is being rejected at admission" failure (pod violates LimitRange max, or pod doesn't specify requests/limits when quota requires them, or invalid resource unit syntax like `2G` intended as 2 GiB when `2Gi` was meant and the numeric difference matters)
   - Must identify the problem from Events, pod status, or LimitRange/ResourceQuota state and fix it
   - The broken YAML and any broken namespace setup must be provided in the setup commands so the learner doesn't have to type it

   **Level 4 (3 exercises): Complex real-world scenarios**
   - Realistic production-style resource configuration:
     - A multi-namespace setup where one namespace has a strict ResourceQuota and a LimitRange providing defaults, and pods are created in that namespace with and without explicit resource fields, and the learner verifies both the admission behavior and the applied defaults
     - A workload-realistic pod sized for a specific SLO: "this container's working set is 400Mi and it tolerates bursts to 600Mi; it needs 250m CPU steady and can burst to 500m", with the learner translating those requirements into correct requests and limits and picking the right QoS class
     - A multi-container pod where one container is a main service and another is a helper, each with different resource profiles; the learner sets them correctly and verifies the pod's effective resource footprint (sum of requests, sum of limits) and QoS class
   - 8+ verification checks covering multiple aspects (requests, limits, QoS class, pod status, LimitRange defaults, ResourceQuota usage)
   - These are build tasks, not debugging tasks; the objective can describe what to build

   **Level 5 (3 exercises): Advanced debugging and comprehensive tasks**
   - Multiple issues in one setup (2-3 problems across pod spec, LimitRange, and ResourceQuota)
   - Subtle issues: LimitRange max that's lower than the default it's trying to apply (so defaults are rejected), ResourceQuota that requires both requests AND limits but pod only has requests, memory limit in K/M/G units where Ki/Mi/Gi was intended (off by ~2.4% which may or may not matter), ephemeral-storage limit that's too tight and causes eviction, container that requests more CPU than the node's allocatable
   - OR a comprehensive build task: "Configure a namespace for a multi-tenant scenario where each team gets a quota, each container must declare reasonable defaults, no container can request more than 2 CPUs or 4Gi memory, and a 3-tier application pod is placed in that namespace with appropriate per-container sizing"
   - Requires deep understanding of how requests, limits, QoS, LimitRange, and ResourceQuota interact at admission and runtime
   - 10+ verification checks

3. **Exercise Structure**
   - Each exercise must include:
     - Numbered heading ONLY (e.g., "### Exercise 3.1") with NO descriptive title or subtitle
     - Clear objective statement that describes the goal without telegraphing the solution
     - Complete setup commands (copy-paste ready, no placeholders). Setup must create any LimitRange or ResourceQuota the exercise depends on.
     - Specific task description
     - Verification commands with expected results (specific expected output: QoS class via jsonpath, pod status, resource values via jsonpath, FailedScheduling events, OOMKilled reason)
     - A cleanup note listing resources to remove so LimitRanges and ResourceQuotas don't leak into later exercises
   - Use unique namespaces per exercise (ex-1-1, ex-1-2, etc.) to prevent LimitRange and ResourceQuota interference
   - Use distinct pod names per exercise
   - Setup commands should create the namespace, apply any LimitRange/ResourceQuota, and for debugging exercises apply the broken YAML via a heredoc
   - For exercises involving OOMKill or throttling, include a wait step before verification (kubectl wait with appropriate condition, or sleep with explicit intent) because these behaviors take 10-30 seconds to manifest

4. **Anti-Spoiler Requirements (CRITICAL for debugging exercises)**
   - Exercise headings must NOT contain descriptive titles that hint at the problem
     - BAD: "Exercise 3.1: The pod that gets OOMKilled"
     - BAD: "Exercise 3.2: LimitRange max conflict"
     - BAD: "Exercise 5.1: Three quota violations"
     - GOOD: "Exercise 3.1"
   - Objective lines must NOT reveal the number or type of issues
     - BAD: "Increase the memory limit so the pod stops getting OOMKilled"
     - BAD: "Fix the LimitRange so defaults apply correctly"
     - GOOD: "Fix the broken configuration so the pod reaches Running state and remains Running with restartCount 0 for at least 60 seconds"
     - GOOD: "The setup above has one or more problems. Find and fix whatever is needed so that..."
   - Task descriptions should state the desired end state, not the number or location of bugs
   - Section-level headings like "Level 3: Debugging Broken Configurations" are acceptable as navigation; per-exercise hints are not
   - Level 4 build exercises CAN describe what to build in their objectives (that's the task, not a spoiler)

5. **Resource Constraints**
   - Only use Kubernetes resources I've already learned and that are in scope for this assignment
   - In-scope resources: Pods, Namespaces, LimitRanges, ResourceQuotas
   - Do NOT use ConfigMaps, Secrets, Services, Deployments, ReplicaSets, DaemonSets, PersistentVolumes
   - Do NOT use probes, lifecycle hooks
   - Do NOT use scheduling primitives (nodeSelector, affinity, taints, tolerations) unless the exercise specifically requires demonstrating that a pod is unschedulable for resource reasons and a scheduling mechanism is needed to pin to a specific node; in that case use nodeName, not affinity
   - Do NOT use init containers unless specifically demonstrating init container resource accounting (effective pod requests consider the max of any init container's requests and the sum of regular container requests); mention this concept in tutorial, keep exercises focused on regular containers
   - Container images for standard workloads: `busybox`, `alpine`, `nginx:1.25`. Use specific tags, never `latest`.
   - Container images for stress/load workloads: `polinux/stress:latest` is commonly used but pin a specific tag when you can verify one; alternatively use busybox with shell commands like `dd if=/dev/zero of=/dev/null` for CPU burn or a shell loop for memory. Choose whichever is more reliable and explain the command inline.
   - All stress commands should be time-bounded (via sleep after or via --timeout flags on stress) so exercises complete without requiring a kill

6. **File Format**
   - Output FOUR separate Markdown files:
     - `README.md` - Overview of all files and how to use them
     - `pod-resources-qos-tutorial.md` - Complete tutorial
     - `pod-resources-qos-homework.md` - 15 progressive exercises only
     - `pod-resources-qos-homework-answers.md` - Complete solutions
   - Use proper Markdown syntax with fenced code blocks and language tags (bash, yaml)
   - Each file should be self-contained
   - README.md should include:
     - Brief description of what each file contains
     - Recommended workflow (tutorial → homework → answers)
     - Difficulty level progression explanation
     - Prerequisites needed (kind cluster with nerdctl, CKA sections completed, Assignments 1-4 completed; multi-node cluster from Assignment 4 is helpful but single-node works for most exercises)
     - A "Know Your Cluster" note with the `kubectl describe node` and `kubectl get nodes -o custom-columns` commands for checking allocatable resources before starting
     - Estimated time commitment
     - A note that this is Assignment 5 in a pod series, with a brief list of the other planned assignments
     - A note that some exercises involve deliberate OOMKills and resource exhaustion; this is expected and not harmful to the cluster
   - homework.md should include:
     - Brief introduction referencing the tutorial file
     - Exercise setup commands section at the start (cluster verification, capacity check, optional global cleanup)
     - All 15 exercises organized by difficulty level
     - Cleanup section at the end (per-namespace, removal of LimitRanges and ResourceQuotas)
     - "Key Takeaways" section summarizing important concepts, including the request/limit distinction, the three QoS classes and how they're determined, the OOMKilled-vs-throttled behavior split, and the LimitRange/ResourceQuota admission flow
   - tutorial.md should teach ONE cohesive workflow end-to-end (recommend: start with a pod with no resources, progress through adding requests, then limits, then land on a Guaranteed pod, then show OOMKill and throttling, then introduce LimitRange and ResourceQuota as the namespace-level controls)
     - Include a "Reference Commands" section at the end with imperative and declarative examples
     - Include a "Resource Units Cheat Sheet" showing CPU unit conversions (1 = 1000m = 1 CPU) and memory unit conversions (Mi vs M, Gi vs G, with the specific byte counts)
     - Include a "QoS Class Decision Table" showing the rules for each class and when to choose each
     - Include a "Diagnostic Workflow for Resource Issues" showing the commands to run when a pod is Pending, OOMKilled, or rejected at admission
     - This serves as a quick reference while doing exercises
   - answers.md should include solutions for all 15 exercises
     - Answer key headings should use "Exercise X.Y Solution" format (no descriptive titles needed, since answers don't spoil)

7. **Answer Key Requirements**
   - File: pod-resources-qos-homework-answers.md
   - Include complete solutions for all exercises
   - Declarative is the primary approach for this assignment
   - For debugging exercises, explain what was wrong, why it caused the observed failure, and how to diagnose it from kubectl output (describe pod for Events, get pod -o yaml for QoS class and lastState, describe limitrange/resourcequota for admission state)
   - Include a "Common Mistakes" section covering:
     - Using decimal units (M, G, K) when binary (Mi, Gi, Ki) was intended; worth being explicit about the ~2.4% and ~7.4% differences
     - Setting limits without requests (Kubernetes auto-fills requests = limits, which is fine but often surprising)
     - Setting requests without limits (allowed, creates Burstable pods, but allows the container to consume unbounded resources up to node capacity)
     - Expecting CPU limits to kill the container (they don't; memory limits kill, CPU limits throttle)
     - Missing that a pod needs BOTH requests AND limits to be Guaranteed, for BOTH CPU AND memory, on EVERY container
     - Configuring LimitRange max lower than default (default gets rejected)
     - Creating pods without resources in a namespace with a ResourceQuota that requires resources; the pod is rejected at admission
     - Forgetting that ResourceQuota sums across all pods in the namespace; one pod can't use it all if other pods exist
     - Using ephemeral-storage limits without understanding what counts (emptyDir + logs + writable layer)
     - Confusing node allocatable with node capacity; capacity includes system reserves that allocatable excludes
   - Include a "Verification Commands Cheat Sheet" with the most useful kubectl commands: QoS class via jsonpath, resource values via jsonpath, OOMKilled state via jsonpath on containerStatuses, ResourceQuota usage via describe, LimitRange state via describe

8. **Quality Standards**
   - No conflicts between tutorial and exercises (different namespaces, resource names, LimitRange/ResourceQuota isolation)
   - All commands must be copy-paste ready with no manual substitution required
   - Verification commands should be specific (check QoS class via jsonpath, check resource values via jsonpath, check container lastState reason, check ResourceQuota.status.used) not vague ("check if it works")
   - Exercises should build practical muscle memory for the CKA performance exam, where setting correct requests and limits under time pressure and diagnosing OOMKill/unschedulable pods from Events is a core skill
   - Tutorial should teach ONE cohesive workflow end-to-end
   - No em dashes anywhere in output (use commas, periods, or parentheses)
   - Use narrative paragraph flow in prose explanations, not stacked single-sentence declarations
   - Full replacement files, no patches or diffs
   - Stress workloads must be time-bounded and clean up after themselves; no infinite-running stress containers
   - Where exercises depend on timing (OOMKill observation, restart count accumulation), state the wait time explicitly and do not expect instant verification

Please create the homework assignment for Pod Resources and QoS.
Generate all four files: README.md, pod-resources-qos-tutorial.md, pod-resources-qos-homework.md, and pod-resources-qos-homework-answers.md
