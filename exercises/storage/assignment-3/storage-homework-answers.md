# Storage Homework Answers: StorageClasses and Dynamic Provisioning

Complete solutions for all exercises.

---

## Exercise 1.1 Solution

```bash
kubectl get sc

# Identify default
kubectl get sc -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}{"\n"}{end}'
```

In kind, the default is typically `standard`.

---

## Exercise 1.2 Solution

```bash
kubectl describe sc standard

# Or get provisioner
kubectl get sc standard -o jsonpath='{.provisioner}'
# Output: rancher.io/local-path
```

---

## Exercise 1.3 Solution

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: default-claim
  namespace: ex-1-3
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

kubectl get pvc default-claim -n ex-1-3
```

---

## Exercise 2.1 Solution

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: auto-pvc
  namespace: ex-2-1
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Get the auto-created PV
kubectl get pvc auto-pvc -n ex-2-1 -o jsonpath='{.spec.volumeName}'
kubectl get pv
```

---

## Exercise 2.2 Solution

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
  namespace: ex-2-2
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: data-pod
  namespace: ex-2-2
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo 'persistent' > /data/test.txt && sleep 3600"]
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: app-data
EOF
```

---

## Exercise 2.3 Solution

```bash
# Static (empty storageClassName)
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: static-claim
  namespace: ex-2-3
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: ""
EOF
# This stays Pending unless a matching PV exists

# Dynamic (default class)
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-claim
  namespace: ex-2-3
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
# This gets a PV automatically
```

---

## Exercise 3.1 Solution

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: bad-class-claim
  namespace: ex-3-1
spec:
  storageClassName: nonexistent
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

kubectl describe pvc bad-class-claim -n ex-3-1
# Shows: storageclass.storage.k8s.io "nonexistent" not found
```

---

## Exercise 3.2 Solution

**Problem:** Wrong class name "standrd"

**Fix:** Delete and recreate with correct name "standard":

```bash
kubectl delete pvc typo-claim -n ex-3-2

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fixed-claim
  namespace: ex-3-2
spec:
  storageClassName: standard
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
```

---

## Exercise 3.3 Solution

```bash
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: broken-class
provisioner: fake.provisioner/none
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: broken-claim
  namespace: ex-3-3
spec:
  storageClassName: broken-class
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

kubectl describe pvc broken-claim -n ex-3-3
# Stays Pending because provisioner doesn't exist
```

---

## Exercise 4.1 Solution

```bash
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-storage
provisioner: rancher.io/local-path
reclaimPolicy: Retain
volumeBindingMode: Immediate
EOF
```

---

## Exercise 4.2 Solution

```bash
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: expandable-storage
provisioner: rancher.io/local-path
allowVolumeExpansion: true
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: expandable-claim
  namespace: default
spec:
  storageClassName: expandable-storage
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Wait for binding, then expand
kubectl patch pvc expandable-claim -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'
```

---

## Exercise 4.3 Solution

```bash
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: waitfirst-storage
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
EOF

kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: delayed-claim
  namespace: ex-4-3
spec:
  storageClassName: waitfirst-storage
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

kubectl get pvc delayed-claim -n ex-4-3
# Status: Pending (WaitForFirstConsumer)

# Create pod to trigger binding
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: trigger-pod
  namespace: ex-4-3
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: delayed-claim
EOF

kubectl get pvc delayed-claim -n ex-4-3
# Status: Bound
```

---

## Exercise 5.1 Solution

```bash
# Get current default
kubectl get sc

# Remove default annotation from current
kubectl patch sc standard -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

# Create new class with default
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: new-default
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
EOF

kubectl get sc
# new-default should show (default)
```

---

## Exercise 5.2 Solution

```bash
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: expand-test
provisioner: rancher.io/local-path
allowVolumeExpansion: true
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grow-claim
  namespace: ex-5-2
spec:
  storageClassName: expand-test
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: data-pod
  namespace: ex-5-2
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo 'important data' > /data/file.txt && sleep 3600"]
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: grow-claim
EOF

# Wait for pod, then expand
kubectl patch pvc grow-claim -n ex-5-2 -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'

# Verify data persists
kubectl exec -n ex-5-2 data-pod -- cat /data/file.txt
```

---

## Exercise 5.3 Solution

```bash
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: false
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: archive
provisioner: rancher.io/local-path
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF
```

---

## Common Mistakes

1. **Non-existent StorageClass:** PVC stays Pending
2. **Multiple defaults:** Unpredictable behavior
3. **Expecting expansion without allowVolumeExpansion:** Fails
4. **WaitForFirstConsumer confusion:** PVC Pending until pod scheduled
5. **Wrong provisioner:** PVC stays Pending

---

## StorageClass Commands Cheat Sheet

| Task | Command |
|------|---------|
| List StorageClasses | `kubectl get sc` |
| Get default | `kubectl get sc -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'` |
| Describe SC | `kubectl describe sc <name>` |
| Set as default | `kubectl patch sc <name> -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'` |
| Remove default | `kubectl patch sc <name> -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'` |
