# Volumes and PersistentVolumes Tutorial

Kubernetes pods are ephemeral. A container's writable layer disappears when the container terminates, and the pod's filesystem dies with the pod. For data that must outlive a pod restart, you attach a volume. For data that must outlive the pod entirely (for example, a database's data directory that must survive a rollout), you use a PersistentVolume (PV) plus a PersistentVolumeClaim (PVC). This tutorial covers the PV side of that relationship: the volume types built into Kubernetes, the PV resource itself, and the lifecycle a PV goes through as it serves storage to one or more pods over time.

The CKA exam has a dedicated Services and Storage domain that requires fluency with volumes, PVs, PVCs, and StorageClasses. This assignment is step one of three. Here the emphasis is on the "what does the storage side declare" question. Assignment 2 picks up "how does a pod claim storage" via PVCs, and assignment 3 covers "how does the storage side automate provisioning" via StorageClasses.

## Prerequisites

Any single-node kind cluster works. See `docs/cluster-setup.md#single-node-kind-cluster` for the creation command. Verify the cluster.

```bash
kubectl get nodes
# Expected: STATUS  Ready
```

Create the tutorial namespace.

```bash
kubectl create namespace tutorial-storage
kubectl config set-context --current --namespace=tutorial-storage
```

## Part 1: `emptyDir` (pod-lifetime scratch)

The simplest volume type. Created when the pod is assigned to a node, destroyed when the pod is removed. Shared across containers in the pod. Useful for scratch space, logs before a logs sidecar ships them, and shared caches between containers in the same pod.

**Spec field reference for `emptyDir`:**

- **Fields:** `medium` (optional), `sizeLimit` (optional).
- **Valid `medium` values:** empty string (node's default filesystem, default) or `Memory` (tmpfs, RAM-backed, counts against the container's memory limit).
- **Default `sizeLimit`:** unlimited; bounded by the node's ephemeral-storage resource. Set to a quantity to cap the emptyDir size.
- **Failure mode when misconfigured:** `sizeLimit` exceeded causes the kubelet to evict the pod with a `MountVolume.SetUp failed` event. `medium: Memory` counts against the pod's memory limit, so a writer that fills it produces OOM behavior.

Apply a pod with a shared `emptyDir`.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: scratch
spec:
  containers:
  - name: writer
    image: busybox:1.36
    command: ["sh", "-c", "echo 'hello from writer' > /data/msg && sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  - name: reader
    image: busybox:1.36
    command: ["sh", "-c", "sleep 2 && cat /data/msg && sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
EOF
kubectl wait --for=condition=Ready pod/scratch --timeout=60s
kubectl logs scratch -c reader
```

Expected output:

```
hello from writer
```

Data written by one container is visible to the other. Delete the pod.

```bash
kubectl delete pod scratch
```

## Part 2: `hostPath` (node-level storage)

`hostPath` mounts a directory from the node's filesystem into the container. Data persists beyond the pod's lifetime because the node keeps the directory. Use cases in CKA scope are narrow: pre-populated data the administrator placed on the node, single-node-cluster test setups, and infrastructure pods that need to read host state (CNI, CSI, node exporters). Almost never the right choice for general application storage because pods that move to a different node lose the data.

**Spec field reference for `hostPath`:**

- **Fields:** `path`, `type`.
- **Valid `type` values:** `""` (default; no type check), `DirectoryOrCreate`, `Directory`, `FileOrCreate`, `File`, `Socket`, `CharDevice`, `BlockDevice`.
- **Default `type`:** empty string, meaning no check. The mount proceeds regardless of whether the path exists.
- **Failure mode when misconfigured:** with `type: Directory`, if the path does not exist on the node, the kubelet produces `MountVolume.SetUp failed ... does not exist` and the pod stays Pending. With `type: DirectoryOrCreate`, the kubelet creates the directory with permissions that match the kubelet's umask, which often does not match what the container wants.

Create a directory on the kind node and write a file to it.

```bash
nerdctl exec kind-control-plane sh -c 'mkdir -p /host-data && echo "from the node" > /host-data/greet'
```

Apply a pod that mounts `/host-data`.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: host-reader
spec:
  containers:
  - name: probe
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: host
      mountPath: /data
  volumes:
  - name: host
    hostPath:
      path: /host-data
      type: Directory
EOF
kubectl wait --for=condition=Ready pod/host-reader --timeout=60s
kubectl exec host-reader -- cat /data/greet
```

Expected output:

```
from the node
```

Delete the pod and clean up the host path.

```bash
kubectl delete pod host-reader
nerdctl exec kind-control-plane rm -rf /host-data
```

## Part 3: `PersistentVolume` (cluster-level storage resource)

A PersistentVolume is a cluster-scoped API resource representing a piece of storage that exists independently of any pod. PVs are usually either created by the administrator ("static provisioning") or created automatically by a provisioner when a PVC requests them ("dynamic provisioning", covered in assignment 3). This tutorial and assignment focus on static provisioning.

**Spec field reference for `PersistentVolume`:**

- **`spec.capacity.storage`**
  - **Type:** `Quantity` (string like `1Gi`, `500Mi`, `100Gi`, `2Ti`).
  - **Valid values:** any Kubernetes quantity; usual units are `Ki`, `Mi`, `Gi`, `Ti`.
  - **Default:** none; required.
  - **Failure mode when misconfigured:** the API rejects an invalid quantity (the PV creation fails). A PVC requesting more than the PV offers will never bind.

- **`spec.accessModes`**
  - **Type:** array of strings.
  - **Valid values:** `ReadWriteOnce` (RWO, one node mount), `ReadOnlyMany` (ROX, many nodes read-only), `ReadWriteMany` (RWX, many nodes read-write), `ReadWriteOncePod` (RWOP, one pod only, K8s 1.29+).
  - **Default:** none; required.
  - **Failure mode when misconfigured:** a PVC requesting a mode the PV does not support will not bind. `hostPath` technically honors any access mode declaration at the API level; the semantic is enforced only if the backend is real networked storage.

- **`spec.persistentVolumeReclaimPolicy`**
  - **Type:** string.
  - **Valid values:** `Retain` (PV stays after PVC deletion, keeps data, manual cleanup), `Delete` (PV and backend deleted when PVC is deleted, default for dynamic provisioning), `Recycle` (deprecated; don't use).
  - **Default:** `Retain` for statically provisioned PVs; `Delete` for dynamically provisioned PVs.
  - **Failure mode when misconfigured:** `Delete` on a `hostPath` backend silently leaves the directory on the node (the backend does not support true deletion). `Retain` followed by PVC deletion leaves the PV in `Released` phase and prevents rebinding until the administrator intervenes.

- **`spec.storageClassName`**
  - **Type:** string.
  - **Valid values:** any StorageClass name, `""` (empty string, for static provisioning).
  - **Default:** empty string.
  - **Failure mode when misconfigured:** a PVC with a different `storageClassName` will not bind. A common gotcha: leaving the field unset and then expecting a PVC with an explicit empty string `""` to bind. They do match, but the API-server may canonicalize differently.

- **`spec.volumeMode`**
  - **Type:** string.
  - **Valid values:** `Filesystem`, `Block`.
  - **Default:** `Filesystem`.
  - **Failure mode when misconfigured:** `Block` requires the consuming pod to use `volumeDevices` instead of `volumeMounts` and requires a backend that supports raw block. `hostPath` does not support `Block`.

- **Backend fields:** exactly one of `hostPath`, `nfs`, `local`, `csi`, `iscsi`, etc. Determines where the storage lives.

Apply a simple statically provisioned PV backed by `hostPath`.

```bash
nerdctl exec kind-control-plane mkdir -p /pv-one

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-one
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /pv-one
    type: DirectoryOrCreate
EOF
kubectl get pv pv-one
```

Expected output (one row):

```
NAME     CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   REASON   AGE
pv-one   1Gi        RWO            Retain           Available           manual                  5s
```

The PV is in the `Available` phase. No PVC has claimed it yet. Note also that PVs are cluster-scoped, not namespaced; `pv-one` exists outside any namespace.

## Part 4: PV lifecycle phases

A PersistentVolume passes through one of these phases at any time:

- **`Available`**: the PV exists but no PVC is bound to it.
- **`Bound`**: a PVC is bound to the PV. The PV is in use.
- **`Released`**: the PVC that was bound is deleted, but the PV still contains the data (because `reclaimPolicy: Retain`). A released PV cannot be bound by another PVC until the administrator intervenes.
- **`Failed`**: an automatic reclamation operation (under `Delete` or `Recycle`) failed.
- **`Pending`**: a transient state during creation; rarely seen.

Drive a PV through phases. First, create a PVC that will bind to `pv-one`.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim-one
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 500Mi
  storageClassName: manual
EOF
kubectl get pv pv-one -o jsonpath='{.status.phase}{"\n"}'
```

Expected output:

```
Bound
```

Delete the PVC.

```bash
kubectl delete pvc claim-one
kubectl get pv pv-one -o jsonpath='{.status.phase}{"\n"}'
```

Expected output:

```
Released
```

The PV is now Released. It cannot be rebound automatically; its `spec.claimRef` still references the deleted PVC. This is the single most common point of confusion around PVs. The administrator must either delete and recreate the PV or edit out the `claimRef`.

```bash
kubectl patch pv pv-one --type='json' -p='[{"op": "remove", "path": "/spec/claimRef"}]'
kubectl get pv pv-one -o jsonpath='{.status.phase}{"\n"}'
```

Expected output:

```
Available
```

Now it is bindable again. Delete the PV and its backing directory.

```bash
kubectl delete pv pv-one
nerdctl exec kind-control-plane rm -rf /pv-one
```

## Part 5: Labels and selectors on PVs

Labels on a PV combined with a `selector` on a PVC let an administrator steer which PVC claims which PV. The most common use case: separating "fast" from "slow" PVs before StorageClasses were common.

Create two PVs, one labeled "fast" and one labeled "slow".

```bash
nerdctl exec kind-control-plane sh -c 'mkdir -p /pv-fast /pv-slow'

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-fast
  labels:
    tier: fast
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /pv-fast
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-slow
  labels:
    tier: slow
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /pv-slow
    type: DirectoryOrCreate
EOF
```

Apply a PVC that selects the "fast" tier.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pick-fast
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 500Mi
  storageClassName: manual
  selector:
    matchLabels:
      tier: fast
EOF
kubectl get pvc pick-fast -o jsonpath='{.spec.volumeName}{"\n"}'
```

Expected output:

```
pv-fast
```

Only `pv-fast` was a candidate because only it carried `tier=fast`. The PVC is now Bound to `pv-fast`; `pv-slow` stays Available.

Clean up.

```bash
kubectl delete pvc pick-fast
kubectl patch pv pv-fast --type='json' -p='[{"op": "remove", "path": "/spec/claimRef"}]' 2>/dev/null || true
kubectl delete pv pv-fast pv-slow
nerdctl exec kind-control-plane sh -c 'rm -rf /pv-fast /pv-slow'
```

## Part 6: Node affinity on a PV

A PV backed by local storage (`hostPath` or the `local` volume type) only exists on a specific node. `spec.nodeAffinity` on the PV tells the scheduler which node can see the PV, so a pod that claims it lands on the right node.

Apply a `local`-backed PV with node affinity to the kind control-plane node.

```bash
nerdctl exec kind-control-plane mkdir -p /pv-local

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-local
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  local:
    path: /pv-local
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: ["kind-control-plane"]
EOF
kubectl get pv pv-local
```

Expected output: a PV in `Available` phase with the `local` backend. If a PVC binds and a pod uses it, the scheduler consults the PV's `nodeAffinity` and places the pod on the named node. Clean up.

```bash
kubectl delete pv pv-local
nerdctl exec kind-control-plane rm -rf /pv-local
```

## Cleanup

Delete the tutorial namespace.

```bash
kubectl delete namespace tutorial-storage
kubectl config set-context --current --namespace=default
```

## Reference Commands

| Task | Command |
|---|---|
| List PVs | `kubectl get pv` |
| PV details | `kubectl describe pv <name>` |
| PV status phase | `kubectl get pv <name> -o jsonpath='{.status.phase}'` |
| PV backing directory | `kubectl get pv <name> -o jsonpath='{.spec.hostPath.path}'` |
| Remove a stale claimRef | `kubectl patch pv <name> --type='json' -p='[{"op":"remove","path":"/spec/claimRef"}]'` |
| Show the PV a PVC bound to | `kubectl get pvc <name> -o jsonpath='{.spec.volumeName}'` |

## Key Takeaways

`emptyDir` is pod-lifetime scratch; `hostPath` persists on the node but pins data to that node; `PersistentVolume` is the cluster-scoped storage abstraction. A PV's `capacity`, `accessModes`, and `storageClassName` control which PVCs can bind to it; labels and a PVC `selector` provide finer-grained control. The five PV phases are `Available`, `Bound`, `Released`, `Failed`, and (briefly) `Pending`. A PV with `reclaimPolicy: Retain` lands in `Released` after its PVC is deleted, and requires removing `spec.claimRef` before it can bind again. Local volumes (`hostPath` and the `local` type) should declare `spec.nodeAffinity` so the scheduler places consumers on the right node. PV spec validation rejects bad quantities at admission time; a bad access mode or storage class produces a binding failure only when a PVC arrives, which is the debugging hook for Level 3.
