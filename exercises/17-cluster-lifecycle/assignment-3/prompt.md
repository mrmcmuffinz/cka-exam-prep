I need you to create a comprehensive Kubernetes homework assignment to help me practice **etcd Operations and High Availability**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S6 (through lecture 142)
- I have completed 17-cluster-lifecycle/assignment-1 and assignment-2
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers etcd architecture, backup and restore operations using etcdctl, etcd health verification, and conceptual understanding of HA control plane topologies. Cluster installation and upgrades are assumed knowledge from assignments 1 and 2. Certificate management for etcd is covered in tls-and-certificates and should only be referenced here as needed for etcdctl authentication.

**In scope for this assignment:**

*etcd Architecture in Kubernetes*
- etcd's role as the cluster state store (all cluster data, resource definitions, secrets)
- Single etcd instance vs. etcd cluster (quorum requirements: 2n+1 for n failures)
- Stacked etcd topology (etcd runs on control plane nodes as static pods)
- External etcd topology (etcd runs on dedicated nodes, separate from control plane)
- etcd data directory location (/var/lib/etcd)

*etcd Backup with etcdctl*
- etcdctl snapshot save command and required flags
- Required authentication: --cacert, --cert, --key (paths to etcd certificates)
- Finding etcd certificate paths from static pod manifest or etcd configuration
- Verifying backup integrity with etcdctl snapshot status
- Backup file contents and portability
- Scheduling backups (conceptual, cron-based approach)

*etcd Restore with etcdctl*
- etcdctl snapshot restore command and required flags
- --data-dir flag to specify new data directory
- Why restore creates a new cluster (new cluster ID, new member IDs)
- Post-restore steps: update etcd static pod manifest to point to new data directory
- Restarting etcd after restore
- Verifying cluster state after restore

*etcd Health and Data Integrity*
- etcdctl endpoint health command
- etcdctl endpoint status for cluster state information
- etcdctl member list for cluster membership
- Diagnosing etcd issues: connection refused, authentication failures, quorum loss
- Understanding etcd performance metrics (conceptual)

*HA Control Plane Concepts*
- Stacked HA topology: multiple control plane nodes, each running etcd, API server, scheduler, controller manager
- External etcd HA topology: dedicated etcd cluster, control plane nodes without etcd
- Load balancer requirement for API server HA
- Leader election for scheduler and controller manager (only one active at a time)
- etcd quorum requirements for HA (3 nodes tolerate 1 failure, 5 nodes tolerate 2 failures)

*HA Configuration (Conceptual)*
- kubeadm init with --control-plane-endpoint for HA
- Joining additional control plane nodes
- Why external etcd might be preferred (separate failure domains, dedicated resources)
- Trade-offs between stacked and external topologies

**Out of scope (covered in other assignments, do not include):**

- kubeadm init and join basic workflows (exercises/17-17-cluster-lifecycle/assignment-1)
- Cluster upgrades (exercises/17-17-cluster-lifecycle/assignment-2)
- Node drain and maintenance (exercises/17-17-cluster-lifecycle/assignment-2)
- TLS certificate creation and management (exercises/18-tls-and-certificates/). Only reference certificate paths for etcdctl authentication.
- Detailed etcd troubleshooting for corrupted data (exercises/19-19-troubleshooting/assignment-2)
- API server, scheduler, controller manager troubleshooting (exercises/19-19-troubleshooting/assignment-2)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: cluster-lifecycle-tutorial.md (append section 3)
   - Explain etcd's role and architecture
   - Demonstrate etcd backup with etcdctl (accessing etcd in kind via exec)
   - Demonstrate etcd restore workflow (conceptual steps for restore)
   - Show etcd health verification commands
   - Explain HA topologies with diagrams (text-based)
   - Use tutorial-cluster-lifecycle namespace where applicable

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: cluster-lifecycle-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): etcd Exploration**
   - Locate etcd static pod manifest and identify certificate paths
   - Connect to etcd and verify cluster health
   - List etcd cluster members

   **Level 2 (Exercises 2.1-2.3): Backup Operations**
   - Create an etcd snapshot backup
   - Verify backup integrity with snapshot status
   - Document backup procedure as a runbook

   **Level 3 (Exercises 3.1-3.3): Debugging etcd Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: wrong certificate paths, endpoint not reachable, authentication failure

   **Level 4 (Exercises 4.1-4.3): Restore Operations**
   - Restore etcd from a backup (conceptual, document the workflow)
   - Understand restore implications (new cluster ID)
   - Verify cluster state after conceptual restore

   **Level 5 (Exercises 5.1-5.3): HA Concepts and Complex Scenarios**
   - Exercise 5.1: Design an HA cluster topology (document decisions)
   - Exercise 5.2: Complete backup and restore runbook for production
   - Exercise 5.3: Disaster recovery scenario planning

3. **Answer Key File**
   - Create the answer key: cluster-lifecycle-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Wrong certificate paths for etcdctl
     - Forgetting ETCDCTL_API=3 environment variable
     - Not specifying --data-dir on restore
     - Restoring to the same data directory (overwrites existing data)
     - Not updating static pod manifest after restore
   - etcdctl commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of etcd Operations and HA assignment
   - Prerequisites: 17-cluster-lifecycle/assignment-1, assignment-2
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: multi-node kind cluster
   - Note about kind limitations for HA exercises
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Multi-node kind cluster (1 control-plane, 2-3 workers)
- etcdctl installed or accessible via kind exec
- ETCDCTL_API=3 environment variable

RESOURCE GATE:
This assignment uses a restricted resource gate (generation order 3):
- All resources from assignments 1 and 2
- etcd access via etcdctl
- Do NOT use: Services, Ingress, PersistentVolumes, NetworkPolicies

KIND CLUSTER NOTE:
Kind runs etcd as a container within the control-plane container. Backup exercises work via exec into the kind container. Restore exercises are largely conceptual because modifying the etcd data directory in kind requires careful container manipulation. HA exercises are entirely conceptual since kind does not support multi-control-plane configurations with true HA.

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Debugging exercise headings are bare.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/17-17-cluster-lifecycle/assignment-1: Cluster installation
  - exercises/17-17-cluster-lifecycle/assignment-2: Cluster maintenance

- **Follow-up assignments:**
  - exercises/18-18-tls-and-certificates/assignment-1: Certificate management (etcd certs)
  - exercises/19-19-troubleshooting/assignment-2: Control plane troubleshooting (etcd failures)

COURSE MATERIAL REFERENCE:
- S2 (Lectures 6-17): etcd architecture introduction
- S6 (Lectures 138-142): etcd backup and restore
- S10 (Lectures 241-244): HA cluster design, etcd in HA
