# Assignment 1: Volumes and PersistentVolumes

This is the first of three Storage assignments, covering volume types and the PersistentVolume resource. The focus is on the storage-provider side of the PV-PVC binding relationship: what a PV declares, which lifecycle phases it passes through, how static provisioning works, and when to use labels and node affinity to guide binding. Assignment 2 covers the consumer side (PersistentVolumeClaims, binding mechanics, reclaim behavior) and assignment 3 covers StorageClasses and dynamic provisioning.

## Files

| File | Purpose |
|---|---|
| `prompt.md` | The generation prompt (input to the homework generator skill) |
| `README.md` | This overview |
| `storage-tutorial.md` | Step-by-step tutorial teaching volume types, PV spec fields, and static provisioning |
| `storage-homework.md` | 15 progressive exercises across five difficulty levels |
| `storage-homework-answers.md` | Complete solutions with diagnostic reasoning and common mistakes |

## Recommended Workflow

Work through the tutorial end to end first. It starts with the three volume types a CKA candidate must own (`emptyDir`, `hostPath`, and `persistentVolumeClaim`), then walks through PV creation field by field with every spec field's valid values, default, and failure mode documented. The second half demonstrates the five PV lifecycle phases by driving a PV through `Available`, `Bound`, and `Released` and observing each transition. Only then attempt the homework. Level 3 debugging exercises assume you can read `kubectl describe pv` output to identify why a PV is not in the expected phase.

## Difficulty Progression

Level 1 practices the three volume types: a pod with `emptyDir`, a pod with `hostPath`, and a verification round where data persistence is observed and compared. Level 2 introduces PersistentVolume creation itself: a `hostPath`-backed PV, a PV with a specific access mode, and PV inspection. Level 3 is debugging PVs: a PV stuck in `Released` that cannot rebind, a PV with invalid capacity format, and a PV whose access mode does not match the only available PVC. Level 4 is realistic configuration: PV with node affinity, PV with label selector for binding control, and reclaim-policy choice. Level 5 is design and comprehensive debugging: design PVs for a multi-node application, diagnose a PV that will not become `Available`, and pre-provision PVs for a specific workload set.

## Prerequisites

Complete `exercises/01-01-pods/assignment-1` (pod fundamentals) and `exercises/01-01-pods/assignment-2` (volume mounts). This assignment assumes you can author a pod spec with volume mounts; it adds the PV resource on top and does not reteach volume-mount syntax.

## Cluster Requirements

A single-node kind cluster is sufficient for all exercises. See `docs/cluster-setup.md#single-node-kind-cluster` for the creation command. Some Level 4 and Level 5 exercises use `hostPath` on the kind node; the paths are created and removed by the exercise setup blocks. No CNI, CSI, or storage-provider installation is required beyond kind's default `rancher.io/local-path` provisioner (which is not used by this assignment; dynamic provisioning is covered in assignment 3).

## Estimated Time Commitment

The tutorial takes 45 to 60 minutes. The 15 exercises together take four to six hours. Level 1 runs 10 minutes per exercise; Level 2 runs 15 to 20 minutes; Level 3 debugging runs 15 to 25 minutes per exercise because the failure modes (stuck phases, capacity parse errors, access-mode mismatches) each require reading the PV events; Level 4 runs 20 to 30 minutes; Level 5 runs 30 to 45 minutes per exercise.

## Scope Boundary and What Comes Next

This assignment covers PersistentVolumes and volume types only. PersistentVolumeClaims (which consume PVs) are covered in `exercises/07-07-storage/assignment-2`. StorageClasses and dynamic provisioning are covered in `exercises/07-07-storage/assignment-3`. StatefulSets (which use `volumeClaimTemplates` to request PVCs automatically) live in `exercises/03-03-statefulsets/assignment-1`. `fsGroup` and volume permissions are `exercises/13-13-security-contexts/assignment-1`. The CSI driver install and write-your-own-provisioner topics are outside the CKA scope and are not exercised in this repo.

## Key Takeaways After Completing This Assignment

After finishing all 15 exercises you should be able to choose between `emptyDir`, `hostPath`, and `persistentVolumeClaim` based on the data's lifetime and portability requirements, author a PersistentVolume spec end to end with the right `capacity`, `accessModes`, `persistentVolumeReclaimPolicy`, and backend fields, explain the five PV lifecycle phases and what triggers transitions between them, diagnose a PV stuck in `Available` or `Released` by reading its describe output, use labels on PVs combined with PVC selectors to steer binding, use `spec.nodeAffinity` on a local-volume PV to pin it to a specific node, and identify when static provisioning is the right choice (shared storage pre-provisioned by an administrator) versus when dynamic provisioning (assignment 3) is preferred.
