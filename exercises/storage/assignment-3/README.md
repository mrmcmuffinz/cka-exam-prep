# Storage Assignment 3: StorageClasses and Dynamic Provisioning

This assignment covers StorageClass resources, dynamic provisioning workflows, default StorageClass, volume expansion, and binding modes. PV and PVC fundamentals from assignments 1 and 2 are assumed knowledge.

## Prerequisites

Before starting this assignment, you should have completed:

- exercises/storage/assignment-1 (PersistentVolumes)
- exercises/storage/assignment-2 (PersistentVolumeClaims)

## Estimated Time

4-6 hours for tutorial and all exercises.

## Cluster Requirements

This assignment uses a single-node kind cluster. Kind includes a default StorageClass with the rancher.io/local-path provisioner.

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

## What You Will Learn

This assignment teaches StorageClasses and dynamic provisioning:

- **StorageClass resources** and their configuration
- **Dynamic provisioning** workflow
- **Default StorageClass** behavior
- **Volume expansion** with allowVolumeExpansion
- **Binding modes** (Immediate vs WaitForFirstConsumer)

## Difficulty Progression

**Level 1 (StorageClass Basics):** List StorageClasses, identify default, create PVCs with default.

**Level 2 (Dynamic Provisioning):** Create PVC and observe automatic PV creation.

**Level 3 (Debugging Issues):** Diagnose provisioner errors, wrong class names.

**Level 4 (Advanced Configuration):** Create custom StorageClass, configure expansion, test binding modes.

**Level 5 (Complex Scenarios):** Change default StorageClass, expand PVCs, design storage strategy.

## Files in This Directory

| File | Description |
|------|-------------|
| `prompt.md` | The generation prompt used to create this assignment |
| `README.md` | This overview file |
| `storage-tutorial.md` | Step-by-step tutorial on StorageClasses |
| `storage-homework.md` | 15 progressive exercises |
| `storage-homework-answers.md` | Complete solutions with explanations |
