# Cluster Lifecycle Homework: Cluster Installation with kubeadm

This homework contains 15 progressive exercises covering cluster installation concepts and kubeadm artifacts. Since kind abstracts kubeadm operations, these exercises focus on examining artifacts, understanding workflows, and verifying cluster health.

Before starting, ensure you have completed the cluster-lifecycle-tutorial.md file in this directory and have a multi-node kind cluster running.

---

## Level 1: Exploring kubeadm Artifacts

These exercises cover examining the artifacts that kubeadm creates during cluster initialization.

### Exercise 1.1

**Objective:** Examine static pod manifests on the control plane node.

**Setup:**

```bash
kubectl create namespace ex-1-1
```

**Task:**

1. Exec into the kind control plane container
2. List all static pod manifests in /etc/kubernetes/manifests/
3. For each manifest, identify:
   - The component name
   - The container image and version
   - The key command-line arguments

Document your findings.

**Verification:**

```bash
# Check that you identified all 4 control plane components
nerdctl exec kind-control-plane ls /etc/kubernetes/manifests/ | wc -l | grep -q "4" && echo "Manifest count: SUCCESS" || echo "Manifest count: FAILED"

# Verify API server manifest exists
nerdctl exec kind-control-plane test -f /etc/kubernetes/manifests/kube-apiserver.yaml && echo "API server manifest: SUCCESS" || echo "API server manifest: FAILED"
```

---

### Exercise 1.2

**Objective:** Explore the certificate directory structure.

**Setup:**

```bash
kubectl create namespace ex-1-2
```

**Task:**

1. Exec into the kind control plane container
2. List the contents of /etc/kubernetes/pki/
3. Identify:
   - The cluster CA certificate and key files
   - The API server certificate files
   - The etcd certificate directory
   - The service account key pair

For each file type, explain its purpose in the cluster.

**Verification:**

```bash
# CA files exist
nerdctl exec kind-control-plane test -f /etc/kubernetes/pki/ca.crt && echo "CA cert: SUCCESS" || echo "CA cert: FAILED"
nerdctl exec kind-control-plane test -f /etc/kubernetes/pki/ca.key && echo "CA key: SUCCESS" || echo "CA key: FAILED"

# API server files exist
nerdctl exec kind-control-plane test -f /etc/kubernetes/pki/apiserver.crt && echo "API server cert: SUCCESS" || echo "API server cert: FAILED"

# etcd directory exists
nerdctl exec kind-control-plane test -d /etc/kubernetes/pki/etcd && echo "etcd dir: SUCCESS" || echo "etcd dir: FAILED"
```

---

### Exercise 1.3

**Objective:** Verify control plane component pods are running and healthy.

**Setup:**

```bash
kubectl create namespace ex-1-3
```

**Task:**

1. List all pods in the kube-system namespace
2. Identify which pods are control plane components (hint: they have a node name suffix)
3. Check the logs of each control plane component for errors
4. Verify each component is in Running status with all containers ready

Document any errors you find in the logs.

**Verification:**

```bash
# All control plane pods should be running
kubectl get pods -n kube-system -l tier=control-plane --no-headers | grep -c "Running" | grep -q "4" && echo "Control plane pods: SUCCESS" || echo "Control plane pods: FAILED"

# Specific components running
kubectl get pods -n kube-system -l component=kube-apiserver --no-headers | grep -q "Running" && echo "API server: SUCCESS" || echo "API server: FAILED"
kubectl get pods -n kube-system -l component=kube-scheduler --no-headers | grep -q "Running" && echo "Scheduler: SUCCESS" || echo "Scheduler: FAILED"
kubectl get pods -n kube-system -l component=kube-controller-manager --no-headers | grep -q "Running" && echo "Controller manager: SUCCESS" || echo "Controller manager: FAILED"
kubectl get pods -n kube-system -l component=etcd --no-headers | grep -q "Running" && echo "etcd: SUCCESS" || echo "etcd: FAILED"
```

---

## Level 2: Node and Cluster Verification

These exercises cover verifying node prerequisites and cluster health.

### Exercise 2.1

**Objective:** Check node prerequisites inside kind containers.

**Setup:**

```bash
kubectl create namespace ex-2-1
```

**Task:**

1. Exec into the kind control plane container
2. Verify the following prerequisites are met:
   - br_netfilter and overlay kernel modules are loaded
   - net.bridge.bridge-nf-call-iptables is set to 1
   - net.ipv4.ip_forward is set to 1
   - Swap is disabled or minimal

Document the commands you use and the output.

**Verification:**

```bash
# Kernel modules loaded
nerdctl exec kind-control-plane lsmod | grep -q "br_netfilter" && echo "br_netfilter: SUCCESS" || echo "br_netfilter: FAILED"
nerdctl exec kind-control-plane lsmod | grep -q "overlay" && echo "overlay: SUCCESS" || echo "overlay: FAILED"

# Sysctl settings
nerdctl exec kind-control-plane sysctl net.bridge.bridge-nf-call-iptables | grep -q "1" && echo "iptables: SUCCESS" || echo "iptables: FAILED"
nerdctl exec kind-control-plane sysctl net.ipv4.ip_forward | grep -q "1" && echo "ip_forward: SUCCESS" || echo "ip_forward: FAILED"
```

---

### Exercise 2.2

**Objective:** Verify kubelet configuration and status.

**Setup:**

```bash
kubectl create namespace ex-2-2
```

**Task:**

1. Exec into the kind control plane container
2. Check kubelet service status using systemctl
3. Examine the kubelet configuration file at /var/lib/kubelet/config.yaml
4. Identify the following from the config:
   - The static pod path
   - The cluster DNS IP
   - The cluster domain

**Verification:**

```bash
# Kubelet is running
nerdctl exec kind-control-plane systemctl is-active kubelet | grep -q "active" && echo "Kubelet active: SUCCESS" || echo "Kubelet active: FAILED"

# Config file exists
nerdctl exec kind-control-plane test -f /var/lib/kubelet/config.yaml && echo "Config exists: SUCCESS" || echo "Config exists: FAILED"

# Static pod path is correct
nerdctl exec kind-control-plane grep -q "staticPodPath" /var/lib/kubelet/config.yaml && echo "Static pod path: SUCCESS" || echo "Static pod path: FAILED"
```

---

### Exercise 2.3

**Objective:** Verify cluster health using kubectl commands.

**Setup:**

```bash
kubectl create namespace ex-2-3
```

**Task:**

1. Verify all nodes are in Ready state
2. Use kubectl cluster-info to check cluster endpoints
3. Create a test deployment and verify pods can be scheduled
4. Verify DNS is working by checking CoreDNS pods
5. Clean up the test deployment

**Verification:**

```bash
# All nodes ready
kubectl get nodes --no-headers | grep -v "NotReady" | wc -l | grep -q "4" && echo "All nodes ready: SUCCESS" || echo "All nodes ready: FAILED"

# Cluster info works
kubectl cluster-info 2>&1 | grep -q "Kubernetes control plane" && echo "Cluster info: SUCCESS" || echo "Cluster info: FAILED"

# CoreDNS running
kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | grep -q "Running" && echo "CoreDNS: SUCCESS" || echo "CoreDNS: FAILED"
```

---

## Level 3: Debugging Cluster Issues

These exercises present scenarios where you must diagnose problems. The setups simulate issues you might encounter in real clusters.

### Exercise 3.1

**Objective:** Diagnose why a node might appear NotReady.

**Setup:**

```bash
kubectl create namespace ex-3-1
```

**Task:**

A worker node is showing as NotReady. In a real cluster, you would need to diagnose the issue. For this exercise:

1. Check the current status of all nodes
2. For each worker node, describe the node and examine its conditions
3. Document what conditions would indicate:
   - kubelet is not running
   - CNI is not installed
   - Network issues
   - Disk pressure

**Verification:**

```bash
# Document the conditions you identified
kubectl get nodes -o wide && echo "Nodes listed: SUCCESS"

# Describe a worker node
kubectl describe node kind-worker | grep -A5 "Conditions:" && echo "Conditions found: SUCCESS"
```

---

### Exercise 3.2

**Objective:** Understand kubelet troubleshooting.

**Setup:**

```bash
kubectl create namespace ex-3-2
```

**Task:**

If kubelet were not running on a node, the node would be NotReady. For this exercise:

1. Exec into a worker node (kind-worker)
2. Check kubelet status using systemctl
3. View recent kubelet logs using journalctl
4. Identify what configuration kubelet uses
5. Document the commands you would use to restart kubelet if needed

**Verification:**

```bash
# Kubelet is running on worker
nerdctl exec kind-worker systemctl is-active kubelet | grep -q "active" && echo "Worker kubelet: SUCCESS" || echo "Worker kubelet: FAILED"

# Can view kubelet logs
nerdctl exec kind-worker journalctl -u kubelet -n 5 && echo "Logs accessible: SUCCESS"
```

---

### Exercise 3.3

**Objective:** Verify CNI is properly installed.

**Setup:**

```bash
kubectl create namespace ex-3-3
```

**Task:**

Without CNI, pods cannot get IP addresses and nodes stay NotReady. For this exercise:

1. Exec into the control plane node
2. List the CNI configuration files
3. Examine the CNI configuration to identify the network plugin in use
4. Verify pods can communicate by creating two pods and testing connectivity

**Verification:**

```bash
# CNI config exists
nerdctl exec kind-control-plane ls /etc/cni/net.d/ | grep -q ".conf" && echo "CNI config: SUCCESS" || echo "CNI config: FAILED"

# Test pod connectivity
kubectl run test-pod-1 --image=busybox:1.36 -n ex-3-3 --command -- sleep 3600
kubectl run test-pod-2 --image=busybox:1.36 -n ex-3-3 --command -- sleep 3600
sleep 10
POD1_IP=$(kubectl get pod test-pod-1 -n ex-3-3 -o jsonpath='{.status.podIP}')
kubectl exec test-pod-2 -n ex-3-3 -- ping -c 2 $POD1_IP && echo "Pod connectivity: SUCCESS" || echo "Pod connectivity: FAILED"
kubectl delete pod test-pod-1 test-pod-2 -n ex-3-3 --force --grace-period=0
```

---

## Level 4: kubeadm Configuration and Tokens

These exercises cover kubeadm configuration files and bootstrap token management.

### Exercise 4.1

**Objective:** Examine kubeadm configuration.

**Setup:**

```bash
kubectl create namespace ex-4-1
```

**Task:**

1. Kubeadm stores its configuration in a ConfigMap. Find and examine it.
2. Identify the following from the configuration:
   - The Kubernetes version
   - The cluster name
   - The networking configuration (pod and service CIDRs)
3. Document the structure of the kubeadm configuration

**Verification:**

```bash
# Find kubeadm config
kubectl get configmap -n kube-system kubeadm-config -o yaml && echo "Config found: SUCCESS"

# Extract cluster name (may vary based on kind config)
kubectl get configmap -n kube-system kubeadm-config -o jsonpath='{.data.ClusterConfiguration}' | grep -q "clusterName" && echo "Cluster name: SUCCESS" || echo "Cluster name: Check manually"
```

---

### Exercise 4.2

**Objective:** Work with bootstrap tokens.

**Setup:**

```bash
kubectl create namespace ex-4-2
```

**Task:**

1. List all bootstrap token secrets in the kube-system namespace
2. Examine the structure of a bootstrap token secret
3. Identify the following fields:
   - Token ID
   - Token secret (encoded)
   - Expiration time
   - Usages
4. Document what each field means for the join process

**Verification:**

```bash
# Bootstrap tokens exist
kubectl get secrets -n kube-system | grep -q "bootstrap-token" && echo "Tokens exist: SUCCESS" || echo "Tokens exist: FAILED"

# Can describe a token
kubectl get secrets -n kube-system -o name | grep bootstrap-token | head -1 | xargs kubectl describe -n kube-system && echo "Token described: SUCCESS"
```

---

### Exercise 4.3

**Objective:** Understand kubeadm init phases.

**Setup:**

```bash
kubectl create namespace ex-4-3
```

**Task:**

Kubeadm init can be run in phases. For this exercise:

1. Research and document the phases of kubeadm init
2. For each phase, describe what it does
3. Identify which phases create:
   - Certificates
   - kubeconfig files
   - Static pod manifests
   - Cluster configurations

Note: You cannot run kubeadm in kind, but understanding the phases is important for the exam.

**Verification:**

```bash
# Document at least 5 phases (manually verify)
echo "Phases to document:"
echo "1. preflight - checks system requirements"
echo "2. certs - generates certificates"
echo "3. kubeconfig - generates kubeconfig files"
echo "4. kubelet-start - starts kubelet"
echo "5. control-plane - creates static pod manifests"
echo "SUCCESS: Document all phases and their purposes"
```

---

## Level 5: Complex Scenarios

These exercises present complex, realistic scenarios.

### Exercise 5.1

**Objective:** Trace a complete kubeadm init workflow by examining artifacts.

**Setup:**

```bash
kubectl create namespace ex-5-1
```

**Task:**

Trace through the kubeadm init workflow by examining the artifacts it created:

1. **Certificates:** List all certificates in /etc/kubernetes/pki/ and describe the chain of trust
2. **kubeconfig files:** List all kubeconfig files in /etc/kubernetes/ and describe what each is for
3. **Static pods:** Examine each static pod manifest and describe how they interact
4. **Cluster configuration:** Find and document the cluster configuration

Create a document describing how all these artifacts work together.

**Verification:**

```bash
# All artifacts exist
nerdctl exec kind-control-plane ls /etc/kubernetes/pki/ | wc -l | grep -E "^[1-9][0-9]+" && echo "Certs exist: SUCCESS"
nerdctl exec kind-control-plane ls /etc/kubernetes/*.conf | wc -l | grep -E "^[1-9]+" && echo "Kubeconfigs exist: SUCCESS"
nerdctl exec kind-control-plane ls /etc/kubernetes/manifests/*.yaml | wc -l | grep -q "4" && echo "Manifests exist: SUCCESS"
```

---

### Exercise 5.2

**Objective:** Simulate the process of adding a new worker node.

**Setup:**

```bash
kubectl create namespace ex-5-2
```

**Task:**

You cannot actually add a node to a kind cluster, but you can simulate understanding the process:

1. Document the prerequisites a new worker node would need
2. Generate a new bootstrap token (examine how this would work)
3. Document the join command that would be used
4. Describe what happens on the worker node during join
5. Describe how to verify the node joined successfully

**Verification:**

```bash
# Document exists (manual verification)
echo "Document should include:"
echo "1. Prerequisites (container runtime, network settings, etc.)"
echo "2. How to generate a join token"
echo "3. The structure of the kubeadm join command"
echo "4. What happens during join (kubelet starts, node registers)"
echo "5. How to verify (kubectl get nodes)"
echo "SUCCESS: Verify documentation is complete"
```

---

### Exercise 5.3

**Objective:** Create a complete cluster state documentation for handoff.

**Setup:**

```bash
kubectl create namespace ex-5-3
```

**Task:**

Create documentation that captures the complete state of the cluster for handoff to another administrator:

1. **Cluster overview:**
   - Kubernetes version
   - Number and role of nodes
   - Network configuration (CNI, pod CIDR, service CIDR)

2. **Control plane:**
   - Components and their versions
   - Certificate expiration dates (if visible)
   - Configuration highlights

3. **Node status:**
   - Status of each node
   - Key conditions
   - Resources (CPU, memory)

4. **System workloads:**
   - Critical pods in kube-system
   - Their status

**Verification:**

```bash
# Gather cluster info
kubectl version --short 2>/dev/null || kubectl version && echo "Version: SUCCESS"
kubectl get nodes -o wide && echo "Nodes: SUCCESS"
kubectl get pods -n kube-system && echo "System pods: SUCCESS"
kubectl describe nodes | grep -E "^Name:|Allocatable:" && echo "Resources: SUCCESS"
```

---

## Cleanup

Delete all exercise namespaces:

```bash
kubectl delete namespace ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3
```

---

## Key Takeaways

After completing these exercises, you should be able to:

1. **Navigate kubeadm artifacts:** Static pod manifests, certificate directories, kubeconfig files
2. **Verify node prerequisites:** Kernel modules, sysctl settings, container runtime, swap
3. **Check kubelet status:** systemctl, journalctl, configuration files
4. **Verify cluster health:** Node status, control plane pods, DNS, connectivity
5. **Understand bootstrap tokens:** Purpose, structure, creation, expiration
6. **Understand kubeadm phases:** What each phase does during init and join
7. **Document cluster state:** Create comprehensive handoff documentation
