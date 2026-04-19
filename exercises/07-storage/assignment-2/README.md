# Assignment 2: PersistentVolumeClaims and Binding

This is the second of three Storage assignments, covering PersistentVolumeClaims and the mechanics of PV-to-PVC binding. Assignment 1 covered the PV side (what the storage provider declares). Assignment 2 covers the consumer side (how a pod requests storage) and the binding algorithm that pairs the two. Assignment 3 covers StorageClasses and dynamic provisioning, which automates the PV side.

## Files

| File | Purpose |
|---|---|
| `prompt.md` | The generation prompt (input to the homework generator skill) |
| `README.md` | This overview |
| `storage-tutorial.md` | Step-by-step tutorial teaching PVC spec fields, binding mechanics, and reclaim policies |
| `storage-homework.md` | 15 progressive exercises across five difficulty levels |
| `storage-homework-answers.md` | Complete solutions with diagnostic reasoning and common mistakes |

## Recommended Workflow

Work through the tutorial first. It opens with a minimal PVC that binds to a matching PV, then walks through every PVC spec field with its valid values, defaults, and failure modes. The middle section exercises the binding algorithm by deliberately producing mismatches: capacity mismatch, access-mode mismatch, StorageClass mismatch, label selector mismatch. Each failure produces a Pending PVC that the reader diagnoses by reading the events. The tutorial closes with reclaim policy testing: delete a PVC and observe what happens to a `Retain` PV vs. a `Delete` PV. The homework then exercises each piece. Level 3 debugging scenarios are the core of the assignment and assume you can read describe output for both the PV and the PVC to identify which field disagrees.

## Difficulty Progression

Level 1 is PVC basics: create a PVC that binds, mount a PVC in a pod, list and inspect PVCs. Level 2 focuses on binding algorithm details: request specific capacity (round-up behavior), use label selectors to steer which PV binds, pair access modes correctly. Level 3 is debugging binding failures: PVC Pending because the PV's capacity is too small, PVC Pending because of an access mode mismatch, PVC Pending because of a StorageClass name mismatch. Level 4 is reclaim and lifecycle: test `Retain` behavior, test `Delete` behavior, reuse a `Released` PV. Level 5 is complex scenarios: multiple pods claiming the same storage (where access mode really matters), compound debugging with more than one mismatch, and design of a PVC strategy for a stateful application.

## Prerequisites

Complete `exercises/07-07-storage/assignment-1` first. This assignment assumes you can author a PV spec and understand the five PV lifecycle phases. The exercises build PVs alongside PVCs; if you have not internalized the PV side, the binding logic will feel mysterious.

## Cluster Requirements

A single-node kind cluster is sufficient. See `docs/cluster-setup.md#single-node-kind-cluster` for the creation command. No additional components are required. All PVs in this assignment are static and `hostPath`- or `local`-backed.

## Estimated Time Commitment

The tutorial takes 45 to 60 minutes. The 15 exercises together take four to six hours. Level 1 runs 10 to 15 minutes per exercise; Level 2 runs 15 to 20 minutes; Level 3 debugging runs 15 to 25 minutes per exercise because diagnosing a binding failure involves reading both the PV and the PVC describe output; Level 4 runs 20 to 30 minutes per exercise; Level 5 runs 30 to 45 minutes per exercise.

## Scope Boundary and What Comes Next

This assignment covers PVC creation, the binding algorithm, and reclaim-policy behavior. StorageClasses (which automate PV creation via a provisioner) are covered in `exercises/07-07-storage/assignment-3`. StatefulSet volume claim templates (which create one PVC per replica automatically) are `exercises/03-03-statefulsets/assignment-1`. `fsGroup` and file ownership on mounted volumes are `exercises/13-13-security-contexts/assignment-1`. Storage-related troubleshooting cross-referenced from other domains is in `exercises/19-troubleshooting/`.

## Key Takeaways After Completing This Assignment

After finishing all 15 exercises you should be able to author a PVC spec with correct `resources.requests.storage`, `accessModes`, `storageClassName`, and (when needed) `selector` or `volumeName`, read a PVC stuck in `Pending` and identify which of the five binding-criteria fields (capacity, access modes, storage class, selector, `volumeName`) is the mismatch, mount a PVC in a pod via `spec.volumes[*].persistentVolumeClaim.claimName`, describe what happens to a PV in `Retain` vs `Delete` vs `Recycle` after the PVC is deleted, use `spec.volumeName` or `spec.selector` to steer which PV binds to a PVC, reuse a `Released` PV by removing its `spec.claimRef`, and choose access modes (`RWO`, `ROX`, `RWX`, `RWOP`) based on how many pods and nodes need simultaneous access.
