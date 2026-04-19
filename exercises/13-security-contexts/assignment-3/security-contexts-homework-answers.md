# Read-Only Root Filesystem and seccomp Profiles Homework Answers

Complete solutions. Level 3 and Level 5 debugging answers follow the three-stage structure (diagnosis, what the bug is and why, fix).

---

## Exercise 1.1 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: immutable
  namespace: ex-1-1
spec:
  containers:
  - name: app
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      readOnlyRootFilesystem: true
```

The rootfs overlay is mounted read-only. Any write (for example, `echo test > /tmp/file`) returns `EROFS` and the shell prints `Read-only file system`. This is the signature error to recognize in the debugging exercises.

---

## Exercise 1.2 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: immutable-tmp
  namespace: ex-1-2
spec:
  containers:
  - name: app
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
```

`emptyDir` mounts at `/tmp` replace the rootfs path with a writable volume. Writes to `/tmp` succeed because they land on the `emptyDir` tmpfs-backed filesystem. Writes anywhere else on the rootfs still fail with `EROFS`.

---

## Exercise 1.3 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-immutable
  namespace: ex-1-3
spec:
  containers:
  - name: web
    image: nginx:1.25
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
  - name: tmp
    emptyDir: {}
```

The three write paths nginx needs map to the three mounts. Without any one of them the pod CrashLoopBackOffs because nginx writes to the missing path at start. The CKA exam-style learning is to know the common write paths for nginx (these three), for redis (`/data`), for Postgres (its data directory), and similar.

---

## Exercise 2.1 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: runtimedefault
  namespace: ex-2-1
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
```

`Seccomp: 2` confirms the kernel has the filter active; `Seccomp_filters: 1` confirms one filter is loaded. Pod-level setting applies to every container in the pod. Baseline and Restricted PSS profiles require this setting (or `Localhost`).

---

## Exercise 2.2 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: unconfined
  namespace: ex-2-2
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: Unconfined
```

`Seccomp: 0` (SECCOMP_MODE_DISABLED). No filter. PSS Baseline rejects this; Unconfined should only be used for short-lived debugging pods.

---

## Exercise 2.3 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-clock-change
  namespace: ex-2-3
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        add: ["SYS_TIME"]
      seccompProfile:
        type: RuntimeDefault
```

`CAP_SYS_TIME` is granted so the capability check would pass; `clock_settime` is still blocked because containerd's default seccomp profile rejects it with `SCMP_ACT_ERRNO` before the capability check runs. The takeaway: seccomp and capabilities compose, and seccomp runs earlier in the kernel path. If both block an operation, seccomp's error comes out.

---

## Exercise 3.1 Solution

**Diagnosis.**

```bash
kubectl get pod -n ex-3-1 pidfile-fail
kubectl logs -n ex-3-1 pidfile-fail --previous
```

Previous-log output: `sh: can't create /var/run/app.pid: Read-only file system`. Rootfs is read-only, `/var/run` is on the rootfs, the write fails.

**What the bug is and why.** `readOnlyRootFilesystem: true` protects every rootfs path including `/var/run`. The PID write fails with `EROFS`, the command exits non-zero, Kubernetes restarts the container, and the loop repeats.

**Fix.** Mount an `emptyDir` at `/var/run`.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pidfile-fail
  namespace: ex-3-1
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
    volumeMounts:
    - name: run
      mountPath: /var/run
  volumes:
  - name: run
    emptyDir: {}
```

---

## Exercise 3.2 Solution

**Diagnosis.**

```bash
kubectl get pod -n ex-3-2 blocked-syscall
kubectl get events -n ex-3-2 --field-selector involvedObject.name=blocked-syscall --sort-by=.lastTimestamp
```

Events show a container-create error. Container start invokes `clone()` (or `clone3()`) to create the init process; the profile denies `clone`. The container cannot even execute its command.

**What the bug is and why.** The seccomp profile includes `clone` in its ERRNO list. Starting a container requires `clone()` for namespace and thread creation; the runtime fails before the command runs. The intent of the profile (block `unshare`/`setns` to prevent namespace escape) is reasonable; including `clone` was the mistake.

**Fix.** Edit the profile on the kind node to remove `clone` from the blocked list, leaving only `unshare` and `setns`.

```bash
cat <<'EOF' > /tmp/deny-unshare.json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": ["unshare", "setns"],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
EOF
nerdctl cp /tmp/deny-unshare.json kind-control-plane:/var/lib/kubelet/seccomp/deny-unshare.json

kubectl delete pod -n ex-3-2 blocked-syscall
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

---

## Exercise 3.3 Solution

**Diagnosis.**

```bash
kubectl get pod -n ex-3-3 profile-missing
kubectl get events -n ex-3-3 --field-selector involvedObject.name=profile-missing --sort-by=.lastTimestamp
```

The event shows an error mentioning `no such file or directory` at `/var/lib/kubelet/seccomp/nonexistent-profile.json`. The referenced profile does not exist on the node.

**What the bug is and why.** `Localhost` profiles are JSON files under `/var/lib/kubelet/seccomp/` on every node. The kubelet resolves the `localhostProfile` field by opening that path; if the file does not exist, the container cannot start. The spec passes API validation because the Kubernetes API does not verify file existence on nodes.

**Fix.** Either create the file on the kind node (cp a valid profile with that name) or switch to `RuntimeDefault` which requires no file.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: profile-missing
  namespace: ex-3-3
spec:
  containers:
  - name: app
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: RuntimeDefault
```

Either fix works; switching type is the minimal change.

---

## Exercise 4.1 Solution

Profile file:

```json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": ["chmod", "fchmod", "fchmodat", "chown", "fchown", "lchown", "fchownat"],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
```

Copy and apply:

```bash
cat <<'EOF' > /tmp/no-perm-change.json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": ["chmod", "fchmod", "fchmodat", "chown", "fchown", "lchown", "fchownat"],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
EOF
nerdctl cp /tmp/no-perm-change.json kind-control-plane:/var/lib/kubelet/seccomp/no-perm-change.json

kubectl apply -n ex-4-1 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: perm-locked
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: no-perm-change.json
EOF
```

Note the seven syscall names cover both the plain and the `*at`-suffixed variants (modern libc often uses `fchmodat` internally instead of `chmod`). Missing the `*at` variants is a common seccomp-authoring bug.

---

## Exercise 4.2 Solution

Profile file (minimal allow-list for `alpine:3.20` running `sleep 3600`):

```json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "syscalls": [
    {
      "names": [
        "read", "write", "close", "openat", "fstat", "lstat", "newfstatat",
        "mmap", "mprotect", "munmap", "brk",
        "rt_sigaction", "rt_sigprocmask", "rt_sigreturn",
        "ioctl", "readv", "writev",
        "nanosleep", "clock_nanosleep", "clock_gettime",
        "getpid", "getppid", "gettid", "tgkill",
        "exit", "exit_group", "wait4",
        "arch_prctl", "set_tid_address", "set_robust_list", "rseq", "getrandom",
        "execve", "fcntl", "dup2", "dup3",
        "clone", "clone3", "futex", "prlimit64",
        "sigaltstack", "uname", "pipe2"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
```

```bash
cat <<'EOF' > /tmp/sleep-only.json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "syscalls": [
    {
      "names": [
        "read", "write", "close", "openat", "fstat", "lstat", "newfstatat",
        "mmap", "mprotect", "munmap", "brk",
        "rt_sigaction", "rt_sigprocmask", "rt_sigreturn",
        "ioctl", "readv", "writev",
        "nanosleep", "clock_nanosleep", "clock_gettime",
        "getpid", "getppid", "gettid", "tgkill",
        "exit", "exit_group", "wait4",
        "arch_prctl", "set_tid_address", "set_robust_list", "rseq", "getrandom",
        "execve", "fcntl", "dup2", "dup3",
        "clone", "clone3", "futex", "prlimit64",
        "sigaltstack", "uname", "pipe2"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
EOF
nerdctl cp /tmp/sleep-only.json kind-control-plane:/var/lib/kubelet/seccomp/sleep-only.json

kubectl apply -n ex-4-2 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: sleep-only
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: sleep-only.json
EOF
```

Iteration pattern if the pod fails. First symptom: `CreateContainerError` or `Pending` with an error event mentioning seccomp. Find the blocked syscall by running a similar container with `Unconfined` and tracing with `strace` locally. Add the syscall to the allow list; `nerdctl cp` the updated JSON; delete and recreate the pod.

---

## Exercise 4.3 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container
  namespace: ex-4-3
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: sleep-only.json
  containers:
  - name: first
    image: alpine:3.20
    command: ["sleep", "3600"]
  - name: second
    image: alpine:3.20
    command: ["sleep", "3600"]
```

Both containers inherit the pod-level profile. `Seccomp: 2` in each container confirms the filter is applied to both. Container-level `seccompProfile` would override on a per-container basis; with pod-level only, the inheritance is uniform.

---

## Exercise 5.1 Solution

```bash
kubectl apply -n ex-5-1 -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-conf
data:
  default.conf: |
    server {
      listen 8080;
      location / {
        return 200 "fully-hardened\n";
      }
    }
EOF

kubectl apply -n ex-5-1 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: fully-hardened
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
    runAsGroup: 101
    fsGroup: 101
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: web
    image: nginx:1.25
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
        add: ["NET_BIND_SERVICE"]
    ports:
    - containerPort: 8080
    volumeMounts:
    - name: conf
      mountPath: /etc/nginx/conf.d
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: conf
    configMap:
      name: nginx-conf
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
  - name: tmp
    emptyDir: {}
EOF
```

Every field listed in the task is present. `NET_BIND_SERVICE` is included so nginx could bind to port 80 if needed (it listens on 8080, where the capability is not required, but the add is harmless and matches the common hardened pattern). A write into `/usr/share/nginx/blocker` fails with `EROFS`, proving the rootfs is protected. This is the canonical shape PSS Restricted permits; the same pod would pass `pod-security.kubernetes.io/enforce: restricted` on its namespace.

---

## Exercise 5.2 Solution

**Diagnosis.**

```bash
kubectl get pod -n ex-5-2 cascade
kubectl logs -n ex-5-2 cascade | head -n 5
```

If the pod is stuck: the likely cause is the `runAsNonRoot: true` at pod level with no `runAsUser` on the container that overrides. Look at the container status. In this case `runAsUser: 1000` is at pod level, which satisfies the validator.

The log output when the pod starts shows:

```
starting
chmod failed
pid write failed
data write failed
```

All three of the guarded writes fail. `chmod failed` is the intended seccomp block. `pid write failed` is a `Read-only file system` failure (the rootfs protects `/var/run`). `data write failed` is a `Permission denied` because the emptyDir at `/data` is owned by `root:root` and the container runs as UID 1000 with no `fsGroup`.

**What the bug is and why.**

- `/var/run/app.pid` lands on the read-only rootfs. A writable mount at `/var/run` is missing.
- `/data` is an `emptyDir` owned `root:root` because no `fsGroup` is set at pod level. The non-root container cannot write.
- `chmod /etc/passwd` should fail; that is the intended seccomp block and it does. Nothing to fix there.

**Fix.**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cascade
  namespace: ex-5-2
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
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
    - name: run
      mountPath: /var/run
    - name: data
      mountPath: /data
  volumes:
  - name: run
    emptyDir: {}
  - name: data
    emptyDir: {}
```

Two changes from the broken setup: `fsGroup: 2000` at pod level so `/data` is writable by the non-root container, and a new `emptyDir` mount at `/var/run`. The log after the fix shows `starting`, then only `chmod failed`. PID file and metric file writes succeed.

---

## Exercise 5.3 Solution

```bash
cat <<'EOF' > /tmp/service-locked.json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": ["clock_settime", "unshare", "bpf", "kexec_load"],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
EOF
nerdctl cp /tmp/service-locked.json kind-control-plane:/var/lib/kubelet/seccomp/service-locked.json

kubectl apply -n ex-5-3 -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-conf
data:
  default.conf: |
    server {
      listen 8080;
      location / {
        return 200 "service\n";
      }
    }
EOF

kubectl apply -n ex-5-3 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: service-and-metrics
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1001
    runAsGroup: 1001
    fsGroup: 1001
    seccompProfile:
      type: Localhost
      localhostProfile: service-locked.json
  containers:
  - name: service
    image: nginx:1.25
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
        add: ["NET_BIND_SERVICE"]
    command:
    - sh
    - -c
    - |
      nginx -g 'daemon off;' &
      while true; do
        date > /shared/service.ok
        sleep 5
      done
    volumeMounts:
    - name: conf
      mountPath: /etc/nginx/conf.d
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
    - name: tmp
      mountPath: /tmp
    - name: shared
      mountPath: /shared
    ports:
    - containerPort: 8080
  - name: exporter
    image: alpine:3.20
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
    command:
    - sh
    - -c
    - |
      while true; do
        if [ -s /shared/service.ok ]; then
          echo "$(date -Iseconds) seen $(cat /shared/service.ok)" >> /shared/export.log
        fi
        sleep 5
      done
    volumeMounts:
    - name: shared
      mountPath: /shared
  volumes:
  - name: conf
    configMap:
      name: nginx-conf
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
  - name: tmp
    emptyDir: {}
  - name: shared
    emptyDir: {}
EOF
```

Every field required by Restricted is present on both containers (non-root UID, drop ALL, allowPrivilegeEscalation false, readOnlyRootFilesystem true, seccompProfile set). The `service` container has extra writable mounts because nginx needs them; the `exporter` container only needs `/shared` because `alpine:3.20` plus a shell loop has no rootfs writes. The `fsGroup: 1001` makes `/shared` writable by both containers. The service exec loop writes heartbeats every 5 seconds; the exporter appends timestamped summaries.

---

## Common Mistakes

**1. Turning on `readOnlyRootFilesystem` without mapping every writable path.** The default image has writes to at least one of `/tmp`, `/var/run`, or an application-specific data directory. Forgetting any of them produces a CrashLoopBackOff and the signature error `Read-only file system`. The remediation is to run the pod once without `readOnlyRootFilesystem`, inventory every write (via `strace -e openat` or by tailing the application logs), and add `emptyDir` mounts for each.

**2. Missing the `*at` variants of guarded syscalls in a custom seccomp profile.** Modern libc uses `fchmodat`, `fchownat`, `newfstatat`, `openat`, `mkdirat`, and similar rather than the legacy plain names. A profile that only denies `chmod` misses `fchmodat`, which leaves the ostensibly-blocked operation working via the alternate syscall.

**3. Referencing a Localhost profile that does not exist on the node.** The Kubernetes API does not verify file existence at admission. The first time the pod lands on a node, the kubelet tries to open the file and fails. The event message is explicit, but the pod is stuck. Prevent this by copying the profile before applying the pod and by including the profile in any cluster-provisioning script.

**4. Using `Unconfined` as a shortcut during debugging and forgetting to remove it.** `Unconfined` turns off every seccomp protection. PSS Baseline rejects it. Even for debugging, prefer to iterate on a `Localhost` profile over disabling filtering entirely.

**5. Putting `readOnlyRootFilesystem` at pod level.** The field lives on `spec.containers[*].securityContext` only, not on `spec.securityContext`. Setting it at pod level silently does nothing.

**6. Expecting `RuntimeDefault` to block an application-specific syscall.** `RuntimeDefault` is conservative: it blocks only syscalls that are universally dangerous for containerized workloads. If you need to block application-specific syscalls (say, preventing a workload from ever calling `ptrace`), author a `Localhost` profile.

**7. Forgetting that seccomp runs before capability checks.** If the failing syscall is both seccomp-blocked and capability-required, the error message is about seccomp (`EPERM` from the runtime's seccomp layer), not about capabilities. Adding the capability does not help; modify the seccomp profile instead.

**8. Running an init container as root alongside a main container with `runAsNonRoot: true` at pod level.** The pod-level validator checks every container, including init. If the init container needs to run as root (for example, to pre-populate a volume), override `runAsUser: 0` and `runAsNonRoot: false` on that specific init container and keep the main container non-root.

---

## Verification Commands Cheat Sheet

| Check | Command |
|---|---|
| Is the rootfs read-only? | `kubectl exec <pod> -c <c> -- sh -c 'echo x > /tmp/probe 2>&1 || echo PROTECTED'` |
| Seccomp mode | `kubectl exec <pod> -c <c> -- grep "^Seccomp:" /proc/self/status` |
| Number of seccomp filters | `kubectl exec <pod> -c <c> -- grep "^Seccomp_filters:" /proc/self/status` |
| Profile being applied | `kubectl get pod <pod> -o jsonpath='{.spec.securityContext.seccompProfile}{"\n"}{range .spec.containers[*]}{.name}: {.securityContext.seccompProfile}{"\n"}{end}'` |
| Profiles available on the node | `nerdctl exec kind-control-plane ls /var/lib/kubelet/seccomp/` |
| Copy a profile to the node | `nerdctl cp <profile>.json kind-control-plane:/var/lib/kubelet/seccomp/<profile>.json` |
| Events for a failed pod | `kubectl get events --field-selector involvedObject.name=<pod> --sort-by=.lastTimestamp` |
| Full spec of every container's securityContext | `kubectl get pod <pod> -o jsonpath='{.spec.securityContext}{"\n---\n"}{range .spec.containers[*]}{.name}: {.securityContext}{"\n"}{end}'` |
