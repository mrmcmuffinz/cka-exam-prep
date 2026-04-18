# PersistentVolumeClaims and Binding Homework Answers

Complete solutions. Level 3 and Level 5 debugging answers use the three-stage structure.

---

## Exercise 1.1 Solution

PV:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata: {name: ex-1-1-pv}
spec:
  capacity: {storage: 1Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath: {path: /ex-1-1, type: DirectoryOrCreate}
```

PVC:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: basic-claim, namespace: ex-1-1}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: manual
```

The binder matches on `storageClassName: manual`, access mode `ReadWriteOnce`, and capacity (1Gi available >= 500Mi requested). Both phases show `Bound` within a second.

---

## Exercise 1.2 Solution

```yaml
apiVersion: v1
kind: PersistentVolume
metadata: {name: ex-1-2-pv}
spec:
  capacity: {storage: 1Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath: {path: /ex-1-2, type: DirectoryOrCreate}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: app-claim, namespace: ex-1-2}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: manual
---
apiVersion: v1
kind: Pod
metadata: {name: data-app, namespace: ex-1-2}
spec:
  containers:
  - name: writer
    image: busybox:1.36
    command: ["sh", "-c", "echo kept-forever > /data/marker && sleep 3600"]
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: app-claim
```

Pod mounts the PVC via `persistentVolumeClaim.claimName`. The file the container writes lands in `/ex-1-2` on the kind node because of the hostPath backend. The file persists even if the pod is deleted.

---

## Exercise 1.3 Solution

The setup block creates three PVs and three PVCs with `volumeName` pre-binding. Verification:

```bash
kubectl get pvc -n ex-1-3
```

Produces three `Bound` rows. The custom-columns query prints each PVC's size, ordered by name. No additional spec authoring is needed beyond what the setup block does.

---

## Exercise 2.1 Solution

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: smallest-fit, namespace: ex-2-1}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 1Gi}}
  storageClassName: manual-2-1
```

The binder considers all three PVs: `ex-2-1-small` (500Mi, too small), `ex-2-1-medium` (2Gi, sufficient), `ex-2-1-large` (10Gi, sufficient). The binding algorithm prefers the smallest sufficient PV, so `ex-2-1-medium` wins. `ex-2-1-small` stays `Available` because it did not match; `ex-2-1-large` stays `Available` because the binder picked the smaller option.

---

## Exercise 2.2 Solution

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: pick-bulk, namespace: ex-2-2}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: manual-2-2
  selector:
    matchLabels:
      tier: bulk
```

The selector narrows the candidate set to PVs labeled `tier=bulk`. Only `ex-2-2-bulk` qualifies. `ex-2-2-fast` is unaffected.

---

## Exercise 2.3 Solution

PVC that requests `[ReadWriteOnce]`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: needs-rwo, namespace: ex-2-3}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: manual-2-3
```

PVC that requests `[ReadWriteOnce, ReadOnlyMany]`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: needs-both, namespace: ex-2-3}
spec:
  accessModes: ["ReadWriteOnce", "ReadOnlyMany"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: manual-2-3
```

`needs-rwo` binds first because applied first. `needs-both` stays Pending because a PV can only bind to one PVC at a time; the single PV in the namespace is already taken. The lesson: a PVC requesting multiple access modes requires a PV that supports all of them AND is Available.

---

## Exercise 3.1 Solution

**Diagnosis.**

```bash
kubectl get pvc -n ex-3-1 pending-claim
kubectl describe pvc -n ex-3-1 pending-claim | tail -n 10
```

The events say `no persistent volumes available for this claim and no storage class is set`. The only matching PV (`ex-3-1-pv`) is 1Gi; the PVC requests 5Gi. Capacity mismatch.

**What the bug is and why.** The binder checks PV capacity >= PVC request. `1Gi >= 5Gi` is false. No PV satisfies the criterion; the PVC stays `Pending`. This is a one-way inequality; the PV must be at least as large as the request, but it can be much larger.

**Fix.** Reduce the PVC's request to something the PV can satisfy.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: pending-claim, namespace: ex-3-1}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: manual-3-1
```

Delete the old PVC and re-apply.

---

## Exercise 3.2 Solution

**Diagnosis.**

```bash
kubectl describe pvc -n ex-3-2 wrong-mode | tail -n 10
```

Events confirm no matching PV. The PV offers `[ReadWriteOnce]`; the PVC asks for `[ReadWriteMany]`. `ReadWriteMany` is not a subset of `ReadWriteOnce`; the binder rejects the candidate.

**What the bug is and why.** Access-mode matching is not "equal"; it is "every mode in the PVC must be in the PV's list." `ReadWriteMany` is not in `[ReadWriteOnce]`, so no match.

**Fix.** Change the PVC's access mode.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: wrong-mode, namespace: ex-3-2}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: manual-3-2
```

---

## Exercise 3.3 Solution

**Diagnosis.**

```bash
kubectl describe pvc -n ex-3-3 wrong-tier | tail -n 10
kubectl get pv ex-3-3-pv --show-labels
```

The PV carries label `tier=gold`. The PVC's selector requests `tier=silver`. The selector rules out the only available PV.

**What the bug is and why.** `spec.selector` on a PVC adds a filter: the PV's labels must match. `tier=silver` does not match `tier=gold`. The PV is removed from the candidate set.

**Fix.** Change the selector to match or remove it.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: wrong-tier, namespace: ex-3-3}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: manual-3-3
  selector:
    matchLabels:
      tier: gold
```

---

## Exercise 4.1 Solution

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: to-be-deleted, namespace: ex-4-1}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: manual-4-1
---
apiVersion: v1
kind: Pod
metadata: {name: writer, namespace: ex-4-1}
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo payload > /data/record && sleep 3600"]
    volumeMounts:
    - name: v
      mountPath: /data
  volumes:
  - name: v
    persistentVolumeClaim:
      claimName: to-be-deleted
```

After `kubectl delete pod writer` and `kubectl delete pvc to-be-deleted`, the PV enters `Released`. The file `/ex-4-1/record` on the node is intact because `Retain` does not delete backing storage; it just locks the PV to the deleted claim via `spec.claimRef`.

---

## Exercise 4.2 Solution

```bash
kubectl patch pv ex-4-2-pv --type='json' -p='[{"op":"remove","path":"/spec/claimRef"}]'

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: reuser, namespace: ex-4-2}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: manual-4-2
EOF
```

The patch removes the pre-set `spec.claimRef`, transitioning the PV from whatever state it was in (due to the dangling claim) to `Available`. The new PVC `reuser` then binds because it matches. Capacity is fine (1Gi >= 500Mi), storage class matches.

---

## Exercise 4.3 Solution

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: doomed, namespace: ex-4-3}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: manual-4-3
```

After `kubectl delete pvc doomed`, the PV enters `Failed` because the Delete reclaim operation tries to remove backing storage but `hostPath` has no deletion primitive. The directory on the node is untouched. In practice, `Delete` only makes sense for dynamically provisioned PVs backed by a cloud provisioner (CSI); for `hostPath`, always use `Retain`.

---

## Exercise 5.1 Solution

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: shared-reader, namespace: ex-5-1}
spec:
  accessModes: ["ReadOnlyMany"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: manual-5-1
---
apiVersion: v1
kind: Pod
metadata: {name: reader-one, namespace: ex-5-1}
spec:
  containers:
  - name: r
    image: busybox:1.36
    command: ["sh", "-c", "cat /data/shared.txt; sleep 3600"]
    volumeMounts:
    - name: v
      mountPath: /data
      readOnly: true
  volumes:
  - name: v
    persistentVolumeClaim:
      claimName: shared-reader
---
apiVersion: v1
kind: Pod
metadata: {name: reader-two, namespace: ex-5-1}
spec:
  containers:
  - name: r
    image: busybox:1.36
    command: ["sh", "-c", "cat /data/shared.txt; sleep 3600"]
    volumeMounts:
    - name: v
      mountPath: /data
      readOnly: true
  volumes:
  - name: v
    persistentVolumeClaim:
      claimName: shared-reader
```

`ReadOnlyMany` permits multiple pods across multiple nodes to mount the volume read-only. Since kind is single-node, both pods land on the same node and share the file. The PVC is one claim; both pod specs reference the same `claimName`.

---

## Exercise 5.2 Solution

**Diagnosis.**

```bash
kubectl describe pvc -n ex-5-2 compound-fail | tail -n 10
kubectl describe pv ex-5-2-pv
```

Side by side:

- PV `storageClassName: tier-gold`, PVC `storageClassName: tier-silver`. Mismatch.
- PV `accessModes: [ReadWriteOnce]`, PVC `accessModes: [ReadWriteMany]`. Mismatch.
- PV capacity `1Gi`, PVC request `5Gi`. Mismatch.

Three independent criteria each rule out the binding. Fixing any two still leaves the PVC `Pending`; fixing all three is required.

**What the bug is and why.** The binder requires every criterion to match simultaneously. Even a fix to two of the three leaves the third unsatisfied.

**Fix.**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: compound-fail, namespace: ex-5-2}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: tier-gold
```

All three fields are corrected: storage class, access mode, and request size. Delete and re-apply the PVC.

---

## Exercise 5.3 Solution

```yaml
apiVersion: v1
kind: PersistentVolume
metadata: {name: ex-5-3-pv}
spec:
  capacity: {storage: 2Gi}
  accessModes: ["ReadWriteOnce", "ReadOnlyMany"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual-5-3
  hostPath: {path: /ex-5-3, type: DirectoryOrCreate}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: app-storage, namespace: ex-5-3}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 1Gi}}
  storageClassName: manual-5-3
---
apiVersion: v1
kind: Pod
metadata: {name: primary-app, namespace: ex-5-3}
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo production-data > /data/db && sleep 3600"]
    volumeMounts:
    - name: v
      mountPath: /data
  volumes:
  - name: v
    persistentVolumeClaim:
      claimName: app-storage
---
apiVersion: v1
kind: Pod
metadata: {name: backup-reader, namespace: ex-5-3}
spec:
  containers:
  - name: backup
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3 && cat /data/db && sleep 3600"]
    volumeMounts:
    - name: v
      mountPath: /data
      readOnly: true
  volumes:
  - name: v
    persistentVolumeClaim:
      claimName: app-storage
```

The PV supports both access modes; the PVC is bound as RWO. A second pod can still mount the PVC on the same node (kind is single-node), and by setting `volumeMounts[*].readOnly: true` the pod's write attempts fail with `Read-only file system`. This is the static-PV pattern for a primary application plus a read-only backup sidecar.

---

## Common Mistakes

**1. Confusing the access-mode matching direction.** The PV's access modes must contain all of the PVC's. A PVC asking `[ReadWriteOnce, ReadOnlyMany]` needs a PV that supports both. Thinking "the PVC needs ReadWriteOnce and the PV supports that, good" misses the additional `ReadOnlyMany` requirement.

**2. Leaving `storageClassName` unset on a PVC.** If the cluster has a default StorageClass, the admission controller stamps the default name. Your PVC now looks for PVs with that class, not the static ones you created. Always explicitly set `storageClassName` on both the PV and PVC to the same string.

**3. Not removing `spec.claimRef` when reusing a Released PV.** The Released state persists until the administrator intervenes. A new PVC applied while the claimRef is still set stays Pending.

**4. Using `volumeName` on a PVC without matching the other fields.** Setting `volumeName: my-pv` does not override capacity or access-mode matching; it just narrows the candidate set to that one PV. The other criteria still have to match.

**5. Requesting more storage than any PV offers.** The request is a minimum, not a cap. A 1Gi PV cannot satisfy a 2Gi request. Check the PV's actual capacity before writing the PVC.

**6. Mounting a PVC with RWO in two pods on different nodes.** On a real cluster, RWO is enforced at the volume-attachment level: the same volume cannot attach to two nodes. Both pods stay Pending. On kind (single-node) this works, but production rehearsals should use RWX or confirm node affinity.

**7. Writing pod specs that reference a PVC directly as a `hostPath` or by another wrong field.** The correct form is `spec.volumes[*].persistentVolumeClaim.claimName`. The volume is then referenced in `volumeMounts[*].name` like any other volume. Directly naming the PV in the pod spec does not work.

**8. Deleting a PV while a pod still mounts its PVC.** The PV does not actually delete until the PVC releases it. The PV enters `Terminating` phase. If you need to delete the PV cleanly, first delete the pod, then the PVC, then the PV.

---

## Verification Commands Cheat Sheet

| Check | Command |
|---|---|
| PVC phase | `kubectl get pvc -n <ns> <name> -o jsonpath='{.status.phase}'` |
| PVC bound PV | `kubectl get pvc -n <ns> <name> -o jsonpath='{.spec.volumeName}'` |
| PVC access modes (as offered) | `kubectl get pvc -n <ns> <name> -o jsonpath='{.status.accessModes}'` |
| PVC capacity (as offered) | `kubectl get pvc -n <ns> <name> -o jsonpath='{.status.capacity.storage}'` |
| PVC events | `kubectl describe pvc -n <ns> <name>` |
| PV phase | `kubectl get pv <name> -o jsonpath='{.status.phase}'` |
| PV claim reference | `kubectl get pv <name> -o jsonpath='{.spec.claimRef.namespace}/{.spec.claimRef.name}'` |
| PV backing host directory | `kubectl get pv <name> -o jsonpath='{.spec.hostPath.path}'` |
| Remove stale claimRef | `kubectl patch pv <name> --type='json' -p='[{"op":"remove","path":"/spec/claimRef"}]'` |
| All PVs in specific storage class | `kubectl get pv --field-selector=spec.storageClassName=<class>` |
