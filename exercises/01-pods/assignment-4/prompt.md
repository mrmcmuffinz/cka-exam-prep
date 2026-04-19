I need you to create a comprehensive Kubernetes homework assignment to help me practice **Pod Scheduling and Placement**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S6 (Core Concepts, Scheduling, Logging & Monitoring, Application Lifecycle Management, Cluster Maintenance, Security through KubeConfig)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment is the fourth in a planned series of pod-focused assignments. It covers how Kubernetes decides which node a pod runs on, and how pod authors and cluster operators influence that decision. Pod construction fundamentals (Assignment 1), configuration injection (Assignment 2), and health/observability (Assignment 3) are assumed knowledge. Other pod topics will get their own dedicated assignments later and MUST NOT appear here.

**Kind cluster requirement (CRITICAL for this assignment):**
Pod scheduling cannot be meaningfully practiced on a single-node cluster. The learner needs a kind cluster with multiple worker nodes. The homework setup must include instructions for creating a multi-node kind cluster (recommended: 1 control-plane node plus 3 worker nodes) using a kind config file, with the rootless nerdctl provider. Tutorial and exercises should explicitly reference node names from this setup (kind-worker, kind-worker2, kind-worker3) so examples are concrete. Node labels and taints applied during exercise setup should be cleaned up during teardown so repeated runs of the same exercise work consistently.

**In scope for this assignment:**
- The scheduler decision flow at a high level: filtering (predicates) then scoring (priorities), why a pod stays Pending, how to diagnose scheduling failures from Events
- Manual scheduling via nodeName (bypassing the scheduler) and when this is appropriate (debugging, static pods, not production workloads)
- Node labels: listing labels with kubectl get nodes --show-labels, adding labels with kubectl label nodes, the standard well-known labels (kubernetes.io/hostname, kubernetes.io/os, kubernetes.io/arch, node-role.kubernetes.io/*)
- nodeSelector: the simple hard-match selector, when to use it, its limitations
- Node affinity: requiredDuringSchedulingIgnoredDuringExecution (hard), preferredDuringSchedulingIgnoredDuringExecution (soft with weights), operators (In, NotIn, Exists, DoesNotExist, Gt, Lt), matchExpressions structure
- The "IgnoredDuringExecution" suffix: affinity rules are evaluated at scheduling time only, not enforced after the pod is placed
- Node anti-affinity (expressed as NotIn or DoesNotExist on node affinity)
- Pod affinity and pod anti-affinity: requiredDuringSchedulingIgnoredDuringExecution and preferredDuringSchedulingIgnoredDuringExecution, topologyKey (kubernetes.io/hostname for per-node, topology.kubernetes.io/zone for per-zone), labelSelector for matching target pods
- Common pod affinity patterns: "co-locate on same node as X" (pod affinity with hostname topology), "spread across nodes" (pod anti-affinity with hostname topology)
- Taints on nodes: effect values NoSchedule, PreferNoSchedule, NoExecute; adding and removing taints with kubectl taint; the built-in control-plane taint
- Tolerations on pods: the matching semantics (key, operator, value, effect), operator Equal vs Exists, tolerationSeconds for NoExecute
- The taint/toleration asymmetry: tolerations allow a pod to be placed on a tainted node but do not require it; pairing tolerations with node affinity or nodeSelector is the standard pattern for dedicated-node workloads
- Topology spread constraints: maxSkew, topologyKey, whenUnsatisfiable (DoNotSchedule vs ScheduleAnyway), labelSelector, how topology spread differs from pod anti-affinity (pod anti-affinity is all-or-nothing per topology; topology spread allows bounded imbalance)
- Priority classes: creating a PriorityClass, assigning priorityClassName to a pod, preemption behavior when higher-priority pods are unschedulable (observe, do not deeply configure)
- Diagnostic workflow for a Pending pod: kubectl describe pod to read the FailedScheduling event, interpreting messages like "0/4 nodes are available: 3 node(s) didn't match Pod's node affinity/selector, 1 node(s) had untolerated taint"

**Out of scope (covered in other assignments, do not include):**
- Pod spec fundamentals, commands/args, restart policy, image pull policy, labels/annotations on pods for non-scheduling purposes (Assignment 1: Pod Fundamentals)
- Init containers (Assignment 1 for basics, Assignment 6 for advanced patterns)
- ConfigMaps and Secrets in any form (Assignment 2: Pod Configuration Injection)
- Probes, lifecycle hooks, termination (Assignment 3: Pod Health and Observability)
- Resource requests and limits, QoS classes (Assignment 5: Pod Resources and QoS). Note: scheduling decisions depend on requests, but in this assignment, if a pod needs requests to demonstrate a scheduling behavior, set a small request explicitly and explain it is a scheduling input; do not go deep on QoS classes or limit tuning
- Advanced multi-container patterns (Assignment 6)
- ReplicaSets, Deployments, DaemonSets, Services (Assignment 7 and beyond). DaemonSet is a common scheduling-adjacent topic but it belongs to the controllers assignment
- Custom schedulers and scheduler profile configuration (covered in the Mumshad course but out of scope for this assignment; mention existence in tutorial, do not build exercises around them)
- Admission controllers that affect scheduling
- Cluster autoscaler behavior

Workloads in this assignment should be simple single-container pods running a long-lived sleep command (e.g., `busybox sleep 3600`) unless a specific scheduling behavior requires otherwise. The point of the pod is to be schedulable or not, not to do real work.

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: pod-scheduling-tutorial.md
   - Begin with a "Cluster Setup" section that shows how to create a multi-node kind cluster using rootless nerdctl, with a sample kind config file for 1 control-plane and 3 workers. Include the teardown command. Make it clear the rest of the tutorial assumes this cluster.
   - Complete step-by-step tutorial showing how each scheduling mechanism works, in the order a learner should encounter them: manual scheduling, nodeSelector, node affinity, pod affinity/anti-affinity, taints and tolerations, topology spread, priority classes
   - Include BOTH imperative approaches where they exist (kubectl label nodes, kubectl taint nodes, kubectl run with --overrides for ad-hoc scheduling) AND declarative YAML for everything else
   - Be honest that node affinity, pod affinity, tolerations, and topology spread are declarative-only in practice; the imperative workflow is "kubectl run --dry-run=client -o yaml, then edit"
   - Explain every field when introducing it: what it does, what values are valid, how the scheduler uses it, and common pitfalls
   - Demonstrate the diagnostic workflow live: create a pod that cannot be scheduled, show kubectl get pod showing Pending, show kubectl describe pod and walk through the FailedScheduling event message field by field
   - For each scheduling mechanism, show both the success case (pod schedules where expected) and a failure case (pod stays Pending, with the learner reading the event to understand why)
   - For pod affinity, demonstrate "schedule this pod on the same node as an existing pod with label app=cache" as a concrete example
   - For pod anti-affinity, demonstrate "spread three pods across three nodes so no two pods land on the same node"
   - For topology spread, demonstrate "three pods should spread across nodes with maxSkew of 1, so the difference between the most-loaded and least-loaded node is at most 1"
   - For taints and tolerations, demonstrate the full pattern: taint a node, show a pod cannot schedule, add a toleration, show it schedules; then demonstrate the dedicated-node pattern by combining the toleration with a nodeSelector
   - For priority classes, create two PriorityClasses (low and high), run pods at each level, and describe the preemption behavior conceptually (kind clusters may not have enough pressure to observe preemption directly; this is acceptable, describe the behavior with an explanation)
   - Include a section on reading FailedScheduling messages, with annotated examples of the common message formats and what each part means
   - Tutorial should use its own namespace (tutorial-pod-scheduling), its own node labels prefixed with tutorial/, and its own resource names that don't conflict with exercises. Include explicit cleanup of node labels and taints at the end of the tutorial.
   - Tutorial should be a complete, functional workflow from start to finish

2. **Progressive Exercises (15 total)**

   **Level 1 (3 exercises): Basic single-concept tasks**
   - One scheduling mechanism, one pod, straightforward placement requirement
   - Straightforward verification (2-3 checks)
   - Examples: "Label kind-worker2 with disktype=ssd, then create a pod that uses nodeSelector to land on that node", "Create a pod with nodeName set to kind-worker3", "Taint kind-worker with gpu=true:NoSchedule, then create a pod with a matching toleration"

   **Level 2 (3 exercises): Multi-concept tasks**
   - Combine 2-3 scheduling concepts on one pod (e.g., node affinity with multiple matchExpressions, or a toleration paired with node affinity for dedicated-node placement, or required plus preferred node affinity)
   - Use matchExpressions with at least one operator other than In (NotIn, Exists, DoesNotExist, Gt, Lt)
   - Still single pod per exercise in most cases, single namespace
   - More verification checks (4-6 checks)
   - Examples: "Create a pod that requires a node with label zone in [us-east-1a, us-east-1b] AND prefers a node with label disktype=ssd with weight 50", "Taint kind-worker2 with dedicated=ml:NoSchedule, label it dedicated=ml, then create a pod that tolerates the taint AND uses node affinity to require the dedicated=ml label (so the pod only runs on dedicated nodes, and no other pod accidentally lands there)"

   **Level 3 (3 exercises): Debugging broken configurations**
   - Given broken pod YAML or broken node configuration that produces specific scheduling failures
   - Single clear issue per exercise. Mix failure types across the three exercises:
     - At least one "pod is Pending due to nodeSelector or node affinity mismatch" failure (typo in label key, wrong value, operator mismatch)
     - At least one "pod is Pending due to a taint with no matching toleration" failure (missing toleration, toleration key/value mismatch, wrong effect)
     - At least one "pod looks scheduled but landed in the wrong place" failure (affinity rule too loose so it could land anywhere, preferred used where required was intended, pod anti-affinity missing so pods stack)
   - Must identify the problem from FailedScheduling events or pod placement output and fix it
   - The broken YAML and any broken node setup must be provided in the setup commands so the learner doesn't have to type it

   **Level 4 (3 exercises): Complex real-world scenarios**
   - Realistic production-style placement patterns:
     - Dedicated-node pattern: one worker node is reserved for a specific workload via taint, and pods for that workload use tolerations plus node affinity; general workloads must not land there
     - High-availability spread: three pods representing replicas of a stateful workload must spread across all three worker nodes using topology spread constraints or pod anti-affinity (both patterns as separate exercises, so the learner implements each)
     - Co-location pattern: a "frontend" pod must be scheduled on the same node as an existing "cache" pod for latency reasons, using pod affinity
   - 8+ verification checks covering multiple aspects (node labels, taints, pod placement across nodes, pod conditions, Events showing no FailedScheduling)
   - These are build tasks, not debugging tasks; the objective can describe what to build

   **Level 5 (3 exercises): Advanced debugging and comprehensive tasks**
   - Multiple issues in one setup (2-3 problems across node configuration and pod spec)
   - Subtle issues: node affinity requiredDuringSchedulingIgnoredDuringExecution with the wrong key AND a toleration missing, pod anti-affinity topologyKey that doesn't exist as a node label so anti-affinity silently fails, priorityClassName referencing a PriorityClass that doesn't exist, topology spread constraint with labelSelector that matches no pods, tolerations that match the taint key but wrong effect
   - OR a comprehensive build task with specific stated requirements for a small production topology (e.g., 3 workers in two simulated zones via labels, an infrastructure daemon that must run on every node except the control plane, an application that must spread across zones with maxSkew 1, and a critical system pod with highest priority)
   - Requires deep understanding of how scheduling constraints combine, which ones are hard and which are soft, and what the scheduler does when multiple constraints conflict
   - 10+ verification checks

3. **Exercise Structure**
   - Each exercise must include:
     - Numbered heading ONLY (e.g., "### Exercise 3.1") with NO descriptive title or subtitle
     - Clear objective statement that describes the goal without telegraphing the solution
     - Complete setup commands (copy-paste ready, no placeholders). Setup must include any node label and taint operations the exercise needs.
     - Specific task description
     - Verification commands with expected results (specific expected output: which node the pod landed on, whether Events contain FailedScheduling, whether labels and taints are correctly set)
     - A cleanup note listing the node labels and taints to remove at the end of the exercise so they don't leak into later exercises
   - Use unique namespaces per exercise (ex-1-1, ex-1-2, etc.)
   - Use distinct pod names and distinct node label keys per exercise (prefix all custom node labels with ex-<level>-<number>/ or with a clear per-exercise key) so exercises are isolated
   - Setup commands should create the namespace, apply node labels and taints, and for debugging exercises apply the broken YAML via a heredoc
   - Cleanup of node-level state (labels and taints) is not optional; it must be explicit at the end of each exercise or in a per-exercise cleanup block

4. **Anti-Spoiler Requirements (CRITICAL for debugging exercises)**
   - Exercise headings must NOT contain descriptive titles that hint at the problem
     - BAD: "Exercise 3.1: The pod with the wrong node selector"
     - BAD: "Exercise 3.2: Missing toleration"
     - BAD: "Exercise 5.1: Three constraint problems"
     - GOOD: "Exercise 3.1"
   - Objective lines must NOT reveal the number or type of issues
     - BAD: "Fix the nodeSelector mismatch so the pod can schedule"
     - BAD: "There are two issues with the tolerations"
     - GOOD: "Fix the broken configuration so the pod reaches Running state on the intended node"
     - GOOD: "The setup above has one or more problems. Find and fix whatever is needed so that..."
   - Task descriptions should state the desired end state (e.g., "pod is Running on kind-worker2 and no FailedScheduling events exist"), not the number or location of bugs
   - Section-level headings like "Level 3: Debugging Broken Configurations" are acceptable as navigation; per-exercise hints are not
   - Level 4 build exercises CAN describe what to build in their objectives (that's the task, not a spoiler)

5. **Resource Constraints**
   - Only use Kubernetes resources I've already learned and that are in scope for this assignment
   - In-scope resources: Pods, Namespaces, Nodes (for labeling and tainting only, not creating), PriorityClasses
   - Do NOT use ConfigMaps, Secrets, Services, Deployments, ReplicaSets, DaemonSets, PersistentVolumes
   - Do NOT use probes, lifecycle hooks, or resource limits (small resource requests are permitted only when a scheduling decision genuinely depends on them, and must be explained in the exercise setup)
   - Do NOT use init containers unless absolutely necessary
   - Container images should be small and fast: `busybox` and `alpine` are preferred for sleep-based workloads. Use specific tags, never `latest`. nginx:1.25 may be used when a pod that actually serves traffic is needed, but sleep is almost always enough.
   - Commands for sleep workloads: `sh -c 'echo started; sleep 3600'` so the learner can confirm the container actually started via kubectl logs

6. **File Format**
   - Output FOUR separate Markdown files:
     - `README.md` - Overview of all files and how to use them
     - `pod-scheduling-tutorial.md` - Complete tutorial
     - `pod-scheduling-homework.md` - 15 progressive exercises only
     - `pod-scheduling-homework-answers.md` - Complete solutions
   - Use proper Markdown syntax with fenced code blocks and language tags (bash, yaml)
   - Each file should be self-contained
   - README.md should include:
     - Brief description of what each file contains
     - Recommended workflow (tutorial → homework → answers)
     - Difficulty level progression explanation
     - Prerequisites needed (multi-node kind cluster with nerdctl, CKA sections completed, Assignments 1-3 completed)
     - A "Cluster Setup" section with the kind config for a 1 control-plane, 3 worker cluster and the `KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster --config ...` command
     - Estimated time commitment
     - A note that this is Assignment 4 in a pod series, with a brief list of the other planned assignments
     - A note that node labels and taints persist across exercises if not cleaned up, so following the per-exercise cleanup steps matters
   - homework.md should include:
     - Brief introduction referencing the tutorial file
     - Exercise setup commands section at the start (cluster verification with `kubectl get nodes`, optional global cleanup of any leftover labels/taints from previous runs)
     - All 15 exercises organized by difficulty level, each with inline cleanup
     - Cleanup section at the end (per-namespace, removal of all custom node labels, removal of all custom taints, listing of PriorityClasses to delete)
     - "Key Takeaways" section summarizing important concepts, including the scheduler decision flow, the difference between nodeSelector/nodeAffinity/podAffinity/taints, when to use required vs preferred, and the dedicated-node pattern
   - tutorial.md should teach a cohesive workflow end-to-end (recommend: start with manual scheduling, progress through nodeSelector and node affinity, then pod affinity/anti-affinity, then taints/tolerations, then topology spread, then priority classes, with each section building on what came before)
     - Include a "Reference Commands" section at the end with imperative and declarative examples (kubectl label, kubectl taint, kubectl describe node, kubectl get pods -o wide to see node placement)
     - Include a "Scheduling Mechanism Decision Table" showing when to use nodeSelector vs node affinity vs pod affinity vs taints/tolerations vs topology spread
     - Include a "Reading FailedScheduling Events" reference section with annotated example messages
     - Include a "Dedicated-Node Pattern" reference showing the taint+toleration+nodeSelector combination
     - This serves as a quick reference while doing exercises
   - answers.md should include solutions for all 15 exercises
     - Answer key headings should use "Exercise X.Y Solution" format (no descriptive titles needed, since answers don't spoil)

7. **Answer Key Requirements**
   - File: pod-scheduling-homework-answers.md
   - Include complete solutions for all exercises
   - Declarative is the primary approach for pod specs in this assignment; imperative is shown for kubectl label, kubectl taint, and basic pod creation, and explicitly noted as not sufficient for affinity and toleration configuration
   - For debugging exercises, explain what was wrong, why the scheduler rejected the pod (or placed it unexpectedly), and how to diagnose it from the FailedScheduling event and from inspecting node labels and taints
   - Include a "Common Mistakes" section covering:
     - Tolerations without matching node affinity, causing the pod to schedule on tainted nodes but also on untainted nodes (no dedicated-node guarantee)
     - Node affinity without tolerations, causing the pod to match the node but get blocked by the taint
     - Using preferred where required was intended, causing the pod to schedule somewhere unexpected when the preferred nodes are full
     - topologyKey referencing a label that doesn't exist on nodes, causing pod affinity/anti-affinity or topology spread to silently misbehave
     - Operator Exists with a value field (value is ignored, which is confusing)
     - tolerationSeconds on a toleration without NoExecute effect (ignored)
     - Forgetting the built-in control-plane taint when expecting a workload to run on the control-plane node
     - Misunderstanding "IgnoredDuringExecution": affinity is evaluated at scheduling only, so changing node labels later does not reschedule the pod
     - Using nodeName to force scheduling and losing scheduler visibility (no Events, no FailedScheduling, pod just fails silently if the node is unreachable)
   - Include a "Verification Commands Cheat Sheet" with the most useful kubectl commands for inspecting scheduling: kubectl get nodes --show-labels, kubectl describe node, kubectl get pods -o wide, kubectl describe pod (focus on Events section), jsonpath queries for taints and labels

8. **Quality Standards**
   - No conflicts between tutorial and exercises (different namespaces, different node label keys, different resource names)
   - All commands must be copy-paste ready with no manual substitution required, assuming the standard multi-node kind cluster (1 control-plane, 3 workers named kind-worker, kind-worker2, kind-worker3)
   - Verification commands should be specific (check pod placement with `kubectl get pod -o wide`, check labels with jsonpath, check taints with jsonpath, check FailedScheduling events with kubectl get events or describe) not vague ("check if it works")
   - Exercises should build practical muscle memory for the CKA performance exam, where configuring scheduling under time pressure and diagnosing Pending pods from Events is a core skill
   - Tutorial should teach ONE cohesive end-to-end workflow through the scheduling mechanisms
   - No em dashes anywhere in output (use commas, periods, or parentheses)
   - Use narrative paragraph flow in prose explanations, not stacked single-sentence declarations
   - Full replacement files, no patches or diffs
   - Every exercise that modifies node state (labels, taints) must clean up that state at the end, and the cleanup must be tested to work whether or not the learner completed the exercise correctly

Please create the homework assignment for Pod Scheduling and Placement.
Generate all four files: README.md, pod-scheduling-tutorial.md, pod-scheduling-homework.md, and pod-scheduling-homework-answers.md
