# Control Plane Troubleshooting Homework: 15 Progressive Exercises

These exercises build on the concepts covered in `troubleshooting-tutorial.md`. Every exercise is a debugging exercise; the setup breaks something in the control plane, and you must diagnose and fix it. Headings are bare by convention so the setup does not telegraph what is wrong.

All exercises assume the multi-node kind cluster described in `docs/cluster-setup.md#multi-node-kind-cluster`:

```bash
kubectl config current-context   # expect: kind-kind
kubectl get nodes                # expect: 4 nodes, all Ready
nerdctl ps | grep kind-control-plane   # expect: one Up row
```

Some exercises break the API server or etcd. During those exercises `kubectl` will not work until the fix is applied; use `nerdctl exec -it kind-control-plane bash` and the `crictl` / `journalctl` workflow from the tutorial. If a fix goes wrong and the cluster becomes unrecoverable, delete and recreate it: `kind delete cluster` followed by the creation command in `docs/cluster-setup.md#multi-node-kind-cluster`. No exercise requires destroying the cluster when completed correctly.

Every exercise uses one namespace named `ex-<level>-<exercise>` for any test workloads it needs. Not every exercise uses one; it is created only where a test pod is needed to confirm the fix.

## Global Setup

Create the namespaces used by the exercises that need them:

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 \
          ex-3-2 \
          ex-5-3; do
  kubectl create namespace $ns
done
```

Each exercise's setup block is self-contained: it runs the breaking commands. Read the objective, run the setup, solve the task, then run the verification block.

---

## Level 1: Component Status

### Exercise 1.1

**Objective:** Restore full control plane operation.

**Setup:**

```bash
nerdctl exec kind-control-plane bash -c '
  cp /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/ex-1-1-scheduler.yaml.bak
  rm /etc/kubernetes/manifests/kube-scheduler.yaml
'
sleep 10
```

**Task:**

The cluster has four expected control plane static pods (`kube-apiserver`, `kube-scheduler`, `kube-controller-manager`, `etcd`). One is not currently running. Identify which component is missing, restore it from the backup at `/tmp/ex-1-1-scheduler.yaml.bak` inside the control plane node, and wait for it to come back to Ready.

**Verification:**

```bash
kubectl get pods -n kube-system \
  -o custom-columns=NAME:.metadata.name,STATUS:.status.phase \
  | grep -E 'kube-(apiserver|scheduler|controller-manager)|etcd'
# Expected: four lines, all with STATUS Running:
#   etcd-kind-control-plane Running
#   kube-apiserver-kind-control-plane Running
#   kube-controller-manager-kind-control-plane Running
#   kube-scheduler-kind-control-plane Running

kubectl run ex-1-1-probe -n ex-1-1 --image=nginx:1.27 --restart=Never
kubectl wait --for=condition=Ready pod/ex-1-1-probe -n ex-1-1 --timeout=60s
# Expected: pod reaches Ready (confirming the scheduler is functional again).
kubectl delete pod ex-1-1-probe -n ex-1-1
```

---

### Exercise 1.2

**Objective:** Return the controller manager to Ready.

**Setup:**

```bash
nerdctl exec kind-control-plane bash -c '
  cp /etc/kubernetes/manifests/kube-controller-manager.yaml /tmp/ex-1-2-cm.yaml.bak
  sed -i "0,/- kube-controller-manager/s//- kube-controller-manager\n    - --bogus-flag=ex-1-2/" \
    /etc/kubernetes/manifests/kube-controller-manager.yaml
'
sleep 20
```

**Task:**

The controller manager is not Ready. Diagnose what is wrong using the kubectl view and the control plane component logs, then fix the manifest so that the pod reaches Ready. A backup of the original manifest is at `/tmp/ex-1-2-cm.yaml.bak` inside the node if you need a reference.

**Verification:**

```bash
kubectl get pod -n kube-system kube-controller-manager-kind-control-plane \
  -o jsonpath='{.status.phase}{"\n"}'
# Expected: Running

kubectl get pod -n kube-system kube-controller-manager-kind-control-plane \
  -o jsonpath='{.status.containerStatuses[0].ready}{"\n"}'
# Expected: true

# Confirm the controller manager is reconciling by creating a Deployment and
# watching it create a ReplicaSet:
kubectl create deployment ex-1-2-demo -n ex-1-2 --image=nginx:1.27
kubectl wait --for=condition=Available deployment/ex-1-2-demo -n ex-1-2 --timeout=60s
# Expected: deployment reaches Available (ReplicaSet created and pod is Ready).
kubectl delete deployment ex-1-2-demo -n ex-1-2
```

---

### Exercise 1.3

**Objective:** Return etcd to Ready.

**Setup:**

```bash
nerdctl exec kind-control-plane bash -c '
  cp /etc/kubernetes/manifests/etcd.yaml /tmp/ex-1-3-etcd.yaml.bak
  sed -i "s|image: registry.k8s.io/etcd:.*|image: registry.k8s.io/etcd:v999.99.99|" \
    /etc/kubernetes/manifests/etcd.yaml
'
sleep 30
```

**Task:**

The etcd static pod is not Ready. kubectl may work for a while (the API server may be running against the previous etcd container until it is replaced) but is flaky. Diagnose what is wrong, correct the manifest, and confirm etcd returns to Running. The original manifest is at `/tmp/ex-1-3-etcd.yaml.bak` inside the node.

Hint: you may need to read the manifest from inside the node (`cat /etc/kubernetes/manifests/etcd.yaml`) and compare image tags against what the node's registry has.

**Verification:**

```bash
kubectl get pod -n kube-system etcd-kind-control-plane \
  -o jsonpath='{.status.containerStatuses[0].ready}{"\n"}'
# Expected: true

# Confirm etcd responds to health checks by running the etcd container's built-in
# etcdctl health probe through crictl:
nerdctl exec kind-control-plane bash -c '
  CID=$(crictl ps --name etcd -q | head -1)
  crictl exec "$CID" etcdctl \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    endpoint health
'
# Expected: a line containing "is healthy" with a response time.
```

---

## Level 2: Static Pod Manifest Issues

### Exercise 2.1

**Objective:** Return the scheduler to Ready after a YAML structural error.

**Setup:**

```bash
nerdctl exec kind-control-plane bash -c '
  cp /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/ex-2-1-scheduler.yaml.bak
  # Insert a stray top-level key that breaks YAML structure.
  sed -i "/^spec:/i ex-2-1-bad-field: value-at-wrong-indent" \
    /etc/kubernetes/manifests/kube-scheduler.yaml
'
sleep 20
```

**Task:**

After the setup, the kube-scheduler static pod does not come up. The pod may not appear in `kubectl get pods -n kube-system` at all. Diagnose what is preventing kubelet from starting the pod, fix the manifest, and confirm the scheduler returns to Ready. The original is at `/tmp/ex-2-1-scheduler.yaml.bak` inside the node.

**Verification:**

```bash
kubectl get pod -n kube-system kube-scheduler-kind-control-plane \
  -o jsonpath='{.status.containerStatuses[0].ready}{"\n"}'
# Expected: true

# Kubelet journal should no longer show manifest parse errors.
nerdctl exec kind-control-plane bash -c '
  journalctl -u kubelet --since "2 minutes ago" --no-pager \
    | grep -Ei "parse|unmarshal|invalid" \
    | head -5
'
# Expected: no matching lines (empty output).
```

---

### Exercise 2.2

**Objective:** Fix the controller manager so its pod can mount its certificates.

**Setup:**

```bash
nerdctl exec kind-control-plane bash -c '
  cp /etc/kubernetes/manifests/kube-controller-manager.yaml /tmp/ex-2-2-cm.yaml.bak
  # Change the hostPath source for the PKI mount from /etc/kubernetes/pki to a wrong path.
  sed -i "s|path: /etc/kubernetes/pki$|path: /etc/kubernetes/pki-wrong|" \
    /etc/kubernetes/manifests/kube-controller-manager.yaml
'
sleep 30
```

**Task:**

After the setup, the controller manager pod is not Ready. Diagnose the cause by reading the pod's events and identifying the specific mount failure, then correct the manifest so the pod can mount its certificates from the cluster PKI directory. The original manifest is at `/tmp/ex-2-2-cm.yaml.bak` inside the node.

**Verification:**

```bash
kubectl get pod -n kube-system kube-controller-manager-kind-control-plane \
  -o jsonpath='{.status.containerStatuses[0].ready}{"\n"}'
# Expected: true

# Confirm the PKI mount is back to its correct source:
nerdctl exec kind-control-plane bash -c '
  grep -E "path: /etc/kubernetes/pki( |$)" \
    /etc/kubernetes/manifests/kube-controller-manager.yaml | head -1
'
# Expected: a line containing "path: /etc/kubernetes/pki" (no trailing -wrong).
```

---

### Exercise 2.3

**Objective:** Restore the scheduler after an invalid command-line argument.

**Setup:**

```bash
nerdctl exec kind-control-plane bash -c '
  cp /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/ex-2-3-scheduler.yaml.bak
  # Replace the existing --leader-elect line (or append one) with an invalid value.
  if grep -q "leader-elect=" /etc/kubernetes/manifests/kube-scheduler.yaml; then
    sed -i "s|--leader-elect=.*|--leader-elect=not-a-bool|" \
      /etc/kubernetes/manifests/kube-scheduler.yaml
  else
    sed -i "/- kube-scheduler$/a\\    - --leader-elect=not-a-bool" \
      /etc/kubernetes/manifests/kube-scheduler.yaml
  fi
'
sleep 25
```

**Task:**

After the setup, the scheduler is in CrashLoopBackOff. The pod exists (the manifest parses), but the binary exits shortly after starting. Diagnose from the scheduler container's logs, identify the specific flag parse error, and fix the manifest so the scheduler stays Running. The original is at `/tmp/ex-2-3-scheduler.yaml.bak` inside the node.

**Verification:**

```bash
kubectl get pod -n kube-system kube-scheduler-kind-control-plane \
  -o jsonpath='{.status.containerStatuses[0].ready}{"\n"}'
# Expected: true

# No lines matching "invalid argument" for leader-elect in the most recent
# 30 lines of the scheduler pod's log.
kubectl logs -n kube-system kube-scheduler-kind-control-plane --tail=30 \
  | grep -i "invalid argument" \
  | head -1
# Expected: no output (no matching lines).
```

---

## Level 3: Component Failures

### Exercise 3.1

**Objective:** Return the API server to Ready.

**Setup:**

```bash
nerdctl exec kind-control-plane bash -c '
  cp /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/ex-3-1-apiserver.yaml.bak
  sed -i "s|--etcd-servers=https://127.0.0.1:2379|--etcd-servers=https://127.0.0.1:9999|" \
    /etc/kubernetes/manifests/kube-apiserver.yaml
'
sleep 30
```

**Task:**

After the setup, `kubectl` returns connection errors. Diagnose the problem from inside the control plane container using crictl. Identify the specific reason the API server is not serving, correct the manifest, and confirm the cluster is back. The original is at `/tmp/ex-3-1-apiserver.yaml.bak` inside the node.

**Verification:**

```bash
kubectl get nodes
# Expected: four nodes all Ready (after a brief wait for the API server to recover).

kubectl get pod -n kube-system kube-apiserver-kind-control-plane \
  -o jsonpath='{.status.containerStatuses[0].ready}{"\n"}'
# Expected: true

# Confirm the correct --etcd-servers value is present:
nerdctl exec kind-control-plane bash -c '
  grep "etcd-servers" /etc/kubernetes/manifests/kube-apiserver.yaml
'
# Expected: a line containing --etcd-servers=https://127.0.0.1:2379
```

---

### Exercise 3.2

**Objective:** Return the scheduler to Ready so that test pods can be scheduled.

**Setup:**

```bash
nerdctl exec kind-control-plane bash -c '
  cp /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/ex-3-2-scheduler.yaml.bak
  sed -i "s|--kubeconfig=/etc/kubernetes/scheduler.conf|--kubeconfig=/etc/kubernetes/scheduler-wrong.conf|" \
    /etc/kubernetes/manifests/kube-scheduler.yaml
'
sleep 25
```

**Task:**

After the setup, pods submitted to the cluster remain `Pending`. Diagnose why from the kubectl view and the scheduler's component logs; pods that are `Pending` without any scheduling events point at a scheduler-level problem, not an application one. Fix the manifest so the scheduler starts successfully and resumes scheduling. The original is at `/tmp/ex-3-2-scheduler.yaml.bak` inside the node.

**Verification:**

```bash
kubectl get pod -n kube-system kube-scheduler-kind-control-plane \
  -o jsonpath='{.status.containerStatuses[0].ready}{"\n"}'
# Expected: true

# Submit a probe pod and confirm scheduling works:
kubectl run ex-3-2-probe -n ex-3-2 --image=nginx:1.27 --restart=Never
kubectl wait --for=condition=Ready pod/ex-3-2-probe -n ex-3-2 --timeout=60s
# Expected: the pod reaches Ready.
kubectl delete pod ex-3-2-probe -n ex-3-2
```

---

### Exercise 3.3

**Objective:** Restore the controller manager so deployments reconcile again.

**Setup:**

```bash
nerdctl exec kind-control-plane bash -c '
  cp /etc/kubernetes/manifests/kube-controller-manager.yaml /tmp/ex-3-3-cm.yaml.bak
  sed -i "s|--root-ca-file=/etc/kubernetes/pki/ca.crt|--root-ca-file=/etc/kubernetes/pki/missing-ca.crt|" \
    /etc/kubernetes/manifests/kube-controller-manager.yaml
'
sleep 25
```

**Task:**

After the setup, creating a Deployment does not produce a ReplicaSet and no pods appear. The scheduler is fine; the controller manager is the component with the problem. Diagnose from the controller manager's logs, correct the flag, and confirm the cluster reconciles new workloads again. The original is at `/tmp/ex-3-3-cm.yaml.bak` inside the node.

**Verification:**

```bash
kubectl get pod -n kube-system kube-controller-manager-kind-control-plane \
  -o jsonpath='{.status.containerStatuses[0].ready}{"\n"}'
# Expected: true

# Create a temporary Deployment and watch the ReplicaSet appear (proof the
# controller manager is functioning):
kubectl create namespace ex-3-3 --dry-run=client -o yaml | kubectl apply -f -
kubectl create deployment ex-3-3-demo -n ex-3-3 --image=nginx:1.27 --replicas=2
kubectl wait --for=condition=Available deployment/ex-3-3-demo -n ex-3-3 --timeout=60s
# Expected: the deployment reaches Available with 2/2 pods.
kubectl delete namespace ex-3-3
```

---

## Level 4: Certificate Issues

### Exercise 4.1

**Objective:** Renew the API server certificate and put the new certificate into service.

**Setup:**

```bash
# Capture the current NotAfter date of the API server cert so you can prove the
# renewal increased it.
nerdctl exec kind-control-plane bash -c '
  openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -enddate
' | tee /tmp/ex-4-1-notafter-before.txt
```

**Task:**

Use `kubeadm certs renew` to renew only the API server's server certificate (not the whole set). After renewal, restart the `kube-apiserver` static pod so it picks up the new certificate. Verify the new `NotAfter` date is later than the one captured above and that the running API server is serving the renewed certificate.

**Verification:**

```bash
# The on-disk cert has a later NotAfter:
BEFORE=$(grep 'notAfter=' /tmp/ex-4-1-notafter-before.txt | cut -d= -f2-)
AFTER=$(nerdctl exec kind-control-plane \
          openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -enddate \
          | cut -d= -f2-)
echo "Before: $BEFORE"
echo "After:  $AFTER"
# Expected: the After date is later than the Before date.

# The API server's live certificate matches the on-disk file (serial number check):
ON_DISK=$(nerdctl exec kind-control-plane \
           openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -serial)
LIVE=$(nerdctl exec kind-control-plane bash -c '
  echo | openssl s_client -connect 127.0.0.1:6443 -servername kubernetes -showcerts 2>/dev/null \
    | openssl x509 -noout -serial
')
echo "On disk: $ON_DISK"
echo "Live:    $LIVE"
# Expected: the two serial values are identical.

# kubectl still works:
kubectl get nodes
# Expected: four nodes Ready.
```

---

### Exercise 4.2

**Objective:** Confirm the API server certificate was signed by the cluster CA, then confirm the same for the kubelet-client and etcd-client certs that the API server itself uses.

**Setup:**

```bash
# No breakage; this exercise practices certificate verification as a workflow.
nerdctl exec kind-control-plane ls /etc/kubernetes/pki
```

**Task:**

Using `openssl verify` against the correct CA file for each cert, verify that:

1. `/etc/kubernetes/pki/apiserver.crt` was signed by `/etc/kubernetes/pki/ca.crt`.
2. `/etc/kubernetes/pki/apiserver-kubelet-client.crt` was also signed by `/etc/kubernetes/pki/ca.crt`.
3. `/etc/kubernetes/pki/apiserver-etcd-client.crt` was signed by `/etc/kubernetes/pki/etcd/ca.crt` (the etcd CA, not the cluster CA).

Write the three verify commands and store their combined output at `/tmp/ex-4-2-verify.txt` inside the node for review. The objective succeeds only if all three commands report `OK`.

**Verification:**

```bash
nerdctl exec kind-control-plane cat /tmp/ex-4-2-verify.txt
# Expected output (three lines):
# /etc/kubernetes/pki/apiserver.crt: OK
# /etc/kubernetes/pki/apiserver-kubelet-client.crt: OK
# /etc/kubernetes/pki/apiserver-etcd-client.crt: OK

# A cross-check: verifying apiserver-etcd-client.crt against the cluster CA
# must fail, because it is signed by the etcd CA. A report of the expected
# failure confirms understanding.
nerdctl exec kind-control-plane bash -c '
  openssl verify -CAfile /etc/kubernetes/pki/ca.crt \
    /etc/kubernetes/pki/apiserver-etcd-client.crt 2>&1 | head -1
'
# Expected: a line ending in "unable to get local issuer certificate" or
# similar error; NOT the "OK" line above.
```

---

### Exercise 4.3

**Objective:** Renew every kubeadm-managed certificate at once, restart every static pod so the new certs are in service, and confirm every expiration date advanced.

**Setup:**

```bash
# Capture the full check-expiration table for comparison after renewal.
nerdctl exec kind-control-plane kubeadm certs check-expiration \
  > /tmp/ex-4-3-before.txt
```

**Task:**

Use `kubeadm certs renew all` inside the control plane node to regenerate every kubeadm-managed certificate. Then restart all four control plane static pods so they re-read the certs from disk. After the restarts settle, run `kubeadm certs check-expiration` again and confirm every `EXPIRES` entry is later than the corresponding entry captured at setup time.

**Verification:**

```bash
nerdctl exec kind-control-plane kubeadm certs check-expiration \
  > /tmp/ex-4-3-after.txt

# Compare the two files side-by-side. Every EXPIRES row in the after file
# should be later than its counterpart in the before file.
diff /tmp/ex-4-3-before.txt /tmp/ex-4-3-after.txt | head -40
# Expected: a diff showing every EXPIRES column has advanced, and every
# RESIDUAL TIME column has gone back to roughly one year.

# All four control plane pods have recent Age (restarted within the last
# few minutes):
kubectl get pods -n kube-system \
  -o custom-columns=NAME:.metadata.name,AGE:.metadata.creationTimestamp \
  | grep -E 'kube-(apiserver|scheduler|controller-manager)|etcd'
# Expected: four lines whose creationTimestamp is within the last few minutes
# (indicating the pods were recreated after the manifest-touch restart).

# The cluster is still fully functional post-renewal:
kubectl get nodes
# Expected: four nodes Ready.
```

---

## Level 5: Complex Scenarios

### Exercise 5.1

**Objective:** Return the scheduler to Ready with three separate manifest problems corrected.

**Setup:**

```bash
nerdctl exec kind-control-plane bash -c '
  cp /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/ex-5-1-scheduler.yaml.bak

  # Problem A: image tag points at a non-existent version.
  sed -i -E "s|image: (registry.k8s.io/kube-scheduler):v[0-9.]+|image: \\1:v999.99.99|" \
    /etc/kubernetes/manifests/kube-scheduler.yaml

  # Problem B: hostPath for the kubeconfig mount has a typo.
  sed -i "s|path: /etc/kubernetes/scheduler.conf|path: /etc/kubernetes/sheduler.conf|" \
    /etc/kubernetes/manifests/kube-scheduler.yaml

  # Problem C: a bogus flag appended to command.
  sed -i "/- kube-scheduler$/a\\    - --unknown-sched-flag=true" \
    /etc/kubernetes/manifests/kube-scheduler.yaml
'
sleep 30
```

**Task:**

The scheduler will not become Ready. The manifest has one or more problems. Find and fix whatever is needed. The original is at `/tmp/ex-5-1-scheduler.yaml.bak` inside the node. Do not simply restore from the backup; practice diagnosing each issue from the observable symptom (pod events, pod logs, kubelet journal) so that the same approach works on an unfamiliar manifest in the future.

**Verification:**

```bash
kubectl get pod -n kube-system kube-scheduler-kind-control-plane \
  -o jsonpath='{.status.containerStatuses[0].ready}{"\n"}'
# Expected: true

# Confirm no remnant of the three bugs remains:
nerdctl exec kind-control-plane bash -c '
  MAN=/etc/kubernetes/manifests/kube-scheduler.yaml
  echo "image-check:"
  grep "image: registry.k8s.io/kube-scheduler" "$MAN"
  echo "mount-check:"
  grep "path: /etc/kubernetes/scheduler.conf" "$MAN"
  echo "flag-check:"
  grep -c "unknown-sched-flag" "$MAN" || true
'
# Expected:
# image-check: image: registry.k8s.io/kube-scheduler:vX.Y.Z  (a real tag)
# mount-check: path: /etc/kubernetes/scheduler.conf
# flag-check: 0
```

---

### Exercise 5.2

**Objective:** Return etcd and the API server to Ready after etcd is offline.

**Setup:**

```bash
nerdctl exec kind-control-plane bash -c '
  cp /etc/kubernetes/manifests/etcd.yaml /tmp/ex-5-2-etcd.yaml.bak
  mv /etc/kubernetes/manifests/etcd.yaml /tmp/etcd.yaml.staged
'
sleep 30
```

**Task:**

After the setup, etcd is offline. Because the API server requires etcd, `kubectl` returns connection errors. Recover from inside the control plane container: find the staged manifest, restore it to `/etc/kubernetes/manifests/etcd.yaml`, and wait for kubelet to bring etcd and the API server back. Use only the inside-the-node workflow for the recovery (crictl, the manifest directory, and journalctl); do not rely on kubectl until the API server is back. The backup is at `/tmp/ex-5-2-etcd.yaml.bak` inside the node as well.

**Verification:**

```bash
# kubectl is back after the recovery:
kubectl get nodes
# Expected: four nodes Ready (after some seconds).

# All four control plane components are Running and Ready:
kubectl get pods -n kube-system \
  -o custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[0].ready \
  | grep -E 'kube-(apiserver|scheduler|controller-manager)|etcd'
# Expected: four lines, all with READY true.

# etcd itself responds to a health probe:
nerdctl exec kind-control-plane bash -c '
  CID=$(crictl ps --name etcd -q | head -1)
  crictl exec "$CID" etcdctl \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
    --cert=/etc/kubernetes/pki/etcd/server.crt \
    --key=/etc/kubernetes/pki/etcd/server.key \
    endpoint health
'
# Expected: a line containing "is healthy".
```

---

### Exercise 5.3

**Objective:** Restore full cluster function from a state with two simultaneous control plane failures that do not involve the API server or etcd.

**Setup:**

```bash
nerdctl exec kind-control-plane bash -c '
  cp /etc/kubernetes/manifests/kube-scheduler.yaml /tmp/ex-5-3-sched.yaml.bak
  cp /etc/kubernetes/manifests/kube-controller-manager.yaml /tmp/ex-5-3-cm.yaml.bak

  # Break the scheduler: wrong kubeconfig flag value.
  sed -i "s|--kubeconfig=/etc/kubernetes/scheduler.conf|--kubeconfig=/etc/kubernetes/wrong-scheduler.conf|" \
    /etc/kubernetes/manifests/kube-scheduler.yaml

  # Break the controller-manager: unrecognized flag.
  sed -i "/- kube-controller-manager$/a\\    - --not-a-real-flag=true" \
    /etc/kubernetes/manifests/kube-controller-manager.yaml
'
sleep 30
```

**Task:**

After the setup, two control plane components are not Ready. kubectl still works because the API server and etcd are healthy. Diagnose each failure independently (do not assume they are related), fix both manifests, and confirm the cluster is fully operational. Backups are at `/tmp/ex-5-3-sched.yaml.bak` and `/tmp/ex-5-3-cm.yaml.bak` inside the node.

The success criteria below test two downstream consequences: the scheduler is functioning (a probe pod reaches Ready) and the controller manager is reconciling (a Deployment reaches Available).

**Verification:**

```bash
kubectl get pods -n kube-system \
  -o custom-columns=NAME:.metadata.name,READY:.status.containerStatuses[0].ready \
  | grep -E 'kube-(scheduler|controller-manager)'
# Expected:
#   kube-controller-manager-kind-control-plane true
#   kube-scheduler-kind-control-plane true

# Scheduler is scheduling:
kubectl run ex-5-3-probe -n ex-5-3 --image=nginx:1.27 --restart=Never
kubectl wait --for=condition=Ready pod/ex-5-3-probe -n ex-5-3 --timeout=60s
# Expected: pod becomes Ready.
kubectl delete pod ex-5-3-probe -n ex-5-3

# Controller manager is reconciling:
kubectl create deployment ex-5-3-demo -n ex-5-3 --image=nginx:1.27 --replicas=2
kubectl wait --for=condition=Available deployment/ex-5-3-demo -n ex-5-3 --timeout=60s
# Expected: deployment becomes Available 2/2.
kubectl delete deployment ex-5-3-demo -n ex-5-3
```

---

## Cleanup

Delete the exercise namespaces created by the workload-verification probes:

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 \
          ex-3-2 \
          ex-5-3; do
  kubectl delete namespace $ns --ignore-not-found
done
```

Remove any backup files left inside the control plane node:

```bash
nerdctl exec kind-control-plane bash -c '
  rm -f /tmp/ex-*.bak /tmp/ex-*.yaml.bak \
        /tmp/ex-*-notafter-before.txt /tmp/ex-*-verify.txt \
        /tmp/ex-4-3-before.txt /tmp/ex-4-3-after.txt \
        /tmp/etcd.yaml.staged
  ls /tmp | grep -E "^ex-" || echo "all ex- temp files removed"
'
```

If any exercise ended in an unrecoverable cluster state, delete and recreate the cluster per `docs/cluster-setup.md#multi-node-kind-cluster`.

---

## Key Takeaways

Every control plane failure you will encounter on the CKA (and in production kubeadm clusters) manifests through one of a small set of observable symptoms: a control plane static pod is not listed by `kubectl get pods -n kube-system`, a static pod shows CrashLoopBackOff, a static pod is Running but the downstream effect it is supposed to have (pods being scheduled, Deployments producing ReplicaSets, etcd responding to health probes) is not happening, or kubectl itself returns connection errors because the API server is down. The diagnostic path from each symptom to a root cause follows the same four-loop pattern the tutorial teaches: use kubectl when it works, drop to crictl and journalctl inside the node when it does not, read the static pod manifest that kubelet is trying to reconcile, and verify certificates against the cluster CA when a TLS or authentication error shows up.

Static pod manifests in `/etc/kubernetes/manifests/` are the only writable control point kubeadm gives you for the control plane. Every fix in this assignment is either "edit a manifest back to its correct state" or "restart a static pod so a refreshed configuration on disk takes effect." Memorize the four filenames (`etcd.yaml`, `kube-apiserver.yaml`, `kube-controller-manager.yaml`, `kube-scheduler.yaml`), know that renaming a manifest deletes the pod and restoring the name recreates it, and know that `touch`-ing a manifest is the minimum-disruption way to restart the pod without any content change.

`crictl` is the command you reach for when `kubectl` is not available. Its essential commands are `crictl ps`, `crictl logs`, `crictl inspect`, and `crictl exec`. On kind nodes the container runtime is containerd and `crictl` is pre-configured to talk to it; no flags are needed. The equivalence table to keep in your head is: `kubectl get pod` maps to `crictl ps`, `kubectl logs pod` maps to `crictl logs container-id`, `kubectl exec pod -- cmd` maps to `crictl exec container-id cmd`, and `kubectl describe pod` has no single `crictl` analog but is approximated by `crictl inspect container-id`.

Certificate renewal is a two-step operation. The first step, `kubeadm certs renew <name>`, regenerates the certificate file on disk. The second step, restarting the component that uses the cert, is the one most candidates forget. For static pods the second step is `touch /etc/kubernetes/manifests/<component>.yaml` (or `crictl stop` plus `crictl rm` on the container). Without the second step the renewal has no effect; the running component continues to serve the old certificate from memory until some other reason causes it to restart.

Kubeadm manages ten entries total (seven bare certificates plus three kubeconfig files that embed client certs). They sit under three CAs: the cluster CA (`ca`), the etcd CA (`etcd-ca`), and the front-proxy CA (`front-proxy-ca`). Knowing which CA signed which cert is the key to debugging verification failures with `openssl verify`: if a cert says it was signed by the etcd-ca in the `check-expiration` table, verify it against `/etc/kubernetes/pki/etcd/ca.crt`, not against the cluster CA.

The recovery mindset matters. When the control plane is broken, fight the urge to delete and recreate the cluster. The exercises above are designed to be recoverable through manifest edits alone. In production you rarely have the option to recreate. Practicing in-place recovery on a disposable cluster is the best preparation for the times when in-place recovery is the only option.
