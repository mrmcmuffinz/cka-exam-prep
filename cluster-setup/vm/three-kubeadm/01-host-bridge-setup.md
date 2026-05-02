# Host Bridge Setup for Three-Node Networking

**Based on:** [`two-kubeadm/01-host-bridge-setup.md`](../two-kubeadm/01-host-bridge-setup.md)

**Purpose:** This document is identical to the two-node bridge setup. If `br0` is
already configured on your host from the two-node guides, skip this document entirely
and proceed to [02 - VM Provisioning](02-vm-provisioning.md).

---

## Prerequisites

This step runs on the host, not inside a VM.

## Setup

Follow [`two-kubeadm/01-host-bridge-setup.md`](../two-kubeadm/01-host-bridge-setup.md)
exactly. The bridge, NAT rules, and `qemu-bridge-helper` configuration are identical
regardless of how many VMs attach to it.

**Multi-NIC hosts:** See the multi-NIC NAT fix in Part 3 Step 1 of the two-kubeadm
document if your host has multiple physical interfaces with DHCP leases on the same
subnet.

**Option B (physical NIC uplink):** The two-kubeadm document includes an Option B
section describing how to attach a spare physical NIC to `br0` so VMs get real LAN IPs
without NAT. If you use Option B for this three-node guide, update the VM IPs in
`02-vm-provisioning.md` and `00-overview.md` to use your chosen physical network
addresses instead of `192.168.122.x`.

## Verification

After completing the bridge setup:

```bash
# Bridge exists and has the correct IP
ip addr show br0
# Expected: inet 192.168.122.1/24

# IP forwarding is enabled
sysctl net.ipv4.ip_forward
# Expected: net.ipv4.ip_forward = 1

# NAT rule is present
sudo iptables -t nat -L POSTROUTING -n | grep 192.168.122
# Expected: MASQUERADE rule for 192.168.122.0/24

# qemu-bridge-helper is configured
cat /etc/qemu/bridge.conf | grep br0
# Expected: allow br0
```

**Result:** `br0` is up at `192.168.122.1/24` with NAT for outbound traffic and
`qemu-bridge-helper` configured to allow VMs to attach.
