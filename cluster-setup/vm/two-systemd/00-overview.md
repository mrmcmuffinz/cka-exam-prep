# Two-Node Kubernetes Cluster (systemd, From Scratch): Overview

A step-by-step guide for bootstrapping a two-node Kubernetes cluster on a pair of QEMU/KVM VMs, built entirely from raw binaries and systemd services. This is the multi-node companion to `cka/vm/single-systemd`. No `kubeadm`, no CNI operator, no overlay networking.

---

## Documents

Follow these in order. Each document builds on the previous one.

| # | Document | What It Does |
|---|----------|-------------|
| 01 | [Host Bridge Setup](01-host-bridge-setup.md) | Configures the Linux bridge `br0` on the host, IP forwarding, NAT for outbound traffic |
| 02 | [VM Provisioning](02-vm-provisioning.md) | Creates two headless Ubuntu 24.04 VMs (`node1`, `node2`) with cloud-init and static IPs |
| 03 | [Bootstrapping Security](03-bootstrapping-security.md) | Generates the CA on `node1`, copies it to `node2`, each node generates its own component certs |
| 04 | [Control Plane on node1](04-control-plane.md) | Installs etcd, apiserver, controller-manager, scheduler as systemd services |
| 05 | [Container Runtime and Worker (Both Nodes)](05-container-runtime-and-worker.md) | Installs containerd, runc, crictl, CNI binaries, kubelet, kube-proxy on both nodes |
| 06 | [Manual Pod Routing](06-manual-pod-routing.md) | Adds host routes between nodes so cross-node pod traffic actually works |
| 07 | [Cluster Services](07-cluster-services.md) | Installs Helm, CoreDNS, local-path-provisioner, optionally MetalLB |

## Component Versions

| Component | Version |
|-----------|---------|
| Ubuntu (guest) | 24.04 LTS |
| etcd | v3.6.9 |
| Kubernetes | v1.35.3 |
| containerd | v2.1.3 |
| runc | v1.3.0 |
| cri-tools (crictl) | v1.35.0 |
| CNI plugins | v1.7.1 |

Kubernetes v1.35 is the version the CKA exam currently targets.

## Network Configuration

| CIDR | Purpose | Where It Appears |
|------|---------|------------------|
| `192.168.122.0/24` | Host bridge `br0` | VM IPs (`192.168.122.10`, `192.168.122.11`), host gateway (`192.168.122.1`) |
| `10.96.0.0/16` | Service ClusterIP range | apiserver `--service-cluster-ip-range`, controller-manager match, CoreDNS (`10.96.0.10`), kubelet `clusterDNS`, apiserver cert SAN (`10.96.0.1`) |
| `10.244.0.0/16` | Total pod IP range | controller-manager `--cluster-cidr`, kube-proxy `clusterCIDR` |
| `10.244.0.0/24` | `node1` pod slice | CNI bridge subnet on `node1` |
| `10.244.1.0/24` | `node2` pod slice | CNI bridge subnet on `node2` |

## VM Access

Both VMs are reachable directly over SSH from the host through the bridge.

| Access Method | Command |
|--------------|---------|
| SSH into `node1` | `ssh node1` (after SSH config setup) |
| SSH into `node2` | `ssh node2` |
| API server from host | `curl --cacert ~/cka-lab/two-systemd/ca.pem https://192.168.122.10:6443/healthz` |
| `kubectl` from host | Copy `~/auth/admin.kubeconfig` from `node1`, edit server URL |
| `node1` console log | `tail -f ~/cka-lab/two-systemd/node1/node1-console.log` |
| `node2` console log | `tail -f ~/cka-lab/two-systemd/node2/node2-console.log` |
| Stop both VMs | `~/cka-lab/two-systemd/stop-cluster.sh` |
| Start both VMs | `~/cka-lab/two-systemd/start-cluster.sh` |

Default VM credentials: user `kube`, password `kubeadmin`.

## SSH Config

Add this to `~/.ssh/config` once. After this, `ssh node1` and `ssh node2` work without flags.

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

- `node1` runs the entire control plane (etcd, apiserver, controller-manager, scheduler) as systemd services. It also runs kubelet and kube-proxy so workloads can schedule on it.
- `node2` runs kubelet and kube-proxy only.
- All certificates are generated per-node, on each VM, so the CA travels from `node1` to `node2` over scp.
- The host machine manages VM lifecycle, holds the SSH config, and runs the manual route programming for cross-node pod traffic.

## What's Different from `single-systemd`

- VM networking: bridge + TAP instead of QEMU user-mode + port forwarding.
- Cert SAN list: includes both VMs' IPs.
- Per-node identity: each node generates its own `system:node:nodeN` certificate.
- CNI: per-node pod CIDR slice, with manual host routes between nodes.
- Worker components installed on both nodes instead of one.

## Scope

Two-node cluster. The control plane node is left untainted so workloads can also schedule there. HA control plane setups (multiple control plane nodes, external load balancer) are out of scope.
