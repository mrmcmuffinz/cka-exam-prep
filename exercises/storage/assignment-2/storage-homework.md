# Storage Homework: PersistentVolumeClaims and Binding

This homework contains 15 progressive exercises to practice PVCs and binding mechanics.

---

## Setup

Create PVs for the exercises:

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
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/pv-small
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
  accessModes: ["ReadWriteOnce","ReadOnlyMany"]
  persistentVolumeReclaimPolicy: Delete
  storageClassName: ""
  hostPath:
    path: /tmp/pv-medium
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
  accessModes: ["ReadWriteMany"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/pv-large
EOF
```

---

## Level 1: Basic PVC Operations

### Exercise 1.1

**Setup:** `kubectl create namespace ex-1-1`

**Task:** Create a PVC named `basic-claim` requesting 500Mi with ReadWriteOnce access mode and empty storageClassName. Verify it binds to pv-small.

**Verification:**
```bash
kubectl get pvc basic-claim -n ex-1-1
# Expected: Bound to pv-small
```

---

### Exercise 1.2

**Setup:** `kubectl create namespace ex-1-2`

**Task:** Create a PVC named `data-claim` requesting 1Gi with ReadWriteOnce. Mount it in a pod named `data-pod` at /data using busybox:1.36 with command to write and sleep.

**Verification:**
```bash
kubectl exec -n ex-1-2 data-pod -- ls /data
# Expected: Directory accessible
```

---

### Exercise 1.3

**Setup:** `kubectl create namespace ex-1-3`

**Task:** List and describe PVCs. Create a PVC, verify its bound PV, and extract the storage capacity.

---

## Level 2: Binding Mechanics

### Exercise 2.1

**Setup:** `kubectl create namespace ex-2-1`

**Task:** Create a PVC requesting 3Gi. Observe which PV it binds to (should be pv-large, the only one with sufficient capacity).

---

### Exercise 2.2

**Setup:** `kubectl create namespace ex-2-2`

**Task:** Create a PVC with a label selector matching `size: medium`. Verify it binds to pv-medium specifically.

---

### Exercise 2.3

**Setup:** `kubectl create namespace ex-2-3`

**Task:** Create a PVC requesting ReadWriteMany access. Verify it binds to pv-large (the only RWX PV).

---

## Level 3: Debugging Binding Issues

### Exercise 3.1

**Setup:** `kubectl create namespace ex-3-1`

**Task:** Create a PVC requesting 10Gi (more than any available PV). Observe it stays Pending. Diagnose why using kubectl describe.

---

### Exercise 3.2

**Setup:** `kubectl create namespace ex-3-2`

**Task:** Create a PVC requesting ReadWriteOnce but with label selector `size: large`. It will stay Pending because pv-large only supports RWX. Diagnose and fix.

---

### Exercise 3.3

**Setup:** `kubectl create namespace ex-3-3`

**Task:** Create a PVC with storageClassName: "manual". It stays Pending because no PV has that class. Fix by using empty storageClassName.

---

## Level 4: Reclaim and Lifecycle

### Exercise 4.1

**Setup:** `kubectl create namespace ex-4-1`

Create a new PV with Retain policy and bind a PVC to it. Delete the PVC and observe the PV becomes Released.

---

### Exercise 4.2

**Setup:** `kubectl create namespace ex-4-2`

Create a PV with Delete policy. Bind a PVC and then delete the PVC. Observe the PV is also deleted.

---

### Exercise 4.3

**Setup:** `kubectl create namespace ex-4-3`

Take a Released PV, remove its claimRef, and verify it becomes Available. Bind a new PVC to it.

---

## Level 5: Complex Scenarios

### Exercise 5.1

**Setup:** `kubectl create namespace ex-5-1`

**Task:** Create a PVC with RWX access mode. Create two pods that both mount this PVC and verify they can both write to it.

---

### Exercise 5.2

**Setup:** `kubectl create namespace ex-5-2`

**Task:** Debug a complex binding failure: PVC requests 1Gi, ROX, with selector tier=gold. No PV matches all criteria. Create a PV that satisfies all requirements.

---

### Exercise 5.3

**Setup:** `kubectl create namespace ex-5-3`

**Task:** Design a PVC strategy for a stateful app: primary pod needs RWO 5Gi, replica pods need ROX 5Gi to same data. Create appropriate PVs and PVCs.

---

## Cleanup

```bash
kubectl delete namespace ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3 --ignore-not-found
kubectl delete pv pv-small pv-medium pv-large --ignore-not-found
```

---

## Key Takeaways

1. PVCs bind to PVs matching capacity, access modes, and storageClassName
2. Label selectors enable specific PV selection
3. Pending PVCs indicate no matching PV available
4. Retain policy preserves data; Delete policy removes PV
5. Remove claimRef to reuse Released PVs
