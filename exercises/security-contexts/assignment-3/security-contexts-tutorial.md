# Read-Only Root Filesystem and seccomp Profiles Tutorial

`readOnlyRootFilesystem` makes the container's root filesystem immutable at runtime. The rootfs is the layered OCI image filesystem plus the scratch overlay containerd creates for writes; flipping the flag mounts the overlay read-only. An attacker who gains code execution in the container cannot persist an implant, modify application binaries, or write a crash-dump analyzer unless the container also exposes a specific writable mount for the path they target. The trade-off is that the application must have every writable path (typically `/tmp`, log directories, any pidfile or lockfile directories, and any runtime-generated configuration paths) explicitly mounted as an `emptyDir` or `tmpfs`.

seccomp (secure computing) is a Linux kernel feature that filters which system calls a process can make. containerd's default seccomp profile (`RuntimeDefault`) blocks about fifty syscalls that are dangerous for containers, including `kexec_load`, `bpf` (except for unprivileged uses), `userfaultfd`, `clock_settime`, and several keyring operations. This default profile is the same cross-runtime recommended baseline, and Pod Security Admission's Baseline profile requires it. `Unconfined` disables filtering entirely (almost never appropriate). `Localhost` uses a custom JSON profile stored on the node filesystem, which is how you tighten filtering below `RuntimeDefault` or relax it for specific syscalls a workload needs.

Together with identity (assignment 1) and capabilities (assignment 2), these two fields complete the Restricted profile's security-context requirements. A pod that satisfies Restricted has `runAsNonRoot: true`, an explicit non-root `runAsUser`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]` plus a minimal `add`, `seccompProfile.type` set to `RuntimeDefault` or `Localhost`, and volumes drawn from a short allowlist (`configMap`, `csi`, `downwardAPI`, `emptyDir`, `ephemeral`, `persistentVolumeClaim`, `projected`, `secret`). `readOnlyRootFilesystem` is not required by Restricted at the pod level but is strongly recommended and is the PSS Baseline recommendation.

## Prerequisites

Any single-node kind cluster works. See `docs/cluster-setup.md#single-node-kind-cluster`. Custom seccomp profiles require access to the kind node's filesystem, which is achieved with `nerdctl exec` and `nerdctl cp`. Verify the cluster and that you can exec into the kind node container.

```bash
kubectl get nodes
# Expected: STATUS  Ready

nerdctl ps --filter name=kind-control-plane
# Expected: one line showing the kind-control-plane container is Up
```

Create the tutorial namespace.

```bash
kubectl create namespace tutorial-security-contexts
kubectl config set-context --current --namespace=tutorial-security-contexts
```

## Part 1: `readOnlyRootFilesystem` and the write paths

Apply a pod without `readOnlyRootFilesystem` and confirm a write to `/tmp` succeeds.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: writable-root
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
EOF
kubectl wait --for=condition=Ready pod/writable-root --timeout=60s
kubectl exec writable-root -- sh -c 'echo "test" > /tmp/f && cat /tmp/f'
```

Expected output:

```
test
```

Now apply a pod with `readOnlyRootFilesystem: true` and attempt the same write.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: readonly-root
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      readOnlyRootFilesystem: true
EOF
kubectl wait --for=condition=Ready pod/readonly-root --timeout=60s
kubectl exec readonly-root -- sh -c 'echo "test" > /tmp/f 2>&1 || true'
```

Expected output:

```
sh: can't create /tmp/f: Read-only file system
```

The error signature is exact: `Read-only file system` is the kernel error `EROFS`. Any path on the container's rootfs is now read-only. Fix it by adding an `emptyDir` at `/tmp`.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: readonly-with-tmp
spec:
  containers:
  - name: probe
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
EOF
kubectl wait --for=condition=Ready pod/readonly-with-tmp --timeout=60s
kubectl exec readonly-with-tmp -- sh -c 'echo "test" > /tmp/f && cat /tmp/f'
```

Expected output:

```
test
```

Writes to `/tmp` now succeed because `/tmp` is an `emptyDir` mount, not the root overlay. Any other path still fails.

```bash
kubectl exec readonly-with-tmp -- sh -c 'echo "test" > /var/log/app.log 2>&1 || true'
```

Expected output:

```
sh: can't create /var/log/app.log: Read-only file system
```

Delete the pods.

```bash
kubectl delete pod writable-root readonly-root readonly-with-tmp
```

**Spec field reference for `readOnlyRootFilesystem`:**

- **Type:** `bool`.
- **Valid values:** `true` or `false`.
- **Default:** `false`.
- **Failure mode when misconfigured:** any write to the rootfs returns `EROFS` (`Read-only file system`). Applications that write PID files, scratch output, or rotating logs to their working directory will fail at first write. The remediation is to identify every writable path and mount it explicitly.

### Identifying write paths

To find what paths an application needs writable, run it with `readOnlyRootFilesystem: false` once and watch `/proc/<pid>/mountinfo` and `strace -e openat` or check the image's Dockerfile `VOLUME` directives. In practice, most applications need:

- `/tmp` for scratch files.
- A volume for any data the application produces.
- A volume for any log file the application writes (if not going to stdout/stderr).
- A volume at the path where the application writes a PID file (frequently `/var/run`).

## Part 2: seccomp profile types

The `seccompProfile` field on `spec.securityContext` (pod level) or `spec.containers[*].securityContext` (container level) takes a `type` and optional `localhostProfile` path.

**Spec field reference for `seccompProfile`:**

- **Type:** object with two fields: `type` (string) and `localhostProfile` (string, conditional).
- **Valid `type` values:** `RuntimeDefault`, `Localhost`, `Unconfined`.
- **Default:** depends on the runtime. For containerd with no explicit setting, the OCI spec defaults to `Unconfined` for backward compatibility; however, the kubelet and Pod Security Admission encourage explicit `RuntimeDefault`. Baseline and Restricted profiles require `RuntimeDefault` or `Localhost`.
- **Failure mode when misconfigured:** `Localhost` requires `localhostProfile`; if the profile file does not exist at `/var/lib/kubelet/seccomp/<localhostProfile>` on the node where the pod is scheduled, the pod fails to start with an error about the missing profile.

Apply three pods to compare.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-unconfined
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: Unconfined
EOF

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-runtimedefault
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: RuntimeDefault
EOF

kubectl wait --for=condition=Ready pod/seccomp-unconfined --timeout=60s
kubectl wait --for=condition=Ready pod/seccomp-runtimedefault --timeout=60s
```

Read the seccomp status inside each.

```bash
kubectl exec seccomp-unconfined -- grep -E "^Seccomp|^Seccomp_filters" /proc/self/status
```

Expected output:

```
Seccomp:	0
Seccomp_filters:	0
```

`Seccomp: 0` means `SECCOMP_MODE_DISABLED`. No filter applies.

```bash
kubectl exec seccomp-runtimedefault -- grep -E "^Seccomp|^Seccomp_filters" /proc/self/status
```

Expected output:

```
Seccomp:	2
Seccomp_filters:	1
```

`Seccomp: 2` means `SECCOMP_MODE_FILTER`. One filter is loaded (containerd's default). Delete the pods.

```bash
kubectl delete pod seccomp-unconfined seccomp-runtimedefault
```

## Part 3: Observing `RuntimeDefault` block a syscall

containerd's default profile blocks `clock_settime` because changing the wall clock is dangerous. Apply a pod and try to change time.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: no-clock
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
EOF
kubectl wait --for=condition=Ready pod/no-clock --timeout=60s
kubectl exec no-clock -- sh -c 'date -s "2030-01-01" 2>&1 || true'
```

Expected output (substring):

```
date: clock_settime: Operation not permitted
```

Note the capability `SYS_TIME` is granted (so capabilities are not the block) and the error comes from `clock_settime` specifically: seccomp is returning `EPERM` via `SCMP_ACT_ERRNO` before the kernel even checks capabilities. Delete the pod.

```bash
kubectl delete pod no-clock
```

The signature to learn is: if an operation fails with `Operation not permitted` from a syscall that you know does not require a capability (or for which you have the capability), and `RuntimeDefault` is applied, seccomp is probably the reason. `strace` is the diagnostic tool: run the failing program under `strace` and check which syscall returns `EPERM`.

## Part 4: Custom Localhost profile

Localhost profiles are JSON files on the node at `/var/lib/kubelet/seccomp/<name>.json`. A minimal profile allows a specific set of syscalls and denies everything else, or allows everything and denies a list. The JSON format is the runc-native format.

Create a profile that allows most syscalls but explicitly blocks `chmod` and `chown` (useful for an immutable filesystem even if `readOnlyRootFilesystem` is not applied to every mount).

```bash
cat <<'EOF' > /tmp/block-chown.json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "names": ["chmod", "fchmod", "chown", "fchown", "lchown"],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
EOF

nerdctl cp /tmp/block-chown.json kind-control-plane:/var/lib/kubelet/seccomp/block-chown.json
nerdctl exec kind-control-plane ls /var/lib/kubelet/seccomp/
```

Expected output includes `block-chown.json`.

Apply a pod that uses the profile.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: custom-profile
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: block-chown.json
EOF
kubectl wait --for=condition=Ready pod/custom-profile --timeout=60s
kubectl exec custom-profile -- sh -c 'touch /tmp/f && chmod 777 /tmp/f 2>&1 || true'
```

Expected output:

```
chmod: /tmp/f: Operation not permitted
```

The filter is active. Delete the pod.

```bash
kubectl delete pod custom-profile
```

### What happens if the profile file is missing

If the profile name does not exist on the node at the expected path, the pod will not start. Apply a pod referencing a non-existent profile.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: missing-profile
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: does-not-exist.json
EOF
sleep 5
kubectl get pod missing-profile
kubectl get events --field-selector involvedObject.name=missing-profile --sort-by=.lastTimestamp
```

Expected: events include an error mentioning the missing profile at `/var/lib/kubelet/seccomp/does-not-exist.json`. Clean up.

```bash
kubectl delete pod missing-profile
```

## Part 5: Iterating on a Localhost profile

A realistic workflow: the application fails because seccomp blocks a syscall it needs, you identify the syscall, you add it to the profile, you retry. This is the seccomp version of capability debugging.

Create a restrictive profile that denies by default.

```bash
cat <<'EOF' > /tmp/restrictive.json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "syscalls": [
    {
      "names": [
        "read", "write", "close", "fstat", "lstat", "poll", "mmap", "mprotect",
        "munmap", "brk", "rt_sigaction", "rt_sigprocmask", "rt_sigreturn",
        "ioctl", "readv", "writev", "pipe", "pipe2", "nanosleep",
        "getpid", "getppid", "gettid",
        "exit", "exit_group", "wait4", "kill", "uname",
        "openat", "newfstatat", "arch_prctl", "set_tid_address",
        "set_robust_list", "rseq", "getrandom", "tgkill",
        "execve", "fcntl", "dup", "dup2", "dup3",
        "clone", "clone3", "futex", "prlimit64",
        "sigaltstack", "clock_gettime", "clock_nanosleep"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
EOF

nerdctl cp /tmp/restrictive.json kind-control-plane:/var/lib/kubelet/seccomp/restrictive.json
```

Apply a pod using this profile.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: restrictive
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: restrictive.json
EOF
sleep 3
kubectl get pod restrictive
```

If the pod is stuck (sh needs some syscall that is not in the allow list), iterate: identify the missing syscall via `strace` from outside, add it to the JSON, copy back to the node, delete the pod, reapply. The iteration loop is the core seccomp authoring skill.

In practice for this tutorial, the allow list above is sufficient for `sh -c 'sleep 3600'` to run. Verify.

```bash
kubectl wait --for=condition=Ready pod/restrictive --timeout=30s
kubectl exec restrictive -- sh -c 'echo alive'
```

Expected output: `alive`. Try an operation outside the allow list.

```bash
kubectl exec restrictive -- sh -c 'mkdir /tmp/x 2>&1 || true'
```

Expected output (substring):

```
mkdir: can't create directory '/tmp/x': Operation not permitted
```

`mkdir` uses `mkdirat`, which is not in the allow list. Delete the pod.

```bash
kubectl delete pod restrictive
```

## Part 6: The Restricted baseline, fully assembled

Combine every security-context field from assignments 1, 2, and 3 into the canonical Restricted-compliant pod.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: restricted-baseline
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:1.25
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
        add: ["NET_BIND_SERVICE"]
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: run
      mountPath: /var/run
    - name: cache
      mountPath: /var/cache/nginx
  volumes:
  - name: tmp
    emptyDir: {}
  - name: run
    emptyDir: {}
  - name: cache
    emptyDir: {}
EOF
kubectl wait --for=condition=Ready pod/restricted-baseline --timeout=60s
kubectl exec restricted-baseline -- sh -c 'id && grep "^CapEff\|^NoNewPrivs\|^Seccomp" /proc/self/status'
```

Expected output (exact shape):

```
uid=1000 gid=1000 groups=1000
CapEff:	0000000000000400
NoNewPrivs:	1
Seccomp:	2
Seccomp_filters:	1
```

Non-root identity, minimal capabilities (only `cap_net_bind_service` from the `add`), privilege escalation blocked, seccomp active. Delete the pod.

```bash
kubectl delete pod restricted-baseline
```

## Part 7: Cleanup

Delete the tutorial namespace to remove every resource created in this walkthrough. Remove the profile files from the kind node.

```bash
kubectl delete namespace tutorial-security-contexts
kubectl config set-context --current --namespace=default

nerdctl exec kind-control-plane rm -f /var/lib/kubelet/seccomp/block-chown.json \
                                        /var/lib/kubelet/seccomp/restrictive.json
```

## Reference Commands

| Task | Command |
|---|---|
| Confirm `readOnlyRootFilesystem` is active | `kubectl exec <pod> -- sh -c 'echo x > /tmp/probe 2>&1 || echo PROTECTED'` |
| Seccomp mode and filter count | `kubectl exec <pod> -- grep "^Seccomp" /proc/self/status` |
| Copy a custom profile to the kind node | `nerdctl cp <profile>.json kind-control-plane:/var/lib/kubelet/seccomp/<profile>.json` |
| List profiles on the kind node | `nerdctl exec kind-control-plane ls /var/lib/kubelet/seccomp/` |
| Find events for a failed pod (missing profile) | `kubectl get events --field-selector involvedObject.name=<pod>` |
| Inspect the container's seccomp-related fields | `kubectl get pod <pod> -o jsonpath='{.spec.securityContext.seccompProfile}{"\n"}{range .spec.containers[*]}{.name}: {.securityContext.seccompProfile}{"\n"}{end}'` |

## Key Takeaways

`readOnlyRootFilesystem: true` makes the rootfs immutable; every write path must be mounted explicitly, typically as `emptyDir`. `Read-only file system` (`EROFS`) is the error signature. seccomp has three profile types: `RuntimeDefault` (containerd's default, safe), `Localhost` (custom JSON profile on the node), `Unconfined` (no filter, disallowed by PSS Baseline and above). `Localhost` requires the JSON file at `/var/lib/kubelet/seccomp/<localhostProfile>` on the scheduled node; a missing file blocks the pod. The restricted baseline combines every field across all three assignments: `runAsNonRoot`, explicit `runAsUser`/`runAsGroup`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]` plus minimal `add`, `seccompProfile.type: RuntimeDefault`, `readOnlyRootFilesystem: true`, and explicit `emptyDir` mounts for every writable path. Diagnostic path for "operation X fails" runs: capability check first, then read-only filesystem check, then seccomp check.
