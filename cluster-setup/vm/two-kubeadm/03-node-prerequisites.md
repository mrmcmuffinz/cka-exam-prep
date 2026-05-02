# Installing Container Runtime and kubeadm Toolchain

**Based on:** The upstream [kubeadm install documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/).

**Purpose:** Install containerd and crictl via apt, CNI plugin binaries from the upstream release, and the kubeadm/kubelet/kubectl tools on both nodes. Same containerd configuration as the single-node guide, performed on two machines.

---

## What This Chapter Does

Before `kubeadm init` can run, both nodes need a working container runtime and the `kubeadm` toolchain at the matching version. The container runtime stack (containerd, runc, crictl) is identical to what the single-node guide installed. The new pieces are the CNI plugin binaries (Calico calls them in document 05), the `kubeadm`, `kubelet`, and `kubectl` packages from the upstream Kubernetes apt repo, and an `apt-mark hold` so they do not silently upgrade.

This document is identical for `controlplane-1` and `nodes-1`. Run every step on both nodes. The cleanest way is to open two terminals (one SSH'd into each node) and walk through in lockstep.

## What Is Different from the systemd Guides

The systemd guides (`single-systemd`, `two-systemd`) install containerd as a raw binary and write the systemd unit by hand. This guide installs containerd via `apt` instead, which handles the systemd unit automatically and is the approach the kubernetes.io install docs show for Ubuntu. The `kubeadm`, `kubelet`, and `kubectl` packages also come from apt. The critical containerd configuration (`SystemdCgroup = true`, CRI socket path) is the same in all guides.

## Prerequisites

SSH into either node. Cloud-init from the previous document already disabled swap, loaded `overlay` and `br_netfilter`, and set the necessary sysctls. Verify briefly:

```bash
free -h | grep Swap                 # All zeros
lsmod | grep -E 'overlay|br_netfilter'  # Both present
sysctl net.bridge.bridge-nf-call-iptables net.ipv4.ip_forward
# Both should be 1
```

If any of those are wrong, see the cloud-init troubleshooting in `runbook-qemu-vm.md`.

---

## Part 1: Container Runtime

### Step 1: Install containerd

```bash
sudo apt-get update
sudo apt-get install -y containerd
```

`apt install containerd` installs containerd and pulls in `runc` as a dependency. The systemd service unit is registered and started automatically.

### Step 2: Download crictl and CNI Plugin Binaries

`cri-tools` (crictl) is not in Ubuntu's default repos -- it lives in the Kubernetes apt repo, which is not added until Part 2. Install the binary directly. CNI plugin binaries are also not included in the apt containerd package.

```bash
cri_version=1.35.0
cni_plugins_version=1.7.1
arch=amd64

# crictl
curl -fsSL "https://github.com/kubernetes-sigs/cri-tools/releases/download/v${cri_version}/crictl-v${cri_version}-linux-${arch}.tar.gz" \
  | sudo tar -C /usr/local/bin -xz

# CNI plugins (Calico calls these from inside its pod)
sudo mkdir -p /opt/cni/bin
curl -fsSL "https://github.com/containernetworking/plugins/releases/download/v${cni_plugins_version}/cni-plugins-linux-${arch}-v${cni_plugins_version}.tgz" \
  | sudo tar -C /opt/cni/bin -xz
```

### Step 3: Configure containerd

apt does not write a config file. Generate the defaults and enable the systemd cgroup driver:

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
```

`SystemdCgroup = true` is required because Ubuntu 24.04 uses systemd as the cgroup manager. Running cgroupfs and systemd managers simultaneously on the same node causes instability.

### Step 4: Restart containerd

```bash
sudo systemctl restart containerd

# Verify
systemctl status containerd --no-pager
sudo crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock info | head -20
```

### Step 5: crictl Default Endpoint

`kubeadm init` uses `crictl` and expects to find the runtime endpoint without flags. Set it as the default:

```bash
sudo tee /etc/crictl.yaml > /dev/null <<'EOF'
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

# Verify
sudo crictl version
```

---

## Part 2: kubeadm, kubelet, kubectl

The upstream Kubernetes apt repo is now versioned per minor release. Adding the v1.35 repo gives access to `1.35.x` releases only; upgrading to v1.36 later requires changing the repo URL, which is intentional and matches the CKA exam upgrade workflow.

### Step 1: Add the Kubernetes Apt Repo

```bash
sudo mkdir -p /etc/apt/keyrings
sudo curl -fsSL -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg.tmp \
  https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key
sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg /etc/apt/keyrings/kubernetes-apt-keyring.gpg.tmp
sudo rm /etc/apt/keyrings/kubernetes-apt-keyring.gpg.tmp

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
```

### Step 2: Install Pinned to v1.35.3

```bash
# Find the exact package version string available
apt-cache madison kubelet | head -3
```

The output shows package versions like `1.35.3-1.1`. The exact suffix sometimes differs. Substitute what `madison` shows:

```bash
sudo apt install -y \
  kubelet=1.35.3-1.1 \
  kubeadm=1.35.3-1.1 \
  kubectl=1.35.3-1.1
```

### Step 3: Hold the Versions

`apt-mark hold` prevents `apt upgrade` from bumping these silently. Cluster upgrades on the CKA exam are intentional, version-pinned operations; you do not want a routine update to drift the cluster mid-lab.

```bash
sudo apt-mark hold kubelet kubeadm kubectl
```

### Step 4: Verify

```bash
kubeadm version -o short        # v1.35.3
kubelet --version               # Kubernetes v1.35.3
kubectl version --client -o yaml | grep gitVersion
```

All three should report `v1.35.3`.

### Step 5: Pre-Pull Control Plane Images (controlplane-1 only)

On `controlplane-1` only, pre-pull the images `kubeadm init` will need. This is optional but lets you catch image-pull errors before `kubeadm init` runs.

```bash
sudo kubeadm config images pull --kubernetes-version v1.35.3
```

This pulls `kube-apiserver`, `kube-controller-manager`, `kube-scheduler`, `kube-proxy`, `pause`, `etcd`, and `coredns`. On `nodes-1` skip this step; the worker only needs `kube-proxy` and `pause`, which `kubeadm join` will pull when needed.

---

## Part 3: Verify Both Nodes Are Ready

Same checklist on each node. Repeat on `controlplane-1` and `nodes-1`:

```bash
# Swap off
free -m | awk '/Swap/ {print "swap_total="$2}'

# Modules loaded
lsmod | grep -E '^(overlay|br_netfilter)' | wc -l    # 2

# Sysctls
sysctl net.bridge.bridge-nf-call-iptables net.ipv4.ip_forward

# containerd up
systemctl is-active containerd

# crictl can talk to containerd
sudo crictl info > /dev/null && echo "crictl OK"

# kubeadm tools at the right version
kubeadm version -o short
kubelet --version
kubectl version --client -o yaml | grep gitVersion
```

If every check passes on both nodes, move to document 04.

---

## Summary

Both nodes are now ready for `kubeadm init` and `kubeadm join`:

| Component | Location | Purpose |
|-----------|----------|---------|
| containerd | `/usr/bin/containerd` (via apt) | Container lifecycle daemon, CRI implementation |
| runc | `/usr/sbin/runc` (via apt) | Low-level container executor (OCI runtime) |
| crictl | `/usr/local/bin/crictl` | CLI tool for container inspection/debugging |
| CNI plugin binaries | `/opt/cni/bin/*` | Bridge, host-local, loopback, plus others Calico depends on |
| kubeadm | `/usr/bin/kubeadm` | Cluster bootstrap and lifecycle tool |
| kubelet | `/usr/bin/kubelet` | Node agent (does not yet run; will be started by `kubeadm init` or `kubeadm join`) |
| kubectl | `/usr/bin/kubectl` | Kubernetes CLI |

The next document runs `kubeadm init` on `controlplane-1`.
