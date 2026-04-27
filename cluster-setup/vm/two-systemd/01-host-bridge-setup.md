# Host Bridge Setup for Multi-Node Networking

**Based on:** Original work, with reference to the [QEMU bridge networking documentation](https://wiki.qemu.org/Documentation/Networking#Bridged_Networking).

**Purpose:** Configure a Linux bridge on the host so the two VMs share an L2 segment, get real IPs in `192.168.122.0/24`, and can be SSH'd into directly. Replaces the QEMU user-mode networking from the single-node guide, which provides each VM with its own NAT'd network and cannot pass traffic between VMs.

---

## Why Bridge Networking

The single-node guide used QEMU user-mode networking (SLiRP), which gives each VM a private NAT'd network and forwards specific ports back to the host. That works for one VM but does not let two VMs talk to each other, which is the whole point of a multi-node cluster. Pod-to-pod traffic between nodes, the worker calling the apiserver during `kubeadm join`, the apiserver calling kubelet for `kubectl exec`, all of it requires real cross-VM connectivity.

The simplest replacement is a Linux bridge on the host with TAP interfaces for each VM. The bridge becomes a virtual switch; each VM's NIC is a port on that switch. The host gives the bridge an IP and acts as the gateway, so VMs reach the internet through the host's existing uplink interface via NAT.

```
internet
   |
   | (host's uplink: eth0, wlp4s0, etc.)
   |
+--+----------------------------------+
| Host                                |
|   br0 (192.168.122.1/24)            |
|     |                               |
|     +--- tap0 ---- node1 (.10)      |
|     +--- tap1 ---- node2 (.11)      |
+-------------------------------------+
```

VMs reach each other directly over the bridge with no host involvement. VMs reach the internet via NAT on the host. The host can SSH to either VM by IP.

## libvirt Conflict Check

libvirt ships with a default network on `192.168.122.0/24`, served by an interface called `virbr0`. If that network is up on your host, the manual `br0` setup in this document will conflict with it. You have two options:

1. **Reuse `virbr0`.** If you already use libvirt for other VMs, just attach to `virbr0` and skip the bridge creation steps below. The `qemu-bridge-helper` configuration step still applies. The QEMU command in document 02 will need `br=virbr0` instead of `br=br0`.
2. **Build `br0` from scratch.** Recommended if you do not already use libvirt. Disable `virbr0` first if it exists.

Check first:

```bash
# Does the libvirt default network exist?
ip addr show virbr0 2>/dev/null

# Is libvirtd running and managing it?
systemctl is-active libvirtd
```

If `virbr0` exists with `192.168.122.1/24` and you want to disable it:

```bash
sudo virsh net-destroy default
sudo virsh net-autostart --disable default
```

The rest of this document assumes you are building `br0` from scratch. If you are reusing `virbr0`, jump to Part 4 (qemu-bridge-helper).

---

## Part 1: Prerequisites

Install the bridge tools and netfilter persistence packages. `iptables-persistent` saves the NAT rules across reboots.

```bash
sudo apt update
sudo apt install -y bridge-utils iptables-persistent
```

When `iptables-persistent` installs it will ask whether to save current rules. Answer **No** for both IPv4 and IPv6. The rules will be saved later, after they have been added.

---

## Part 2: Create the Bridge

Ubuntu 24.04 ships with `systemd-networkd`. Defining the bridge through `systemd-networkd` keeps it simple and survives reboots cleanly.

### Step 1: Bridge Device

Create the netdev definition:

```bash
sudo tee /etc/systemd/network/10-br0.netdev > /dev/null <<'EOF'
[NetDev]
Name=br0
Kind=bridge

[Bridge]
STP=off
EOF
```

`STP=off` is intentional. The Spanning Tree Protocol is for physical networks with potential loops. With a virtual bridge serving only TAP interfaces, there is no loop risk and STP just adds a 30-second forwarding delay every time a port goes up.

### Step 2: Bridge Network Configuration

```bash
sudo tee /etc/systemd/network/20-br0.network > /dev/null <<'EOF'
[Match]
Name=br0

[Network]
Address=192.168.122.1/24
ConfigureWithoutCarrier=yes
IPForward=ipv4
EOF
```

`ConfigureWithoutCarrier=yes` tells `systemd-networkd` to bring the bridge up even when no TAP interfaces are attached yet. Without this, the bridge only comes up when the first VM connects, which causes a chicken-and-egg problem with NAT rules.

### Step 3: Activate

```bash
sudo systemctl enable --now systemd-networkd
sudo systemctl restart systemd-networkd

# Verify
ip addr show br0
```

The output should show `br0` with `192.168.122.1/24`. If it does not, check `journalctl -u systemd-networkd -n 30` for parse errors.

---

## Part 3: NAT for Outbound Traffic

The bridge has its own subnet that does not exist anywhere outside the host. For VMs to reach the internet, traffic leaving the host needs to be masqueraded so that it appears to come from the host's uplink.

### Step 1: Identify the Uplink Interface

```bash
UPLINK=$(ip route | awk '/default/ {print $5; exit}')
echo "Uplink interface: $UPLINK"
```

This will be something like `wlp4s0`, `eth0`, or `enp3s0` depending on your hardware.

### Step 2: Enable IP Forwarding

```bash
sudo tee /etc/sysctl.d/99-bridge-forward.conf > /dev/null <<'EOF'
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
EOF

sudo sysctl --system

# Verify
sysctl net.ipv4.ip_forward
```

Should print `net.ipv4.ip_forward = 1`.

### Step 3: Add iptables Rules

```bash
# Masquerade VM traffic destined for outside the bridge subnet
sudo iptables -t nat -A POSTROUTING -s 192.168.122.0/24 ! -d 192.168.122.0/24 -o "$UPLINK" -j MASQUERADE

# Allow forwarding both directions
sudo iptables -A FORWARD -i br0 -o "$UPLINK" -j ACCEPT
sudo iptables -A FORWARD -i "$UPLINK" -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

### Step 4: Persist the Rules

```bash
sudo netfilter-persistent save
```

This writes the current rules to `/etc/iptables/rules.v4` so they survive a reboot.

If your system uses `nftables` instead of `iptables-nft`, the equivalent ruleset is:

```bash
sudo nft add table inet nat
sudo nft 'add chain inet nat postrouting { type nat hook postrouting priority 100; }'
sudo nft "add rule inet nat postrouting ip saddr 192.168.122.0/24 ip daddr != 192.168.122.0/24 oifname \"$UPLINK\" masquerade"
```

To check which backend your system is using, run `sudo iptables -V`. If it shows `(nf_tables)`, the iptables commands above are translated to nftables under the hood and either approach works.

---

## Part 4: Configure qemu-bridge-helper

QEMU includes a setuid helper binary that creates and attaches TAP interfaces for unprivileged users. The helper checks an allow-list before attaching to a bridge.

### Step 1: Allow `br0`

```bash
sudo mkdir -p /etc/qemu
sudo tee /etc/qemu/bridge.conf > /dev/null <<'EOF'
allow br0
EOF

# Permissions matter
sudo chown root:kvm /etc/qemu/bridge.conf
sudo chmod 0640 /etc/qemu/bridge.conf
```

### Step 2: Make the Helper setuid

The Ubuntu QEMU package usually installs the helper without the setuid bit, which causes a confusing "failed to parse default acl file" error when QEMU tries to attach a TAP. Set it explicitly:

```bash
sudo chmod u+s /usr/lib/qemu/qemu-bridge-helper

# Verify
ls -la /usr/lib/qemu/qemu-bridge-helper
# Should show: -rwsr-xr-x ... root root
```

The `s` in `-rwsr-xr-x` is the setuid bit. Without it, the helper cannot create TAP interfaces.

---

## Part 5: NetworkManager Conflict (Desktop Installs Only)

On Ubuntu Server, this section does not apply. On Ubuntu Desktop, NetworkManager sometimes claims the bridge and the TAP interfaces, which causes the bridge to flap and breaks `qemu-bridge-helper`.

Tell NetworkManager to leave them alone:

```bash
# Only run this if NetworkManager is installed
if systemctl is-active NetworkManager > /dev/null 2>&1; then
  sudo tee /etc/NetworkManager/conf.d/10-unmanaged-br0.conf > /dev/null <<'EOF'
[keyfile]
unmanaged-devices=interface-name:br0;interface-name:tap*
EOF
  sudo systemctl restart NetworkManager
fi
```

---

## Part 6: Verification

Run through the full check before moving to document 02:

```bash
# Bridge exists with correct IP
ip addr show br0 | grep 'inet 192.168.122.1'

# IP forwarding enabled
sysctl net.ipv4.ip_forward

# NAT rule in place
sudo iptables -t nat -L POSTROUTING -n | grep '192.168.122.0/24'

# Forward rules in place
sudo iptables -L FORWARD -n | grep -E 'br0|192\.168\.122'

# qemu-bridge-helper is setuid
ls -la /usr/lib/qemu/qemu-bridge-helper | grep '^-rws'

# Bridge config allows br0
sudo cat /etc/qemu/bridge.conf
```

All six checks should produce output. If any are missing or wrong, fix that step before proceeding.

---

## Summary

The host is now configured to support bridge networking for the two VMs:

| Component | Path | Purpose |
|-----------|------|---------|
| Bridge device | `/etc/systemd/network/10-br0.netdev` | Defines the `br0` bridge |
| Bridge address | `/etc/systemd/network/20-br0.network` | Assigns `192.168.122.1/24` to `br0` |
| IP forwarding | `/etc/sysctl.d/99-bridge-forward.conf` | Enables forwarding between bridge and uplink |
| NAT rules | `/etc/iptables/rules.v4` | Masquerades VM traffic going out the uplink |
| QEMU helper allow-list | `/etc/qemu/bridge.conf` | Permits unprivileged attach to `br0` |
| QEMU helper binary | `/usr/lib/qemu/qemu-bridge-helper` | setuid root, creates TAP interfaces |

The next document creates the two VMs and attaches them to this bridge.
