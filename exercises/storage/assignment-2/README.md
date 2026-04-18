# Storage Assignment 2: PersistentVolumeClaims and Binding

This assignment covers PVC creation, binding mechanics, using PVCs in pods, access modes, and reclaim policies. PV creation from assignment-1 is assumed knowledge. StorageClasses and dynamic provisioning are covered in assignment-3.

## Prerequisites

Before starting this assignment, you should have completed:

- exercises/storage/assignment-1 (Volumes and PersistentVolumes)

## Estimated Time

4-6 hours for tutorial and all exercises.

## Cluster Requirements

This assignment uses a single-node kind cluster with no special configuration required.

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

## What You Will Learn

This assignment teaches PersistentVolumeClaims and binding:

- **PVC spec** including resources, accessModes, and selectors
- **Binding mechanics** between PVCs and PVs
- **Using PVCs in pods** as volumes
- **Access modes** and their implications
- **Reclaim policies** and their effects

## Difficulty Progression

**Level 1 (Basic PVC Operations):** Create PVCs, verify binding, mount in pods.

**Level 2 (Binding Mechanics):** Capacity matching, label selectors, access modes.

**Level 3 (Debugging Binding Issues):** Diagnose capacity, access mode, and storage class mismatches.

**Level 4 (Reclaim and Lifecycle):** Test Retain and Delete policies, reuse Released PVs.

**Level 5 (Complex Scenarios):** Multi-pod access, complex binding, PVC strategy design.

## Files in This Directory

| File | Description |
|------|-------------|
| `prompt.md` | The generation prompt used to create this assignment |
| `README.md` | This overview file |
| `storage-tutorial.md` | Step-by-step tutorial on PVCs and binding |
| `storage-homework.md` | 15 progressive exercises |
| `storage-homework-answers.md` | Complete solutions with explanations |
