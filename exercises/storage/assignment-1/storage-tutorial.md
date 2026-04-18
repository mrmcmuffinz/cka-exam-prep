# Storage Tutorial: Volumes and PersistentVolumes

## Introduction

Kubernetes provides several ways to give containers access to storage. This tutorial covers volume types and PersistentVolumes, which are the foundation of persistent storage in Kubernetes. Understanding these concepts is essential for the CKA exam and for running stateful applications.

Containers have ephemeral storage by default, meaning data is lost when the container restarts. Volumes provide a way to persist data beyond the container lifecycle, and PersistentVolumes provide a way to manage storage resources independently of pods.

## Prerequisites

You need a running kind cluster. Create one if you do not have one already:

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

Verify the cluster is running:

```bash
kubectl cluster-info
```

## Setup

Create a namespace for the tutorial:

```bash
kubectl create namespace tutorial-storage
```

Set this namespace as the default:

```bash
kubectl config set-context --current --namespace=tutorial-storage
```

## Volume Types Overview

Kubernetes supports many volume types. The most common ones are:

| Volume Type | Lifetime | Use Case |
|-------------|----------|----------|
| emptyDir | Pod lifetime | Scratch space, caching, shared data between containers |
| hostPath | Node lifetime | Access node filesystem, development only |
| configMap | ConfigMap lifetime | Mount configuration files |
| secret | Secret lifetime | Mount sensitive data |
| persistentVolumeClaim | Independent | Persistent storage that survives pod restarts |

## Using emptyDir Volumes

An emptyDir volume is created when a pod is assigned to a node and exists as long as the pod runs on that node. When the pod is removed, the emptyDir is deleted permanently.

Create a pod with an emptyDir volume:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-demo
  namespace: tutorial-storage
spec:
  containers:
  - name: writer
    image: busybox:1.36
    command: ["sh", "-c", "echo 'Hello from emptyDir' > /data/message.txt && sleep 3600"]
    volumeMounts:
    - name: shared-data
      mountPath: /data
  - name: reader
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5 && cat /data/message.txt && sleep 3600"]
    volumeMounts:
    - name: shared-data
      mountPath: /data
  volumes:
  - name: shared-data
    emptyDir: {}
EOF
```

Wait for the pod:

```bash
kubectl wait --for=condition=Ready pod/emptydir-demo --timeout=60s
```

Verify the shared data:

```bash
kubectl logs emptydir-demo -c reader
```

The reader container can read the file written by the writer container because they share the emptyDir volume.

## Using hostPath Volumes

A hostPath volume mounts a file or directory from the host node's filesystem into the pod. This is useful for development but should be avoided in production because it ties pods to specific nodes.

Create a pod with a hostPath volume:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-demo
  namespace: tutorial-storage
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sh", "-c", "echo 'Stored on host' > /host-data/test.txt && cat /host-data/test.txt && sleep 3600"]
    volumeMounts:
    - name: host-volume
      mountPath: /host-data
  volumes:
  - name: host-volume
    hostPath:
      path: /tmp/k8s-demo
      type: DirectoryOrCreate
EOF
```

Wait for the pod and check logs:

```bash
kubectl wait --for=condition=Ready pod/hostpath-demo --timeout=60s
kubectl logs hostpath-demo
```

The hostPath type can be:
- `DirectoryOrCreate`: Creates directory if it does not exist
- `Directory`: Directory must exist
- `FileOrCreate`: Creates file if it does not exist
- `File`: File must exist

## Understanding PersistentVolumes

A PersistentVolume (PV) is a piece of storage in the cluster that has been provisioned by an administrator or dynamically provisioned. PVs are cluster resources that exist independently of pods.

### PV Spec Fields

Key fields in a PV spec:

| Field | Description |
|-------|-------------|
| capacity.storage | Size of the volume (e.g., 1Gi, 500Mi) |
| accessModes | How the volume can be accessed |
| persistentVolumeReclaimPolicy | What happens when the PV is released |
| storageClassName | Links to a StorageClass (empty for static) |
| hostPath/nfs/etc. | The backend storage type |

### Access Modes

| Mode | Abbreviation | Description |
|------|--------------|-------------|
| ReadWriteOnce | RWO | Single node read-write |
| ReadOnlyMany | ROX | Multiple nodes read-only |
| ReadWriteMany | RWX | Multiple nodes read-write |
| ReadWriteOncePod | RWOP | Single pod read-write |

### Reclaim Policies

| Policy | Description |
|--------|-------------|
| Retain | PV becomes Released, data is preserved |
| Delete | PV and underlying storage are deleted |
| Recycle | Basic scrub (deprecated) |

## Creating a PersistentVolume

Create a PV with hostPath backend (suitable for kind):

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: demo-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/demo-pv-data
    type: DirectoryOrCreate
EOF
```

List PersistentVolumes:

```bash
kubectl get pv
```

The PV shows STATUS as Available, meaning it is ready to be bound to a PVC.

Describe the PV:

```bash
kubectl describe pv demo-pv
```

## PV Lifecycle Phases

PersistentVolumes go through these phases:

| Phase | Description |
|-------|-------------|
| Available | PV is ready and not bound to any PVC |
| Bound | PV is bound to a PVC |
| Released | PVC was deleted but PV not yet reclaimed |
| Failed | Automatic reclamation failed |

Check the current phase:

```bash
kubectl get pv demo-pv -o jsonpath='{.status.phase}'
```

## Creating Multiple PVs

Create several PVs with different configurations:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-small
  labels:
    size: small
spec:
  capacity:
    storage: 500Mi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: ""
  hostPath:
    path: /tmp/pv-small
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-medium
  labels:
    size: medium
spec:
  capacity:
    storage: 2Gi
  accessModes:
  - ReadWriteOnce
  - ReadOnlyMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/pv-medium
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-large
  labels:
    size: large
spec:
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/pv-large
    type: DirectoryOrCreate
EOF
```

List all PVs:

```bash
kubectl get pv
```

## PV Labels and Selectors

Labels on PVs can be used by PVCs to select specific PVs:

```bash
# List PVs with labels
kubectl get pv --show-labels

# Filter by label
kubectl get pv -l size=medium
```

## Node Affinity for Local Volumes

For local volumes that are tied to specific nodes, you can use node affinity:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  local:
    path: /tmp/local-pv
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - kind-control-plane
EOF
```

This PV can only be used by pods scheduled on the kind-control-plane node.

## Inspecting PVs

Get detailed information:

```bash
kubectl describe pv demo-pv
```

Get specific fields:

```bash
# Get capacity
kubectl get pv demo-pv -o jsonpath='{.spec.capacity.storage}'

# Get access modes
kubectl get pv demo-pv -o jsonpath='{.spec.accessModes}'

# Get reclaim policy
kubectl get pv demo-pv -o jsonpath='{.spec.persistentVolumeReclaimPolicy}'
```

## Static vs Dynamic Provisioning

**Static provisioning:** Administrator creates PVs manually before users create PVCs. PVCs bind to existing PVs that match their requirements.

**Dynamic provisioning:** When a PVC requests storage with a StorageClass, the provisioner automatically creates a PV. (Covered in assignment-3)

This tutorial focuses on static provisioning.

## Cleanup

Delete the pods and PVs:

```bash
kubectl delete pod emptydir-demo hostpath-demo -n tutorial-storage
kubectl delete pv demo-pv pv-small pv-medium pv-large local-pv
kubectl delete namespace tutorial-storage
```

## Reference Commands

| Task | Command |
|------|---------|
| List PVs | `kubectl get pv` |
| Describe PV | `kubectl describe pv <name>` |
| Get PV YAML | `kubectl get pv <name> -o yaml` |
| Delete PV | `kubectl delete pv <name>` |
| Get PV phase | `kubectl get pv <name> -o jsonpath='{.status.phase}'` |
| Filter by label | `kubectl get pv -l <label>=<value>` |

## Key Takeaways

1. **emptyDir** provides temporary storage that lasts for the pod's lifetime
2. **hostPath** mounts host filesystem into pods (use with caution)
3. **PersistentVolumes** are cluster-level storage resources
4. **Access modes** define how volumes can be mounted (RWO, ROX, RWX, RWOP)
5. **Reclaim policies** determine what happens when a PV is released (Retain, Delete)
6. **Static provisioning** requires creating PVs before PVCs
7. **Node affinity** constrains local PVs to specific nodes
8. PV lifecycle: Available, Bound, Released, Failed
