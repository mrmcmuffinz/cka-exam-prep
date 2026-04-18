# Security Contexts Tutorial: Filesystem and seccomp Profiles

## Introduction

This tutorial covers the final layer of Kubernetes security contexts: filesystem constraints and seccomp profiles. The readOnlyRootFilesystem setting prevents containers from modifying their root filesystem, which limits what attackers can do if they compromise a container. The seccomp (secure computing) feature filters system calls at the kernel level, blocking potentially dangerous operations.

Combined with user/group controls and capabilities from the previous assignments, these settings form a comprehensive defense-in-depth strategy. Understanding these controls is important for the CKA exam and for running secure production workloads.

## Prerequisites

You need a running kind cluster. Create one if you do not have one already:

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

Verify the cluster is running:

```bash
kubectl cluster-info
```

## Setup

Create a namespace for the tutorial:

```bash
kubectl create namespace tutorial-security-contexts
```

Set this namespace as the default for the current context:

```bash
kubectl config set-context --current --namespace=tutorial-security-contexts
```

## Understanding readOnlyRootFilesystem

The readOnlyRootFilesystem setting makes the container's root filesystem read-only. This prevents:
- Writing malware to the container filesystem
- Modifying configuration files
- Creating new executable files
- Persisting changes that survive container restarts

When enabled, any attempt to write to the container filesystem (outside of mounted volumes) fails with "Read-only file system."

## Enabling Read-Only Root Filesystem

Create a pod with readOnlyRootFilesystem enabled:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: readonly-demo
  namespace: tutorial-security-contexts
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      readOnlyRootFilesystem: true
EOF
```

Wait for the pod:

```bash
kubectl wait --for=condition=Ready pod/readonly-demo --timeout=60s
```

Try to write a file:

```bash
kubectl exec readonly-demo -- touch /tmp/testfile
```

The command fails with "Read-only file system."

## Combining Read-Only Root with Writable Mounts

Applications often need to write temporary files, logs, or caches. You can use emptyDir volumes to provide writable directories while keeping the root filesystem read-only.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: readonly-with-tmp
  namespace: tutorial-security-contexts
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
    - name: cache
      mountPath: /var/cache
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
EOF
```

Wait for the pod:

```bash
kubectl wait --for=condition=Ready pod/readonly-with-tmp --timeout=60s
```

Now writing to /tmp succeeds:

```bash
kubectl exec readonly-with-tmp -- touch /tmp/testfile
kubectl exec readonly-with-tmp -- ls /tmp/testfile
```

But writing elsewhere still fails:

```bash
kubectl exec readonly-with-tmp -- touch /home/testfile
```

## Identifying Writable Directory Requirements

Different applications need different writable directories. Common locations include:
- /tmp for temporary files
- /var/run for PID files and sockets
- /var/cache for cached data
- /var/log for log files
- Application-specific directories

To find what directories an application writes to:
1. Run the application without readOnlyRootFilesystem
2. Monitor filesystem writes using strace or audit logs
3. Check application documentation
4. Start with readOnlyRootFilesystem and add emptyDir mounts as "Read-only file system" errors appear

## Understanding seccomp

seccomp (secure computing mode) is a Linux kernel feature that restricts which system calls a process can make. System calls are the interface between user-space programs and the kernel. By filtering syscalls, seccomp can prevent many types of attacks.

Kubernetes supports three types of seccomp profiles:

| Profile Type | Description |
|--------------|-------------|
| RuntimeDefault | The container runtime's default profile (recommended) |
| Localhost | A custom profile from the node's filesystem |
| Unconfined | No seccomp filtering (not recommended) |

## Applying RuntimeDefault seccomp Profile

The RuntimeDefault profile uses the container runtime's built-in seccomp policy. This blocks dangerous syscalls while allowing normal application operation.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-default
  namespace: tutorial-security-contexts
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

Wait for the pod:

```bash
kubectl wait --for=condition=Ready pod/seccomp-default --timeout=60s
```

The container runs normally with syscall filtering in place. Most applications work fine with RuntimeDefault.

## Comparing with Unconfined

The Unconfined profile disables seccomp filtering entirely. This is less secure but sometimes needed for debugging or special applications.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-unconfined
  namespace: tutorial-security-contexts
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

In production, avoid Unconfined unless absolutely necessary. Always prefer RuntimeDefault or a custom Localhost profile.

## Creating Custom seccomp Profiles

Custom seccomp profiles are JSON files that specify which syscalls to allow or deny. They must be placed in /var/lib/kubelet/seccomp/ on the node.

First, let us find the kind node name:

```bash
kubectl get nodes
```

Now copy a custom profile to the kind node. First, create the profile locally:

```bash
cat > /tmp/custom-seccomp.json << 'EOF'
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64", "SCMP_ARCH_X86", "SCMP_ARCH_X32"],
  "syscalls": [
    {
      "names": [
        "read", "write", "open", "close", "fstat", "lseek", "mmap",
        "mprotect", "munmap", "brk", "rt_sigaction", "rt_sigprocmask",
        "ioctl", "access", "pipe", "select", "sched_yield", "mremap",
        "msync", "mincore", "madvise", "dup", "dup2", "pause", "nanosleep",
        "getpid", "socket", "connect", "accept", "sendto", "recvfrom",
        "sendmsg", "recvmsg", "shutdown", "bind", "listen", "getsockname",
        "getpeername", "socketpair", "setsockopt", "getsockopt", "clone",
        "fork", "vfork", "execve", "exit", "wait4", "kill", "uname",
        "fcntl", "flock", "fsync", "fdatasync", "truncate", "ftruncate",
        "getdents", "getcwd", "chdir", "fchdir", "mkdir", "rmdir", "creat",
        "unlink", "readlink", "chmod", "fchmod", "chown", "fchown", "lchown",
        "umask", "gettimeofday", "getrlimit", "getrusage", "sysinfo", "times",
        "getuid", "getgid", "setuid", "setgid", "geteuid", "getegid",
        "setpgid", "getppid", "getpgrp", "setsid", "setreuid", "setregid",
        "getgroups", "setgroups", "setresuid", "getresuid", "setresgid",
        "getresgid", "getpgid", "setfsuid", "setfsgid", "getsid", "capget",
        "capset", "rt_sigpending", "rt_sigtimedwait", "rt_sigqueueinfo",
        "rt_sigsuspend", "sigaltstack", "utime", "mknod", "statfs", "fstatfs",
        "sysfs", "getpriority", "setpriority", "sched_setparam",
        "sched_getparam", "sched_setscheduler", "sched_getscheduler",
        "sched_get_priority_max", "sched_get_priority_min", "sched_rr_get_interval",
        "mlock", "munlock", "mlockall", "munlockall", "vhangup", "pivot_root",
        "prctl", "arch_prctl", "setrlimit", "sync", "acct", "settimeofday",
        "mount", "umount2", "swapon", "swapoff", "reboot", "sethostname",
        "setdomainname", "ioperm", "iopl", "create_module", "init_module",
        "delete_module", "get_kernel_syms", "query_module", "quotactl",
        "nfsservctl", "getpmsg", "putpmsg", "afs_syscall", "tuxcall",
        "security", "gettid", "readahead", "setxattr", "lsetxattr", "fsetxattr",
        "getxattr", "lgetxattr", "fgetxattr", "listxattr", "llistxattr",
        "flistxattr", "removexattr", "lremovexattr", "fremovexattr", "tkill",
        "futex", "sched_setaffinity", "sched_getaffinity", "set_thread_area",
        "io_setup", "io_destroy", "io_getevents", "io_submit", "io_cancel",
        "get_thread_area", "lookup_dcookie", "epoll_create", "epoll_ctl_old",
        "epoll_wait_old", "remap_file_pages", "getdents64", "set_tid_address",
        "restart_syscall", "semtimedop", "fadvise64", "timer_create",
        "timer_settime", "timer_gettime", "timer_getoverrun", "timer_delete",
        "clock_settime", "clock_gettime", "clock_getres", "clock_nanosleep",
        "exit_group", "epoll_wait", "epoll_ctl", "tgkill", "utimes", "mbind",
        "set_mempolicy", "get_mempolicy", "mq_open", "mq_unlink", "mq_timedsend",
        "mq_timedreceive", "mq_notify", "mq_getsetattr", "kexec_load", "waitid",
        "add_key", "request_key", "keyctl", "ioprio_set", "ioprio_get",
        "inotify_init", "inotify_add_watch", "inotify_rm_watch", "migrate_pages",
        "openat", "mkdirat", "mknodat", "fchownat", "futimesat", "newfstatat",
        "unlinkat", "renameat", "linkat", "symlinkat", "readlinkat", "fchmodat",
        "faccessat", "pselect6", "ppoll", "unshare", "set_robust_list",
        "get_robust_list", "splice", "tee", "sync_file_range", "vmsplice",
        "move_pages", "utimensat", "epoll_pwait", "signalfd", "timerfd_create",
        "eventfd", "fallocate", "timerfd_settime", "timerfd_gettime", "accept4",
        "signalfd4", "eventfd2", "epoll_create1", "dup3", "pipe2", "inotify_init1",
        "preadv", "pwritev", "rt_tgsigqueueinfo", "perf_event_open", "recvmmsg",
        "fanotify_init", "fanotify_mark", "prlimit64", "name_to_handle_at",
        "open_by_handle_at", "clock_adjtime", "syncfs", "sendmmsg", "setns",
        "getcpu", "process_vm_readv", "process_vm_writev", "kcmp", "finit_module",
        "sched_setattr", "sched_getattr", "renameat2", "seccomp", "getrandom",
        "memfd_create", "kexec_file_load", "bpf", "execveat", "userfaultfd",
        "membarrier", "mlock2", "copy_file_range", "preadv2", "pwritev2",
        "pkey_mprotect", "pkey_alloc", "pkey_free", "statx", "io_pgetevents",
        "rseq", "stat", "lstat", "poll", "pread64", "pwrite64", "readv", "writev",
        "openat2", "pidfd_getfd", "faccessat2", "epoll_pwait2", "newfstatat"
      ],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
EOF
```

Copy the profile to the kind node:

```bash
# Get the kind node container name
KIND_NODE=$(nerdctl ps --format '{{.Names}}' | grep kind-control-plane)

# Create the seccomp directory on the node
nerdctl exec $KIND_NODE mkdir -p /var/lib/kubelet/seccomp/profiles

# Copy the profile to the node
nerdctl cp /tmp/custom-seccomp.json $KIND_NODE:/var/lib/kubelet/seccomp/profiles/custom.json
```

Now use the custom profile:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-localhost
  namespace: tutorial-security-contexts
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      seccompProfile:
        type: Localhost
        localhostProfile: profiles/custom.json
EOF
```

The localhostProfile path is relative to /var/lib/kubelet/seccomp/ on the node.

## seccomp Profile Structure

A seccomp profile is a JSON file with the following structure:

```json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": ["read", "write", "exit"],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
```

**defaultAction** specifies what to do with syscalls not in the list:
- SCMP_ACT_ALLOW: Allow the syscall
- SCMP_ACT_ERRNO: Block and return an error
- SCMP_ACT_KILL: Kill the process

**syscalls** is an array of rules, each specifying:
- names: List of syscall names
- action: What to do (ALLOW, ERRNO, KILL, LOG, etc.)

## Debugging seccomp Issues

When seccomp blocks a syscall, the operation fails with errors like "Operation not permitted" or "Function not implemented." To debug:

1. Check pod events for seccomp-related errors
2. Try running with Unconfined temporarily to confirm seccomp is the issue
3. Use strace to identify which syscalls the application needs
4. Add missing syscalls to your custom profile

## Defense in Depth: Combining All Security Controls

The most secure configuration combines all security controls from this series. Here is a comprehensive example:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: hardened-pod
  namespace: tutorial-security-contexts
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

This configuration:
- Runs as non-root user and group
- Validates non-root with runAsNonRoot
- Sets fsGroup for volume access
- Makes root filesystem read-only
- Prevents privilege escalation
- Drops all capabilities
- Applies RuntimeDefault seccomp profile
- Provides writable /tmp via emptyDir

Wait for the pod:

```bash
kubectl wait --for=condition=Ready pod/hardened-pod --timeout=60s
```

Verify the security settings:

```bash
# Check user identity
kubectl exec hardened-pod -- id

# Check capabilities (should be none)
kubectl exec hardened-pod -- cat /proc/1/status | grep CapEff

# Check no_new_privs
kubectl exec hardened-pod -- cat /proc/1/status | grep NoNewPrivs

# Test read-only filesystem
kubectl exec hardened-pod -- touch /home/test
# Expected: Read-only file system error

# Test writable /tmp
kubectl exec hardened-pod -- touch /tmp/test
# Expected: Success
```

## Cleanup

Delete the tutorial namespace and all resources:

```bash
kubectl delete namespace tutorial-security-contexts
```

Remove the custom seccomp profile from the kind node:

```bash
KIND_NODE=$(nerdctl ps --format '{{.Names}}' | grep kind-control-plane)
nerdctl exec $KIND_NODE rm -rf /var/lib/kubelet/seccomp/profiles
```

## Reference Commands

| Task | Command |
|------|---------|
| Test write to root filesystem | `kubectl exec <pod> -- touch /test` |
| Test write to volume | `kubectl exec <pod> -- touch /tmp/test` |
| View pod securityContext | `kubectl get pod <pod> -o yaml | grep -A 30 securityContext` |
| List kind node containers | `nerdctl ps --filter name=kind` |
| Copy file to kind node | `nerdctl cp <file> <node>:<path>` |
| Execute command on kind node | `nerdctl exec <node> <command>` |

## Key Takeaways

1. **readOnlyRootFilesystem** prevents writes to the container filesystem, limiting attack impact
2. **emptyDir volumes** provide writable storage when using read-only root
3. **seccomp profiles** filter system calls at the kernel level
4. **RuntimeDefault** is the recommended seccomp profile for most applications
5. **Localhost profiles** allow custom syscall filtering from JSON files on the node
6. **Unconfined** disables seccomp and should be avoided in production
7. **Defense in depth** combines all security controls: user/group, capabilities, filesystem, and seccomp
8. Custom seccomp profiles live in /var/lib/kubelet/seccomp/ on the node
