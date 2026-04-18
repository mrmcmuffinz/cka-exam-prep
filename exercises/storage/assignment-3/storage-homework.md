# StorageClasses and Dynamic Provisioning Homework

Fifteen exercises covering StorageClass authoring, dynamic provisioning with kind's local-path provisioner, binding modes, volume expansion, default-class management, and debugging provisioner failures. Work through the tutorial first.

Exercise namespaces follow `ex-<level>-<exercise>`. StorageClasses are cluster-scoped; their names carry an `ex-<level>-<exercise>` prefix.

---

## Level 1: StorageClass Basics

### Exercise 1.1

**Objective:** List every StorageClass in the cluster and identify the default.

**Setup:**

```bash
kubectl create namespace ex-1-1
```

**Task:** Using `kubectl get storageclass`, produce a list that includes the `(default)` marker. Then extract the name of the default StorageClass in one `jsonpath` query.

**Verification:**

```bash
kubectl get storageclass
# Expected: at least one row, with "(default)" appended to the default class name

kubectl get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}'
# Expected: standard
```

---

### Exercise 1.2

**Objective:** Create a PVC without a `storageClassName` field and confirm the default StorageClass is applied by the admission controller.

**Setup:**

```bash
kubectl create namespace ex-1-2
```

**Task:** In namespace `ex-1-2`, create a PVC `defaulted` with access mode `ReadWriteOnce` and request 500Mi. Do not specify `storageClassName`.

**Verification:**

```bash
kubectl get pvc -n ex-1-2 defaulted -o jsonpath='{.spec.storageClassName}'
# Expected: standard

kubectl get pvc -n ex-1-2 defaulted -o jsonpath='{.status.phase}'
# Expected: Pending (WaitForFirstConsumer mode; no pod yet)
```

---

### Exercise 1.3

**Objective:** Confirm the default StorageClass's provisioner and reclaim policy by extracting them from the StorageClass spec.

**Setup:** (None, uses the default `standard` StorageClass.)

**Task:** Use `kubectl get sc standard -o jsonpath` to print the provisioner, the reclaim policy, the volume binding mode, and whether expansion is allowed.

**Verification:**

```bash
kubectl get sc standard -o jsonpath='{.provisioner}/{.reclaimPolicy}/{.volumeBindingMode}/{.allowVolumeExpansion}'
# Expected: rancher.io/local-path/Delete/WaitForFirstConsumer/false
```

---

## Level 2: Dynamic Provisioning

### Exercise 2.1

**Objective:** Create a PVC with the `standard` StorageClass and a pod that uses it. Observe dynamic PV creation.

**Setup:**

```bash
kubectl create namespace ex-2-1
```

**Task:** In namespace `ex-2-1`, create PVC `dyn-claim` (RWO, 500Mi, `storageClassName: standard`). Create pod `dyn-pod` (`busybox:1.36`, command writes `dynamic-hello` to `/data/f`, then sleeps). Mount the PVC at `/data`.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/dyn-pod -n ex-2-1 --timeout=120s

kubectl get pvc -n ex-2-1 dyn-claim -o jsonpath='{.status.phase}'
# Expected: Bound

kubectl get pvc -n ex-2-1 dyn-claim -o jsonpath='{.spec.volumeName}' | grep -oE '^pvc-'
# Expected: pvc-
# (the PV name is pvc-<uid>, proving it was auto-created by the provisioner)

kubectl exec -n ex-2-1 dyn-pod -- cat /data/f
# Expected: dynamic-hello
```

---

### Exercise 2.2

**Objective:** Compare static and dynamic binding by creating one PVC of each in adjacent namespaces.

**Setup:**

```bash
kubectl create namespace ex-2-2
nerdctl exec kind-control-plane mkdir -p /ex-2-2-static
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata: {name: ex-2-2-static}
spec:
  capacity: {storage: 500Mi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath: {path: /ex-2-2-static, type: DirectoryOrCreate}
EOF
```

**Task:** In namespace `ex-2-2`, create two PVCs: `static-claim` (RWO, 500Mi, `storageClassName: manual`) and `dynamic-claim` (RWO, 500Mi, `storageClassName: standard`). Create a pod for each that mounts the PVC at `/data` and runs `sleep 3600`. Confirm both work and that the underlying PVs differ.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/static-app -n ex-2-2 --timeout=60s
kubectl wait --for=condition=Ready pod/dynamic-app -n ex-2-2 --timeout=120s

kubectl get pvc -n ex-2-2 static-claim -o jsonpath='{.spec.volumeName}'
# Expected: ex-2-2-static

kubectl get pvc -n ex-2-2 dynamic-claim -o jsonpath='{.spec.volumeName}' | grep -oE '^pvc-'
# Expected: pvc-
```

---

### Exercise 2.3

**Objective:** Verify the reclaim-policy difference between static and dynamic by deleting each PVC and observing the PV.

**Setup:** Continue from 2.2.

**Task:** Delete pods `static-app` and `dynamic-app`. Delete PVCs `static-claim` and `dynamic-claim`. Observe the PV phases.

**Verification:**

```bash
# After all deletes:
kubectl get pv ex-2-2-static -o jsonpath='{.status.phase}'
# Expected: Released (reclaimPolicy: Retain)

kubectl get pv --selector='!ignore' -o name | grep pvc- | head -n1
# Expected: (no such PV; the dynamic one was deleted because reclaimPolicy: Delete)
```

---

## Level 3: Debugging

### Exercise 3.1

**Objective:** A PVC references a StorageClass that does not exist. Diagnose and fix.

**Setup:**

```bash
kubectl create namespace ex-3-1
kubectl apply -n ex-3-1 -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: typo-class}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: stanrad
EOF
```

**Task:** The PVC stays Pending. Fix the PVC so it binds using dynamic provisioning.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/probe -n ex-3-1 --timeout=120s 2>/dev/null || true

# Apply a probe pod to trigger WaitForFirstConsumer provisioning after fix
kubectl apply -n ex-3-1 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: probe}
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - {name: v, mountPath: /data}
  volumes:
  - name: v
    persistentVolumeClaim: {claimName: typo-class}
EOF
kubectl wait --for=condition=Ready pod/probe -n ex-3-1 --timeout=120s

kubectl get pvc -n ex-3-1 typo-class -o jsonpath='{.status.phase}'
# Expected: Bound

kubectl get pvc -n ex-3-1 typo-class -o jsonpath='{.spec.storageClassName}'
# Expected: standard
```

---

### Exercise 3.2

**Objective:** The local-path provisioner is scaled to zero replicas. Diagnose why newly-applied PVCs stay Pending.

**Setup:**

```bash
kubectl scale -n local-path-storage deployment/local-path-provisioner --replicas=0 2>/dev/null || true

kubectl create namespace ex-3-2
kubectl apply -n ex-3-2 -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: no-provisioner}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: standard
EOF

kubectl apply -n ex-3-2 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: needs-storage}
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - {name: v, mountPath: /data}
  volumes:
  - name: v
    persistentVolumeClaim: {claimName: no-provisioner}
EOF
```

**Task:** Diagnose why the pod stays Pending. Fix so the pod reaches Running.

**Verification:**

```bash
kubectl get pods -n local-path-storage
# Expected: one local-path-provisioner pod Running

kubectl wait --for=condition=Ready pod/needs-storage -n ex-3-2 --timeout=120s

kubectl get pvc -n ex-3-2 no-provisioner -o jsonpath='{.status.phase}'
# Expected: Bound
```

---

### Exercise 3.3

**Objective:** A PVC references a StorageClass that exists but has a provisioner no controller is running. Diagnose.

**Setup:**

```bash
kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: {name: ex-3-3-fake}
provisioner: example.com/nonexistent
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF

kubectl create namespace ex-3-3
kubectl apply -n ex-3-3 -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: ghost-claim}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: ex-3-3-fake
EOF
```

**Task:** The PVC stays Pending with `ProvisioningFailed` events referring to `example.com/nonexistent`. Fix the PVC to use a real StorageClass and bind.

**Verification:**

```bash
kubectl describe pvc -n ex-3-3 ghost-claim | grep -E "external-provisioner|waiting|ProvisioningFailed" | head -n1
# Expected (before fix): a line mentioning example.com/nonexistent or waiting for provisioner

# After fix (change storageClassName to standard):
kubectl get pvc -n ex-3-3 ghost-claim -o jsonpath='{.spec.storageClassName}'
# Expected: standard

# Apply a pod to trigger provisioning
kubectl apply -n ex-3-3 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: hungry}
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - {name: v, mountPath: /data}
  volumes:
  - name: v
    persistentVolumeClaim: {claimName: ghost-claim}
EOF
kubectl wait --for=condition=Ready pod/hungry -n ex-3-3 --timeout=120s

kubectl get pvc -n ex-3-3 ghost-claim -o jsonpath='{.status.phase}'
# Expected: Bound
```

---

## Level 4: Advanced Configuration

### Exercise 4.1

**Objective:** Create a custom StorageClass backed by `rancher.io/local-path` with `reclaimPolicy: Retain`, `volumeBindingMode: Immediate`, and `allowVolumeExpansion: true`.

**Setup:** (None.)

**Task:** Create a StorageClass named `ex-4-1-custom`.

**Verification:**

```bash
kubectl get sc ex-4-1-custom -o jsonpath='{.provisioner}/{.reclaimPolicy}/{.volumeBindingMode}/{.allowVolumeExpansion}'
# Expected: rancher.io/local-path/Retain/Immediate/true
```

---

### Exercise 4.2

**Objective:** Test volume expansion on a StorageClass that allows it.

**Setup:**

```bash
kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: {name: ex-4-2-expand}
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

kubectl create namespace ex-4-2
```

**Task:** In namespace `ex-4-2`, create PVC `growable` (RWO, 500Mi, `storageClassName: ex-4-2-expand`). Create pod `grower` that mounts the PVC and sleeps. Expand the PVC to 1Gi.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/grower -n ex-4-2 --timeout=120s

kubectl get pvc -n ex-4-2 growable -o jsonpath='{.status.capacity.storage}'
# Expected: 500Mi

# Expand
kubectl patch pvc -n ex-4-2 growable -p '{"spec":{"resources":{"requests":{"storage":"1Gi"}}}}'

kubectl get pvc -n ex-4-2 growable -o jsonpath='{.spec.resources.requests.storage}'
# Expected: 1Gi

sleep 15
kubectl get pvc -n ex-4-2 growable -o jsonpath='{.status.capacity.storage}'
# Expected: 1Gi
```

---

### Exercise 4.3

**Objective:** Contrast `WaitForFirstConsumer` and `Immediate` by observing when provisioning happens.

**Setup:**

```bash
kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: {name: ex-4-3-immediate}
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: Immediate
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: {name: ex-4-3-wait}
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
EOF

kubectl create namespace ex-4-3
```

**Task:** In namespace `ex-4-3`, create PVC `immediately-bound` (RWO, 500Mi, `storageClassName: ex-4-3-immediate`) and PVC `wait-bound` (RWO, 500Mi, `storageClassName: ex-4-3-wait`). Do not create any pods yet. Observe the initial phase of each PVC.

**Verification:**

```bash
sleep 10
kubectl get pvc -n ex-4-3 immediately-bound -o jsonpath='{.status.phase}'
# Expected: Bound

kubectl get pvc -n ex-4-3 wait-bound -o jsonpath='{.status.phase}'
# Expected: Pending
```

---

## Level 5: Complex Scenarios

### Exercise 5.1

**Objective:** Switch the cluster's default StorageClass without leaving two defaults set.

**Setup:**

```bash
kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: {name: ex-5-1-new-default}
provisioner: rancher.io/local-path
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF
```

**Task:** Annotate `ex-5-1-new-default` as the default, and remove the annotation from `standard`. Verify only one default exists. Then restore `standard` as default and remove the annotation from `ex-5-1-new-default`.

**Verification:**

```bash
# After setting ex-5-1-new-default as default:
kubectl get sc | grep -c "(default)"
# Expected: 1

kubectl get sc -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}'
# Expected: ex-5-1-new-default

# After restoring standard:
kubectl get sc -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}'
# Expected: standard
```

---

### Exercise 5.2

**Objective:** Grow a PVC from 500Mi to 2Gi and verify the expansion propagates to the filesystem seen from inside the container.

**Setup:**

```bash
kubectl apply -f - <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: {name: ex-5-2-expand}
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

kubectl create namespace ex-5-2
```

**Task:** In namespace `ex-5-2`, create PVC `shrink-happens-later` (500Mi) using the class above. Create pod `sizer` that mounts the PVC and sleeps. Fill the volume to approximately 400Mi (write a file with zeros). Expand the PVC to 2Gi. Verify the container can then fill up to about 1900Mi.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/sizer -n ex-5-2 --timeout=120s

# Fill ~400Mi
kubectl exec -n ex-5-2 sizer -- dd if=/dev/zero of=/data/fill bs=1M count=400

kubectl exec -n ex-5-2 sizer -- df -h /data | tail -n1 | awk '{print $2}'
# Expected: approximately 500M (the original size)

# Expand
kubectl patch pvc -n ex-5-2 shrink-happens-later -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'

sleep 15
kubectl get pvc -n ex-5-2 shrink-happens-later -o jsonpath='{.status.capacity.storage}'
# Expected: 2Gi

# For local-path, no pod restart is needed; check size from inside
kubectl exec -n ex-5-2 sizer -- df -h /data | tail -n1 | awk '{print $2}'
# Expected: approximately 2G (the expanded size)
```

Note: `local-path` on kind uses the node's underlying filesystem so `df` may show the full node capacity rather than the PVC size. The key signal is `status.capacity.storage` on the PVC; that is the Kubernetes-tracked value and it will read 2Gi after the patch takes effect.

---

### Exercise 5.3

**Objective:** Design a storage strategy for a three-tier application: a `database` tier needs 5Gi of `Retain` storage, a `cache` tier needs 1Gi of ephemeral `Delete` storage, and an `archive` tier needs 10Gi of expandable `Retain` storage.

**Setup:**

```bash
kubectl create namespace ex-5-3
```

**Task:** Create three StorageClasses: `ex-5-3-database` (Retain, no expansion), `ex-5-3-cache` (Delete, no expansion), `ex-5-3-archive` (Retain, `allowVolumeExpansion: true`). All three use `rancher.io/local-path`. In namespace `ex-5-3`, create three PVCs: `db-claim` (5Gi, `ex-5-3-database`), `cache-claim` (1Gi, `ex-5-3-cache`), `archive-claim` (10Gi, `ex-5-3-archive`), all RWO. Create a pod for each that mounts its PVC at `/data` and runs sleep. Delete all three pods and then all three PVCs. Observe which PVs survive and which are deleted.

**Verification:**

```bash
# After creating all three pod+PVC sets and reaching Ready:
kubectl get pvc -n ex-5-3 db-claim cache-claim archive-claim -o jsonpath='{range .items[*]}{.metadata.name}:{.status.phase} {end}'
# Expected: db-claim:Bound cache-claim:Bound archive-claim:Bound

# Record the PV names for each before deletion
DB_PV=$(kubectl get pvc -n ex-5-3 db-claim -o jsonpath='{.spec.volumeName}')
CACHE_PV=$(kubectl get pvc -n ex-5-3 cache-claim -o jsonpath='{.spec.volumeName}')
ARCHIVE_PV=$(kubectl get pvc -n ex-5-3 archive-claim -o jsonpath='{.spec.volumeName}')

# Delete pods and PVCs
kubectl delete pod --all -n ex-5-3
kubectl delete pvc --all -n ex-5-3

sleep 10

# Retain PVs stay (Released):
kubectl get pv "$DB_PV" -o jsonpath='{.status.phase}'
# Expected: Released

kubectl get pv "$ARCHIVE_PV" -o jsonpath='{.status.phase}'
# Expected: Released

# Delete PV is gone:
kubectl get pv "$CACHE_PV" 2>&1 | grep -o 'NotFound'
# Expected: NotFound
```

---

## Cleanup

Delete all exercise namespaces, custom StorageClasses, and any remaining PVs. Restore the local-path-provisioner to one replica.

```bash
for ns in ex-1-1 ex-1-2 ex-2-1 ex-2-2 ex-3-1 ex-3-2 ex-3-3 ex-4-2 ex-4-3 ex-5-2 ex-5-3; do
  kubectl delete namespace "$ns" --ignore-not-found
done

for sc in ex-3-3-fake ex-4-1-custom ex-4-2-expand ex-4-3-immediate ex-4-3-wait \
          ex-5-1-new-default ex-5-2-expand ex-5-3-database ex-5-3-cache ex-5-3-archive; do
  kubectl delete storageclass "$sc" --ignore-not-found
done

kubectl delete pv ex-2-2-static --ignore-not-found

kubectl scale -n local-path-storage deployment/local-path-provisioner --replicas=1 2>/dev/null || true

nerdctl exec kind-control-plane sh -c 'rm -rf /ex-*-*' || true
```

## Key Takeaways

A StorageClass is cluster-scoped and identifies a provisioner plus parameters. The default class (annotated with `storageclass.kubernetes.io/is-default-class: "true"`) applies to PVCs with no explicit `storageClassName`. `WaitForFirstConsumer` binding mode delays provisioning until a pod references the PVC, which is the right choice for node-local provisioners. `allowVolumeExpansion: true` enables in-place PVC resizing via `kubectl patch`; for CSI backends the expansion may require a pod restart (tracked via the `FileSystemResizePending` condition). `reclaimPolicy: Delete` removes the backend storage when the PVC is deleted (for CSI drivers that support deletion); `Retain` leaves the PV `Released` with data intact. The kind cluster's `rancher.io/local-path` provisioner is sufficient for every exercise here; no CSI driver installation is required.
