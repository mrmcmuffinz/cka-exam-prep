#!/usr/bin/env bash
#
# break-cluster.sh
#
# Introduces a single fault into the Kubernetes cluster for troubleshooting practice.
# Run this from the QEMU host. The script SSHes into the VM to apply the break.
#
# Usage:
#   ./break-cluster.sh          # Pick a random scenario
#   ./break-cluster.sh 3        # Run scenario 3 specifically
#   ./break-cluster.sh --list   # Show how many scenarios are available (no spoilers)
#   ./break-cluster.sh --reset  # Attempt to restore all components to working state
#
# Configuration:
#   Set BREAK_SSH_CMD to override the default SSH command.
#   Example: export BREAK_SSH_CMD="ssh node01"
#
# After running, SSH into the VM and use kubectl, systemctl, journalctl, and your
# knowledge of the cluster to diagnose and fix the problem.

set -euo pipefail

TOTAL_SCENARIOS=15

# -------------------------------------------------------------------
# SSH configuration
# Adjust these if your SSH config differs.
# If you have a Host entry in ~/.ssh/config, set BREAK_SSH_CMD="ssh node01".
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
# -------------------------------------------------------------------

scenario_1() {
  backup_if_needed /etc/systemd/system/etcd.service
  run_on_vm "sed -i 's|--data-dir=/var/lib/etcd|--data-dir=/var/lib/etcd-bad|' /etc/systemd/system/etcd.service && systemctl daemon-reload && systemctl restart etcd" 2>/dev/null || true
}

scenario_2() {
  backup_if_needed /etc/systemd/system/kube-apiserver.service
  run_on_vm "sed -i 's|--etcd-servers=https://127.0.0.1:2379|--etcd-servers=https://127.0.0.1:9999|' /etc/systemd/system/kube-apiserver.service && systemctl daemon-reload && systemctl restart kube-apiserver" 2>/dev/null || true
}

scenario_3() {
  backup_if_needed /etc/systemd/system/kube-apiserver.service
  run_on_vm "sed -i 's|--tls-cert-file=/var/lib/kubernetes/kubernetes.pem|--tls-cert-file=/var/lib/kubernetes/missing.pem|' /etc/systemd/system/kube-apiserver.service && systemctl daemon-reload && systemctl restart kube-apiserver" 2>/dev/null || true
}

scenario_4() {
  backup_if_needed /etc/systemd/system/kube-controller-manager.service
  run_on_vm "sed -i 's|--kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig|--kubeconfig=/var/lib/kubernetes/wrong.kubeconfig|' /etc/systemd/system/kube-controller-manager.service && systemctl daemon-reload && systemctl restart kube-controller-manager" 2>/dev/null || true
}

scenario_5() {
  backup_if_needed /etc/systemd/system/kube-scheduler.service
  run_on_vm "sed -i 's|--config=/etc/kubernetes/config/kube-scheduler.yaml|--config=/etc/kubernetes/config/missing-scheduler.yaml|' /etc/systemd/system/kube-scheduler.service && systemctl daemon-reload && systemctl restart kube-scheduler" 2>/dev/null || true
}

scenario_6() {
  run_on_vm "systemctl stop kube-apiserver && systemctl disable kube-apiserver" 2>/dev/null || true
}

scenario_7() {
  backup_if_needed /etc/etcd/ca.pem
  run_on_vm "mv /etc/etcd/ca.pem /etc/etcd/ca.pem.hidden && systemctl restart etcd" 2>/dev/null || true
}

scenario_8() {
  backup_if_needed /etc/systemd/system/kube-apiserver.service
  run_on_vm "sed -i 's|--service-cluster-ip-range=10.96.0.0/16|--service-cluster-ip-range=10.99.0.0/16|' /etc/systemd/system/kube-apiserver.service && systemctl daemon-reload && systemctl restart kube-apiserver" 2>/dev/null || true
}

scenario_9() {
  backup_if_needed /etc/systemd/system/etcd.service
  run_on_vm "sed -i 's|--listen-client-urls https://|--listen-client-urls http://|g' /etc/systemd/system/etcd.service && systemctl daemon-reload && systemctl restart etcd" 2>/dev/null || true
}

scenario_10() {
  backup_if_needed /etc/systemd/system/kube-apiserver.service
  run_on_vm "sed -i 's|--authorization-mode=Node,RBAC|--authorization-mode=AlwaysDeny|' /etc/systemd/system/kube-apiserver.service && systemctl daemon-reload && systemctl restart kube-apiserver" 2>/dev/null || true
}

scenario_11() {
  backup_if_needed /var/lib/kubelet/kubelet-config.yaml
  run_on_vm "sed -i 's|containerRuntimeEndpoint: \"unix:///var/run/containerd/containerd.sock\"|containerRuntimeEndpoint: \"unix:///var/run/containerd/wrong.sock\"|' /var/lib/kubelet/kubelet-config.yaml && systemctl restart kubelet" 2>/dev/null || true
}

scenario_12() {
  run_on_vm "systemctl stop containerd && systemctl disable containerd" 2>/dev/null || true
}

scenario_13() {
  backup_if_needed /etc/cni/net.d/10-bridge.conf
  run_on_vm "mv /etc/cni/net.d/10-bridge.conf /etc/cni/net.d/10-bridge.conf.hidden && systemctl restart kubelet" 2>/dev/null || true
}

scenario_14() {
  backup_if_needed /var/lib/kubelet/kubeconfig
  run_on_vm "sed -i 's|server: https://127.0.0.1:6443|server: https://127.0.0.1:7777|' /var/lib/kubelet/kubeconfig && systemctl restart kubelet" 2>/dev/null || true
}

scenario_15() {
  backup_if_needed /etc/systemd/system/kube-apiserver.service
  run_on_vm "sed -i 's|--enable-admission-plugins=|--enable-admission-plugins=AlwaysDeny,|' /etc/systemd/system/kube-apiserver.service && systemctl daemon-reload && systemctl restart kube-apiserver" 2>/dev/null || true
}

# -------------------------------------------------------------------
# Reset function
# -------------------------------------------------------------------
reset_all() {
  echo "=== Restoring all components ==="

  $SSH_CMD "sudo bash" << 'REMOTE'
files=(
  /etc/systemd/system/etcd.service
  /etc/systemd/system/kube-apiserver.service
  /etc/systemd/system/kube-controller-manager.service
  /etc/systemd/system/kube-scheduler.service
  /var/lib/kubelet/kubelet-config.yaml
  /var/lib/kubelet/kubeconfig
  /etc/cni/net.d/10-bridge.conf
  /etc/etcd/ca.pem
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

systemctl daemon-reload
systemctl enable etcd kube-apiserver kube-controller-manager kube-scheduler containerd kubelet kube-proxy 2>/dev/null || true
systemctl restart etcd
sleep 2
systemctl restart kube-apiserver
sleep 2
systemctl restart kube-controller-manager
systemctl restart kube-scheduler
systemctl restart containerd
sleep 2
systemctl restart kubelet
systemctl restart kube-proxy

echo ""
echo "=== Reset complete. Waiting 10 seconds for components to stabilize... ==="
sleep 10

echo ""
echo "=== Component status ==="
for svc in etcd kube-apiserver kube-controller-manager kube-scheduler containerd kubelet kube-proxy; do
  status=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")
  printf "  %-30s %s\n" "$svc" "$status"
done

echo ""
echo "=== Node status ==="
KUBECONFIG=/home/kube/.kube/config kubectl get nodes 2>/dev/null || echo "  kubectl not responding yet, give it another minute"
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
echo "============================================="
echo ""
echo "Something has been broken in your cluster."
echo "SSH into the VM and use kubectl, systemctl,"
echo "journalctl, and your knowledge of the cluster"
echo "to find and fix the problem."
echo ""
echo "  ssh -p 2222 kube@127.0.0.1"
echo ""
echo "Diagnostic starting points:"
echo "  systemctl status <service>"
echo "  journalctl -u <service>"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  curl -k https://127.0.0.1:6443/healthz"
echo ""
echo "To reset: $0 --reset"
echo "============================================="

"scenario_${scenario_num}"

echo ""
echo "Break applied. Good luck."
