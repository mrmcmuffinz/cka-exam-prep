# Read-Only Root Filesystem and seccomp Profiles Homework

Fifteen exercises covering `readOnlyRootFilesystem`, `seccompProfile` (with `RuntimeDefault`, `Localhost`, and `Unconfined`), and the combination of every security-context field from assignments 1, 2, and 3 into the Restricted baseline. Work through the tutorial first, because the Level 4 custom-profile exercises and Level 5 comprehensive scenarios reuse its `nerdctl cp` workflow.

Exercise namespaces follow `ex-<level>-<exercise>`. The global cleanup block at the bottom removes every namespace. Some exercises require copying JSON profile files to the kind node's `/var/lib/kubelet/seccomp/` directory; the setup blocks do that for you.

---

## Level 1: Read-Only Root Filesystem

### Exercise 1.1

**Objective:** Enable `readOnlyRootFilesystem: true` and confirm writes to the rootfs fail with `Read-only file system`.

**Setup:**

```bash
kubectl create namespace ex-1-1
```

**Task:** In namespace `ex-1-1`, create a pod named `immutable` running image `alpine:3.20` with command `["sleep", "3600"]` and `readOnlyRootFilesystem: true`.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/immutable -n ex-1-1 --timeout=60s

kubectl exec -n ex-1-1 immutable -- sh -c 'echo test > /tmp/file 2>&1 || true'
# Expected: sh: can't create /tmp/file: Read-only file system

kubectl get pod -n ex-1-1 immutable -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}'
# Expected: true
```

---

### Exercise 1.2

**Objective:** Enable `readOnlyRootFilesystem` and provide a writable `/tmp` via `emptyDir`.

**Setup:**

```bash
kubectl create namespace ex-1-2
```

**Task:** In namespace `ex-1-2`, create a pod named `immutable-tmp` running image `alpine:3.20` with command `["sleep", "3600"]`, `readOnlyRootFilesystem: true`, and an `emptyDir` mounted at `/tmp`. The container must be able to write to `/tmp/test-file`.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/immutable-tmp -n ex-1-2 --timeout=60s

kubectl exec -n ex-1-2 immutable-tmp -- sh -c 'echo hello > /tmp/test-file && cat /tmp/test-file'
# Expected: hello

kubectl exec -n ex-1-2 immutable-tmp -- sh -c 'echo blocked > /etc/blocker 2>&1 || true'
# Expected (substring): Read-only file system
```

---

### Exercise 1.3

**Objective:** Identify every writable path an application needs and supply all of them via `emptyDir` mounts.

**Setup:**

```bash
kubectl create namespace ex-1-3
```

**Task:** In namespace `ex-1-3`, run nginx. The stock `nginx:1.25` image needs write access to `/var/cache/nginx` (proxy cache), `/var/run` (pidfile), and `/tmp` (temporary files). Create a pod named `nginx-immutable` running `nginx:1.25` with `readOnlyRootFilesystem: true` and three `emptyDir` volumes mounted at those three paths.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/nginx-immutable -n ex-1-3 --timeout=60s

kubectl exec -n ex-1-3 nginx-immutable -- wget -qO- http://localhost/ | head -c 15
# Expected: <!DOCTYPE html

kubectl get pod -n ex-1-3 nginx-immutable -o jsonpath='{.status.containerStatuses[0].restartCount}'
# Expected: 0
```

---

## Level 2: seccomp Basics

### Exercise 2.1

**Objective:** Apply `RuntimeDefault` at pod level and confirm it is active.

**Setup:**

```bash
kubectl create namespace ex-2-1
```

**Task:** In namespace `ex-2-1`, create a pod named `runtimedefault` running image `alpine:3.20` with command `["sleep", "3600"]` and `seccompProfile.type: RuntimeDefault` at pod level.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/runtimedefault -n ex-2-1 --timeout=60s

kubectl exec -n ex-2-1 runtimedefault -- grep "^Seccomp:" /proc/self/status | awk '{print $2}'
# Expected: 2

kubectl exec -n ex-2-1 runtimedefault -- grep "^Seccomp_filters:" /proc/self/status | awk '{print $2}'
# Expected: 1

kubectl get pod -n ex-2-1 runtimedefault -o jsonpath='{.spec.securityContext.seccompProfile.type}'
# Expected: RuntimeDefault
```

---

### Exercise 2.2

**Objective:** Demonstrate that `Unconfined` disables filtering by reading the Seccomp line in `/proc/self/status`.

**Setup:**

```bash
kubectl create namespace ex-2-2
```

**Task:** In namespace `ex-2-2`, create a pod named `unconfined` running image `alpine:3.20` with command `["sleep", "3600"]` and `seccompProfile.type: Unconfined`.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/unconfined -n ex-2-2 --timeout=60s

kubectl exec -n ex-2-2 unconfined -- grep "^Seccomp:" /proc/self/status | awk '{print $2}'
# Expected: 0

kubectl exec -n ex-2-2 unconfined -- grep "^Seccomp_filters:" /proc/self/status | awk '{print $2}'
# Expected: 0

kubectl get pod -n ex-2-2 unconfined -o jsonpath='{.spec.containers[0].securityContext.seccompProfile.type}'
# Expected: Unconfined
```

---

### Exercise 2.3

**Objective:** Observe that `RuntimeDefault` blocks `clock_settime` even when `CAP_SYS_TIME` is granted, and understand why.

**Setup:**

```bash
kubectl create namespace ex-2-3
```

**Task:** In namespace `ex-2-3`, create a pod named `no-clock-change` running image `alpine:3.20` with command `["sleep", "3600"]`, `capabilities.add: ["SYS_TIME"]`, and `seccompProfile.type: RuntimeDefault`.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/no-clock-change -n ex-2-3 --timeout=60s

kubectl exec -n ex-2-3 no-clock-change -- sh -c 'date -s "2030-01-01" 2>&1 || true' | grep -o 'Operation not permitted'
# Expected: Operation not permitted

kubectl exec -n ex-2-3 no-clock-change -- grep "^Seccomp:" /proc/self/status | awk '{print $2}'
# Expected: 2
```

---

## Level 3: Debugging

### Exercise 3.1

**Objective:** The container below is crashing because the application cannot write its PID file. Find and fix the problem without disabling `readOnlyRootFilesystem`.

**Setup:**

```bash
kubectl create namespace ex-3-1
kubectl apply -n ex-3-1 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pidfile-fail
spec:
  containers:
  - name: app
    image: alpine:3.20
    command:
    - sh
    - -c
    - |
      echo $$ > /var/run/app.pid
      exec sleep 3600
    securityContext:
      readOnlyRootFilesystem: true
EOF
```

**Task:** Modify the pod so the PID file write succeeds and the pod reaches `Running`. Keep `readOnlyRootFilesystem: true`; add the minimum writable mount needed.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/pidfile-fail -n ex-3-1 --timeout=60s

kubectl exec -n ex-3-1 pidfile-fail -- test -s /var/run/app.pid
echo $?
# Expected: 0

kubectl get pod -n ex-3-1 pidfile-fail -o jsonpath='{.status.containerStatuses[0].restartCount}'
# Expected: 0

kubectl get pod -n ex-3-1 pidfile-fail -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}'
# Expected: true
```

---

### Exercise 3.2

**Objective:** The container below is failing to start. Identify whether the cause is seccomp, capabilities, or filesystem, and apply the minimal fix.

**Setup:**

```bash
kubectl create namespace ex-3-2
cat <<'EOF' > /tmp/deny-unshare.json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": ["unshare", "setns", "clone"],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
EOF
nerdctl cp /tmp/deny-unshare.json kind-control-plane:/var/lib/kubelet/seccomp/deny-unshare.json

kubectl apply -n ex-3-2 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: blocked-syscall
spec:
  containers:
  - name: app
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: deny-unshare.json
EOF
```

**Task:** The pod never reaches Ready; it fails with a container-create error. Identify the reason and adjust the seccomp profile field so the pod starts successfully while still blocking `unshare`. The minimal correct answer is not to remove the profile; adjust the profile JSON (on the node) so that the kernel-level clone operation required to start an `alpine:3.20` process is allowed, then reapply. Hint: container start uses `clone` heavily.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/blocked-syscall -n ex-3-2 --timeout=90s

kubectl get pod -n ex-3-2 blocked-syscall -o jsonpath='{.status.phase}'
# Expected: Running

kubectl exec -n ex-3-2 blocked-syscall -- sh -c 'unshare --user echo hi 2>&1 || true' | grep -o 'Operation not permitted'
# Expected: Operation not permitted

kubectl get pod -n ex-3-2 blocked-syscall -o jsonpath='{.spec.containers[0].securityContext.seccompProfile.localhostProfile}'
# Expected: deny-unshare.json
```

---

### Exercise 3.3

**Objective:** The container below is stuck at `CreateContainerError`. Diagnose the reason and fix.

**Setup:**

```bash
kubectl create namespace ex-3-3
kubectl apply -n ex-3-3 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: profile-missing
spec:
  containers:
  - name: app
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: nonexistent-profile.json
EOF
```

**Task:** Adjust the pod spec so it reaches `Running`. You may keep the `Localhost` type (fix the profile reference or create the profile) or switch to a different type.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/profile-missing -n ex-3-3 --timeout=60s

kubectl get pod -n ex-3-3 profile-missing -o jsonpath='{.status.phase}'
# Expected: Running
```

---

## Level 4: Custom seccomp Profiles

### Exercise 4.1

**Objective:** Write a Localhost profile that blocks `chmod` and `chown`, copy it to the kind node, and apply it.

**Setup:**

```bash
kubectl create namespace ex-4-1
```

**Task:** Create a JSON file named `no-perm-change.json` with `defaultAction: SCMP_ACT_ALLOW` and an entry denying `chmod`, `fchmod`, `fchmodat`, `chown`, `fchown`, `lchown`, `fchownat`. Copy it to `/var/lib/kubelet/seccomp/no-perm-change.json` on `kind-control-plane`. Then in namespace `ex-4-1`, create a pod named `perm-locked` running image `alpine:3.20` with command `["sleep", "3600"]` and `seccompProfile.type: Localhost` referencing your profile.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/perm-locked -n ex-4-1 --timeout=60s

kubectl exec -n ex-4-1 perm-locked -- sh -c 'touch /tmp/probe && chmod 755 /tmp/probe 2>&1 || true' | grep -o 'Operation not permitted'
# Expected: Operation not permitted

kubectl exec -n ex-4-1 perm-locked -- ls -la /tmp/probe
# Expected: line with -rw-r--r-- (original umask, because chmod was blocked)

kubectl get pod -n ex-4-1 perm-locked -o jsonpath='{.spec.containers[0].securityContext.seccompProfile.localhostProfile}'
# Expected: no-perm-change.json
```

---

### Exercise 4.2

**Objective:** Write a profile that denies by default but allows the syscalls needed to run `sleep`. Iterate until the pod stays `Running`.

**Setup:**

```bash
kubectl create namespace ex-4-2
```

**Task:** Create `sleep-only.json` on the kind node at `/var/lib/kubelet/seccomp/sleep-only.json` with `defaultAction: SCMP_ACT_ERRNO` and an `SCMP_ACT_ALLOW` list that is sufficient to run `alpine:3.20`'s `sleep 3600`. In namespace `ex-4-2`, create a pod named `sleep-only` using this profile and command `["sleep", "3600"]`.

**Hint:** `sleep` is part of busybox under `alpine:3.20`. Typical syscalls needed include `read`, `write`, `close`, `openat`, `fstat`, `lstat`, `newfstatat`, `mmap`, `mprotect`, `munmap`, `brk`, `rt_sigaction`, `rt_sigprocmask`, `rt_sigreturn`, `arch_prctl`, `set_tid_address`, `set_robust_list`, `rseq`, `getrandom`, `execve`, `clone`, `clone3`, `wait4`, `exit`, `exit_group`, `nanosleep`, `clock_nanosleep`, `clock_gettime`, `prlimit64`, `fcntl`, `getpid`, `futex`, `uname`, `tgkill`.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/sleep-only -n ex-4-2 --timeout=90s

kubectl get pod -n ex-4-2 sleep-only -o jsonpath='{.status.phase}'
# Expected: Running

kubectl exec -n ex-4-2 sleep-only -- grep "^Seccomp_filters:" /proc/self/status | awk '{print $2}'
# Expected: 1
```

---

### Exercise 4.3

**Objective:** Apply a profile at pod level and observe that it applies to every container.

**Setup:**

```bash
kubectl create namespace ex-4-3
```

**Task:** Reuse the `sleep-only.json` profile from 4.2. In namespace `ex-4-3`, create a pod named `multi-container` with two containers, both image `alpine:3.20` with command `["sleep", "3600"]`. Apply `seccompProfile.type: Localhost`, `localhostProfile: sleep-only.json` at the pod level so both containers inherit it.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/multi-container -n ex-4-3 --timeout=60s

kubectl exec -n ex-4-3 multi-container -c 0 -- grep "^Seccomp:" /proc/self/status | awk '{print $2}' 2>/dev/null || \
  kubectl exec -n ex-4-3 multi-container -c "$(kubectl get pod -n ex-4-3 multi-container -o jsonpath='{.spec.containers[0].name}')" -- grep "^Seccomp:" /proc/self/status | awk '{print $2}'
# Expected: 2

kubectl get pod -n ex-4-3 multi-container -o jsonpath='{.spec.securityContext.seccompProfile.localhostProfile}'
# Expected: sleep-only.json
```

---

## Level 5: Defense in Depth

### Exercise 5.1

**Objective:** Construct a single pod spec that satisfies every security-context field in Pod Security Admission's Restricted profile: `runAsNonRoot: true`, explicit `runAsUser`/`runAsGroup`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]` with minimal `add`, `seccompProfile.type: RuntimeDefault`, `readOnlyRootFilesystem: true`, and every writable path explicitly mounted.

**Setup:**

```bash
kubectl create namespace ex-5-1
```

**Task:** In namespace `ex-5-1`, create a pod named `fully-hardened` that runs `nginx:1.25` and serves HTTP on port 8080 using a ConfigMap-provided nginx config. Include every field listed above. The pod must reach `Running`, serve HTTP on port 8080 inside the container, and fail closed on any hardening-gate check.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/fully-hardened -n ex-5-1 --timeout=60s

kubectl exec -n ex-5-1 fully-hardened -- wget -qO- http://localhost:8080
# Expected: a non-empty response body

kubectl exec -n ex-5-1 fully-hardened -- id -u
# Expected: a non-zero UID

kubectl exec -n ex-5-1 fully-hardened -- grep "^NoNewPrivs:" /proc/self/status | awk '{print $2}'
# Expected: 1

kubectl exec -n ex-5-1 fully-hardened -- grep "^Seccomp:" /proc/self/status | awk '{print $2}'
# Expected: 2

kubectl exec -n ex-5-1 fully-hardened -- sh -c 'echo blocked > /usr/share/nginx/blocker 2>&1 || true' | grep -o 'Read-only file system'
# Expected: Read-only file system

kubectl get pod -n ex-5-1 fully-hardened -o jsonpath='{.spec.containers[0].securityContext.capabilities.drop[0]}'
# Expected: ALL
```

---

### Exercise 5.2

**Objective:** Diagnose and fix a compound failure where multiple security-context layers interact.

**Setup:**

```bash
kubectl create namespace ex-5-2

cat <<'EOF' > /tmp/restricted-demo.json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": ["chmod", "fchmod", "fchmodat", "chown", "fchown", "lchown", "fchownat", "clock_settime"],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
EOF
nerdctl cp /tmp/restricted-demo.json kind-control-plane:/var/lib/kubelet/seccomp/restricted-demo.json

kubectl apply -n ex-5-2 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: cascade
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: Localhost
      localhostProfile: restricted-demo.json
  containers:
  - name: app
    image: alpine:3.20
    command:
    - sh
    - -c
    - |
      echo starting
      chmod 600 /etc/passwd 2>&1 || echo "chmod failed"
      echo $$ > /var/run/app.pid 2>&1 || echo "pid write failed"
      touch /data/metric 2>&1 || echo "data write failed"
      exec sleep 3600
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
EOF
```

**Task:** Make the pod reach `Running`, successfully write the PID file, successfully write `/data/metric`, and have the `chmod /etc/passwd` command fail (because that is the intended seccomp block). Preserve every hardening field. The intended failure is only the `chmod /etc/passwd`. Adjust mounts, identity, or other fields as needed so the other two writes succeed.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/cascade -n ex-5-2 --timeout=90s

kubectl logs -n ex-5-2 cascade | head -n 5
# Expected: starts with "starting", then "chmod failed", then NOT "pid write failed" or "data write failed"

kubectl exec -n ex-5-2 cascade -- test -s /var/run/app.pid
echo $?
# Expected: 0

kubectl exec -n ex-5-2 cascade -- test -e /data/metric
echo $?
# Expected: 0
```

---

### Exercise 5.3

**Objective:** Design a production-style, two-container pod that satisfies Restricted and has a shared metrics volume; write the seccomp profile, copy it to the node, and apply.

**Setup:**

```bash
kubectl create namespace ex-5-3
```

**Task:** In namespace `ex-5-3`, create a pod named `service-and-metrics` with two containers. `service` runs `nginx:1.25` on port 8080, writes metrics to `/shared/service.ok` every 5 seconds, and satisfies Restricted. `exporter` runs `alpine:3.20`, reads from `/shared/service.ok` every 5 seconds and appends a timestamped summary to `/shared/export.log`, and satisfies Restricted. Both containers use a Localhost seccomp profile named `service-locked.json` you create (default allow, deny `clock_settime`, `unshare`, `bpf`, `kexec_load`). Write the profile to the kind node before applying the pod.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/service-and-metrics -n ex-5-3 --timeout=90s

kubectl exec -n ex-5-3 service-and-metrics -c service -- id -u
# Expected: non-zero

kubectl exec -n ex-5-3 service-and-metrics -c exporter -- id -u
# Expected: non-zero

sleep 10
kubectl exec -n ex-5-3 service-and-metrics -c exporter -- wc -l /shared/export.log | awk '{print $1}'
# Expected: >= 1

kubectl exec -n ex-5-3 service-and-metrics -c service -- wget -qO- http://localhost:8080 | head -c 15
# Expected: <!DOCTYPE html

kubectl exec -n ex-5-3 service-and-metrics -c service -- grep "^Seccomp_filters:" /proc/self/status | awk '{print $2}'
# Expected: 1

kubectl get pod -n ex-5-3 service-and-metrics -o jsonpath='{.spec.containers[0].securityContext.readOnlyRootFilesystem}'
# Expected: true
```

---

## Cleanup

Remove every exercise namespace and the custom profile files from the node.

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 \
         ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3; do
  kubectl delete namespace "$ns" --ignore-not-found
done

nerdctl exec kind-control-plane sh -c 'rm -f /var/lib/kubelet/seccomp/deny-unshare.json \
                                              /var/lib/kubelet/seccomp/no-perm-change.json \
                                              /var/lib/kubelet/seccomp/sleep-only.json \
                                              /var/lib/kubelet/seccomp/restricted-demo.json \
                                              /var/lib/kubelet/seccomp/service-locked.json' || true
```

## Key Takeaways

`readOnlyRootFilesystem: true` makes the rootfs immutable; `emptyDir` (or another writable volume type) provides any path that still needs to be writable. `Read-only file system` is the exact error when a write hits the protected rootfs. seccomp `RuntimeDefault` is the containerd-provided safe profile; `Localhost` uses a JSON file at `/var/lib/kubelet/seccomp/<name>` on the scheduled node; `Unconfined` disables filtering. A missing Localhost profile file blocks the pod from starting. The Restricted-compatible baseline combines identity from assignment 1 (`runAsNonRoot`, explicit UID/GID, `fsGroup`), capabilities from assignment 2 (`drop: ALL`, minimal `add`, `allowPrivilegeEscalation: false`), and filesystem/seccomp from this assignment (`readOnlyRootFilesystem: true`, `seccompProfile.type: RuntimeDefault`). Debugging order for "container won't start or operation fails": capabilities first (decode `CapEff`), filesystem second (try a write to the failing path, look for `EROFS`), seccomp third (read `Seccomp` mode, run the failing program under `strace` to find the blocked syscall).
