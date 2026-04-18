# Capabilities and Privilege Control Homework Answers

Complete solutions. Every Level 3 and Level 5 debugging answer follows the three-stage structure (diagnosis, what the bug is and why, fix).

---

## Exercise 1.1 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: inspector
  namespace: ex-1-1
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
```

No `securityContext` is set, so the container inherits containerd's default bounding set. The hex `00000000a80425fb` decodes to fourteen capabilities: `cap_chown`, `cap_dac_override`, `cap_fowner`, `cap_fsetid`, `cap_kill`, `cap_setgid`, `cap_setuid`, `cap_setpcap`, `cap_net_bind_service`, `cap_net_raw`, `cap_sys_chroot`, `cap_mknod`, `cap_audit_write`, `cap_setfcap`. These are the default set containerd grants unprivileged containers.

---

## Exercise 1.2 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: super-user
  namespace: ex-1-2
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
```

`privileged: true` grants every capability and disables several other security-subsystem defaults. `CapEff` shows `000001ffffffffff` (forty-one bits set, covering every defined Linux capability).

---

## Exercise 1.3 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-caps
  namespace: ex-1-3
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        drop: ["ALL"]
```

Dropping `ALL` removes every capability from every capability set (bounding, permitted, effective, inheritable, ambient). `CapEff` is `0000000000000000` and `CapBnd` is `0000000000000000`. The container still runs (processes do not require capabilities for routine operations), but any operation that does require a capability will return `EPERM`.

---

## Exercise 2.1 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: net-admin
  namespace: ex-2-1
spec:
  containers:
  - name: probe
    image: nicolaka/netshoot:v0.13
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        add: ["NET_ADMIN"]
```

`NET_ADMIN` gates network-configuration syscalls including `ioctl(SIOCSIFFLAGS)` which `ip link set <if> down` uses. The loopback interface (`lo`) can be brought down because the process has the capability. The capability name is `NET_ADMIN`, not `CAP_NET_ADMIN`; the Kubernetes API expects the short form.

---

## Exercise 2.2 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-ping
  namespace: ex-2-2
spec:
  containers:
  - name: probe
    image: nicolaka/netshoot:v0.13
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        drop: ["NET_RAW"]
```

`ping` opens a raw ICMP socket (`socket(AF_INET, SOCK_RAW, IPPROTO_ICMP)`); the kernel checks `CAP_NET_RAW` on the calling process. With `NET_RAW` dropped, the socket syscall returns `EPERM` and ping prints `Operation not permitted`. Modern distributions sometimes use a `cap_net_raw+ep` file capability on the ping binary, but even that path requires the bounding set to contain `cap_net_raw`, which was just dropped.

---

## Exercise 2.3 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: minimal
  namespace: ex-2-3
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        drop: ["ALL"]
        add: ["NET_BIND_SERVICE"]
```

Evaluation order for the final capability set: start with containerd's default, drop everything, then add back only the listed entries. The result is exactly `cap_net_bind_service` (hex `0000000000000400`). Pod Security Admission's Restricted profile enforces `drop: [ALL]` and an `add` list constrained to `NET_BIND_SERVICE` only, so this is the canonical Restricted shape.

---

## Exercise 3.1 Solution

**Diagnosis.**

```bash
kubectl get pod -n ex-3-1 broken-host
kubectl logs -n ex-3-1 broken-host --previous
kubectl exec -n ex-3-1 broken-host -- sh -c 'hostname new-name 2>&1' || true
```

Previous logs show `hostname: sethostname: Operation not permitted`. `sethostname(2)` requires `CAP_SYS_ADMIN`. The default bounding set does not include `CAP_SYS_ADMIN`.

**What the bug is and why.** The `hostname <name>` command invokes `sethostname(2)`, which the kernel guards with `CAP_SYS_ADMIN`. Containerd's default bounding set does not include this capability (deliberately, because it covers a wide range of dangerous operations). Without it, the `hostname` command returns `EPERM`, the shell exits non-zero, the pod's main process exits, and Kubernetes restarts the container. The restart loop continues.

**Fix.** Add only `SYS_ADMIN` (not `privileged: true`, which grants everything).

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: broken-host
  namespace: ex-3-1
spec:
  containers:
  - name: app
    image: alpine:3.20
    command: ["sh", "-c", "hostname pod-custom && exec sleep 3600"]
    securityContext:
      capabilities:
        add: ["SYS_ADMIN"]
```

Recreate the pod: `kubectl delete pod -n ex-3-1 broken-host && kubectl apply -n ex-3-1 -f fixed.yaml`.

---

## Exercise 3.2 Solution

**Diagnosis.**

```bash
kubectl get pod -n ex-3-2 sudo-user
kubectl logs -n ex-3-2 sudo-user --previous | tail -n 10
```

Previous logs show `sudo: The "no new privileges" flag is set, which prevents sudo from running as root.`. `sudo` detects the `no_new_privs` kernel flag and refuses to proceed; this is a built-in sudo sanity check introduced precisely so that sudo does not try to elevate under `no_new_privs` and produce a confusing partial-success state.

**What the bug is and why.** `allowPrivilegeEscalation: false` sets the kernel `no_new_privs` flag on the container process. Any descendant of that process inherits the flag. `sudo` checks the flag and, upon seeing it, prints the exact diagnostic line above and returns non-zero. The pod's setup script relies on `sudo id` returning `uid=0(root)`, and that is precisely what `no_new_privs` prevents.

**Fix.** Remove the explicit `allowPrivilegeEscalation: false` (or set it to `true`), so that `sudo` can elevate. In practice you would almost never want this on a production pod; the right fix is to redesign the workload so it does not depend on sudo. For the exercise as written, the fix is minimal:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sudo-user
  namespace: ex-3-2
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
      allowPrivilegeEscalation: true
```

`NoNewPrivs` in `/proc/self/status` is now `0`, and the `id.out` file contains `uid=0(root)`.

---

## Exercise 3.3 Solution

**Diagnosis.**

```bash
kubectl get pod -n ex-3-3 chowner
kubectl logs -n ex-3-3 chowner --previous
kubectl exec -n ex-3-3 chowner -- sh -c 'chown 2000:2000 /tmp/probe 2>&1' || true
```

Previous logs show `chown: /tmp/evidence: Operation not permitted`. `chown(2)` across UIDs (changing ownership to a different UID than the caller's) requires `CAP_CHOWN`. The pod drops `ALL`, so the default `CAP_CHOWN` from the default set is gone.

**What the bug is and why.** `chown 2000:2000` attempts to change file ownership from the current UID (1000, from `runAsUser`) to UID 2000. The kernel check for cross-UID chown is `CAP_CHOWN`, which is in containerd's default set but was just dropped by `capabilities.drop: ["ALL"]`. Without `CAP_CHOWN`, the syscall returns `EPERM` and the command exits non-zero. The pod's setup script exits before reaching `exec sleep 3600`.

**Fix.** Add just `CHOWN` to the capability list. Do not loosen `drop: ALL` or remove `runAsUser`.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: chowner
  namespace: ex-3-3
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
        add: ["CHOWN"]
```

---

## Exercise 4.1 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-escalate
  namespace: ex-4-1
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 1000
      allowPrivilegeEscalation: false
```

`NoNewPrivs: 1` confirms the kernel flag is set. Any descendant of the main process inherits the flag. Setuid binaries no longer elevate. `id -u` returns 1000, since `runAsUser` dictates that.

---

## Exercise 4.2 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hardened-baseline
  namespace: ex-4-2
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
```

Four controls stacked: non-root validator, explicit non-root UID, no privilege escalation, no capabilities. The container can still do everything a normal user process can (open files per UID/GID rules, read `/proc/self/`, write to writable mounts), but cannot perform any operation that requires a capability, cannot elevate via setuid, and fails closed if the image ever changes to root.

---

## Exercise 4.3 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: with-elevation
  namespace: ex-4-3
spec:
  volumes:
  - name: shared
    emptyDir: {}
  initContainers:
  - name: prepare
    image: alpine:3.20
    command: ["sh", "-c", "cp /bin/busybox /shared/myid && chmod u+s /shared/myid && chown root:root /shared/myid"]
    securityContext:
      runAsUser: 0
    volumeMounts:
    - name: shared
      mountPath: /shared
  containers:
  - name: main
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 1000
      allowPrivilegeEscalation: true
    volumeMounts:
    - name: shared
      mountPath: /shared
---
apiVersion: v1
kind: Pod
metadata:
  name: without-elevation
  namespace: ex-4-3
spec:
  volumes:
  - name: shared
    emptyDir: {}
  initContainers:
  - name: prepare
    image: alpine:3.20
    command: ["sh", "-c", "cp /bin/busybox /shared/myid && chmod u+s /shared/myid && chown root:root /shared/myid"]
    securityContext:
      runAsUser: 0
    volumeMounts:
    - name: shared
      mountPath: /shared
  containers:
  - name: main
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 1000
      allowPrivilegeEscalation: false
    volumeMounts:
    - name: shared
      mountPath: /shared
```

Important detail: `alpine:3.20` uses busybox for core utilities. Copying `/bin/busybox` (which implements `id`) as `/shared/myid` gives us a setuid binary. The init container runs as UID 0 so it can set the setuid bit and root ownership. On `with-elevation`, running `myid -u` returns `0` because the setuid bit elevates the calling process. On `without-elevation`, `NoNewPrivs: 1` means the kernel ignores the setuid bit, and `myid -u` returns the calling UID (1000).

---

## Exercise 5.1 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: network-app
  namespace: ex-5-1
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: app
    image: alpine:3.20
    command:
    - sh
    - -c
    - |
      apk add --no-cache libcap busybox-extras > /dev/null
      (nc -l -p 80 &) 2>/dev/null
      exec sleep 3600
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["CHOWN", "NET_BIND_SERVICE"]
```

Requirements mapped to fields: `runAsUser: 1000` plus `runAsNonRoot: true` satisfy "non-root"; `drop: ALL` plus `add: [CHOWN, NET_BIND_SERVICE]` provides exactly the two capabilities named; `allowPrivilegeEscalation: false` is the final hardening bit. `NET_BIND_SERVICE` is the capability that allows binding to ports below 1024 as a non-root user; `CHOWN` allows cross-UID `chown`.

---

## Exercise 5.2 Solution

**Diagnosis.**

```bash
kubectl get pod -n ex-5-2 compound-failure
kubectl get pod -n ex-5-2 compound-failure -o jsonpath='{.status.containerStatuses[0].state.waiting.message}'
kubectl logs -n ex-5-2 compound-failure --previous 2>/dev/null
```

First issue is visible in the containerStatus: `container has runAsNonRoot and image will run as root`. This is the assignment-1 signature: `runAsNonRoot: true` at pod level, no `runAsUser`, `alpine:3.20` image defaults to root.

Second issue: if you fix the first and look at the container log, you see the capability names. The spec lists `CAP_CHOWN` and `CAP_NET_BIND_SERVICE`. Kubernetes accepts capability names without the `CAP_` prefix; with the prefix, the API treats them as strings that do not match any capability and silently drops them.

Third issue: once the container starts and the command runs, the `chown 2000:2000 /work/data` call fails with `Permission denied` because `/work` is an `emptyDir` with owner root and the container runs as a non-root UID. Without `fsGroup`, the non-root process cannot even create `/work/data` in the first place.

**What the bug is and why.**

- Identity: `runAsNonRoot: true` at pod level checks the effective UID (which without `runAsUser` falls through to the image default of 0). The check fails and the container never starts.
- Capability names: the Kubernetes API treats `capabilities.add` entries as plain strings to pass to the runtime. Runtimes expect the short form (`CHOWN`, not `CAP_CHOWN`). With `CAP_` prefixed, no capability matches and the final effective set is empty plus what the runtime coincidentally preserves for root (which in this case is also empty because the drop: ALL is applied). The container process has `CapEff: 0`, so `chown` fails regardless of the intended capability.
- Volume ownership: even with capabilities present, the non-root UID has no write access to `/work` without an `fsGroup` that covers the mount.

**Fix.**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: compound-failure
  namespace: ex-5-2
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
  containers:
  - name: app
    image: alpine:3.20
    command:
    - sh
    - -c
    - |
      apk add --no-cache libcap busybox-extras > /dev/null
      touch /work/data
      (nc -l -p 80 &) 2>/dev/null
      sleep 1
      chown 2000:2000 /work/data 2>&1 || echo "chown failed"
      exec sleep 3600
    securityContext:
      capabilities:
        add: ["CHOWN", "NET_BIND_SERVICE"]
        drop: ["ALL"]
    volumeMounts:
    - name: work
      mountPath: /work
  volumes:
  - name: work
    emptyDir: {}
```

Three changes: add `runAsUser: 1000` at pod level to satisfy `runAsNonRoot`, strip the `CAP_` prefix from capability names, and add `fsGroup: 2000` so `/work` is writable by the non-root container. The script now touches `/work/data` (it previously assumed the file was created elsewhere), runs `nc` in the background, and successfully `chown`s the file.

---

## Exercise 5.3 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: three-sets
  namespace: ex-5-3
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: web
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["NET_BIND_SERVICE"]
  - name: log-rotator
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["CHOWN", "FOWNER"]
  - name: noop
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
```

Each container specifies its own `capabilities` list at container level. Container-level `capabilities` cannot be set at pod level (the Kubernetes spec does not have a pod-level `capabilities` field). `allowPrivilegeEscalation` is settable at container level only as well; the cleanest pattern for a uniform no-escalation guarantee is to set it on every container (or rely on PSA Restricted enforcement, which requires it cluster-wide).

Verify each container's effective set maps exactly to its `add` list:

- `web` CapEff after decode: `cap_net_bind_service` alone.
- `log-rotator` CapEff after decode: `cap_chown,cap_fowner`.
- `noop` CapEff: `0000000000000000` (no capabilities at all).

---

## Common Mistakes

**1. Writing capability names with the `CAP_` prefix.** Kubernetes accepts `NET_ADMIN`, not `CAP_NET_ADMIN`. Writing the long form does not fail validation but has no effect: the capability is not added. The symptom is an operation that fails with `EPERM` even though the spec "has" the capability listed.

**2. Setting `capabilities` at pod level.** The Kubernetes pod spec has `spec.securityContext` but no `capabilities` field under it. `capabilities` lives only on `spec.containers[*].securityContext`. Setting it under `spec.securityContext` is accepted by the API (the field does not exist, so the extra key is ignored) but has no effect.

**3. Using `privileged: true` as a shortcut for "add this one capability."** Privileged containers get every capability and disable several other security layers. If you need `NET_ADMIN`, add `NET_ADMIN`, not `privileged: true`.

**4. Forgetting that `drop: ALL` drops the default set too.** The default set includes `CAP_CHOWN`, `CAP_NET_RAW`, `CAP_NET_BIND_SERVICE`, and others. Any workload that depended on them silently (because they were always available) breaks after `drop: ALL` unless the required ones are re-added via `add`.

**5. Setting `allowPrivilegeEscalation: false` on a workload that needs sudo.** `sudo` checks `no_new_privs` and refuses to run. Rewrite the workload so it does not need sudo (run the whole container as the target UID, or use separate containers for privileged setup and unprivileged runtime).

**6. Interpreting `NoNewPrivs: 0` on a securityContext that sets `allowPrivilegeEscalation: false`.** The kernel flag is per-thread and is set after exec of the container init process. A check from inside the container's shell should return `1`. If it returns `0`, the flag was not applied; usually this means the field was misplaced (set at pod level instead of container level, for example) or the container is `privileged: true`, which disables `no_new_privs` regardless.

**7. Expecting `allowPrivilegeEscalation` to block privilege acquisition from `capabilities.add`.** It does not. `capabilities.add` grants capabilities to the container at start time; `no_new_privs` only prevents gaining new privileges after exec of a setuid binary. These are orthogonal controls.

**8. Confusing `CAP_SYS_ADMIN` with "sys admin" level privilege.** `CAP_SYS_ADMIN` is a catch-all that includes many operations (mount, pivot_root, sethostname, setdomainname, and about twenty others); in practice it is almost as dangerous as full root. If you only need one of the guarded syscalls (say, `sethostname`), there is no finer-grained capability; you still need `CAP_SYS_ADMIN`. That is why `SYS_ADMIN` is one of the capabilities Restricted categorically forbids in `add`.

---

## Verification Commands Cheat Sheet

| Check | Command |
|---|---|
| Effective capabilities (hex mask) | `kubectl exec <pod> -c <container> -- grep "^CapEff" /proc/self/status` |
| Decoded effective capabilities | `kubectl exec <pod> -c <container> -- sh -c 'capsh --decode=$(awk "/^CapEff/ {print \$2}" /proc/self/status)'` |
| Bounding set (maximum allowed) | `kubectl exec <pod> -c <container> -- grep "^CapBnd" /proc/self/status` |
| `no_new_privs` flag | `kubectl exec <pod> -c <container> -- grep "^NoNewPrivs" /proc/self/status` |
| File capabilities on a binary | `kubectl exec <pod> -c <container> -- getcap /path/to/binary` |
| Show container securityContext | `kubectl get pod <pod> -o jsonpath='{range .spec.containers[*]}{.name}: {.securityContext}{"\n"}{end}'` |
| Find which syscall needs which capability | `man 7 capabilities` (local, not via kubectl) |
