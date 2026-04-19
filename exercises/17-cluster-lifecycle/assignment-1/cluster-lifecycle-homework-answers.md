# Cluster Lifecycle Homework Answers

Complete solutions for all 15 exercises. Levels 1, 2, 4, and 5 are build-or-inspect tasks; Level 3 exercises are debugging and follow the three-stage structure (Diagnosis, What the bug is and why, Fix).

---

## Exercise 1.1 Solution

```bash
BEFORE=$(kubectl get pod kube-scheduler-kind-control-plane -n kube-system \
  -o jsonpath='{.metadata.creationTimestamp}')
echo "Before: $BEFORE"

nerdctl exec kind-control-plane touch /etc/kubernetes/manifests/kube-scheduler.yaml
sleep 15

AFTER=$(kubectl get pod kube-scheduler-kind-control-plane -n kube-system \
  -o jsonpath='{.metadata.creationTimestamp}')
echo "After: $AFTER"
```

Kubelet reconciles static pod manifests every few seconds. `touch` on the manifest file updates its mtime; kubelet notices the change, stops the existing pod, and starts a fresh one from the unchanged manifest content. The `creationTimestamp` on the new pod reflects the new creation, so the Before/After comparison proves the reconciliation fired.

---

## Exercise 1.2 Solution

```bash
nerdctl exec kind-control-plane bash -c '
  {
    openssl verify -CAfile /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/apiserver.crt
    openssl verify -CAfile /etc/kubernetes/pki/etcd/ca.crt /etc/kubernetes/pki/apiserver-etcd-client.crt
    openssl verify -CAfile /etc/kubernetes/pki/front-proxy-ca.crt /etc/kubernetes/pki/front-proxy-client.crt
  } > /tmp/ex-1-2-verify.txt
'
```

Each certificate must be verified against the CA that signed it. The cluster CA (`ca.crt`) signs most client and server certs; the etcd CA signs etcd-related client certs; the front-proxy CA signs the aggregation-layer client cert. The `CERTIFICATE AUTHORITY` column in `kubeadm certs check-expiration`'s output is the authoritative mapping for every kubeadm-managed cert.

---

## Exercise 1.3 Solution

```bash
# Back up and remove the scheduler manifest:
nerdctl exec kind-control-plane bash -c '
  cp /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/ex-1-3-sched.yaml.bak
  rm /etc/kubernetes/manifests/kube-scheduler.yaml
'

# Create a probe pod while the scheduler is down:
kubectl run probe -n ex-1-3 --image=nginx:1.27 --restart=Never
# The probe stays Pending because the scheduler is absent.

# Restore the manifest:
nerdctl exec kind-control-plane \
  cp /tmp/ex-1-3-sched.yaml.bak /etc/kubernetes/manifests/kube-scheduler.yaml

kubectl wait --for=condition=Ready pod/probe -n ex-1-3 --timeout=60s
```

Kubelet stops a static pod when its manifest file disappears from the watched directory; restoring the file causes the pod to be recreated. While the scheduler is down, no pending pod can be assigned to a node; as soon as the scheduler returns, the backlog drains.

---

## Exercise 2.1 Solution

```bash
nerdctl exec kind-control-plane bash -c '
  {
    echo "=== br_netfilter ==="
    lsmod | grep ^br_netfilter
    echo "=== overlay ==="
    lsmod | grep ^overlay
    echo "=== net.bridge.bridge-nf-call-iptables ==="
    sysctl net.bridge.bridge-nf-call-iptables
    echo "=== net.ipv4.ip_forward ==="
    sysctl net.ipv4.ip_forward
    echo "=== swap ==="
    cat /proc/swaps
  } > /tmp/ex-2-1-prereqs.txt
'
```

kubeadm preflight checks require the two kernel modules (`br_netfilter` for iptables-based bridge traffic rules, `overlay` for overlayfs layered storage) and two sysctl settings (both set to `1`). On kind, these are pre-configured by the node image; on bare metal they must be explicitly loaded and set at kubelet startup. Swap must also be off; if `/proc/swaps` shows entries, kubelet will refuse to start unless overridden.

---

## Exercise 2.2 Solution

```bash
nerdctl exec kind-control-plane bash -c '
  STATIC_POD=$(grep -E "^staticPodPath:" /var/lib/kubelet/config.yaml)
  CLUSTER_DNS=$(grep -A1 "^clusterDNS:" /var/lib/kubelet/config.yaml | tail -1 | sed "s|^- ||" | sed "s|^|clusterDNS: |")
  CLUSTER_DOMAIN=$(grep -E "^clusterDomain:" /var/lib/kubelet/config.yaml)
  {
    echo "$STATIC_POD"
    echo "$CLUSTER_DNS"
    echo "$CLUSTER_DOMAIN"
  } > /tmp/ex-2-2-kubelet.txt
'
```

The kubelet's config file carries every setting kubelet uses after kubeadm init. The `staticPodPath` points at `/etc/kubernetes/manifests`, which is the directory kubelet watches for static pod manifests. `clusterDNS` is the service IP of the cluster DNS (CoreDNS), which pods inherit for their DNS resolver configuration. `clusterDomain` is the DNS suffix pods use to resolve Service names.

---

## Exercise 2.3 Solution

The probe sequence is the verification block itself. No additional commands are needed; each check reports the state of one cluster subsystem. The design of the probe mirrors the "smoke test" operators run after a cluster upgrade: nodes Ready, control plane Ready, DNS Ready, workload Ready, DNS actually serving queries.

---

## Exercise 3.1 Solution

### Diagnosis

Check node status:

```bash
kubectl get nodes
```

Expected: `kind-worker` shows `SchedulingDisabled` in the STATUS column.

Inspect the node's taints (which `kubectl cordon` adds automatically):

```bash
kubectl describe node kind-worker | grep -A2 Taints:
```

Expected: a taint `node.kubernetes.io/unschedulable:NoSchedule`.

### What the bug is and why it happens

`kubectl cordon` adds the `node.kubernetes.io/unschedulable:NoSchedule` taint to the node; the scheduler refuses to place new pods on nodes carrying that taint unless a pod's toleration explicitly permits it. Existing pods on the node are not evicted (that would require `kubectl drain`), but no new pods are scheduled.

### Fix

Uncordon the node:

```bash
kubectl uncordon kind-worker
```

The taint is removed; the scheduler resumes placing pods on the node. `kubectl cordon` and `kubectl uncordon` are the standard workflow for draining a node safely before maintenance and returning it to service afterward.

---

## Exercise 3.2 Solution

### Diagnosis

Check node status:

```bash
kubectl get nodes
```

Expected: `kind-worker` shows `NotReady`.

Describe the node to see why:

```bash
kubectl describe node kind-worker | grep -A2 Conditions:
```

Expected: the `Ready` condition is `False`, with a message indicating kubelet has not posted a status update recently.

Verify kubelet's state directly:

```bash
nerdctl exec kind-worker systemctl is-active kubelet
```

Expected: `inactive`.

### What the bug is and why it happens

Node Ready status is driven by kubelet posting periodic heartbeats to the API server. When kubelet is stopped, the API server's node controller waits for the lease to expire (default 40 seconds) and then marks the node `NotReady`. Existing pods on the node are eventually evicted by the pod GC controller, but pods without graceful shutdown handlers continue to run inside the node until something else removes them.

### Fix

Restart kubelet:

```bash
nerdctl exec kind-worker systemctl start kubelet

kubectl wait --for=condition=Ready node/kind-worker --timeout=120s
```

The node returns to Ready within a heartbeat cycle after kubelet is back.

---

## Exercise 3.3 Solution

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: connectivity-a
  namespace: ex-3-3
spec:
  nodeSelector:
    kubernetes.io/hostname: kind-worker
  containers:
    - name: probe
      image: busybox:1.36
      command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: connectivity-b
  namespace: ex-3-3
spec:
  nodeSelector:
    kubernetes.io/hostname: kind-worker2
  containers:
    - name: probe
      image: busybox:1.36
      command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/connectivity-a -n ex-3-3 --timeout=60s
kubectl wait --for=condition=Ready pod/connectivity-b -n ex-3-3 --timeout=60s
```

The essence of a working CNI is the ability for pods on different nodes to reach each other over the pod network. This exercise pins two pods to different workers and probes connectivity between them; a successful ping confirms the CNI (kindnet or Calico, depending on cluster setup) is installed, each node has been provisioned with pod IPs from its allocated pod CIDR, and the routing between nodes is working.

---

## Exercise 4.1 Solution

```bash
nerdctl exec kind-control-plane bash -c '
  kubectl get configmap -n kube-system kubeadm-config \
    -o jsonpath="{.data.ClusterConfiguration}" > /tmp/ex-4-1-cluster-config.yaml
'
```

The `kubeadm-config` ConfigMap stores the cluster's effective `ClusterConfiguration` as a YAML blob in the `data.ClusterConfiguration` key. Extracting it as a file yields the exact configuration kubeadm would consume if asked to upgrade or re-init the cluster. The `networking.podSubnet` and `networking.serviceSubnet` values in this file are the cluster's pod and service CIDRs.

---

## Exercise 4.2 Solution

```bash
nerdctl exec kind-control-plane bash -c '
  NEW_TOKEN=$(kubeadm token create)
  echo "Generated: $NEW_TOKEN"
  TOKEN_ID=$(echo "$NEW_TOKEN" | cut -d. -f1)
  echo "$TOKEN_ID" > /tmp/ex-4-2-token-id.txt

  # Inspect the token secret:
  kubectl get secret -n kube-system bootstrap-token-$TOKEN_ID -o yaml | head -20

  # Delete the token:
  kubeadm token delete "$TOKEN_ID"
'
```

`kubeadm token create` produces a bootstrap token of the form `abcdef.0123456789abcdef`: a six-character ID followed by a sixteen-character secret. The token's backing Secret lives at `bootstrap-token-<id>` in `kube-system` and contains the token ID, the token secret (base64-encoded), an expiration time, and a list of usages (`authentication` and `signing` by default). `kubeadm token delete` removes the Secret, which immediately invalidates the token.

---

## Exercise 4.3 Solution

```bash
nerdctl exec kind-control-plane bash -c '
  kubeadm config print init-defaults > /tmp/ex-4-3-init.yaml

  # Set the Kubernetes version:
  sed -i "s|^kubernetesVersion:.*|kubernetesVersion: v1.35.0|" /tmp/ex-4-3-init.yaml

  # Set the pod subnet (add the line under networking: if it is missing):
  if grep -q "podSubnet:" /tmp/ex-4-3-init.yaml; then
    sed -i "s|podSubnet:.*|podSubnet: 10.244.0.0/16|" /tmp/ex-4-3-init.yaml
  else
    sed -i "/^networking:/a\\  podSubnet: 10.244.0.0/16" /tmp/ex-4-3-init.yaml
  fi
'
```

`kubeadm config print init-defaults` produces a fully commented starting-point configuration for a new cluster. The operator customizes `kubernetesVersion` to pin the control plane to a specific release, and `networking.podSubnet` (along with `networking.serviceSubnet`) to configure the cluster's CIDRs. The resulting file is what you would pass to `kubeadm init --config=/tmp/ex-4-3-init.yaml` on a real bare-metal control plane node.

---

## Exercise 5.1 Solution

```bash
nerdctl exec kind-control-plane bash -c '
  {
    openssl verify -CAfile /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/apiserver.crt
    openssl verify -CAfile /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/apiserver-kubelet-client.crt
    openssl verify -CAfile /etc/kubernetes/pki/etcd/ca.crt /etc/kubernetes/pki/apiserver-etcd-client.crt
    openssl verify -CAfile /etc/kubernetes/pki/front-proxy-ca.crt /etc/kubernetes/pki/front-proxy-client.crt
    openssl verify -CAfile /etc/kubernetes/pki/etcd/ca.crt /etc/kubernetes/pki/etcd/healthcheck-client.crt
    openssl verify -CAfile /etc/kubernetes/pki/etcd/ca.crt /etc/kubernetes/pki/etcd/peer.crt
    openssl verify -CAfile /etc/kubernetes/pki/etcd/ca.crt /etc/kubernetes/pki/etcd/server.crt
  } > /tmp/ex-5-1-audit.txt
'
```

Seven non-CA leaf certs, each verified against the CA that signed it, produces seven `: OK` lines. Any other outcome signals a broken PKI chain and warrants immediate investigation before the next control plane restart.

---

## Exercise 5.2 Solution

```bash
nerdctl exec kind-control-plane bash -c '
  openssl x509 -in /etc/kubernetes/pki/apiserver-kubelet-client.crt -noout -enddate \
    > /tmp/ex-5-2-before.txt

  kubeadm certs renew apiserver-kubelet-client

  openssl x509 -in /etc/kubernetes/pki/apiserver-kubelet-client.crt -noout -enddate \
    > /tmp/ex-5-2-after.txt

  touch /etc/kubernetes/manifests/kube-apiserver.yaml
'

sleep 15
kubectl get nodes
```

`kubeadm certs renew <name>` regenerates the certificate on disk with a new serial number and a fresh one-year validity. The API server continues to hold its old in-memory cert until the pod restarts; touching the manifest triggers kubelet to recreate the pod, which then loads the new cert from disk. The verification's Before/After comparison proves the file on disk changed; the final `kubectl get nodes` proves the API server came back after the restart.

---

## Exercise 5.3 Solution

```bash
{
  echo "==== Kubernetes version ===="
  kubectl version 2>/dev/null

  echo ""
  echo "==== Node list ===="
  kubectl get nodes -o wide

  echo ""
  echo "==== kube-system pods ===="
  kubectl get pods -n kube-system

  echo ""
  echo "==== Certificate expirations ===="
  nerdctl exec kind-control-plane kubeadm certs check-expiration

  echo ""
  echo "==== CIDR (pod and service) ===="
  nerdctl exec kind-control-plane bash -c '
    kubectl get configmap -n kube-system kubeadm-config \
      -o jsonpath="{.data.ClusterConfiguration}" \
    | grep -E "podSubnet|serviceSubnet"
  '
} > /tmp/ex-5-3-snapshot.txt
```

The snapshot combines five sources into one file: the API version from `kubectl version`, the node inventory from `kubectl get nodes -o wide` (which includes roles, internal IPs, and kubelet versions), the control-plane-and-CoreDNS pod list, the certificate expiration summary, and the pod-and-service CIDR configuration. The combined file is a one-shot handoff artifact an on-call engineer can drop into a ticket or a shared document when a cluster changes hands.

---

## Common Mistakes

Confusing `kubectl cordon` with `kubectl drain`. Cordon only adds a taint that prevents new pods from being scheduled; existing pods keep running. Drain adds the taint and then evicts every eligible pod so the node can be stopped for maintenance. The two are the first and second steps of a node-maintenance workflow, not substitutes for each other.

Forgetting to restart a static pod after renewing its certificate. `kubeadm certs renew` writes the new cert to disk but does not touch the running container; the running process keeps using the old in-memory cert until something forces a restart. `touch /etc/kubernetes/manifests/<component>.yaml` is the canonical minimum-disruption trigger.

Running `kubeadm init` on kind. Kind's node image has already been initialized as a control plane during image build; `kubeadm init` inside a kind node container would fail in confusing ways. Kind supports kubeadm's inspection and lifecycle commands (`kubeadm certs`, `kubeadm token`, `kubeadm config print`) but not its installation commands.

Expecting `kubectl describe node` to show kubelet service logs. The `Conditions` block reports the node's high-level Ready/MemoryPressure/DiskPressure state as seen by the API server, which reflects kubelet's heartbeats but not kubelet's internal logs. For kubelet logs, exec into the node and run `journalctl -u kubelet`.

Treating the `kubeadm-config` ConfigMap as read-only. It is editable in principle; an operator can update it to prepare for a kubeadm upgrade, and kubeadm reads it during subsequent operations. Incorrect manual edits are a frequent source of trouble during cluster upgrades, which is why the common practice is to always regenerate the ConfigMap from a well-known input file rather than edit in place.

---

## Verification Commands Cheat Sheet

```bash
# Static pod reconciliation
nerdctl exec kind-control-plane touch /etc/kubernetes/manifests/<file>
nerdctl exec kind-control-plane ls /etc/kubernetes/manifests/

# Certificate verification and renewal
nerdctl exec kind-control-plane kubeadm certs check-expiration
nerdctl exec kind-control-plane kubeadm certs renew <name>
nerdctl exec kind-control-plane openssl verify -CAfile <ca.crt> <leaf.crt>

# Token management
nerdctl exec kind-control-plane kubeadm token list
nerdctl exec kind-control-plane kubeadm token create
nerdctl exec kind-control-plane kubeadm token delete <id>

# Kubelet health
nerdctl exec kind-control-plane systemctl is-active kubelet
nerdctl exec kind-worker systemctl start kubelet
nerdctl exec <node> journalctl -u kubelet -n 50

# Node health
kubectl get nodes
kubectl describe node <name>
kubectl cordon <name>
kubectl uncordon <name>
kubectl drain <name> --ignore-daemonsets

# Cluster-wide state
kubectl get configmap -n kube-system kubeadm-config -o jsonpath='{.data.ClusterConfiguration}'
kubeadm config print init-defaults
```

The five-minute cluster health check: `kubectl get nodes`, `kubectl get pods -n kube-system`, `kubeadm certs check-expiration`, `kubeadm token list`, and a test pod rollout. Each command answers one specific question about one cluster subsystem. Running them in that order is the operator's standard sweep after any cluster change.
