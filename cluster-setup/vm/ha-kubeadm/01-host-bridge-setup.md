# Host Bridge Setup and HAProxy Load Balancer

**Based on:** [`two-kubeadm/01-host-bridge-setup.md`](../two-kubeadm/01-host-bridge-setup.md)

**Purpose:** Configure the Linux bridge `br0` (identical to the other multi-node guides)
and add a HAProxy load balancer on the host to distribute traffic across both control
plane API servers. The HAProxy VIP (`192.168.122.100`) is the `controlPlaneEndpoint`
that all kubeconfigs and worker join commands point to.

---

## Prerequisites

This step runs on the host, not inside any VM.

## Part 1: Bridge Setup

If `br0` is already configured from a previous guide, skip to Part 2.

Follow [`two-kubeadm/01-host-bridge-setup.md`](../two-kubeadm/01-host-bridge-setup.md)
exactly. The bridge, NAT, and `qemu-bridge-helper` setup is identical.

## Part 2: Add the VIP Address to the Host Bridge

The HAProxy VIP is a static IP alias on the host's `br0` interface. VMs can reach it
at `192.168.122.100` through the bridge.

```bash
# Add the VIP as a persistent alias via systemd-networkd
sudo tee /etc/systemd/network/25-br0-vip.network <<EOF
[Match]
Name=br0

[Address]
Address=192.168.122.100/32
EOF

# Apply without restarting the bridge
sudo ip addr add 192.168.122.100/32 dev br0 2>/dev/null || true
sudo networkctl reload

# Verify
ip addr show br0 | grep 192.168.122
# Should show both 192.168.122.1/24 and 192.168.122.100/32
```

## Part 3: Install HAProxy

```bash
sudo apt-get install -y haproxy
```

## Part 4: Configure HAProxy

```bash
sudo tee /etc/haproxy/haproxy.cfg <<'EOF'
global
    log /dev/log local0
    maxconn 4096
    daemon

defaults
    log global
    mode tcp
    option tcplog
    option dontlognull
    timeout connect 5s
    timeout client  30s
    timeout server  30s

frontend k8s-api
    bind 192.168.122.100:6443
    default_backend k8s-control-planes

backend k8s-control-planes
    balance roundrobin
    option tcp-check
    server controlplane-1 192.168.122.10:6443 check inter 5s fall 2 rise 2
    server controlplane-2 192.168.122.11:6443 check inter 5s fall 2 rise 2

# Stats page (accessible from host at http://192.168.122.1:9000/stats)
listen stats
    bind 192.168.122.1:9000
    mode http
    stats enable
    stats uri /stats
    stats refresh 5s
    stats auth admin:admin
EOF

sudo systemctl enable --now haproxy
sudo systemctl status haproxy --no-pager
```

## Part 5: Pre-Init HAProxy State

Before `kubeadm init` runs, both backends are `DOWN` (the API servers do not exist
yet). HAProxy will show them as down, which is expected. Once `controlplane-1`'s API
server starts, HAProxy will detect it and mark it `UP`.

## Part 6: Verify the Bridge Setup

```bash
# Bridge and VIP exist
ip addr show br0

# HAProxy is listening on the VIP
sudo ss -tlnp | grep 6443

# IP forwarding is on
sysctl net.ipv4.ip_forward
# Expected: 1

# NAT is in place
sudo iptables -t nat -L POSTROUTING -n | grep MASQUERADE
```

**Result:** `br0` is configured at `192.168.122.1/24` with the VIP alias at
`192.168.122.100/32`. HAProxy is running and will route traffic to whichever control
plane API servers are healthy.
