# Storage

**CKA Domain:** Storage (10%)
**Competencies covered:** Implement storage classes and dynamic volume provisioning, configure volume types/access modes/reclaim policies, manage persistent volumes and persistent volume claims

---

## Rationale for Number of Assignments

Persistent storage in Kubernetes encompasses volume types, PersistentVolumes, PersistentVolumeClaims, binding mechanics, access modes, reclaim policies, StorageClasses, and dynamic provisioning. This produces roughly 16-18 distinct subtopics. The material splits naturally into three focused progressions: PersistentVolume creation and lifecycle, PersistentVolumeClaim binding with access modes and reclaim policies, and StorageClass-driven dynamic provisioning. Each assignment delivers 5-6 subtopics at depth, building from static provisioning through binding mechanics to fully automated dynamic workflows.

---

## Assignment Summary

| Assignment | Description | Prerequisites |
|---|---|---|
| assignment-1 | Volumes and PersistentVolumes | Volume types overview (emptyDir, hostPath, PVC), PersistentVolume spec (capacity, accessModes, persistentVolumeReclaimPolicy), PV lifecycle phases (Available, Bound, Released, Failed), static PV provisioning, PV label selectors and node affinity, inspecting PVs | None |
| assignment-2 | PersistentVolumeClaims and Binding | PVC spec (resources.requests.storage, accessModes, storageClassName), PV-to-PVC binding mechanics (capacity, access mode, storage class matching), using PVCs in pod specs, access modes (ReadWriteOnce, ReadOnlyMany, ReadWriteMany, ReadWriteOncePod), reclaim policies (Retain, Delete), troubleshooting binding failures | 07-storage/assignment-1 |
| assignment-3 | StorageClasses and Dynamic Provisioning | StorageClass resources and provisioner field, dynamic provisioning workflow, default StorageClass annotation, StorageClass parameters and provisioner-specific options, volume expansion (allowVolumeExpansion), VolumeBindingMode (Immediate vs WaitForFirstConsumer) | 07-storage/assignment-2 |

## Scope Boundaries

This topic covers persistent data in Kubernetes. The following related areas are handled by other topics:

- **ConfigMap and Secret volumes** (in-memory, not persistent): covered in `01-pods/assignment-2`
- **emptyDir for inter-container sharing** (ephemeral, not persistent): covered in `01-pods/assignment-6`
- **fsGroup and volume permissions** (security contexts affecting mounted volumes): covered in `13-security-contexts/assignment-1`
- **StatefulSets** (controllers with stable storage identity): covered in `statefulsets/`

Assignment-1 focuses on PersistentVolume resources and static provisioning. Assignment-2 focuses on PVC binding and consumption. Assignment-3 focuses on StorageClass automation and dynamic provisioning.

## Cluster Requirements

Single-node kind cluster for all three assignments. Kind includes a default `standard` StorageClass with the `rancher.io/local-path` provisioner, which is sufficient for dynamic provisioning exercises in assignment-3. No special configuration needed.

## Recommended Order

1. No strict prerequisites, though familiarity with pod specs (01-pods/assignment-1) and volume mounts (01-pods/assignment-2) is assumed
2. Work through assignments 1, 2, 3 sequentially
3. Assignment-2 assumes understanding of PV structure from assignment-1
4. Assignment-3 assumes understanding of PV/PVC binding mechanics from assignments 1 and 2
5. This series can be generated any time after the Storage course section (S8) is complete
