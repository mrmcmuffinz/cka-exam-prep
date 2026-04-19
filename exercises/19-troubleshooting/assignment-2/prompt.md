I need you to create a comprehensive Kubernetes homework assignment to help me practice **Control Plane Troubleshooting**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed cluster-lifecycle and tls-and-certificates assignments
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers control plane component failures: API server, scheduler, controller manager, and etcd issues. Application troubleshooting is covered in assignment-1. Node and kubelet issues are covered in assignment-3. Network issues are covered in assignment-4.

**In scope for this assignment:**

*API Server Failures*
- Static pod manifest errors in /etc/kubernetes/manifests/
- Certificate issues (expired, wrong CA, wrong subject)
- Port conflicts
- Configuration errors in kube-apiserver.yaml
- API server not responding

*Scheduler Failures*
- Scheduler not running
- Scheduler misconfigured
- Pods stuck in Pending (scheduler issue vs resource issue)
- Scheduler logs analysis

*Controller Manager Failures*
- Controller manager not running
- RBAC issues preventing reconciliation
- Controller manager logs
- Resources not being reconciled

*etcd Failures*
- etcd not running
- etcd connectivity issues
- etcd authentication failures
- etcd data corruption (symptoms)
- etcd cluster quorum loss

*Static Pod Manifest Debugging*
- Location: /etc/kubernetes/manifests/
- YAML syntax errors
- Image tag issues
- Volume mount errors
- Resource specification errors

*Certificate Expiration and Verification*
- Checking certificate expiration
- Certificate subject mismatches
- CA verification
- kubeadm certs check-expiration

*Control Plane Component Logs*
- kubectl logs for kube-system pods
- crictl logs for static pods (when kubectl unavailable)
- journalctl for system services
- Log analysis patterns

**Out of scope (covered in other assignments, do not include):**

- Application troubleshooting (exercises/19-19-troubleshooting/assignment-1)
- Node and kubelet issues (exercises/19-19-troubleshooting/assignment-3)
- Network troubleshooting (exercises/19-19-troubleshooting/assignment-4)
- etcd backup/restore (exercises/17-17-cluster-lifecycle/assignment-3)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: troubleshooting-tutorial.md (section 2)
   - Explain control plane architecture
   - Show how to diagnose each component
   - Demonstrate static pod manifest debugging
   - Show certificate verification
   - Cover log analysis
   - Use tutorial-troubleshooting namespace where applicable

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: troubleshooting-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)
   - All exercises are debugging exercises
   - Exercise headings are bare (### Exercise 1.1, etc.)

   **Level 1 (Exercises 1.1-1.3): Component Status**
   - Verify control plane components running
   - Check component logs
   - Identify failed component

   **Level 2 (Exercises 2.1-2.3): Static Pod Issues**
   - Find syntax error in manifest
   - Fix image tag issue
   - Correct volume mount error

   **Level 3 (Exercises 3.1-3.3): Component Failures**
   - API server not starting
   - Scheduler not running
   - Controller manager failure

   **Level 4 (Exercises 4.1-4.3): Certificate Issues**
   - Expired certificate diagnosis
   - Wrong CA verification
   - Certificate renewal

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Multiple control plane issues
   - etcd connectivity problem
   - Full control plane recovery

3. **Answer Key File**
   - Create the answer key: troubleshooting-homework-answers.md
   - Full diagnostic workflow for each exercise
   - Control plane debugging flowcharts
   - Common mistakes in diagnosis

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Control Plane Troubleshooting assignment
   - Prerequisites: cluster-lifecycle, tls-and-certificates
   - Estimated time commitment: 6-8 hours
   - Cluster requirements: multi-node kind cluster
   - Kind limitations note
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Multi-node kind cluster
- Access to control plane container via nerdctl exec
- kubectl and crictl

KIND CLUSTER NOTE:
Kind runs control plane components as containers within the kind node container. Some exercises may be conceptual or require different approaches than bare-metal clusters. Clearly identify kind-specific workarounds.

RESOURCE GATE:
All CKA resources are in scope (generation order 36):
- All Kubernetes resources
- Control plane component access
- Static pod manifests
- Certificates

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
  - exercises/18-tls-and-certificates/ assignments

- **Follow-up assignments:**
  - exercises/19-19-troubleshooting/assignment-3: Node troubleshooting
  - exercises/19-19-troubleshooting/assignment-4: Network troubleshooting

COURSE MATERIAL REFERENCE:
- S14 (Lectures 289-291): Control plane failure
- S6 (Lectures 138-142): etcd
- S7 (Lectures 146-159): Certificates
