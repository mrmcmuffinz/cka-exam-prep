I need you to create a comprehensive Kubernetes homework assignment to help me practice **PersistentVolumeClaims and Binding**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed storage/assignment-1 (Volumes and PersistentVolumes)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers PVC creation, binding mechanics, using PVCs in pods, access modes, and reclaim policies. PV creation is assumed knowledge from assignment-1. StorageClasses and dynamic provisioning are covered in assignment-3.

**In scope for this assignment:**

*PVC Spec*
- apiVersion: v1, kind: PersistentVolumeClaim
- spec.resources.requests.storage: requested size
- spec.accessModes: list of required access modes
- spec.storageClassName: specifies which StorageClass (or empty string for static binding)
- spec.selector: label selector for specific PVs (optional)
- spec.volumeName: bind to specific PV by name (optional)

*PV-to-PVC Binding Mechanics*
- How Kubernetes matches PVCs to PVs
- Capacity matching: PV capacity must be >= PVC request
- Access mode matching: PV must support all PVC access modes
- StorageClass matching: must match (including both empty)
- Label selector matching: PV labels must match PVC selector
- Binding is exclusive: one PVC per PV

*Using PVCs in Pod Specs*
- volumes section: referencing PVC by name
- volumeMounts section: mounting PVC in container
- Multiple pods using same PVC (depends on access mode)
- Pod scheduling with PVC (pod scheduled to node with PV)

*Access Modes*
- ReadWriteOnce (RWO): single node read-write
- ReadOnlyMany (ROX): many nodes read-only
- ReadWriteMany (RWX): many nodes read-write
- ReadWriteOncePod (RWOP): single pod read-write
- Access mode implications for pod scheduling

*Reclaim Policies*
- Retain: PV becomes Released, data preserved, manual cleanup
- Delete: PV and underlying storage deleted when PVC deleted
- Recycle (deprecated): basic scrub, no longer recommended
- Changing reclaim policy on existing PV

*Troubleshooting Binding Failures*
- PVC stuck in Pending: no matching PV
- Capacity mismatch: requested > available
- Access mode mismatch: incompatible modes
- StorageClass mismatch: different or missing class
- PV already bound: exclusive binding
- Label selector not matching

**Out of scope (covered in other assignments, do not include):**

- PV creation in depth (exercises/storage/assignment-1)
- Volume types (exercises/storage/assignment-1)
- StorageClasses (exercises/storage/assignment-3)
- Dynamic provisioning (exercises/storage/assignment-3)
- Volume expansion (exercises/storage/assignment-3)
- fsGroup (exercises/security-contexts/assignment-1)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: storage-tutorial.md (section 2)
   - Explain PVC structure and each field
   - Walk through PVC creation and binding
   - Demonstrate using PVCs in pods
   - Explain access modes and their implications
   - Show troubleshooting techniques for binding failures
   - Use tutorial-storage namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: storage-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Basic PVC Operations**
   - Create a PVC and verify it binds to a PV
   - Mount PVC in a pod
   - List and describe PVCs

   **Level 2 (Exercises 2.1-2.3): Binding Mechanics**
   - Create PVC with specific size requirements
   - Create PVC with label selector
   - Observe binding with different access modes

   **Level 3 (Exercises 3.1-3.3): Debugging Binding Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: PVC pending due to capacity, access mode mismatch, storage class mismatch

   **Level 4 (Exercises 4.1-4.3): Reclaim and Lifecycle**
   - Test Retain reclaim policy
   - Test Delete reclaim policy
   - Reuse Released PV (manual intervention)

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Exercise 5.1: Multi-pod access to shared storage
   - Exercise 5.2: Debug complex binding failure
   - Exercise 5.3: Design PVC strategy for stateful application

3. **Answer Key File**
   - Create the answer key: storage-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Requesting more storage than PV has
     - Expecting RWO to work on multiple nodes
     - Not understanding Released state
     - Missing storageClassName (defaults to cluster default)
     - Using volumeName without matching labels
   - PVC commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of PersistentVolumeClaims and Binding assignment
   - Prerequisites: storage/assignment-1
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- PVs created for exercises
- kubectl client

RESOURCE GATE:
This assignment uses a restricted resource gate (generation order 15):
- Pods, Deployments
- PersistentVolumes, PersistentVolumeClaims
- Namespaces
- Do NOT use: Services, Ingress, NetworkPolicies, StorageClasses (covered in assignment-3)

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
  - exercises/storage/assignment-1: PersistentVolumes

- **Follow-up assignments:**
  - exercises/storage/assignment-3: StorageClasses and dynamic provisioning

COURSE MATERIAL REFERENCE:
- S8 (Lectures 193-198): Volumes, PersistentVolumes, PersistentVolumeClaims
