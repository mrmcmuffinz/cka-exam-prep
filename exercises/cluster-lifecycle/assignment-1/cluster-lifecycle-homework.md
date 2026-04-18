# Cluster Lifecycle Homework: Cluster Installation with kubeadm

This homework contains 15 progressive exercises covering kubeadm artifacts, cluster health, and targeted lifecycle operations. Every exercise is a build-or-fix task with a verifiable end state. Because kind abstracts the bare-metal kubeadm workflow, these exercises focus on operations that are meaningful inside a kind control-plane container: editing manifests, running `kubeadm` subcommands, verifying certificates, and observing kubelet reconciliation.

All exercises assume the multi-node kind cluster from `docs/cluster-setup.md#multi-node-kind-cluster`:

```bash
kubectl config current-context     # expect: kind-kind
kubectl get nodes                  # expect: 4 nodes, all Ready
nerdctl ps | grep kind-control-plane   # expect: one Up row
```

Every operation that modifies the control plane node runs inside the node via `nerdctl exec kind-control-plane bash -c '...'` or `nerdctl exec -it kind-control-plane bash`. Every exercise that breaks the cluster has an explicit recovery step.

## Global Setup

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 \
          ex-2-1 ex-2-2 ex-2-3 \
          ex-3-1 ex-3-2 ex-3-3 \
          ex-4-1 ex-4-2 ex-4-3 \
          ex-5-1 ex-5-2 ex-5-3; do
  kubectl create namespace $ns
done
```

---

## Level 1: Static Pod Manifests and Certificates

### Exercise 1.1

**Objective:** Confirm kubelet's static-pod reconciliation by restarting the scheduler via manifest touch, and verify the pod's Age resets.

**Task:**

Inside the control plane node, capture the current scheduler pod's creationTimestamp, touch `/etc/kubernetes/manifests/kube-scheduler.yaml`, and wait for kubelet to reconcile. Confirm the pod has been recreated (new creationTimestamp).

**Verification:**

```bash
BEFORE=$(kubectl get pod kube-scheduler-kind-control-plane -n kube-system \
  -o jsonpath='{.metadata.creationTimestamp}')
echo "Before: $BEFORE"

nerdctl exec kind-control-plane touch /etc/kubernetes/manifests/kube-scheduler.yaml
sleep 15

AFTER=$(kubectl get pod kube-scheduler-kind-control-plane -n kube-system \
  -o jsonpath='{.metadata.creationTimestamp}')
echo "After: $AFTER"

# Expected: the After timestamp is later than the Before timestamp.

kubectl get pod kube-scheduler-kind-control-plane -n kube-system \
  -o jsonpath='{.status.containerStatuses[0].ready}{"\n"}'
# Expected: true
```

---

### Exercise 1.2

**Objective:** Verify the cluster's PKI chain of trust using `openssl verify`.

**Task:**

Run `openssl verify` inside the control plane node against `apiserver.crt` (signed by the cluster CA), `apiserver-etcd-client.crt` (signed by the etcd CA), and `front-proxy-client.crt` (signed by the front-proxy CA). Capture all three outputs to `/tmp/ex-1-2-verify.txt` inside the node.

**Verification:**

```bash
nerdctl exec kind-control-plane cat /tmp/ex-1-2-verify.txt
# Expected output (three lines):
# /etc/kubernetes/pki/apiserver.crt: OK
# /etc/kubernetes/pki/apiserver-etcd-client.crt: OK
# /etc/kubernetes/pki/front-proxy-client.crt: OK
```

---

### Exercise 1.3

**Objective:** Prove static-pod lifecycle management by removing the scheduler manifest and restoring it.

**Task:**

Back up `/etc/kubernetes/manifests/kube-scheduler.yaml` to `/tmp/`, remove it from the manifests directory, confirm the scheduler pod disappears, then restore it from the backup and confirm the pod returns to Ready. During the scheduler-down interval, create a test pod in `ex-1-3` and observe that it stays `Pending` until the scheduler returns.

**Verification:**

```bash
# After restoration, scheduler is back:
kubectl get pod kube-scheduler-kind-control-plane -n kube-system \
  -o jsonpath='{.status.containerStatuses[0].ready}{"\n"}'
# Expected: true

# The probe pod that was stuck Pending during the outage eventually reaches Ready:
kubectl get pod probe -n ex-1-3 \
  -o jsonpath='{.status.phase}{"\n"}'
# Expected: Running
```

---

## Level 2: Node Prerequisites and Kubelet

### Exercise 2.1

**Objective:** Confirm the three kubeadm-required kernel modules and two sysctl settings.

**Task:**

Inside the control plane node, verify the following using the expected outputs. Save the combined output of the five checks to `/tmp/ex-2-1-prereqs.txt` inside the node.

**Verification:**

```bash
nerdctl exec kind-control-plane cat /tmp/ex-2-1-prereqs.txt
# Expected output includes lines for:
# - br_netfilter (lsmod output shows the module)
# - overlay (lsmod output shows the module)
# - net.bridge.bridge-nf-call-iptables = 1
# - net.ipv4.ip_forward = 1
# - swap disabled or minimal (/proc/swaps is empty beyond the header)
```

---

### Exercise 2.2

**Objective:** Read the kubelet configuration and confirm the three kubeadm-managed settings.

**Task:**

Inside the control plane node, read `/var/lib/kubelet/config.yaml` and confirm the values of `staticPodPath`, `clusterDNS`, and `clusterDomain`. Write the three values (one per line, in that order) to `/tmp/ex-2-2-kubelet.txt`.

**Verification:**

```bash
nerdctl exec kind-control-plane cat /tmp/ex-2-2-kubelet.txt
# Expected (three lines):
# staticPodPath: /etc/kubernetes/manifests
# clusterDNS: 10.96.0.10
# clusterDomain: cluster.local
```

---

### Exercise 2.3

**Objective:** Verify cluster health end to end using a minimum probe.

**Task:**

Run the probe sequence: confirm all four nodes are Ready; confirm the four control plane static pods are Ready; confirm CoreDNS is Ready; deploy a small nginx Deployment in namespace `ex-2-3`, wait for it to be Available, perform a `kubectl exec` into the pod to confirm DNS works (`nslookup kubernetes.default`), then delete the Deployment.

**Verification:**

```bash
kubectl get nodes -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' \
  | sort | uniq -c
# Expected: one line showing "4 True" (all four nodes Ready).

kubectl get pods -n kube-system \
  -l tier=control-plane -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' \
  | sort | uniq -c
# Expected: "4 true" (all four control plane pods Ready).

kubectl get pods -n kube-system -l k8s-app=kube-dns \
  -o jsonpath='{.items[0].status.containerStatuses[0].ready}{"\n"}'
# Expected: true

kubectl run nslook -n ex-2-3 --rm -it --restart=Never --image=busybox:1.36 \
  -- nslookup kubernetes.default
# Expected: an Address line for the kubernetes Service (usually 10.96.0.1).
```

---

## Level 3: Debugging Cluster Issues

### Exercise 3.1

**Objective:** Recover a cordoned worker node so it can schedule new pods again.

**Setup:**

```bash
kubectl cordon kind-worker
```

**Task:**

After the setup, the node `kind-worker` is marked unschedulable. Confirm this via `kubectl get nodes`, then uncordon the node so it can schedule pods again. Create a Deployment in `ex-3-1` with a pod affinity to `kind-worker` and confirm the pod is scheduled there.

**Verification:**

```bash
kubectl get node kind-worker \
  -o jsonpath='{.spec.unschedulable}{"\n"}'
# Expected: an empty string or "false" (node is no longer cordoned).

kubectl run pin-to-worker -n ex-3-1 \
  --image=nginx:1.27 --restart=Never \
  --overrides='{"spec":{"nodeName":"kind-worker"}}'
kubectl wait --for=condition=Ready pod/pin-to-worker -n ex-3-1 --timeout=60s
# Expected: pod/pin-to-worker condition met
kubectl delete pod pin-to-worker -n ex-3-1
```

---

### Exercise 3.2

**Objective:** Recover a worker node whose kubelet has been stopped.

**Setup:**

```bash
nerdctl exec kind-worker systemctl stop kubelet
sleep 45
```

**Task:**

After the setup, `kind-worker` is NotReady because its kubelet is stopped. Confirm the NotReady status, restart kubelet inside the worker, and wait for the node to return to Ready.

**Verification:**

```bash
# Wait for the Ready condition after restarting kubelet:
kubectl wait --for=condition=Ready node/kind-worker --timeout=120s

kubectl get node kind-worker \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}{"\n"}'
# Expected: True

nerdctl exec kind-worker systemctl is-active kubelet
# Expected: active
```

---

### Exercise 3.3

**Objective:** Verify CNI is functional by testing pod-to-pod cross-node connectivity.

**Task:**

Create two pods in namespace `ex-3-3`: one pinned to `kind-worker` and one pinned to `kind-worker2`. From the first pod, ping the second pod's IP. Delete both pods on success.

**Verification:**

```bash
# Pod-to-pod connectivity across nodes (the essence of a working CNI):
SECOND_IP=$(kubectl get pod connectivity-b -n ex-3-3 \
  -o jsonpath='{.status.podIP}')
kubectl exec connectivity-a -n ex-3-3 -- ping -c 2 $SECOND_IP
# Expected: "2 packets transmitted, 2 received" or similar success output.

kubectl delete pod connectivity-a connectivity-b -n ex-3-3
```

---

## Level 4: kubeadm Configuration and Tokens

### Exercise 4.1

**Objective:** Produce the current cluster's ClusterConfiguration and use it to verify the pod and service CIDR.

**Task:**

Inside the control plane node, read the `kubeadm-config` ConfigMap in `kube-system` and extract the `ClusterConfiguration` YAML to `/tmp/ex-4-1-cluster-config.yaml` inside the node. Confirm the pod CIDR and service CIDR values are present in that file.

**Verification:**

```bash
nerdctl exec kind-control-plane test -f /tmp/ex-4-1-cluster-config.yaml
# Expected: exit 0 (file exists).

nerdctl exec kind-control-plane grep -E 'podSubnet|serviceSubnet' /tmp/ex-4-1-cluster-config.yaml
# Expected: two lines, one with podSubnet: and one with serviceSubnet:, each with
# a CIDR value (the exact values depend on the kind cluster's networking config).
```

---

### Exercise 4.2

**Objective:** Create a new bootstrap token, inspect it, and delete it.

**Task:**

Inside the control plane node, create a new bootstrap token using `kubeadm token create`, capture the token ID from the output, inspect the token's Secret in `kube-system`, and then delete the token with `kubeadm token delete`. Write the token ID to `/tmp/ex-4-2-token-id.txt`.

**Verification:**

```bash
nerdctl exec kind-control-plane cat /tmp/ex-4-2-token-id.txt
# Expected: a line with a 6-character token ID (the part before the colon in the
# full token string abcdef.0123456789abcdef).

# After deletion, the token is gone:
TOKEN_ID=$(nerdctl exec kind-control-plane cat /tmp/ex-4-2-token-id.txt)
nerdctl exec kind-control-plane kubeadm token list | grep -c "$TOKEN_ID" || true
# Expected: 0 (no matching line; the token was deleted).
```

---

### Exercise 4.3

**Objective:** Use `kubeadm config print` to generate a sample init configuration you could use on a new cluster.

**Task:**

Inside the control plane node, use `kubeadm config print init-defaults` to generate a default ClusterConfiguration. Save the output to `/tmp/ex-4-3-init.yaml` inside the node. Then modify that file in place to set `kubernetesVersion: v1.35.0` and `networking.podSubnet: 10.244.0.0/16`.

**Verification:**

```bash
nerdctl exec kind-control-plane test -f /tmp/ex-4-3-init.yaml
# Expected: exit 0.

nerdctl exec kind-control-plane grep 'kubernetesVersion:' /tmp/ex-4-3-init.yaml
# Expected: a line ending in v1.35.0

nerdctl exec kind-control-plane grep 'podSubnet:' /tmp/ex-4-3-init.yaml
# Expected: a line ending in 10.244.0.0/16
```

---

## Level 5: Complex Scenarios

### Exercise 5.1

**Objective:** Audit every certificate under `/etc/kubernetes/pki/` and confirm each one verifies against its correct CA.

**Task:**

Inside the control plane node, run `openssl verify` for each non-CA leaf certificate (`apiserver.crt`, `apiserver-kubelet-client.crt`, `apiserver-etcd-client.crt`, `front-proxy-client.crt`, `etcd/healthcheck-client.crt`, `etcd/peer.crt`, `etcd/server.crt`) against the correct CA (`ca.crt` for the first two, `etcd/ca.crt` for the etcd certs, `front-proxy-ca.crt` for the front-proxy client). Save all seven verifications to `/tmp/ex-5-1-audit.txt`.

**Verification:**

```bash
nerdctl exec kind-control-plane cat /tmp/ex-5-1-audit.txt
# Expected: seven lines, each ending in ": OK".

nerdctl exec kind-control-plane grep -c ": OK$" /tmp/ex-5-1-audit.txt
# Expected: 7
```

---

### Exercise 5.2

**Objective:** Renew a specific certificate and prove the new expiration is later than the old one.

**Task:**

Inside the control plane node, capture the current expiration of `apiserver-kubelet-client.crt` (via `openssl x509 -enddate`) to `/tmp/ex-5-2-before.txt`. Run `kubeadm certs renew apiserver-kubelet-client`. Capture the new expiration to `/tmp/ex-5-2-after.txt`. Restart the API server (touch its manifest) so the new cert is in service.

**Verification:**

```bash
nerdctl exec kind-control-plane bash -c '
  BEFORE=$(cat /tmp/ex-5-2-before.txt | cut -d= -f2)
  AFTER=$(cat /tmp/ex-5-2-after.txt | cut -d= -f2)
  echo "Before: $BEFORE"
  echo "After:  $AFTER"
'
# Expected: the After date is later than the Before date.

kubectl get nodes
# Expected: four nodes Ready (confirming kubectl still works after the API server restart).
```

---

### Exercise 5.3

**Objective:** Produce a cluster-state snapshot file suitable for operator handoff.

**Task:**

Build a small shell pipeline that writes a single text file at `/tmp/ex-5-3-snapshot.txt` containing the following sections, each separated by a header line of `==== <section> ====`:

1. Kubernetes version (`kubectl version`).
2. Node list with roles and versions (`kubectl get nodes -o wide`).
3. All kube-system pods with status (`kubectl get pods -n kube-system`).
4. Certificate expirations (`nerdctl exec kind-control-plane kubeadm certs check-expiration`).
5. Cluster CIDR from kubeadm-config (the `podSubnet` and `serviceSubnet` lines from Exercise 4.1's output).

**Verification:**

```bash
test -f /tmp/ex-5-3-snapshot.txt
# Expected: exit 0.

wc -l /tmp/ex-5-3-snapshot.txt
# Expected: at least 30 lines.

grep -c '^==== ' /tmp/ex-5-3-snapshot.txt
# Expected: 5 (five section headers).

for section in 'Kubernetes version' 'Node list' 'kube-system pods' 'Certificate' 'CIDR'; do
  grep -c "$section" /tmp/ex-5-3-snapshot.txt
done
# Expected: each grep returns at least 1.
```

---

## Cleanup

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 \
          ex-2-1 ex-2-2 ex-2-3 \
          ex-3-1 ex-3-2 ex-3-3 \
          ex-4-1 ex-4-2 ex-4-3 \
          ex-5-1 ex-5-2 ex-5-3; do
  kubectl delete namespace $ns --ignore-not-found
done

# Remove temp files from the control plane node:
nerdctl exec kind-control-plane bash -c 'rm -f /tmp/ex-*.txt /tmp/ex-*.yaml'
rm -f /tmp/ex-5-3-snapshot.txt
```

---

## Key Takeaways

Kubeadm places a small set of artifacts on disk in predictable locations: static pod manifests in `/etc/kubernetes/manifests/`, certificates and kubeconfig files in `/etc/kubernetes/pki/` and `/etc/kubernetes/*.conf`, and a kubeadm configuration ConfigMap in `kube-system`. Every lifecycle operation (node join, certificate renewal, config upgrade) reduces to editing or inspecting one of those artifacts, and every kubeadm subcommand (`kubeadm certs check-expiration`, `kubeadm certs renew`, `kubeadm token create`, `kubeadm config print`) targets one of them. Kind abstracts the installation step (the operator never runs `kubeadm init` on kind because kind does it on the image), but every on-disk artifact is the same shape as on a bare-metal kubeadm cluster.

Kubelet is the static-pod supervisor. Touching a manifest causes kubelet to reconcile within a few seconds; removing a manifest causes kubelet to stop the pod cleanly; restoring the manifest causes kubelet to recreate it. Stopping kubelet itself (via `systemctl stop kubelet` inside the node) causes the node to go `NotReady` as the API server stops receiving heartbeats, and restarting kubelet returns the node to Ready within a node-status update cycle. These patterns are the essence of kubeadm-managed cluster life.

Certificates in a kubeadm cluster fall into three CA chains: the cluster CA (`ca.crt`) signs most client certs and the API server cert; the etcd CA (`etcd/ca.crt`) signs etcd client and server certs; the front-proxy CA signs the front-proxy client cert. `openssl verify -CAfile <ca> <cert>` is the authoritative chain check, and `kubeadm certs check-expiration` summarizes all ten managed entries (seven bare certs plus three kubeconfigs) with their expiration dates and signing CAs. `kubeadm certs renew <name>` regenerates a single cert on disk; restarting the consuming static pod (by touching its manifest) puts the new cert into service.

The health-check playbook for any kubeadm cluster condenses to four commands: `kubectl get nodes`, `kubectl get pods -n kube-system`, `kubeadm certs check-expiration`, and `kubeadm token list`. Running them in that order confirms node Ready status, control plane pod health, certificate freshness, and bootstrap token availability. The same commands apply on bare metal, VMs, and kind equally, which is why kind is an adequate practice environment for this topic even though the `kubeadm init` flow itself is abstracted away.
