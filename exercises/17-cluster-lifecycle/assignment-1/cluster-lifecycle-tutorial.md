# Cluster Lifecycle Tutorial: Cluster Installation with kubeadm

This tutorial teaches you how Kubernetes clusters are bootstrapped using kubeadm. You will learn about node prerequisites, the kubeadm init and join workflows, control plane component verification, and Kubernetes extension interfaces.

## Introduction

Kubeadm is the official tool for bootstrapping production-ready Kubernetes clusters. It handles the complex process of setting up a cluster: generating certificates, creating static pod manifests for control plane components, configuring kubelet, and bootstrapping etcd. Understanding kubeadm is essential for the CKA exam, which requires you to demonstrate cluster installation and troubleshooting skills.

This tutorial uses a kind cluster. Kind (Kubernetes in Docker) uses kubeadm internally, so all kubeadm artifacts are present in the cluster. While you cannot run kubeadm init or join directly (kind manages this), you can examine the artifacts and understand the workflows.

## Prerequisites

Before starting this tutorial, ensure you have:

- A multi-node kind cluster running (1 control-plane, 3 workers)
- kubectl configured to communicate with your cluster
- nerdctl available for executing commands inside kind containers

Verify your cluster is ready:

```bash
kubectl get nodes
```

You should see one control-plane node and three worker nodes, all in Ready status.

## Tutorial Setup

Most of this tutorial involves examining artifacts inside kind containers. Create a tutorial namespace for any Kubernetes resources:

```bash
kubectl create namespace tutorial-cluster-lifecycle
```

## Understanding Kubeadm

Kubeadm is designed to bootstrap a minimum viable Kubernetes cluster. It focuses on the cluster initialization workflow, leaving infrastructure concerns (VMs, networking, load balancers) to other tools. The kubeadm workflow has two main phases:

1. **kubeadm init:** Run on the first control plane node to initialize the cluster
2. **kubeadm join:** Run on additional nodes (control plane or worker) to join them to the cluster

### What kubeadm init Does

When you run `kubeadm init` on a control plane node, it:

1. Runs preflight checks (verifying prerequisites)
2. Generates the cluster CA and all component certificates
3. Generates kubeconfig files for admin and components
4. Creates static pod manifests for etcd, API server, controller manager, and scheduler
5. Applies RBAC and other cluster configurations
6. Generates a bootstrap token for joining nodes

### What kubeadm join Does

When you run `kubeadm join` on a worker node, it:

1. Uses the bootstrap token to authenticate with the API server
2. Downloads the cluster CA certificate
3. Configures kubelet with the cluster CA
4. Starts kubelet, which registers the node with the API server

## Node Prerequisites

Before running kubeadm, nodes must meet several prerequisites. Let's examine these in a kind node.

### Examining Node Configuration

Exec into the kind control plane container:

```bash
nerdctl exec -it kind-control-plane /bin/bash
```

Inside the container, check the prerequisites:

### Container Runtime

Kubernetes requires a container runtime. Kind uses containerd:

```bash
systemctl status containerd
crictl info
```

The CRI (Container Runtime Interface) allows Kubernetes to work with different container runtimes.

### Kernel Modules

Required kernel modules for networking:

```bash
lsmod | grep br_netfilter
lsmod | grep overlay
```

These modules enable bridge networking and overlay filesystems.

### Sysctl Settings

Required network settings:

```bash
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.bridge.bridge-nf-call-ip6tables
sysctl net.ipv4.ip_forward
```

These settings must be 1 to enable proper packet forwarding.

### Swap

Kubernetes requires swap to be disabled:

```bash
free -h | grep Swap
# Should show 0 or very low swap
```

If swap is enabled, kubelet refuses to start (though recent versions can be configured to tolerate swap).

Exit the container:

```bash
exit
```

## Static Pod Manifests

Control plane components (except kubelet) run as static pods. Static pods are managed directly by kubelet based on manifest files, not by the API server.

### Examining Static Pod Manifests

```bash
nerdctl exec -it kind-control-plane ls /etc/kubernetes/manifests/
```

You should see:
- etcd.yaml
- kube-apiserver.yaml
- kube-controller-manager.yaml
- kube-scheduler.yaml

### API Server Manifest

Examine the API server manifest:

```bash
nerdctl exec kind-control-plane cat /etc/kubernetes/manifests/kube-apiserver.yaml
```

Key fields to note:
- **image:** The container image version
- **command:** The API server flags (--advertise-address, --secure-port, --etcd-servers, etc.)
- **volumeMounts:** Where certificates and config are mounted
- **livenessProbe:** How kubelet checks if the API server is healthy

### How Static Pods Work

Kubelet watches the `/etc/kubernetes/manifests/` directory. When a manifest is added, kubelet creates the pod. When a manifest is modified, kubelet recreates the pod. When a manifest is removed, kubelet deletes the pod.

The API server eventually learns about these pods through kubelet's node status updates, so you can see them with `kubectl get pods -n kube-system`.

## Certificate Directory Structure

Kubeadm generates all certificates needed for secure cluster communication.

### Exploring the PKI Directory

```bash
nerdctl exec kind-control-plane ls -la /etc/kubernetes/pki/
```

Key files:
- **ca.crt, ca.key:** Cluster CA certificate and key
- **apiserver.crt, apiserver.key:** API server serving certificate
- **apiserver-kubelet-client.crt:** API server's client certificate for kubelet
- **front-proxy-ca.crt:** CA for aggregated API servers
- **etcd/:** Subdirectory containing etcd-specific certificates
- **sa.key, sa.pub:** Service account signing key pair

### Certificate Purposes

Each component needs certificates for different purposes:
- **Server certificates:** Prove identity when accepting connections
- **Client certificates:** Prove identity when making connections
- **CA certificates:** Sign and verify other certificates

The API server, for example, has both server certificates (for kubectl to connect to it) and client certificates (for connecting to kubelet and etcd).

## Control Plane Component Verification

Let's verify that all control plane components are running correctly.

### Using kubectl

From outside the container:

```bash
# Check control plane pods
kubectl get pods -n kube-system

# Check specific component logs
kubectl logs -n kube-system -l component=kube-apiserver
kubectl logs -n kube-system -l component=kube-scheduler
kubectl logs -n kube-system -l component=kube-controller-manager
kubectl logs -n kube-system -l component=etcd
```

### Using crictl Inside the Node

```bash
nerdctl exec kind-control-plane crictl ps
```

This shows containers running on the node, including control plane components.

### Checking Component Health

```bash
# Cluster info
kubectl cluster-info

# Component statuses (deprecated but may appear on exam)
kubectl get componentstatuses

# Node conditions
kubectl describe node kind-control-plane | grep -A20 "Conditions:"
```

## Kubelet Configuration

Kubelet is the primary node agent. It is not a static pod but a systemd service (in kind, it runs as a process in the container).

### Checking Kubelet Status

```bash
nerdctl exec kind-control-plane systemctl status kubelet
```

### Kubelet Configuration File

```bash
nerdctl exec kind-control-plane cat /var/lib/kubelet/config.yaml
```

Key configuration:
- **clusterDNS:** IP address of CoreDNS
- **clusterDomain:** cluster.local
- **staticPodPath:** /etc/kubernetes/manifests
- **authentication/authorization:** How kubelet authenticates API requests

### Kubelet Logs

```bash
nerdctl exec kind-control-plane journalctl -u kubelet -n 50
```

## Extension Interfaces

Kubernetes uses three plugin interfaces to integrate with infrastructure components.

### CNI (Container Network Interface)

CNI plugins provide pod networking. They handle:
- Assigning IP addresses to pods
- Configuring network routes between pods
- Implementing network policies (in supported plugins)

Common CNI plugins:
- **Calico:** Full-featured with network policies
- **Cilium:** eBPF-based with advanced features
- **Flannel:** Simple overlay networking
- **Weave:** Mesh networking
- **kindnet:** Simple CNI used by kind

Check the CNI configuration:

```bash
nerdctl exec kind-control-plane ls /etc/cni/net.d/
nerdctl exec kind-control-plane cat /etc/cni/net.d/10-kindnet.conflist
```

Without a CNI plugin, pods cannot communicate and nodes stay in NotReady state.

### CSI (Container Storage Interface)

CSI plugins provide persistent storage. They handle:
- Provisioning volumes (creating storage)
- Attaching volumes to nodes
- Mounting volumes in pods

Common CSI drivers:
- Cloud provider storage (AWS EBS, GCP PD, Azure Disk)
- Open source (Rook-Ceph, OpenEBS, Longhorn)
- Local path provisioner (for development)

Kind uses a local path provisioner by default.

### CRI (Container Runtime Interface)

CRI allows Kubernetes to work with different container runtimes:
- **containerd:** Most common runtime
- **CRI-O:** Alternative container runtime
- **Docker:** Via dockershim (deprecated)

Kind uses containerd:

```bash
nerdctl exec kind-control-plane crictl version
```

## Cluster Health Checks

After installation, verify the cluster is healthy.

### Basic Health Checks

```bash
# All nodes ready
kubectl get nodes

# All system pods running
kubectl get pods -n kube-system

# Cluster info
kubectl cluster-info

# Create a test pod
kubectl run health-test --image=nginx:1.25 -n tutorial-cluster-lifecycle
kubectl wait --for=condition=Ready pod/health-test -n tutorial-cluster-lifecycle --timeout=60s

# Verify pod is running
kubectl get pod health-test -n tutorial-cluster-lifecycle

# Cleanup
kubectl delete pod health-test -n tutorial-cluster-lifecycle
```

### Troubleshooting NotReady Nodes

If a node is NotReady:

1. Check node conditions: `kubectl describe node <name>`
2. Check kubelet status: `systemctl status kubelet` (inside node)
3. Check kubelet logs: `journalctl -u kubelet` (inside node)
4. Check CNI is installed: `ls /etc/cni/net.d/`

Common causes:
- CNI not installed
- Kubelet not running
- Network connectivity issues
- Certificate problems

## Bootstrap Tokens

Kubeadm uses bootstrap tokens to authenticate nodes joining the cluster.

### Understanding Bootstrap Tokens

Bootstrap tokens are short-lived (24 hours by default) and stored as secrets in kube-system:

```bash
kubectl get secrets -n kube-system | grep bootstrap-token
```

### Token Structure

A token has the format `[6 characters].[16 characters]`, for example: `abcdef.0123456789abcdef`

The first part is the token ID, the second is the secret.

### Creating a New Token

```bash
# This would work in a real kubeadm cluster
# In kind, you can examine existing tokens
kubectl get secrets -n kube-system -o name | grep bootstrap-token | head -1 | xargs kubectl get -n kube-system -o yaml
```

### Generating Join Commands

In a real kubeadm cluster, you would run:

```bash
kubeadm token create --print-join-command
```

This outputs the complete `kubeadm join` command with token and CA certificate hash.

## Tutorial Cleanup

Delete the tutorial namespace:

```bash
kubectl delete namespace tutorial-cluster-lifecycle
```

## Reference Commands

### Node Examination

| Task | Command |
|------|---------|
| Exec into kind node | `nerdctl exec -it kind-control-plane /bin/bash` |
| List static pod manifests | `ls /etc/kubernetes/manifests/` |
| View API server manifest | `cat /etc/kubernetes/manifests/kube-apiserver.yaml` |
| List PKI certificates | `ls /etc/kubernetes/pki/` |
| Check kubelet status | `systemctl status kubelet` |
| View kubelet logs | `journalctl -u kubelet -n 50` |
| Check CNI config | `ls /etc/cni/net.d/` |
| Check container runtime | `crictl version` |

### Cluster Verification

| Task | Command |
|------|---------|
| Check node status | `kubectl get nodes` |
| Check system pods | `kubectl get pods -n kube-system` |
| Cluster info | `kubectl cluster-info` |
| Component statuses | `kubectl get componentstatuses` |
| Node conditions | `kubectl describe node <name>` |
| Control plane logs | `kubectl logs -n kube-system -l component=<component>` |

### Troubleshooting

| Symptom | What to Check |
|---------|---------------|
| Node NotReady | CNI installed, kubelet running, network connectivity |
| Pods not scheduling | Scheduler running, node capacity, taints |
| API server not responding | API server pod running, certificates valid |
| etcd errors | etcd pod running, etcd cluster health |
