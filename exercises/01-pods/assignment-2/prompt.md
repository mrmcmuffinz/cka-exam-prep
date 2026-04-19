I need you to create a comprehensive Kubernetes homework assignment to help me practice **Pod Configuration Injection**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S6 (Core Concepts, Scheduling, Logging & Monitoring, Application Lifecycle Management, Cluster Maintenance, Security through KubeConfig)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment is the second in a planned series of pod-focused assignments. It covers how external configuration data gets into pods. Pod construction fundamentals are assumed knowledge from Assignment 1. Other pod topics will get their own dedicated assignments later and MUST NOT appear here.

**In scope for this assignment:**
- ConfigMap creation (imperative from literals, imperative from files, declarative YAML)
- Secret creation (imperative from literals, imperative from files, declarative YAML with base64-encoded data)
- Secret types (generic/Opaque, docker-registry, tls) with Opaque as the primary focus
- Consuming ConfigMaps as environment variables (single key via env.valueFrom.configMapKeyRef, all keys via envFrom.configMapRef)
- Consuming Secrets as environment variables (single key via env.valueFrom.secretKeyRef, all keys via envFrom.secretRef)
- Consuming ConfigMaps as volume mounts (full volume, specific keys via items, subPath for single-file mounts)
- Consuming Secrets as volume mounts (full volume, specific keys via items, subPath, defaultMode and per-key mode for file permissions)
- Projected volumes combining multiple ConfigMaps and Secrets into one mount point
- Downward API volumes (pod metadata, labels, annotations as files)
- Immutable ConfigMaps and Secrets (immutable: true field)
- Optional references (optional: true on configMapRef, secretRef, configMapKeyRef, secretKeyRef) and the pod behavior when the referenced resource is missing
- Update propagation behavior: env vars do NOT update when ConfigMap/Secret changes, volume-mounted files DO update (with eventual consistency, not atomic)
- base64 encoding and decoding for Secrets (use `base64 -w0` for encoding, never `tr -d '\n'`)

**Out of scope (covered in other assignments, do not include):**
- Pod spec fundamentals, commands/args, restart policy, image pull policy, labels/annotations on pods (Assignment 1: Pod Fundamentals)
- Init containers (Assignment 1 for basics, Assignment 6 for advanced patterns)
- Liveness, readiness, or startup probes (Assignment 3: Pod Health and Observability)
- Lifecycle hooks (Assignment 3)
- Node selectors, node affinity, taints, tolerations (Assignment 4: Pod Scheduling)
- Resource requests and limits, QoS classes (Assignment 5: Pod Resources and QoS)
- Advanced multi-container patterns (Assignment 6)
- ReplicaSets, Deployments, DaemonSets (Assignment 7: Workload Controllers)
- RBAC for accessing ConfigMaps/Secrets (separate RBAC assignment series)
- Encrypting Secrets at rest (etcd encryption configuration, covered in Security section work later)
- External secret management (Vault, Sealed Secrets, External Secrets Operator)

Pods in this assignment should be simple single-container pods unless a multi-container pod is needed to demonstrate something specific (e.g., two containers consuming the same projected volume). Keep pod spec complexity low so the focus stays on configuration injection.

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: pod-config-injection-tutorial.md
   - Complete step-by-step tutorial showing how to inject configuration into pods across all the major patterns
   - Include BOTH imperative (kubectl create configmap, kubectl create secret) AND declarative (YAML) approaches
   - Show the imperative-to-declarative workflow: generate YAML with `--dry-run=client -o yaml`, then edit and apply
   - Explain every spec field when introducing it: what it does, what values are valid, how Kubernetes uses it, and defaults
   - Cover all four major injection patterns with working examples:
     1. ConfigMap as single env var (env.valueFrom.configMapKeyRef)
     2. ConfigMap as bulk env vars (envFrom.configMapRef)
     3. ConfigMap as volume mount (full volume, then items, then subPath)
     4. Same four patterns for Secrets
   - Demonstrate the update propagation difference: change a ConfigMap, show that env-var-consuming pods do not see the change (require pod restart), and volume-mounted files do see the change (after kubelet sync interval)
   - Demonstrate a projected volume that combines a ConfigMap, a Secret, and downward API data into a single mount point with clear subPaths
   - Show Secret creation with `base64 -w0` for encoding, and explain why `base64 -w0` is preferred over piping to `tr -d '\n'` (the -w0 flag disables line wrapping in one step, less error-prone)
   - Show `kubectl create secret generic --from-literal` and `--from-file` as the imperative shortcuts that handle encoding for you
   - Show inspection commands: `kubectl get configmap/secret -o yaml`, `kubectl describe configmap/secret`, `kubectl get secret -o jsonpath='{.data.<key>}' | base64 -d`, and `kubectl exec` into a pod to verify mounted files and env vars
   - Demonstrate optional references with both a present and a missing ConfigMap to show the different behaviors
   - Tutorial should use its own namespace (tutorial-pod-config-injection) and resource names that don't conflict with exercises
   - Tutorial should be a complete, functional workflow from start to finish
   - Include a clear warning section that Secrets are base64-encoded, not encrypted, and that etcd encryption and RBAC are the actual security controls

2. **Progressive Exercises (15 total)**

   **Level 1 (3 exercises): Basic single-concept tasks**
   - One ConfigMap or Secret consumed via one injection pattern
   - Single pod, single namespace, one resource to create, one mount or env var to wire up
   - Straightforward verification (2-3 checks)
   - Examples: "Create a ConfigMap with two literal keys and mount it as a volume at /etc/config in a pod", "Create a Secret with one key and expose its value as a single environment variable in a pod", "Create a ConfigMap from a file and inject all its keys as env vars using envFrom"

   **Level 2 (3 exercises): Multi-concept tasks**
   - Combine 2-3 injection patterns in a single pod (e.g., some env vars from ConfigMap, some from Secret, and a volume mount for a config file)
   - OR use items to mount specific keys from a ConfigMap to specific file paths
   - OR use subPath to mount a single file from a ConfigMap into an existing directory without shadowing it
   - Still single pod, single namespace
   - More verification checks (4-6 checks)
   - Examples: "Create a pod where two env vars come from a Secret, one env var comes from a ConfigMap, and a config file is mounted via subPath at /etc/app/app.conf", "Create a ConfigMap with four keys but mount only two of them as files with custom paths"

   **Level 3 (3 exercises): Debugging broken configurations**
   - Given broken pod/ConfigMap/Secret YAML that fails in specific ways
   - Single clear issue per exercise. Mix failure types across the three exercises:
     - At least one "pod stuck in CreateContainerConfigError or ContainerCreating" failure (missing ConfigMap/Secret, wrong key name, wrong resource name reference)
     - At least one "pod runs but value is wrong" failure (valid YAML but valueFrom points to wrong key, or base64 encoding is wrong, or subPath mounts the wrong file)
     - Failure modes to draw from: referenced ConfigMap/Secret doesn't exist, key name typo in configMapKeyRef/secretKeyRef, Secret data value not base64-encoded (declarative YAML mistake), wrong API field (data vs stringData confusion), volume mount path collision, items path with leading slash, subPath pointing to non-existent key
   - Must identify the problem from pod status, events, or by inspecting the ConfigMap/Secret and fix it
   - The broken YAML must be provided in the setup commands so the learner doesn't have to type it

   **Level 4 (3 exercises): Complex real-world scenarios**
   - Realistic production-style configuration injection:
     - A pod that consumes a multi-file config directory (nginx-style /etc/nginx/conf.d pattern) from a ConfigMap
     - A pod with credentials in a Secret, app config in a ConfigMap, and runtime metadata from the downward API, all projected into a single /etc/app mount point
     - A multi-container pod where both containers consume the same ConfigMap but mount different keys at different paths
   - Use `defaultMode` or per-key `mode` to set restrictive file permissions on mounted Secrets (e.g., 0400)
   - 8+ verification checks covering multiple aspects (ConfigMap contents, Secret contents, env var values in the container, file contents at expected paths, file permissions)
   - These are build tasks, not debugging tasks; the objective can describe what to build

   **Level 5 (3 exercises): Advanced debugging and comprehensive tasks**
   - Multiple issues in one setup (2-3 problems across ConfigMap, Secret, and pod spec)
   - Subtle issues: immutable ConfigMap that needs to be recreated, optional reference that should be required, stringData vs data conflict where both are set, items list that's missing a key the pod expects, projected volume sources referencing mixed-case or hyphenated keys that collide when flattened
   - OR a comprehensive build task: "Set up configuration for a 3-tier application pod structure with a shared base ConfigMap, environment-specific overrides, and per-component Secrets, injected via a mix of env vars and volume mounts"
   - Requires deep understanding of how ConfigMap/Secret references resolve and how mount semantics work
   - 10+ verification checks

3. **Exercise Structure**
   - Each exercise must include:
     - Numbered heading ONLY (e.g., "### Exercise 3.1") with NO descriptive title or subtitle
     - Clear objective statement that describes the goal without telegraphing the solution
     - Complete setup commands (copy-paste ready, no placeholders)
     - Specific task description
     - Verification commands with expected results (specific expected output, not vague checks)
   - Use unique namespaces per exercise (ex-1-1, ex-1-2, etc.)
   - Use distinct ConfigMap and Secret names per exercise so learners don't accidentally reuse resources
   - Setup commands should create the namespace and any broken resources for debugging exercises
   - Debugging exercises should provide the broken YAML via a heredoc in the setup so the learner can apply it directly

4. **Anti-Spoiler Requirements (CRITICAL for debugging exercises)**
   - Exercise headings must NOT contain descriptive titles that hint at the problem
     - BAD: "Exercise 3.1: The Secret that isn't encoded"
     - BAD: "Exercise 3.2: The missing ConfigMap key"
     - BAD: "Exercise 5.1: Three problems across ConfigMap and pod"
     - GOOD: "Exercise 3.1"
   - Objective lines must NOT reveal the number or type of issues
     - BAD: "Fix the base64 encoding issue in the Secret"
     - BAD: "There are two issues with the ConfigMap reference"
     - GOOD: "Fix the broken configuration so that the pod reaches Running state and exposes DATABASE_URL with the expected value"
     - GOOD: "The setup above has one or more problems. Find and fix whatever is needed so that..."
   - Task descriptions should state the desired end state, not the number or location of bugs
   - Section-level headings like "Level 3: Debugging Broken Configurations" are acceptable as navigation; per-exercise hints are not
   - Level 4 build exercises CAN describe what to build in their objectives (that's the task, not a spoiler)

5. **Resource Constraints**
   - Only use Kubernetes resources I've already learned and that are in scope for this assignment
   - In-scope resources: Pods, Namespaces, ConfigMaps, Secrets, projected volumes, downward API volumes, emptyDir (if needed for transient inter-container demonstration)
   - Do NOT use Services, Deployments, ReplicaSets, DaemonSets, PersistentVolumes, hostPath volumes, or any scheduling primitives (nodeSelector, affinity, taints, tolerations)
   - Do NOT use probes or lifecycle hooks
   - Do NOT use resource requests or limits
   - Do NOT use init containers unless absolutely necessary for a specific demonstration (prefer single-container pods)
   - Container images should be small and fast: `busybox`, `alpine`, `nginx:1.25`, `nginx:1.25-alpine` are preferred. Use specific tags, never `latest`.
   - For exercises that need to display env vars or file contents, use `busybox` or `alpine` with a command like `sh -c 'env; cat /etc/config/*; sleep 3600'` so the learner can inspect via `kubectl logs` and `kubectl exec`

6. **File Format**
   - Output FOUR separate Markdown files:
     - `README.md` - Overview of all files and how to use them
     - `pod-config-injection-tutorial.md` - Complete tutorial
     - `pod-config-injection-homework.md` - 15 progressive exercises only
     - `pod-config-injection-homework-answers.md` - Complete solutions
   - Use proper Markdown syntax with fenced code blocks and language tags (bash, yaml)
   - Each file should be self-contained
   - README.md should include:
     - Brief description of what each file contains
     - Recommended workflow (tutorial → homework → answers)
     - Difficulty level progression explanation
     - Prerequisites needed (kind cluster with nerdctl, CKA sections completed, Assignment 1 completed)
     - Estimated time commitment
     - A note that this is Assignment 2 in a pod series, with a brief list of the other planned assignments so the learner knows what's coming
   - homework.md should include:
     - Brief introduction referencing the tutorial file
     - Exercise setup commands section at the start (cluster verification, optional global cleanup)
     - All 15 exercises organized by difficulty level
     - Cleanup section at the end (per-namespace and full)
     - "Key Takeaways" section summarizing important concepts, including the env-var-vs-volume update propagation distinction, the base64-not-encrypted reality of Secrets, and the imperative shortcuts for creating ConfigMaps and Secrets quickly
   - tutorial.md should teach ONE complete real-world workflow end-to-end (recommend: build a pod that represents a realistic web application with app config from a ConfigMap, database credentials from a Secret, runtime pod metadata from the downward API, all combined into a projected volume, plus a few env vars for values that are expected to be stable)
     - Include a "Reference Commands" section at the end with imperative and declarative examples for ConfigMap creation, Secret creation, and all four injection patterns
     - Include a "base64 Encoding Reference" section showing `base64 -w0` for encoding and `base64 -d` for decoding
     - Include an "Injection Pattern Decision Table" showing when to use env vars vs envFrom vs volume mounts vs projected volumes
     - This serves as a quick reference while doing exercises
   - answers.md should include solutions for all 15 exercises
     - Answer key headings should use "Exercise X.Y Solution" format (no descriptive titles needed, since answers don't spoil)

7. **Answer Key Requirements**
   - File: pod-config-injection-homework-answers.md
   - Include complete solutions for all exercises
   - Show both imperative and declarative approaches where both are reasonable; for projected volumes and complex multi-source configs, declarative is the only realistic approach and that should be stated
   - For debugging exercises, explain what was wrong, why it caused the observed failure, and how you'd diagnose it from kubectl output (describe, logs, get pod/configmap/secret -o yaml, exec to inspect)
   - Include a "Common Mistakes" section covering:
     - `data` vs `stringData` confusion in Secrets (data requires base64, stringData doesn't)
     - Forgetting `base64 -w0` and getting line-wrapped output that breaks Secret YAML
     - `configMapRef` vs `configMapKeyRef` (one is for envFrom bulk, one is for single env var)
     - Volume mount shadowing an existing directory vs using subPath
     - Expecting env vars to pick up ConfigMap updates (they don't, you need to restart the pod)
     - Items path requiring a relative path, not starting with /
     - Immutable ConfigMaps/Secrets needing deletion and recreation, not updates
     - Case sensitivity in key names
   - Include a "Verification Commands Cheat Sheet" with the most useful kubectl commands for inspecting ConfigMaps, Secrets, and their consumption inside pods

8. **Quality Standards**
   - No conflicts between tutorial and exercises (different namespaces, resource names)
   - All commands must be copy-paste ready with no manual substitution required
   - Verification commands should be specific (check the actual env var value inside the container, check file contents, check file permissions, check that a key exists in a ConfigMap) not vague ("check if it works")
   - Exercises should build practical muscle memory for the CKA performance exam, where creating and consuming ConfigMaps and Secrets quickly under time pressure is a core skill
   - Tutorial should teach ONE complete real-world workflow end-to-end
   - No em dashes anywhere in output (use commas, periods, or parentheses)
   - Use narrative paragraph flow in prose explanations, not stacked single-sentence declarations
   - Full replacement files, no patches or diffs
   - Always use `base64 -w0` for encoding Secret values, never `tr -d '\n'`

Please create the homework assignment for Pod Configuration Injection.
Generate all four files: README.md, pod-config-injection-tutorial.md, pod-config-injection-homework.md, and pod-config-injection-homework-answers.md
