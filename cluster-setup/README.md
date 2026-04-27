# Kubernetes from Scratch: VM-Based Cluster Guides

This directory contains four guides for building Kubernetes clusters on QEMU/KVM virtual machines, from two different installation methods (manual systemd configuration vs. kubeadm) and two different scales (single-node vs. two-node). The guides exist to teach how Kubernetes works under the hood. They are educational material for learners who want to understand what `kubeadm` automates, how CNI plugins program routes, how etcd clustering works, and how certificates flow through the system.

These guides are optional and not required for CKA exam preparation. The main exercises in this repository (`exercises/`) are built around kind clusters, which start fast, clean up easily, and closely match the exam environment. The VM-based guides in this directory exist for the subset of learners who find that understanding the internals makes the exam topics click. They complement the main exercises rather than replace them.

## The Four Guides

| Guide | Install Method | Nodes | Time Estimate | Purpose |
|-------|----------------|-------|---------------|---------|
| [`vm/single-systemd`](vm/single-systemd/) | Manual binaries + systemd units | 1 | 2-3 hours | Understand what every component does and how they connect |
| [`vm/single-kubeadm`](vm/single-kubeadm/) | kubeadm | 1 | 30-45 minutes | See what kubeadm automates, practice exam-style operations |
| [`vm/two-systemd`](vm/two-systemd/) | Manual binaries + systemd units | 2 | 3-4 hours | Understand multi-node networking, manual route programming |
| [`vm/two-kubeadm`](vm/two-kubeadm/) | kubeadm | 2 | 1 hour | Practice kubeadm join, multi-node exam scenarios |

All four guides target Kubernetes v1.35.3 (the CKA exam version) and use Ubuntu 24.04 LTS guest VMs.

### Single-Systemd: The Deepest Dive

The [`vm/single-systemd`](vm/single-systemd/) guide builds a single-node cluster entirely from scratch. You download raw binaries for etcd, kube-apiserver, kube-controller-manager, kube-scheduler, kubelet, and kube-proxy, write systemd units for each, generate all certificates by hand with cfssl, and configure the CNI plugin directly. This is the slowest path (2-3 hours start to finish) but the one with the most visibility. When something breaks in a production cluster, the mental model you build here is what helps you diagnose it.

This guide is adapted from [Kubernetes the Harder Way](https://github.com/ghik/kubernetes-the-harder-way/tree/linux) by ghik, which itself is inspired by Kelsey Hightower's [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way).

### Single-Kubeadm: The Exam-Focused Path

The [`vm/single-kubeadm`](vm/single-kubeadm/) guide builds the same single-node cluster but uses `kubeadm init` instead of manual systemd units. It takes 30-45 minutes instead of 2-3 hours. The guide includes a file mapping table that shows where each `kubeadm`-generated file lives and what its hand-rolled equivalent was in the systemd guide, so you can use the systemd guide as a reference when troubleshooting.

The CKA exam runs on `kubeadm`-installed clusters and tests `kubeadm` lifecycle operations directly: cluster init, worker join, token rotation, certificate renewal, control plane upgrades, and etcd backup/restore. This guide is the right tool for practicing those exam-shaped operations.

### Two-Systemd: Multi-Node Internals

The [`vm/two-systemd`](vm/two-systemd/) guide extends the single-systemd approach to two nodes: one control plane, one worker. The VMs sit on a Linux bridge with real IPs instead of QEMU user-mode networking. Cross-node pod traffic requires manually adding `ip route` entries on each node, which exposes the routing layer that Calico, Cilium, and Flannel handle automatically. This is the guide to work through if you want to understand how CNI plugins actually program routes and what "overlay network" means in concrete terms.

Nobody runs production clusters this way. The point is educational: seeing the seams makes the abstractions less magical.

### Two-Kubeadm: Multi-Node Exam Practice

The [`vm/two-kubeadm`](vm/two-kubeadm/) guide builds a two-node cluster with `kubeadm`, installs Calico (so `NetworkPolicy` actually works), and is suitable for practicing every Day 1 through Day 14 scenario in the Mumshad CKA course: scheduling, taints and tolerations, node affinity, daemonsets, cordon and drain, control plane upgrades, kubeadm join token rotation, etcd backup and restore, and multi-node networking troubleshooting.

## Is This For You?

### Use kind clusters (per docs/cluster-setup.md) if:
- You want to work through the main exercises quickly
- You value speed and disposability (cluster up in 30 seconds, tear down instantly)
- You are on macOS or Windows (kind runs anywhere Docker/nerdctl runs)
- You just want to pass the CKA exam

### Use these VM guides if:
- You want to understand how Kubernetes works internally
- Exam topics like "etcd backup" or "certificate renewal" feel opaque and you want to see what those operations actually touch
- You learn best by building something from first principles
- You have an Ubuntu 24.04 host with KVM support and 8-16 GB RAM to spare
- You are comfortable with multi-hour exercises

The two approaches are complementary. Many learners work through the main exercises with kind first, then come back to the VM guides later when they want deeper understanding of specific topics (PKI, CNI, etcd clustering, static pods).

## Platform Requirements

All four guides assume:
- **Host OS:** Ubuntu 24.04 LTS
- **CPU:** x86_64 with hardware virtualization enabled (Intel VT-x or AMD-V)
- **RAM:** At least 8 GB for single-node guides, 16 GB for two-node guides (4 GB allocated per VM plus host overhead)
- **Disk:** 50 GB free for single-node, 100 GB for two-node
- **Tooling:** QEMU/KVM, cloud-init, basic shell proficiency

These are more restrictive than kind. If you are on macOS, Windows, or a Linux host without KVM, stick with kind.

## Recommended Sequence

**New to Kubernetes?** Start with the main exercises in `exercises/01-pods/` using kind clusters (per `docs/cluster-setup.md`). The VM guides assume you already know what pods, services, and namespaces are.

**Preparing for CKA exam operations?** Do `vm/single-kubeadm` first to practice cluster init and lifecycle operations, then `vm/two-kubeadm` for multi-node scenarios (kubeadm join, drain, upgrade).

**Want to truly understand Kubernetes?** The deepest path is:
1. `vm/single-systemd` (2-3 hours): Build every component by hand
2. `vm/single-kubeadm` (30-45 min): See what kubeadm automates, use the file mapping table to connect back to the systemd guide
3. `vm/two-systemd` (3-4 hours): Extend the systemd approach to two nodes, program routes manually
4. `vm/two-kubeadm` (1 hour): See the kubeadm equivalent for multi-node

Most learners do not work through all four. Common patterns:
- Just `single-systemd` for the deepest dive on control plane components
- Just `single-kubeadm` + `two-kubeadm` for exam-focused practice
- `single-systemd` followed by `single-kubeadm` to see the before-and-after of what kubeadm automates

## What These Guides Offer That kind Doesn't

1. **PKI visibility**: Hand-generating certificates with cfssl exposes the full CA chain, SANs, and how component identities work
2. **systemd service files**: See exact component flags and their purpose (kind abstracts this into container entrypoints)
3. **CNI routing layer**: Manual route programming demystifies overlay networks (kind uses kindnet, which is opaque)
4. **etcd operations**: Direct `etcdctl` interaction (kind runs etcd as a static pod, less visible)
5. **Certificate SANs**: Understand why the apiserver cert needs multiple IPs (matters for troubleshooting)
6. **kubelet bootstrap**: See the CSR approval flow that kubeadm automates
7. **Control plane as static pods**: Understand `/etc/kubernetes/manifests/` watching (kubeadm uses this, systemd guide explains it)

## What kind Offers That VMs Don't

1. **Speed**: Cluster up in 30 seconds vs. 10 minutes (kubeadm) or 2 hours (systemd)
2. **Disposability**: `kind delete cluster` and start fresh instantly
3. **Resource efficiency**: No full VM overhead
4. **Multi-cluster**: Run several in parallel for testing
5. **Cross-platform**: Works on macOS, Windows, Linux

**Conclusion:** kind is for practicing, VMs are for understanding. Use the right tool for your goal.

## Relationship to Main Exercises

The 45 assignments in `exercises/` are the core of this repository. They are built to develop exam fluency through repetition on a kind cluster. Each assignment has a tutorial, 15 progressive exercises, and a complete answer key. The content is designed to be worked through in sequence, following the `LEARNING_PATH.md` curriculum.

The VM guides in this directory are supplementary. They exist for learners who want to go deeper on specific topics after completing the relevant main exercises. For example:
- After `exercises/18-tls-and-certificates/`, the `vm/single-systemd/02-bootstrapping-security.md` document shows exactly how to generate every certificate in the cluster by hand
- After `exercises/17-cluster-lifecycle/`, the `vm/single-kubeadm/02-control-plane-init.md` document shows what `kubeadm init` actually does under the hood

The VM guides are not prerequisites for the main exercises. Start with the main exercises, come back to the VM guides when a topic feels opaque and you want to see the internals.

## Next Steps

Pick a guide from the table above, read its README, and start building. Each guide is self-contained with step-by-step instructions, verification commands after each major operation, and troubleshooting runbooks.
