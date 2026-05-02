# VM Provisioning: Five Nodes

**Based on:** [`three-kubeadm/02-vm-provisioning.md`](../three-kubeadm/02-vm-provisioning.md)

**Purpose:** Create five headless Ubuntu 24.04 VMs on the host bridge with static IPs
and cloud-init. The process is identical to the three-node guide but extended to cover
two control planes and three workers.

---

## Prerequisites

- `br0` is configured and HAProxy is running (document 01).
- Ubuntu 24.04 cloud image is cached at `~/cka-lab/images/ubuntu-24.04-server-cloudimg-amd64.img`.
- `qemu-system-x86_64`, `qemu-img`, and `genisoimage` are installed on the host.

## Node Assignment

| Hostname | Bridge IP | Role |
|----------|-----------|------|
| `controlplane-1` | `192.168.122.10` | First control plane |
| `controlplane-2` | `192.168.122.11` | Second control plane |
| `nodes-1` | `192.168.122.12` | Worker |
| `nodes-2` | `192.168.122.13` | Worker |
| `nodes-3` | `192.168.122.14` | Worker |

## Part 1: Directory Structure

```bash
BASE=~/cka-lab/ha-kubeadm
for name in controlplane-1 controlplane-2 nodes-1 nodes-2 nodes-3; do
  mkdir -p "$BASE/$name/cloud-init"
done
```

## Part 2: Generate Per-Node Cloud-Init and Disks

```bash
BASE=~/cka-lab/ha-kubeadm
IMAGE=~/cka-lab/images/ubuntu-24.04-server-cloudimg-amd64.img

generate_node() {
  local name="$1"
  local ip="$2"
  local node_dir="$BASE/$name"

  cat > "$node_dir/cloud-init/meta-data" <<EOF
instance-id: ${name}
local-hostname: ${name}
EOF

  cat > "$node_dir/cloud-init/user-data" <<EOF
#cloud-config

hostname: ${name}
manage_etc_hosts: true
fqdn: ${name}.cka.local

users:
  - name: kube
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo
    shell: /bin/bash
    lock_passwd: false
    plain_text_passwd: "kubeadmin"
    ssh_authorized_keys: []

ssh_pwauth: true

packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
  - socat
  - conntrack
  - ipset
  - net-tools
  - jq
  - bash-completion
  - vim

write_files:
  - path: /etc/modules-load.d/k8s.conf
    content: |
      overlay
      br_netfilter

  - path: /etc/sysctl.d/k8s.conf
    content: |
      net.bridge.bridge-nf-call-iptables  = 1
      net.bridge.bridge-nf-call-ip6tables = 1
      net.ipv4.ip_forward                 = 1

  - path: /etc/netplan/99-cka-bridge.yaml
    content: |
      network:
        version: 2
        ethernets:
          enp0s2:
            dhcp4: false
            addresses: [${ip}/24]
            routes:
              - to: default
                via: 192.168.122.1
            nameservers:
              addresses: [8.8.8.8, 8.8.4.4]

runcmd:
  - netplan apply
  - modprobe overlay
  - modprobe br_netfilter
  - sysctl --system
  - swapoff -a
  - sed -i '/\sswap\s/s/^/#/' /etc/fstab

power_state:
  mode: reboot
  message: "Cloud-init complete. Rebooting."
  timeout: 30
  condition: true
EOF

  genisoimage -output "$node_dir/seed.iso" \
    -volid cidata -joliet -rock \
    "$node_dir/cloud-init/user-data" \
    "$node_dir/cloud-init/meta-data"

  qemu-img create -f qcow2 \
    -b "$(realpath "$IMAGE")" -F qcow2 \
    "$node_dir/${name}.qcow2" 40G

  echo "Node $name configured at $node_dir"
}

generate_node controlplane-1 192.168.122.10
generate_node controlplane-2 192.168.122.11
generate_node nodes-1        192.168.122.12
generate_node nodes-2        192.168.122.13
generate_node nodes-3        192.168.122.14
```

## Part 3: Per-Node Start and Stop Scripts

```bash
BASE=~/cka-lab/ha-kubeadm

make_scripts() {
  local name="$1"
  local node_dir="$BASE/$name"

  cat > "$node_dir/start-${name}.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
qemu-system-x86_64 \\
    -name ${name} \\
    -machine type=q35,accel=kvm \\
    -cpu host -smp 2 -m 4096 \\
    -drive file="\$SCRIPT_DIR/${name}.qcow2",format=qcow2,if=virtio \\
    -drive file="\$SCRIPT_DIR/seed.iso",format=raw,if=virtio \\
    -netdev bridge,id=net0,br=br0 \\
    -device virtio-net-pci,netdev=net0 \\
    -display none \\
    -serial file:"\$SCRIPT_DIR/${name}-console.log" \\
    -daemonize \\
    -pidfile "\$SCRIPT_DIR/${name}.pid" "\$@"
echo "${name} started (PID \$(cat "\$SCRIPT_DIR/${name}.pid"))"
SCRIPT
  chmod +x "$node_dir/start-${name}.sh"

  cat > "$node_dir/stop-${name}.sh" <<SCRIPT
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="\$SCRIPT_DIR/${name}.pid"
if [[ -f "\$PID_FILE" ]]; then
  PID=\$(cat "\$PID_FILE")
  if kill -0 "\$PID" 2>/dev/null; then
    kill "\$PID"
    tail --pid="\$PID" -f /dev/null 2>/dev/null || true
    echo "${name} stopped."
  else
    echo "${name} not running (stale PID)."
  fi
  rm -f "\$PID_FILE"
else
  echo "No PID file for ${name}."
fi
SCRIPT
  chmod +x "$node_dir/stop-${name}.sh"
}

for node in controlplane-1 controlplane-2 nodes-1 nodes-2 nodes-3; do
  make_scripts "$node"
done
```

## Part 4: Cluster-Level Scripts

```bash
BASE=~/cka-lab/ha-kubeadm

cat > "$BASE/start-cluster.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for node in controlplane-1 controlplane-2 nodes-1 nodes-2 nodes-3; do
  "$DIR/$node/start-${node}.sh"
  sleep 2
done
echo "All five nodes starting. Wait 60-90 seconds for cloud-init."
SCRIPT
chmod +x "$BASE/start-cluster.sh"

cat > "$BASE/stop-cluster.sh" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for node in nodes-3 nodes-2 nodes-1 controlplane-2 controlplane-1; do
  "$DIR/$node/stop-${node}.sh"
done
SCRIPT
chmod +x "$BASE/stop-cluster.sh"
```

## Part 5: Start All VMs and Verify

```bash
~/cka-lab/ha-kubeadm/start-cluster.sh
```

Wait 60-90 seconds, then check all five:

```bash
for node in controlplane-1 controlplane-2 nodes-1 nodes-2 nodes-3; do
  echo "=== $node ==="
  ssh "$node" '
    echo "IP: $(hostname -I)"
    echo "Swap: $(free -h | awk "/Swap/ {print \$2}")"
    lsmod | grep -E "overlay|br_netfilter" | awk "{print \$1}"
    sysctl -n net.ipv4.ip_forward
  '
done
```

**Result:** Five VMs at `.10`, `.11`, `.12`, `.13`, `.14` with static bridge IPs,
kubeadm prerequisites met.
