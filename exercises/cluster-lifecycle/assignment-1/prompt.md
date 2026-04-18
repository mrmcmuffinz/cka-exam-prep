I need you to create a comprehensive Kubernetes homework assignment to help me practice **Cluster Installation with kubeadm**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S6 (through lecture 142, covering Core Concepts, Scheduling, Logging & Monitoring, Application Lifecycle Management, and Cluster Maintenance)
- I have completed all pod assignments (1-7) and rbac/assignment-1
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers cluster installation using kubeadm, including node prerequisites, the kubeadm init and join workflows, control plane component verification, and conceptual understanding of extension interfaces (CNI, CSI, CRI). TLS certificates, cluster upgrades, and etcd operations are covered in subsequent assignments and MUST NOT appear here beyond what is necessary to verify a successful installation.

**In scope for this assignment:**

*Node Prerequisites and Preparation*
- Container runtime requirements (containerd as the standard CKA runtime)
- Networking prerequisites (unique hostname, MAC, product_uuid per node)
- Required ports for control plane (6443, 2379-2380, 10250-10252) and workers (10250, 30000-32767)
- Swap disabled requirement and why Kubernetes requires it
- Kernel modules (br_netfilter, overlay) and sysctl settings (net.bridge.bridge-nf-call-iptables, net.ipv4.ip_forward)
- Installing kubeadm, kubelet, and kubectl packages

*kubeadm init Workflow*
- kubeadm init command and essential flags (--pod-network-cidr, --apiserver-advertise-address, --control-plane-endpoint)
- kubeadm configuration files as an alternative to command-line flags
- What kubeadm init does: generates certificates, creates static pod manifests, bootstraps etcd, starts control plane components
- Understanding the init output: kubeconfig setup instructions, join command with token
- Post-init tasks: copying admin.conf to user kubeconfig, applying CNI plugin

*kubeadm join Workflow*
- kubeadm join command structure (control plane endpoint, token, ca-cert-hash)
- How the bootstrap token authenticates the joining node
- What kubeadm join does on a worker node: starts kubelet, registers node with API server
- Regenerating join tokens when they expire (kubeadm token create --print-join-command)

*Control Plane Component Verification*
- Verifying API server, scheduler, and controller-manager are running (kubectl get pods -n kube-system)
- Understanding static pod manifests in /etc/kubernetes/manifests/
- Verifying kubelet status on each node (systemctl status kubelet, journalctl -u kubelet)
- Verifying node registration (kubectl get nodes, node conditions)
- Verifying cluster DNS is running (CoreDNS deployment in kube-system)

*Extension Interfaces (Conceptual)*
- CNI (Container Network Interface): what it abstracts (pod networking), why it is required, common implementations (Calico, Cilium, Flannel, Weave)
- CSI (Container Storage Interface): what it abstracts (persistent storage provisioning), how provisioners implement it
- CRI (Container Runtime Interface): what it abstracts (container lifecycle), containerd as the standard runtime
- Understanding that these are plugin interfaces, not components to configure directly in this assignment

*Cluster Health Checks*
- kubectl cluster-info for API server and CoreDNS endpoints
- kubectl get componentstatuses (deprecated but may still appear on exam)
- kubectl get nodes to verify all nodes are Ready
- Basic troubleshooting: node NotReady, kubelet not running, CNI not installed

**Out of scope (covered in other assignments, do not include):**

- TLS certificate creation, viewing, or management (exercises/tls-and-certificates/assignment-1)
- Certificates API for user certificates (exercises/tls-and-certificates/assignment-2)
- Certificate troubleshooting (exercises/tls-and-certificates/assignment-3)
- Cluster version upgrades with kubeadm upgrade (exercises/cluster-lifecycle/assignment-2)
- Node drain, cordon, uncordon operations (exercises/cluster-lifecycle/assignment-2)
- etcd backup and restore (exercises/cluster-lifecycle/assignment-3)
- HA control plane configuration (exercises/cluster-lifecycle/assignment-3)
- RBAC configuration (exercises/rbac/). This assignment uses cluster-admin access.
- Network Policies (exercises/network-policies/). CNI installation is in scope, but policy configuration is not.
- Detailed troubleshooting of control plane failures (exercises/troubleshooting/assignment-2)
- Detailed troubleshooting of node failures (exercises/troubleshooting/assignment-3)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: cluster-lifecycle-tutorial.md
   - Explain what kubeadm does and why it is the standard cluster bootstrap tool for CKA
   - Walk through node prerequisites with explanations of why each is required
   - Demonstrate kubeadm init on a control plane node (conceptually, since kind abstracts this)
   - Demonstrate kubeadm join for worker nodes
   - Show how to verify all control plane components are running
   - Explain the role of CNI and show how to apply a CNI plugin (Calico or Flannel)
   - Include commands to inspect kubeadm artifacts within kind nodes (docker exec or nerdctl exec into kind containers)
   - Use a dedicated tutorial namespace where applicable (tutorial-cluster-lifecycle)
   - Include cleanup commands at the end of each major section

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: cluster-lifecycle-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)
   - Each exercise is self-contained with setup commands and verification commands
   - Every exercise uses its own namespace where applicable: ex-1-1, ex-1-2, etc.

   **Level 1 (Exercises 1.1-1.3): Exploring kubeadm Artifacts**
   - Examine static pod manifests in /etc/kubernetes/manifests/ (exec into kind control-plane container)
   - Inspect kubeadm configuration and certificates directory structure
   - Verify control plane component pods are running and healthy

   **Level 2 (Exercises 2.1-2.3): Node and Cluster Verification**
   - Check node prerequisites (kernel modules, sysctl settings) within kind nodes
   - Verify kubelet configuration and status
   - Use kubectl to verify cluster health (nodes, component status, DNS)

   **Level 3 (Exercises 3.1-3.3): Debugging Cluster Issues**
   - Three debugging exercises with broken or misconfigured scenarios
   - Exercise headings are bare (### Exercise 3.1) with no descriptive titles to avoid spoilers
   - Scenarios: node not Ready, kubelet not running, CNI not installed (simulate by examining symptoms)

   **Level 4 (Exercises 4.1-4.3): kubeadm Configuration and Tokens**
   - Generate and inspect kubeadm configuration files
   - Work with bootstrap tokens (create, list, delete)
   - Understand kubeadm phases (init phase breakdown)

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Exercise 5.1: Trace a complete kubeadm init workflow by examining artifacts
   - Exercise 5.2: Simulate adding a new worker node (generate join command, understand the process)
   - Exercise 5.3: Verify and document the complete cluster state for handoff

3. **Answer Key File**
   - Create the answer key: cluster-lifecycle-homework-answers.md
   - Full solutions for all 15 exercises with explanations
   - For debugging exercises, include diagnostic workflow
   - Common mistakes section covering:
     - Forgetting to apply CNI after kubeadm init (nodes stay NotReady)
     - Token expiration (default 24 hours) and how to regenerate
     - Swap enabled causing kubelet to refuse to start
     - Firewall blocking required ports
     - Missing kernel modules or sysctl settings
   - Verification commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of the Cluster Installation assignment and its place in the CKA exam prep series
   - Prerequisites: pods/assignment-7, rbac/assignment-1
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: multi-node kind cluster (1 control-plane, 2-3 workers)
   - Note about kind abstracting kubeadm (exercises use exec to examine artifacts)
   - Recommended workflow: read tutorial, work exercises, compare with answers
   - Link to the homework plan for context

ENVIRONMENT REQUIREMENTS:
- Multi-node kind cluster (1 control-plane, 2-3 workers)
- No special CNI requirements (default kindnet is sufficient for most exercises)
- kubectl client and nerdctl for exec into kind containers
- Exercises examine kubeadm artifacts but do not actually run kubeadm (kind manages this)

RESOURCE GATE:
This assignment uses a restricted resource gate (generation order 1, before Networking section):
- Pods, ReplicaSets, Deployments, DaemonSets
- ConfigMaps, Secrets
- Namespaces, ServiceAccounts
- Roles, RoleBindings (namespace-scoped only)
- Nodes (read-only inspection)
- Do NOT use: Services, Ingress, PersistentVolumes, NetworkPolicies, ClusterRoles

KIND CLUSTER SETUP:
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
```

Create the cluster with:
```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster --config kind-multi-node.yaml
```

KIND CLUSTER NOTE:
Kind abstracts kubeadm operations. Learners cannot run kubeadm init/join directly, but they can examine the artifacts kubeadm created:
- Static pod manifests in /etc/kubernetes/manifests/ (accessible via nerdctl exec)
- Certificates in /etc/kubernetes/pki/
- kubeadm configuration used to bootstrap the cluster
- kubelet configuration and status

The tutorial and exercises should clearly explain this abstraction and show how to use nerdctl exec to explore kubeadm artifacts within kind nodes.

CONVENTIONS:
- No em dashes anywhere in generated content. Use commas, periods, or parentheses.
- Narrative paragraph flow in prose sections, not stacked single-sentence bullet points.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-cluster-lifecycle`.
- Debugging exercise headings are bare (### Exercise 3.1) with no descriptive titles.
- Container images use explicit version tags: nginx:1.25, busybox:1.36
- Full file replacements when generating, never patches or diffs.

CROSS-REFERENCES:
- **Prerequisites (must be completed first):**
  - exercises/pods/assignment-7 (Workload Controllers): Understanding Deployments and DaemonSets helps understand control plane components
  - exercises/rbac/assignment-1 (RBAC namespace-scoped): Understanding ServiceAccounts and RBAC for verifying permissions

- **Follow-up assignments:**
  - exercises/cluster-lifecycle/assignment-2: Cluster upgrades and maintenance operations
  - exercises/cluster-lifecycle/assignment-3: etcd operations and HA control plane
  - exercises/tls-and-certificates/assignment-1: TLS fundamentals and certificate creation

COURSE MATERIAL REFERENCE:
This assignment aligns with Mumshad CKA course sections:
- S2 (Lectures 6-17): Cluster architecture, etcd, API server, scheduler, kubelet, kube-proxy
- S6 (Lectures 130-132): OS upgrades, drain, cordon (introduction only, details in assignment-2)
- S10 (Lectures 241-244): Cluster design, infrastructure choices
- S11 (Lectures 246-251): kubeadm init, join, cluster deployment
