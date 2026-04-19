# Cluster Lifecycle Homework Answers: Cluster Upgrades and Maintenance

Complete solutions for all 15 exercises.

---

## Exercise 1.1 Solution

**Methods to check version:**

```bash
# Method 1: kubectl version
kubectl version

# Method 2: Node version
kubectl get nodes -o wide

# Method 3: API server version via curl
kubectl get --raw /version

# Method 4: kubeadm (in node)
nerdctl exec kind-control-plane kubeadm version
```

---

## Exercise 1.2 Solution

```bash
kubectl get nodes -o custom-columns="NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion"
kubectl version --short 2>/dev/null | grep Server
```

In kind clusters, all nodes typically run the same version.

---

## Exercise 1.3 Solution

**Upgrade planning document:**

1. **Pre-upgrade checks:**
   - Current version: `kubectl version`
   - Node status: `kubectl get nodes`
   - Workload status: `kubectl get pods --all-namespaces`

2. **kubeadm upgrade plan checks:**
   - Current cluster version
   - Available upgrade versions
   - Component versions that will be upgraded
   - Required manual actions

3. **Prerequisites:**
   - Backup etcd
   - Review release notes
   - Ensure sufficient resources

---

## Exercise 2.1 Solution

```bash
kubectl cordon kind-worker
kubectl create deployment cordon-test --image=nginx:1.25 --replicas=5 -n ex-2-1
sleep 10
kubectl get pods -n ex-2-1 -o wide
# All pods should be on worker2 or worker3, not on cordoned worker
kubectl uncordon kind-worker
kubectl delete deployment cordon-test -n ex-2-1
```

---

## Exercise 2.2 Solution

```bash
kubectl drain kind-worker2 --ignore-daemonsets
kubectl get pods -n ex-2-2 -o wide
# No pods should be on kind-worker2
kubectl uncordon kind-worker2
```

---

## Exercise 2.3 Solution

```bash
kubectl uncordon kind-worker3
kubectl scale deployment uncordon-test --replicas=9 -n ex-2-3
sleep 10
kubectl get pods -n ex-2-3 -o wide
# Some pods should now be on kind-worker3
```

---

## Exercise 3.1 Solution

**Issue:** Standalone pod blocks drain because it is not managed by a controller.

**Fix:**
```bash
kubectl drain kind-worker --ignore-daemonsets --force
kubectl uncordon kind-worker
```

**Explanation:** The --force flag deletes standalone pods (pods not managed by ReplicaSet, Deployment, etc.). Without a controller, these pods will not be recreated.

---

## Exercise 3.2 Solution

**Issue:** Pod with emptyDir volume blocks drain by default.

**Fix:**
```bash
NODE=$(kubectl get pod emptydir-pod -n ex-3-2 -o jsonpath='{.spec.nodeName}')
kubectl drain $NODE --ignore-daemonsets --delete-emptydir-data
kubectl uncordon $NODE
```

**Explanation:** The --delete-emptydir-data flag acknowledges that emptyDir data will be lost when the pod is evicted.

---

## Exercise 3.3 Solution

**Issue:** PDB requires minAvailable=3 but only 3 replicas exist.

**Fix options:**

Option 1: Lower minAvailable
```bash
kubectl patch pdb pdb-test -n ex-3-3 -p '{"spec":{"minAvailable":1}}'
```

Option 2: Increase replicas
```bash
kubectl scale deployment pdb-test --replicas=5 -n ex-3-3
```

Then drain:
```bash
kubectl drain kind-worker --ignore-daemonsets --timeout=60s
kubectl uncordon kind-worker
```

---

## Exercise 4.1 Solution

**Control Plane Upgrade Runbook:**

```markdown
# Control Plane Upgrade: 1.29 to 1.30

## 1. Pre-upgrade
kubectl get nodes
kubectl get pods -n kube-system
# Backup etcd

## 2. Upgrade kubeadm (on control plane node)
apt-get update
apt-get install -y kubeadm=1.30.0-00
kubeadm version

## 3. Plan upgrade
kubeadm upgrade plan

## 4. Apply upgrade
kubeadm upgrade apply v1.30.0

## 5. Drain control plane (from another machine)
kubectl drain <control-plane> --ignore-daemonsets

## 6. Upgrade kubelet (on control plane node)
apt-get install -y kubelet=1.30.0-00 kubectl=1.30.0-00
systemctl daemon-reload
systemctl restart kubelet

## 7. Uncordon (from another machine)
kubectl uncordon <control-plane>

## 8. Verify
kubectl get nodes
kubectl get pods -n kube-system
```

---

## Exercise 4.2 Solution

**Multi-Node Cluster Upgrade Runbook:**

```markdown
# Cluster Upgrade: 4 Nodes (1 CP, 3 Workers)

## Order of Operations
1. Control plane first
2. Workers one at a time

## Control Plane (see Exercise 4.1)

## Each Worker Node
1. kubectl drain <worker> --ignore-daemonsets
2. (On worker) apt-get install -y kubeadm=1.30.0-00
3. (On worker) kubeadm upgrade node
4. (On worker) apt-get install -y kubelet=1.30.0-00 kubectl=1.30.0-00
5. (On worker) systemctl daemon-reload && systemctl restart kubelet
6. kubectl uncordon <worker>
7. kubectl get nodes (verify Ready)
8. Wait for pods to stabilize before next worker

## Zero Downtime Strategy
- Ensure deployments have multiple replicas
- Use PDBs to maintain minimum availability
- Drain one worker at a time
```

---

## Exercise 4.3 Solution

**Version Verification:**

```bash
# Node versions
kubectl get nodes -o custom-columns="NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion"

# Control plane component versions
kubectl get pods -n kube-system -o custom-columns="NAME:.metadata.name,IMAGE:.spec.containers[0].image" | grep -E "kube-apiserver|kube-controller|kube-scheduler|etcd"

# kubeadm version (on each node)
kubeadm version

# API server version
kubectl version
```

---

## Exercise 5.1 Solution

```bash
for NODE in kind-worker kind-worker2 kind-worker3; do
  echo "=== Draining $NODE ==="
  kubectl drain $NODE --ignore-daemonsets --timeout=120s
  
  echo "Checking pod availability..."
  kubectl get pods -n ex-5-1 --field-selector=status.phase=Running --no-headers | wc -l
  
  echo "=== Uncordoning $NODE ==="
  kubectl uncordon $NODE
  
  sleep 10
done
```

---

## Exercise 5.2 Solution

```bash
# Attempt drain (will fail)
kubectl drain kind-worker --ignore-daemonsets --timeout=30s

# Check error message
# "Cannot evict pod as it would violate the pod's disruption budget"

# Fix: Increase replicas to allow drain
kubectl scale deployment fail-test --replicas=4 -n ex-5-2
sleep 10

# Retry drain
kubectl drain kind-worker --ignore-daemonsets --timeout=60s

# Uncordon
kubectl uncordon kind-worker

# Restore original replicas
kubectl scale deployment fail-test --replicas=3 -n ex-5-2
```

---

## Exercise 5.3 Solution

**Post-Upgrade Verification Checklist:**

```markdown
# Post-Upgrade Verification

## 1. Node Health
- [ ] All nodes Ready: kubectl get nodes
- [ ] All nodes same version: kubectl get nodes -o wide
- [ ] No SchedulingDisabled: kubectl get nodes | grep -v SchedulingDisabled

## 2. Control Plane
- [ ] API server responding: kubectl cluster-info
- [ ] All control plane pods Running: kubectl get pods -n kube-system -l tier=control-plane
- [ ] Component versions match: kubectl get pods -n kube-system -o custom-columns="NAME:.metadata.name,IMAGE:.spec.containers[0].image"

## 3. Networking
- [ ] CoreDNS running: kubectl get pods -n kube-system -l k8s-app=kube-dns
- [ ] DNS resolution working: kubectl run test --image=busybox:1.36 --rm -it -- nslookup kubernetes
- [ ] Pod-to-pod connectivity: (create two pods, ping between them)
- [ ] Services working: kubectl get svc --all-namespaces

## 4. Storage
- [ ] PVs in correct state: kubectl get pv
- [ ] PVCs bound: kubectl get pvc --all-namespaces
- [ ] StorageClasses available: kubectl get storageclass

## 5. Workloads
- [ ] All Deployments available: kubectl get deployments --all-namespaces
- [ ] No crashlooping pods: kubectl get pods --all-namespaces | grep -v Running
- [ ] DaemonSets on all nodes: kubectl get daemonsets -n kube-system
```

---

## Common Mistakes

1. **Forgetting --ignore-daemonsets:** Almost always required for drain
2. **Not understanding drain also cordons:** No need to cordon separately before drain
3. **Trying to drain standalone pods without --force:** Will fail
4. **Skipping kubeadm upgrade node on workers:** Using apply instead (wrong)
5. **Not restarting kubelet after upgrade:** New version not in effect
6. **Upgrading kubelet before kubeadm upgrade:** Wrong order

---

## Verification Commands Cheat Sheet

| Task | Command |
|------|---------|
| Check versions | `kubectl get nodes -o wide` |
| Cordon | `kubectl cordon <node>` |
| Uncordon | `kubectl uncordon <node>` |
| Drain | `kubectl drain <node> --ignore-daemonsets` |
| Force drain | `kubectl drain <node> --ignore-daemonsets --force` |
| Drain with emptyDir | `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data` |
| Check scheduling | `kubectl get nodes` |
| List PDBs | `kubectl get pdb --all-namespaces` |
