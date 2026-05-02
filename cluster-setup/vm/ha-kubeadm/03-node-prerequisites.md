# Node Prerequisites: Five Nodes

**Based on:** [`three-kubeadm/03-node-prerequisites.md`](../three-kubeadm/03-node-prerequisites.md)

**Purpose:** Install the container runtime and kubeadm toolchain on all five nodes.
The commands are identical to the three-node guide, extended to cover both control
planes and all three workers.

---

## Prerequisites

All five VMs are running and reachable:

```bash
for node in controlplane-1 controlplane-2 nodes-1 nodes-2 nodes-3; do
  ssh "$node" 'echo "$(hostname): $(hostname -I)"'
done
```

## Part 1: Install containerd and runc (all five nodes)

```bash
CONTAINERD_VERSION=2.1.3
RUNC_VERSION=1.3.0
CNI_VERSION=1.7.1
CRI_VERSION=1.35.0
ARCH=amd64

for node in controlplane-1 controlplane-2 nodes-1 nodes-2 nodes-3; do
  echo "=== $node ==="
  ssh "$node" "sudo bash" <<EOF
set -euo pipefail

curl -fsSL https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz \
  | sudo tar -C /usr/local -xz

curl -fsSLo /usr/local/sbin/runc https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.${ARCH}
chmod +x /usr/local/sbin/runc

mkdir -p /opt/cni/bin
curl -fsSL https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/cni-plugins-linux-${ARCH}-v${CNI_VERSION}.tgz \
  | tar -C /opt/cni/bin -xz

curl -fsSL https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRI_VERSION}/crictl-v${CRI_VERSION}-linux-${ARCH}.tar.gz \
  | sudo tar -C /usr/local/bin -xz

mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

curl -fsSLo /etc/systemd/system/containerd.service \
  https://raw.githubusercontent.com/containerd/containerd/v${CONTAINERD_VERSION}/containerd.service

cat > /etc/crictl.yaml <<CRICTL
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
CRICTL

systemctl daemon-reload
systemctl enable --now containerd
EOF
done
```

## Part 2: Install kubeadm, kubelet, kubectl (all five nodes)

```bash
K8S_VERSION=1.35

for node in controlplane-1 controlplane-2 nodes-1 nodes-2 nodes-3; do
  echo "=== $node ==="
  ssh "$node" "sudo bash" <<EOF
set -euo pipefail

curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubeadm=1.35.3-1.1 kubelet=1.35.3-1.1 kubectl=1.35.3-1.1
apt-mark hold kubeadm kubelet kubectl

systemctl enable kubelet
EOF
done
```

## Part 3: Verify

```bash
for node in controlplane-1 controlplane-2 nodes-1 nodes-2 nodes-3; do
  echo "=== $node ==="
  ssh "$node" '
    sudo ctr version 2>/dev/null | grep Version || echo "containerd: ERROR"
    kubeadm version -o short
  '
done
```

**Result:** All five nodes have containerd running and the kubeadm toolchain at v1.35.3.
