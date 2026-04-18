# Volumes and PersistentVolumes Homework

Fifteen exercises covering `emptyDir`, `hostPath`, PersistentVolume creation, the five PV lifecycle phases, reclaim policies, label selectors, and node affinity. Work through the tutorial first. The exercises assume you can read `kubectl describe pv` and identify why a PV is in a particular phase.

Exercise namespaces follow `ex-<level>-<exercise>` for namespaced resources. PersistentVolumes are cluster-scoped; the setup blocks name them with an `ex-<level>-<exercise>` prefix to keep them visually separate. The global cleanup block at the bottom removes every namespace and every PV created during the exercises.

---

## Level 1: Volume Types

### Exercise 1.1

**Objective:** Create a pod with an `emptyDir` shared between two containers and prove writes from one are visible to the other.

**Setup:**

```bash
kubectl create namespace ex-1-1
```

**Task:** In namespace `ex-1-1`, create a pod named `shared-scratch` with two containers both running `busybox:1.36`. The `writer` container writes `hello` to `/data/message` once and sleeps. The `reader` container reads `/data/message` once (after a short delay to let the write complete) and sleeps. Both mount the same `emptyDir` at `/data`.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/shared-scratch -n ex-1-1 --timeout=60s

kubectl logs -n ex-1-1 shared-scratch -c reader
# Expected: hello

kubectl exec -n ex-1-1 shared-scratch -c writer -- cat /data/message
# Expected: hello

kubectl get pod -n ex-1-1 shared-scratch -o jsonpath='{.spec.volumes[0].emptyDir}'
# Expected: {}
```

---

### Exercise 1.2

**Objective:** Create a pod that mounts a `hostPath` directory from the kind node and reads a file that was placed there out of band.

**Setup:**

```bash
kubectl create namespace ex-1-2
nerdctl exec kind-control-plane sh -c 'mkdir -p /host-1-2 && echo "node-preloaded" > /host-1-2/content'
```

**Task:** In namespace `ex-1-2`, create a pod named `host-consumer` running image `busybox:1.36` with command `["sleep", "3600"]`. Mount `/host-1-2` on the node at `/data` in the container, using `type: Directory`.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/host-consumer -n ex-1-2 --timeout=60s

kubectl exec -n ex-1-2 host-consumer -- cat /data/content
# Expected: node-preloaded

kubectl get pod -n ex-1-2 host-consumer -o jsonpath='{.spec.volumes[0].hostPath.type}'
# Expected: Directory
```

---

### Exercise 1.3

**Objective:** Demonstrate that `emptyDir` does not persist across pod deletion but `hostPath` does.

**Setup:**

```bash
kubectl create namespace ex-1-3
nerdctl exec kind-control-plane mkdir -p /host-1-3
```

**Task:** In namespace `ex-1-3`, create a pod `ephemeral-writer` running `busybox:1.36` that writes two files on startup: `mark-A` to an `emptyDir` at `/empty` and `mark-B` to a `hostPath` at `/host`. Then delete and recreate the pod with the same specs (except the `emptyDir` content should be missing and the `hostPath` content should still be there).

**Verification:**

```bash
# First pod applies, writes both files, then is deleted
kubectl wait --for=condition=Ready pod/ephemeral-writer -n ex-1-3 --timeout=60s
kubectl exec -n ex-1-3 ephemeral-writer -- cat /empty/mark-A
# Expected: A
kubectl exec -n ex-1-3 ephemeral-writer -- cat /host/mark-B
# Expected: B

kubectl delete pod -n ex-1-3 ephemeral-writer

# Recreate with the same spec, do NOT overwrite the files this time
# (setup blocks allow you to write a second pod spec that only reads)

kubectl apply -n ex-1-3 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: ephemeral-writer
spec:
  containers:
  - name: probe
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - {name: empty, mountPath: /empty}
    - {name: host,  mountPath: /host}
  volumes:
  - name: empty
    emptyDir: {}
  - name: host
    hostPath:
      path: /host-1-3
      type: Directory
EOF

kubectl wait --for=condition=Ready pod/ephemeral-writer -n ex-1-3 --timeout=60s

kubectl exec -n ex-1-3 ephemeral-writer -- ls /empty
# Expected: (empty directory; no mark-A)

kubectl exec -n ex-1-3 ephemeral-writer -- cat /host/mark-B
# Expected: B
```

---

## Level 2: PersistentVolume Creation

### Exercise 2.1

**Objective:** Create a statically provisioned PersistentVolume backed by `hostPath` and verify it enters the `Available` phase.

**Setup:**

```bash
nerdctl exec kind-control-plane mkdir -p /ex-2-1
```

**Task:** Create a cluster-scoped PersistentVolume named `ex-2-1-pv` with capacity 2Gi, access mode `ReadWriteOnce`, reclaim policy `Retain`, `storageClassName: manual`, and `hostPath` backend at `/ex-2-1` with `type: DirectoryOrCreate`.

**Verification:**

```bash
kubectl get pv ex-2-1-pv -o jsonpath='{.status.phase}'
# Expected: Available

kubectl get pv ex-2-1-pv -o jsonpath='{.spec.capacity.storage}'
# Expected: 2Gi

kubectl get pv ex-2-1-pv -o jsonpath='{.spec.accessModes[0]}'
# Expected: ReadWriteOnce

kubectl get pv ex-2-1-pv -o jsonpath='{.spec.persistentVolumeReclaimPolicy}'
# Expected: Retain
```

---

### Exercise 2.2

**Objective:** Create a PV with `ReadOnlyMany` access mode for shared read-only reference data.

**Setup:**

```bash
nerdctl exec kind-control-plane mkdir -p /ex-2-2 && nerdctl exec kind-control-plane sh -c 'echo shared > /ex-2-2/reference.txt'
```

**Task:** Create a PV named `ex-2-2-pv` with capacity 500Mi, access mode `ReadOnlyMany`, reclaim policy `Retain`, `storageClassName: manual`, and `hostPath` backend at `/ex-2-2`.

**Verification:**

```bash
kubectl get pv ex-2-2-pv -o jsonpath='{.status.phase}'
# Expected: Available

kubectl get pv ex-2-2-pv -o jsonpath='{.spec.accessModes[0]}'
# Expected: ReadOnlyMany

kubectl get pv ex-2-2-pv -o jsonpath='{.spec.hostPath.path}'
# Expected: /ex-2-2
```

---

### Exercise 2.3

**Objective:** Inspect a pre-existing PV and extract every key spec field in one JSON path query.

**Setup:**

```bash
nerdctl exec kind-control-plane mkdir -p /ex-2-3
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ex-2-3-pv
  labels:
    purpose: inspection
spec:
  capacity:
    storage: 750Mi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Delete
  storageClassName: manual
  hostPath:
    path: /ex-2-3
    type: DirectoryOrCreate
EOF
```

**Task:** Using `kubectl get pv ... -o jsonpath`, extract and print the capacity, the first access mode, the reclaim policy, the storage class, the hostPath path, and the label `purpose`, all in one shell command.

**Verification:**

```bash
kubectl get pv ex-2-3-pv -o jsonpath='{.spec.capacity.storage}/{.spec.accessModes[0]}/{.spec.persistentVolumeReclaimPolicy}/{.spec.storageClassName}/{.spec.hostPath.path}/{.metadata.labels.purpose}'
# Expected: 750Mi/ReadWriteOnce/Delete/manual//ex-2-3/inspection
```

---

## Level 3: Debugging

### Exercise 3.1

**Objective:** The PV below is not reaching `Available`. Diagnose the root cause and fix the PV spec.

**Setup:**

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
nerdctl exec kind-control-plane mkdir -p /ex-3-1
```

**Task:** Replace the PV with a corrected version so that `kubectl get pv ex-3-1-pv` reports phase `Available`.

**Verification:**

```bash
kubectl get pv ex-3-1-pv -o jsonpath='{.status.phase}'
# Expected: Available

kubectl get pv ex-3-1-pv -o jsonpath='{.spec.capacity.storage}'
# Expected: 1Gi (or any valid quantity like 1G)
```

---

### Exercise 3.2

**Objective:** The PV below is stuck in `Released`. Make it `Available` again so it can rebind without losing the data.

**Setup:**

```bash
nerdctl exec kind-control-plane mkdir -p /ex-3-2
nerdctl exec kind-control-plane sh -c 'echo keep-me > /ex-3-2/data'

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ex-3-2-pv
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /ex-3-2
    type: Directory
EOF

kubectl create namespace ex-3-2
kubectl apply -n ex-3-2 -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: temp-claim
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 500Mi
  storageClassName: manual
EOF

sleep 3
kubectl delete pvc -n ex-3-2 temp-claim
sleep 3
```

**Task:** `ex-3-2-pv` is now in `Released`. Without deleting it (which would lose the data reference), make it `Available` again so a new PVC can bind.

**Verification:**

```bash
kubectl get pv ex-3-2-pv -o jsonpath='{.status.phase}'
# Expected: Available

nerdctl exec kind-control-plane cat /ex-3-2/data
# Expected: keep-me
```

---

### Exercise 3.3

**Objective:** The PVC below is stuck in `Pending`. The PV `ex-3-3-pv` exists but does not bind. Find and fix the problem.

**Setup:**

```bash
nerdctl exec kind-control-plane mkdir -p /ex-3-3
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ex-3-3-pv
spec:
  capacity:
    storage: 500Mi
  accessModes: ["ReadOnlyMany"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /ex-3-3
    type: DirectoryOrCreate
EOF

kubectl create namespace ex-3-3
kubectl apply -n ex-3-3 -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: needy
spec:
  accessModes: ["ReadWriteMany"]
  resources:
    requests:
      storage: 200Mi
  storageClassName: manual
EOF
```

**Task:** The PVC `needy` is Pending. Adjust the PVC spec (do not change the PV; there are reasons the administrator cannot edit the PV in production) so that it binds. The fix must preserve the PVC's claim to ~200Mi of storage.

**Verification:**

```bash
kubectl get pvc -n ex-3-3 needy -o jsonpath='{.status.phase}'
# Expected: Bound

kubectl get pvc -n ex-3-3 needy -o jsonpath='{.spec.volumeName}'
# Expected: ex-3-3-pv
```

---

## Level 4: Configuration

### Exercise 4.1

**Objective:** Create a PV with node affinity pinning it to the kind control-plane node.

**Setup:**

```bash
nerdctl exec kind-control-plane mkdir -p /ex-4-1
```

**Task:** Create a PV named `ex-4-1-pv` using the `local` volume type (not `hostPath`) at `/ex-4-1`, with capacity 1Gi, access mode `ReadWriteOnce`, reclaim policy `Retain`, `storageClassName: manual`, and node affinity requiring `kubernetes.io/hostname = kind-control-plane`.

**Verification:**

```bash
kubectl get pv ex-4-1-pv -o jsonpath='{.status.phase}'
# Expected: Available

kubectl get pv ex-4-1-pv -o jsonpath='{.spec.local.path}'
# Expected: /ex-4-1

kubectl get pv ex-4-1-pv -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}'
# Expected: kind-control-plane
```

---

### Exercise 4.2

**Objective:** Create two PVs with different labels and show that a PVC with a label selector binds to exactly one.

**Setup:**

```bash
nerdctl exec kind-control-plane sh -c 'mkdir -p /ex-4-2-ssd /ex-4-2-hdd'
kubectl create namespace ex-4-2
```

**Task:** Create two PVs `ex-4-2-ssd` and `ex-4-2-hdd`, both with capacity 1Gi, access mode RWO, reclaim `Retain`, `storageClassName: manual`, `hostPath` to the respective directory. Label `ex-4-2-ssd` with `tier=ssd` and `ex-4-2-hdd` with `tier=hdd`. In namespace `ex-4-2`, create a PVC named `want-ssd` that uses `matchLabels: {tier: ssd}` in its `spec.selector`.

**Verification:**

```bash
kubectl get pvc -n ex-4-2 want-ssd -o jsonpath='{.spec.volumeName}'
# Expected: ex-4-2-ssd

kubectl get pv ex-4-2-ssd -o jsonpath='{.status.phase}'
# Expected: Bound

kubectl get pv ex-4-2-hdd -o jsonpath='{.status.phase}'
# Expected: Available
```

---

### Exercise 4.3

**Objective:** Compare `Retain` and `Delete` reclaim policies side by side on `hostPath`-backed PVs, and document what happens to the backing directory.

**Setup:**

```bash
nerdctl exec kind-control-plane sh -c 'mkdir -p /ex-4-3-retain /ex-4-3-delete'
nerdctl exec kind-control-plane sh -c 'echo keep > /ex-4-3-retain/data && echo should-go > /ex-4-3-delete/data'
kubectl create namespace ex-4-3
```

**Task:** Create two PVs `ex-4-3-retain` (reclaim `Retain`) and `ex-4-3-delete` (reclaim `Delete`), both `hostPath`, both 500Mi, both RWO, both `storageClassName: manual`. Create two PVCs `claim-retain` and `claim-delete` each bound to the respective PV (via `spec.volumeName`). Delete both PVCs. Observe the resulting phase of each PV and confirm the directory on the node.

**Verification:**

```bash
# After the PVCs are created and then deleted:
kubectl get pv ex-4-3-retain -o jsonpath='{.status.phase}'
# Expected: Released (because Retain)

kubectl get pv ex-4-3-delete -o jsonpath='{.status.phase}' 2>/dev/null || echo "not found"
# Expected: Failed OR not found (hostPath Delete fails because the backend has no deletion semantics;
# the PV may be marked Failed. This is an important practical subtlety.)

nerdctl exec kind-control-plane cat /ex-4-3-retain/data
# Expected: keep

nerdctl exec kind-control-plane cat /ex-4-3-delete/data 2>/dev/null || echo "gone"
# Expected: should-go (because hostPath Delete does not actually delete host dirs)
```

---

## Level 5: Advanced

### Exercise 5.1

**Objective:** Design a PV strategy for an application that runs on the kind control-plane node and needs two distinct PVs: a `data-volume` (2Gi, RWO) and a `config-volume` (100Mi, ROX, labeled `purpose=config`).

**Setup:**

```bash
nerdctl exec kind-control-plane sh -c 'mkdir -p /ex-5-1-data /ex-5-1-config'
```

**Task:** Create both PVs with appropriate backends. Both must pin to the control-plane node via `nodeAffinity` (use `local` volume type for both), both use `storageClassName: manual`, the data volume is `Retain`, the config volume is `Retain`. Label the config volume with `purpose=config`. Name them `ex-5-1-data` and `ex-5-1-config`.

**Verification:**

```bash
kubectl get pv ex-5-1-data ex-5-1-config -o jsonpath='{.items[*].status.phase}'
# Expected: Available Available

kubectl get pv ex-5-1-data -o jsonpath='{.spec.capacity.storage}'
# Expected: 2Gi

kubectl get pv ex-5-1-config -o jsonpath='{.spec.capacity.storage}'
# Expected: 100Mi

kubectl get pv ex-5-1-config -o jsonpath='{.metadata.labels.purpose}'
# Expected: config
```

---

### Exercise 5.2

**Objective:** Diagnose why the PV below does not reach `Available` despite the `hostPath` directory existing and the spec being valid.

**Setup:**

```bash
nerdctl exec kind-control-plane mkdir -p /ex-5-2-primary

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ex-5-2-primary
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  claimRef:
    namespace: ghost-namespace
    name: ghost-claim
    kind: PersistentVolumeClaim
    apiVersion: v1
  hostPath:
    path: /ex-5-2-primary
    type: Directory
EOF
```

**Task:** The PV enters `Available` or stays in an odd bound-but-not-bound limbo because of a `claimRef` pointing at a PVC and namespace that do not exist. Fix the PV so that it is simply `Available` and can be claimed by a real PVC without any pre-binding hint.

**Verification:**

```bash
kubectl get pv ex-5-2-primary -o jsonpath='{.status.phase}'
# Expected: Available

kubectl get pv ex-5-2-primary -o jsonpath='{.spec.claimRef}' 2>/dev/null
# Expected: (empty; the claimRef has been removed)
```

---

### Exercise 5.3

**Objective:** Pre-provision a set of PVs for a specific workload: a three-replica statefulset-style workload will produce three PVCs named `data-app-0`, `data-app-1`, `data-app-2`. Author three PVs so that when those PVCs are created they each bind to exactly one PV.

**Setup:**

```bash
nerdctl exec kind-control-plane sh -c 'mkdir -p /ex-5-3-0 /ex-5-3-1 /ex-5-3-2'
kubectl create namespace ex-5-3
```

**Task:** Create three PVs `ex-5-3-pv-0`, `ex-5-3-pv-1`, `ex-5-3-pv-2`, each 500Mi, RWO, `storageClassName: manual`, `hostPath` to the respective directory. Use labels or pre-set `spec.claimRef` so that when the three PVCs `data-app-0`, `data-app-1`, `data-app-2` are later applied to namespace `ex-5-3`, each binds to exactly one PV in the 0-to-0, 1-to-1, 2-to-2 pattern.

Then apply the three PVCs and verify.

**Verification:**

```bash
# After creating PVs and then the PVCs:
kubectl get pvc -n ex-5-3 data-app-0 -o jsonpath='{.spec.volumeName}'
# Expected: ex-5-3-pv-0

kubectl get pvc -n ex-5-3 data-app-1 -o jsonpath='{.spec.volumeName}'
# Expected: ex-5-3-pv-1

kubectl get pvc -n ex-5-3 data-app-2 -o jsonpath='{.spec.volumeName}'
# Expected: ex-5-3-pv-2
```

---

## Cleanup

Delete every exercise namespace and every PV created. Also remove the host directories created on the kind node.

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 ex-3-2 ex-3-3 ex-4-2 ex-4-3 ex-5-3; do
  kubectl delete namespace "$ns" --ignore-not-found
done

kubectl delete pv ex-2-1-pv ex-2-2-pv ex-2-3-pv ex-3-1-pv ex-3-2-pv ex-3-3-pv \
                  ex-4-1-pv ex-4-2-ssd ex-4-2-hdd ex-4-3-retain ex-4-3-delete \
                  ex-5-1-data ex-5-1-config ex-5-2-primary \
                  ex-5-3-pv-0 ex-5-3-pv-1 ex-5-3-pv-2 --ignore-not-found

nerdctl exec kind-control-plane sh -c 'rm -rf /host-1-2 /host-1-3 /ex-2-1 /ex-2-2 /ex-2-3 \
  /ex-3-1 /ex-3-2 /ex-3-3 /ex-4-1 /ex-4-2-ssd /ex-4-2-hdd \
  /ex-4-3-retain /ex-4-3-delete /ex-5-1-data /ex-5-1-config /ex-5-2-primary \
  /ex-5-3-0 /ex-5-3-1 /ex-5-3-2'
```

## Key Takeaways

PersistentVolumes are cluster-scoped resources separate from pods. Capacity, access modes, reclaim policy, storage class, and the backend fields make up the PV spec. The five PV lifecycle phases are `Available`, `Bound`, `Released`, `Failed`, and (briefly) `Pending`. A PV with `reclaimPolicy: Retain` plus a deleted PVC ends up `Released`; removing `spec.claimRef` reverts it to `Available`. Labels on PVs combined with a PVC `selector` let administrators steer binding without StorageClasses. `spec.nodeAffinity` on local-backed PVs ensures consumers schedule onto the right node. `hostPath` does not implement `reclaimPolicy: Delete` semantics; the backing directory persists regardless.
