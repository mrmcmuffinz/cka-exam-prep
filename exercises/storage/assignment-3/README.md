# Assignment 3: StorageClasses and Dynamic Provisioning

This is the final Storage assignment. Assignment 1 covered PersistentVolumes (the storage offer). Assignment 2 covered PersistentVolumeClaims and the binding algorithm (the storage request and how the two pair). This assignment covers StorageClass resources and dynamic provisioning, the machinery that eliminates the "someone pre-creates every PV manually" pattern from assignments 1 and 2. In kind, the `rancher.io/local-path` provisioner is available by default; this assignment uses it throughout rather than installing a CSI driver.

## Files

| File | Purpose |
|---|---|
| `prompt.md` | The generation prompt (input to the homework generator skill) |
| `README.md` | This overview |
| `storage-tutorial.md` | Step-by-step tutorial teaching StorageClass spec fields, dynamic provisioning, binding modes, and volume expansion |
| `storage-homework.md` | 15 progressive exercises across five difficulty levels |
| `storage-homework-answers.md` | Complete solutions with diagnostic reasoning and common mistakes |

## Recommended Workflow

Work through the tutorial first. It starts by listing every StorageClass in the cluster and identifying the default via the `storageclass.kubernetes.io/is-default-class` annotation. Then it walks through StorageClass spec fields one by one with valid values, defaults, and failure modes. The middle section demonstrates dynamic provisioning: apply a PVC with no matching PV; the provisioner creates a PV automatically; the PVC binds. The tutorial then switches binding modes (`Immediate` vs `WaitForFirstConsumer`), tests volume expansion (`allowVolumeExpansion`), and shows how to change the default StorageClass. The homework then practices each piece. Level 3 debugging scenarios assume you can read the PVC events to distinguish between "no matching PV" and "provisioner not running" failures.

## Difficulty Progression

Level 1 is discovery and basics: list StorageClasses, identify the default, create a PVC using the default. Level 2 is dynamic provisioning mechanics: apply a PVC and watch the PV appear, use a dynamically provisioned volume in a pod, compare static vs dynamic. Level 3 is debugging: a non-existent StorageClass name, a PVC that was never provisioned because the provisioner is not running (simulated by scaling the provisioner down), and a storage-class mismatch where the PVC names a wrong class. Level 4 is advanced configuration: create a custom StorageClass, configure volume expansion, test `WaitForFirstConsumer` mode. Level 5 is comprehensive: change the default StorageClass on the cluster, expand an existing PVC and verify, design a multi-class storage strategy for a three-tier application.

## Prerequisites

Complete `exercises/storage/assignment-1` (PVs) and `exercises/storage/assignment-2` (PVCs and binding). This assignment assumes you can author PVs and PVCs and can diagnose a `Pending` PVC from describe output. The new material is the StorageClass resource and the provisioner-driven workflow.

## Cluster Requirements

A single-node kind cluster is sufficient. See `docs/cluster-setup.md#single-node-kind-cluster` for the creation command. Kind ships with a default StorageClass named `standard` backed by `rancher.io/local-path`; this provisioner creates PVs by writing to `/var/local-path-provisioner/<pv-id>/` on the node. No additional components are needed for this assignment.

## Estimated Time Commitment

The tutorial takes 45 to 60 minutes. The 15 exercises together take four to six hours. Level 1 runs 10 minutes per exercise; Level 2 runs 15 to 20 minutes; Level 3 debugging runs 15 to 25 minutes per exercise because identifying "provisioner down" vs "class mismatch" requires reading events and looking at the provisioner pod; Level 4 runs 20 to 30 minutes per exercise, with the expansion exercises requiring a pod restart to see the filesystem-level resize; Level 5 runs 30 to 45 minutes per exercise.

## Scope Boundary and What Comes Next

This assignment covers StorageClass resources, dynamic provisioning with kind's local-path provisioner, volume expansion, and binding modes. CSI driver installation and authoring custom provisioners are out of scope for the CKA and are not exercised. Snapshot, clone, and quota primitives are beyond CKA scope. StatefulSet volume-claim templates (which combine dynamic provisioning with per-replica PVCs) are `exercises/statefulsets/assignment-1`. Security-context interactions with dynamically provisioned volumes (`fsGroup` on the PVC-mounted volume) are `exercises/security-contexts/assignment-1`. Troubleshooting dynamically provisioned storage from a pod-centric angle is part of `exercises/troubleshooting/assignment-1`.

## Key Takeaways After Completing This Assignment

After finishing all 15 exercises you should be able to list StorageClasses and identify the default, author a StorageClass with a specific `provisioner`, `parameters`, `reclaimPolicy`, `volumeBindingMode`, and `allowVolumeExpansion`, create a PVC that triggers dynamic provisioning and read the resulting PV out of the cluster, distinguish between `Immediate` and `WaitForFirstConsumer` binding modes and explain when each is appropriate, expand a PVC (using a StorageClass with `allowVolumeExpansion: true`) and verify the resize propagated to the underlying filesystem, change the default StorageClass without accidentally creating multiple defaults, debug a PVC Pending because of a wrong StorageClass name or an absent provisioner, and choose between static provisioning (assignments 1 and 2) and dynamic provisioning (this assignment) based on the operational model.
