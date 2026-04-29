#!/usr/bin/env bash
#
# break-cluster.sh
#
# Introduces a single fault into the kubeadm-installed single-node Kubernetes
# cluster for troubleshooting practice. Run this from the QEMU host. The script
# SSHes into the VM to apply the break.
#
# Unlike the single-systemd version (which targets systemd unit files), this
# script targets the kubeadm-specific surface: static pod manifests in
# /etc/kubernetes/manifests/, the Tigera operator and Calico installation,
# kubelet config, and apt-pinned package state.
#
# Usage:
#   ./break-cluster.sh          # Pick a random scenario
#   ./break-cluster.sh 3        # Run scenario 3 specifically
#   ./break-cluster.sh --list   # Show how many scenarios are available (no spoilers)
#   ./break-cluster.sh --reset  # Attempt to restore all components to working state
#
# Configuration:
#   Set BREAK_SSH_CMD to override the default SSH command.
#   Example: export BREAK_SSH_CMD="ssh node1"
#
# After running, SSH into the VM and use kubectl, systemctl, journalctl, crictl,
# and your knowledge of the cluster to diagnose and fix the problem.

set -euo pipefail

TOTAL_SCENARIOS=15

# -------------------------------------------------------------------
# SSH configuration
# Adjust if your SSH config differs.
# If you have a Host entry in ~/.ssh/config, set BREAK_SSH_CMD="ssh node1".
# -------------------------------------------------------------------
SSH_CMD="${BREAK_SSH_CMD:-ssh -p 2222 kube@127.0.0.1}"

run_on_vm() {
  $SSH_CMD "sudo bash -c '$1'"
}

# -------------------------------------------------------------------
# Backup helper (runs on VM)
# -------------------------------------------------------------------
backup_if_needed() {
  local file="$1"
  run_on_vm "if [ -f '$file' ] && [ ! -f '${file}.break-backup' ]; then cp '$file' '${file}.break-backup'; fi"
}

# -------------------------------------------------------------------
# Scenarios
# Each one introduces a different category of failure that maps to a
# CKA-relevant troubleshooting skill.
# -------------------------------------------------------------------

# Bad etcd data-dir in static pod manifest
scenario_1() {
  backup_if_needed /etc/kubernetes/manifests/etcd.yaml
  run_on_vm "sed -i 's|--data-dir=/var/lib/etcd|--data-dir=/var/lib/etcd-bad|' /etc/kubernetes/manifests/etcd.yaml" 2>/dev/null || true
}

# Wrong etcd endpoint in apiserver static pod manifest
scenario_2() {
  backup_if_needed /etc/kubernetes/manifests/kube-apiserver.yaml
  run_on_vm "sed -i 's|--etcd-servers=https://127.0.0.1:2379|--etcd-servers=https://127.0.0.1:9999|' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null || true
}

# Missing apiserver TLS cert path
scenario_3() {
  backup_if_needed /etc/kubernetes/manifests/kube-apiserver.yaml
  run_on_vm "sed -i 's|--tls-cert-file=/etc/kubernetes/pki/apiserver.crt|--tls-cert-file=/etc/kubernetes/pki/missing.crt|' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null || true
}

# Wrong kubeconfig path in controller-manager static pod manifest
scenario_4() {
  backup_if_needed /etc/kubernetes/manifests/kube-controller-manager.yaml
  run_on_vm "sed -i 's|--kubeconfig=/etc/kubernetes/controller-manager.conf|--kubeconfig=/etc/kubernetes/wrong.conf|' /etc/kubernetes/manifests/kube-controller-manager.yaml" 2>/dev/null || true
}

# Wrong kubeconfig path in scheduler static pod manifest
scenario_5() {
  backup_if_needed /etc/kubernetes/manifests/kube-scheduler.yaml
  run_on_vm "sed -i 's|--kubeconfig=/etc/kubernetes/scheduler.conf|--kubeconfig=/etc/kubernetes/missing-scheduler.conf|' /etc/kubernetes/manifests/kube-scheduler.yaml" 2>/dev/null || true
}

# kubelet stopped and disabled (entire cluster goes down because kubelet manages static pods)
scenario_6() {
  run_on_vm "systemctl stop kubelet && systemctl disable kubelet" 2>/dev/null || true
}

# etcd CA hidden (signature validation will fail)
scenario_7() {
  backup_if_needed /etc/kubernetes/pki/etcd/ca.crt
  run_on_vm "mv /etc/kubernetes/pki/etcd/ca.crt /etc/kubernetes/pki/etcd/ca.crt.hidden" 2>/dev/null || true
}

# Wrong service-cluster-ip-range in apiserver (DNS and existing Services break)
scenario_8() {
  backup_if_needed /etc/kubernetes/manifests/kube-apiserver.yaml
  run_on_vm "sed -i 's|--service-cluster-ip-range=10.96.0.0/16|--service-cluster-ip-range=10.99.0.0/16|' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null || true
}

# containerd cgroup driver mismatch (kubelet expects systemd)
scenario_9() {
  backup_if_needed /etc/containerd/config.toml
  run_on_vm "sed -i 's|SystemdCgroup = true|SystemdCgroup = false|' /etc/containerd/config.toml && systemctl restart containerd" 2>/dev/null || true
}

# AlwaysDeny authorization mode in apiserver
scenario_10() {
  backup_if_needed /etc/kubernetes/manifests/kube-apiserver.yaml
  run_on_vm "sed -i 's|--authorization-mode=Node,RBAC|--authorization-mode=AlwaysDeny|' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null || true
}

# Wrong containerd socket in kubelet config
scenario_11() {
  backup_if_needed /var/lib/kubelet/config.yaml
  run_on_vm "sed -i 's|containerRuntimeEndpoint: unix:///run/containerd/containerd.sock|containerRuntimeEndpoint: unix:///run/containerd/wrong.sock|' /var/lib/kubelet/config.yaml && systemctl restart kubelet" 2>/dev/null || true
}

# containerd stopped and disabled (no container runtime)
scenario_12() {
  run_on_vm "systemctl stop containerd && systemctl disable containerd" 2>/dev/null || true
}

# Calico CNI config hidden (node goes NotReady)
scenario_13() {
  run_on_vm "if [ -f /etc/cni/net.d/10-calico.conflist ]; then mv /etc/cni/net.d/10-calico.conflist /etc/cni/net.d/10-calico.conflist.hidden; fi" 2>/dev/null || true
}

# Tigera operator scaled to zero (Calico stops being reconciled, eventually breaks)
scenario_14() {
  run_on_vm "kubectl --kubeconfig=/etc/kubernetes/admin.conf scale deployment tigera-operator -n tigera-operator --replicas=0" 2>/dev/null || true
  # Then delete a calico-node pod so we can see the operator is missing
  run_on_vm "kubectl --kubeconfig=/etc/kubernetes/admin.conf delete pod -n calico-system -l k8s-app=calico-node --ignore-not-found" 2>/dev/null || true
}

# AlwaysDeny admission controller in apiserver
scenario_15() {
  backup_if_needed /etc/kubernetes/manifests/kube-apiserver.yaml
  run_on_vm "sed -i 's|--enable-admission-plugins=NodeRestriction|--enable-admission-plugins=NodeRestriction,AlwaysDeny|' /etc/kubernetes/manifests/kube-apiserver.yaml" 2>/dev/null || true
}

# -------------------------------------------------------------------
# Reset function
# -------------------------------------------------------------------
reset_all() {
  echo "=== Restoring all components ==="

  $SSH_CMD "sudo bash" << 'REMOTE'
files=(
  /etc/kubernetes/manifests/etcd.yaml
  /etc/kubernetes/manifests/kube-apiserver.yaml
  /etc/kubernetes/manifests/kube-controller-manager.yaml
  /etc/kubernetes/manifests/kube-scheduler.yaml
  /etc/containerd/config.toml
  /var/lib/kubelet/config.yaml
  /etc/kubernetes/pki/etcd/ca.crt
)

for file in "${files[@]}"; do
  if [ -f "${file}.break-backup" ]; then
    cp "${file}.break-backup" "$file"
    echo "  Restored: $file"
  fi
  if [ -f "${file}.hidden" ]; then
    mv "${file}.hidden" "$file"
    echo "  Unhidden: $file"
  fi
done

# Restore Calico CNI config if hidden
if [ -f /etc/cni/net.d/10-calico.conflist.hidden ]; then
  mv /etc/cni/net.d/10-calico.conflist.hidden /etc/cni/net.d/10-calico.conflist
  echo "  Unhidden: /etc/cni/net.d/10-calico.conflist"
fi

# Re-enable services
systemctl daemon-reload
systemctl enable containerd kubelet 2>/dev/null || true
systemctl restart containerd
sleep 2
systemctl restart kubelet

# Scale tigera-operator back up if it was scaled down
kubectl --kubeconfig=/etc/kubernetes/admin.conf scale deployment tigera-operator -n tigera-operator --replicas=1 2>/dev/null || true

echo ""
echo "=== Reset complete. Waiting 15 seconds for static pods to come back... ==="
sleep 15

echo ""
echo "=== Service status ==="
for svc in containerd kubelet; do
  status=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")
  printf "  %-30s %s\n" "$svc" "$status"
done

echo ""
echo "=== Static pod status ==="
sudo crictl ps 2>/dev/null | grep -E "apiserver|etcd|controller|scheduler" | awk '{print "  " $NF " " $5}' || echo "  crictl not responding yet"

echo ""
echo "=== Node status ==="
kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes 2>/dev/null || echo "  apiserver not responding yet, give it another minute"
REMOTE
}

# -------------------------------------------------------------------
# Main
# -------------------------------------------------------------------

if [[ "${1:-}" == "--list" ]]; then
  echo "$TOTAL_SCENARIOS scenarios available."
  echo "Usage: $0 [1-$TOTAL_SCENARIOS] or $0 for random."
  exit 0
fi

if [[ "${1:-}" == "--reset" ]]; then
  reset_all
  exit 0
fi

if [[ -n "${1:-}" ]]; then
  scenario_num="$1"
else
  scenario_num=$(( (RANDOM % TOTAL_SCENARIOS) + 1 ))
fi

if [[ "$scenario_num" -lt 1 || "$scenario_num" -gt "$TOTAL_SCENARIOS" ]]; then
  echo "ERROR: Scenario must be between 1 and $TOTAL_SCENARIOS."
  exit 1
fi

echo "============================================="
echo "  Cluster Break Scenario #${scenario_num}"
echo "  (single-kubeadm)"
echo "============================================="
echo ""
echo "Something has been broken in your cluster."
echo "SSH into the VM and use kubectl, systemctl,"
echo "journalctl, crictl, and your knowledge of the"
echo "cluster to find and fix the problem."
echo ""
echo "  ssh -p 2222 kube@127.0.0.1"
echo ""
echo "Diagnostic starting points:"
echo "  systemctl status kubelet containerd"
echo "  journalctl -u kubelet -n 50"
echo "  sudo crictl ps -a"
echo "  sudo ls /etc/kubernetes/manifests/"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  curl -k https://127.0.0.1:6443/healthz"
echo ""
echo "Remember: control plane components are static pods."
echo "kubelet recreates them automatically when their"
echo "manifest in /etc/kubernetes/manifests/ changes."
echo ""
echo "To reset: $0 --reset"
echo "============================================="

"scenario_${scenario_num}"

echo ""
echo "Break applied. Good luck."
