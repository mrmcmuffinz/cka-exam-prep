I need you to create a comprehensive Kubernetes homework assignment to help me practice **Workload Controllers**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S6 (Core Concepts, Scheduling, Logging & Monitoring, Application Lifecycle Management, Cluster Maintenance, Security through KubeConfig)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment is the seventh and final in the planned pod-focused series, and it transitions from "the pod itself" to "things that manage pods." It covers the three core workload controllers a CKA candidate must know cold: ReplicaSets (the underlying primitive), Deployments (the workhorse controller for stateless applications), and DaemonSets (the controller for per-node workloads). Pod construction fundamentals (Assignment 1), configuration injection (Assignment 2), health/observability (Assignment 3), scheduling (Assignment 4), resources/QoS (Assignment 5), and multi-container patterns (Assignment 6) are all assumed knowledge. Every concept taught in those assignments applies here, because controllers manage pods built from pod specs.

**Multi-node kind cluster recommended:**
DaemonSets are meaningless on a single-node cluster, and Deployment rollouts are easier to observe with multiple nodes. Use the multi-node kind cluster (1 control-plane, 3 workers) from Assignment 4. The README should reference that setup.

**In scope for this assignment:**

*ReplicaSets:*
- ReplicaSet spec structure: replicas count, selector, template (pod spec embedded)
- The selector-matches-template-labels contract: if the selector doesn't match labels in the template, the API server rejects it
- How ReplicaSets reconcile: kill excess pods, create missing pods, match on selector (not on being a descendant), which means a ReplicaSet can "adopt" pods whose labels match
- Scaling ReplicaSets: kubectl scale, editing the replicas field
- Deletion: --cascade=orphan vs default (delete the pods too)
- Why you almost never create a ReplicaSet directly (Deployments create them for you); ReplicaSets are taught here for conceptual understanding and because the exam can test them

*Deployments:*
- Deployment spec structure: replicas, selector, template, strategy (RollingUpdate vs Recreate), revisionHistoryLimit
- RollingUpdate strategy: maxSurge and maxUnavailable, how they bound the rollout, default values (25% each)
- Recreate strategy: when to use it (migrations that can't tolerate overlap, singletons)
- How Deployments manage ReplicaSets: creating a new ReplicaSet for each template change, scaling the old one down while scaling the new one up
- Rollout workflow: kubectl rollout status, kubectl rollout history, kubectl rollout undo (with optional --to-revision), kubectl rollout pause and kubectl rollout resume
- Common rollout triggers: image tag changes, env var changes, label changes on the template (note: selector is immutable, template labels are not)
- Rollout failure modes: new ReplicaSet's pods never become Ready (image pull error, crash, failed probes), rollout stuck, how to abort
- progressDeadlineSeconds: how long a rollout can take before it's marked failed; what "failed" means in terms of controller behavior
- Scaling Deployments: kubectl scale deployment, edit, or change the YAML replicas field
- Labeling and selector rules: the selector is effectively immutable after creation, the template labels must match the selector, adding labels is fine but changing the selector is not
- Imperative shortcuts: kubectl create deployment, kubectl set image, kubectl edit deployment, kubectl rollout

*DaemonSets:*
- DaemonSet spec structure: selector, template, updateStrategy (RollingUpdate vs OnDelete)
- How DaemonSets place pods: one per node, automatically responds to nodes joining and leaving the cluster
- Node selection within DaemonSets: nodeSelector and node affinity on the template (for running only on some nodes, e.g., only on Linux workers), tolerations for running on tainted nodes (including the control-plane node)
- The common pattern of DaemonSets tolerating all taints to run on every node (used by log collectors, CNI agents, node exporters)
- Update strategies: RollingUpdate (default, maxUnavailable controls how many nodes can be unavailable at once) and OnDelete (pods only update when manually deleted; useful for highly-controlled rollouts)
- When to use DaemonSets: log collection, metrics agents, network plugins, storage plugins, per-node caches
- Diagnostic workflow: kubectl get daemonset shows DESIRED, CURRENT, READY, UP-TO-DATE, AVAILABLE, NODE SELECTOR; kubectl describe ds for events

*Cross-controller concepts:*
- The controller → pod ownership chain: Deployment owns ReplicaSet(s) owns Pod(s); ownerReferences in pod metadata
- Garbage collection: deleting the owner cascades to children by default
- Why labels and selectors are the "glue" of Kubernetes and why wrong labels are a common source of controller confusion
- kubectl rollout commands across controllers (all three support rollout status/history/undo, though DaemonSet is less commonly rolled back)
- Reading controller state from status fields: observedGeneration, conditions, collisionCount (rare)

**Out of scope (covered in other assignments or entirely outside this series, do not include):**
- Pod spec fundamentals, commands/args, restart policy, image pull policy, labels/annotations on pods (Assignment 1); every controller's template is still a pod spec, but this assignment assumes the learner can build pod specs without re-teaching.
- Init containers and multi-container patterns (Assignments 1 and 6): controller templates can contain init containers and sidecars, and exercises may occasionally use them when realistic, but the pattern teaching is not repeated here.
- ConfigMaps and Secrets (Assignment 2): if an exercise needs configuration injected into a controller's pods, refer to Assignment 2 techniques; do not re-teach.
- Probes and lifecycle hooks (Assignment 3): readiness probes matter for rollouts (a pod isn't counted Ready until its readiness probe passes), so briefly explain the interaction in the tutorial; do not build exercises around probe tuning.
- Scheduling primitives (Assignment 4): DaemonSets use nodeSelector, affinity, and tolerations extensively, but those mechanisms are assumed knowledge. Exercises can reference them.
- Resource requests and limits (Assignment 5): workload templates have resources; don't re-teach.
- StatefulSets: explicitly out of scope for this assignment. Mention in tutorial as "the next thing to learn after this" but don't cover or use them.
- Jobs and CronJobs: explicitly out of scope for this assignment. Mention in tutorial as adjacent controllers but don't cover.
- HorizontalPodAutoscaler and VerticalPodAutoscaler: out of scope.
- Services, Ingress, Gateway API: out of scope. Rollouts are observable without Services (via kubectl get pods and Deployment status), keep exercises Service-free.
- Helm, Kustomize, operators, custom resources: out of scope.

Workloads in exercises should be simple and fast-starting. `nginx:1.25` is the default choice for "real-ish server", `busybox` or `alpine` for "prints something and sleeps". Use specific tags, never `latest`. Avoid images with long startup times or heavy resource needs so rollouts complete quickly during practice.

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: workload-controllers-tutorial.md
   - Begin with a short "Why controllers?" section explaining that bare pods have no self-healing: if a pod dies, it's gone. Controllers exist to maintain desired state.
   - Complete step-by-step tutorial building up through the three controllers in the order a learner should encounter them: ReplicaSet first (because it's the primitive), then Deployment (the workhorse and where nearly all the interesting behavior lives), then DaemonSet (the specialized per-node controller)
   - Include BOTH imperative (kubectl create deployment, kubectl scale, kubectl set image, kubectl rollout, kubectl expose) AND declarative (YAML) approaches. Imperative is heavily useful for the CKA exam given the time pressure; emphasize it.
   - Explain every field when introducing it: replicas, selector, template, strategy fields for RollingUpdate, updateStrategy for DaemonSets, the subtle immutability of selectors
   - For ReplicaSets, build one from YAML, scale it, show how pods get names derived from the ReplicaSet name plus a random suffix, demonstrate the selector-matches-template-labels requirement by showing what happens if they don't match
   - For Deployments, build one imperatively with kubectl create deployment, inspect the ReplicaSet it creates, then do a rolling update by changing the image with kubectl set image, watch the rollout with kubectl rollout status, inspect the rollout history with kubectl rollout history, roll back with kubectl rollout undo. Then do it all declaratively (edit YAML, apply, watch).
   - Demonstrate maxSurge and maxUnavailable concretely: set them to explicit values, do a rollout, and observe how pod counts behave (describe or predict the behavior; kind clusters may roll through so fast it's hard to observe the transient state, so prepare the learner for this limitation)
   - Demonstrate a failing rollout: trigger a rollout with a bad image tag, show the rollout gets stuck, show kubectl rollout status reporting the failure, show the old ReplicaSet still serving while the new one fails, roll back
   - Demonstrate the difference between kubectl rollout undo (goes to previous revision) and kubectl rollout undo --to-revision=N (goes to specific revision)
   - Demonstrate Recreate strategy: set strategy to Recreate, do a rollout, show that all old pods terminate before new pods start (brief outage in exchange for no overlap)
   - For DaemonSets, build one targeting all worker nodes, show it places one pod per node, label one of the worker nodes with a selector to demonstrate node-selector-based targeting, show how tainting a node that the DaemonSet does not tolerate removes the pod, add a toleration to the DaemonSet and show the pod returns
   - Demonstrate the control-plane taint: show that a default DaemonSet does not run on the kind control-plane node, then add the control-plane toleration and show the DaemonSet now runs there too (this is the pattern cluster-critical agents use)
   - Demonstrate DaemonSet update strategies: do a RollingUpdate with a small maxUnavailable and show it rolls one node at a time; briefly describe OnDelete without a full demo
   - Show the controller → pod ownership chain: inspect a Deployment's ReplicaSets, inspect a pod's ownerReferences pointing to its ReplicaSet, inspect a ReplicaSet's ownerReferences pointing to its Deployment
   - Demonstrate garbage collection: delete a Deployment and watch its ReplicaSets and Pods be deleted; then show --cascade=orphan as the alternative
   - Tutorial should use its own namespace (tutorial-workload-controllers) and resource names that don't conflict with exercises
   - Tutorial should be a complete, functional workflow from start to finish

2. **Progressive Exercises (15 total)**

   **Level 1 (3 exercises): Basic single-concept tasks**
   - One controller, one action, straightforward verification (2-3 checks)
   - Examples: "Create a Deployment named web with 3 replicas of nginx:1.25 in namespace ex-1-1; verify 3 pods are Running", "Scale an existing Deployment to 5 replicas using kubectl scale", "Create a DaemonSet that runs a busybox container printing the node name every 10 seconds on every worker node"

   **Level 2 (3 exercises): Multi-concept tasks**
   - Combine 2-3 controller concepts (create a Deployment with a specific strategy, then update its image and roll back; create a DaemonSet with a nodeSelector and add a toleration; create a Deployment with explicit maxSurge and maxUnavailable values)
   - More verification checks (4-6 checks)
   - Examples: "Create a Deployment with 4 replicas, maxSurge 1, maxUnavailable 0, then update the image and verify the rollout never has fewer than 4 ready pods at any point", "Create a ReplicaSet, then 'adopt' an existing matching pod by verifying the ReplicaSet's pod count includes it", "Create a DaemonSet that runs only on nodes labeled workload=logging, add that label to two worker nodes, then remove the label from one and observe the pod eviction"

   **Level 3 (3 exercises): Debugging broken configurations**
   - Given broken workload YAML that fails in specific ways
   - Single clear issue per exercise. Mix failure types across the three exercises:
     - At least one "controller creates no pods or wrong number of pods" failure (selector doesn't match template labels, replicas value wrong, selector matches pods from a different controller causing chaos)
     - At least one "rollout is stuck or failing" failure (image tag invalid, probe misconfigured in template, progressDeadlineSeconds too short for the actual rollout time, Recreate strategy requested but set via typo to RollingUpdate)
     - At least one "DaemonSet isn't scheduling where expected" failure (missing toleration for a node taint the learner must identify, nodeSelector targeting a label no node has, updateStrategy misconfigured)
   - Must identify the problem from controller status, events, and pod state
   - The broken YAML must be provided in the setup commands

   **Level 4 (3 exercises): Complex real-world scenarios**
   - Realistic production-style controller configurations:
     - A Deployment with all the production essentials: 3 replicas, rolling update with tight maxSurge/maxUnavailable, readiness probe in the template, image pulled from a pinned tag, labels following a simple app/version convention; then perform a rolling update to a new version and roll back
     - A DaemonSet for a cluster-wide agent that must run on every node including the control-plane, tolerating all taints, with a small resource footprint
     - A two-Deployment scenario representing a simple app: a "frontend" Deployment and a "backend" Deployment, each with their own replicas and templates, in the same namespace, with labels that allow each controller to select only its own pods (demonstrating the importance of good label hygiene when multiple controllers coexist)
   - 8+ verification checks covering multiple aspects (pod counts, ready state, rollout history, node distribution for DaemonSets, label correctness)
   - These are build tasks, not debugging tasks; the objective can describe what to build

   **Level 5 (3 exercises): Advanced debugging and comprehensive tasks**
   - Multiple issues in one setup (2-3 problems across controller config, template, and rollout strategy)
   - Subtle issues: selector that matches pods from two controllers simultaneously (one controller keeps deleting the other's pods), revisionHistoryLimit of 0 so rollback is impossible, readiness probe in a Deployment template that's too strict so the rollout stalls at 1 new pod ready, DaemonSet with tolerations that also accidentally match node affinity that excludes most nodes (combined constraints eliminate almost all targets), kubectl rollout undo requested on a Deployment that was never rolled out so nothing happens, maxUnavailable 100% combined with Recreate making it effectively a Recreate-with-extra-steps
   - OR a comprehensive build task: "Set up a small realistic application topology: a frontend Deployment (3 replicas, rolling update), a backend Deployment (2 replicas, Recreate strategy because it holds singleton state in its template), and a cluster-wide logging DaemonSet. Each must have correct labels, selectors, and templates such that the three controllers are fully independent and none accidentally touches another's pods. Then perform a rolling update on the frontend, roll it back, and verify the other two controllers were unaffected."
   - Requires deep understanding of labels, selectors, rollout strategies, and controller interactions
   - 10+ verification checks

3. **Exercise Structure**
   - Each exercise must include:
     - Numbered heading ONLY (e.g., "### Exercise 3.1") with NO descriptive title or subtitle
     - Clear objective statement that describes the goal without telegraphing the solution
     - Complete setup commands (copy-paste ready, no placeholders). Setup must create any node labels, taints, or broken resources the exercise depends on.
     - Specific task description
     - Verification commands with expected results (specific expected output: replica counts via jsonpath, rollout status, pod distribution across nodes, rollout history entries, controller Conditions)
     - Cleanup notes for any node-level state (labels, taints) the exercise applied
   - Use unique namespaces per exercise (ex-1-1, ex-1-2, etc.)
   - Use distinct controller names per exercise so rollouts and scaling actions are isolated
   - Setup commands should create the namespace and any broken resources for debugging exercises
   - Debugging exercises should provide the broken YAML via a heredoc

4. **Anti-Spoiler Requirements (CRITICAL for debugging exercises)**
   - Exercise headings must NOT contain descriptive titles that hint at the problem
     - BAD: "Exercise 3.1: The selector that matches nothing"
     - BAD: "Exercise 3.2: Missing DaemonSet toleration"
     - BAD: "Exercise 5.1: Three Deployment issues"
     - GOOD: "Exercise 3.1"
   - Objective lines must NOT reveal the number or type of issues
     - BAD: "Fix the Deployment's selector to match its template labels"
     - BAD: "There are two issues with the rollout strategy"
     - GOOD: "Fix the broken Deployment so it has 4 Ready pods and a successful rollout history of at least one revision"
     - GOOD: "The setup above has one or more problems. Find and fix whatever is needed so that..."
   - Task descriptions should state the desired end state, not the number or location of bugs
   - Section-level headings like "Level 3: Debugging Broken Configurations" are acceptable as navigation; per-exercise hints are not
   - Level 4 build exercises CAN describe what to build in their objectives (that's the task, not a spoiler)

5. **Resource Constraints**
   - Only use Kubernetes resources I've already learned and that are in scope for this assignment
   - In-scope resources: Pods, Namespaces, ReplicaSets, Deployments, DaemonSets, Nodes (for labeling and tainting in DaemonSet exercises only)
   - Do NOT use StatefulSets, Jobs, CronJobs, Services, Ingress, PersistentVolumes, HorizontalPodAutoscalers
   - Do NOT use ConfigMaps or Secrets unless a very specific exercise genuinely needs them; prefer inline env var literals and commands
   - Probes and resource requests/limits are permitted in templates where they naturally belong (readiness probes affect rollout behavior and are realistic; small resource requests keep exercises production-realistic), but exercises should not be ABOUT probe tuning or resource tuning; those are separate assignments
   - Container images: `nginx:1.25` for web-ish workloads, `busybox` and `alpine` for script-based workloads. Use specific tags, never `latest`. For rollout exercises, use `nginx:1.25` and `nginx:1.26-alpine` (or similar) as the two versions so the rollout has a visible difference.

6. **File Format**
   - Output FOUR separate Markdown files:
     - `README.md` - Overview of all files and how to use them
     - `workload-controllers-tutorial.md` - Complete tutorial
     - `workload-controllers-homework.md` - 15 progressive exercises only
     - `workload-controllers-homework-answers.md` - Complete solutions
   - Use proper Markdown syntax with fenced code blocks and language tags (bash, yaml)
   - Each file should be self-contained
   - README.md should include:
     - Brief description of what each file contains
     - Recommended workflow (tutorial → homework → answers)
     - Difficulty level progression explanation
     - Prerequisites needed (multi-node kind cluster with nerdctl from Assignment 4 setup, CKA sections completed, Assignments 1-6 completed)
     - Estimated time commitment
     - A note that this is Assignment 7 and the final entry in the pod-focused series, with a brief forward-pointer to natural next topics (StatefulSets, Jobs/CronJobs, Services, Ingress) as separate assignment series
     - A note that node-state cleanup (labels, taints applied during DaemonSet exercises) is important to avoid leaking into subsequent exercises
   - homework.md should include:
     - Brief introduction referencing the tutorial file
     - Exercise setup commands section at the start (cluster verification with `kubectl get nodes`, optional global cleanup)
     - All 15 exercises organized by difficulty level
     - Cleanup section at the end (per-namespace, removal of any custom node labels and taints, verification of clean state)
     - "Key Takeaways" section summarizing important concepts, including the controller reconciliation loop, the selector/template label contract, RollingUpdate field semantics (maxSurge and maxUnavailable), rollout history and undo, DaemonSet node-targeting patterns, and the controller-ownership chain
   - tutorial.md should teach a cohesive progression through the three controllers, building from simple to production-realistic
     - Include a "Reference Commands" section with imperative and declarative examples for all three controllers, including the kubectl rollout subcommands and kubectl scale variations
     - Include a "Controller Comparison Table" showing ReplicaSet vs Deployment vs DaemonSet across: purpose, typical use case, what it manages, scaling semantics, update strategy options, when to use
     - Include a "Rollout Commands Cheat Sheet" with kubectl rollout status, history, undo, pause, resume, restart
     - Include a "Label Hygiene" reference section on selector/template label rules and how to avoid controllers stepping on each other's pods
     - Include a "Diagnostic Workflow for Stuck Rollouts" showing the command sequence to identify whether the problem is image pull, probe failure, resource shortage, or selector mismatch
     - This serves as a quick reference while doing exercises
   - answers.md should include solutions for all 15 exercises
     - Answer key headings should use "Exercise X.Y Solution" format (no descriptive titles needed, since answers don't spoil)

7. **Answer Key Requirements**
   - File: workload-controllers-homework-answers.md
   - Include complete solutions for all exercises
   - Show both imperative and declarative approaches prominently; the CKA exam rewards fluent imperative use
   - For debugging exercises, explain what was wrong, why it caused the observed failure, and how to diagnose it from kubectl output (describe deployment/replicaset/daemonset, get pods with wide output, rollout status, events, inspecting ownerReferences)
   - Include a "Common Mistakes" section covering:
     - Selector not matching template labels (the pod-creation request gets rejected or the controller creates pods that it then cannot manage)
     - Trying to change a Deployment's selector (selector is effectively immutable after creation; workaround is delete and recreate)
     - Using `kubectl apply` with a label change in the selector and expecting it to work
     - Setting maxUnavailable to 100% without realizing it turns a rolling update into a near-Recreate
     - Using `latest` tag and not understanding why rollouts don't happen (the image reference didn't change, so the Deployment doesn't see it as a rollout)
     - Expecting `kubectl rollout undo` to work when revisionHistoryLimit is 0
     - Creating DaemonSets without tolerations and then wondering why they don't run on tainted nodes (including the built-in control-plane taint)
     - Deleting a Deployment with --cascade=orphan and then creating a new one with the same selector (which adopts the orphaned pods in unexpected ways)
     - Confusing `kubectl rollout restart` (which bumps a template annotation to trigger a fresh rollout with no spec change) with `kubectl rollout undo` (which reverts to a prior revision)
     - Scaling a Deployment and expecting it to create pods with a different template (the template changes with rollouts, not scales)
     - Two controllers in the same namespace with overlapping selectors; they fight over the pods and reconciliation never settles
   - Include a "Verification Commands Cheat Sheet" with the most useful kubectl commands: rollout status/history, get deployment/rs/ds with -o wide, pod ownerReferences via jsonpath, DaemonSet node distribution via `kubectl get pods -o wide` sorted by node, Deployment conditions via jsonpath

8. **Quality Standards**
   - No conflicts between tutorial and exercises (different namespaces, different controller names, different labels)
   - All commands must be copy-paste ready with no manual substitution required, assuming the standard multi-node kind cluster (1 control-plane, 3 workers named kind-worker, kind-worker2, kind-worker3)
   - Verification commands should be specific (check replica counts via jsonpath, check rollout status, check pod distribution across nodes via `kubectl get pods -o wide`, check ownerReferences, check rollout history) not vague ("check if it works")
   - Exercises should build practical muscle memory for the CKA performance exam, where creating Deployments imperatively, performing rollouts and rollbacks, and diagnosing stuck rollouts under time pressure are core skills
   - Tutorial should teach a cohesive progression through all three controllers end-to-end
   - No em dashes anywhere in output (use commas, periods, or parentheses)
   - Use narrative paragraph flow in prose explanations, not stacked single-sentence declarations
   - Full replacement files, no patches or diffs
   - Every exercise that modifies node state (labels, taints) must clean up that state at the end
   - Rollout exercises should use fast-starting images so the learner doesn't spend minutes waiting for each rollout to complete

Please create the homework assignment for Workload Controllers.
Generate all four files: README.md, workload-controllers-tutorial.md, workload-controllers-homework.md, and workload-controllers-homework-answers.md
