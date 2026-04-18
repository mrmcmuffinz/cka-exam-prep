# Cluster Lifecycle Homework Answers: Cluster Installation with kubeadm

This file contains complete solutions for all 15 exercises. For conceptual exercises, detailed explanations are provided.

---

## Exercise 1.1 Solution

**Task:** Examine static pod manifests on the control plane node.

**Solution:**

```bash
# Exec into control plane
nerdctl exec -it kind-control-plane /bin/bash

# List manifests
ls /etc/kubernetes/manifests/
# Output: etcd.yaml  kube-apiserver.yaml  kube-controller-manager.yaml  kube-scheduler.yaml

# Examine each manifest
cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -E "image:|--"
cat /etc/kubernetes/manifests/kube-scheduler.yaml | grep -E "image:|--"
cat /etc/kubernetes/manifests/kube-controller-manager.yaml | grep -E "image:|--"
cat /etc/kubernetes/manifests/etcd.yaml | grep -E "image:|--"

exit
```

**Key findings:**

| Component | Key Arguments |
|-----------|---------------|
| kube-apiserver | --advertise-address, --secure-port=6443, --etcd-servers, --service-cluster-ip-range |
| kube-scheduler | --kubeconfig, --leader-elect=true |
| kube-controller-manager | --kubeconfig, --leader-elect=true, --cluster-cidr |
| etcd | --data-dir, --listen-client-urls, --advertise-client-urls |

---

## Exercise 1.2 Solution

**Task:** Explore the certificate directory structure.

**Solution:**

```bash
nerdctl exec kind-control-plane ls -la /etc/kubernetes/pki/
```

**Key files and purposes:**

| File | Purpose |
|------|---------|
| ca.crt, ca.key | Cluster CA, signs all other certificates |
| apiserver.crt, apiserver.key | API server serving certificate |
| apiserver-kubelet-client.crt | API server client cert for kubelet |
| apiserver-etcd-client.crt | API server client cert for etcd |
| front-proxy-ca.crt, front-proxy-ca.key | CA for aggregated API servers |
| front-proxy-client.crt | Client cert for front proxy |
| sa.key, sa.pub | Service account signing keys |
| etcd/ca.crt | etcd-specific CA |
| etcd/server.crt | etcd serving certificate |
| etcd/peer.crt | etcd peer communication |

---

## Exercise 1.3 Solution

**Task:** Verify control plane component pods are running.

**Solution:**

```bash
# List control plane pods
kubectl get pods -n kube-system -l tier=control-plane

# Check each component
kubectl logs -n kube-system -l component=kube-apiserver --tail=10
kubectl logs -n kube-system -l component=kube-scheduler --tail=10
kubectl logs -n kube-system -l component=kube-controller-manager --tail=10
kubectl logs -n kube-system -l component=etcd --tail=10

# Verify all running
kubectl get pods -n kube-system -l tier=control-plane -o wide
```

**Expected output:** Four pods running (etcd, kube-apiserver, kube-controller-manager, kube-scheduler), all with status Running and READY 1/1.

---

## Exercise 2.1 Solution

**Task:** Check node prerequisites.

**Solution:**

```bash
nerdctl exec kind-control-plane /bin/bash -c '
echo "=== Kernel Modules ==="
lsmod | grep -E "br_netfilter|overlay"

echo "=== Sysctl Settings ==="
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
sysctl net.ipv4.ip_forward

echo "=== Swap ==="
free -h | grep Swap

echo "=== Container Runtime ==="
crictl version
'
```

**Expected results:**
- br_netfilter and overlay modules loaded
- All sysctl values = 1
- Swap at 0 or minimal
- containerd running

---

## Exercise 2.2 Solution

**Task:** Verify kubelet configuration and status.

**Solution:**

```bash
# Kubelet status
nerdctl exec kind-control-plane systemctl status kubelet

# Kubelet configuration
nerdctl exec kind-control-plane cat /var/lib/kubelet/config.yaml
```

**Key configuration values:**

| Setting | Value | Purpose |
|---------|-------|---------|
| staticPodPath | /etc/kubernetes/manifests | Where kubelet looks for static pods |
| clusterDNS | [10.96.0.10] | CoreDNS service IP |
| clusterDomain | cluster.local | DNS domain suffix |
| authentication.x509.clientCAFile | /etc/kubernetes/pki/ca.crt | CA for client auth |

---

## Exercise 2.3 Solution

**Task:** Verify cluster health.

**Solution:**

```bash
# All nodes ready
kubectl get nodes

# Cluster info
kubectl cluster-info

# CoreDNS running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test deployment
kubectl create deployment health-test --image=nginx:1.25 -n ex-2-3
kubectl wait --for=condition=available deployment/health-test -n ex-2-3 --timeout=60s
kubectl get pods -n ex-2-3

# Cleanup
kubectl delete deployment health-test -n ex-2-3
```

---

## Exercise 3.1 Solution

**Task:** Diagnose why a node might appear NotReady.

**Solution:**

```bash
# Check node status
kubectl get nodes

# Describe a worker node
kubectl describe node kind-worker
```

**Node conditions indicating issues:**

| Condition | Status | Indicates |
|-----------|--------|-----------|
| Ready | False | Node cannot run pods |
| MemoryPressure | True | Node running out of memory |
| DiskPressure | True | Node running out of disk |
| PIDPressure | True | Too many processes |
| NetworkUnavailable | True | CNI not configured |

**Common causes of NotReady:**
- CNI not installed: NetworkUnavailable=True
- Kubelet not running: Ready=Unknown, conditions stale
- Network issues: Cannot reach API server
- Disk pressure: DiskPressure=True

---

## Exercise 3.2 Solution

**Task:** Understand kubelet troubleshooting.

**Solution:**

```bash
# Exec into worker
nerdctl exec -it kind-worker /bin/bash

# Check kubelet status
systemctl status kubelet

# View kubelet logs (last 50 lines)
journalctl -u kubelet -n 50

# View kubelet configuration
cat /var/lib/kubelet/config.yaml

# Commands to restart kubelet (if needed)
systemctl restart kubelet
systemctl status kubelet

exit
```

**Troubleshooting steps:**
1. Check if kubelet is running: `systemctl status kubelet`
2. View recent logs: `journalctl -u kubelet -n 100`
3. Check configuration: `cat /var/lib/kubelet/config.yaml`
4. Restart if needed: `systemctl restart kubelet`

---

## Exercise 3.3 Solution

**Task:** Verify CNI is properly installed.

**Solution:**

```bash
# Check CNI configuration
nerdctl exec kind-control-plane ls /etc/cni/net.d/
nerdctl exec kind-control-plane cat /etc/cni/net.d/10-kindnet.conflist

# Test pod connectivity
kubectl run test-pod-1 --image=busybox:1.36 -n ex-3-3 --command -- sleep 3600
kubectl run test-pod-2 --image=busybox:1.36 -n ex-3-3 --command -- sleep 3600
sleep 10

# Get Pod 1 IP
POD1_IP=$(kubectl get pod test-pod-1 -n ex-3-3 -o jsonpath='{.status.podIP}')

# Ping from Pod 2
kubectl exec test-pod-2 -n ex-3-3 -- ping -c 2 $POD1_IP

# Cleanup
kubectl delete pod test-pod-1 test-pod-2 -n ex-3-3 --force --grace-period=0
```

**Explanation:** Kind uses kindnet CNI. Without CNI, pods would not have IP addresses and cross-pod communication would fail.

---

## Exercise 4.1 Solution

**Task:** Examine kubeadm configuration.

**Solution:**

```bash
# Get kubeadm config ConfigMap
kubectl get configmap -n kube-system kubeadm-config -o yaml

# Extract and view ClusterConfiguration
kubectl get configmap -n kube-system kubeadm-config -o jsonpath='{.data.ClusterConfiguration}' | head -50
```

**Key configuration elements:**

| Field | Description |
|-------|-------------|
| kubernetesVersion | The cluster version |
| clusterName | Name of the cluster |
| networking.podSubnet | CIDR for pod IPs |
| networking.serviceSubnet | CIDR for service IPs |
| controlPlaneEndpoint | API server endpoint |
| etcd.local.dataDir | etcd data directory |

---

## Exercise 4.2 Solution

**Task:** Work with bootstrap tokens.

**Solution:**

```bash
# List bootstrap token secrets
kubectl get secrets -n kube-system | grep bootstrap-token

# Examine a token
TOKEN_SECRET=$(kubectl get secrets -n kube-system -o name | grep bootstrap-token | head -1)
kubectl get $TOKEN_SECRET -n kube-system -o yaml
```

**Token secret structure:**

| Field | Purpose |
|-------|---------|
| token-id | First 6 characters of the token |
| token-secret | Last 16 characters (base64 encoded) |
| expiration | When the token expires |
| usage-bootstrap-authentication | Allow authentication |
| usage-bootstrap-signing | Allow signing cluster-info |
| auth-extra-groups | Groups the token grants |

**During join:**
1. Node uses token for initial authentication
2. Downloads cluster-info ConfigMap
3. Verifies CA certificate hash
4. Kubelet generates CSR for its certificate

---

## Exercise 4.3 Solution

**Task:** Understand kubeadm init phases.

**kubeadm init phases:**

| Phase | Description |
|-------|-------------|
| preflight | Checks system requirements |
| certs | Generates all certificates |
| kubeconfig | Creates kubeconfig files |
| kubelet-start | Writes kubelet config and starts it |
| control-plane | Creates static pod manifests |
| etcd | Creates etcd static pod manifest |
| upload-config | Uploads kubeadm config to ConfigMap |
| upload-certs | Uploads certificates (HA setup) |
| mark-control-plane | Adds labels and taints |
| bootstrap-token | Creates bootstrap token |
| kubelet-finalize | Updates kubelet settings |
| addon | Installs CoreDNS and kube-proxy |

**Which phases create what:**
- Certificates: certs phase
- kubeconfig files: kubeconfig phase
- Static pod manifests: control-plane and etcd phases
- Cluster configurations: upload-config phase

---

## Exercise 5.1 Solution

**Task:** Trace the kubeadm init workflow.

**Solution:**

```bash
# 1. Certificates
nerdctl exec kind-control-plane ls /etc/kubernetes/pki/

# 2. kubeconfig files
nerdctl exec kind-control-plane ls /etc/kubernetes/*.conf

# 3. Static pod manifests
nerdctl exec kind-control-plane ls /etc/kubernetes/manifests/

# 4. Cluster configuration
kubectl get configmap -n kube-system kubeadm-config -o yaml
```

**Workflow documentation:**

1. **Certificates (PKI):**
   - Cluster CA (ca.crt/key) is the root of trust
   - All component certificates are signed by CA
   - etcd has its own CA for isolation
   - Service account keys sign JWT tokens

2. **kubeconfig files:**
   - admin.conf: Cluster admin access
   - controller-manager.conf: Controller manager to API server
   - scheduler.conf: Scheduler to API server
   - kubelet.conf: Kubelet to API server

3. **Static pods:**
   - API server: Entry point for all cluster operations
   - etcd: Stores all cluster state
   - Scheduler: Assigns pods to nodes
   - Controller manager: Runs control loops

4. **Configuration:**
   - Stored in kubeadm-config ConfigMap
   - Used for upgrades and additional joins

---

## Exercise 5.2 Solution

**Task:** Simulate adding a new worker node.

**Documentation:**

**Prerequisites for new worker:**
1. Linux host with supported OS
2. containerd installed and running
3. kubelet and kubeadm packages installed
4. Kernel modules: br_netfilter, overlay
5. Sysctl settings: net.bridge.bridge-nf-call-iptables=1, net.ipv4.ip_forward=1
6. Swap disabled
7. Network connectivity to control plane

**Generate join token:**
```bash
# On control plane (not in kind)
kubeadm token create --print-join-command
```

**Join command structure:**
```bash
kubeadm join <control-plane-ip>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

**What happens during join:**
1. kubeadm downloads cluster-info from API server
2. Verifies CA certificate hash
3. Configures kubelet with cluster CA
4. Starts kubelet
5. Kubelet creates CSR, gets certificate
6. Node registers with API server

**Verification:**
```bash
kubectl get nodes
kubectl describe node <new-node-name>
```

---

## Exercise 5.3 Solution

**Task:** Create cluster state documentation.

**Documentation template:**

```markdown
# Cluster State Documentation

## Cluster Overview

**Kubernetes Version:** (from kubectl version)
**Nodes:** 4 (1 control-plane, 3 workers)
**CNI:** kindnet
**Pod CIDR:** (from kubeadm config)
**Service CIDR:** (from kubeadm config)

## Control Plane

**API Server:** Running
**Scheduler:** Running, leader-elect enabled
**Controller Manager:** Running, leader-elect enabled
**etcd:** Single instance (non-HA)

## Nodes

| Name | Role | Status | Version | IP |
|------|------|--------|---------|-----|
| kind-control-plane | control-plane | Ready | vX.XX | X.X.X.X |
| kind-worker | worker | Ready | vX.XX | X.X.X.X |
| kind-worker2 | worker | Ready | vX.XX | X.X.X.X |
| kind-worker3 | worker | Ready | vX.XX | X.X.X.X |

## System Workloads

| Pod | Namespace | Status |
|-----|-----------|--------|
| coredns-xxx | kube-system | Running |
| etcd-xxx | kube-system | Running |
| kube-apiserver-xxx | kube-system | Running |
| kube-controller-manager-xxx | kube-system | Running |
| kube-proxy-xxx | kube-system | Running |
| kube-scheduler-xxx | kube-system | Running |
| kindnet-xxx | kube-system | Running |

## Certificate Expiration

(Check with openssl or kubeadm certs check-expiration)
```

---

## Common Mistakes

### 1. Forgetting to Apply CNI After kubeadm init

Nodes stay NotReady until CNI is installed. After `kubeadm init`, always apply a CNI plugin before joining workers.

### 2. Token Expiration

Bootstrap tokens expire after 24 hours by default. If joining a node fails with authentication error, generate a new token.

### 3. Swap Enabled

Kubelet refuses to start if swap is enabled. Either disable swap or configure kubelet to tolerate it (not recommended for production).

### 4. Firewall Blocking Required Ports

Control plane needs: 6443, 2379-2380, 10250-10252
Workers need: 10250, 30000-32767
Ensure these ports are open.

### 5. Missing Kernel Modules

br_netfilter and overlay modules must be loaded. Add them to /etc/modules-load.d/ for persistence.

### 6. Wrong CA Certificate Hash

The hash in the join command must match the actual CA certificate. Regenerate the join command if in doubt.

---

## Verification Commands Cheat Sheet

| Task | Command |
|------|---------|
| List static pod manifests | `ls /etc/kubernetes/manifests/` |
| View manifest | `cat /etc/kubernetes/manifests/<name>.yaml` |
| List certificates | `ls /etc/kubernetes/pki/` |
| Check kubelet status | `systemctl status kubelet` |
| View kubelet logs | `journalctl -u kubelet -n 50` |
| View kubelet config | `cat /var/lib/kubelet/config.yaml` |
| Check kernel modules | `lsmod \| grep -E "br_netfilter\|overlay"` |
| Check sysctl | `sysctl net.bridge.bridge-nf-call-iptables` |
| List bootstrap tokens | `kubectl get secrets -n kube-system \| grep bootstrap-token` |
| Get kubeadm config | `kubectl get cm -n kube-system kubeadm-config -o yaml` |
| Check node status | `kubectl get nodes -o wide` |
| Describe node | `kubectl describe node <name>` |
| Control plane pods | `kubectl get pods -n kube-system -l tier=control-plane` |
