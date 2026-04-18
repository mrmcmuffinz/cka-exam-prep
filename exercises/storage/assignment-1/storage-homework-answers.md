# Volumes and PersistentVolumes Homework Answers

Complete solutions. Level 3 and Level 5 debugging answers use the three-stage structure (diagnosis, what the bug is and why, fix).

---

## Exercise 1.1 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: shared-scratch
  namespace: ex-1-1
spec:
  containers:
  - name: writer
    image: busybox:1.36
    command: ["sh", "-c", "echo hello > /data/message && sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  - name: reader
    image: busybox:1.36
    command: ["sh", "-c", "sleep 2 && cat /data/message && sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
```

`emptyDir` is shared across all containers in the pod that mount it. The writer starts its write immediately; the reader sleeps two seconds so the write has time to complete. Both end on `sleep 3600` so the pod stays Running. `emptyDir: {}` uses the default medium (node filesystem) with no size limit.

---

## Exercise 1.2 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: host-consumer
  namespace: ex-1-2
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: host
      mountPath: /data
  volumes:
  - name: host
    hostPath:
      path: /host-1-2
      type: Directory
```

`type: Directory` causes the kubelet to verify that the host path already exists. If it does not, the pod goes Pending with a mount failure, which is exactly what the exercise setup ensures does not happen.

---

## Exercise 1.3 Solution

Two applies: the first creates the pod that writes both files, the second creates a new pod that mounts the same volumes (but with different write commands that do nothing). The verification uses the recreated pod.

First pod (writer):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ephemeral-writer
  namespace: ex-1-3
spec:
  containers:
  - name: probe
    image: busybox:1.36
    command: ["sh", "-c", "echo A > /empty/mark-A && echo B > /host/mark-B && sleep 3600"]
    volumeMounts:
    - name: empty
      mountPath: /empty
    - name: host
      mountPath: /host
  volumes:
  - name: empty
    emptyDir: {}
  - name: host
    hostPath:
      path: /host-1-3
      type: Directory
```

After the pod is deleted, the `emptyDir` is garbage-collected by the kubelet. The `hostPath` directory is on the node and survives. The recreated pod (using `command: ["sleep", "3600"]` as in the Task) sees an empty `/empty` and `/host/mark-B` still there.

The learning: `emptyDir` is pod-lifetime. `hostPath` is node-lifetime.

---

## Exercise 2.1 Solution

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ex-2-1-pv
spec:
  capacity:
    storage: 2Gi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /ex-2-1
    type: DirectoryOrCreate
```

`DirectoryOrCreate` instructs the kubelet to create the directory if it does not exist. The PV enters `Available` because no PVC has bound to it yet. PVs are cluster-scoped; there is no namespace in the metadata.

---

## Exercise 2.2 Solution

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ex-2-2-pv
spec:
  capacity:
    storage: 500Mi
  accessModes: ["ReadOnlyMany"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /ex-2-2
    type: Directory
```

`ReadOnlyMany` means many nodes can mount the volume read-only. The backend still must support that semantic; `hostPath` nominally does for single-node test setups.

---

## Exercise 2.3 Solution

```bash
kubectl get pv ex-2-3-pv -o jsonpath='{.spec.capacity.storage}/{.spec.accessModes[0]}/{.spec.persistentVolumeReclaimPolicy}/{.spec.storageClassName}/{.spec.hostPath.path}/{.metadata.labels.purpose}'
```

Every field queried in one `jsonpath`. The extra `/` separators come out literally. The expected output is `750Mi/ReadWriteOnce/Delete/manual//ex-2-3/inspection`. Note the double slash before `/ex-2-3` because the path starts with a slash.

---

## Exercise 3.1 Solution

**Diagnosis.**

```bash
kubectl get pv ex-3-1-pv
kubectl describe pv ex-3-1-pv 2>&1 | head -n 20
```

The describe shows no such PV (the API server rejected the spec at admission time). Re-apply and capture the error.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ex-3-1-pv
spec:
  capacity:
    storage: 1G1
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /ex-3-1
    type: DirectoryOrCreate
EOF
```

Expected error: `Invalid value: "1G1": quantities must match the regular expression`. The capacity quantity `1G1` is not a valid Kubernetes quantity.

**What the bug is and why.** Kubernetes quantities use SI suffixes (`K`, `M`, `G`, `T`, `P`, `E`) or binary IEC suffixes (`Ki`, `Mi`, `Gi`, `Ti`, `Pi`, `Ei`). `1G1` is neither. The API server's quantity validator rejects the spec at write time, so the PV never exists. The key diagnostic hint is that `kubectl get pv ex-3-1-pv` returns "not found" rather than showing a PV in some odd state.

**Fix.** Correct the capacity to a valid quantity.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ex-3-1-pv
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /ex-3-1
    type: DirectoryOrCreate
```

---

## Exercise 3.2 Solution

**Diagnosis.**

```bash
kubectl get pv ex-3-2-pv
kubectl describe pv ex-3-2-pv | grep -E "Status|Claim"
```

Output shows `Status: Released` and a `Claim` referencing `ex-3-2/temp-claim`, but the PVC does not exist anymore. `Released` blocks rebinding.

**What the bug is and why.** `reclaimPolicy: Retain` means when the PVC is deleted, the PV keeps its data but also keeps a `spec.claimRef` field pointing to the deleted PVC. Kubernetes will not rebind the PV as long as `claimRef` is set, because that would violate the exclusive-binding invariant. The administrator must explicitly remove `claimRef` to indicate the data is free to be reused.

**Fix.** Remove the `claimRef`.

```bash
kubectl patch pv ex-3-2-pv --type='json' -p='[{"op": "remove", "path": "/spec/claimRef"}]'
```

`kubectl get pv ex-3-2-pv -o jsonpath='{.status.phase}'` now returns `Available`. The data at `/ex-3-2/data` is unchanged on the node.

---

## Exercise 3.3 Solution

**Diagnosis.**

```bash
kubectl get pvc -n ex-3-3 needy
kubectl describe pvc -n ex-3-3 needy
```

The events show `no persistent volumes available for this claim and no storage class is set` with details about the mismatch. Compare PV and PVC specs:

- PV: `accessModes: [ReadOnlyMany]`, `capacity: 500Mi`.
- PVC: `accessModes: [ReadWriteMany]`, `requests: 200Mi`.

The access-mode list does not match (the PV does not offer RWX), so no match. Capacity is fine (PV offers 500Mi, PVC asks for 200Mi).

**What the bug is and why.** A PVC binds to a PV only if the PV's `accessModes` is a superset of (or equals) the PVC's `accessModes`. `ReadOnlyMany` is not a superset of `ReadWriteMany`. The binding algorithm rejects the candidate and leaves the PVC Pending.

**Fix.** Change the PVC's `accessModes` to match what the PV offers.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: needy
  namespace: ex-3-3
spec:
  accessModes: ["ReadOnlyMany"]
  resources:
    requests:
      storage: 200Mi
  storageClassName: manual
```

Delete the old PVC and reapply (PVC specs are mostly immutable; easier to delete and recreate for this case). The PVC binds to `ex-3-3-pv` immediately.

---

## Exercise 4.1 Solution

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ex-4-1-pv
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  local:
    path: /ex-4-1
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values: ["kind-control-plane"]
```

`local` volume type is the modern replacement for `hostPath` when you want node affinity and the Kubernetes lifecycle to enforce scheduling constraints. Pods that claim this PV will only schedule onto `kind-control-plane`.

---

## Exercise 4.2 Solution

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ex-4-2-ssd
  labels:
    tier: ssd
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /ex-4-2-ssd
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ex-4-2-hdd
  labels:
    tier: hdd
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /ex-4-2-hdd
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: want-ssd
  namespace: ex-4-2
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 500Mi
  storageClassName: manual
  selector:
    matchLabels:
      tier: ssd
```

The PVC's `selector` restricts the candidate set to PVs matching `tier=ssd`. Only `ex-4-2-ssd` qualifies; it binds. `ex-4-2-hdd` stays Available for any other PVC that wants `tier=hdd` or no selector.

---

## Exercise 4.3 Solution

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ex-4-3-retain
spec:
  capacity: {storage: 500Mi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath: {path: /ex-4-3-retain, type: Directory}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ex-4-3-delete
spec:
  capacity: {storage: 500Mi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Delete
  storageClassName: manual
  hostPath: {path: /ex-4-3-delete, type: Directory}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim-retain
  namespace: ex-4-3
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 200Mi}}
  storageClassName: manual
  volumeName: ex-4-3-retain
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim-delete
  namespace: ex-4-3
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 200Mi}}
  storageClassName: manual
  volumeName: ex-4-3-delete
```

Then:

```bash
kubectl delete pvc -n ex-4-3 claim-retain claim-delete
```

Retain-policy PV enters `Released`; the directory on the node is unchanged. Delete-policy PV for `hostPath` has no real deletion path: Kubernetes tries to "delete" the backend but `hostPath` has no deletion provisioner, so the PV ends up in `Failed` phase (visible with `kubectl get pv`). The underlying directory on the node is untouched.

The practical takeaway: `Delete` reclaim policy makes sense for provisioners that can actually delete (CSI drivers for AWS EBS, Azure Disk, etc.). For `hostPath`, always use `Retain`.

---

## Exercise 5.1 Solution

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ex-5-1-data
spec:
  capacity: {storage: 2Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  local: {path: /ex-5-1-data}
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - {key: kubernetes.io/hostname, operator: In, values: [kind-control-plane]}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ex-5-1-config
  labels: {purpose: config}
spec:
  capacity: {storage: 100Mi}
  accessModes: ["ReadOnlyMany"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  local: {path: /ex-5-1-config}
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - {key: kubernetes.io/hostname, operator: In, values: [kind-control-plane]}
```

Both PVs use `local` (with `nodeAffinity`) rather than `hostPath` because local volumes formalize the node-pinning semantic that `hostPath` only implements by accident. The `purpose=config` label lets a PVC with a selector target specifically the config PV.

---

## Exercise 5.2 Solution

**Diagnosis.**

```bash
kubectl get pv ex-5-2-primary
kubectl describe pv ex-5-2-primary | grep -E "Status|Claim"
```

Status shows `Pending` or `Available` with a dangling `Claim: ghost-namespace/ghost-claim`. The PV was created with a pre-set `spec.claimRef`, which tells Kubernetes "only bind this PV to this exact PVC in this namespace." Since that PVC does not exist, the PV is effectively reserved for a PVC that will never arrive.

**What the bug is and why.** Pre-setting `spec.claimRef` at creation is a technique for pre-binding a PV to a specific PVC (same as the pattern in Exercise 5.3). When the referenced PVC does not exist, the PV is reserved but idle. Kubernetes keeps it that way to preserve the administrator's explicit intent.

**Fix.** Remove the `claimRef`.

```bash
kubectl patch pv ex-5-2-primary --type='json' -p='[{"op": "remove", "path": "/spec/claimRef"}]'
```

The PV now enters `Available` and will bind to any compatible PVC.

---

## Exercise 5.3 Solution

Use `spec.claimRef` on each PV to pre-bind it to a specific PVC that does not exist yet. When the PVC is created later, Kubernetes sees the pre-bind and completes the binding.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ex-5-3-pv-0
spec:
  capacity: {storage: 500Mi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  claimRef: {namespace: ex-5-3, name: data-app-0, kind: PersistentVolumeClaim, apiVersion: v1}
  hostPath: {path: /ex-5-3-0, type: DirectoryOrCreate}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ex-5-3-pv-1
spec:
  capacity: {storage: 500Mi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  claimRef: {namespace: ex-5-3, name: data-app-1, kind: PersistentVolumeClaim, apiVersion: v1}
  hostPath: {path: /ex-5-3-1, type: DirectoryOrCreate}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ex-5-3-pv-2
spec:
  capacity: {storage: 500Mi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  claimRef: {namespace: ex-5-3, name: data-app-2, kind: PersistentVolumeClaim, apiVersion: v1}
  hostPath: {path: /ex-5-3-2, type: DirectoryOrCreate}
```

Then apply the three PVCs (no selector, no `volumeName`; the PV's `claimRef` does the work):

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: data-app-0, namespace: ex-5-3}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 200Mi}}
  storageClassName: manual
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: data-app-1, namespace: ex-5-3}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 200Mi}}
  storageClassName: manual
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: data-app-2, namespace: ex-5-3}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 200Mi}}
  storageClassName: manual
```

Each PVC binds to exactly its pre-bound PV via the `claimRef`. This is the canonical static-provisioning pattern for StatefulSet-style workloads when you want specific data to be associated with specific pods.

---

## Common Mistakes

**1. Forgetting that PVs are cluster-scoped.** A PV does not have a namespace. A PVC does. Copying a PV spec from one cluster to another does not carry over namespace context. Exercises that confuse the two produce apply errors.

**2. Not removing `spec.claimRef` after PVC deletion.** A PV with `reclaimPolicy: Retain` whose PVC is deleted enters `Released` and retains its `claimRef` pointing to the deleted PVC. Until an administrator removes the `claimRef`, the PV cannot rebind. The removal is `kubectl patch pv ... --type='json' -p='[{"op":"remove","path":"/spec/claimRef"}]'`.

**3. Using `hostPath` with `reclaimPolicy: Delete`.** The `Delete` policy expects the backend to delete the underlying storage. `hostPath` has no such implementation, so the reclaim operation goes to `Failed` phase and the directory on the node is untouched. For `hostPath`, always use `Retain`.

**4. Invalid quantity strings in `capacity.storage`.** Kubernetes quantities use `Ki`/`Mi`/`Gi`/`Ti` (binary) or `K`/`M`/`G`/`T` (decimal). Typos like `1G1`, `500m` (millibyte!), or `2 Gi` (space) are rejected at admission. The symptom is a 422 from `kubectl apply`, not a stuck PV.

**5. Access-mode mismatch between PV and PVC.** A PVC can only bind to a PV whose `accessModes` contain every mode the PVC requests. A PVC asking for `[ReadWriteOnce, ReadWriteMany]` does not bind to a PV offering only `[ReadWriteOnce]`. Exam scenarios intentionally confuse the directionality.

**6. Omitting `storageClassName` on the PV but setting it on the PVC (or vice versa).** An empty `storageClassName` is distinct from an unset `storageClassName` in some Kubernetes versions. For static provisioning, explicitly set `storageClassName: manual` (or any non-cluster-default string) on both sides so they match.

**7. `local` volume type without `nodeAffinity`.** The `local` backend requires `spec.nodeAffinity` to be set; the API server rejects a `local` PV that does not declare it.

**8. `hostPath` with `type: Directory` when the path does not yet exist.** The pod goes Pending with a `MountVolume.SetUp` error. Use `type: DirectoryOrCreate` if you want the kubelet to create the path on demand.

---

## Verification Commands Cheat Sheet

| Check | Command |
|---|---|
| PV phase | `kubectl get pv <name> -o jsonpath='{.status.phase}'` |
| PV capacity | `kubectl get pv <name> -o jsonpath='{.spec.capacity.storage}'` |
| PV access modes | `kubectl get pv <name> -o jsonpath='{.spec.accessModes}'` |
| PV reclaim policy | `kubectl get pv <name> -o jsonpath='{.spec.persistentVolumeReclaimPolicy}'` |
| PV storage class | `kubectl get pv <name> -o jsonpath='{.spec.storageClassName}'` |
| PV backing path (hostPath) | `kubectl get pv <name> -o jsonpath='{.spec.hostPath.path}'` |
| PV claim reference | `kubectl get pv <name> -o jsonpath='{.spec.claimRef.namespace}/{.spec.claimRef.name}'` |
| Remove a stale claimRef | `kubectl patch pv <name> --type='json' -p='[{"op":"remove","path":"/spec/claimRef"}]'` |
| PVC phase | `kubectl get pvc -n <ns> <name> -o jsonpath='{.status.phase}'` |
| PVC bound PV | `kubectl get pvc -n <ns> <name> -o jsonpath='{.spec.volumeName}'` |
| Events on a PV | `kubectl describe pv <name>` |
