# Storage

**CKA Domain:** Storage (10%)
**Competencies covered:** Implement storage classes and dynamic volume provisioning,
configure volume types/access modes/reclaim policies, manage PVs and PVCs

---

## Why One Assignment

The Storage domain covers PersistentVolumes, PersistentVolumeClaims, StorageClasses,
dynamic provisioning, access modes, and reclaim policies. The subtopic count is
roughly 12 areas. While storage is conceptually layered (volumes, then PV/PVC binding,
then StorageClasses, then dynamic provisioning), the layers are tightly coupled and
the exam domain weight is only 10%. A single assignment provides enough depth to
cover all three CKA competencies with room for binding-mismatch debugging exercises
and multi-pod shared storage scenarios.

---

## Assignments

| Assignment | Title | Covers | Prerequisites |
|---|---|---|---|
| assignment-1 | Persistent Storage | Volume types (emptyDir, hostPath, PVC), PV spec, PVC spec, PV-to-PVC binding mechanics, using PVCs in pod specs, access modes (RWO, ROX, RWX, RWOP), reclaim policies (Retain, Delete), StorageClass resources, dynamic provisioning, default StorageClass, volume expansion | None |

## Scope Boundaries

This topic covers persistent data in Kubernetes. The following related areas are
handled by other topics:

- **ConfigMap and Secret volumes** (in-memory, not persistent): covered in `pods/assignment-2`
- **emptyDir for inter-container sharing** (ephemeral): covered in `pods/assignment-6`
- **fsGroup and volume permissions**: covered in `security-contexts/assignment-1`
- **StatefulSets** (controllers with stable storage identity): not currently in scope for CKA assignments, may be added if exam coverage warrants it

## Cluster Requirements

Single-node kind cluster. Kind includes a default `standard` StorageClass with the
`rancher.io/local-path` provisioner, which is sufficient for dynamic provisioning
exercises. No special configuration needed.

## Recommended Order

No strict prerequisites. The assignment can be generated any time after the Storage
course section (S8) is complete. Familiarity with pod specs (pods/assignment-1) and
volume mounts (pods/assignment-2) is assumed but not gated.
