# Security Contexts Homework: Filesystem and seccomp Profiles

This homework contains 15 progressive exercises to practice filesystem constraints and seccomp profiles in Kubernetes. Complete the tutorial before attempting these exercises.

---

## Level 1: Read-Only Filesystem

### Exercise 1.1

**Objective:** Enable read-only root filesystem and observe the behavior.

**Setup:**

```bash
kubectl create namespace ex-1-1
```

**Task:**

Create a pod named `readonly-test` in namespace `ex-1-1` using busybox:1.36 with command `["sleep", "3600"]`. Enable readOnlyRootFilesystem in the security context.

**Verification:**

```bash
# Verify the pod is running
kubectl get pod -n ex-1-1 readonly-test

# Expected: Running

# Try to write a file to the root filesystem
kubectl exec -n ex-1-1 readonly-test -- touch /tmp/test

# Expected: "Read-only file system" error

# Try to write to another location
kubectl exec -n ex-1-1 readonly-test -- touch /home/test

# Expected: "Read-only file system" error
```

---

### Exercise 1.2

**Objective:** Add an emptyDir volume for writable temporary storage.

**Setup:**

```bash
kubectl create namespace ex-1-2
```

**Task:**

Create a pod named `readonly-with-tmp` in namespace `ex-1-2` using busybox:1.36 with command `["sleep", "3600"]`. Configure the pod to:
- Enable readOnlyRootFilesystem
- Mount an emptyDir volume at /tmp

**Verification:**

```bash
# Verify the pod is running
kubectl get pod -n ex-1-2 readonly-with-tmp

# Write to /tmp should succeed
kubectl exec -n ex-1-2 readonly-with-tmp -- touch /tmp/testfile
kubectl exec -n ex-1-2 readonly-with-tmp -- ls /tmp/testfile

# Expected: /tmp/testfile

# Write to root filesystem should fail
kubectl exec -n ex-1-2 readonly-with-tmp -- touch /home/test

# Expected: "Read-only file system" error
```

---

### Exercise 1.3

**Objective:** Configure multiple writable directories for an application.

**Setup:**

```bash
kubectl create namespace ex-1-3
```

**Task:**

Create a pod named `app-container` in namespace `ex-1-3` using nginx:1.25. Configure the pod to:
- Enable readOnlyRootFilesystem
- Provide writable directories for:
  - /tmp (temporary files)
  - /var/cache/nginx (nginx cache)
  - /var/run (PID files and sockets)

The nginx container should start successfully.

**Verification:**

```bash
# Verify the pod is running
kubectl get pod -n ex-1-3 app-container

# Expected: Running

# Verify writable directories work
kubectl exec -n ex-1-3 app-container -- touch /tmp/test
kubectl exec -n ex-1-3 app-container -- touch /var/cache/nginx/test
kubectl exec -n ex-1-3 app-container -- touch /var/run/test

# Expected: All commands succeed

# Verify root filesystem is read-only
kubectl exec -n ex-1-3 app-container -- touch /etc/test

# Expected: "Read-only file system" error
```

---

## Level 2: seccomp Basics

### Exercise 2.1

**Objective:** Apply RuntimeDefault seccomp profile explicitly.

**Setup:**

```bash
kubectl create namespace ex-2-1
```

**Task:**

Create a pod named `seccomp-runtime` in namespace `ex-2-1` using busybox:1.36 with command `["sleep", "3600"]`. Explicitly set the seccomp profile to RuntimeDefault.

**Verification:**

```bash
# Verify the pod is running
kubectl get pod -n ex-2-1 seccomp-runtime

# Expected: Running

# Verify the seccomp profile is set
kubectl get pod -n ex-2-1 seccomp-runtime -o yaml | grep -A 3 seccompProfile

# Expected: type: RuntimeDefault

# Basic operations should work
kubectl exec -n ex-2-1 seccomp-runtime -- ls /

# Expected: Directory listing succeeds
```

---

### Exercise 2.2

**Objective:** Compare RuntimeDefault with Unconfined profile.

**Setup:**

```bash
kubectl create namespace ex-2-2
```

**Task:**

Create two pods in namespace `ex-2-2`:
1. Pod named `with-seccomp` using RuntimeDefault seccomp profile
2. Pod named `without-seccomp` using Unconfined seccomp profile

Both should use busybox:1.36 with command `["sleep", "3600"]`.

**Verification:**

```bash
# Verify both pods are running
kubectl get pods -n ex-2-2

# Expected: Both Running

# Check seccomp profiles
kubectl get pod -n ex-2-2 with-seccomp -o jsonpath='{.spec.containers[0].securityContext.seccompProfile.type}'
# Expected: RuntimeDefault

kubectl get pod -n ex-2-2 without-seccomp -o jsonpath='{.spec.containers[0].securityContext.seccompProfile.type}'
# Expected: Unconfined

# Both should execute commands normally
kubectl exec -n ex-2-2 with-seccomp -- echo "test"
kubectl exec -n ex-2-2 without-seccomp -- echo "test"

# Expected: Both output "test"
```

---

### Exercise 2.3

**Objective:** Apply seccomp profile at pod level vs container level.

**Setup:**

```bash
kubectl create namespace ex-2-3
```

**Task:**

Create a pod named `seccomp-levels` in namespace `ex-2-3` with:
- Pod-level seccomp profile: RuntimeDefault
- Two containers using busybox:1.36 with command `["sleep", "3600"]`:
  - Container `default-profile` that inherits pod-level seccomp
  - Container `unconfined-profile` that overrides with Unconfined

**Verification:**

```bash
# Verify the pod is running
kubectl get pod -n ex-2-3 seccomp-levels

# Expected: Running with 2 containers

# Check that pod-level profile is RuntimeDefault
kubectl get pod -n ex-2-3 seccomp-levels -o jsonpath='{.spec.securityContext.seccompProfile.type}'

# Expected: RuntimeDefault

# Check container-level override for unconfined-profile
kubectl get pod -n ex-2-3 seccomp-levels -o jsonpath='{.spec.containers[?(@.name=="unconfined-profile")].securityContext.seccompProfile.type}'

# Expected: Unconfined
```

---

## Level 3: Debugging Filesystem and seccomp Issues

### Exercise 3.1

**Objective:** An application fails to start due to filesystem issues. Find and fix the problem.

**Setup:**

```bash
kubectl create namespace ex-3-1

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
EOF
```

**Task:**

The pod above is failing because it cannot write to /var/log. Diagnose the issue and fix the configuration so the application can write logs while maintaining a read-only root filesystem.

**Verification:**

```bash
# After fixing, verify the pod is running
kubectl get pod -n ex-3-1 logger-app

# Expected: Running

# Verify the log file was created
kubectl exec -n ex-3-1 logger-app -- cat /var/log/app.log

# Expected: log entry
```

---

### Exercise 3.2

**Objective:** A pod is not starting due to seccomp restrictions. Find and fix the issue.

**Setup:**

```bash
kubectl create namespace ex-3-2

# First, create a restrictive seccomp profile on the kind node
KIND_NODE=$(nerdctl ps --format '{{.Names}}' | grep kind-control-plane)
nerdctl exec $KIND_NODE mkdir -p /var/lib/kubelet/seccomp/profiles

cat > /tmp/restrictive.json << 'EOF'
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": ["exit", "exit_group"],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
EOF

nerdctl cp /tmp/restrictive.json $KIND_NODE:/var/lib/kubelet/seccomp/profiles/restrictive.json

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
        type: Localhost
        localhostProfile: profiles/restrictive.json
EOF
```

**Task:**

The pod above uses a very restrictive custom seccomp profile that only allows exit syscalls. The pod cannot run because essential syscalls are blocked. Fix the pod configuration to use a less restrictive profile that allows the application to run.

**Verification:**

```bash
# After fixing, verify the pod is running
kubectl get pod -n ex-3-2 restricted-pod

# Expected: Running (not Error or CrashLoopBackOff)

# Verify commands work
kubectl exec -n ex-3-2 restricted-pod -- echo "working"

# Expected: working
```

---

### Exercise 3.3

**Objective:** A multi-container pod has filesystem issues. Find and fix them.

**Setup:**

```bash
kubectl create namespace ex-3-3

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
  volumes:
  - name: shared
    emptyDir: {}
EOF
```

**Task:**

The pod above has two containers sharing data. The writer can write to /data, but the reader cannot write its output to /output because it is on the read-only root filesystem. Fix the configuration so both containers can perform their tasks.

**Verification:**

```bash
# After fixing, verify the pod is running
kubectl get pod -n ex-3-3 data-processor

# Expected: Both containers Running

# Wait for data processing
sleep 10

# Verify the reader wrote output
kubectl exec -n ex-3-3 data-processor -c reader -- cat /output/result.txt

# Expected: done
```

---

## Level 4: Custom seccomp Profiles

### Exercise 4.1

**Objective:** Create and apply a custom seccomp profile that allows basic operations.

**Setup:**

```bash
kubectl create namespace ex-4-1

# Create a custom profile that allows common syscalls
cat > /tmp/basic-profile.json << 'EOF'
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64", "SCMP_ARCH_X86", "SCMP_ARCH_X32"],
  "syscalls": [
    {
      "names": [
        "read", "write", "open", "close", "stat", "fstat", "lstat",
        "poll", "lseek", "mmap", "mprotect", "munmap", "brk",
        "rt_sigaction", "rt_sigprocmask", "rt_sigreturn", "ioctl",
        "pread64", "pwrite64", "readv", "writev", "access", "pipe",
        "select", "sched_yield", "mremap", "msync", "mincore", "madvise",
        "dup", "dup2", "pause", "nanosleep", "getpid", "getuid", "getgid",
        "geteuid", "getegid", "getppid", "getpgrp", "setsid", "getgroups",
        "uname", "fcntl", "flock", "fsync", "fdatasync", "truncate",
        "ftruncate", "getdents", "getcwd", "chdir", "mkdir", "rmdir",
        "creat", "unlink", "readlink", "chmod", "fchmod", "chown", "fchown",
        "umask", "gettimeofday", "getrlimit", "sysinfo", "times", "ptrace",
        "syslog", "capget", "capset", "setuid", "setgid", "setpgid",
        "setreuid", "setregid", "setgroups", "setresuid", "setresgid",
        "getresuid", "getresgid", "getpgid", "setfsuid", "setfsgid",
        "getsid", "prctl", "arch_prctl", "clock_gettime", "clock_getres",
        "clock_nanosleep", "exit_group", "epoll_wait", "epoll_ctl",
        "tgkill", "openat", "mkdirat", "fchownat", "newfstatat",
        "unlinkat", "renameat", "fchmodat", "faccessat", "pselect6",
        "ppoll", "set_robust_list", "get_robust_list", "epoll_pwait",
        "eventfd2", "epoll_create1", "dup3", "pipe2", "getrandom",
        "execve", "wait4", "clone", "fork", "vfork", "exit", "futex",
        "set_tid_address", "getdents64", "restart_syscall", "prlimit64",
        "mlock", "munlock", "getitimer", "setitimer", "alarm", "sigaltstack",
        "statfs", "fstatfs", "kill"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
EOF

# Copy to kind node
KIND_NODE=$(nerdctl ps --format '{{.Names}}' | grep kind-control-plane)
nerdctl exec $KIND_NODE mkdir -p /var/lib/kubelet/seccomp/profiles
nerdctl cp /tmp/basic-profile.json $KIND_NODE:/var/lib/kubelet/seccomp/profiles/basic.json
```

**Task:**

Create a pod named `custom-seccomp` in namespace `ex-4-1` using busybox:1.36 with command `["sleep", "3600"]`. Apply the custom seccomp profile at profiles/basic.json.

**Verification:**

```bash
# Verify the pod is running
kubectl get pod -n ex-4-1 custom-seccomp

# Expected: Running

# Verify basic operations work
kubectl exec -n ex-4-1 custom-seccomp -- ls /
kubectl exec -n ex-4-1 custom-seccomp -- echo "test"

# Expected: Both commands succeed

# Check the seccomp profile is Localhost
kubectl get pod -n ex-4-1 custom-seccomp -o jsonpath='{.spec.containers[0].securityContext.seccompProfile.type}'

# Expected: Localhost
```

---

### Exercise 4.2

**Objective:** Test a profile that blocks specific syscalls.

**Setup:**

```bash
kubectl create namespace ex-4-2

# Create a profile that blocks network syscalls
cat > /tmp/no-network.json << 'EOF'
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "architectures": ["SCMP_ARCH_X86_64", "SCMP_ARCH_X86", "SCMP_ARCH_X32"],
  "syscalls": [
    {
      "names": ["socket", "connect", "accept", "bind", "listen", "sendto", "recvfrom", "sendmsg", "recvmsg"],
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
EOF

# Copy to kind node
KIND_NODE=$(nerdctl ps --format '{{.Names}}' | grep kind-control-plane)
nerdctl cp /tmp/no-network.json $KIND_NODE:/var/lib/kubelet/seccomp/profiles/no-network.json
```

**Task:**

Create a pod named `no-network-pod` in namespace `ex-4-2` using busybox:1.36 with command `["sleep", "3600"]`. Apply the custom seccomp profile at profiles/no-network.json that blocks network syscalls.

**Verification:**

```bash
# Verify the pod is running
kubectl get pod -n ex-4-2 no-network-pod

# Expected: Running

# Non-network operations should work
kubectl exec -n ex-4-2 no-network-pod -- ls /
kubectl exec -n ex-4-2 no-network-pod -- echo "test"

# Expected: Both succeed

# Network operations should be blocked
kubectl exec -n ex-4-2 no-network-pod -- wget -q -O - http://kubernetes.default.svc 2>&1 | head -1

# Expected: Error related to network operation being blocked
```

---

### Exercise 4.3

**Objective:** Iterate on a seccomp profile to add required syscalls.

**Setup:**

```bash
kubectl create namespace ex-4-3

# Create an intentionally incomplete profile
cat > /tmp/incomplete.json << 'EOF'
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64", "SCMP_ARCH_X86", "SCMP_ARCH_X32"],
  "syscalls": [
    {
      "names": [
        "read", "write", "close", "nanosleep", "exit_group"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
EOF

# Copy to kind node
KIND_NODE=$(nerdctl ps --format '{{.Names}}' | grep kind-control-plane)
nerdctl cp /tmp/incomplete.json $KIND_NODE:/var/lib/kubelet/seccomp/profiles/incomplete.json
```

**Task:**

The profile at profiles/incomplete.json is missing syscalls needed for the ls command. Create a new profile that includes the missing syscalls (at least: openat, getdents64, fstat, close, write, exit_group). Copy it to the kind node as profiles/fixed.json and create a pod named `fixed-profile` that uses it.

**Verification:**

```bash
# Verify the pod is running
kubectl get pod -n ex-4-3 fixed-profile

# Expected: Running

# ls command should work
kubectl exec -n ex-4-3 fixed-profile -- ls /

# Expected: Directory listing
```

---

## Level 5: Defense in Depth

### Exercise 5.1

**Objective:** Configure a pod with all recommended security controls.

**Setup:**

```bash
kubectl create namespace ex-5-1
```

**Task:**

Create a pod named `fully-hardened` in namespace `ex-5-1` using busybox:1.36 with command `["sleep", "3600"]`. Apply all recommended security controls:

1. Run as non-root user (UID 1000, GID 1000)
2. Enforce runAsNonRoot validation
3. Set fsGroup for volume access (GID 2000)
4. Enable readOnlyRootFilesystem
5. Prevent privilege escalation
6. Drop all capabilities
7. Apply RuntimeDefault seccomp profile
8. Mount emptyDir at /tmp for writable storage

**Verification:**

```bash
# Verify the pod is running
kubectl get pod -n ex-5-1 fully-hardened

# Expected: Running

# Check user identity
kubectl exec -n ex-5-1 fully-hardened -- id

# Expected: uid=1000 gid=1000 groups=1000,2000

# Check no capabilities
kubectl exec -n ex-5-1 fully-hardened -- cat /proc/1/status | grep CapEff

# Expected: CapEff: 0000000000000000

# Check no_new_privs
kubectl exec -n ex-5-1 fully-hardened -- cat /proc/1/status | grep NoNewPrivs

# Expected: NoNewPrivs: 1

# Test read-only root (should fail)
kubectl exec -n ex-5-1 fully-hardened -- touch /home/test

# Expected: Read-only file system

# Test writable /tmp (should succeed)
kubectl exec -n ex-5-1 fully-hardened -- touch /tmp/test

# Expected: Success
```

---

### Exercise 5.2

**Objective:** Debug an application failing due to multiple security constraints.

**Setup:**

```bash
kubectl create namespace ex-5-2

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
      seccompProfile:
        type: RuntimeDefault
EOF
```

**Task:**

The pod above has multiple security constraints that are causing it to fail. The application needs to:
1. Ping localhost (requires NET_RAW capability)
2. Write output to /tmp (blocked by read-only root filesystem)

Fix the configuration while maintaining as much security as possible.

**Verification:**

```bash
# After fixing, verify the pod is running
kubectl get pod -n ex-5-2 secure-app

# Expected: Running

# Verify ping worked (check logs)
kubectl logs -n ex-5-2 secure-app

# Expected: Ping output showing successful ping

# Verify output was written
kubectl exec -n ex-5-2 secure-app -- cat /tmp/output.txt

# Expected: result

# Verify security is still in place
kubectl exec -n ex-5-2 secure-app -- id
# Expected: uid=1000

kubectl exec -n ex-5-2 secure-app -- cat /proc/1/status | grep NoNewPrivs
# Expected: NoNewPrivs: 1
```

---

### Exercise 5.3

**Objective:** Design a comprehensive security strategy for a production-like deployment.

**Setup:**

```bash
kubectl create namespace ex-5-3
```

**Task:**

Design and implement a pod named `production-app` in namespace `ex-5-3` that represents a secure production deployment. The pod should have:

1. A main container `api` using nginx:1.25 that:
   - Runs as user 101 (nginx user)
   - Has read-only root filesystem
   - Has writable directories for /tmp, /var/cache/nginx, /var/run
   - Drops all capabilities except NET_BIND_SERVICE
   - Has RuntimeDefault seccomp profile
   - Prevents privilege escalation

2. A sidecar container `logger` using busybox:1.36 that:
   - Runs as user 1000
   - Has read-only root filesystem
   - Writes logs to a shared volume at /logs
   - Drops all capabilities
   - Has RuntimeDefault seccomp profile
   - Runs command: `["sh", "-c", "while true; do echo 'heartbeat' >> /logs/heartbeat.log; sleep 10; done"]`

3. Both containers share a log volume with fsGroup for access

**Verification:**

```bash
# Verify both containers are running
kubectl get pod -n ex-5-3 production-app

# Expected: 2/2 Running

# Verify api container security
kubectl exec -n ex-5-3 production-app -c api -- id
# Expected: uid=101

kubectl exec -n ex-5-3 production-app -c api -- cat /proc/1/status | grep NoNewPrivs
# Expected: NoNewPrivs: 1

# Verify api has only NET_BIND_SERVICE capability
kubectl exec -n ex-5-3 production-app -c api -- cat /proc/1/status | grep CapEff
# Expected: CapEff should show only NET_BIND_SERVICE bit

# Verify logger container security
kubectl exec -n ex-5-3 production-app -c logger -- id
# Expected: uid=1000

kubectl exec -n ex-5-3 production-app -c logger -- cat /proc/1/status | grep CapEff
# Expected: CapEff: 0000000000000000

# Wait for logger to write
sleep 15

# Verify shared log volume works
kubectl exec -n ex-5-3 production-app -c api -- cat /logs/heartbeat.log
# Expected: heartbeat entries

# Verify read-only root
kubectl exec -n ex-5-3 production-app -c api -- touch /etc/test
# Expected: Read-only file system
```

---

## Cleanup

Delete all exercise namespaces:

```bash
kubectl delete namespace ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3
```

Clean up custom seccomp profiles from the kind node:

```bash
KIND_NODE=$(nerdctl ps --format '{{.Names}}' | grep kind-control-plane)
nerdctl exec $KIND_NODE rm -rf /var/lib/kubelet/seccomp/profiles
```

---

## Key Takeaways

1. **readOnlyRootFilesystem** prevents writes to the container filesystem, limiting attack impact
2. **emptyDir volumes** provide writable storage when using read-only root
3. **RuntimeDefault seccomp** is the recommended profile for most applications
4. **Localhost seccomp profiles** allow custom syscall filtering using JSON files on the node
5. Custom profiles live in /var/lib/kubelet/seccomp/ on the node
6. **Defense in depth** combines user/group, capabilities, filesystem, and seccomp controls
7. Always start with restrictive settings and add exceptions as needed
8. Test security configurations thoroughly before deploying to production
