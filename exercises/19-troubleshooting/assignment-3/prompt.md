I need you to create a comprehensive Kubernetes homework assignment to help me practice **Node and Kubelet Troubleshooting**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed cluster-lifecycle assignments
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers node and kubelet troubleshooting: node NotReady, kubelet failures, container runtime issues, node conditions, and node recovery. Application and control plane troubleshooting are covered in assignments 1 and 2. Network troubleshooting is covered in assignment-4.

**In scope for this assignment:**

*Node NotReady Diagnosis*
- kubectl describe node: conditions and events
- Node conditions: Ready, MemoryPressure, DiskPressure, PIDPressure
- Taints applied by conditions
- Identifying root cause from conditions

*Kubelet Not Running*
- systemctl status kubelet
- journalctl -u kubelet
- Kubelet configuration issues
- Certificate issues preventing kubelet startup
- Container runtime not available

*Container Runtime Issues*
- Container runtime not running
- containerd status and logs
- Runtime configuration issues
- Image pull failures at runtime level

*Node Conditions*
- MemoryPressure: node running low on memory
- DiskPressure: node running low on disk
- PIDPressure: node running low on PIDs
- NetworkUnavailable: node network not configured
- How conditions affect scheduling

*Taints from Node Conditions*
- Automatic taints applied by node problems
- node.kubernetes.io/not-ready
- node.kubernetes.io/unreachable
- node.kubernetes.io/memory-pressure
- node.kubernetes.io/disk-pressure

*Node Drain and Recovery*
- Draining unhealthy node
- Recovering node to Ready state
- Uncordoning after recovery
- Pod rescheduling after recovery

*Kubelet Configuration Issues*
- Kubelet config file location
- Common misconfigurations
- Registration failures
- Node labels and annotations

**Out of scope (covered in other assignments, do not include):**

- Application troubleshooting (exercises/19-19-troubleshooting/assignment-1)
- Control plane troubleshooting (exercises/19-19-troubleshooting/assignment-2)
- Network troubleshooting (exercises/19-19-troubleshooting/assignment-4)
- Node drain for upgrades (exercises/17-17-cluster-lifecycle/assignment-2)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: troubleshooting-tutorial.md (section 3)
   - Explain node architecture and kubelet role
   - Show NotReady diagnosis workflow
   - Demonstrate kubelet troubleshooting
   - Explain node conditions and taints
   - Cover recovery procedures
   - Note kind-specific behavior

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: troubleshooting-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)
   - All exercises are debugging exercises
   - Exercise headings are bare (### Exercise 1.1, etc.)

   **Level 1 (Exercises 1.1-1.3): Node Status**
   - Check node conditions
   - Identify NotReady node
   - View node events

   **Level 2 (Exercises 2.1-2.3): Kubelet Issues**
   - Check kubelet status
   - View kubelet logs
   - Identify kubelet configuration issue

   **Level 3 (Exercises 3.1-3.3): Node Failures**
   - Node with memory pressure
   - Node with disk pressure
   - Container runtime issue

   **Level 4 (Exercises 4.1-4.3): Recovery**
   - Drain and recover node
   - Fix kubelet configuration
   - Verify node recovery

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Multiple node issues
   - Node causing workload failures
   - Full node recovery procedure

3. **Answer Key File**
   - Create the answer key: troubleshooting-homework-answers.md
   - Full diagnostic workflow for each exercise
   - Node troubleshooting flowcharts
   - Common mistakes in diagnosis

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Node and Kubelet Troubleshooting assignment
   - Prerequisites: cluster-lifecycle
   - Estimated time commitment: 6-8 hours
   - Cluster requirements: multi-node kind cluster
   - Kind limitations note
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Multi-node kind cluster (3+ workers to safely drain)
- Access to node containers via nerdctl exec
- kubectl client

KIND CLUSTER NOTE:
Kind nodes are containers, not VMs or bare-metal. Kubelet runs inside the kind container. Some exercises may be conceptual or require kind-specific approaches. Clearly identify differences from real clusters.

RESOURCE GATE:
All CKA resources are in scope (generation order 37):
- All Kubernetes resources
- Node access
- Kubelet and runtime

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-troubleshooting`.
- ALL exercise headings are bare.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/17-cluster-lifecycle/ assignments

- **Follow-up assignments:**
  - exercises/19-19-troubleshooting/assignment-4: Network troubleshooting

COURSE MATERIAL REFERENCE:
- S14 (Lectures 292-294): Worker node failure
