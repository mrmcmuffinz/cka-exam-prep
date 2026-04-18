# Control Plane Troubleshooting Homework Answers

Complete solutions for all 15 exercises. Every exercise in this assignment is a debugging exercise, so every answer follows the three-stage structure: Diagnosis (the exact commands to run and what output to read), What the bug is and why (the underlying cause), and Fix (the corrective command sequence). Level 4 is workflow-driven rather than failure-driven; those answers show the canonical renewal and verification sequence.

---

## Exercise 1.1 Solution

### Diagnosis

Look at the control plane components in `kube-system`:

```bash
kubectl get pods -n kube-system \
  -o custom-columns=NAME:.metadata.name,STATUS:.status.phase \
  | grep -E 'kube-(apiserver|scheduler|controller-manager)|etcd'
```

Expected output: three lines (`etcd`, `kube-apiserver`, `kube-controller-manager`) instead of four. `kube-scheduler` is missing.

Enter the control plane node and look for a scheduler container at the runtime level:

```bash
nerdctl exec kind-control-plane crictl ps -a --name kube-scheduler
```

Expected: no rows. The container never started, which means kubelet never saw a manifest for it.

Confirm by listing the manifest directory:

```bash
nerdctl exec kind-control-plane ls /etc/kubernetes/manifests/
```

Expected output lists `etcd.yaml`, `kube-apiserver.yaml`, `kube-controller-manager.yaml`, but no `kube-scheduler.yaml`. Kubelet only manages static pods whose manifests exist in this directory; removing a manifest is the documented way to deactivate a static pod.

### What the bug is and why it happens

The scheduler's manifest file has been removed from `/etc/kubernetes/manifests/`. Kubelet reconciles static pods by watching the directory; when a manifest disappears, kubelet stops the corresponding pod and cleans up. The backup file at `/tmp/ex-1-1-scheduler.yaml.bak` proves the content still exists; it just is not in the directory kubelet watches.

### Fix

Move the backup manifest back into place:

```bash
nerdctl exec kind-control-plane \
  mv /tmp/ex-1-1-scheduler.yaml.bak /etc/kubernetes/manifests/kube-scheduler.yaml
```

Wait about ten seconds for kubelet to reconcile, then confirm:

```bash
kubectl get pod -n kube-system kube-scheduler-kind-control-plane
```

Expected: Status `Running`, Ready `1/1`.

---

## Exercise 1.2 Solution

### Diagnosis

Check controller manager status:

```bash
kubectl get pod -n kube-system kube-controller-manager-kind-control-plane
```

Expected: Status `Running` with a restart count above 0, or `CrashLoopBackOff` with several restarts.

Read the controller manager's logs to see why the process is exiting:

```bash
kubectl logs -n kube-system kube-controller-manager-kind-control-plane --tail=20
```

Expected: a line resembling `Error: unknown flag: --bogus-flag` (or similar flag-parse failure), followed by usage text. If the pod has just restarted and its previous crash output is gone, use `--previous`:

```bash
kubectl logs -n kube-system kube-controller-manager-kind-control-plane --previous --tail=20
```

Confirm by inspecting the manifest:

```bash
nerdctl exec kind-control-plane \
  cat /etc/kubernetes/manifests/kube-controller-manager.yaml | head -20
```

The manifest shows a `- --bogus-flag=ex-1-2` entry among the container command arguments.

### What the bug is and why it happens

`kube-controller-manager` performs strict flag parsing at startup. When the binary encounters an unknown flag it exits immediately with `Error: unknown flag: ...`, which kubelet observes and counts as a pod failure; the pod enters CrashLoopBackOff. Adding unknown flags to a static pod manifest is a common source of crash loops after a copy-paste mistake or a downgrade that removes a previously-valid flag.

### Fix

Remove the bad flag line from the manifest:

```bash
nerdctl exec kind-control-plane \
  sed -i '/- --bogus-flag=ex-1-2/d' \
    /etc/kubernetes/manifests/kube-controller-manager.yaml
```

Or open the manifest with `vi` and delete the line manually. Kubelet reconciles within seconds and the pod comes back Ready.

---

## Exercise 1.3 Solution

### Diagnosis

Look at etcd status:

```bash
kubectl get pod -n kube-system etcd-kind-control-plane
```

Expected: Status `ImagePullBackOff` or `ErrImagePull`, Ready `0/1`.

Describe the pod and read the Events:

```bash
kubectl describe pod -n kube-system etcd-kind-control-plane | tail -15
```

Expected: Events include a `Failed to pull image "registry.k8s.io/etcd:v999.99.99"` entry with a specific error message (`not found`, `manifest unknown`, or a registry authentication error).

Inspect the manifest to confirm the bad image tag:

```bash
nerdctl exec kind-control-plane \
  grep 'image:' /etc/kubernetes/manifests/etcd.yaml
```

Expected: a line containing `image: registry.k8s.io/etcd:v999.99.99`.

### What the bug is and why it happens

The etcd manifest was edited to reference `registry.k8s.io/etcd:v999.99.99`, a tag that does not exist in the upstream registry. Kubelet attempts to pull the image; the pull fails; the pod enters `ImagePullBackOff` and is never started. The previous etcd container (running the old correct image) was terminated when the manifest change was detected, so etcd is effectively offline.

This is a realistic failure mode for clusters where an operator upgraded a manifest without verifying that the new image tag is available in the internal registry, or where a typo was introduced during an edit.

### Fix

Restore the correct image tag by using the backup:

```bash
nerdctl exec kind-control-plane \
  cp /tmp/ex-1-3-etcd.yaml.bak /etc/kubernetes/manifests/etcd.yaml
```

Alternatively, read the correct tag from the backup manifest and patch the broken one:

```bash
GOOD_TAG=$(nerdctl exec kind-control-plane \
  bash -c 'grep "image:" /tmp/ex-1-3-etcd.yaml.bak | sed "s|.*image: ||"')
nerdctl exec kind-control-plane \
  sed -i "s|image: registry.k8s.io/etcd:.*|image: $GOOD_TAG|" \
    /etc/kubernetes/manifests/etcd.yaml
```

Kubelet reconciles; etcd pulls the correct image (probably from its local containerd cache because it was running the same image before the change) and comes back Ready within about thirty seconds.

---

## Exercise 2.1 Solution

### Diagnosis

Check whether the scheduler pod is even listed:

```bash
kubectl get pod -n kube-system -l component=kube-scheduler
```

Expected: no entries. Unlike Exercise 1.2 where the pod exists and is crash-looping, here kubelet has not even started a pod because it cannot parse the manifest.

Read the kubelet journal for parse errors:

```bash
nerdctl exec kind-control-plane \
  journalctl -u kubelet --since "2 minutes ago" --no-pager \
  | grep -E 'kube-scheduler.yaml|parse|unmarshal|invalid' \
  | tail -10
```

Expected: one or more lines identifying the scheduler manifest and describing a YAML parse error (often `error unmarshaling JSON: while decoding JSON: json: unknown field "ex-2-1-bad-field"` or `yaml: line N: mapping values are not allowed in this context`).

Inspect the manifest directly:

```bash
nerdctl exec kind-control-plane \
  cat /etc/kubernetes/manifests/kube-scheduler.yaml | head -10
```

The offending line `ex-2-1-bad-field: value-at-wrong-indent` sits at the top level of the document, sibling to `apiVersion`, `kind`, `metadata`, and `spec`. A top-level key that Kubernetes does not recognize fails unmarshaling against the Pod schema.

### What the bug is and why it happens

The manifest was edited to include a top-level field (`ex-2-1-bad-field`) that is not part of the Pod schema. Kubelet's reconcile loop reads the manifest, attempts to unmarshal it into a `core.v1.Pod` object, and the unmarshal fails because of the unknown field. Kubelet logs the error and does not start a pod. Because there is no pod object, there is nothing to show up in `kubectl get pods`; the silent failure mode fits an exercise-caliber manifest typo exactly.

### Fix

Remove the offending line:

```bash
nerdctl exec kind-control-plane \
  sed -i '/^ex-2-1-bad-field:/d' \
    /etc/kubernetes/manifests/kube-scheduler.yaml
```

Kubelet reconciles within a few seconds and starts the scheduler pod. Confirm with `kubectl get pod -n kube-system kube-scheduler-kind-control-plane` which now reports `Running`, Ready `1/1`.

---

## Exercise 2.2 Solution

### Diagnosis

Check the controller manager's status:

```bash
kubectl get pod -n kube-system kube-controller-manager-kind-control-plane
```

Expected: Status `ContainerCreating` (stuck) rather than `Running` or `CrashLoopBackOff`. The pod is not yet running because a volume mount is blocking creation.

Read the pod's Events:

```bash
kubectl describe pod -n kube-system kube-controller-manager-kind-control-plane | tail -15
```

Expected: an Events entry like `MountVolume.SetUp failed for volume "k8s-certs" : hostPath type check failed: /etc/kubernetes/pki-wrong is not a directory`, or `FailedMount` with a similar message naming the wrong path.

Confirm by inspecting the manifest:

```bash
nerdctl exec kind-control-plane \
  grep -A1 'k8s-certs' /etc/kubernetes/manifests/kube-controller-manager.yaml
```

Expected: a `hostPath` entry with `path: /etc/kubernetes/pki-wrong`.

### What the bug is and why it happens

The hostPath source for the `k8s-certs` volume was changed from `/etc/kubernetes/pki` to `/etc/kubernetes/pki-wrong`. kubelet's mount helper checks that the hostPath source exists and is of the expected type before proceeding with pod startup; when the path is missing the mount fails and the pod is blocked in `ContainerCreating`. The manifest's `volumeMounts` entries on the container itself still reference the right mount path in the container's filesystem, but the volume's hostPath source (on the node) is wrong, so kubelet never gets to the point of starting the container.

### Fix

Restore the correct path:

```bash
nerdctl exec kind-control-plane \
  sed -i 's|path: /etc/kubernetes/pki-wrong|path: /etc/kubernetes/pki|' \
    /etc/kubernetes/manifests/kube-controller-manager.yaml
```

Kubelet reconciles, mounts the volume, and starts the container. Confirm the pod reaches Ready with the verification command in the exercise.

---

## Exercise 2.3 Solution

### Diagnosis

Check scheduler status:

```bash
kubectl get pod -n kube-system kube-scheduler-kind-control-plane
```

Expected: `CrashLoopBackOff` or Status `Running` with restarts climbing.

Read the scheduler's logs:

```bash
kubectl logs -n kube-system kube-scheduler-kind-control-plane --tail=20
```

Expected: a line like `Error: invalid argument "not-a-bool" for "--leader-elect" flag: strconv.ParseBool: parsing "not-a-bool": invalid syntax`. The error cites the specific flag and value.

Inspect the manifest:

```bash
nerdctl exec kind-control-plane \
  grep 'leader-elect' /etc/kubernetes/manifests/kube-scheduler.yaml
```

Expected: a line with `--leader-elect=not-a-bool`.

### What the bug is and why it happens

`--leader-elect` is a boolean flag; valid values are `true` or `false`. Passing a non-boolean string causes the Go flag-parsing layer to return `strconv.ParseBool: parsing "...": invalid syntax`, and the binary exits with a non-zero status. The static pod's container status goes to `Exited` with exit code 1 (or similar), kubelet restarts the pod, and the same error recurs, producing `CrashLoopBackOff`.

### Fix

Change the flag to a valid boolean or remove it entirely (the default is `true`):

```bash
nerdctl exec kind-control-plane \
  sed -i 's|--leader-elect=not-a-bool|--leader-elect=true|' \
    /etc/kubernetes/manifests/kube-scheduler.yaml
```

Or delete the offending line if the backup did not have it:

```bash
nerdctl exec kind-control-plane \
  sed -i '/--leader-elect=not-a-bool/d' \
    /etc/kubernetes/manifests/kube-scheduler.yaml
```

Either approach results in a scheduler pod that starts cleanly.

---

## Exercise 3.1 Solution

### Diagnosis

`kubectl` is unavailable, so the entire diagnosis happens inside the node. Enter it:

```bash
nerdctl exec -it kind-control-plane bash
```

List control plane containers with the runtime:

```bash
crictl ps -a --name kube-apiserver
```

Expected: a row with `STATE` set to `Exited` (recently terminated). The container keeps restarting, so the row may also show a non-zero exit count in `CREATED` timestamps.

Fetch the last log output from the API server:

```bash
crictl logs $(crictl ps -a --name kube-apiserver -q | head -1) 2>&1 | tail -40
```

Expected: lines indicating the API server cannot reach etcd, for example `connection refused: 127.0.0.1:9999` or `etcd cluster is unavailable or misconfigured`. The specific port (9999) is the smoking gun; etcd listens on 2379.

Inspect the manifest to confirm:

```bash
grep etcd-servers /etc/kubernetes/manifests/kube-apiserver.yaml
```

Expected: a line with `--etcd-servers=https://127.0.0.1:9999`.

### What the bug is and why it happens

The API server's `--etcd-servers` flag was changed from the correct etcd listener (port 2379) to a wrong port (9999). The API server starts, immediately tries to talk to etcd, cannot connect, logs a connection-refused error, and exits. Kubelet restarts it; the same error recurs. The pod enters CrashLoopBackOff. Because the API server is the gateway for all kubectl operations, kubectl itself sees connection errors whenever it tries to reach the cluster.

### Fix

Correct the `--etcd-servers` flag:

```bash
sed -i 's|--etcd-servers=https://127.0.0.1:9999|--etcd-servers=https://127.0.0.1:2379|' \
  /etc/kubernetes/manifests/kube-apiserver.yaml
```

Exit the node (`exit`) and wait a few seconds. kubectl recovers when kubelet reconciles the manifest and the API server connects to etcd successfully.

---

## Exercise 3.2 Solution

### Diagnosis

Check scheduler and pod status:

```bash
kubectl get pod -n kube-system kube-scheduler-kind-control-plane
```

Expected: CrashLoopBackOff.

Read the scheduler's logs:

```bash
kubectl logs -n kube-system kube-scheduler-kind-control-plane --previous --tail=20
```

Expected: a line like `stat /etc/kubernetes/scheduler-wrong.conf: no such file or directory` or `failed to load Kubernetes client config: stat /etc/kubernetes/scheduler-wrong.conf: no such file or directory`.

Read the manifest's command:

```bash
nerdctl exec kind-control-plane \
  grep kubeconfig /etc/kubernetes/manifests/kube-scheduler.yaml
```

Expected: `--kubeconfig=/etc/kubernetes/scheduler-wrong.conf`.

### What the bug is and why it happens

The `--kubeconfig` flag points at a nonexistent file. The scheduler needs a kubeconfig to talk to the API server; the kubeadm-managed file is `/etc/kubernetes/scheduler.conf`. With a wrong path the scheduler cannot load its credentials, exits with a file-not-found error, and enters CrashLoopBackOff. While the scheduler is down, new pods have nowhere to be scheduled and remain `Pending`.

### Fix

Correct the flag:

```bash
nerdctl exec kind-control-plane \
  sed -i 's|--kubeconfig=/etc/kubernetes/scheduler-wrong.conf|--kubeconfig=/etc/kubernetes/scheduler.conf|' \
    /etc/kubernetes/manifests/kube-scheduler.yaml
```

Wait for kubelet to reconcile. The scheduler starts and begins processing pending pods.

---

## Exercise 3.3 Solution

### Diagnosis

Check controller manager status:

```bash
kubectl get pod -n kube-system kube-controller-manager-kind-control-plane
```

Expected: CrashLoopBackOff.

Read logs:

```bash
kubectl logs -n kube-system kube-controller-manager-kind-control-plane --previous --tail=20
```

Expected: a line like `open /etc/kubernetes/pki/missing-ca.crt: no such file or directory` or similar, coming from the root CA-load step during startup.

Inspect the manifest:

```bash
nerdctl exec kind-control-plane \
  grep root-ca-file /etc/kubernetes/manifests/kube-controller-manager.yaml
```

Expected: `--root-ca-file=/etc/kubernetes/pki/missing-ca.crt`.

### What the bug is and why it happens

`--root-ca-file` tells the controller manager which CA to include in ServiceAccount token secrets so that workloads can verify the API server. When the file does not exist, the controller manager aborts startup and CrashLoopBackOffs. While it is down, no new controllers reconcile; Deployments do not produce ReplicaSets, Services do not get endpoint slices updated, and ServiceAccount tokens are not rotated.

### Fix

Restore the correct path:

```bash
nerdctl exec kind-control-plane \
  sed -i 's|--root-ca-file=/etc/kubernetes/pki/missing-ca.crt|--root-ca-file=/etc/kubernetes/pki/ca.crt|' \
    /etc/kubernetes/manifests/kube-controller-manager.yaml
```

Kubelet reconciles within seconds; the controller manager comes back and begins reconciling the backlog.

---

## Exercise 4.1 Solution

This exercise practices the canonical renewal workflow on a single certificate. No bug is present; the point is to internalize the two-step sequence (renew file on disk, then restart the consuming component) and to verify the restart actually put the new certificate into service.

Run the renewal inside the control plane node:

```bash
nerdctl exec kind-control-plane kubeadm certs renew apiserver
```

Expected output includes `[renew] Renewing certificate for APIserver` and `Done renewing certificates. You must restart the kube-apiserver component to pick up the new certificate.` The final sentence is the one that catches most candidates: the file on disk is new, but the running process still holds the old cert in memory.

Inspect the new file:

```bash
nerdctl exec kind-control-plane \
  openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -enddate
```

Expected: `notAfter=` date later than the capture stored in `/tmp/ex-4-1-notafter-before.txt`.

Restart the API server by touching its manifest:

```bash
nerdctl exec kind-control-plane \
  touch /etc/kubernetes/manifests/kube-apiserver.yaml
```

Alternatively, force the container to be recreated through the runtime:

```bash
nerdctl exec kind-control-plane bash -c '
  CID=$(crictl ps --name kube-apiserver -q | head -1)
  crictl stop "$CID"
  crictl rm "$CID"
'
```

Either approach causes kubelet to recreate the pod, which loads the new certificate from disk.

Verify that the running API server serves the new cert by comparing its serial to the on-disk serial; the verification block in the exercise performs this check. If the serials differ, the restart did not happen; re-check that the API server pod's `creationTimestamp` is within the last minute.

---

## Exercise 4.2 Solution

This exercise practices certificate verification as an explicit workflow. Each of the three certificates was signed by a different CA:

- `apiserver.crt` is signed by the cluster `ca.crt`. It is the server certificate the API server presents to clients.
- `apiserver-kubelet-client.crt` is signed by the cluster `ca.crt`. It is the client certificate the API server uses to authenticate when it talks to kubelet.
- `apiserver-etcd-client.crt` is signed by the etcd CA at `/etc/kubernetes/pki/etcd/ca.crt`. It is the client certificate the API server uses when it talks to etcd.

Run the three verify commands inside the node and tee the output:

```bash
nerdctl exec kind-control-plane bash -c '
  {
    openssl verify -CAfile /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/apiserver.crt
    openssl verify -CAfile /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/apiserver-kubelet-client.crt
    openssl verify -CAfile /etc/kubernetes/pki/etcd/ca.crt /etc/kubernetes/pki/apiserver-etcd-client.crt
  } | tee /tmp/ex-4-2-verify.txt
'
```

Expected output:

```
/etc/kubernetes/pki/apiserver.crt: OK
/etc/kubernetes/pki/apiserver-kubelet-client.crt: OK
/etc/kubernetes/pki/apiserver-etcd-client.crt: OK
```

The negative cross-check in the verification block deliberately uses the wrong CA for `apiserver-etcd-client.crt`, demonstrating that `openssl verify` returns an error when the signing chain does not match. This is the intuition that flips a mystery TLS failure (`tls: unknown authority`) into a targeted debug: identify which cert failed to verify, identify which CA was expected, confirm the mismatch with `openssl verify`, and renew or re-issue against the right CA.

The CA lookup shortcut: the `CERTIFICATE AUTHORITY` column in `kubeadm certs check-expiration`'s output tells you which CA signed each kubeadm-managed cert. Blank means the file is a kubeconfig (its embedded client cert is signed by the cluster CA). `ca` means the cluster CA signed it. `etcd-ca` means the etcd CA signed it. `front-proxy-ca` means the front-proxy CA signed it.

---

## Exercise 4.3 Solution

Full renewal is the same two-step pattern as 4.1 applied to every managed cert:

```bash
nerdctl exec kind-control-plane kubeadm certs renew all
```

Expected: ten `[renew] Renewing certificate for ...` lines (one per managed entry) and a final sentence that includes the instruction to restart the static pods.

Restart all four static pods with a single touch pass:

```bash
nerdctl exec kind-control-plane bash -c '
  touch /etc/kubernetes/manifests/kube-apiserver.yaml
  touch /etc/kubernetes/manifests/kube-controller-manager.yaml
  touch /etc/kubernetes/manifests/kube-scheduler.yaml
  touch /etc/kubernetes/manifests/etcd.yaml
'
```

The API server restart is the most disruptive and takes a few seconds; kubectl will briefly return connection errors, then recover.

Verify the before/after table with `diff`:

```bash
diff /tmp/ex-4-3-before.txt /tmp/ex-4-3-after.txt
```

Expected: every `EXPIRES` field has advanced by approximately one year, and every `RESIDUAL TIME` is now close to `365d` (or `364d` depending on when you ran it). The `EXTERNALLY MANAGED` column is unchanged and still reads `no` for every entry.

The CA section at the bottom of the table is unchanged, because `kubeadm certs renew all` does not touch the CAs themselves; the three CAs are long-lived (ten-year default validity) and are not rotated by this command. Rotating a CA is a separate, disruptive operation that is not in this assignment's scope.

---

## Exercise 5.1 Solution

### Diagnosis

Check scheduler status:

```bash
kubectl get pod -n kube-system kube-scheduler-kind-control-plane
```

Expected: some failure state (ImagePullBackOff, ContainerCreating stuck on mount, or CrashLoopBackOff). The observable symptom depends on which of the three bugs kubelet encounters first during pod startup.

Read Events and logs:

```bash
kubectl describe pod -n kube-system kube-scheduler-kind-control-plane | tail -15
kubectl logs -n kube-system kube-scheduler-kind-control-plane --previous --tail=20 2>/dev/null || true
nerdctl exec kind-control-plane \
  journalctl -u kubelet --since "2 minutes ago" --no-pager | tail -30
```

Expected: at least two of these three signals, depending on which bug manifests first:

- `Failed to pull image "registry.k8s.io/kube-scheduler:v999.99.99"`: the image tag bug.
- `MountVolume.SetUp failed ... /etc/kubernetes/sheduler.conf: no such file`: the hostPath typo bug.
- `Error: unknown flag: --unknown-sched-flag`: the bogus flag bug (only visible if the pod managed to start and then crashed).

Often the mount failure appears first because kubelet checks hostPath sources before pulling images; in that case the image pull never happens and the log signal points only at the mount. Finding all three requires inspecting the manifest directly.

Read the manifest:

```bash
nerdctl exec kind-control-plane \
  grep -E 'image:|path:|- --' /etc/kubernetes/manifests/kube-scheduler.yaml
```

Inspect the image tag, every hostPath, and every flag. You will see:

- `image: registry.k8s.io/kube-scheduler:v999.99.99` (non-existent tag).
- `path: /etc/kubernetes/sheduler.conf` (typo; should be `scheduler.conf`).
- `- --unknown-sched-flag=true` (unrecognized flag).

### What the bug is and why it happens

Three independent bugs, each sufficient on its own to prevent the scheduler from becoming Ready:

1. The image tag is wrong; kubelet cannot pull the image.
2. The hostPath source for the kubeconfig is misspelled; even if the image were pulled, kubelet cannot satisfy the volume mount.
3. A bogus flag was appended to the container command; even if the previous two were fixed, the scheduler binary would exit on unknown flag.

All three must be fixed for the scheduler to become Ready. The exercise is deliberately set up to exercise the discipline of inspecting the manifest in full rather than fixing only the symptom that the most recent log line reported.

### Fix

Fix each problem in order. The approach below writes a scripted fix inside the node; the corresponding `vi` edits would achieve the same result:

```bash
nerdctl exec kind-control-plane bash -c '
  MAN=/etc/kubernetes/manifests/kube-scheduler.yaml

  # Restore the original image tag from the backup.
  GOOD_IMG=$(grep "image: registry.k8s.io/kube-scheduler" /tmp/ex-5-1-scheduler.yaml.bak | sed "s|.*image: ||")
  sed -i "s|image: registry.k8s.io/kube-scheduler:v999.99.99|image: $GOOD_IMG|" "$MAN"

  # Fix the hostPath typo.
  sed -i "s|path: /etc/kubernetes/sheduler.conf|path: /etc/kubernetes/scheduler.conf|" "$MAN"

  # Remove the bogus flag.
  sed -i "/--unknown-sched-flag=true/d" "$MAN"
'
```

Kubelet reconciles. All three symptoms clear together and the scheduler pod becomes Ready.

---

## Exercise 5.2 Solution

### Diagnosis

`kubectl` is not responding because the API server depends on etcd and etcd is offline. Work exclusively inside the node:

```bash
nerdctl exec -it kind-control-plane bash
```

List the manifests directory:

```bash
ls /etc/kubernetes/manifests/
```

Expected: three files (`kube-apiserver.yaml`, `kube-controller-manager.yaml`, `kube-scheduler.yaml`) plus no `etcd.yaml`. The etcd manifest was moved out.

Check crictl for a running etcd container:

```bash
crictl ps --name etcd
```

Expected: no rows. etcd is not running at the runtime level.

Check kubelet's journal for recent signals:

```bash
journalctl -u kubelet --since "2 minutes ago" --no-pager | tail -20
```

Expected: entries showing kubelet reaping the etcd pod (because the manifest disappeared), plus API server liveness failures (since the API server cannot reach etcd).

Find the staged manifest:

```bash
ls /tmp/etcd.yaml.staged /tmp/ex-5-2-etcd.yaml.bak 2>/dev/null
```

Expected: at least one of these files exists and is a valid etcd static pod spec.

### What the bug is and why it happens

The etcd manifest was moved out of the kubelet-watched directory to `/tmp/etcd.yaml.staged`. kubelet stopped the etcd pod (its normal behavior when a static-pod manifest disappears). With etcd gone, the API server cannot reach its backing store; its liveness probes fail, and kubelet restarts the API server, where the same connection error recurs. The whole cluster looks down from outside.

The recovery is to put the manifest back and let kubelet reconcile.

### Fix

Move the manifest back to its original location:

```bash
mv /tmp/etcd.yaml.staged /etc/kubernetes/manifests/etcd.yaml
```

Or, if the staged copy is not the form you trust, use the backup:

```bash
cp /tmp/ex-5-2-etcd.yaml.bak /etc/kubernetes/manifests/etcd.yaml
```

Exit the node (`exit`). Wait thirty to sixty seconds. Kubelet starts etcd; the API server comes back when its etcd connection succeeds; `kubectl get nodes` succeeds again.

If the API server takes longer to recover than expected, touch its manifest to force kubelet to restart it:

```bash
nerdctl exec kind-control-plane \
  touch /etc/kubernetes/manifests/kube-apiserver.yaml
```

---

## Exercise 5.3 Solution

### Diagnosis

kubectl still works (the API server and etcd are healthy), so start from the kubectl view:

```bash
kubectl get pods -n kube-system \
  -o custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[0].ready \
  | grep -E 'kube-(apiserver|scheduler|controller-manager)|etcd'
```

Expected: `kube-apiserver` and `etcd` are `true`; `kube-scheduler` and `kube-controller-manager` are `false`.

Read each troubled component's log independently:

```bash
kubectl logs -n kube-system kube-scheduler-kind-control-plane --previous --tail=20
kubectl logs -n kube-system kube-controller-manager-kind-control-plane --previous --tail=20
```

Expected from the scheduler: a `no such file or directory` error naming `/etc/kubernetes/wrong-scheduler.conf`. Expected from the controller manager: an `unknown flag: --not-a-real-flag` error.

Inspect both manifests:

```bash
nerdctl exec kind-control-plane bash -c '
  echo "--- scheduler kubeconfig flag ---"
  grep "kubeconfig" /etc/kubernetes/manifests/kube-scheduler.yaml
  echo "--- controller-manager flags ---"
  grep -A1 "not-a-real-flag" /etc/kubernetes/manifests/kube-controller-manager.yaml
'
```

Expected: scheduler shows `--kubeconfig=/etc/kubernetes/wrong-scheduler.conf`; controller manager shows the `--not-a-real-flag=true` flag.

### What the bug is and why it happens

Two independent failures:

1. The scheduler's `--kubeconfig` flag points at a file that does not exist.
2. The controller manager's command list has an unrecognized flag.

Each failure causes CrashLoopBackOff in its respective component. They are not related; the symptoms (pods stuck Pending; Deployments not producing ReplicaSets) are the downstream consequences of the two components being offline, not evidence of a connection problem between them.

### Fix

Fix each independently:

```bash
nerdctl exec kind-control-plane bash -c '
  sed -i "s|--kubeconfig=/etc/kubernetes/wrong-scheduler.conf|--kubeconfig=/etc/kubernetes/scheduler.conf|" \
    /etc/kubernetes/manifests/kube-scheduler.yaml

  sed -i "/--not-a-real-flag=true/d" \
    /etc/kubernetes/manifests/kube-controller-manager.yaml
'
```

Wait for kubelet to reconcile both manifests. Verify the two pods reach Ready and run the downstream probes (the probe pod for scheduler functionality, the probe Deployment for controller manager functionality) described in the exercise's verification block.

---

## Common Mistakes

Forgetting to restart a static pod after editing a flag that the binary reads only at startup. Most control plane components parse their command-line once at process start; changing the manifest file is not enough if the container keeps running with the old configuration. The reconcile loop does restart the pod on manifest change automatically, but when `kubeadm certs renew` writes a new certificate to disk without touching the manifest, you have to trigger the restart yourself (`touch` the manifest, or `crictl stop` plus `crictl rm` on the container).

Assuming `kubectl` is the only tool that matters. When the API server is down, kubectl returns connection errors and every diagnostic command you typed by muscle memory fails. The lifeline is `nerdctl exec -it kind-control-plane bash` followed by `crictl ps`, `crictl logs`, and `journalctl -u kubelet`. Practicing these commands on a healthy cluster (Step 2 of the tutorial) is the only way they stay available when you need them under pressure.

Removing or restoring a static pod manifest by editing instead of moving. Deleting the manifest entirely is sometimes the right tool (to stop a broken component cleanly, for example during troubleshooting), and moving it to a different directory keeps a recoverable backup at hand. Editing inside the manifest to disable the pod often produces a pod that is half-started and harder to reason about than a cleanly absent one.

Forgetting that the controller manager and scheduler need their kubeconfigs. The `--kubeconfig` flag on each points at `/etc/kubernetes/controller-manager.conf` and `/etc/kubernetes/scheduler.conf` respectively. These files contain the embedded client certificates those components use to authenticate to the API server. A wrong path, a missing file, or an expired cert inside the file all make the component fail to start, and the error message is usually a file-not-found or a TLS validation failure rather than an authorization one.

Trying to verify a certificate against the wrong CA. Every CKA candidate has run `openssl verify -CAfile /etc/kubernetes/pki/ca.crt` at least once, but the cluster has three CAs, not one. `apiserver-etcd-client.crt` is signed by `/etc/kubernetes/pki/etcd/ca.crt`, not by the cluster CA. `front-proxy-client.crt` is signed by `/etc/kubernetes/pki/front-proxy-ca.crt`. Use the `CERTIFICATE AUTHORITY` column in `kubeadm certs check-expiration` output to identify which CA signed which cert before reaching for `openssl verify`.

Expecting an HA-flavored recovery in a single-control-plane cluster. Some scenarios covered in Kubernetes documentation (graceful failover, drain-and-cordon the affected control plane node, kubeadm join a replacement) require multiple control plane nodes. In a single-control-plane kind cluster, and on a single-control-plane CKA exam topology, recovery is entirely in-place: fix the manifest, fix the cert, fix the flag, restart the component, verify. Relying on "the other control plane node will take over" during practice leaves you without a plan when the exam cluster is single-node.

Confusing `systemctl restart kubelet` with restarting a control plane component. Restarting kubelet does not restart the static pods; it just restarts kubelet itself. To restart a static pod you either touch its manifest or use `crictl stop` plus `crictl rm` on its container. The two commands are not substitutes for each other.

---

## Verification Commands Cheat Sheet

```bash
# From outside the node (kubectl works)
kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[0].ready
kubectl describe pod -n kube-system <pod-name>
kubectl logs -n kube-system <pod-name> --tail=50
kubectl logs -n kube-system <pod-name> --previous --tail=50

# Enter the node
nerdctl exec -it kind-control-plane bash

# Inside the node: containers via the runtime
crictl ps
crictl ps -a --name kube-apiserver
crictl logs $(crictl ps --name kube-apiserver -q | head -1)
crictl inspect $(crictl ps --name kube-apiserver -q | head -1) | head -80
crictl exec <container-id> <command>

# Inside the node: manifests
ls /etc/kubernetes/manifests/
cat /etc/kubernetes/manifests/kube-scheduler.yaml
vi /etc/kubernetes/manifests/kube-scheduler.yaml
touch /etc/kubernetes/manifests/kube-scheduler.yaml

# Inside the node: kubelet service
systemctl status kubelet
journalctl -u kubelet --no-pager -n 50
journalctl -u kubelet --since "5 minutes ago"

# Inside the node: certificates
kubeadm certs check-expiration
kubeadm certs renew <name>
kubeadm certs renew all
openssl x509 -in /etc/kubernetes/pki/<file>.crt -noout -subject -issuer -dates -ext subjectAltName
openssl verify -CAfile /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/apiserver.crt
openssl verify -CAfile /etc/kubernetes/pki/etcd/ca.crt /etc/kubernetes/pki/apiserver-etcd-client.crt

# Inside the node: live certificate served by the API server
echo | openssl s_client -connect 127.0.0.1:6443 -servername kubernetes -showcerts 2>/dev/null \
  | openssl x509 -noout -serial
```

When kubectl fails and you are unsure what to type first, a good default sequence is: enter the node, `crictl ps` to see which containers are running, `crictl ps -a` to include recently-exited ones, `journalctl -u kubelet -n 50` to see what kubelet is complaining about, then inspect whichever manifest in `/etc/kubernetes/manifests/` corresponds to the component in question. Each of those four steps is under five seconds of typing and together they identify the cause of the vast majority of control plane failures.
