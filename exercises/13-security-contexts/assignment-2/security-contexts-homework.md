# Capabilities and Privilege Control Homework

Fifteen exercises on `capabilities.add`, `capabilities.drop`, `allowPrivilegeEscalation`, and their interactions with identity from assignment 1. Work through the tutorial first. Every debugging exercise in Level 3 and Level 5 expects you to read `/proc/self/status` for the current capability set and to decode it with `capsh`.

Exercise namespaces follow `ex-<level>-<exercise>`. The global cleanup block at the bottom removes every namespace.

---

## Level 1: Inspecting Capabilities

### Exercise 1.1

**Objective:** Run a pod with no explicit capabilities configuration, read its effective capability set from `/proc/self/status`, and decode it.

**Setup:**

```bash
kubectl create namespace ex-1-1
```

**Task:** In namespace `ex-1-1`, create a pod named `inspector` running image `alpine:3.20` with command `["sleep", "3600"]`. Do not set `securityContext`. Install `libcap` inside the container (`apk add --no-cache libcap`) so that `capsh` is available for decoding.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/inspector -n ex-1-1 --timeout=60s

kubectl exec -n ex-1-1 inspector -- apk add --no-cache libcap > /dev/null 2>&1

kubectl exec -n ex-1-1 inspector -- grep "^CapEff" /proc/self/status
# Expected: CapEff: 00000000a80425fb

kubectl exec -n ex-1-1 inspector -- capsh --decode=00000000a80425fb | tr -d '\n'
# Expected (substring): cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service,cap_net_raw,cap_sys_chroot,cap_mknod,cap_audit_write,cap_setfcap
```

---

### Exercise 1.2

**Objective:** Run a pod with `privileged: true`, read `/proc/self/status`, and confirm the full capability set.

**Setup:**

```bash
kubectl create namespace ex-1-2
```

**Task:** In namespace `ex-1-2`, create a pod named `super-user` running image `alpine:3.20` with command `["sleep", "3600"]` and `privileged: true` at container level.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/super-user -n ex-1-2 --timeout=60s

kubectl exec -n ex-1-2 super-user -- grep "^CapEff" /proc/self/status
# Expected: CapEff: 000001ffffffffff (every bit set)

kubectl get pod -n ex-1-2 super-user -o jsonpath='{.spec.containers[0].securityContext.privileged}'
# Expected: true
```

---

### Exercise 1.3

**Objective:** Drop all capabilities, read `/proc/self/status`, and confirm the effective capability set is empty.

**Setup:**

```bash
kubectl create namespace ex-1-3
```

**Task:** In namespace `ex-1-3`, create a pod named `no-caps` running image `alpine:3.20` with command `["sleep", "3600"]` and `capabilities.drop: ["ALL"]`.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/no-caps -n ex-1-3 --timeout=60s

kubectl exec -n ex-1-3 no-caps -- grep "^CapEff" /proc/self/status
# Expected: CapEff: 0000000000000000

kubectl exec -n ex-1-3 no-caps -- grep "^CapBnd" /proc/self/status
# Expected: CapBnd: 0000000000000000
```

---

## Level 2: Adding and Dropping Capabilities

### Exercise 2.1

**Objective:** Add `NET_ADMIN` to a container and prove it can now bring a network interface down.

**Setup:**

```bash
kubectl create namespace ex-2-1
```

**Task:** In namespace `ex-2-1`, create a pod named `net-admin` running image `nicolaka/netshoot:v0.13` with command `["sleep", "3600"]`. Add the `NET_ADMIN` capability at container level.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/net-admin -n ex-2-1 --timeout=60s

kubectl exec -n ex-2-1 net-admin -- ip link set lo down
kubectl exec -n ex-2-1 net-admin -- ip link show lo | grep -o 'state DOWN'
# Expected: state DOWN

kubectl exec -n ex-2-1 net-admin -- ip link set lo up

kubectl get pod -n ex-2-1 net-admin -o jsonpath='{.spec.containers[0].securityContext.capabilities.add[0]}'
# Expected: NET_ADMIN
```

---

### Exercise 2.2

**Objective:** Drop `NET_RAW` from a container and confirm that `ping` (which uses raw sockets) now fails.

**Setup:**

```bash
kubectl create namespace ex-2-2
```

**Task:** In namespace `ex-2-2`, create a pod named `no-ping` running image `nicolaka/netshoot:v0.13` with command `["sleep", "3600"]`. Drop the `NET_RAW` capability at container level.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/no-ping -n ex-2-2 --timeout=60s

kubectl exec -n ex-2-2 no-ping -- sh -c 'ping -c 1 -W 2 127.0.0.1 2>&1 || true' | grep -o 'Operation not permitted'
# Expected: Operation not permitted

kubectl get pod -n ex-2-2 no-ping -o jsonpath='{.spec.containers[0].securityContext.capabilities.drop[0]}'
# Expected: NET_RAW
```

---

### Exercise 2.3

**Objective:** Apply the Restricted-profile pattern: drop ALL, add only `NET_BIND_SERVICE`, and confirm the effective set contains only that one capability.

**Setup:**

```bash
kubectl create namespace ex-2-3
```

**Task:** In namespace `ex-2-3`, create a pod named `minimal` running image `alpine:3.20` with command `["sleep", "3600"]`. At container level, drop ALL capabilities and add only `NET_BIND_SERVICE`.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/minimal -n ex-2-3 --timeout=60s

kubectl exec -n ex-2-3 minimal -- apk add --no-cache libcap > /dev/null 2>&1

kubectl exec -n ex-2-3 minimal -- sh -c 'capsh --decode=$(awk "/^CapEff/ {print \$2}" /proc/self/status)'
# Expected (trailing substring): cap_net_bind_service
# (CapEff value will be 0000000000000400; the decoded output names only cap_net_bind_service)

kubectl get pod -n ex-2-3 minimal -o jsonpath='{.spec.containers[0].securityContext.capabilities.add[0]}'
# Expected: NET_BIND_SERVICE
```

---

## Level 3: Debugging

### Exercise 3.1

**Objective:** The container below is expected to change the system hostname on startup but is crashing. Diagnose the failure and make the container able to complete that operation.

**Setup:**

```bash
kubectl create namespace ex-3-1
kubectl apply -n ex-3-1 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-host
spec:
  containers:
  - name: app
    image: alpine:3.20
    command: ["sh", "-c", "hostname pod-custom && exec sleep 3600"]
EOF
```

**Task:** Modify the pod so it reaches `Running` and `hostname` reports `pod-custom`. Do not use `privileged: true`; grant only the specific capability the operation requires.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/broken-host -n ex-3-1 --timeout=60s

kubectl exec -n ex-3-1 broken-host -- hostname
# Expected: pod-custom

kubectl get pod -n ex-3-1 broken-host -o jsonpath='{.status.containerStatuses[0].restartCount}'
# Expected: 0 (or very low and not increasing)

kubectl get pod -n ex-3-1 broken-host -o jsonpath='{.spec.containers[0].securityContext.privileged}'
# Expected: (empty)
```

---

### Exercise 3.2

**Objective:** The container below is trying to run a `sudo` command on startup but the command keeps failing. Diagnose and fix by adjusting the security context so the command the container runs reaches completion. Do not change the command line.

**Setup:**

```bash
kubectl create namespace ex-3-2
kubectl apply -n ex-3-2 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: sudo-user
spec:
  containers:
  - name: app
    image: alpine:3.20
    command:
    - sh
    - -c
    - |
      apk add --no-cache sudo shadow > /dev/null
      adduser -D worker
      echo "worker ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
      su worker -c 'sudo id' > /id.out
      cat /id.out
      exec sleep 3600
    securityContext:
      allowPrivilegeEscalation: false
EOF
```

**Task:** Get the pod to `Running` with `id.out` containing `uid=0(root)`. Keep the command as-is.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/sudo-user -n ex-3-2 --timeout=120s

kubectl exec -n ex-3-2 sudo-user -- cat /id.out | head -n1
# Expected: starts with uid=0(root)

kubectl exec -n ex-3-2 sudo-user -- grep "^NoNewPrivs" /proc/self/status | awk '{print $2}'
# Expected: 0
```

---

### Exercise 3.3

**Objective:** The pod below is crashing trying to execute a simple chown across UIDs in its container. Diagnose the failure and grant only the minimal capability required without loosening any other security control.

**Setup:**

```bash
kubectl create namespace ex-3-3
kubectl apply -n ex-3-3 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: chowner
spec:
  containers:
  - name: app
    image: alpine:3.20
    command:
    - sh
    - -c
    - |
      touch /tmp/evidence
      chown 2000:2000 /tmp/evidence
      stat -c "%u:%g" /tmp/evidence
      exec sleep 3600
    securityContext:
      runAsUser: 1000
      capabilities:
        drop: ["ALL"]
EOF
```

**Task:** Modify the pod so the `chown` succeeds. Do not raise the UID to 0, do not remove `runAsUser`, do not remove the `drop: ALL`; the only accepted change is to add a single specific capability.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/chowner -n ex-3-3 --timeout=60s

kubectl logs -n ex-3-3 chowner | tail -n1
# Expected: 2000:2000

kubectl get pod -n ex-3-3 chowner -o jsonpath='{.spec.containers[0].securityContext.capabilities.add[0]}'
# Expected: CHOWN

kubectl get pod -n ex-3-3 chowner -o jsonpath='{.spec.containers[0].securityContext.capabilities.drop[0]}'
# Expected: ALL
```

---

## Level 4: Privilege Escalation Control

### Exercise 4.1

**Objective:** Set `allowPrivilegeEscalation: false` on a pod and verify the `NoNewPrivs` kernel flag is set.

**Setup:**

```bash
kubectl create namespace ex-4-1
```

**Task:** In namespace `ex-4-1`, create a pod named `no-escalate` running image `alpine:3.20` with command `["sleep", "3600"]`, `runAsUser: 1000`, and `allowPrivilegeEscalation: false` at container level.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/no-escalate -n ex-4-1 --timeout=60s

kubectl exec -n ex-4-1 no-escalate -- grep "^NoNewPrivs" /proc/self/status | awk '{print $2}'
# Expected: 1

kubectl exec -n ex-4-1 no-escalate -- id -u
# Expected: 1000
```

---

### Exercise 4.2

**Objective:** Apply the defense-in-depth hardening pattern as a single pod spec and prove every control is in effect at once.

**Setup:**

```bash
kubectl create namespace ex-4-2
```

**Task:** In namespace `ex-4-2`, create a pod named `hardened-baseline` running image `alpine:3.20` with command `["sleep", "3600"]`. Apply all of: `runAsNonRoot: true` at pod level, `runAsUser: 1000` at pod level, `allowPrivilegeEscalation: false` at container level, `capabilities.drop: ["ALL"]` at container level.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/hardened-baseline -n ex-4-2 --timeout=60s

kubectl exec -n ex-4-2 hardened-baseline -- id -u
# Expected: 1000

kubectl exec -n ex-4-2 hardened-baseline -- grep "^CapEff" /proc/self/status | awk '{print $2}'
# Expected: 0000000000000000

kubectl exec -n ex-4-2 hardened-baseline -- grep "^NoNewPrivs" /proc/self/status | awk '{print $2}'
# Expected: 1

kubectl get pod -n ex-4-2 hardened-baseline -o jsonpath='{.spec.securityContext.runAsNonRoot}'
# Expected: true
```

---

### Exercise 4.3

**Objective:** Demonstrate that `allowPrivilegeEscalation: false` prevents a setuid binary from elevating privileges.

**Setup:**

```bash
kubectl create namespace ex-4-3
```

**Task:** In namespace `ex-4-3`, create two pods `with-elevation` and `without-elevation`, each running image `alpine:3.20` with command `["sleep", "3600"]` and `runAsUser: 1000`. Set `allowPrivilegeEscalation: true` on the first and `false` on the second. Install `shadow` (`apk add --no-cache shadow`) and create a fake setuid binary in each by copying `/bin/id` to `/tmp/myid` and setting `chmod u+s /tmp/myid`, but do this from an init step that runs as root by also setting `runAsUser: 0` on a separate initContainer (if needed to set the setuid bit). Run `/tmp/myid` as UID 1000 in each pod's main container. The pod with `true` runs the setuid binary as UID 0; the pod with `false` runs it as UID 1000.

**Hint:** Use an `initContainer` with `runAsUser: 0` to prepare `/tmp/myid` on a shared `emptyDir`, then the main container (running as UID 1000) exec the setuid binary.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/with-elevation pod/without-elevation -n ex-4-3 --timeout=120s

kubectl exec -n ex-4-3 with-elevation -c main -- /shared/myid -u
# Expected: 0 (the setuid bit elevated to root)

kubectl exec -n ex-4-3 without-elevation -c main -- /shared/myid -u
# Expected: 1000 (NoNewPrivs blocked the elevation)
```

---

## Level 5: Advanced and Comprehensive

### Exercise 5.1

**Objective:** Design a minimal capability set for an application that must bind to port 80, change ownership of log files across UIDs, and nothing else.

**Setup:**

```bash
kubectl create namespace ex-5-1
```

**Task:** In namespace `ex-5-1`, create a pod named `network-app` running image `alpine:3.20` with a command that installs `libcap`, writes a small TCP echo script with `nc -l -p 80`, and sleeps. The container must run as a non-root UID (`runAsUser: 1000`), drop all capabilities, and add only those needed to bind to port 80 and change ownership across UIDs. Include `allowPrivilegeEscalation: false` and `runAsNonRoot: true`.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/network-app -n ex-5-1 --timeout=60s

kubectl exec -n ex-5-1 network-app -- id -u
# Expected: 1000

kubectl exec -n ex-5-1 network-app -- apk add --no-cache libcap > /dev/null 2>&1

kubectl exec -n ex-5-1 network-app -- sh -c 'capsh --decode=$(awk "/^CapEff/ {print \$2}" /proc/self/status)' | tr -d '\n'
# Expected (substring): cap_chown,cap_net_bind_service

kubectl exec -n ex-5-1 network-app -- grep "^NoNewPrivs" /proc/self/status | awk '{print $2}'
# Expected: 1
```

---

### Exercise 5.2

**Objective:** The pod below is failing to start. There are multiple interacting misconfigurations spanning identity and capabilities. Diagnose every problem, fix them, and reach a working `hardened-baseline`-style configuration.

**Setup:**

```bash
kubectl create namespace ex-5-2
kubectl apply -n ex-5-2 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: compound-failure
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: alpine:3.20
    command:
    - sh
    - -c
    - |
      apk add --no-cache libcap > /dev/null
      nc -l -p 80 &
      sleep 1
      chown 2000:2000 /work/data 2>&1 || echo "chown failed"
      exec sleep 3600
    securityContext:
      capabilities:
        add: ["CAP_CHOWN", "CAP_NET_BIND_SERVICE"]
        drop: ["ALL"]
    volumeMounts:
    - name: work
      mountPath: /work
  volumes:
  - name: work
    emptyDir: {}
EOF
```

**Task:** Get the pod to `Running` with the `chown` succeeding and the `nc -l -p 80` process listening. Preserve `runAsNonRoot: true`, `drop: ALL`, and keep the command unchanged.

**Hints:** There are three problems to find and fix: one with identity (no `runAsUser`), one with capability names (the `CAP_` prefix), and one with volume ownership (`/work` is not writable by the non-root user without `fsGroup`).

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/compound-failure -n ex-5-2 --timeout=90s

kubectl exec -n ex-5-2 compound-failure -- id -u
# Expected: a non-zero UID

kubectl logs -n ex-5-2 compound-failure | grep -v "chown failed"
# Expected: no "chown failed" line

kubectl exec -n ex-5-2 compound-failure -- stat -c "%u:%g" /work/data
# Expected: 2000:2000

kubectl exec -n ex-5-2 compound-failure -- sh -c 'capsh --decode=$(awk "/^CapEff/ {print \$2}" /proc/self/status)' | tr -d '\n'
# Expected (substring): cap_chown,cap_net_bind_service
```

---

### Exercise 5.3

**Objective:** Design and apply a multi-container pod with three containers, each with a different minimum capability set. Prove each container has only its intended capabilities.

**Setup:**

```bash
kubectl create namespace ex-5-3
```

**Task:** In namespace `ex-5-3`, create a pod named `three-sets`. All three containers use image `alpine:3.20` with command `["sleep", "3600"]` and run as `runAsUser: 1000` with `runAsNonRoot: true` at pod level. Container `web` drops ALL and adds `NET_BIND_SERVICE`. Container `log-rotator` drops ALL and adds `CHOWN` and `FOWNER`. Container `noop` drops ALL. Set `allowPrivilegeEscalation: false` at pod level.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/three-sets -n ex-5-3 --timeout=60s

for c in web log-rotator noop; do
  kubectl exec -n ex-5-3 three-sets -c "$c" -- apk add --no-cache libcap > /dev/null 2>&1
done

kubectl exec -n ex-5-3 three-sets -c web -- sh -c 'capsh --decode=$(awk "/^CapEff/ {print \$2}" /proc/self/status)' | tr -d '\n'
# Expected (substring): cap_net_bind_service

kubectl exec -n ex-5-3 three-sets -c log-rotator -- sh -c 'capsh --decode=$(awk "/^CapEff/ {print \$2}" /proc/self/status)' | tr -d '\n'
# Expected (substring): cap_chown,cap_fowner

kubectl exec -n ex-5-3 three-sets -c noop -- grep "^CapEff" /proc/self/status | awk '{print $2}'
# Expected: 0000000000000000

kubectl exec -n ex-5-3 three-sets -c web -- grep "^NoNewPrivs" /proc/self/status | awk '{print $2}'
# Expected: 1
```

---

## Cleanup

Remove every exercise namespace.

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 \
         ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3; do
  kubectl delete namespace "$ns" --ignore-not-found
done
```

## Key Takeaways

Kubernetes accepts capability names without the `CAP_` prefix; writing `CAP_NET_ADMIN` in a spec silently fails. `capabilities` is container-level only. The Restricted-profile baseline is `drop: [ALL]` plus a minimal `add` list. `allowPrivilegeEscalation: false` sets `no_new_privs`, blocking setuid elevation. `privileged: true` is almost never right for application workloads. Debugging a capability failure starts with `grep "^CapEff" /proc/self/status` and a lookup against the syscall's required capability; this is a faster path than guessing.
