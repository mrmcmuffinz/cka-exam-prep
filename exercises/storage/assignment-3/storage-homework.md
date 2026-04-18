# Storage Homework: StorageClasses and Dynamic Provisioning

This homework contains 15 progressive exercises on StorageClasses.

---

## Level 1: StorageClass Basics

### Exercise 1.1

**Task:** List all StorageClasses in the cluster and identify which one is the default.

**Verification:**
```bash
kubectl get sc
kubectl get sc -o yaml | grep -A5 annotations
```

---

### Exercise 1.2

**Task:** Describe the default StorageClass and identify its provisioner.

**Verification:**
```bash
kubectl describe sc <default-class>
# Note the provisioner
```

---

### Exercise 1.3

**Setup:** `kubectl create namespace ex-1-3`

**Task:** Create a PVC named `default-claim` without specifying storageClassName. Verify it uses the default class and gets bound.

**Verification:**
```bash
kubectl get pvc default-claim -n ex-1-3
# Should be Bound
```

---

## Level 2: Dynamic Provisioning

### Exercise 2.1

**Setup:** `kubectl create namespace ex-2-1`

**Task:** Create a PVC and observe the automatic PV creation. Document the PV name that was created.

---

### Exercise 2.2

**Setup:** `kubectl create namespace ex-2-2`

**Task:** Create a PVC using the default class and mount it in a pod. Write data to it and verify persistence.

---

### Exercise 2.3

**Setup:** `kubectl create namespace ex-2-3`

**Task:** Compare static provisioning (empty storageClassName) vs dynamic provisioning (default class). Create one PVC of each type.

---

## Level 3: Debugging StorageClass Issues

### Exercise 3.1

**Setup:** `kubectl create namespace ex-3-1`

**Task:** Create a PVC with storageClassName: "nonexistent". Observe it stays Pending. Diagnose using describe.

---

### Exercise 3.2

**Setup:** `kubectl create namespace ex-3-2`

**Task:** Create a PVC with a typo in the class name (e.g., "standrd" instead of "standard"). Fix the issue.

---

### Exercise 3.3

**Setup:** `kubectl create namespace ex-3-3`

**Task:** Create a StorageClass with an invalid provisioner. Create a PVC using it. Observe the failure and diagnose.

---

## Level 4: Advanced Configuration

### Exercise 4.1

**Task:** Create a custom StorageClass named `fast-storage` with:
- provisioner: rancher.io/local-path
- reclaimPolicy: Retain
- volumeBindingMode: Immediate

---

### Exercise 4.2

**Task:** Create a StorageClass with allowVolumeExpansion: true. Create a PVC using it, then expand the PVC.

---

### Exercise 4.3

**Setup:** `kubectl create namespace ex-4-3`

**Task:** Create a StorageClass with WaitForFirstConsumer binding mode. Create a PVC and verify it stays Pending until a pod uses it.

---

## Level 5: Complex Scenarios

### Exercise 5.1

**Task:** Change the default StorageClass from the current default to a custom class you create.

---

### Exercise 5.2

**Setup:** `kubectl create namespace ex-5-2`

**Task:** Create a PVC with allowVolumeExpansion class, mount it in a pod, write data, then expand the PVC and verify the data persists.

---

### Exercise 5.3

**Task:** Design a storage strategy with three StorageClasses:
- `fast`: Immediate binding, Delete reclaim, no expansion
- `standard`: WaitForFirstConsumer, Delete reclaim, expansion enabled
- `archive`: WaitForFirstConsumer, Retain reclaim, expansion enabled

---

## Cleanup

```bash
kubectl delete namespace ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 ex-4-3 ex-5-2 --ignore-not-found
kubectl delete sc fast-storage expandable-storage waitfirst-storage fast standard archive --ignore-not-found
```

---

## Key Takeaways

1. StorageClasses enable automatic PV provisioning
2. The default class is used when no class is specified
3. WaitForFirstConsumer delays binding for zone-aware scheduling
4. allowVolumeExpansion enables PVC resizing
5. Only one StorageClass should be marked as default
