I need you to create a comprehensive Kubernetes homework assignment to help me practice **Volumes and PersistentVolumes**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S8 (through Storage)
- I have completed 01-pods/assignment-1 and 01-pods/assignment-2 (pod specs and volumes)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers volume types, PersistentVolume resources, static provisioning, and PV lifecycle. PersistentVolumeClaims and binding mechanics are covered in assignment-2. StorageClasses and dynamic provisioning are covered in assignment-3.

**In scope for this assignment:**

*Volume Types Overview*
- emptyDir: ephemeral, pod-lifetime, shared between containers
- hostPath: maps directory from node, persists beyond pod but tied to node
- PersistentVolumeClaim: references external storage via PVC
- configMap and secret: projected configuration (covered in pods series, reference only)
- Other types (conceptual): nfs, iscsi, cephfs, cloud provider volumes

*PersistentVolume Spec*
- apiVersion: v1, kind: PersistentVolume
- spec.capacity.storage: size declaration (Gi, Mi, Ti)
- spec.accessModes: ReadWriteOnce, ReadOnlyMany, ReadWriteMany, ReadWriteOncePod
- spec.persistentVolumeReclaimPolicy: Retain, Delete, Recycle (deprecated)
- spec.storageClassName: links to StorageClass (or empty for static provisioning)
- spec.hostPath (for kind exercises), spec.nfs, spec.local (for different backends)

*PV Lifecycle Phases*
- Available: PV is ready and not bound to any PVC
- Bound: PV is bound to a PVC
- Released: PVC deleted but PV not yet reclaimed
- Failed: automatic reclamation failed
- Understanding phase transitions

*Static PV Provisioning*
- Creating PVs manually before PVCs exist
- Matching PVs to PVCs (size, access mode, storage class)
- When static provisioning is appropriate
- Pre-provisioning storage for specific workloads

*PV Label Selectors and Node Affinity*
- Labels on PVs for selective binding
- spec.nodeAffinity for local volumes
- Ensuring PV is on same node as pod (local volumes)
- Using labels to match specific PVs

*Inspecting PVs*
- kubectl get pv: listing all PersistentVolumes
- kubectl describe pv: detailed information
- Understanding PV status and events
- Identifying why PV is in specific phase

**Out of scope (covered in other assignments, do not include):**

- PersistentVolumeClaims (exercises/07-07-storage/assignment-2)
- PVC binding mechanics (exercises/07-07-storage/assignment-2)
- StorageClasses (exercises/07-07-storage/assignment-3)
- Dynamic provisioning (exercises/07-07-storage/assignment-3)
- ConfigMap and Secret volumes in depth (exercises/01-01-pods/assignment-2)
- fsGroup and volume permissions (exercises/13-13-security-contexts/assignment-1)
- StatefulSets (not in current CKA scope)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: storage-tutorial.md
   - Explain volume types and when to use each
   - Walk through PersistentVolume creation
   - Explain each field in PV spec
   - Demonstrate PV lifecycle phases
   - Show static provisioning workflow
   - Use tutorial-storage namespace where applicable

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: storage-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Basic Volume Types**
   - Create a pod with emptyDir volume
   - Create a pod with hostPath volume
   - Verify volume mounts and data persistence

   **Level 2 (Exercises 2.1-2.3): PersistentVolume Creation**
   - Create a PV with hostPath backend
   - Create a PV with specific access mode
   - List and describe PVs

   **Level 3 (Exercises 3.1-3.3): Debugging PV Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: PV stuck in Released, invalid capacity, wrong access mode

   **Level 4 (Exercises 4.1-4.3): PV Configuration**
   - Configure PV with node affinity
   - Set up PV with labels for selective binding
   - Configure reclaim policies

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Exercise 5.1: Design PV strategy for multi-node application
   - Exercise 5.2: Diagnose PV not becoming Available
   - Exercise 5.3: Pre-provision PVs for specific workloads

3. **Answer Key File**
   - Create the answer key: storage-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - hostPath not existing on node
     - Access mode not matching workload requirements
     - Reclaim policy misunderstanding (Retain keeps data, Delete removes it)
     - Local volume without node affinity
     - Capacity format errors
   - PV commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Volumes and PersistentVolumes assignment
   - Prerequisites: 01-pods/assignment-1, 01-pods/assignment-2
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- hostPath access via kind node
- kubectl client

RESOURCE GATE:
This assignment uses a restricted resource gate (generation order 14):
- Pods with volumes
- PersistentVolumes
- Namespaces
- Do NOT use: Services, Ingress, NetworkPolicies, PersistentVolumeClaims (covered in assignment-2)

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
  - exercises/01-01-pods/assignment-1: Pod fundamentals
  - exercises/01-01-pods/assignment-2: Volume mounts

- **Follow-up assignments:**
  - exercises/07-07-storage/assignment-2: PersistentVolumeClaims and binding
  - exercises/07-07-storage/assignment-3: StorageClasses and dynamic provisioning

COURSE MATERIAL REFERENCE:
- S8 (Lectures 193-198): Volumes, PersistentVolumes, PersistentVolumeClaims
