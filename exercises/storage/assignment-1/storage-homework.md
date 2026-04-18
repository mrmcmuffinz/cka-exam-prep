# Storage Homework: Volumes and PersistentVolumes

This homework contains 15 progressive exercises to practice volume types and PersistentVolumes. Complete the tutorial before attempting these exercises.

---

## Level 1: Basic Volume Types

### Exercise 1.1

**Objective:** Create a pod with an emptyDir volume for temporary storage.

**Setup:**

```bash
kubectl create namespace ex-1-1
```

**Task:**

Create a pod named `temp-storage` in namespace `ex-1-1` using busybox:1.36. The pod should:
- Have an emptyDir volume named `cache`
- Mount the volume at `/cache`
- Run command: `["sh", "-c", "echo 'cached data' > /cache/data.txt && sleep 3600"]`

**Verification:**

```bash
# Verify the pod is running
kubectl get pod temp-storage -n ex-1-1

# Verify the file was created
kubectl exec -n ex-1-1 temp-storage -- cat /cache/data.txt

# Expected: cached data
```

---

### Exercise 1.2

**Objective:** Create a pod with a hostPath volume.

**Setup:**

```bash
kubectl create namespace ex-1-2
```

**Task:**

Create a pod named `host-storage` in namespace `ex-1-2` using busybox:1.36. The pod should:
- Have a hostPath volume at `/tmp/ex-1-2-data` with type DirectoryOrCreate
- Mount the volume at `/host-data`
- Run command: `["sh", "-c", "echo 'host data' > /host-data/file.txt && sleep 3600"]`

**Verification:**

```bash
# Verify the pod is running
kubectl get pod host-storage -n ex-1-2

# Verify the file was created
kubectl exec -n ex-1-2 host-storage -- cat /host-data/file.txt

# Expected: host data
```

---

### Exercise 1.3

**Objective:** Verify volume mounts and data persistence within pod lifecycle.

**Setup:**

```bash
kubectl create namespace ex-1-3
```

**Task:**

Create a pod named `multi-container` in namespace `ex-1-3` with two containers sharing an emptyDir volume:
- Container `writer` using busybox:1.36: writes "shared message" to /shared/message.txt
- Container `reader` using busybox:1.36: reads from /shared/message.txt after a delay
- Both containers mount the emptyDir at /shared

**Verification:**

```bash
# Wait for pod to be ready
kubectl wait --for=condition=Ready pod/multi-container -n ex-1-3 --timeout=60s

# Check reader container logs
kubectl logs multi-container -n ex-1-3 -c reader

# Expected: shared message
```

---

## Level 2: PersistentVolume Creation

### Exercise 2.1

**Objective:** Create a PersistentVolume with hostPath backend.

**Setup:**

No namespace needed as PVs are cluster-scoped.

**Task:**

Create a PV named `pv-hostpath` with:
- Capacity: 1Gi
- Access mode: ReadWriteOnce
- Reclaim policy: Retain
- hostPath: /tmp/pv-hostpath-data (DirectoryOrCreate)
- No storage class (empty string)

**Verification:**

```bash
# Verify PV exists
kubectl get pv pv-hostpath

# Expected: Shows 1Gi, RWO, Retain, Available

# Verify capacity
kubectl get pv pv-hostpath -o jsonpath='{.spec.capacity.storage}'

# Expected: 1Gi
```

---

### Exercise 2.2

**Objective:** Create a PV with specific access modes.

**Setup:**

None needed.

**Task:**

Create a PV named `pv-multimode` with:
- Capacity: 2Gi
- Access modes: ReadWriteOnce AND ReadOnlyMany
- Reclaim policy: Delete
- hostPath: /tmp/pv-multimode-data

**Verification:**

```bash
# Verify PV exists
kubectl get pv pv-multimode

# Verify access modes
kubectl get pv pv-multimode -o jsonpath='{.spec.accessModes}'

# Expected: ["ReadWriteOnce","ReadOnlyMany"]
```

---

### Exercise 2.3

**Objective:** List and describe PersistentVolumes.

**Setup:**

Ensure PVs from 2.1 and 2.2 exist.

**Task:**

Use kubectl to:
1. List all PVs with their status
2. Get detailed information about pv-hostpath
3. Extract just the reclaim policy of pv-multimode

**Verification:**

```bash
# List PVs
kubectl get pv

# Expected: Shows pv-hostpath and pv-multimode

# Describe
kubectl describe pv pv-hostpath

# Get reclaim policy
kubectl get pv pv-multimode -o jsonpath='{.spec.persistentVolumeReclaimPolicy}'

# Expected: Delete
```

---

## Level 3: Debugging PV Issues

### Exercise 3.1

**Objective:** A PV is stuck in Released state. Understand why and resolve.

**Setup:**

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: released-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/released-pv
  claimRef:
    name: old-claim
    namespace: deleted-namespace
EOF
```

**Task:**

The PV above has a claimRef to a deleted PVC, making it stuck in Released state. To make it Available again, you need to remove the claimRef. Edit the PV to remove the claimRef so it can be bound to a new PVC.

**Verification:**

```bash
# Check status before fix
kubectl get pv released-pv

# Expected: Released (before fix)

# After fixing
kubectl get pv released-pv

# Expected: Available
```

---

### Exercise 3.2

**Objective:** A PV has invalid capacity. Find and fix the issue.

**Setup:**

Try to create this PV (it will fail):

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: invalid-capacity-pv
spec:
  capacity:
    storage: 1GB
  accessModes:
  - ReadWriteOnce
  hostPath:
    path: /tmp/invalid-pv
EOF
```

**Task:**

The PV creation fails because the capacity format is invalid. Kubernetes uses binary units (Gi, Mi, Ki) not decimal units (GB, MB, KB). Fix the capacity to use the correct format.

**Verification:**

```bash
# After fixing, verify PV exists
kubectl get pv invalid-capacity-pv

# Expected: Shows 1Gi
```

---

### Exercise 3.3

**Objective:** Debug why a PV cannot be used for a specific access mode.

**Setup:**

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: single-mode-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/single-mode-pv
EOF
```

**Task:**

A user wants to mount this PV on multiple nodes simultaneously for reading. Explain why this is not possible with the current configuration and what access mode would be needed.

**Verification:**

```bash
# Check current access modes
kubectl get pv single-mode-pv -o jsonpath='{.spec.accessModes}'

# Expected: ["ReadWriteOnce"]

# For multi-node read access, you would need ReadOnlyMany or ReadWriteMany
```

---

## Level 4: PV Configuration

### Exercise 4.1

**Objective:** Configure a PV with node affinity.

**Setup:**

Get the node name:

```bash
kubectl get nodes -o jsonpath='{.items[0].metadata.name}'
```

**Task:**

Create a PV named `local-affinity-pv` with:
- Capacity: 1Gi
- Access mode: ReadWriteOnce
- Local path: /tmp/local-affinity
- Node affinity restricting to the cluster's node (use the node name from above)

**Verification:**

```bash
# Verify PV exists
kubectl get pv local-affinity-pv

# Verify node affinity is set
kubectl get pv local-affinity-pv -o yaml | grep -A 10 nodeAffinity

# Expected: Shows nodeAffinity with the node name
```

---

### Exercise 4.2

**Objective:** Set up a PV with labels for selective binding.

**Setup:**

None needed.

**Task:**

Create a PV named `labeled-pv` with:
- Capacity: 500Mi
- Access mode: ReadWriteOnce
- Labels: tier=gold, environment=production
- hostPath: /tmp/labeled-pv

**Verification:**

```bash
# Verify labels
kubectl get pv labeled-pv --show-labels

# Expected: Shows tier=gold,environment=production

# Filter by label
kubectl get pv -l tier=gold

# Expected: Shows labeled-pv
```

---

### Exercise 4.3

**Objective:** Configure different reclaim policies.

**Setup:**

None needed.

**Task:**

Create two PVs to understand reclaim policies:
1. `retain-pv`: 1Gi, RWO, Retain policy, hostPath /tmp/retain-pv
2. `delete-pv`: 1Gi, RWO, Delete policy, hostPath /tmp/delete-pv

**Verification:**

```bash
# Check reclaim policies
kubectl get pv retain-pv -o jsonpath='{.spec.persistentVolumeReclaimPolicy}'
# Expected: Retain

kubectl get pv delete-pv -o jsonpath='{.spec.persistentVolumeReclaimPolicy}'
# Expected: Delete
```

---

## Level 5: Complex Scenarios

### Exercise 5.1

**Objective:** Design a PV strategy for a multi-tier application.

**Setup:**

```bash
kubectl create namespace ex-5-1
```

**Task:**

Create PVs for a three-tier application:
1. `database-pv`: 10Gi, RWO, Retain (data must survive deletion)
2. `cache-pv`: 2Gi, RWO, Delete (cache can be recreated)
3. `logs-pv`: 5Gi, RWX, Retain (logs accessed by multiple pods)

All should use hostPath under /tmp/ex-5-1/.

**Verification:**

```bash
# List all PVs with specific criteria
kubectl get pv -o custom-columns='NAME:.metadata.name,CAPACITY:.spec.capacity.storage,ACCESS:.spec.accessModes,RECLAIM:.spec.persistentVolumeReclaimPolicy'

# Expected: Shows all three PVs with correct configurations
```

---

### Exercise 5.2

**Objective:** Diagnose why a PV is not becoming Available.

**Setup:**

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: problem-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nonexistent-class
  hostPath:
    path: /tmp/problem-pv
EOF
```

**Task:**

The PV above has a storageClassName that does not exist. While this does not prevent the PV from being Available, it means PVCs without a storageClassName will not match it. Update the PV to have an empty storageClassName so it can be used with static binding.

**Verification:**

```bash
# Check storageClassName before fix
kubectl get pv problem-pv -o jsonpath='{.spec.storageClassName}'

# Expected: nonexistent-class (before fix)

# After fixing
kubectl get pv problem-pv -o jsonpath='{.spec.storageClassName}'

# Expected: (empty)
```

---

### Exercise 5.3

**Objective:** Pre-provision PVs for specific workloads.

**Setup:**

```bash
kubectl create namespace ex-5-3
```

**Task:**

Pre-provision PVs for a team that needs:
1. 3 identical PVs for a distributed database (pv-db-0, pv-db-1, pv-db-2)
   - Each: 5Gi, RWO, Retain
   - Labels: app=database, replica=0/1/2
2. 1 shared PV for configuration
   - Name: pv-config
   - 100Mi, ROX, Retain
   - Label: app=config

**Verification:**

```bash
# List all database PVs
kubectl get pv -l app=database

# Expected: 3 PVs

# List config PV
kubectl get pv -l app=config

# Expected: 1 PV with 100Mi
```

---

## Cleanup

Delete all PVs created in these exercises:

```bash
kubectl delete pv pv-hostpath pv-multimode released-pv invalid-capacity-pv single-mode-pv local-affinity-pv labeled-pv retain-pv delete-pv database-pv cache-pv logs-pv problem-pv pv-db-0 pv-db-1 pv-db-2 pv-config --ignore-not-found
kubectl delete namespace ex-1-1 ex-1-2 ex-1-3 ex-5-1 ex-5-3 --ignore-not-found
```

---

## Key Takeaways

1. emptyDir volumes are ephemeral and tied to pod lifetime
2. hostPath volumes access the node filesystem directly
3. PersistentVolumes are cluster-scoped storage resources
4. Access modes (RWO, ROX, RWX, RWOP) control how volumes are mounted
5. Reclaim policies (Retain, Delete) determine post-release behavior
6. Use labels for selective PV-to-PVC binding
7. Node affinity constrains local PVs to specific nodes
8. Released PVs need claimRef removed to become Available again
