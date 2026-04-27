# Installing Container Runtime and kubeadm Toolchain

**Based on:** [04-container-runtime.md](../../vm/docs/04-container-runtime.md) and the upstream [kubeadm install documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/).

**Purpose:** Install containerd, runc, the CNI plugin binaries, crictl, and the kubeadm/kubelet/kubectl tools on both nodes. Same containerd configuration as the single-node guide, but now performed on two machines, with apt-pinned Kubernetes packages added.

---

## What This Chapter Does

Before `kubeadm init` can run, both nodes need a working container runtime and the `kubeadm` toolchain at the matching version. The container runtime stack (containerd, runc, crictl) is identical to what the single-node guide installed. The new pieces are the CNI plugin binaries (Calico calls them in document 05), the `kubeadm`, `kubelet`, and `kubectl` packages from the upstream Kubernetes apt repo, and an `apt-mark hold` so they do not silently upgrade.

This document is identical for `node1` and `node2`. Run every step on both nodes. The cleanest way is to open two terminals (one SSH'd into each node) and walk through in lockstep.

## What Is Different from the Single-Node Guide

The single-node guide installed every component as a raw binary and wrote systemd units by hand. This guide stops at the runtime layer (the same as before) and then switches to apt packages from `pkgs.k8s.io` for `kubeadm`, `kubelet`, and `kubectl`. The reason is simple: the CKA exam runs on `kubeadm` clusters, and `kubeadm`'s upgrade path expects the apt packaging.

The container runtime install is identical to single-node document 04, repeated here so this guide is self-contained.

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

### Step 1: Shell Variables

```bash
arch=amd64
k8s_version=1.35.3
cri_version=1.35.0
runc_version=1.3.0
containerd_version=2.1.3
cni_plugins_version=1.7.1
```

### Step 2: Download the Binaries

```bash
crictl_archive=crictl-v${cri_version}-linux-${arch}.tar.gz
containerd_archive=containerd-${containerd_version}-linux-${arch}.tar.gz
cni_plugins_archive=cni-plugins-linux-${arch}-v${cni_plugins_version}.tgz

wget -q --show-progress --https-only --timestamping \
  "https://github.com/kubernetes-sigs/cri-tools/releases/download/v${cri_version}/${crictl_archive}" \
  "https://github.com/opencontainers/runc/releases/download/v${runc_version}/runc.${arch}" \
  "https://github.com/containerd/containerd/releases/download/v${containerd_version}/${containerd_archive}" \
  "https://github.com/containernetworking/plugins/releases/download/v${cni_plugins_version}/${cni_plugins_archive}"
```

### Step 3: Install

```bash
# containerd
mkdir -p containerd
tar -xvf ${containerd_archive} -C containerd
sudo cp containerd/bin/* /bin/

# runc
cp runc.${arch} runc
chmod +x runc
sudo cp runc /usr/local/bin/

# crictl
tar -xvf ${crictl_archive}
chmod +x crictl
sudo cp crictl /usr/local/bin/

# CNI plugin binaries (Calico calls these from inside its pod)
sudo mkdir -p /opt/cni/bin
sudo tar -xvf ${cni_plugins_archive} -C /opt/cni/bin/
```

### Step 4: Configure containerd

Same configuration as single-node document 04. `SystemdCgroup = true` because Ubuntu uses systemd; running cgroupfs and systemd cgroup managers simultaneously causes instability.

```bash
sudo mkdir -p /etc/containerd/

cat <<EOF | sudo tee /etc/containerd/config.toml
version = 3
[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc]
  runtime_type = 'io.containerd.runc.v2'
  [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
    SystemdCgroup = true
    BinaryName = '/usr/local/bin/runc'
EOF
```

### Step 5: systemd Unit

```bash
cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF
```

### Step 6: Start

```bash
sudo systemctl daemon-reload
sudo systemctl enable containerd
sudo systemctl start containerd

# Verify
systemctl status containerd --no-pager
sudo crictl --runtime-endpoint unix:///var/run/containerd/containerd.sock info | head -20
```

### Step 7: crictl Default Endpoint

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

### Step 5: Pre-Pull Control Plane Images (node1 only)

On `node1` only, pre-pull the images `kubeadm init` will need. This is optional but lets you catch image-pull errors before `kubeadm init` runs.

```bash
sudo kubeadm config images pull --kubernetes-version v1.35.3
```

This pulls `kube-apiserver`, `kube-controller-manager`, `kube-scheduler`, `kube-proxy`, `pause`, `etcd`, and `coredns`. On `node2` skip this step; the worker only needs `kube-proxy` and `pause`, which `kubeadm join` will pull when needed.

---

## Part 3: Verify Both Nodes Are Ready

Same checklist on each node. Repeat on `node1` and `node2`:

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

| Component | Binary Location | Purpose |
|-----------|----------------|---------|
| containerd | `/bin/containerd` | Container lifecycle daemon, CRI implementation |
| runc | `/usr/local/bin/runc` | Low-level container executor (OCI runtime) |
| crictl | `/usr/local/bin/crictl` | CLI tool for container inspection/debugging |
| CNI plugin binaries | `/opt/cni/bin/*` | Bridge, host-local, loopback, plus others Calico depends on |
| kubeadm | `/usr/bin/kubeadm` | Cluster bootstrap and lifecycle tool |
| kubelet | `/usr/bin/kubelet` | Node agent (does not yet run; will be started by `kubeadm init` or `kubeadm join`) |
| kubectl | `/usr/bin/kubectl` | Kubernetes CLI |

The next document runs `kubeadm init` on `node1`.
