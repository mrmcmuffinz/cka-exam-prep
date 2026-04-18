# Security Contexts Homework Answers: Filesystem and seccomp Profiles

This file contains complete solutions for all 15 exercises on filesystem constraints and seccomp profiles.

---

## Exercise 1.1 Solution

**Task:** Enable read-only root filesystem.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: readonly-test
  namespace: ex-1-1
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      readOnlyRootFilesystem: true
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: readonly-test
  namespace: ex-1-1
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      readOnlyRootFilesystem: true
EOF
```

**Explanation:** readOnlyRootFilesystem: true makes the container's root filesystem read-only. Any attempt to write to the filesystem fails with "Read-only file system."

---

## Exercise 1.2 Solution

**Task:** Add emptyDir for writable /tmp.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: readonly-with-tmp
  namespace: ex-1-2
spec:
  containers:
  - name: test
    image: busybox:1.36
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

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: readonly-with-tmp
  namespace: ex-1-2
spec:
  containers:
  - name: test
    image: busybox:1.36
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
```

**Explanation:** The emptyDir volume provides a writable filesystem mounted at /tmp. The root filesystem remains read-only, but /tmp is writable.

---

## Exercise 1.3 Solution

**Task:** Configure multiple writable directories for nginx.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-container
  namespace: ex-1-3
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: app-container
  namespace: ex-1-3
spec:
  containers:
  - name: nginx
    image: nginx:1.25
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
EOF
```

**Explanation:** nginx needs writable directories for temporary files, cache, and PID/socket files. Each is provided by a separate emptyDir volume.

---

## Exercise 2.1 Solution

**Task:** Apply RuntimeDefault seccomp profile.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-runtime
  namespace: ex-2-1
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: RuntimeDefault
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-runtime
  namespace: ex-2-1
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: RuntimeDefault
EOF
```

**Explanation:** RuntimeDefault uses the container runtime's built-in seccomp profile, which blocks dangerous syscalls while allowing normal application operation.

---

## Exercise 2.2 Solution

**Task:** Compare RuntimeDefault and Unconfined.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: with-seccomp
  namespace: ex-2-2
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: RuntimeDefault
---
apiVersion: v1
kind: Pod
metadata:
  name: without-seccomp
  namespace: ex-2-2
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: Unconfined
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: with-seccomp
  namespace: ex-2-2
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: RuntimeDefault
---
apiVersion: v1
kind: Pod
metadata:
  name: without-seccomp
  namespace: ex-2-2
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: Unconfined
EOF
```

**Explanation:** RuntimeDefault provides syscall filtering for security. Unconfined disables filtering entirely, which is less secure and should be avoided in production.

---

## Exercise 2.3 Solution

**Task:** Pod-level vs container-level seccomp.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-levels
  namespace: ex-2-3
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: default-profile
    image: busybox:1.36
    command: ["sleep", "3600"]
  - name: unconfined-profile
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: Unconfined
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-levels
  namespace: ex-2-3
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: default-profile
    image: busybox:1.36
    command: ["sleep", "3600"]
  - name: unconfined-profile
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: Unconfined
EOF
```

**Explanation:** Pod-level seccomp applies to all containers by default. Container-level settings override the pod-level for that specific container.

---

## Exercise 3.1 Solution

**Problem:** The container cannot write to /var/log because the root filesystem is read-only.

**Fix:**

```bash
kubectl delete pod -n ex-3-1 logger-app

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: logger-app
  namespace: ex-3-1
spec:
  containers:
  - name: logger
    image: busybox:1.36
    command: ["sh", "-c", "echo 'log entry' >> /var/log/app.log && sleep 3600"]
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: logs
      mountPath: /var/log
  volumes:
  - name: logs
    emptyDir: {}
EOF
```

**Explanation:** Mount an emptyDir at /var/log to provide writable storage for log files while keeping the root filesystem read-only.

---

## Exercise 3.2 Solution

**Problem:** The custom seccomp profile only allows exit syscalls, which is not enough for a container to run.

**Fix:** Use RuntimeDefault instead of the restrictive custom profile.

```bash
kubectl delete pod -n ex-3-2 restricted-pod

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: restricted-pod
  namespace: ex-3-2
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: RuntimeDefault
EOF
```

**Explanation:** The restrictive profile blocked essential syscalls. RuntimeDefault provides a secure but functional set of allowed syscalls.

---

## Exercise 3.3 Solution

**Problem:** The reader container needs to write to /output but the root filesystem is read-only.

**Fix:**

```bash
kubectl delete pod -n ex-3-3 data-processor

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: data-processor
  namespace: ex-3-3
spec:
  containers:
  - name: writer
    image: busybox:1.36
    command: ["sh", "-c", "echo 'data' > /data/input.txt && sleep 3600"]
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: shared
      mountPath: /data
  - name: reader
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5 && cat /data/input.txt && echo 'done' > /output/result.txt && sleep 3600"]
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: shared
      mountPath: /data
    - name: output
      mountPath: /output
  volumes:
  - name: shared
    emptyDir: {}
  - name: output
    emptyDir: {}
EOF
```

**Explanation:** Add an emptyDir volume mounted at /output for the reader container to write its results.

---

## Exercise 4.1 Solution

**Task:** Apply custom seccomp profile.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: custom-seccomp
  namespace: ex-4-1
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: profiles/basic.json
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: custom-seccomp
  namespace: ex-4-1
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: profiles/basic.json
EOF
```

**Explanation:** The Localhost type references a custom profile from the node's /var/lib/kubelet/seccomp/ directory. The localhostProfile path is relative to that directory.

---

## Exercise 4.2 Solution

**Task:** Apply profile that blocks network syscalls.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-network-pod
  namespace: ex-4-2
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: profiles/no-network.json
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: no-network-pod
  namespace: ex-4-2
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: profiles/no-network.json
EOF
```

**Explanation:** The no-network profile has defaultAction: ALLOW but explicitly blocks socket, connect, and other network syscalls.

---

## Exercise 4.3 Solution

**Task:** Create a fixed seccomp profile.

First, create the fixed profile:

```bash
cat > /tmp/fixed.json << 'EOF'
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64", "SCMP_ARCH_X86", "SCMP_ARCH_X32"],
  "syscalls": [
    {
      "names": [
        "read", "write", "close", "nanosleep", "exit_group",
        "openat", "getdents64", "fstat", "newfstatat", "brk",
        "mmap", "mprotect", "munmap", "rt_sigaction", "rt_sigprocmask",
        "ioctl", "access", "dup2", "getpid", "getuid", "getgid",
        "geteuid", "getegid", "fcntl", "getcwd", "arch_prctl",
        "set_tid_address", "set_robust_list", "prlimit64", "getrandom",
        "close_range", "rseq"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
EOF

# Copy to kind node
KIND_NODE=$(nerdctl ps --format '{{.Names}}' | grep kind-control-plane)
nerdctl cp /tmp/fixed.json $KIND_NODE:/var/lib/kubelet/seccomp/profiles/fixed.json
```

Then create the pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: fixed-profile
  namespace: ex-4-3
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: profiles/fixed.json
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: fixed-profile
  namespace: ex-4-3
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: profiles/fixed.json
EOF
```

**Explanation:** The ls command requires openat, getdents64, fstat, write, and close syscalls. The fixed profile adds these plus other essential syscalls for basic operation.

---

## Exercise 5.1 Solution

**Task:** Configure all recommended security controls.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: fully-hardened
  namespace: ex-5-1
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
    runAsNonRoot: true
    fsGroup: 2000
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: fully-hardened
  namespace: ex-5-1
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
    runAsNonRoot: true
    fsGroup: 2000
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
EOF
```

**Explanation:** This configuration implements all layers of defense in depth: non-root user, read-only filesystem, no capabilities, no privilege escalation, and seccomp filtering.

---

## Exercise 5.2 Solution

**Problem:** The application needs NET_RAW for ping and a writable /tmp.

**Fix:**

```bash
kubectl delete pod -n ex-5-2 secure-app

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: ex-5-2
spec:
  securityContext:
    runAsUser: 1000
    runAsNonRoot: true
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "ping -c 1 127.0.0.1 && echo 'result' > /tmp/output.txt && sleep 3600"]
    securityContext:
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["NET_RAW"]
      seccompProfile:
        type: RuntimeDefault
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
EOF
```

**Explanation:** Two fixes were needed:
1. Add NET_RAW capability for ping (while still dropping ALL and adding only what is needed)
2. Add emptyDir for /tmp to enable writing the output file

---

## Exercise 5.3 Solution

**Task:** Design a production-like secure deployment.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: production-app
  namespace: ex-5-3
spec:
  securityContext:
    fsGroup: 3000
  containers:
  - name: api
    image: nginx:1.25
    securityContext:
      runAsUser: 101
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["NET_BIND_SERVICE"]
      seccompProfile:
        type: RuntimeDefault
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
    - name: logs
      mountPath: /logs
  - name: logger
    image: busybox:1.36
    command: ["sh", "-c", "while true; do echo 'heartbeat' >> /logs/heartbeat.log; sleep 10; done"]
    securityContext:
      runAsUser: 1000
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
    volumeMounts:
    - name: logs
      mountPath: /logs
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
  - name: logs
    emptyDir: {}
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: production-app
  namespace: ex-5-3
spec:
  securityContext:
    fsGroup: 3000
  containers:
  - name: api
    image: nginx:1.25
    securityContext:
      runAsUser: 101
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["NET_BIND_SERVICE"]
      seccompProfile:
        type: RuntimeDefault
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
    - name: logs
      mountPath: /logs
  - name: logger
    image: busybox:1.36
    command: ["sh", "-c", "while true; do echo 'heartbeat' >> /logs/heartbeat.log; sleep 10; done"]
    securityContext:
      runAsUser: 1000
      readOnlyRootFilesystem: true
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
    volumeMounts:
    - name: logs
      mountPath: /logs
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
  - name: logs
    emptyDir: {}
EOF
```

**Explanation:** This production-like configuration demonstrates:
- Different users for different containers (isolation)
- Read-only filesystems with specific writable directories
- Minimal capabilities (only NET_BIND_SERVICE for nginx)
- Shared volume with fsGroup for cross-container access
- All privilege escalation paths blocked
- seccomp filtering on all containers

---

## Common Mistakes

### Forgetting emptyDir for /tmp when enabling read-only root

Many applications write to /tmp. When enabling readOnlyRootFilesystem, always consider adding emptyDir mounts for /tmp, /var/run, /var/cache, and application-specific directories.

### Wrong profile path for Localhost seccomp

The localhostProfile path is relative to /var/lib/kubelet/seccomp/, not an absolute path. Write `profiles/custom.json`, not `/var/lib/kubelet/seccomp/profiles/custom.json`.

### Unconfined profile not recommended but sometimes needed for debugging

Unconfined disables seccomp filtering entirely. Use it only for debugging when you suspect seccomp is blocking required syscalls, then switch to a proper profile.

### seccomp profile not supported by container runtime

Some container runtimes or configurations may not support all seccomp features. RuntimeDefault should always work, but custom Localhost profiles require the file to exist on the node.

### Combining too many restrictions and breaking application

Start with one restriction at a time and verify the application works. Add restrictions incrementally to identify which combination causes issues.

---

## Security Context Reference Cheat Sheet

| Setting | Level | Purpose |
|---------|-------|---------|
| runAsUser | Pod/Container | Set UID for container process |
| runAsGroup | Pod/Container | Set primary GID for container process |
| runAsNonRoot | Pod/Container | Validate container runs as non-root |
| fsGroup | Pod | Set group ownership for volumes |
| supplementalGroups | Pod | Add extra group memberships |
| readOnlyRootFilesystem | Container | Make root filesystem read-only |
| allowPrivilegeEscalation | Container | Prevent privilege escalation |
| capabilities.drop | Container | Remove capabilities |
| capabilities.add | Container | Add capabilities |
| seccompProfile.type | Pod/Container | Set seccomp profile type |
| seccompProfile.localhostProfile | Pod/Container | Path to custom profile |

### seccomp Profile Types

| Type | Description |
|------|-------------|
| RuntimeDefault | Container runtime's default profile (recommended) |
| Localhost | Custom profile from node filesystem |
| Unconfined | No filtering (avoid in production) |

### Common Writable Directories

| Directory | Typical Use |
|-----------|-------------|
| /tmp | Temporary files |
| /var/run | PID files, sockets |
| /var/cache | Application cache |
| /var/log | Log files |
| /var/lib/<app> | Application data |
