# Control Plane Troubleshooting Tutorial

Assignment 1 covered application-layer troubleshooting: pod failure states, logs, events, resource exhaustion, configuration mistakes visible from kubectl. This tutorial picks up where that one left off and teaches the diagnostic loops you reach for when the thing that is broken is the cluster itself. The core skill is switching between four views of the same system: the kubectl view (control plane pods in `kube-system`), the inside-the-node view (`crictl`, `journalctl`, raw log files in `/var/log`), the manifest view (the YAML files in `/etc/kubernetes/manifests/` that kubelet reconciles), and the certificate view (the PKI files in `/etc/kubernetes/pki/` plus the kubeadm-managed kubeconfigs).

Kind makes all four views reachable from a single command. A kind "node" is a container named `kind-control-plane` that runs containerd, kubelet as a systemd service, and the four control plane components as static pods. Entering that container with `nerdctl exec -it kind-control-plane bash` gives you the exact tools you would use on a real kubeadm node: `crictl` for container-level operations, `systemctl` and `journalctl` for the kubelet service, and direct filesystem access to `/etc/kubernetes/`. The only real difference from a bare-metal cluster is that kind does not model many nodes as many boxes; you still reach the control plane by the same workflow.

The tutorial uses a namespace called `tutorial-troubleshooting` for the few cases where a test workload makes the symptom observable (for example, pods stuck in `Pending` because the scheduler is down). Everything else operates on the control plane itself.

## Prerequisites

A multi-node kind cluster created per `docs/cluster-setup.md#multi-node-kind-cluster`. Verify:

```bash
kubectl config current-context          # expect: kind-kind
kubectl get nodes                       # expect: 4 nodes, all Ready
```

Verify access to the control plane container:

```bash
nerdctl ps | grep kind-control-plane
```

Expected: one container named `kind-control-plane` in `Up` status. If your cluster uses the Docker provider instead of nerdctl, substitute `docker ps` and `docker exec` in every command below.

Create the tutorial namespace:

```bash
kubectl create namespace tutorial-troubleshooting
```

## Step 1: The Control Plane from the Outside

Every kubeadm cluster runs four control plane components as static pods: `kube-apiserver`, `kube-scheduler`, `kube-controller-manager`, and `etcd`. Static pods are managed by kubelet directly rather than by a controller, which means they do not appear in Deployments or ReplicaSets, they cannot be created through the API, and deleting their pod resource via kubectl does not actually remove them (kubelet recreates them from the on-disk manifest within seconds).

See them through the kubectl view:

```bash
kubectl get pods -n kube-system
```

Expected: rows for `kube-apiserver-kind-control-plane`, `kube-scheduler-kind-control-plane`, `kube-controller-manager-kind-control-plane`, and `etcd-kind-control-plane`, all in `Running` status with `1/1` Ready. Other pods (CoreDNS, `kube-proxy`, `kindnet` or Calico pods) are also listed; focus on the four control plane names.

The pod-name suffix is the node name. In a single-control-plane cluster that suffix is always the node. In an HA cluster you would see three of each (one per control plane node).

Pull control plane component logs through kubectl:

```bash
kubectl logs -n kube-system kube-apiserver-kind-control-plane --tail=20
kubectl logs -n kube-system kube-scheduler-kind-control-plane --tail=20
kubectl logs -n kube-system kube-controller-manager-kind-control-plane --tail=20
kubectl logs -n kube-system etcd-kind-control-plane --tail=20
```

Expected: recent log lines from each component. Normal startup signals to look for:

- `kube-apiserver`: lines containing `Serving securely on [::]:6443` and `Ready` checks.
- `kube-scheduler`: lines containing `Leader election succeeded` or `Starting Kubernetes Scheduler`.
- `kube-controller-manager`: lines containing `Started` for each controller (deployment, replicaset, node, service-account, and others).
- `etcd`: lines containing `ready to serve client requests` or `serving client traffic`.

The kubectl view is enough for most diagnostic work. It falls short only when the API server itself is down (in which case kubectl has nothing to talk to) or when a component is restarting so quickly that its pod log is empty by the time you look.

## Step 2: The Control Plane from Inside the Node

When kubectl is not available, use the inside-the-node view. Enter the control plane container:

```bash
nerdctl exec -it kind-control-plane bash
```

You are now at a bash prompt inside the kind node. The tools you need are:

```bash
crictl version
systemctl status kubelet
ls /etc/kubernetes/manifests/
```

Expected from `crictl version`: the `runtimeapi` and `runtimeVersion` fields populated (kind ships `containerd` as the runtime). Expected from `systemctl status kubelet`: active (running) state. Expected from the `ls` on manifests: `etcd.yaml`, `kube-apiserver.yaml`, `kube-controller-manager.yaml`, `kube-scheduler.yaml`.

List running control plane containers from the container runtime directly:

```bash
crictl ps
```

Expected: rows for the four control plane components plus `kube-proxy` and `coredns` if they happen to run here. The container IDs are 12-hex-character truncations; you use the full ID or a unique prefix with the other `crictl` commands.

Fetch a container's log through the runtime (this works when kubectl does not):

```bash
crictl logs $(crictl ps --name kube-apiserver -q)
```

The `--name` filter limits by container name, `-q` prints only the IDs. Wrap with `$( ... )` to pass the ID directly to `crictl logs`.

Inspect a container for its full specification:

```bash
crictl inspect $(crictl ps --name kube-apiserver -q) | head -80
```

The output is equivalent to `kubectl get pod ... -o yaml` combined with `kubectl describe pod ...` for a single container: it shows the command-line arguments, the mounts, the environment, and the status.

View kubelet's systemd journal:

```bash
journalctl -u kubelet --no-pager -n 30
```

Expected: recent kubelet log lines. Kubelet is the static-pod supervisor; when a static pod manifest is malformed, kubelet logs the parse error here. When a pod fails to start, kubelet logs why. This is the log to read first when a static pod is missing from `crictl ps` and you do not know why.

Exit the node container:

```bash
exit
```

These inside-the-node commands are the fallback that takes over when kubectl cannot reach the API server.

## Step 3: The Manifest Edit Cycle

Static pod manifests in `/etc/kubernetes/manifests/` are the source of truth for the control plane pods. Kubelet watches the directory and reconciles changes every few seconds: if you edit a manifest, kubelet stops the current pod, starts a new one from the updated manifest, and writes any relevant event to `journalctl -u kubelet`. If the updated manifest is invalid (YAML parse error, missing required field, unknown flag), kubelet logs the error and refuses to start the pod, leaving the old pod alive only if kubelet has not yet stopped it.

Enter the node and look at the scheduler manifest:

```bash
nerdctl exec -it kind-control-plane bash
cat /etc/kubernetes/manifests/kube-scheduler.yaml
```

You will see a standard pod spec with `apiVersion: v1`, `kind: Pod`, `metadata.name: kube-scheduler`, a single container with the `kube-scheduler` image, command-line flags, and `hostNetwork: true`. The `spec.containers[0].command` is a list starting with `kube-scheduler` followed by flags; `spec.containers[0].image` is the pinned version (for example, `registry.k8s.io/kube-scheduler:v1.35.0`).

Practice the edit cycle by adding a benign annotation to the manifest. This triggers kubelet to restart the pod without changing behavior:

```bash
touch /etc/kubernetes/manifests/kube-scheduler.yaml
```

The `touch` updates the file modification time. Kubelet notices within a few seconds, stops the current scheduler pod, and starts a fresh one. Verify by watching the Age column:

```bash
kubectl get pod -n kube-system kube-scheduler-kind-control-plane
```

Expected: the Age column resets to a few seconds. If it did not reset, wait another 10 seconds; kubelet's reconcile interval varies slightly.

To apply a real edit, open the manifest with `vi`:

```bash
vi /etc/kubernetes/manifests/kube-scheduler.yaml
```

Within the file you can change the container image tag, add or remove a command-line flag, adjust a `resources.requests` block, and so on. Save and exit; kubelet reconciles within a few seconds. If the edit is invalid, the pod does not come back; check `journalctl -u kubelet --no-pager -n 30` for the error.

The edit cycle is: read the manifest, make a change, save, wait a few seconds, verify the pod is back via `crictl ps` or `kubectl get pod`. Every exercise in this assignment that modifies the control plane uses this cycle.

Exit the node:

```bash
exit
```

Manifest spec fields to internalize for the homework:

`spec.containers[0].command`. The list starts with the component binary and is followed by its flags, one token per list entry. Default when omitted: the image's ENTRYPOINT takes over, which is usually not what you want for kubeadm-managed components. Failure mode when a flag is wrong: the pod starts, the binary fails with a usage error, and the container enters CrashLoopBackOff; the full error is visible with `crictl logs <id>` or `kubectl logs`.

`spec.containers[0].image`. Pinned version of the control plane image. Default when omitted: the pod fails to validate (image is required). Failure mode when the tag does not exist: `ErrImagePull` / `ImagePullBackOff` on the pod; crictl logs are empty because the container never started.

`spec.containers[0].volumeMounts` and `spec.volumes`. Hostpath mounts for certs, kubeconfig, and etcd data. Default when misconfigured: pod starts but the binary cannot read the files it needs (certs not found, kubeconfig parse error); the specific error is in the component logs. Failure mode when the hostpath source does not exist: pod is in `ContainerCreating` and the Events list shows `FailedMount`.

`spec.hostNetwork: true`. Always true for control plane components; they need access to host ports (6443 for the API server, 2379/2380 for etcd). Default when omitted: the pod gets cluster-network IPs, the API server cannot bind to the expected port, and other components cannot reach it.

`spec.priorityClassName: system-node-critical`. Ensures kubelet does not evict the pod under resource pressure. Default when omitted: the pod runs at normal priority and can be evicted.

## Step 4: Deliberately Break the Scheduler and Recover It

Walk through a full scheduler failure to exercise the inside-the-node loop. Enter the node:

```bash
nerdctl exec -it kind-control-plane bash
```

Back up the scheduler manifest (so you can restore it cleanly), then remove it from the manifest directory:

```bash
cp /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/kube-scheduler.yaml.bak
rm /etc/kubernetes/manifests/kube-scheduler.yaml
```

Wait a few seconds for kubelet to reconcile, then verify the scheduler is gone from the kubectl view:

```bash
kubectl get pods -n kube-system | grep scheduler || echo "scheduler absent"
```

Expected output includes `scheduler absent`. Kubelet stops the pod when its manifest is removed; it does not log an error because removing a manifest is the documented way to deactivate a static pod.

Observe the downstream effect: pods cannot be scheduled. From outside the node, create a test pod:

```bash
exit                                            # leave the node
kubectl run probe -n tutorial-troubleshooting --image=nginx:1.27 --restart=Never
kubectl get pod probe -n tutorial-troubleshooting
```

Expected: the pod is stuck in `Pending`. Describe it:

```bash
kubectl describe pod probe -n tutorial-troubleshooting | tail -15
```

Expected: no Events from the scheduler (nothing like `Successfully assigned`); the pod has no assigned node. The symptom at the API level is "pod stuck Pending with no scheduling events," which is the classic scheduler-down signature.

Restore the scheduler by putting the manifest back:

```bash
nerdctl exec kind-control-plane \
  mv /tmp/kube-scheduler.yaml.bak /etc/kubernetes/manifests/kube-scheduler.yaml
```

Wait a few seconds and verify:

```bash
kubectl get pods -n kube-system | grep scheduler
kubectl get pod probe -n tutorial-troubleshooting
```

Expected: the scheduler pod is back in `Running`; the probe pod has moved to `Pending` → `ContainerCreating` → `Running` (may take a few more seconds). Clean up:

```bash
kubectl delete pod probe -n tutorial-troubleshooting
```

The exercise pattern (break by removing or breaking a manifest, observe the symptom, restore the manifest, verify recovery) is the core of every Level 2 and Level 3 exercise.

## Step 5: Certificate Inspection and Renewal

Kubeadm manages a set of certificates with predictable names and lifetimes. The authoritative command for checking all of them is `kubeadm certs check-expiration`. Run it from inside the control plane node:

```bash
nerdctl exec kind-control-plane kubeadm certs check-expiration
```

Expected output has two sections. The first lists the individual certificates:

```
CERTIFICATE                EXPIRES                  RESIDUAL TIME   CERTIFICATE AUTHORITY   EXTERNALLY MANAGED
admin.conf                 Apr 18, 2027 02:00 UTC   364d                                    no
apiserver                  Apr 18, 2027 02:00 UTC   364d            ca                      no
apiserver-etcd-client      Apr 18, 2027 02:00 UTC   364d            etcd-ca                 no
apiserver-kubelet-client   Apr 18, 2027 02:00 UTC   364d            ca                      no
controller-manager.conf    Apr 18, 2027 02:00 UTC   364d                                    no
etcd-healthcheck-client    Apr 18, 2027 02:00 UTC   364d            etcd-ca                 no
etcd-peer                  Apr 18, 2027 02:00 UTC   364d            etcd-ca                 no
etcd-server                Apr 18, 2027 02:00 UTC   364d            etcd-ca                 no
front-proxy-client         Apr 18, 2027 02:00 UTC   364d            front-proxy-ca          no
scheduler.conf             Apr 18, 2027 02:00 UTC   364d                                    no
```

The second section lists the CAs:

```
CERTIFICATE AUTHORITY   EXPIRES                  RESIDUAL TIME   EXTERNALLY MANAGED
ca                      Apr 16, 2036 02:00 UTC   9y              no
etcd-ca                 Apr 16, 2036 02:00 UTC   9y              no
front-proxy-ca          Apr 16, 2036 02:00 UTC   9y              no
```

Read the output format: CERTIFICATE name, EXPIRES date, RESIDUAL TIME, signing CERTIFICATE AUTHORITY, and whether the cert is EXTERNALLY MANAGED (for enterprise setups with external PKI). Kubeadm-generated certificates have a default validity of one year; CAs default to ten years.

Ten kubeadm-managed entries in total: seven client or server certificates, plus three kubeconfig files with embedded client certs:

1. `apiserver` (CA: ca). Server cert for the API server; presents to clients on port 6443.
2. `apiserver-kubelet-client` (CA: ca). Client cert the API server uses to reach kubelets.
3. `apiserver-etcd-client` (CA: etcd-ca). Client cert the API server uses to reach etcd.
4. `front-proxy-client` (CA: front-proxy-ca). Client cert for the extension API server proxy chain.
5. `etcd-healthcheck-client` (CA: etcd-ca). Client cert for etcd's health probe.
6. `etcd-peer` (CA: etcd-ca). Peer-to-peer TLS in an HA etcd cluster (still generated in single-node for consistency).
7. `etcd-server` (CA: etcd-ca). Server cert for the etcd listener.
8. `admin.conf` (kubeconfig with embedded cert). The admin's local kubeconfig.
9. `controller-manager.conf` (kubeconfig). The controller manager's kubeconfig.
10. `scheduler.conf` (kubeconfig). The scheduler's kubeconfig.

Inspect a certificate file directly with openssl:

```bash
nerdctl exec kind-control-plane \
  openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -subject -issuer -dates
```

Expected output: the CN/O subject, the issuer DN (the cluster CA), and NotBefore/NotAfter dates. The Subject Alternative Names (SANs) for the API server certificate are especially important; view them with:

```bash
nerdctl exec kind-control-plane \
  openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -ext subjectAltName
```

Expected: IP and DNS entries including `kubernetes`, `kubernetes.default`, `kubernetes.default.svc`, `kubernetes.default.svc.cluster.local`, the cluster service CIDR's first IP (typically `10.96.0.1`), and the control plane node address.

## Step 6: Renew a Certificate and Restart the Pod

`kubeadm certs renew` regenerates a certificate on disk. It does not restart the component that uses the cert; the component continues to serve the old cert from memory until its process restarts. For static pod components, the restart is done by either touching the manifest or by killing the underlying container through `crictl`. The kubelet then reconciles and starts a new pod, which reads the new cert.

Walk through renewing the scheduler's kubeconfig:

```bash
nerdctl exec kind-control-plane kubeadm certs renew scheduler.conf
```

Expected output: `[renew] Renewing certificate for SCHEDULER_CONF` and `Done renewing certificates. You must restart the kube-scheduler component to pick up the new certificate.`

Verify the on-disk change:

```bash
nerdctl exec kind-control-plane kubeadm certs check-expiration \
  | grep scheduler.conf
```

Expected: the EXPIRES date is now one year from today (or later), later than before the renewal.

Restart the scheduler via manifest touch:

```bash
nerdctl exec kind-control-plane \
  touch /etc/kubernetes/manifests/kube-scheduler.yaml
```

Wait a few seconds and verify:

```bash
kubectl get pod -n kube-system kube-scheduler-kind-control-plane
```

Expected: Age is a few seconds old. The scheduler is now running with the renewed certificate.

The same pattern applies to every cert renewal: on-disk change, then static pod restart. `kubeadm certs renew all` regenerates every managed cert in one pass; the restart step covers all four static pods together:

```bash
nerdctl exec kind-control-plane bash -c '
  touch /etc/kubernetes/manifests/kube-apiserver.yaml
  touch /etc/kubernetes/manifests/kube-controller-manager.yaml
  touch /etc/kubernetes/manifests/kube-scheduler.yaml
  touch /etc/kubernetes/manifests/etcd.yaml
'
```

The four `touch` commands restart all four components; the API server restart is by far the most disruptive (kubectl will error for a few seconds until the new API server is ready). In production you would stagger this across nodes in an HA cluster; in kind's single-control-plane cluster you can do them in any order.

## Step 7: Verify a Certificate Against the Cluster CA

When diagnosing a client-cert authentication failure, knowing which CA signed a cert answers the first question. Use `openssl verify`:

```bash
nerdctl exec kind-control-plane \
  openssl verify -CAfile /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/apiserver.crt
```

Expected output: `/etc/kubernetes/pki/apiserver.crt: OK`. That single line confirms the `apiserver.crt` was signed by the cluster `ca.crt`.

If the verification fails, the output includes an error like `error 20: unable to get local issuer certificate` (the cert was signed by a different CA or the file is malformed) or `error 10: certificate has expired`. Both errors are meaningful diagnostic information.

Three CAs live in `/etc/kubernetes/pki/`:

```bash
nerdctl exec kind-control-plane ls /etc/kubernetes/pki/
```

Expected: files including `ca.crt`, `ca.key` (cluster CA), `etcd/ca.crt`, `etcd/ca.key` (etcd CA), `front-proxy-ca.crt`, `front-proxy-ca.key` (front-proxy CA). Each signs a different subset of the ten kubeadm-managed certs; the `check-expiration` table's CERTIFICATE AUTHORITY column tells you which CA signed each cert.

## Step 8: When the API Server Itself Is Down

The most stressful scenario: kubectl returns connection errors. Work exclusively inside the node.

Enter the node:

```bash
nerdctl exec -it kind-control-plane bash
```

First check whether the pod is running at the container level:

```bash
crictl ps -a --name kube-apiserver
```

Expected columns: `CONTAINER`, `IMAGE`, `CREATED`, `STATE`, `NAME`. The `STATE` column tells you:

- `Running`: the container is alive but not serving (network? cert?).
- `Exited`: the container crashed or was stopped.
- No row: the static pod has never started; the manifest is likely invalid.

If `STATE` is `Running` but kubectl cannot reach it, the diagnosis path is different (port conflict, wrong bind address, TLS problem). If `STATE` is `Exited`, read the crash log:

```bash
crictl logs $(crictl ps -a --name kube-apiserver -q | head -1) | tail -40
```

Expected: the last lines of stdout/stderr from the API server, often including `error: ...` or `F ...` flag-parsing failures.

If the container never started, kubelet logs the reason:

```bash
journalctl -u kubelet --no-pager | grep -i 'apiserver\|error' | tail -20
```

Look for `Failed to read pod manifest`, `unmarshal`, `invalid syntax`, or `Manifest` entries that name `kube-apiserver.yaml`.

Finally, look at the manifest directly:

```bash
cat /etc/kubernetes/manifests/kube-apiserver.yaml
```

Check for the common breakages: missing or wrong `--etcd-servers`, typo in a flag name, bad image tag, or a YAML parse error (a misplaced indentation).

To recover, fix the manifest. Kubelet reconciles the change within a few seconds and the API server pod comes back.

Exit the node:

```bash
exit
```

When kubectl recovers (within a few seconds of the fix), confirm the world from the outside:

```bash
kubectl get pods -n kube-system
```

Expected: the four control plane pods all `Running`.

## Step 9: Clean Up

Remove the tutorial namespace:

```bash
kubectl delete namespace tutorial-troubleshooting
```

The tutorial left no lasting changes to the control plane; the scheduler deletion in Step 4 was reversed immediately, and the certificate renewal in Step 6 is a normal maintenance operation. No post-exercise recovery is needed.

## Reference Commands

Keep this section open while working through the homework.

### The four diagnostic loops

| Loop | Use when | Start with |
|---|---|---|
| kubectl view | normal conditions, API server reachable | `kubectl get pods -n kube-system` and `kubectl logs -n kube-system <pod>` |
| inside-the-node view | API server down, or no log output through kubectl | `nerdctl exec -it kind-control-plane bash` then `crictl ps` and `journalctl -u kubelet` |
| manifest view | static pod missing, mis-configured, or about to be edited | `ls /etc/kubernetes/manifests/` inside the node, `cat <file>`, edit with `vi`, kubelet reconciles on save |
| certificate view | TLS or authentication failure, or planned renewal | `kubeadm certs check-expiration`, `openssl x509 -in <file>`, `kubeadm certs renew <name>`, then restart the static pod |

### Inside-the-node commands

```bash
# Enter the node (kind):
nerdctl exec -it kind-control-plane bash

# List running containers at the runtime level:
crictl ps
crictl ps -a --name kube-apiserver

# Get logs from a container at the runtime level (kubectl-independent):
crictl logs <container-id>
crictl logs -f <container-id>

# Inspect a container's spec and status:
crictl inspect <container-id>

# Stop and remove a container (forces kubelet to recreate from manifest):
crictl stop <container-id>
crictl rm <container-id>

# Read kubelet's systemd journal:
journalctl -u kubelet --no-pager -n 50
journalctl -u kubelet --since "5 minutes ago"

# Check kubelet service health:
systemctl status kubelet
```

### Manifest operations

```bash
# Static pod manifest directory (inside the node):
ls /etc/kubernetes/manifests/

# Edit a manifest (inside the node):
vi /etc/kubernetes/manifests/kube-scheduler.yaml

# Trigger a restart without changing the content:
touch /etc/kubernetes/manifests/kube-scheduler.yaml

# Temporarily disable a static pod (kubelet will remove its pod):
mv /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/

# Restore it:
mv /tmp/kube-scheduler.yaml /etc/kubernetes/manifests/
```

### Certificate operations

```bash
# Check all kubeadm-managed certs and kubeconfigs:
kubeadm certs check-expiration

# Renew a single cert:
kubeadm certs renew apiserver
kubeadm certs renew scheduler.conf

# Renew everything at once:
kubeadm certs renew all

# Inspect a cert file:
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -subject -issuer -dates
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -ext subjectAltName

# Verify a cert was signed by the cluster CA:
openssl verify -CAfile /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/apiserver.crt

# Apply cert renewal: restart the static pods so they re-read the cert files.
touch /etc/kubernetes/manifests/kube-apiserver.yaml
touch /etc/kubernetes/manifests/kube-controller-manager.yaml
touch /etc/kubernetes/manifests/kube-scheduler.yaml
touch /etc/kubernetes/manifests/etcd.yaml
```

### Common control plane failure symptoms

| Symptom | Likely component | First step |
|---|---|---|
| `kubectl` returns connection refused | API server | Enter node; `crictl ps -a --name kube-apiserver` |
| Pods stuck `Pending`, no scheduling events | Scheduler | `kubectl get pod -n kube-system | grep scheduler` and logs |
| Deployments have no ReplicaSets; Services have no endpoints | Controller manager | `kubectl logs -n kube-system kube-controller-manager-...` |
| `connection refused: 127.0.0.1:2379` in API server log | etcd | `kubectl get pod -n kube-system etcd-...` and its logs |
| `x509: certificate has expired` | any component | `kubeadm certs check-expiration`, then targeted renew |
| `CreateContainerError` on a control plane pod | manifest volume mount or image tag | `kubectl describe pod`, then inspect the manifest |

The diagnostic workflow for every exercise below starts with one of these symptoms and follows through the loops above until the root cause is identified, the correct fix is applied, and recovery is verified at every level.
