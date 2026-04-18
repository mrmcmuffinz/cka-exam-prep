# Storage Homework Answers: Volumes and PersistentVolumes

This file contains complete solutions for all 15 exercises on volumes and PersistentVolumes.

---

## Exercise 1.1 Solution

**Task:** Create pod with emptyDir.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: temp-storage
  namespace: ex-1-1
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo 'cached data' > /cache/data.txt && sleep 3600"]
    volumeMounts:
    - name: cache
      mountPath: /cache
  volumes:
  - name: cache
    emptyDir: {}
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: temp-storage
  namespace: ex-1-1
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo 'cached data' > /cache/data.txt && sleep 3600"]
    volumeMounts:
    - name: cache
      mountPath: /cache
  volumes:
  - name: cache
    emptyDir: {}
EOF
```

**Explanation:** emptyDir creates an empty directory that exists for the lifetime of the pod. Data is lost when the pod is deleted.

---

## Exercise 1.2 Solution

**Task:** Create pod with hostPath.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: host-storage
  namespace: ex-1-2
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo 'host data' > /host-data/file.txt && sleep 3600"]
    volumeMounts:
    - name: host-volume
      mountPath: /host-data
  volumes:
  - name: host-volume
    hostPath:
      path: /tmp/ex-1-2-data
      type: DirectoryOrCreate
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: host-storage
  namespace: ex-1-2
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo 'host data' > /host-data/file.txt && sleep 3600"]
    volumeMounts:
    - name: host-volume
      mountPath: /host-data
  volumes:
  - name: host-volume
    hostPath:
      path: /tmp/ex-1-2-data
      type: DirectoryOrCreate
EOF
```

**Explanation:** hostPath mounts a directory from the host into the pod. DirectoryOrCreate creates the directory if it does not exist.

---

## Exercise 1.3 Solution

**Task:** Multi-container pod with shared volume.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container
  namespace: ex-1-3
spec:
  containers:
  - name: writer
    image: busybox:1.36
    command: ["sh", "-c", "echo 'shared message' > /shared/message.txt && sleep 3600"]
    volumeMounts:
    - name: shared
      mountPath: /shared
  - name: reader
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5 && cat /shared/message.txt && sleep 3600"]
    volumeMounts:
    - name: shared
      mountPath: /shared
  volumes:
  - name: shared
    emptyDir: {}
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: multi-container
  namespace: ex-1-3
spec:
  containers:
  - name: writer
    image: busybox:1.36
    command: ["sh", "-c", "echo 'shared message' > /shared/message.txt && sleep 3600"]
    volumeMounts:
    - name: shared
      mountPath: /shared
  - name: reader
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5 && cat /shared/message.txt && sleep 3600"]
    volumeMounts:
    - name: shared
      mountPath: /shared
  volumes:
  - name: shared
    emptyDir: {}
EOF
```

**Explanation:** Both containers mount the same emptyDir volume, allowing them to share data.

---

## Exercise 2.1 Solution

**Task:** Create PV with hostPath.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-hostpath
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/pv-hostpath-data
    type: DirectoryOrCreate
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-hostpath
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/pv-hostpath-data
    type: DirectoryOrCreate
EOF
```

**Explanation:** A basic PV with hostPath backend. Empty storageClassName enables static binding.

---

## Exercise 2.2 Solution

**Task:** Create PV with multiple access modes.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-multimode
spec:
  capacity:
    storage: 2Gi
  accessModes:
  - ReadWriteOnce
  - ReadOnlyMany
  persistentVolumeReclaimPolicy: Delete
  storageClassName: ""
  hostPath:
    path: /tmp/pv-multimode-data
    type: DirectoryOrCreate
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-multimode
spec:
  capacity:
    storage: 2Gi
  accessModes:
  - ReadWriteOnce
  - ReadOnlyMany
  persistentVolumeReclaimPolicy: Delete
  storageClassName: ""
  hostPath:
    path: /tmp/pv-multimode-data
    type: DirectoryOrCreate
EOF
```

**Explanation:** A PV can support multiple access modes. The actual mode used depends on the PVC that binds to it.

---

## Exercise 2.3 Solution

**Task:** List and describe PVs.

```bash
# List PVs
kubectl get pv

# Describe
kubectl describe pv pv-hostpath

# Get reclaim policy
kubectl get pv pv-multimode -o jsonpath='{.spec.persistentVolumeReclaimPolicy}'
```

**Explanation:** Standard kubectl commands work with PVs just like other resources.

---

## Exercise 3.1 Solution

**Problem:** PV is stuck in Released state due to claimRef.

**Fix:**

```bash
kubectl patch pv released-pv --type=json -p='[{"op": "remove", "path": "/spec/claimRef"}]'
```

Or edit manually:

```bash
kubectl edit pv released-pv
# Remove the claimRef section
```

**Explanation:** When a PVC is deleted, the PV with Retain policy keeps the claimRef. Remove it to make the PV Available again.

---

## Exercise 3.2 Solution

**Problem:** Invalid capacity format (GB instead of Gi).

**Fix:**

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: invalid-capacity-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  hostPath:
    path: /tmp/invalid-pv
    type: DirectoryOrCreate
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: invalid-capacity-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  storageClassName: ""
  hostPath:
    path: /tmp/invalid-pv
    type: DirectoryOrCreate
EOF
```

**Explanation:** Kubernetes uses binary units (Ki, Mi, Gi, Ti) not decimal units (KB, MB, GB, TB).

---

## Exercise 3.3 Solution

**Analysis:**

The PV has only ReadWriteOnce access mode, which means it can only be mounted by one node at a time. For multi-node read access, you would need either ReadOnlyMany (ROX) or ReadWriteMany (RWX).

To fix, you would need to recreate the PV with additional access modes:

```yaml
accessModes:
- ReadWriteOnce
- ReadOnlyMany
```

Note that hostPath volumes inherently only work on a single node, so even with ROX, the pods would need to be on the same node.

---

## Exercise 4.1 Solution

**Task:** Create PV with node affinity.

```bash
# Get node name
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-affinity-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  local:
    path: /tmp/local-affinity
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $NODE_NAME
EOF
```

**Explanation:** Node affinity ensures the PV is only used by pods scheduled on the specified node.

---

## Exercise 4.2 Solution

**Task:** Create PV with labels.

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: labeled-pv
  labels:
    tier: gold
    environment: production
spec:
  capacity:
    storage: 500Mi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/labeled-pv
    type: DirectoryOrCreate
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: labeled-pv
  labels:
    tier: gold
    environment: production
spec:
  capacity:
    storage: 500Mi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/labeled-pv
    type: DirectoryOrCreate
EOF
```

**Explanation:** Labels enable PVCs to select specific PVs using label selectors.

---

## Exercise 4.3 Solution

**Task:** Create PVs with different reclaim policies.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: retain-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/retain-pv
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: delete-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: ""
  hostPath:
    path: /tmp/delete-pv
    type: DirectoryOrCreate
EOF
```

**Explanation:** Retain keeps the PV and data after PVC deletion. Delete removes the PV (and underlying storage if applicable).

---

## Exercise 5.1 Solution

**Task:** Create PVs for multi-tier application.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: database-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/ex-5-1/database
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: cache-pv
spec:
  capacity:
    storage: 2Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: ""
  hostPath:
    path: /tmp/ex-5-1/cache
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: logs-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/ex-5-1/logs
    type: DirectoryOrCreate
EOF
```

**Explanation:** Different tiers have different requirements. Database needs Retain for data safety. Cache can use Delete since it is recreatable. Logs need RWX for multi-pod access.

---

## Exercise 5.2 Solution

**Problem:** PV has a storageClassName that prevents static binding.

**Fix:**

```bash
kubectl patch pv problem-pv --type=json -p='[{"op": "replace", "path": "/spec/storageClassName", "value": ""}]'
```

Or apply a corrected version:

```bash
kubectl delete pv problem-pv
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
  storageClassName: ""
  hostPath:
    path: /tmp/problem-pv
    type: DirectoryOrCreate
EOF
```

**Explanation:** An empty storageClassName allows static binding. A non-existent class prevents matching with PVCs that have no class.

---

## Exercise 5.3 Solution

**Task:** Pre-provision PVs for team.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-db-0
  labels:
    app: database
    replica: "0"
spec:
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/ex-5-3/db-0
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-db-1
  labels:
    app: database
    replica: "1"
spec:
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/ex-5-3/db-1
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-db-2
  labels:
    app: database
    replica: "2"
spec:
  capacity:
    storage: 5Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/ex-5-3/db-2
    type: DirectoryOrCreate
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-config
  labels:
    app: config
spec:
  capacity:
    storage: 100Mi
  accessModes:
  - ReadOnlyMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/ex-5-3/config
    type: DirectoryOrCreate
EOF
```

**Explanation:** Pre-provisioning PVs with consistent naming and labels makes it easier for PVCs to select the right storage.

---

## Common Mistakes

### hostPath not existing on node

Use `type: DirectoryOrCreate` to automatically create the directory.

### Access mode not matching workload requirements

RWO for single-node, ROX for multi-node read, RWX for multi-node write. Match the mode to your workload.

### Reclaim policy misunderstanding

Retain keeps data but leaves PV in Released state. Delete removes PV. Neither automatically makes the PV available for reuse without intervention.

### Local volume without node affinity

Local volumes require node affinity to ensure pods are scheduled on the node with the storage.

### Capacity format errors

Use Gi, Mi, Ki (binary units), not GB, MB, KB (decimal units).

---

## PV Commands Cheat Sheet

| Task | Command |
|------|---------|
| List PVs | `kubectl get pv` |
| Describe PV | `kubectl describe pv <name>` |
| Get PV YAML | `kubectl get pv <name> -o yaml` |
| Delete PV | `kubectl delete pv <name>` |
| Get capacity | `kubectl get pv <name> -o jsonpath='{.spec.capacity.storage}'` |
| Get access modes | `kubectl get pv <name> -o jsonpath='{.spec.accessModes}'` |
| Get phase | `kubectl get pv <name> -o jsonpath='{.status.phase}'` |
| Get reclaim policy | `kubectl get pv <name> -o jsonpath='{.spec.persistentVolumeReclaimPolicy}'` |
| Filter by label | `kubectl get pv -l <label>=<value>` |
| Remove claimRef | `kubectl patch pv <name> --type=json -p='[{"op":"remove","path":"/spec/claimRef"}]'` |
