# Storage Assignment 1: Volumes and PersistentVolumes

This assignment covers volume types, PersistentVolume resources, static provisioning, and PV lifecycle. You will learn how to create and manage PersistentVolumes, understand different volume types, and work with PV lifecycle phases.

## Prerequisites

Before starting this assignment, you should have completed:

- exercises/pods/assignment-1 (Pod fundamentals)
- exercises/pods/assignment-2 (Volume mounts)

You should be comfortable creating pods with volumes.

## Estimated Time

4-6 hours for tutorial and all exercises.

## Cluster Requirements

This assignment uses a single-node kind cluster with no special configuration required.

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

## What You Will Learn

This assignment teaches volume types and PersistentVolumes:

- **Volume types** including emptyDir, hostPath, and PersistentVolumeClaim
- **PersistentVolume spec** including capacity, accessModes, and reclaimPolicy
- **PV lifecycle phases** (Available, Bound, Released, Failed)
- **Static provisioning** where PVs are created before PVCs
- **Node affinity** for local volumes

## Difficulty Progression

**Level 1 (Basic Volume Types):** Create pods with emptyDir and hostPath volumes.

**Level 2 (PV Creation):** Create PersistentVolumes with different configurations.

**Level 3 (Debugging PV Issues):** Diagnose PVs stuck in Released, invalid capacity, wrong access modes.

**Level 4 (PV Configuration):** Configure node affinity, labels, reclaim policies.

**Level 5 (Complex Scenarios):** Design PV strategies, diagnose availability issues.

## Recommended Workflow

1. Read the tutorial file to understand volumes and PersistentVolumes
2. Complete the exercises in order, as later exercises build on earlier concepts
3. Try each exercise before checking the answer key
4. Compare your solutions with the answer key to learn alternative approaches

## Files in This Directory

| File | Description |
|------|-------------|
| `prompt.md` | The generation prompt used to create this assignment |
| `README.md` | This overview file |
| `storage-tutorial.md` | Step-by-step tutorial on volumes and PersistentVolumes |
| `storage-homework.md` | 15 progressive exercises |
| `storage-homework-answers.md` | Complete solutions with explanations |
