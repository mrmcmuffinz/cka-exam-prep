I need you to create a comprehensive Kubernetes homework assignment to help me practice **Cluster Upgrades and Maintenance**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S6 (through lecture 142, covering Core Concepts, Scheduling, Logging & Monitoring, Application Lifecycle Management, and Cluster Maintenance)
- I have completed cluster-lifecycle/assignment-1 (Cluster Installation)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers cluster version upgrades using kubeadm, node maintenance operations (drain, cordon, uncordon), and post-upgrade verification. Cluster installation (kubeadm init/join) is assumed knowledge from assignment-1. etcd backup/restore and HA control plane configuration are covered in assignment-3 and MUST NOT appear here.

**In scope for this assignment:**

*Upgrade Planning*
- Understanding Kubernetes version skew policy (kubelet can be one minor version behind API server, kubectl can be one version ahead or behind)
- kubeadm upgrade plan: what it checks, how to interpret output
- Determining current cluster version (kubectl version, kubeadm version)
- Checking available upgrade versions
- Understanding that upgrades must be sequential (1.29 -> 1.30 -> 1.31, cannot skip minor versions)

*Control Plane Node Upgrade Workflow*
- Upgrading kubeadm package first (apt-get or yum)
- Running kubeadm upgrade plan to verify upgrade path
- Running kubeadm upgrade apply v1.X.Y on the first control plane node
- What kubeadm upgrade apply does: upgrades static pod manifests, upgrades cluster configuration
- Draining the control plane node before upgrading kubelet
- Upgrading kubelet and kubectl packages
- Restarting kubelet after package upgrade
- Uncordoning the control plane node

*Worker Node Upgrade Workflow*
- Draining the worker node (workloads move to other nodes)
- Upgrading kubeadm package on the worker
- Running kubeadm upgrade node (not kubeadm upgrade apply)
- Upgrading kubelet and kubectl packages
- Restarting kubelet
- Uncordoning the worker node
- Verifying workloads have been rescheduled

*Node Drain Operations*
- kubectl drain: what it does (evicts pods, cordons node)
- Understanding drain flags: --ignore-daemonsets (required for nodes with DaemonSet pods), --delete-emptydir-data (for pods using emptyDir), --force (for pods not managed by controllers)
- What happens to pods during drain: ReplicaSet/Deployment pods are recreated elsewhere, standalone pods are deleted
- PodDisruptionBudgets and how they affect drain operations
- Drain failures: pods that cannot be evicted, how to diagnose

*Node Cordon and Uncordon*
- kubectl cordon: marks node as unschedulable, does not evict existing pods
- kubectl uncordon: marks node as schedulable again
- When to use cordon vs drain (maintenance types)
- Verifying node scheduling status (kubectl get nodes, SchedulingDisabled taint)

*Post-Upgrade Verification*
- Verifying all control plane components are running the new version
- Verifying all nodes are Ready and running the correct kubelet version
- Verifying cluster functionality (can create and schedule pods)
- Checking for deprecated API versions in existing resources
- Verifying workload health after upgrade

**Out of scope (covered in other assignments, do not include):**

- kubeadm init and join workflows (exercises/cluster-lifecycle/assignment-1)
- Node prerequisites and preparation (exercises/cluster-lifecycle/assignment-1)
- CNI installation (exercises/cluster-lifecycle/assignment-1)
- etcd backup and restore (exercises/cluster-lifecycle/assignment-3)
- HA control plane configuration (exercises/cluster-lifecycle/assignment-3)
- TLS certificate management (exercises/tls-and-certificates/)
- RBAC configuration (exercises/rbac/)
- Detailed troubleshooting of upgrade failures (exercises/troubleshooting/assignment-2)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: cluster-lifecycle-tutorial.md (append to existing or create section 2)
   - Explain the Kubernetes version skew policy and why sequential upgrades are required
   - Walk through a complete control plane upgrade workflow
   - Walk through a complete worker node upgrade workflow
   - Demonstrate drain, cordon, and uncordon with real examples
   - Explain PodDisruptionBudgets and their impact on drains
   - Show post-upgrade verification steps
   - Note kind limitations (cannot actually upgrade kind clusters in place)
   - Use tutorial-cluster-lifecycle namespace where applicable

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: cluster-lifecycle-homework.md (separate from assignment-1)
   - 15 exercises across 5 difficulty levels (3 exercises per level)
   - Each exercise is self-contained with setup commands and verification commands

   **Level 1 (Exercises 1.1-1.3): Version Information and Planning**
   - Check current cluster version using multiple methods
   - Understand and interpret kubeadm upgrade plan output (conceptual, examine documentation)
   - Identify version skew between components

   **Level 2 (Exercises 2.1-2.3): Node Maintenance Operations**
   - Cordon a node and verify pods are not scheduled to it
   - Drain a node with --ignore-daemonsets and verify pod eviction
   - Uncordon a node and verify scheduling resumes

   **Level 3 (Exercises 3.1-3.3): Debugging Drain Issues**
   - Three debugging exercises with pods that resist drain
   - Exercise headings are bare (### Exercise 3.1) with no descriptive titles
   - Scenarios: standalone pod blocking drain, emptyDir pod blocking drain, PDB preventing eviction

   **Level 4 (Exercises 4.1-4.3): Upgrade Workflow Simulation**
   - Trace a control plane upgrade workflow by examining documentation and commands
   - Create a runbook for upgrading a multi-node cluster
   - Verify post-upgrade component versions

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Exercise 5.1: Rolling node maintenance (drain and uncordon nodes one at a time while maintaining workload availability)
   - Exercise 5.2: Handle drain failure due to PDB (adjust PDB or workload to allow drain)
   - Exercise 5.3: Complete upgrade verification checklist for handoff documentation

3. **Answer Key File**
   - Create the answer key: cluster-lifecycle-homework-answers.md
   - Full solutions for all 15 exercises with explanations
   - Common mistakes section covering:
     - Forgetting --ignore-daemonsets on drain (fails due to DaemonSet pods)
     - Not understanding that drain also cordons the node
     - Trying to drain a node with standalone pods without --force
     - Skipping kubeadm upgrade node on workers (using apply instead)
     - Not restarting kubelet after package upgrade
   - Verification commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of the Cluster Upgrades and Maintenance assignment
   - Prerequisites: cluster-lifecycle/assignment-1
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: multi-node kind cluster
   - Note about kind limitations for actual upgrades
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Multi-node kind cluster (1 control-plane, 2-3 workers)
- Workloads (Deployments) to demonstrate drain behavior
- kubectl client

RESOURCE GATE:
This assignment uses a restricted resource gate (generation order 2):
- Pods, ReplicaSets, Deployments, DaemonSets
- ConfigMaps, Secrets
- Namespaces, ServiceAccounts
- Roles, RoleBindings
- Nodes (inspection and cordon/drain)
- PodDisruptionBudgets
- Do NOT use: Services, Ingress, PersistentVolumes, NetworkPolicies, ClusterRoles

KIND CLUSTER NOTE:
Kind clusters cannot be upgraded in place. The tutorial and exercises should:
- Explain the actual kubeadm upgrade workflow conceptually
- Focus hands-on exercises on drain/cordon/uncordon operations (fully functional in kind)
- Use documentation examination and runbook creation for upgrade-specific exercises
- Clearly distinguish which exercises are hands-on vs. conceptual

CONVENTIONS:
- No em dashes anywhere. Use commas, periods, or parentheses.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Debugging exercise headings are bare.
- Container images use explicit version tags.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/cluster-lifecycle/assignment-1: Cluster installation fundamentals

- **Follow-up assignments:**
  - exercises/cluster-lifecycle/assignment-3: etcd operations and HA control plane
  - exercises/troubleshooting/assignment-2: Control plane troubleshooting (failed upgrades)
  - exercises/troubleshooting/assignment-3: Node troubleshooting

COURSE MATERIAL REFERENCE:
This assignment aligns with Mumshad CKA course sections:
- S6 (Lectures 130-132): OS upgrades, drain, cordon, uncordon
- S6 (Lectures 133-137): Kubernetes version upgrades with kubeadm
