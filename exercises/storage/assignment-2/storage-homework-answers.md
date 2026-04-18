# Storage Homework Answers: PersistentVolumeClaims and Binding

Complete solutions for all exercises.

---

## Exercise 1.1 Solution

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: basic-claim
  namespace: ex-1-1
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 500Mi
  storageClassName: ""
EOF
```

---

## Exercise 1.2 Solution

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-claim
  namespace: ex-1-2
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
  storageClassName: ""
---
apiVersion: v1
kind: Pod
metadata:
  name: data-pod
  namespace: ex-1-2
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo test > /data/test.txt && sleep 3600"]
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: data-claim
EOF
```

---

## Exercise 2.1 Solution

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: large-claim
  namespace: ex-2-1
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 3Gi
  storageClassName: ""
EOF

# Binds to pv-large (5Gi) because it's the only PV >= 3Gi
```

---

## Exercise 2.2 Solution

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: selective-claim
  namespace: ex-2-2
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
  storageClassName: ""
  selector:
    matchLabels:
      size: medium
EOF
```

---

## Exercise 2.3 Solution

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rwx-claim
  namespace: ex-2-3
spec:
  accessModes: ["ReadWriteMany"]
  resources:
    requests:
      storage: 1Gi
  storageClassName: ""
EOF

# Binds to pv-large (only RWX PV)
```

---

## Exercise 3.1 Solution

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: too-big-claim
  namespace: ex-3-1
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 10Gi
  storageClassName: ""
EOF

kubectl describe pvc too-big-claim -n ex-3-1
# Shows: no persistent volumes available for this claim
```

---

## Exercise 3.2 Solution

**Problem:** pv-large only supports RWX, not RWO.

**Fix:** Change access mode to RWX:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fixed-claim
  namespace: ex-3-2
spec:
  accessModes: ["ReadWriteMany"]
  resources:
    requests:
      storage: 1Gi
  storageClassName: ""
  selector:
    matchLabels:
      size: large
EOF
```

---

## Exercise 3.3 Solution

**Fix:** Change storageClassName to empty:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fixed-class-claim
  namespace: ex-3-3
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 500Mi
  storageClassName: ""
EOF
```

---

## Exercise 4.1 Solution

```bash
# Create PV with Retain
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: retain-test-pv
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/retain-test
EOF

# Create PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: retain-claim
  namespace: ex-4-1
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
  storageClassName: ""
EOF

# Delete PVC
kubectl delete pvc retain-claim -n ex-4-1

# Check PV status
kubectl get pv retain-test-pv
# Status: Released
```

---

## Exercise 4.2 Solution

```bash
# Create PV with Delete
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: delete-test-pv
spec:
  capacity:
    storage: 1Gi
  accessModes: ["ReadWriteOnce"]
  persistentVolumeReclaimPolicy: Delete
  storageClassName: ""
  hostPath:
    path: /tmp/delete-test
EOF

# Create and delete PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: delete-claim
  namespace: ex-4-2
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
  storageClassName: ""
EOF

kubectl delete pvc delete-claim -n ex-4-2

# Check PV - should be deleted
kubectl get pv delete-test-pv
# Not found
```

---

## Exercise 4.3 Solution

```bash
# Use the Released PV from 4.1
kubectl patch pv retain-test-pv --type=json -p='[{"op":"remove","path":"/spec/claimRef"}]'

kubectl get pv retain-test-pv
# Status: Available

# Create new PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: reuse-claim
  namespace: ex-4-3
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
  storageClassName: ""
EOF
```

---

## Exercise 5.1 Solution

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-claim
  namespace: ex-5-1
spec:
  accessModes: ["ReadWriteMany"]
  resources:
    requests:
      storage: 1Gi
  storageClassName: ""
---
apiVersion: v1
kind: Pod
metadata:
  name: writer-1
  namespace: ex-5-1
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo 'from pod 1' >> /data/log.txt && sleep 3600"]
    volumeMounts:
    - name: shared
      mountPath: /data
  volumes:
  - name: shared
    persistentVolumeClaim:
      claimName: shared-claim
---
apiVersion: v1
kind: Pod
metadata:
  name: writer-2
  namespace: ex-5-1
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5 && echo 'from pod 2' >> /data/log.txt && sleep 3600"]
    volumeMounts:
    - name: shared
      mountPath: /data
  volumes:
  - name: shared
    persistentVolumeClaim:
      claimName: shared-claim
EOF
```

---

## Exercise 5.2 Solution

```bash
# Create matching PV
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: gold-pv
  labels:
    tier: gold
spec:
  capacity:
    storage: 2Gi
  accessModes: ["ReadOnlyMany"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/gold-pv
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gold-claim
  namespace: ex-5-2
spec:
  accessModes: ["ReadOnlyMany"]
  resources:
    requests:
      storage: 1Gi
  storageClassName: ""
  selector:
    matchLabels:
      tier: gold
EOF
```

---

## Exercise 5.3 Solution

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: app-data-pv
spec:
  capacity:
    storage: 5Gi
  accessModes: ["ReadWriteOnce", "ReadOnlyMany"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /tmp/app-data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: primary-claim
  namespace: ex-5-3
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 5Gi
  storageClassName: ""
EOF

# Replicas would use the same PVC with ROX access mode
# In practice, you'd need a shared filesystem that supports this
```

---

## Common Mistakes

1. **Requesting more than available:** No PV with sufficient capacity causes Pending
2. **Access mode mismatch:** PV must support all modes requested by PVC
3. **StorageClass mismatch:** Empty string != no storageClassName specified
4. **Released PV not reusable:** Must remove claimRef first
5. **Expecting RWX on hostPath:** hostPath is inherently node-local

---

## PVC Commands Cheat Sheet

| Task | Command |
|------|---------|
| List PVCs | `kubectl get pvc -n <ns>` |
| Describe PVC | `kubectl describe pvc <name> -n <ns>` |
| Get bound PV | `kubectl get pvc <name> -o jsonpath='{.spec.volumeName}'` |
| Delete PVC | `kubectl delete pvc <name> -n <ns>` |
