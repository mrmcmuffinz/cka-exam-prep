# StorageClasses and Dynamic Provisioning Tutorial

Assignments 1 and 2 assumed an administrator pre-created every PersistentVolume before any PVC claimed it. Real clusters rarely work that way. A StorageClass tells Kubernetes "when a PVC requests storage of this type, run this provisioner to create a PV automatically." Dynamic provisioning removes the administrator's pre-creation step and lets developers self-serve storage through PVC authorship alone.

kind ships with a default StorageClass named `standard` backed by the `rancher.io/local-path` provisioner. This provisioner creates a PV whose backend is a directory under `/var/local-path-provisioner/<uid>/` on the node. That is enough to exercise every StorageClass concept the CKA expects: creating a custom class, switching the default, setting binding modes, enabling expansion. This tutorial uses `local-path` throughout; CSI driver installation is outside CKA scope.

## Prerequisites

Any single-node kind cluster works. See `docs/cluster-setup.md#single-node-kind-cluster` for the creation command. Complete `exercises/storage/assignment-1` and `/assignment-2` first; this tutorial assumes fluency with PVs and PVCs.

Verify the cluster and the default StorageClass.

```bash
kubectl get nodes
kubectl get storageclass
```

Expected output for the second command (a single row, with `(default)` on the standard class):

```
NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  ...
```

The `(default)` marker is set by the annotation `storageclass.kubernetes.io/is-default-class: "true"` on the `standard` StorageClass.

Create the tutorial namespace.

```bash
kubectl create namespace tutorial-storage
kubectl config set-context --current --namespace=tutorial-storage
```

## Part 1: The StorageClass spec

**Spec field reference for `StorageClass`:**

- **`provisioner`**
  - **Type:** string.
  - **Valid values:** the name of a provisioner (`rancher.io/local-path`, `kubernetes.io/aws-ebs`, `ebs.csi.aws.com`, `pd.csi.storage.gke.io`, and so on). For static provisioning, use `kubernetes.io/no-provisioner`.
  - **Default:** none; required.
  - **Failure mode when misconfigured:** if the provisioner name does not match any controller running in the cluster, PVCs using this StorageClass stay `Pending` indefinitely. Events include `waiting for a volume to be created` but no volume is created because no controller claims the work.

- **`parameters`**
  - **Type:** map of strings.
  - **Valid values:** provisioner-specific. For `rancher.io/local-path`, parameters include `nodePath` and `pathPattern`. For AWS EBS: `type`, `fsType`, `iopsPerGB`, `encrypted`.
  - **Default:** empty map.
  - **Failure mode when misconfigured:** an invalid parameter for the specific provisioner causes the provisioner to log an error and the PVC to stay `Pending`.

- **`reclaimPolicy`**
  - **Type:** string.
  - **Valid values:** `Delete`, `Retain`.
  - **Default:** `Delete` (yes, different from static PV default which is `Retain`).
  - **Failure mode when misconfigured:** `Recycle` is not allowed for StorageClasses (the API rejects it). Choosing `Delete` for data you actually want to keep leads to data loss when the PVC is deleted.

- **`volumeBindingMode`**
  - **Type:** string.
  - **Valid values:** `Immediate`, `WaitForFirstConsumer`.
  - **Default:** `Immediate`.
  - **Failure mode when misconfigured:** `Immediate` for a provisioner that needs topology awareness (zone, node affinity) may produce a PV that cannot be mounted by the pod that eventually schedules on the wrong node. `WaitForFirstConsumer` with a workload that expects storage to exist before scheduling makes debugging harder because the PVC stays `Pending` until a pod references it.

- **`allowVolumeExpansion`**
  - **Type:** bool.
  - **Valid values:** `true`, `false`.
  - **Default:** `false`.
  - **Failure mode when misconfigured:** attempting to edit a PVC's request size when the class does not allow expansion produces an API-level error. You cannot enable expansion retroactively by editing the StorageClass.

- **`mountOptions`**
  - **Type:** array of strings.
  - **Valid values:** any mount options the filesystem driver accepts.
  - **Default:** empty.

Apply a custom StorageClass that mirrors the defaults but is explicitly named.

```bash
kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tut-local
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: false
EOF

kubectl get storageclass tut-local
```

Expected output: a row naming `tut-local` with the exact fields above. StorageClasses are cluster-scoped (no namespace).

## Part 2: Dynamic provisioning

Apply a PVC that references `tut-local`. With binding mode `WaitForFirstConsumer`, the PVC stays `Pending` until a pod references it.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-claim
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 500Mi
  storageClassName: tut-local
EOF

kubectl get pvc dynamic-claim
```

Expected output:

```
NAME            STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
dynamic-claim   Pending                                      tut-local      5s
```

The PVC is `Pending`. The class's `WaitForFirstConsumer` is why. Apply a pod that uses the PVC; provisioning triggers.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: dynamic-pod
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo dynamic-hello > /data/file && sleep 3600"]
    volumeMounts:
    - name: v
      mountPath: /data
  volumes:
  - name: v
    persistentVolumeClaim:
      claimName: dynamic-claim
EOF

kubectl wait --for=condition=Ready pod/dynamic-pod --timeout=120s
kubectl get pvc dynamic-claim
kubectl get pv
```

Expected output:

```
NAME            STATUS   VOLUME                                     CAPACITY   ...
dynamic-claim   Bound    pvc-<random-uid>                           500Mi      ...
```

And the PV list now has a newly-created PV with a name like `pvc-<uid>`. That PV was provisioned by `rancher.io/local-path` in response to the pod referencing the PVC. Verify the pod can read and write.

```bash
kubectl exec dynamic-pod -- cat /data/file
# Expected: dynamic-hello
```

Delete the pod and PVC. Because reclaim policy is `Delete`, the PV is also removed.

```bash
kubectl delete pod dynamic-pod
kubectl delete pvc dynamic-claim
sleep 5
kubectl get pv
# Expected: no PV named pvc-<uid> (the provisioner deleted it)
```

## Part 3: `Immediate` vs `WaitForFirstConsumer`

Apply a StorageClass with `Immediate` binding mode and observe the PV get created before any pod references the PVC.

```bash
kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tut-immediate
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: false
EOF

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: immediate-claim
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 500Mi
  storageClassName: tut-immediate
EOF

sleep 5
kubectl get pvc immediate-claim
```

Expected output:

```
NAME              STATUS   VOLUME            CAPACITY   ...
immediate-claim   Bound    pvc-<random-uid>  500Mi      ...
```

The PVC is already `Bound` even though no pod has referenced it. The provisioner ran at PVC-apply time. `Immediate` mode is fine for provisioners that do not need topology awareness, but for node-local volumes (like `rancher.io/local-path`) it risks pinning the PV to a node that the eventual pod does not schedule to. This is exactly why `WaitForFirstConsumer` is the default for node-local provisioners. Clean up.

```bash
kubectl delete pvc immediate-claim
sleep 3
```

## Part 4: Volume expansion

Apply a StorageClass with expansion enabled.

```bash
kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tut-expandable
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: expand-claim
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 500Mi
  storageClassName: tut-expandable
---
apiVersion: v1
kind: Pod
metadata:
  name: expand-pod
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: v
      mountPath: /data
  volumes:
  - name: v
    persistentVolumeClaim:
      claimName: expand-claim
EOF
kubectl wait --for=condition=Ready pod/expand-pod --timeout=120s
kubectl get pvc expand-claim -o jsonpath='{.status.capacity.storage}'
```

Expected output:

```
500Mi
```

Now edit the PVC to request more.

```bash
kubectl patch pvc expand-claim -p '{"spec":{"resources":{"requests":{"storage":"1Gi"}}}}'
kubectl get pvc expand-claim -o jsonpath='{.spec.resources.requests.storage}{"\n"}'
```

Expected output:

```
1Gi
```

The spec request is now 1Gi. However the status capacity may still show 500Mi for a moment; the actual resize happens at the filesystem level, which for some provisioners requires a pod restart. For `rancher.io/local-path`, which just mounts a host directory, the expansion is effectively immediate and the `status.capacity` updates within a few seconds.

```bash
sleep 10
kubectl get pvc expand-claim -o jsonpath='{.status.capacity.storage}{"\n"}'
```

Expected output:

```
1Gi
```

For CSI-backed classes like `ebs.csi.aws.com`, the expansion path is more involved: the controller resizes the underlying block device, then the node-component resizes the filesystem, which may require the pod to restart (tracked by the `FileSystemResizePending` condition on the PVC). Clean up.

```bash
kubectl delete pod expand-pod
kubectl delete pvc expand-claim
```

## Part 5: Changing the default StorageClass

Only one StorageClass in a cluster should have the `storageclass.kubernetes.io/is-default-class: "true"` annotation. Changing the default is a two-step operation: clear the annotation on the old default, set it on the new default.

First, confirm which class is currently the default.

```bash
kubectl get storageclass
```

The `(default)` marker appears next to the default. Clear the annotation on `standard` and set it on `tut-local`.

```bash
kubectl annotate storageclass standard storageclass.kubernetes.io/is-default-class-
kubectl annotate storageclass tut-local storageclass.kubernetes.io/is-default-class=true

kubectl get storageclass
```

Expected output: `(default)` now appears on `tut-local`, not on `standard`. Any PVC applied without an explicit `storageClassName` will now use `tut-local`.

Restore the original default before continuing.

```bash
kubectl annotate storageclass tut-local storageclass.kubernetes.io/is-default-class-
kubectl annotate storageclass standard storageclass.kubernetes.io/is-default-class=true
kubectl get storageclass
```

Expected: `(default)` is back on `standard`.

**Gotcha:** if you accidentally leave the annotation on two classes simultaneously, Kubernetes picks one non-deterministically. Always verify with `kubectl get storageclass` after any default change.

## Part 6: Comparing static and dynamic provisioning

Static (assignments 1 and 2): administrator creates a PV, then a PVC binds to it. Dynamic (this assignment): administrator creates only a StorageClass; a PVC triggers PV creation on demand.

| Concern | Static | Dynamic |
|---|---|---|
| Who creates PVs | administrator, ahead of time | provisioner, on demand |
| PVC author must know which PV exists | yes | no |
| PV capacity matches exactly | possibly oversized | matches request |
| When provisioning can happen | any time (before or after PVC) | only after PVC (and only after pod if WaitForFirstConsumer) |
| StorageClass needed | optional (use `""` or `manual`) | required |
| Suitable for pre-populated data | yes (PV can reference existing data) | no (provisioner creates empty volume) |

Dynamic is the default in production because it scales with developer self-service. Static is used when data already exists (pre-seeded databases, legacy backups) or when the administrator wants strict control over which pods get which specific storage.

## Cleanup

Delete the tutorial namespace and the custom StorageClasses.

```bash
kubectl delete namespace tutorial-storage
kubectl delete storageclass tut-local tut-immediate tut-expandable
kubectl config set-context --current --namespace=default
```

## Reference Commands

| Task | Command |
|---|---|
| List StorageClasses | `kubectl get storageclass` (or `sc`) |
| Identify default StorageClass | Look for `(default)` marker in output |
| View a StorageClass | `kubectl describe sc <name>` |
| Set a StorageClass as default | `kubectl annotate sc <name> storageclass.kubernetes.io/is-default-class=true` |
| Clear default marker | `kubectl annotate sc <name> storageclass.kubernetes.io/is-default-class-` |
| Resize a PVC | `kubectl patch pvc <name> -p '{"spec":{"resources":{"requests":{"storage":"<new>"}}}}'` |
| Find the PV behind a PVC | `kubectl get pvc <name> -o jsonpath='{.spec.volumeName}'` |

## Key Takeaways

A StorageClass is a cluster-scoped resource that names a provisioner plus parameters for dynamic PV creation. The default StorageClass is marked with `storageclass.kubernetes.io/is-default-class: "true"`. A PVC without `storageClassName` uses the default; with an explicit name, it uses that class. `volumeBindingMode: WaitForFirstConsumer` delays provisioning until a pod references the PVC, which is the right choice for node-local provisioners. `allowVolumeExpansion: true` lets you edit a PVC's request size; the underlying provisioner does the work, and for CSI drivers may require a pod restart (tracked via the `FileSystemResizePending` PVC condition). Only one StorageClass should carry the default annotation at a time. kind's `rancher.io/local-path` provisioner is sufficient for every exercise in this assignment; no CSI driver install is needed.
