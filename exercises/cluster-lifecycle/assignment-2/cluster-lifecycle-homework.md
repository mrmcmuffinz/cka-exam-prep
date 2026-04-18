# Cluster Lifecycle Homework: Cluster Upgrades and Maintenance

This homework contains 15 exercises covering cluster upgrades and maintenance operations.

---

## Level 1: Version Information and Planning

### Exercise 1.1

**Objective:** Check cluster version using multiple methods.

**Setup:**
```bash
kubectl create namespace ex-1-1
```

**Task:** Use at least three different commands to determine the Kubernetes version.

**Verification:**
```bash
kubectl version --short 2>/dev/null || kubectl version && echo "SUCCESS"
```

---

### Exercise 1.2

**Objective:** Understand version skew between components.

**Setup:**
```bash
kubectl create namespace ex-1-2
```

**Task:** Check the version of kubelet on each node and compare with the API server version. Document any version differences.

**Verification:**
```bash
kubectl get nodes -o wide && echo "SUCCESS"
```

---

### Exercise 1.3

**Objective:** Research upgrade planning.

**Setup:**
```bash
kubectl create namespace ex-1-3
```

**Task:** Document the steps for planning a cluster upgrade from version 1.29 to 1.30, including what `kubeadm upgrade plan` checks.

**Verification:**
```bash
echo "Document should include: version compatibility, available versions, component changes" && echo "SUCCESS"
```

---

## Level 2: Node Maintenance Operations

### Exercise 2.1

**Objective:** Cordon a node and verify scheduling behavior.

**Setup:**
```bash
kubectl create namespace ex-2-1
```

**Task:** Cordon a worker node, create a deployment with 5 replicas, verify pods are not scheduled to the cordoned node, then uncordon.

**Verification:**
```bash
kubectl cordon kind-worker
kubectl create deployment cordon-test --image=nginx:1.25 --replicas=5 -n ex-2-1
sleep 10
kubectl get pods -n ex-2-1 -o wide | grep -v "kind-worker " | grep -c "Running" | grep -q "5" && echo "Cordon: SUCCESS" || echo "Cordon: Check manually"
kubectl uncordon kind-worker
kubectl delete deployment cordon-test -n ex-2-1
```

---

### Exercise 2.2

**Objective:** Drain a node and verify pod eviction.

**Setup:**
```bash
kubectl create namespace ex-2-2
kubectl create deployment drain-test --image=nginx:1.25 --replicas=6 -n ex-2-2
kubectl wait --for=condition=available deployment/drain-test -n ex-2-2 --timeout=60s
```

**Task:** Drain kind-worker2, verify pods moved to other nodes, then uncordon.

**Verification:**
```bash
kubectl drain kind-worker2 --ignore-daemonsets --timeout=60s
kubectl get pods -n ex-2-2 -o wide | grep "kind-worker2" | wc -l | grep -q "0" && echo "Drain: SUCCESS" || echo "Drain: FAILED"
kubectl uncordon kind-worker2
```

---

### Exercise 2.3

**Objective:** Uncordon a node and verify scheduling resumes.

**Setup:**
```bash
kubectl create namespace ex-2-3
kubectl cordon kind-worker3
kubectl create deployment uncordon-test --image=nginx:1.25 --replicas=3 -n ex-2-3
kubectl wait --for=condition=available deployment/uncordon-test -n ex-2-3 --timeout=60s
```

**Task:** Uncordon kind-worker3, scale the deployment to 9 replicas, verify pods can be scheduled to the uncordoned node.

**Verification:**
```bash
kubectl uncordon kind-worker3
kubectl scale deployment uncordon-test --replicas=9 -n ex-2-3
sleep 10
kubectl get pods -n ex-2-3 -o wide | grep -q "kind-worker3" && echo "Uncordon: SUCCESS" || echo "Uncordon: Check distribution"
kubectl delete deployment uncordon-test -n ex-2-3
```

---

## Level 3: Debugging Drain Issues

### Exercise 3.1

**Objective:** Fix the blocking drain operation.

**Setup:**
```bash
kubectl create namespace ex-3-1
kubectl run standalone-pod --image=nginx:1.25 -n ex-3-1
sleep 5
```

**Task:** Attempt to drain kind-worker. It will fail because of a standalone pod. Find and fix the issue.

**Verification:**
```bash
kubectl drain kind-worker --ignore-daemonsets --force --timeout=30s && echo "Drain: SUCCESS" || echo "Drain: Try with --force"
kubectl uncordon kind-worker
```

---

### Exercise 3.2

**Objective:** Fix the blocking drain due to emptyDir.

**Setup:**
```bash
kubectl create namespace ex-3-2
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-pod
  namespace: ex-3-2
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    volumeMounts:
    - name: cache
      mountPath: /cache
  volumes:
  - name: cache
    emptyDir: {}
EOF
sleep 5
```

**Task:** Drain the node where the emptyDir pod is running. Handle the drain properly.

**Verification:**
```bash
NODE=$(kubectl get pod emptydir-pod -n ex-3-2 -o jsonpath='{.spec.nodeName}')
kubectl drain $NODE --ignore-daemonsets --delete-emptydir-data --timeout=30s && echo "Drain: SUCCESS"
kubectl uncordon $NODE
```

---

### Exercise 3.3

**Objective:** Handle drain blocked by PodDisruptionBudget.

**Setup:**
```bash
kubectl create namespace ex-3-3
kubectl create deployment pdb-test --image=nginx:1.25 --replicas=3 -n ex-3-3
kubectl wait --for=condition=available deployment/pdb-test -n ex-3-3 --timeout=60s
cat <<EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: pdb-test
  namespace: ex-3-3
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: pdb-test
EOF
```

**Task:** The drain will be blocked by PDB. Modify the configuration to allow drain to proceed.

**Verification:**
```bash
# Fix: Either lower minAvailable or increase replicas
kubectl patch pdb pdb-test -n ex-3-3 -p '{"spec":{"minAvailable":1}}'
sleep 5
kubectl drain kind-worker --ignore-daemonsets --timeout=60s && echo "Drain: SUCCESS"
kubectl uncordon kind-worker
```

---

## Level 4: Upgrade Workflow Simulation

### Exercise 4.1

**Objective:** Document the control plane upgrade workflow.

**Setup:**
```bash
kubectl create namespace ex-4-1
```

**Task:** Create a step-by-step runbook for upgrading a control plane node from 1.29 to 1.30. Include all commands and verification steps.

**Verification:**
```bash
echo "Runbook should include: upgrade kubeadm, plan, apply, drain, upgrade kubelet, uncordon" && echo "SUCCESS"
```

---

### Exercise 4.2

**Objective:** Create a multi-node cluster upgrade runbook.

**Setup:**
```bash
kubectl create namespace ex-4-2
```

**Task:** Create a runbook for upgrading a 4-node cluster (1 control plane, 3 workers) with zero downtime for workloads.

**Verification:**
```bash
echo "Runbook should address: order of operations, draining strategy, verification between nodes" && echo "SUCCESS"
```

---

### Exercise 4.3

**Objective:** Verify component versions match post-upgrade.

**Setup:**
```bash
kubectl create namespace ex-4-3
```

**Task:** Document how to verify all components are running the same version after an upgrade.

**Verification:**
```bash
kubectl get nodes -o wide && echo "Nodes: SUCCESS"
kubectl get pods -n kube-system -o custom-columns="NAME:.metadata.name,IMAGE:.spec.containers[0].image" | head -10 && echo "Images: SUCCESS"
```

---

## Level 5: Complex Scenarios

### Exercise 5.1

**Objective:** Rolling node maintenance with workload availability.

**Setup:**
```bash
kubectl create namespace ex-5-1
kubectl create deployment rolling-test --image=nginx:1.25 --replicas=6 -n ex-5-1
kubectl wait --for=condition=available deployment/rolling-test -n ex-5-1 --timeout=60s
cat <<EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: rolling-pdb
  namespace: ex-5-1
spec:
  minAvailable: 4
  selector:
    matchLabels:
      app: rolling-test
EOF
```

**Task:** Drain and uncordon each worker node one at a time while maintaining at least 4 available pods.

**Verification:**
```bash
for NODE in kind-worker kind-worker2 kind-worker3; do
  echo "Processing $NODE"
  kubectl drain $NODE --ignore-daemonsets --timeout=60s
  kubectl get pods -n ex-5-1 --field-selector=status.phase=Running | grep -c "Running"
  kubectl uncordon $NODE
  sleep 5
done
echo "SUCCESS"
```

---

### Exercise 5.2

**Objective:** Handle drain failure and recovery.

**Setup:**
```bash
kubectl create namespace ex-5-2
kubectl create deployment fail-test --image=nginx:1.25 --replicas=3 -n ex-5-2
kubectl wait --for=condition=available deployment/fail-test -n ex-5-2 --timeout=60s
cat <<EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: fail-pdb
  namespace: ex-5-2
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: fail-test
EOF
```

**Task:** Attempt to drain a node. When it fails due to PDB, document the error, adjust the workload to allow drain, complete the drain, then restore original configuration.

**Verification:**
```bash
kubectl scale deployment fail-test --replicas=4 -n ex-5-2
sleep 10
kubectl drain kind-worker --ignore-daemonsets --timeout=60s && echo "Drain: SUCCESS"
kubectl uncordon kind-worker
```

---

### Exercise 5.3

**Objective:** Create upgrade verification checklist.

**Setup:**
```bash
kubectl create namespace ex-5-3
```

**Task:** Create a comprehensive post-upgrade verification checklist that covers nodes, control plane, networking, storage, and workloads.

**Verification:**
```bash
echo "Checklist should include: node versions, control plane pods, DNS, service connectivity, PV/PVC status" && echo "SUCCESS"
```

---

## Cleanup

```bash
kubectl delete namespace ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3
kubectl uncordon kind-worker kind-worker2 kind-worker3 2>/dev/null
```

---

## Key Takeaways

1. **Version skew policy:** kubelet can be one minor version behind API server
2. **Sequential upgrades:** Cannot skip minor versions
3. **Cordon vs drain:** Cordon prevents scheduling, drain evicts pods
4. **Drain flags:** --ignore-daemonsets is almost always required
5. **PDBs:** Can block drain operations, plan accordingly
6. **Upgrade order:** Control plane first, then workers one at a time
