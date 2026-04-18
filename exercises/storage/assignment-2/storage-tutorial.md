# Storage Tutorial: PersistentVolumeClaims and Binding

## Introduction

A PersistentVolumeClaim (PVC) is a request for storage by a user. PVCs consume PV resources just as pods consume node resources. This tutorial covers how to create PVCs, understand binding mechanics, and use PVCs in pods.

## Prerequisites

You need a running kind cluster:

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

## Setup

Create a namespace and some PVs to work with:

```bash
kubectl create namespace tutorial-storage
kubectl config set-context --current --namespace=tutorial-storage

# Create PVs for the tutorial
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-1gi
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/pv-1gi
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-5gi
spec:
  capacity:
    storage: 5Gi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Delete
  storageClassName: ""
  hostPath:
    path: /tmp/pv-5gi
EOF
```

## PVC Spec Structure

A PVC specifies:

| Field | Description |
|-------|-------------|
| resources.requests.storage | Minimum storage required |
| accessModes | Required access modes |
| storageClassName | StorageClass to use (empty for static) |
| selector | Label selector for specific PVs |
| volumeName | Bind to specific PV by name |

## Creating a PVC

Create a simple PVC:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-claim
  namespace: tutorial-storage
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: ""
EOF
```

Check the PVC status:

```bash
kubectl get pvc my-claim
```

The PVC should be Bound to pv-1gi.

## Binding Mechanics

Kubernetes matches PVCs to PVs based on:

1. **Capacity:** PV capacity >= PVC request
2. **Access Modes:** PV supports all PVC access modes
3. **StorageClass:** Must match (including both empty)
4. **Labels:** PV labels match PVC selector (if specified)
5. **Volume Name:** If specified, only that PV matches

Check what PV was bound:

```bash
kubectl get pvc my-claim -o jsonpath='{.spec.volumeName}'
```

## Using PVCs in Pods

Mount a PVC in a pod:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pvc-pod
  namespace: tutorial-storage
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo 'Hello' > /data/test.txt && sleep 3600"]
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: my-claim
EOF
```

Verify the data:

```bash
kubectl exec pvc-pod -- cat /data/test.txt
```

## Using Label Selectors

Create a labeled PV and select it:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-labeled
  labels:
    tier: fast
spec:
  capacity:
    storage: 2Gi
  accessModes: ["ReadWriteOnce"]
  storageClassName: ""
  hostPath:
    path: /tmp/pv-labeled
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: selective-claim
  namespace: tutorial-storage
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
  storageClassName: ""
  selector:
    matchLabels:
      tier: fast
EOF
```

## Reclaim Policies in Action

When you delete a PVC:
- **Retain:** PV becomes Released, data preserved
- **Delete:** PV is deleted (and underlying storage if applicable)

Delete the PVC and observe:

```bash
kubectl delete pvc my-claim
kubectl get pv pv-1gi
# Status: Released (because Retain policy)
```

## Making Released PV Available Again

Remove the claimRef to reuse:

```bash
kubectl patch pv pv-1gi --type=json -p='[{"op":"remove","path":"/spec/claimRef"}]'
kubectl get pv pv-1gi
# Status: Available
```

## Troubleshooting Binding

If a PVC is stuck in Pending:

```bash
kubectl describe pvc <name>
```

Common issues:
- No PV with sufficient capacity
- Access mode mismatch
- StorageClass mismatch
- All matching PVs already bound

## Cleanup

```bash
kubectl delete namespace tutorial-storage
kubectl delete pv pv-1gi pv-5gi pv-labeled --ignore-not-found
```

## Key Takeaways

1. PVCs request storage; PVs provide storage
2. Binding matches capacity, access modes, and storageClassName
3. Use selectors for specific PV selection
4. Retain policy preserves data but leaves PV in Released state
5. Delete policy removes the PV when PVC is deleted
6. Remove claimRef to make Released PVs Available again
