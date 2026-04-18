# Security Contexts Homework Answers: Capabilities and Privilege Control

This file contains complete solutions for all 15 exercises on capabilities and privilege escalation controls.

---

## Exercise 1.1 Solution

**Task:** Examine default capabilities.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: inspect-caps
  namespace: ex-1-1
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: inspect-caps
  namespace: ex-1-1
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
```

**Explanation:** Without any security context configuration, the container receives the default capabilities from the container runtime. The exact set depends on containerd's configuration, but typically includes capabilities like CHOWN, DAC_OVERRIDE, FSETID, FOWNER, NET_RAW, SETGID, SETUID, and others.

---

## Exercise 1.2 Solution

**Task:** Compare regular and privileged containers.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: regular-container
  namespace: ex-1-2
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: privileged-container
  namespace: ex-1-2
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: regular-container
  namespace: ex-1-2
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: privileged-container
  namespace: ex-1-2
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
EOF
```

**Explanation:** Privileged containers receive all capabilities (CapEff shows all bits set), access to host devices, and other elevated permissions. This demonstrates why privileged mode should be avoided in production.

---

## Exercise 1.3 Solution

**Task:** View all capability sets.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cap-details
  namespace: ex-1-3
spec:
  containers:
  - name: test
    image: alpine:3.20
    command: ["sleep", "3600"]
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: cap-details
  namespace: ex-1-3
spec:
  containers:
  - name: test
    image: alpine:3.20
    command: ["sleep", "3600"]
EOF
```

**Explanation of capability sets:**
- **CapInh (Inheritable):** Capabilities preserved across execve() for privileged programs
- **CapPrm (Permitted):** Maximum capabilities this process can use
- **CapEff (Effective):** Capabilities currently active for permission checks
- **CapBnd (Bounding):** Upper limit on capabilities that can ever be gained
- **CapAmb (Ambient):** Capabilities preserved across execve() for unprivileged programs

---

## Exercise 2.1 Solution

**Task:** Add NET_ADMIN capability.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: net-configurator
  namespace: ex-2-1
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        add: ["NET_ADMIN"]
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: net-configurator
  namespace: ex-2-1
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        add: ["NET_ADMIN"]
EOF
```

**Explanation:** NET_ADMIN allows the container to configure network interfaces, routing tables, and firewall rules. This is needed for tools like ip, iptables, and network configuration utilities.

---

## Exercise 2.2 Solution

**Task:** Drop NET_RAW capability.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-raw-sockets
  namespace: ex-2-2
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        drop: ["NET_RAW"]
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: no-raw-sockets
  namespace: ex-2-2
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        drop: ["NET_RAW"]
EOF
```

**Explanation:** NET_RAW allows creating raw sockets, which are used by ping, traceroute, and packet capture tools. Dropping this capability prevents these operations while allowing normal network communication.

---

## Exercise 2.3 Solution

**Task:** Drop all, add specific.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: minimal-privileges
  namespace: ex-2-3
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        drop: ["ALL"]
        add: ["NET_BIND_SERVICE"]
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: minimal-privileges
  namespace: ex-2-3
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        drop: ["ALL"]
        add: ["NET_BIND_SERVICE"]
EOF
```

**Explanation:** This pattern first removes all capabilities, then adds back only what is needed. NET_BIND_SERVICE (0x0400 in hex) allows binding to ports below 1024, useful for web servers running as non-root.

---

## Exercise 3.1 Solution

**Problem:** The container needs to add an IP address to an interface, which requires NET_ADMIN capability.

**Fix:**

```bash
kubectl delete pod -n ex-3-1 network-manager

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: network-manager
  namespace: ex-3-1
spec:
  containers:
  - name: manager
    image: busybox:1.36
    command: ["sh", "-c", "ip addr add 10.200.0.1/24 dev lo && sleep 3600"]
    securityContext:
      capabilities:
        add: ["NET_ADMIN"]
EOF
```

**Explanation:** Network configuration operations like adding IP addresses require NET_ADMIN capability. Without it, the ip addr add command fails with "Operation not permitted."

---

## Exercise 3.2 Solution

**Problem:** The container drops all capabilities but needs NET_RAW for ping.

**Fix:**

```bash
kubectl delete pod -n ex-3-2 ping-service

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ping-service
  namespace: ex-3-2
spec:
  containers:
  - name: pinger
    image: busybox:1.36
    command: ["sh", "-c", "ping -c 5 127.0.0.1 && sleep 3600"]
    securityContext:
      capabilities:
        drop: ["ALL"]
        add: ["NET_RAW"]
EOF
```

**Explanation:** Ping uses raw sockets which require NET_RAW capability. The fix maintains the secure drop-all pattern while adding back only the required capability.

---

## Exercise 3.3 Solution

**Analysis:** This exercise demonstrates the interaction between allowPrivilegeEscalation and capabilities.

The configuration has:
- SETUID and SETGID capabilities added
- allowPrivilegeEscalation: false

The key insight is that even though the capabilities are added, allowPrivilegeEscalation: false sets the no_new_privs flag, which prevents:
- Setuid binaries from gaining elevated privileges
- The process from gaining capabilities it does not already have
- Privilege escalation through any mechanism

**The configuration is intentionally conflicting.** If an application truly needs setuid functionality, allowPrivilegeEscalation must be true. However, this is a security risk and should be avoided when possible.

The pod runs fine, but setuid binaries inside the container will not be able to elevate privileges. This is a documentation and understanding exercise, not a fix exercise.

---

## Exercise 4.1 Solution

**Task:** Configure privilege escalation prevention.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-escalation
  namespace: ex-4-1
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 1000
      allowPrivilegeEscalation: false
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: no-escalation
  namespace: ex-4-1
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 1000
      allowPrivilegeEscalation: false
EOF
```

**Explanation:** allowPrivilegeEscalation: false sets the no_new_privs flag, preventing processes from gaining privileges through setuid binaries or other mechanisms, while maintaining the default capabilities.

---

## Exercise 4.2 Solution

**Task:** Implement all recommended security controls.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: defense-in-depth
  namespace: ex-4-2
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
    runAsNonRoot: true
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: defense-in-depth
  namespace: ex-4-2
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
    runAsNonRoot: true
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
EOF
```

**Explanation:** This combines multiple layers of security:
- Non-root user prevents using root's implicit privileges
- runAsNonRoot validates the non-root requirement
- allowPrivilegeEscalation prevents gaining new privileges
- Dropping all capabilities removes all special permissions

---

## Exercise 4.3 Solution

**Task:** Compare privilege escalation settings.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: with-escalation
  namespace: ex-4-3
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 1000
---
apiVersion: v1
kind: Pod
metadata:
  name: without-escalation
  namespace: ex-4-3
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 1000
      allowPrivilegeEscalation: false
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: with-escalation
  namespace: ex-4-3
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 1000
---
apiVersion: v1
kind: Pod
metadata:
  name: without-escalation
  namespace: ex-4-3
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 1000
      allowPrivilegeEscalation: false
EOF
```

**Explanation:** The NoNewPrivs flag difference shows how allowPrivilegeEscalation affects the kernel-level security controls applied to the process.

---

## Exercise 5.1 Solution

**Task:** Configure minimal capabilities for network monitoring.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: network-monitor
  namespace: ex-5-1
spec:
  securityContext:
    runAsUser: 1000
  containers:
  - name: monitor
    image: busybox:1.36
    command: ["sh", "-c", "ping -c 2 127.0.0.1 && ip link show && sleep 3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["NET_RAW", "NET_ADMIN"]
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: network-monitor
  namespace: ex-5-1
spec:
  securityContext:
    runAsUser: 1000
  containers:
  - name: monitor
    image: busybox:1.36
    command: ["sh", "-c", "ping -c 2 127.0.0.1 && ip link show && sleep 3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["NET_RAW", "NET_ADMIN"]
EOF
```

**Explanation:** This solution grants only the capabilities needed:
- NET_RAW for ping (raw socket operations)
- NET_ADMIN for ip link show (network administration)
All other capabilities are dropped, minimizing the attack surface.

---

## Exercise 5.2 Solution

**Problem:** The application needs multiple capabilities that were all dropped: NET_RAW for ping, NET_ADMIN for ip link show.

**Fix:**

```bash
kubectl delete pod -n ex-5-2 constrained-app

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: constrained-app
  namespace: ex-5-2
spec:
  securityContext:
    runAsUser: 1000
    runAsNonRoot: true
    fsGroup: 2000
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "ping -c 1 127.0.0.1 && ip link show && echo 'data' > /data/output.txt && sleep 3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["NET_RAW", "NET_ADMIN"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
EOF
```

**Explanation:** The fix adds NET_RAW and NET_ADMIN capabilities while maintaining all other security constraints. The fsGroup ensures the emptyDir is writable by the non-root user.

---

## Exercise 5.3 Solution

**Task:** Design capability strategy for multi-container pod.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-service
  namespace: ex-5-3
spec:
  securityContext:
    fsGroup: 3000
  containers:
  - name: web-server
    image: nginx:1.25
    securityContext:
      runAsUser: 101
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["NET_BIND_SERVICE"]
    volumeMounts:
    - name: shared
      mountPath: /shared
  - name: network-probe
    image: busybox:1.36
    command: ["sh", "-c", "while true; do ping -c 1 127.0.0.1 > /dev/null && echo 'probe ok'; sleep 30; done"]
    securityContext:
      runAsUser: 1000
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["NET_RAW"]
    volumeMounts:
    - name: shared
      mountPath: /shared
  - name: file-processor
    image: busybox:1.36
    command: ["sh", "-c", "echo 'processed' > /shared/status.txt && sleep 3600"]
    securityContext:
      runAsUser: 2000
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
    volumeMounts:
    - name: shared
      mountPath: /shared
  volumes:
  - name: shared
    emptyDir: {}
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: multi-service
  namespace: ex-5-3
spec:
  securityContext:
    fsGroup: 3000
  containers:
  - name: web-server
    image: nginx:1.25
    securityContext:
      runAsUser: 101
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["NET_BIND_SERVICE"]
    volumeMounts:
    - name: shared
      mountPath: /shared
  - name: network-probe
    image: busybox:1.36
    command: ["sh", "-c", "while true; do ping -c 1 127.0.0.1 > /dev/null && echo 'probe ok'; sleep 30; done"]
    securityContext:
      runAsUser: 1000
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["NET_RAW"]
    volumeMounts:
    - name: shared
      mountPath: /shared
  - name: file-processor
    image: busybox:1.36
    command: ["sh", "-c", "echo 'processed' > /shared/status.txt && sleep 3600"]
    securityContext:
      runAsUser: 2000
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
    volumeMounts:
    - name: shared
      mountPath: /shared
  volumes:
  - name: shared
    emptyDir: {}
EOF
```

**Explanation:** Each container receives only the capabilities it needs:
- web-server: NET_BIND_SERVICE for privileged ports
- network-probe: NET_RAW for ping operations
- file-processor: No capabilities (processing files does not require special privileges)

All containers disable privilege escalation and run as non-root users. The shared volume uses fsGroup for cross-container access.

---

## Common Mistakes

### Adding capability but not enabling it at runtime

Capabilities must be specified correctly in the securityContext. A typo in the capability name results in the capability not being added.

### Dropping ALL without adding required capabilities

When using `drop: ["ALL"]`, you must explicitly add back any capabilities the application needs. Common missing capabilities include NET_RAW (for ping), NET_ADMIN (for network configuration), and NET_BIND_SERVICE (for privileged ports).

### Confusing privileged mode with individual capabilities

`privileged: true` grants all capabilities plus additional access (devices, mounts). Individual capabilities are more secure because they grant only specific privileges.

### allowPrivilegeEscalation not affecting existing processes

allowPrivilegeEscalation sets no_new_privs, which affects processes executed by the container process. The container process itself can still have capabilities, but setuid binaries it runs cannot escalate.

### Capability names without CAP_ prefix in Kubernetes

In Kubernetes manifests, capability names do not include the CAP_ prefix. Write NET_ADMIN, not CAP_NET_ADMIN. Using the wrong format may cause the capability to not be applied.

### Expecting capabilities to work with runAsNonRoot alone

runAsNonRoot validates the user is not root, but does not change capabilities. A non-root container may still have capabilities from the container runtime defaults unless you explicitly drop them.

---

## Capability Debugging Commands Cheat Sheet

| Task | Command |
|------|---------|
| View capability sets | `kubectl exec <pod> -- cat /proc/1/status | grep -i cap` |
| Check no_new_privs flag | `kubectl exec <pod> -- cat /proc/1/status | grep NoNewPrivs` |
| Test NET_ADMIN capability | `kubectl exec <pod> -- ip link set lo down` |
| Test NET_RAW capability | `kubectl exec <pod> -- ping -c 1 127.0.0.1` |
| Test NET_BIND_SERVICE | `kubectl exec <pod> -- nc -l -p 80` (requires nc) |
| View pod security context | `kubectl get pod <pod> -o yaml | grep -A 25 securityContext` |
| Check if privileged | `kubectl get pod <pod> -o jsonpath='{.spec.containers[*].securityContext.privileged}'` |
| Describe pod for errors | `kubectl describe pod <pod>` |

### Common Capability Hex Values

| Capability | Hex Value |
|------------|-----------|
| NET_BIND_SERVICE | 0x0400 |
| NET_RAW | 0x2000 |
| NET_ADMIN | 0x1000 |
| SYS_ADMIN | 0x200000 |
| ALL (all bits set) | 0x1ffffffffff |
