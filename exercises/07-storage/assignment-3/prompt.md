I need you to create a comprehensive Kubernetes homework assignment to help me practice **StorageClasses and Dynamic Provisioning**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed 07-storage/assignment-1 and assignment-2
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers StorageClass resources, dynamic provisioning workflows, default StorageClass, volume expansion, and binding modes. PV and PVC fundamentals are assumed knowledge from assignments 1 and 2.

**In scope for this assignment:**

*StorageClass Resources*
- apiVersion: storage.k8s.io/v1, kind: StorageClass
- metadata.name: StorageClass identifier
- provisioner: which CSI driver or in-tree provisioner
- parameters: provisioner-specific configuration
- reclaimPolicy: Default reclaim policy for dynamically provisioned PVs
- allowVolumeExpansion: whether PVCs can be resized
- volumeBindingMode: Immediate vs WaitForFirstConsumer

*Dynamic Provisioning Workflow*
- PVC references StorageClass by name
- Provisioner creates PV automatically
- PV is bound to PVC immediately
- No manual PV creation required
- Provisioner manages underlying storage

*Default StorageClass*
- storageclass.kubernetes.io/is-default-class: "true" annotation
- PVCs without storageClassName use default
- Only one default per cluster (or undefined behavior)
- How to change default StorageClass
- kind's default: rancher.io/local-path provisioner

*StorageClass Parameters*
- Provisioner-specific settings
- Common parameters: type, fsType, zone
- Cloud provider parameters (conceptual)
- local-path provisioner parameters in kind

*Volume Expansion*
- allowVolumeExpansion: true in StorageClass
- Editing PVC to request more storage
- Controller resizes PV
- Filesystem resize (may require pod restart)
- Not all provisioners support expansion

*VolumeBindingMode*
- Immediate: PV created and bound immediately
- WaitForFirstConsumer: PV created when pod using PVC is scheduled
- Why WaitForFirstConsumer matters (zone awareness, node affinity)
- Observing delayed binding behavior

**Out of scope (covered in other assignments, do not include):**

- PV creation in depth (exercises/07-07-storage/assignment-1)
- PVC binding mechanics (exercises/07-07-storage/assignment-2)
- CSI driver installation (cluster setup, not exercise)
- Cloud-specific storage configuration
- Snapshot and clone features (advanced, may not be in CKA)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: storage-tutorial.md (section 3)
   - Explain StorageClass purpose and structure
   - Demonstrate dynamic provisioning with kind's local-path
   - Show default StorageClass behavior
   - Explain volume expansion
   - Explain binding modes and their implications
   - Use tutorial-storage namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: storage-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): StorageClass Basics**
   - List StorageClasses in the cluster
   - Identify the default StorageClass
   - Create PVC using default StorageClass

   **Level 2 (Exercises 2.1-2.3): Dynamic Provisioning**
   - Create PVC and observe automatic PV creation
   - Use dynamically provisioned volume in pod
   - Compare static vs dynamic provisioning

   **Level 3 (Exercises 3.1-3.3): Debugging StorageClass Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: PVC pending no provisioner, wrong StorageClass name, provisioner not installed

   **Level 4 (Exercises 4.1-4.3): Advanced Configuration**
   - Create custom StorageClass
   - Configure volume expansion
   - Test WaitForFirstConsumer binding mode

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Exercise 5.1: Change default StorageClass
   - Exercise 5.2: Expand a PVC and verify
   - Exercise 5.3: Design storage strategy with multiple StorageClasses

3. **Answer Key File**
   - Create the answer key: storage-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Non-existent StorageClass name in PVC
     - Expecting expansion without allowVolumeExpansion
     - Multiple default StorageClasses
     - WaitForFirstConsumer with no pod (PVC stays Pending)
     - Provisioner not available in cluster
   - StorageClass commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of StorageClasses and Dynamic Provisioning assignment
   - Prerequisites: 07-storage/assignment-1, assignment-2
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster (has local-path provisioner)
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- Kind's default local-path provisioner
- kubectl client

RESOURCE GATE:
This assignment uses a restricted resource gate (generation order 16):
- Pods, Deployments
- PersistentVolumes, PersistentVolumeClaims
- StorageClasses
- Namespaces
- Do NOT use: Services, Ingress, NetworkPolicies

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-storage`.
- Debugging exercise headings are bare.
- Container images use explicit version tags.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/07-07-storage/assignment-1: PersistentVolumes
  - exercises/07-07-storage/assignment-2: PersistentVolumeClaims

- **Follow-up assignments:**
  - exercises/13-13-security-contexts/assignment-1: fsGroup affects mounted volume permissions
  - exercises/19-19-troubleshooting/assignment-1: Storage-related troubleshooting

COURSE MATERIAL REFERENCE:
- S8 (Lectures 201-203): Storage classes
