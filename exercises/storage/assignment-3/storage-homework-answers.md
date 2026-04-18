# StorageClasses and Dynamic Provisioning Homework Answers

Complete solutions. Level 3 and Level 5 debugging answers use the three-stage structure.

---

## Exercise 1.1 Solution

```bash
kubectl get storageclass
kubectl get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}'
```

The `(default)` marker in `kubectl get sc` output comes from the annotation `storageclass.kubernetes.io/is-default-class: "true"`. The jsonpath query filters on that annotation and returns only matching StorageClass names. kind ships with exactly one default, `standard`.

---

## Exercise 1.2 Solution

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: defaulted, namespace: ex-1-2}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
```

When `storageClassName` is absent, the DefaultStorageClass admission controller mutates the PVC to add `storageClassName: standard` (the default). The PVC is then Pending because the `standard` StorageClass uses `WaitForFirstConsumer` binding mode and no pod has referenced it yet.

---

## Exercise 1.3 Solution

```bash
kubectl get sc standard -o jsonpath='{.provisioner}/{.reclaimPolicy}/{.volumeBindingMode}/{.allowVolumeExpansion}'
```

Output: `rancher.io/local-path/Delete/WaitForFirstConsumer/false`. This is the exact out-of-box configuration kind provides. None of those fields is customizable post-creation (StorageClass specs are mostly immutable; you would recreate the class to change them).

---

## Exercise 2.1 Solution

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: dyn-claim, namespace: ex-2-1}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: standard
---
apiVersion: v1
kind: Pod
metadata: {name: dyn-pod, namespace: ex-2-1}
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo dynamic-hello > /data/f && sleep 3600"]
    volumeMounts:
    - name: v
      mountPath: /data
  volumes:
  - name: v
    persistentVolumeClaim:
      claimName: dyn-claim
```

Applying the PVC first leaves it Pending. Applying the pod references the PVC, which triggers `rancher.io/local-path` to provision a new PV named `pvc-<random-uid>`, bind it to the PVC, and allow the pod to start. The full flow from apply to Running typically takes 5-15 seconds.

---

## Exercise 2.2 Solution

Two PVCs and two pods:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: static-claim, namespace: ex-2-2}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: manual
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: dynamic-claim, namespace: ex-2-2}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: standard
---
apiVersion: v1
kind: Pod
metadata: {name: static-app, namespace: ex-2-2}
spec:
  containers:
  - {name: app, image: busybox:1.36, command: ["sleep", "3600"], volumeMounts: [{name: v, mountPath: /data}]}
  volumes:
  - {name: v, persistentVolumeClaim: {claimName: static-claim}}
---
apiVersion: v1
kind: Pod
metadata: {name: dynamic-app, namespace: ex-2-2}
spec:
  containers:
  - {name: app, image: busybox:1.36, command: ["sleep", "3600"], volumeMounts: [{name: v, mountPath: /data}]}
  volumes:
  - {name: v, persistentVolumeClaim: {claimName: dynamic-claim}}
```

The static PVC binds to `ex-2-2-static` (the administrator-created PV). The dynamic PVC gets a freshly provisioned PV with a name like `pvc-<uid>`.

---

## Exercise 2.3 Solution

Execute the deletions in order. For local-path PVs with `reclaimPolicy: Delete`, the provisioner removes the PV (and the backing directory on the node) shortly after the PVC is deleted. For `ex-2-2-static` with `reclaimPolicy: Retain`, the PV enters `Released` with a dangling `spec.claimRef`. The dynamic PV no longer shows up in `kubectl get pv`.

---

## Exercise 3.1 Solution

**Diagnosis.**

```bash
kubectl get pvc -n ex-3-1 typo-class
kubectl describe pvc -n ex-3-1 typo-class | tail -n 10
```

The describe shows the PVC is Pending. The StorageClass `stanrad` does not exist; `kubectl get sc` confirms only `standard` is present.

**What the bug is and why.** The PVC spec's `storageClassName` is a typo for `standard`. Because that class does not exist, no provisioner watches the PVC, and because there is no statically provisioned PV with `storageClassName: stanrad` either, the PVC has no path to binding.

**Fix.** Change the PVC's `storageClassName` to `standard`.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: typo-class, namespace: ex-3-1}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: standard
```

Delete and re-apply the PVC (`storageClassName` is immutable post-creation). Apply a consumer pod to trigger WaitForFirstConsumer provisioning.

---

## Exercise 3.2 Solution

**Diagnosis.**

```bash
kubectl get pods -n local-path-storage
kubectl describe pvc -n ex-3-2 no-provisioner | tail -n 15
```

The provisioner deployment has 0 replicas; no pod is running. PVC events show `waiting for a volume to be created, either by external provisioner "rancher.io/local-path" or manually created by system administrator`.

**What the bug is and why.** Dynamic provisioning requires the provisioner controller to be running. With the deployment scaled to zero, no controller is watching PVCs for the `standard` class. The PVC is correctly authored but has no one to service it.

**Fix.** Scale the provisioner back up.

```bash
kubectl scale -n local-path-storage deployment/local-path-provisioner --replicas=1
```

The provisioner pod starts within seconds, sees the existing Pending PVC plus the pod referencing it, and creates the PV. The pod reaches `Running` shortly after.

---

## Exercise 3.3 Solution

**Diagnosis.**

```bash
kubectl get sc ex-3-3-fake -o jsonpath='{.provisioner}'
kubectl describe pvc -n ex-3-3 ghost-claim | tail -n 15
```

Provisioner is `example.com/nonexistent`. No controller in the cluster claims that provisioner name. PVC events show the provisioning attempt timing out or never happening.

**What the bug is and why.** The StorageClass is authored correctly from a schema perspective: name, provisioner, reclaim policy, binding mode. But Kubernetes does not validate that the `provisioner` name corresponds to a running controller. The PVC stays Pending because no controller acts on the provisioning intent.

**Fix.** Change the PVC's `storageClassName` to a StorageClass with a real provisioner.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: ghost-claim, namespace: ex-3-3}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: standard
```

Delete the old PVC and reapply (immutable field). Then apply a pod to trigger provisioning.

---

## Exercise 4.1 Solution

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: {name: ex-4-1-custom}
provisioner: rancher.io/local-path
reclaimPolicy: Retain
volumeBindingMode: Immediate
allowVolumeExpansion: true
```

StorageClasses are cluster-scoped; apply with `kubectl apply -f`. No namespace is set.

---

## Exercise 4.2 Solution

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: growable, namespace: ex-4-2}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: ex-4-2-expand
---
apiVersion: v1
kind: Pod
metadata: {name: grower, namespace: ex-4-2}
spec:
  containers:
  - {name: app, image: busybox:1.36, command: ["sleep", "3600"], volumeMounts: [{name: v, mountPath: /data}]}
  volumes:
  - {name: v, persistentVolumeClaim: {claimName: growable}}
```

Expansion command:

```bash
kubectl patch pvc -n ex-4-2 growable -p '{"spec":{"resources":{"requests":{"storage":"1Gi"}}}}'
```

For `rancher.io/local-path`, the expansion updates the status immediately because the backend is a host directory. For CSI-backed classes (AWS EBS, Azure Disk), the resize is a multi-step operation: the external resizer controller calls the cloud API to grow the volume, then the kubelet or CSI node plugin resizes the filesystem. The PVC status has a `FileSystemResizePending` condition that clears when the node-side resize completes.

---

## Exercise 4.3 Solution

Two PVCs, no pods:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: immediately-bound, namespace: ex-4-3}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: ex-4-3-immediate
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: wait-bound, namespace: ex-4-3}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: ex-4-3-wait
```

`immediately-bound` binds on apply: the provisioner sees the PVC, creates a PV, and the PV binds within seconds. `wait-bound` stays Pending. If you then apply a pod referencing `wait-bound`, the provisioner finally creates the PV, because the first consumer exists. The takeaway is that `WaitForFirstConsumer` is appropriate for node-local storage (the provisioner needs the topology info that only arrives when the pod gets scheduled).

---

## Exercise 5.1 Solution

```bash
# Set ex-5-1-new-default as default, unset standard:
kubectl annotate sc standard storageclass.kubernetes.io/is-default-class-
kubectl annotate sc ex-5-1-new-default storageclass.kubernetes.io/is-default-class=true

# Verify only one default:
kubectl get sc | grep -c "(default)"   # 1
kubectl get sc -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}'
# ex-5-1-new-default

# Restore:
kubectl annotate sc ex-5-1-new-default storageclass.kubernetes.io/is-default-class-
kubectl annotate sc standard storageclass.kubernetes.io/is-default-class=true
```

The trailing `-` on `kubectl annotate` removes the annotation. The trick on switching defaults is to remove the old one first, add the new one second. If you set the new one before removing the old one, the cluster has two defaults momentarily, and any PVC applied during that window gets non-deterministic assignment.

---

## Exercise 5.2 Solution

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: shrink-happens-later, namespace: ex-5-2}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: ex-5-2-expand
---
apiVersion: v1
kind: Pod
metadata: {name: sizer, namespace: ex-5-2}
spec:
  containers:
  - {name: app, image: busybox:1.36, command: ["sleep", "3600"], volumeMounts: [{name: v, mountPath: /data}]}
  volumes:
  - {name: v, persistentVolumeClaim: {claimName: shrink-happens-later}}
```

After the pod is Ready, fill the volume:

```bash
kubectl exec -n ex-5-2 sizer -- dd if=/dev/zero of=/data/fill bs=1M count=400
```

Expand:

```bash
kubectl patch pvc -n ex-5-2 shrink-happens-later -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'
```

`status.capacity.storage` on the PVC updates to 2Gi within about 15 seconds. `rancher.io/local-path` does not enforce a size quota on the backing directory; the PVC status is the authoritative Kubernetes-level record. For CSI-backed classes, `df -h` inside the container would report the new size, and in some cases a pod restart is required for the filesystem resize to take effect (watch for the `FileSystemResizePending` PVC condition).

---

## Exercise 5.3 Solution

Three StorageClasses:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: {name: ex-5-3-database}
provisioner: rancher.io/local-path
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: {name: ex-5-3-cache}
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: {name: ex-5-3-archive}
provisioner: rancher.io/local-path
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

Three PVCs and three pods in `ex-5-3`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: db-claim, namespace: ex-5-3}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 5Gi}}
  storageClassName: ex-5-3-database
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: cache-claim, namespace: ex-5-3}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 1Gi}}
  storageClassName: ex-5-3-cache
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: archive-claim, namespace: ex-5-3}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 10Gi}}
  storageClassName: ex-5-3-archive
---
apiVersion: v1
kind: Pod
metadata: {name: db, namespace: ex-5-3}
spec:
  containers:
  - {name: app, image: busybox:1.36, command: ["sleep", "3600"], volumeMounts: [{name: v, mountPath: /data}]}
  volumes: [{name: v, persistentVolumeClaim: {claimName: db-claim}}]
---
apiVersion: v1
kind: Pod
metadata: {name: cache, namespace: ex-5-3}
spec:
  containers:
  - {name: app, image: busybox:1.36, command: ["sleep", "3600"], volumeMounts: [{name: v, mountPath: /data}]}
  volumes: [{name: v, persistentVolumeClaim: {claimName: cache-claim}}]
---
apiVersion: v1
kind: Pod
metadata: {name: archive, namespace: ex-5-3}
spec:
  containers:
  - {name: app, image: busybox:1.36, command: ["sleep", "3600"], volumeMounts: [{name: v, mountPath: /data}]}
  volumes: [{name: v, persistentVolumeClaim: {claimName: archive-claim}}]
```

After applying, the pods each trigger provisioning of their PVC. Records the PV name for each (the dynamic name). After deleting all pods and PVCs:

- `db-claim` was on a `Retain` class: the PV stays `Released`.
- `cache-claim` was on a `Delete` class: the PV is removed by the provisioner.
- `archive-claim` was on a `Retain` class: the PV stays `Released`.

The strategy intent reflects real-world patterns: databases keep their data on `Retain` so accidental PVC deletion does not lose production records; caches are ephemeral so `Delete` is fine; archives that may grow get `allowVolumeExpansion: true` so they can be resized in place as storage requirements grow.

---

## Common Mistakes

**1. Assuming a StorageClass that does not exist in the cluster.** PVC Pending with a StorageClass name that does not match any existing class stays Pending with no binding attempts. Always `kubectl get sc` before authoring PVCs.

**2. Omitting `storageClassName` when the cluster has no default.** A PVC without an explicit class on a cluster with no default stays Pending with no attempted provisioning. Always set `storageClassName` explicitly in production.

**3. Setting two defaults.** When more than one StorageClass has `storageclass.kubernetes.io/is-default-class: "true"`, PVCs with no explicit class go to a non-deterministic default. Always remove the old default before setting a new one.

**4. Expecting `WaitForFirstConsumer` to provision on PVC apply.** The PVC stays Pending until a pod references it. Then the provisioner runs. This is correct behavior, not a bug.

**5. Trying to edit an immutable StorageClass field.** `provisioner`, `reclaimPolicy`, and `volumeBindingMode` are effectively immutable post-creation (Kubernetes will reject edits to most fields). To change them, delete and recreate the class; any PVC referencing the old class must be updated.

**6. Editing a PVC's `storageClassName` after creation.** The field is immutable once the PVC is created. You must delete and recreate the PVC to change it.

**7. Expecting `Delete` reclaim on `hostPath` or `local` volumes to remove the data.** For `hostPath`, `Delete` fails (the PV enters `Failed`). For the `rancher.io/local-path` provisioner specifically, `Delete` does remove the backing directory, because the provisioner implements the delete semantics. Not all provisioners do.

**8. Requesting volume expansion on a StorageClass without `allowVolumeExpansion: true`.** The API rejects the patch. The class must have the flag enabled at creation; you cannot enable it retroactively on an existing class.

---

## Verification Commands Cheat Sheet

| Check | Command |
|---|---|
| List StorageClasses | `kubectl get sc` |
| Default StorageClass name | `kubectl get sc -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}'` |
| StorageClass provisioner | `kubectl get sc <name> -o jsonpath='{.provisioner}'` |
| StorageClass binding mode | `kubectl get sc <name> -o jsonpath='{.volumeBindingMode}'` |
| Set default annotation | `kubectl annotate sc <name> storageclass.kubernetes.io/is-default-class=true` |
| Remove default annotation | `kubectl annotate sc <name> storageclass.kubernetes.io/is-default-class-` |
| Expand a PVC | `kubectl patch pvc <name> -p '{"spec":{"resources":{"requests":{"storage":"<new>"}}}}'` |
| PVC expansion status | `kubectl get pvc <name> -o jsonpath='{.status.conditions[*].type}'` (look for `FileSystemResizePending`) |
| Provisioner pod status | `kubectl get pods -n local-path-storage` |
| PVC provisioning events | `kubectl describe pvc <name>` (look at Events) |
