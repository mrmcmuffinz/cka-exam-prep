# Two-Node Kubernetes Cluster: Overview

A step-by-step guide for bootstrapping a two-node Kubernetes cluster on a pair of QEMU/KVM virtual machines using `kubeadm`. Built for CKA exam preparation as the multi-node companion to the single-node guide.

---

## Documents

Follow these in order. Each document builds on the previous one.

| # | Document | What It Does |
|---|----------|-------------|
| 01 | [Host Bridge Setup](01-host-bridge-setup.md) | Configures the Linux bridge `br0` on the host, IP forwarding, NAT for outbound traffic, and `qemu-bridge-helper` so VMs can attach to the bridge |
| 02 | [VM Provisioning](02-vm-provisioning.md) | Creates two headless Ubuntu 24.04 VMs (`node1`, `node2`) with cloud-init, static IPs, SSH access, and per-node start/stop scripts |
| 03 | [Node Prerequisites](03-node-prerequisites.md) | Installs containerd, runc, CNI binaries, crictl, and the `kubeadm`/`kubelet`/`kubectl` toolchain on both nodes |
| 04 | [Control Plane Init](04-control-plane-init.md) | Runs `kubeadm init` on `node1` with a YAML config, sets up `kubectl`, copies the kubeconfig to the host |
| 05 | [CNI Installation](05-cni-installation.md) | Installs Calico via the Tigera operator, removes the control-plane taint, verifies pod networking and `NetworkPolicy` enforcement |
| 06 | [Worker Join](06-worker-join.md) | Joins `node2` with a fresh `kubeadm token`, verifies cross-node networking, snapshots both qcow2 disks |
| 07 | [Cluster Services](07-cluster-services.md) | Installs Helm, `local-path-provisioner`, `metrics-server`, and optionally MetalLB |

## Component Versions

| Component | Version |
|-----------|---------|
| Ubuntu (guest) | 24.04 LTS |
| Kubernetes | v1.35.3 |
| containerd | v2.1.3 |
| runc | v1.3.0 |
| cri-tools (crictl) | v1.35.0 |
| CNI plugins | v1.7.1 |
| Calico | v3.31.0 |

Kubernetes v1.35 is the version the CKA exam currently targets.

## Network Configuration

Three IP ranges are used throughout the documents and must stay consistent:

| CIDR | Purpose | Where It Appears |
|------|---------|------------------|
| `192.168.122.0/24` | Host bridge `br0` | VM IPs (`192.168.122.10`, `192.168.122.11`), host gateway (`192.168.122.1`), MetalLB pool (optional) |
| `10.96.0.0/16` | Service ClusterIP range | `kubeadm` `serviceSubnet`, CoreDNS ClusterIP (`10.96.0.10`), `kubernetes` Service (`10.96.0.1`) |
| `10.244.0.0/16` | Pod IP range | `kubeadm` `podSubnet`, Calico IPPool `cidr` |

The bridge subnet matches libvirt's default `virbr0`. The host bridge setup in document 01 detects this collision and offers a way to reuse `virbr0` instead.

## VM Access

Both VMs are reachable directly over SSH from the host. After the SSH config setup in document 00, these short forms work without flags.

| Access Method | Command |
|--------------|---------|
| SSH into control plane | `ssh node1` |
| SSH into worker | `ssh node2` |
| API server from host | `curl --cacert ~/cka-lab/two-kubeadm/ca.crt https://192.168.122.10:6443/healthz` |
| `kubectl` from host | `KUBECONFIG=~/cka-lab/two-kubeadm/admin.conf kubectl get nodes` |
| `node1` console log | `tail -f ~/cka-lab/two-kubeadm/node1/node1-console.log` |
| `node2` console log | `tail -f ~/cka-lab/two-kubeadm/node2/node2-console.log` |
| Stop both VMs | `~/cka-lab/two-kubeadm/stop-cluster.sh` |
| Start both VMs | `~/cka-lab/two-kubeadm/start-cluster.sh` |

Default VM credentials: user `kube`, password `kubeadmin`.

## SSH Config

Add this to `~/.ssh/config` on the host once. After this, `ssh node1` and `ssh node2` resolve correctly.

```ssh-config
Host node1
    HostName 192.168.122.10
    User kube
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new

Host node2
    HostName 192.168.122.11
    User kube
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking accept-new
```

## Where Everything Runs

All Kubernetes components run inside the VMs. `kubeadm`, `kubelet`, `kubectl`, and the container runtime are installed on both nodes. The static-pod control plane (etcd, kube-apiserver, kube-controller-manager, kube-scheduler) runs only on `node1`. The host machine is used to manage VM lifecycle, SSH into either node, and optionally to run `kubectl` against the cluster through the copied kubeconfig.

## Scope

This guide covers a two-node cluster with one control plane and one worker. The control plane node is intentionally left untainted so that workloads can also schedule on it, which lets you exercise drain, cordon, taint, and affinity scenarios without a third node. HA control plane setups (stacked etcd, multiple control plane nodes, external load balancer) are out of scope and would be a separate document.
