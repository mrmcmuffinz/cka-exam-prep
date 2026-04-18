# PersistentVolumeClaims and Binding Tutorial

A PersistentVolume (the subject of assignment 1) is an offer of storage. A PersistentVolumeClaim is a request for storage. The Kubernetes binding controller reconciles the two by finding a PV that satisfies every criterion a PVC declares. This tutorial walks through every field of a PVC spec with its valid values, default, and failure mode, then drills on the binding algorithm with matched and deliberately-mismatched cases, then closes on reclaim-policy behavior when a PVC is deleted.

The CKA exam expects you to diagnose a PVC stuck in `Pending` by correlating the PVC's requirements against every available PV's offering. In practice, once you have that habit, the debugging is mechanical: list all PVs, list all PVCs, read the events, find the mismatch. This tutorial builds the habit explicitly.

## Prerequisites

Any single-node kind cluster works. See `docs/cluster-setup.md#single-node-kind-cluster`. Complete `exercises/storage/assignment-1` first; this tutorial assumes you understand PVs. Verify the cluster.

```bash
kubectl get nodes
# Expected: STATUS  Ready
```

Create the tutorial namespace.

```bash
kubectl create namespace tutorial-storage
kubectl config set-context --current --namespace=tutorial-storage
```

## Part 1: A PVC that binds

Create a matched PV and PVC and observe the binding.

```bash
nerdctl exec kind-control-plane mkdir -p /tut-pv

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: tut-pv
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /tut-pv
    type: DirectoryOrCreate
EOF

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: tut-claim
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 500Mi
  storageClassName: manual
EOF

kubectl get pvc tut-claim
kubectl get pv tut-pv
```

Expected: `tut-claim` reports `STATUS Bound` with `VOLUME tut-pv`. `tut-pv` reports `STATUS Bound`. The binding took milliseconds.

**Spec field reference for `PersistentVolumeClaim`:**

- **`spec.accessModes`**
  - **Type:** array of strings.
  - **Valid values:** `ReadWriteOnce` (RWO), `ReadOnlyMany` (ROX), `ReadWriteMany` (RWX), `ReadWriteOncePod` (RWOP).
  - **Default:** none; required.
  - **Failure mode when misconfigured:** a PVC requesting a mode the PV does not offer stays `Pending`. Listing `[ReadWriteOnce, ReadWriteMany]` requests a PV that supports BOTH, not either.

- **`spec.resources.requests.storage`**
  - **Type:** `Quantity`.
  - **Valid values:** any Kubernetes quantity such as `500Mi`, `10Gi`.
  - **Default:** none; required.
  - **Failure mode when misconfigured:** a PVC requesting more than any PV's capacity stays `Pending` with `FailedScheduling` / `FailedBinding` events. The match is "PV.capacity >= PVC.request", so requesting 10Gi never binds to a 1Gi PV.

- **`spec.storageClassName`**
  - **Type:** string.
  - **Valid values:** any StorageClass name, `""` (empty string for static).
  - **Default:** depends on cluster. If absent AND a default StorageClass exists, the cluster stamps the default. If explicitly `""`, static binding only.
  - **Failure mode when misconfigured:** PVC's `storageClassName` must match the PV's exactly. An empty string on one side and a specific class on the other does not match. A missing field on a PVC might auto-populate with the default class, which usually has no matching static PVs.

- **`spec.selector`**
  - **Type:** `LabelSelector` object with `matchLabels` and/or `matchExpressions`.
  - **Valid values:** any valid LabelSelector.
  - **Default:** none; no selector means any matching PV is a candidate.
  - **Failure mode when misconfigured:** if the selector matches no PV labels, the PVC stays `Pending`. Selectors on a PVC are combined with the other criteria, not instead of them; the selector narrows the candidate set further.

- **`spec.volumeName`**
  - **Type:** string.
  - **Valid values:** the name of a specific PV.
  - **Default:** empty.
  - **Failure mode when misconfigured:** if the named PV does not exist or does not match the other PVC fields (capacity too small, access modes wrong), the PVC stays `Pending`. Setting `volumeName` skips label selectors but still requires capacity and access-mode matching.

- **`spec.volumeMode`**
  - **Type:** string.
  - **Valid values:** `Filesystem`, `Block`.
  - **Default:** `Filesystem`.
  - **Failure mode when misconfigured:** `Block` requires a compatible PV backend. `hostPath` does not support Block.

Clean up so the later sections can use the PV name.

```bash
kubectl delete pvc tut-claim
kubectl patch pv tut-pv --type='json' -p='[{"op":"remove","path":"/spec/claimRef"}]' 2>/dev/null || true
kubectl delete pv tut-pv
nerdctl exec kind-control-plane rm -rf /tut-pv
```

## Part 2: Mounting a PVC in a pod

Create a PV and PVC, then mount the PVC in a pod.

```bash
nerdctl exec kind-control-plane mkdir -p /tut-mount

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: tut-mount
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /tut-mount
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: tut-mount-claim
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 500Mi
  storageClassName: manual
---
apiVersion: v1
kind: Pod
metadata:
  name: tut-pod
spec:
  containers:
  - name: writer
    image: busybox:1.36
    command: ["sh", "-c", "echo 'persistent data' > /data/file && sleep 3600"]
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: tut-mount-claim
EOF

kubectl wait --for=condition=Ready pod/tut-pod --timeout=60s
kubectl exec tut-pod -- cat /data/file
```

Expected output:

```
persistent data
```

The key line in the pod spec is `volumes[*].persistentVolumeClaim.claimName`. Volumes referenced by PVCs use this form, not the `hostPath` or `emptyDir` form. Verify persistence across pod deletion.

```bash
kubectl delete pod tut-pod
nerdctl exec kind-control-plane cat /tut-mount/file
```

Expected output:

```
persistent data
```

The PV's backing `hostPath` on the node retains the file even though the pod is gone. Recreate the pod and confirm it can read the same data.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: tut-pod
spec:
  containers:
  - name: reader
    image: busybox:1.36
    command: ["sh", "-c", "cat /data/file; sleep 3600"]
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: tut-mount-claim
EOF
kubectl wait --for=condition=Ready pod/tut-pod --timeout=60s
kubectl logs tut-pod
```

Expected output:

```
persistent data
```

## Part 3: The binding algorithm

Kubernetes binds a PVC to the first matching PV it finds. The criteria in order:

1. **`storageClassName` must match exactly.** Empty string and omitted string are different for pedantic cluster configurations; be explicit.
2. **Access modes.** Every mode in the PVC must be in the PV.
3. **Capacity.** PV capacity must be greater than or equal to PVC requested storage.
4. **Label selector.** If the PVC has a `selector`, the PV's labels must match.
5. **VolumeName.** If the PVC sets `volumeName`, only that specific PV is a candidate (the other criteria still apply).

Set up three PVs with different capacities and a PVC that should match the medium one.

```bash
nerdctl exec kind-control-plane sh -c 'mkdir -p /tut-small /tut-medium /tut-large'

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: tut-small
spec:
  capacity: {storage: 500Mi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual-algo
  hostPath: {path: /tut-small, type: DirectoryOrCreate}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: tut-medium
spec:
  capacity: {storage: 2Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual-algo
  hostPath: {path: /tut-medium, type: DirectoryOrCreate}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: tut-large
spec:
  capacity: {storage: 10Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual-algo
  hostPath: {path: /tut-large, type: DirectoryOrCreate}
EOF

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: tut-algo-claim
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
  storageClassName: manual-algo
EOF

kubectl get pvc tut-algo-claim -o jsonpath='{.spec.volumeName}'
```

Expected output: one of `tut-medium` or `tut-large` (the binder selects the smallest PV that satisfies the criteria, so `tut-medium` is typical). `tut-small` is too small. The binding is not deterministic between multiple matching PVs, although the algorithm prefers smaller-but-sufficient.

Clean up.

```bash
kubectl delete pvc tut-algo-claim
for pv in tut-small tut-medium tut-large; do
  kubectl patch pv "$pv" --type='json' -p='[{"op":"remove","path":"/spec/claimRef"}]' 2>/dev/null || true
  kubectl delete pv "$pv"
done
nerdctl exec kind-control-plane sh -c 'rm -rf /tut-small /tut-medium /tut-large'
```

## Part 4: Binding failures

Demonstrate each failure mode. First, capacity mismatch.

```bash
nerdctl exec kind-control-plane mkdir -p /tut-fail

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: tut-fail-pv
spec:
  capacity: {storage: 500Mi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual-fail
  hostPath: {path: /tut-fail, type: DirectoryOrCreate}
EOF

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: tut-fail-capacity
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 2Gi
  storageClassName: manual-fail
EOF

sleep 3
kubectl get pvc tut-fail-capacity
kubectl describe pvc tut-fail-capacity | tail -n 10
```

Expected output: `STATUS Pending`. Events include `no persistent volumes available for this claim and no storage class is set` or similar, because the only PV with the right class is too small. Fix by either adjusting the request down or by creating a larger PV. Delete the PVC.

```bash
kubectl delete pvc tut-fail-capacity
```

Now access mode mismatch.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: tut-fail-access
spec:
  accessModes: ["ReadWriteMany"]
  resources:
    requests:
      storage: 100Mi
  storageClassName: manual-fail
EOF

sleep 3
kubectl get pvc tut-fail-access
```

Expected output: `STATUS Pending`. The PV offers only `ReadWriteOnce`; the PVC asks for `ReadWriteMany`. Delete.

```bash
kubectl delete pvc tut-fail-access
```

Now storage-class mismatch.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: tut-fail-class
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 100Mi
  storageClassName: manual
EOF

sleep 3
kubectl get pvc tut-fail-class
```

Expected output: `STATUS Pending`. PV is `storageClassName: manual-fail`, PVC is `storageClassName: manual`; no match. Clean up everything.

```bash
kubectl delete pvc tut-fail-class
kubectl delete pv tut-fail-pv
nerdctl exec kind-control-plane rm -rf /tut-fail
```

## Part 5: `volumeName` pre-binding

Use `spec.volumeName` to bind to a specific PV, skipping the selector logic.

```bash
nerdctl exec kind-control-plane sh -c 'mkdir -p /tut-name-a /tut-name-b'

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata: {name: tut-name-a}
spec:
  capacity: {storage: 1Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath: {path: /tut-name-a, type: DirectoryOrCreate}
---
apiVersion: v1
kind: PersistentVolume
metadata: {name: tut-name-b}
spec:
  capacity: {storage: 1Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath: {path: /tut-name-b, type: DirectoryOrCreate}
EOF

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: tut-pick-b
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 500Mi
  storageClassName: manual
  volumeName: tut-name-b
EOF
kubectl get pvc tut-pick-b -o jsonpath='{.spec.volumeName}'
```

Expected output:

```
tut-name-b
```

The PVC binds specifically to `tut-name-b` even though `tut-name-a` would have been a match. Clean up.

```bash
kubectl delete pvc tut-pick-b
kubectl patch pv tut-name-b --type='json' -p='[{"op":"remove","path":"/spec/claimRef"}]' 2>/dev/null || true
kubectl delete pv tut-name-a tut-name-b
nerdctl exec kind-control-plane sh -c 'rm -rf /tut-name-a /tut-name-b'
```

## Part 6: Reclaim policies

Compare `Retain` and `Delete` by creating two PVs, binding PVCs to each, and deleting both PVCs.

```bash
nerdctl exec kind-control-plane sh -c 'mkdir -p /tut-reclaim-r /tut-reclaim-d'
nerdctl exec kind-control-plane sh -c 'echo keep > /tut-reclaim-r/data && echo temp > /tut-reclaim-d/data'

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata: {name: tut-retain}
spec:
  capacity: {storage: 1Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual-rr
  hostPath: {path: /tut-reclaim-r, type: Directory}
---
apiVersion: v1
kind: PersistentVolume
metadata: {name: tut-delete}
spec:
  capacity: {storage: 1Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Delete
  storageClassName: manual-rr
  hostPath: {path: /tut-reclaim-d, type: Directory}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: claim-r}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: manual-rr
  volumeName: tut-retain
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: claim-d}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: manual-rr
  volumeName: tut-delete
EOF

sleep 2
kubectl delete pvc claim-r claim-d
sleep 2
kubectl get pv tut-retain tut-delete
```

Expected output (approximately):

```
NAME          CAPACITY   ...   STATUS     CLAIM                      STORAGECLASS    ...
tut-retain    1Gi        ...   Released   tutorial-storage/claim-r   manual-rr       ...
tut-delete    1Gi        ...   Failed     tutorial-storage/claim-d   manual-rr       ...
```

`tut-retain` is `Released` because `Retain` does nothing on PVC deletion other than lock the PV to the deleted claim. `tut-delete` is `Failed` because `hostPath` does not implement the Delete reclaim operation. Both directories on the node are still present. Clean up.

```bash
kubectl patch pv tut-retain --type='json' -p='[{"op":"remove","path":"/spec/claimRef"}]'
kubectl delete pv tut-retain tut-delete
nerdctl exec kind-control-plane sh -c 'rm -rf /tut-reclaim-r /tut-reclaim-d'
```

## Part 7: Reusing a `Released` PV

Create a Released PV and rebind a new PVC to it.

```bash
nerdctl exec kind-control-plane mkdir -p /tut-reuse
nerdctl exec kind-control-plane sh -c 'echo preserved > /tut-reuse/payload'

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata: {name: tut-reuse}
spec:
  capacity: {storage: 1Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath: {path: /tut-reuse, type: Directory}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: first-claim}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: manual
EOF

sleep 2
kubectl delete pvc first-claim
sleep 2
kubectl get pv tut-reuse -o jsonpath='{.status.phase}{"\n"}'
```

Expected output: `Released`. Now remove the `claimRef` and bind a new PVC.

```bash
kubectl patch pv tut-reuse --type='json' -p='[{"op":"remove","path":"/spec/claimRef"}]'
kubectl get pv tut-reuse -o jsonpath='{.status.phase}{"\n"}'
```

Expected output: `Available`.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: second-claim}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: manual
EOF
sleep 2
kubectl get pvc second-claim -o jsonpath='{.spec.volumeName}{"\n"}'
```

Expected output: `tut-reuse`. The second PVC bound to the reused PV, and a pod that mounts this PVC will see `preserved` at `/data/payload`. Clean up.

```bash
kubectl delete pvc second-claim
kubectl patch pv tut-reuse --type='json' -p='[{"op":"remove","path":"/spec/claimRef"}]'
kubectl delete pv tut-reuse
nerdctl exec kind-control-plane rm -rf /tut-reuse
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
| List PVCs in a namespace | `kubectl get pvc -n <ns>` |
| PVC phase | `kubectl get pvc -n <ns> <name> -o jsonpath='{.status.phase}'` |
| PVC bound volume | `kubectl get pvc -n <ns> <name> -o jsonpath='{.spec.volumeName}'` |
| PVC events | `kubectl describe pvc -n <ns> <name>` |
| List PVs | `kubectl get pv` |
| Find PVs using a storage class | `kubectl get pv --field-selector=spec.storageClassName=<class>` |

## Key Takeaways

A PVC matches a PV if: `storageClassName` matches exactly, every `accessMode` in the PVC is offered by the PV, PV capacity >= PVC request, PVC selector matches PV labels (if selector is set), PVC `volumeName` matches (if set). The binding controller prefers the smallest PV that satisfies all criteria. A PVC stays `Pending` until a matching PV exists; once bound, the relationship is exclusive (one PVC per PV). Pods reference a PVC via `spec.volumes[*].persistentVolumeClaim.claimName`. On PVC deletion, a PV with `Retain` goes `Released` and preserves `spec.claimRef`; removing the claimRef returns it to `Available`. `Delete` on a backend that does not support deletion (like `hostPath`) ends in `Failed` phase. `Recycle` is deprecated and should not be used. Access modes are selected based on how many pods and nodes need simultaneous write access.
