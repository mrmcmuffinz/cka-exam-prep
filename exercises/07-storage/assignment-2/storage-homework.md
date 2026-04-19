# PersistentVolumeClaims and Binding Homework

Fifteen exercises covering PVC authoring, the binding algorithm, pod consumption of PVCs, reclaim policies, and debugging binding failures. Work through the tutorial first. Level 3 and Level 5 debugging exercises expect you to read `kubectl describe pv` and `kubectl describe pvc` to find the specific criterion that blocks binding.

Exercise namespaces follow `ex-<level>-<exercise>`. PVs are cluster-scoped; their names have an `ex-<level>-<exercise>` prefix to isolate them. The global cleanup block removes everything.

---

## Level 1: Basic PVC Operations

### Exercise 1.1

**Objective:** Create a matched PV and PVC and confirm they bind.

**Setup:**

```bash
kubectl create namespace ex-1-1
nerdctl exec kind-control-plane mkdir -p /ex-1-1
```

**Task:** Create a cluster-scoped PV `ex-1-1-pv` (1Gi, RWO, Retain, `storageClassName: manual`, hostPath `/ex-1-1`). In namespace `ex-1-1`, create a PVC `basic-claim` requesting 500Mi with RWO and `storageClassName: manual`.

**Verification:**

```bash
kubectl get pvc -n ex-1-1 basic-claim -o jsonpath='{.status.phase}'
# Expected: Bound

kubectl get pvc -n ex-1-1 basic-claim -o jsonpath='{.spec.volumeName}'
# Expected: ex-1-1-pv

kubectl get pv ex-1-1-pv -o jsonpath='{.status.phase}'
# Expected: Bound
```

---

### Exercise 1.2

**Objective:** Mount a PVC in a pod and verify data persistence.

**Setup:**

```bash
kubectl create namespace ex-1-2
nerdctl exec kind-control-plane mkdir -p /ex-1-2
```

**Task:** Create PV `ex-1-2-pv` (1Gi, RWO, Retain, `storageClassName: manual`, hostPath `/ex-1-2`). In namespace `ex-1-2`, create PVC `app-claim` (500Mi, RWO, `storageClassName: manual`). Create pod `data-app` (image `busybox:1.36`, command writes `kept-forever` to `/data/marker`, then sleeps). Mount the PVC at `/data`. Confirm the write lands in the backing host directory.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/data-app -n ex-1-2 --timeout=60s

kubectl exec -n ex-1-2 data-app -- cat /data/marker
# Expected: kept-forever

nerdctl exec kind-control-plane cat /ex-1-2/marker
# Expected: kept-forever

kubectl get pvc -n ex-1-2 app-claim -o jsonpath='{.status.phase}'
# Expected: Bound
```

---

### Exercise 1.3

**Objective:** List every PVC in a namespace with its bound PV, capacity, and access mode, all in one query.

**Setup:**

```bash
kubectl create namespace ex-1-3

for n in one two three; do
  nerdctl exec kind-control-plane mkdir -p "/ex-1-3-$n"
  size="500Mi"
  [ "$n" = "two" ] && size="1Gi"
  [ "$n" = "three" ] && size="2Gi"
  kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ex-1-3-pv-$n
spec:
  capacity: {storage: $size}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual-1-3
  hostPath: {path: /ex-1-3-$n, type: DirectoryOrCreate}
EOF
  kubectl apply -n ex-1-3 -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim-$n
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: $size}}
  storageClassName: manual-1-3
  volumeName: ex-1-3-pv-$n
EOF
done

sleep 3
```

**Task:** Run a `kubectl get pvc` command in namespace `ex-1-3` that outputs one line per PVC with the fields: NAME, STATUS, VOLUME, CAPACITY, ACCESS MODES. The default `kubectl get pvc` output meets this requirement; confirm.

**Verification:**

```bash
kubectl get pvc -n ex-1-3
# Expected: three rows, all STATUS=Bound, volumes ex-1-3-pv-one/two/three

kubectl get pvc -n ex-1-3 -o custom-columns='NAME:.metadata.name,SIZE:.status.capacity.storage' --no-headers | sort
# Expected (three lines):
# claim-one    500Mi
# claim-three  2Gi
# claim-two    1Gi
```

---

## Level 2: Binding Mechanics

### Exercise 2.1

**Objective:** Request a specific capacity and show the binder picks the smallest matching PV.

**Setup:**

```bash
kubectl create namespace ex-2-1
nerdctl exec kind-control-plane sh -c 'mkdir -p /ex-2-1-small /ex-2-1-medium /ex-2-1-large'

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata: {name: ex-2-1-small}
spec:
  capacity: {storage: 500Mi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual-2-1
  hostPath: {path: /ex-2-1-small, type: DirectoryOrCreate}
---
apiVersion: v1
kind: PersistentVolume
metadata: {name: ex-2-1-medium}
spec:
  capacity: {storage: 2Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual-2-1
  hostPath: {path: /ex-2-1-medium, type: DirectoryOrCreate}
---
apiVersion: v1
kind: PersistentVolume
metadata: {name: ex-2-1-large}
spec:
  capacity: {storage: 10Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual-2-1
  hostPath: {path: /ex-2-1-large, type: DirectoryOrCreate}
EOF
```

**Task:** Create PVC `smallest-fit` in namespace `ex-2-1` requesting 1Gi, RWO, `storageClassName: manual-2-1`. Confirm it does not bind to the small PV (too small), does bind, and the binder prefers the medium one.

**Verification:**

```bash
kubectl get pvc -n ex-2-1 smallest-fit -o jsonpath='{.status.phase}'
# Expected: Bound

kubectl get pvc -n ex-2-1 smallest-fit -o jsonpath='{.spec.volumeName}'
# Expected: ex-2-1-medium (the binder typically picks the smallest sufficient PV;
# ex-2-1-small is too small, so ex-2-1-medium is chosen over ex-2-1-large)

kubectl get pv ex-2-1-small -o jsonpath='{.status.phase}'
# Expected: Available

kubectl get pv ex-2-1-large -o jsonpath='{.status.phase}'
# Expected: Available
```

---

### Exercise 2.2

**Objective:** Use a label selector on a PVC to pick a specific PV out of several candidates with the same size.

**Setup:**

```bash
kubectl create namespace ex-2-2
nerdctl exec kind-control-plane sh -c 'mkdir -p /ex-2-2-fast /ex-2-2-bulk'

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata: {name: ex-2-2-fast, labels: {tier: fast}}
spec:
  capacity: {storage: 1Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual-2-2
  hostPath: {path: /ex-2-2-fast, type: DirectoryOrCreate}
---
apiVersion: v1
kind: PersistentVolume
metadata: {name: ex-2-2-bulk, labels: {tier: bulk}}
spec:
  capacity: {storage: 1Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual-2-2
  hostPath: {path: /ex-2-2-bulk, type: DirectoryOrCreate}
EOF
```

**Task:** Create PVC `pick-bulk` in namespace `ex-2-2` requesting 500Mi RWO `storageClassName: manual-2-2` with a selector matching `tier: bulk`.

**Verification:**

```bash
kubectl get pvc -n ex-2-2 pick-bulk -o jsonpath='{.spec.volumeName}'
# Expected: ex-2-2-bulk

kubectl get pv ex-2-2-fast -o jsonpath='{.status.phase}'
# Expected: Available
```

---

### Exercise 2.3

**Objective:** Confirm access-mode semantics by requesting multiple modes on a PVC.

**Setup:**

```bash
kubectl create namespace ex-2-3
nerdctl exec kind-control-plane mkdir -p /ex-2-3

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata: {name: ex-2-3-pv}
spec:
  capacity: {storage: 1Gi}
  accessModes: ["ReadWriteOnce", "ReadOnlyMany"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual-2-3
  hostPath: {path: /ex-2-3, type: DirectoryOrCreate}
EOF
```

**Task:** Create two PVCs in namespace `ex-2-3`: `needs-rwo` requesting `[ReadWriteOnce]` and `needs-both` requesting `[ReadWriteOnce, ReadOnlyMany]`. Both request 500Mi, `storageClassName: manual-2-3`. Because a PV can only bind to one PVC at a time, only the first-created claim binds.

**Verification:**

```bash
# Apply needs-rwo first, then needs-both.
kubectl get pvc -n ex-2-3 needs-rwo -o jsonpath='{.status.phase}'
# Expected: Bound

kubectl get pvc -n ex-2-3 needs-both -o jsonpath='{.status.phase}'
# Expected: Pending
```

---

## Level 3: Debugging

### Exercise 3.1

**Objective:** The PVC below is Pending. Diagnose why and fix the PVC.

**Setup:**

```bash
kubectl create namespace ex-3-1
nerdctl exec kind-control-plane mkdir -p /ex-3-1

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata: {name: ex-3-1-pv}
spec:
  capacity: {storage: 1Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual-3-1
  hostPath: {path: /ex-3-1, type: DirectoryOrCreate}
EOF

kubectl apply -n ex-3-1 -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: pending-claim}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 5Gi}}
  storageClassName: manual-3-1
EOF
```

**Task:** Adjust the PVC so it binds. Do not change the PV.

**Verification:**

```bash
kubectl get pvc -n ex-3-1 pending-claim -o jsonpath='{.status.phase}'
# Expected: Bound

kubectl get pvc -n ex-3-1 pending-claim -o jsonpath='{.spec.volumeName}'
# Expected: ex-3-1-pv
```

---

### Exercise 3.2

**Objective:** The PVC below is Pending. Diagnose why and fix.

**Setup:**

```bash
kubectl create namespace ex-3-2
nerdctl exec kind-control-plane mkdir -p /ex-3-2

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata: {name: ex-3-2-pv}
spec:
  capacity: {storage: 1Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual-3-2
  hostPath: {path: /ex-3-2, type: DirectoryOrCreate}
EOF

kubectl apply -n ex-3-2 -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: wrong-mode}
spec:
  accessModes: ["ReadWriteMany"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: manual-3-2
EOF
```

**Task:** Fix the PVC so it binds. Do not change the PV.

**Verification:**

```bash
kubectl get pvc -n ex-3-2 wrong-mode -o jsonpath='{.status.phase}'
# Expected: Bound
```

---

### Exercise 3.3

**Objective:** The PVC below is Pending. Diagnose why and fix.

**Setup:**

```bash
kubectl create namespace ex-3-3
nerdctl exec kind-control-plane mkdir -p /ex-3-3

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata: {name: ex-3-3-pv, labels: {tier: gold}}
spec:
  capacity: {storage: 1Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual-3-3
  hostPath: {path: /ex-3-3, type: DirectoryOrCreate}
EOF

kubectl apply -n ex-3-3 -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: wrong-tier}
spec:
  accessModes: ["ReadWriteOnce"]
  resources: {requests: {storage: 500Mi}}
  storageClassName: manual-3-3
  selector:
    matchLabels:
      tier: silver
EOF
```

**Task:** Fix the PVC so it binds. Do not change the PV.

**Verification:**

```bash
kubectl get pvc -n ex-3-3 wrong-tier -o jsonpath='{.status.phase}'
# Expected: Bound

kubectl get pvc -n ex-3-3 wrong-tier -o jsonpath='{.spec.volumeName}'
# Expected: ex-3-3-pv
```

---

## Level 4: Reclaim and Lifecycle

### Exercise 4.1

**Objective:** Test `Retain` behavior: PVC deletion leaves the PV Released, data intact.

**Setup:**

```bash
kubectl create namespace ex-4-1
nerdctl exec kind-control-plane mkdir -p /ex-4-1

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata: {name: ex-4-1-pv}
spec:
  capacity: {storage: 1Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual-4-1
  hostPath: {path: /ex-4-1, type: DirectoryOrCreate}
EOF
```

**Task:** In namespace `ex-4-1`, create PVC `to-be-deleted` (500Mi, RWO, `storageClassName: manual-4-1`). Create pod `writer` that writes `payload` to `/data/record` and sleeps, mounting the PVC at `/data`. Delete the pod, then delete the PVC. Observe the PV.

**Verification:**

```bash
# After the full task sequence:
kubectl get pv ex-4-1-pv -o jsonpath='{.status.phase}'
# Expected: Released

nerdctl exec kind-control-plane cat /ex-4-1/record
# Expected: payload
```

---

### Exercise 4.2

**Objective:** Reuse a Released PV by removing its `claimRef` and binding a new PVC.

**Setup:**

```bash
nerdctl exec kind-control-plane mkdir -p /ex-4-2
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata: {name: ex-4-2-pv}
spec:
  capacity: {storage: 1Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual-4-2
  claimRef: {namespace: stale, name: stale-claim, kind: PersistentVolumeClaim, apiVersion: v1}
  hostPath: {path: /ex-4-2, type: Directory}
EOF
kubectl create namespace ex-4-2
```

**Task:** Remove the `claimRef` on `ex-4-2-pv`. Create PVC `reuser` (500Mi, RWO, `storageClassName: manual-4-2`) in namespace `ex-4-2`. Confirm it binds to the reused PV.

**Verification:**

```bash
kubectl get pv ex-4-2-pv -o jsonpath='{.spec.claimRef}' 2>/dev/null
# Expected: (empty)

kubectl get pvc -n ex-4-2 reuser -o jsonpath='{.spec.volumeName}'
# Expected: ex-4-2-pv
```

---

### Exercise 4.3

**Objective:** Observe what happens to a `hostPath` PV with `Delete` reclaim policy when its PVC is removed.

**Setup:**

```bash
kubectl create namespace ex-4-3
nerdctl exec kind-control-plane mkdir -p /ex-4-3

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata: {name: ex-4-3-pv}
spec:
  capacity: {storage: 1Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Delete
  storageClassName: manual-4-3
  hostPath: {path: /ex-4-3, type: Directory}
EOF
```

**Task:** Create PVC `doomed` (500Mi, RWO, `storageClassName: manual-4-3`) in namespace `ex-4-3`. Delete it. Observe the PV's phase and the host directory.

**Verification:**

```bash
# After delete:
kubectl get pv ex-4-3-pv -o jsonpath='{.status.phase}'
# Expected: Failed

nerdctl exec kind-control-plane test -d /ex-4-3 && echo present
# Expected: present
```

---

## Level 5: Complex Scenarios

### Exercise 5.1

**Objective:** Configure multiple pods to share the same PVC using `ReadOnlyMany`.

**Setup:**

```bash
kubectl create namespace ex-5-1
nerdctl exec kind-control-plane mkdir -p /ex-5-1
nerdctl exec kind-control-plane sh -c 'echo shared-content > /ex-5-1/shared.txt'

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata: {name: ex-5-1-pv}
spec:
  capacity: {storage: 1Gi}
  accessModes: ["ReadOnlyMany"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual-5-1
  hostPath: {path: /ex-5-1, type: Directory}
EOF
```

**Task:** In namespace `ex-5-1`, create a PVC `shared-reader` that binds to `ex-5-1-pv`. Create two pods `reader-one` and `reader-two`, each mounting the PVC read-only at `/data` and reading `/data/shared.txt` once on startup.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/reader-one pod/reader-two -n ex-5-1 --timeout=60s

kubectl logs -n ex-5-1 reader-one
# Expected (contains): shared-content

kubectl logs -n ex-5-1 reader-two
# Expected (contains): shared-content

kubectl get pvc -n ex-5-1 shared-reader -o jsonpath='{.status.accessModes[0]}'
# Expected: ReadOnlyMany
```

---

### Exercise 5.2

**Objective:** Diagnose a compound binding failure with three mismatches (capacity, access mode, storage class).

**Setup:**

```bash
kubectl create namespace ex-5-2
nerdctl exec kind-control-plane mkdir -p /ex-5-2

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolume
metadata: {name: ex-5-2-pv}
spec:
  capacity: {storage: 1Gi}
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: tier-gold
  hostPath: {path: /ex-5-2, type: DirectoryOrCreate}
EOF

kubectl apply -n ex-5-2 -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: compound-fail}
spec:
  accessModes: ["ReadWriteMany"]
  resources: {requests: {storage: 5Gi}}
  storageClassName: tier-silver
EOF
```

**Task:** Fix the PVC so it binds. Do not change the PV. You will need to adjust three fields on the PVC.

**Verification:**

```bash
kubectl get pvc -n ex-5-2 compound-fail -o jsonpath='{.status.phase}'
# Expected: Bound

kubectl get pvc -n ex-5-2 compound-fail -o jsonpath='{.spec.volumeName}'
# Expected: ex-5-2-pv
```

---

### Exercise 5.3

**Objective:** Design a PVC strategy for a stateful application: a primary pod needs 1Gi of writable storage, and a nightly backup pod needs to mount the same data read-only.

**Setup:**

```bash
kubectl create namespace ex-5-3
nerdctl exec kind-control-plane mkdir -p /ex-5-3
```

**Task:** Create a PV `ex-5-3-pv` that supports both `ReadWriteOnce` and `ReadOnlyMany` access modes, 2Gi capacity, `storageClassName: manual-5-3`, reclaim `Retain`, hostPath `/ex-5-3`. In namespace `ex-5-3`, create one PVC `app-storage` that asks for RWO. Create a primary pod `primary-app` that mounts the PVC RWO and writes `production-data` to `/data/db`. Create a backup pod `backup-reader` that mounts the SAME PVC read-only via `volumeMounts[*].readOnly: true`, on the same node (kind is single-node), and reads that file.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/primary-app -n ex-5-3 --timeout=60s
kubectl wait --for=condition=Ready pod/backup-reader -n ex-5-3 --timeout=60s

kubectl exec -n ex-5-3 primary-app -- cat /data/db
# Expected: production-data

kubectl exec -n ex-5-3 backup-reader -- cat /data/db
# Expected: production-data

kubectl exec -n ex-5-3 backup-reader -- sh -c 'echo tamper > /data/db 2>&1 || true' | grep -o 'Read-only file system'
# Expected: Read-only file system
```

---

## Cleanup

Delete all exercise namespaces and PVs.

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 \
         ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3; do
  kubectl delete namespace "$ns" --ignore-not-found
done

for pv in ex-1-1-pv ex-1-2-pv ex-1-3-pv-one ex-1-3-pv-two ex-1-3-pv-three \
          ex-2-1-small ex-2-1-medium ex-2-1-large ex-2-2-fast ex-2-2-bulk \
          ex-2-3-pv ex-3-1-pv ex-3-2-pv ex-3-3-pv \
          ex-4-1-pv ex-4-2-pv ex-4-3-pv \
          ex-5-1-pv ex-5-2-pv ex-5-3-pv; do
  kubectl patch pv "$pv" --type='json' -p='[{"op":"remove","path":"/spec/claimRef"}]' 2>/dev/null || true
  kubectl delete pv "$pv" --ignore-not-found
done

nerdctl exec kind-control-plane sh -c 'rm -rf /ex-*-*'
```

## Key Takeaways

The binding criteria are `storageClassName` match, access-mode superset, capacity sufficient, label selector (if any), and `volumeName` (if any). The binder prefers the smallest PV that satisfies every criterion. A PVC stays `Pending` until all criteria are met for some PV; the events on the PVC name the mismatch. Pods consume PVCs via `volumes[*].persistentVolumeClaim.claimName`. Reclaim policy `Retain` leaves the PV `Released` on PVC deletion and requires `claimRef` removal to rebind. Reclaim policy `Delete` on `hostPath` ends in `Failed` because `hostPath` lacks deletion semantics. Multiple pods can mount the same PVC only when the access mode allows it (`ROX`, `RWX`, or `RWO` with both pods on the same node).
