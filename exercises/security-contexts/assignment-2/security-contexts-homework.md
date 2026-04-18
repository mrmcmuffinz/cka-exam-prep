# Security Contexts Homework: Capabilities and Privilege Control

This homework contains 15 progressive exercises to practice Linux capabilities and privilege escalation controls in Kubernetes. Complete the tutorial before attempting these exercises.

---

## Level 1: Inspecting Capabilities

### Exercise 1.1

**Objective:** Examine the default capabilities granted to a container.

**Setup:**

```bash
kubectl create namespace ex-1-1
```

**Task:**

Create a pod named `inspect-caps` in namespace `ex-1-1` using the `busybox:1.36` image with command `["sleep", "3600"]`. Do not configure any security context settings. Then examine the capabilities granted to the container.

**Verification:**

```bash
# Check the pod is running
kubectl get pod -n ex-1-1 inspect-caps

# Expected: Running

# Examine capabilities
kubectl exec -n ex-1-1 inspect-caps -- cat /proc/1/status | grep -i cap

# Expected: CapPrm and CapEff should show non-zero values (default capabilities)
```

---

### Exercise 1.2

**Objective:** Compare capabilities between a regular container and a privileged container.

**Setup:**

```bash
kubectl create namespace ex-1-2
```

**Task:**

Create two pods in namespace `ex-1-2`:
1. A pod named `regular-container` using busybox:1.36 with no special security settings
2. A pod named `privileged-container` using busybox:1.36 with privileged: true

Both should run `["sleep", "3600"]`. Compare their capability sets.

**Verification:**

```bash
# Check both pods are running
kubectl get pods -n ex-1-2

# Compare capabilities
kubectl exec -n ex-1-2 regular-container -- cat /proc/1/status | grep CapEff
kubectl exec -n ex-1-2 privileged-container -- cat /proc/1/status | grep CapEff

# Expected: privileged container shows CapEff: 000001ffffffffff (all capabilities)
# Expected: regular container shows a subset like CapEff: 00000000a80425fb
```

---

### Exercise 1.3

**Objective:** Verify capability sets using /proc/self/status.

**Setup:**

```bash
kubectl create namespace ex-1-3
```

**Task:**

Create a pod named `cap-details` in namespace `ex-1-3` using alpine:3.20 with command `["sleep", "3600"]`. Examine all five capability sets (CapInh, CapPrm, CapEff, CapBnd, CapAmb) and understand what each represents.

**Verification:**

```bash
# Check the pod is running
kubectl get pod -n ex-1-3 cap-details

# View all capability sets
kubectl exec -n ex-1-3 cap-details -- cat /proc/1/status | grep -i cap

# Expected output shows five lines:
# CapInh: Inheritable - capabilities inherited across execve
# CapPrm: Permitted - maximum capabilities the process can use
# CapEff: Effective - capabilities currently in effect
# CapBnd: Bounding - upper limit on capabilities that can be gained
# CapAmb: Ambient - capabilities preserved across execve for non-privileged programs
```

---

## Level 2: Adding and Dropping Capabilities

### Exercise 2.1

**Objective:** Add NET_ADMIN capability to enable network configuration.

**Setup:**

```bash
kubectl create namespace ex-2-1
```

**Task:**

Create a pod named `net-configurator` in namespace `ex-2-1` using busybox:1.36 with command `["sleep", "3600"]`. Add the NET_ADMIN capability so the container can configure network interfaces.

**Verification:**

```bash
# Verify the pod is running
kubectl get pod -n ex-2-1 net-configurator

# Test network administration capability
kubectl exec -n ex-2-1 net-configurator -- ip link show

# Expected: Command succeeds showing network interfaces

# Test modifying interface (should succeed with NET_ADMIN)
kubectl exec -n ex-2-1 net-configurator -- ip link set lo down
kubectl exec -n ex-2-1 net-configurator -- ip link set lo up

# Expected: Both commands succeed without error
```

---

### Exercise 2.2

**Objective:** Drop NET_RAW capability to disable raw socket operations.

**Setup:**

```bash
kubectl create namespace ex-2-2
```

**Task:**

Create a pod named `no-raw-sockets` in namespace `ex-2-2` using busybox:1.36 with command `["sleep", "3600"]`. Drop the NET_RAW capability to prevent raw socket operations like ping.

**Verification:**

```bash
# Verify the pod is running
kubectl get pod -n ex-2-2 no-raw-sockets

# Test that ping fails (requires NET_RAW)
kubectl exec -n ex-2-2 no-raw-sockets -- ping -c 1 127.0.0.1

# Expected: ping fails with "Operation not permitted"

# Verify other network operations still work
kubectl exec -n ex-2-2 no-raw-sockets -- wget -q -O - http://kubernetes.default.svc 2>&1 | head -1

# Expected: Some response (may be an error page, but the connection attempt works)
```

---

### Exercise 2.3

**Objective:** Implement the "drop all, add specific" pattern.

**Setup:**

```bash
kubectl create namespace ex-2-3
```

**Task:**

Create a pod named `minimal-privileges` in namespace `ex-2-3` using busybox:1.36 with command `["sleep", "3600"]`. Configure the container to:
1. Drop ALL capabilities
2. Add back only NET_BIND_SERVICE (allows binding to ports below 1024)

**Verification:**

```bash
# Verify the pod is running
kubectl get pod -n ex-2-3 minimal-privileges

# Check capabilities (should only show NET_BIND_SERVICE)
kubectl exec -n ex-2-3 minimal-privileges -- cat /proc/1/status | grep CapEff

# Expected: CapEff should show only NET_BIND_SERVICE bit set (0000000000000400)

# Verify ping fails (NET_RAW is dropped)
kubectl exec -n ex-2-3 minimal-privileges -- ping -c 1 127.0.0.1

# Expected: Operation not permitted
```

---

## Level 3: Debugging Capability Issues

### Exercise 3.1

**Objective:** A container cannot perform network configuration. Find and fix the issue.

**Setup:**

```bash
kubectl create namespace ex-3-1

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
EOF
```

**Task:**

The pod above is failing because the container cannot add an IP address to an interface. Diagnose why this operation is failing and fix the pod configuration.

**Verification:**

```bash
# After fixing, verify the pod is running
kubectl get pod -n ex-3-1 network-manager

# Expected: Running (not CrashLoopBackOff)

# Verify the IP was added
kubectl exec -n ex-3-1 network-manager -- ip addr show lo

# Expected: Should show 10.200.0.1/24 on the lo interface
```

---

### Exercise 3.2

**Objective:** A security-hardened container cannot run its application. Find and fix the issue.

**Setup:**

```bash
kubectl create namespace ex-3-2

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
EOF
```

**Task:**

The pod above is configured with maximum security (all capabilities dropped) but the application requires ping functionality. Fix the configuration to allow ping while maintaining the drop-all approach for other capabilities.

**Verification:**

```bash
# After fixing, verify the pod is running
kubectl get pod -n ex-3-2 ping-service

# Expected: Running

# Verify ping works
kubectl exec -n ex-3-2 ping-service -- ping -c 1 127.0.0.1

# Expected: Successful ping response
```

---

### Exercise 3.3

**Objective:** An application using setuid binaries is failing. Find and fix the issue.

**Setup:**

```bash
kubectl create namespace ex-3-3

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: setuid-app
  namespace: ex-3-3
spec:
  securityContext:
    runAsUser: 1000
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
        add: ["SETUID", "SETGID"]
EOF
```

**Task:**

The pod above is configured to allow SETUID and SETGID capabilities, but privilege escalation is blocked. The application needs to use setuid binaries. However, there is a conflict in the configuration. Analyze the configuration to understand why setuid functionality may not work as expected, and explain the interaction between allowPrivilegeEscalation and capabilities.

**Verification:**

```bash
# Verify the pod is running
kubectl get pod -n ex-3-3 setuid-app

# Check the no_new_privs flag
kubectl exec -n ex-3-3 setuid-app -- cat /proc/1/status | grep NoNewPrivs

# Expected: NoNewPrivs: 1

# The key insight: even though SETUID capability is added,
# allowPrivilegeEscalation: false prevents privilege escalation.
# This is a documentation/understanding exercise.
```

---

## Level 4: Privilege Escalation Control

### Exercise 4.1

**Objective:** Configure a container to prevent privilege escalation.

**Setup:**

```bash
kubectl create namespace ex-4-1
```

**Task:**

Create a pod named `no-escalation` in namespace `ex-4-1` using busybox:1.36 with command `["sleep", "3600"]`. Configure the container to:
1. Run as user 1000
2. Prevent privilege escalation
3. Keep default capabilities (do not drop any)

**Verification:**

```bash
# Verify the pod is running
kubectl get pod -n ex-4-1 no-escalation

# Check user identity
kubectl exec -n ex-4-1 no-escalation -- id

# Expected: uid=1000

# Check no_new_privs flag
kubectl exec -n ex-4-1 no-escalation -- cat /proc/1/status | grep NoNewPrivs

# Expected: NoNewPrivs: 1

# Verify capabilities are still present
kubectl exec -n ex-4-1 no-escalation -- cat /proc/1/status | grep CapEff

# Expected: Non-zero value showing default capabilities
```

---

### Exercise 4.2

**Objective:** Combine multiple security controls for defense in depth.

**Setup:**

```bash
kubectl create namespace ex-4-2
```

**Task:**

Create a pod named `defense-in-depth` in namespace `ex-4-2` using busybox:1.36 with command `["sleep", "3600"]`. Configure the pod with all recommended security controls:
1. Run as non-root user (UID 1000)
2. Run as non-root group (GID 1000)
3. Enforce runAsNonRoot validation
4. Prevent privilege escalation
5. Drop all capabilities

**Verification:**

```bash
# Verify the pod is running
kubectl get pod -n ex-4-2 defense-in-depth

# Check user identity
kubectl exec -n ex-4-2 defense-in-depth -- id

# Expected: uid=1000 gid=1000

# Check no_new_privs
kubectl exec -n ex-4-2 defense-in-depth -- cat /proc/1/status | grep NoNewPrivs

# Expected: NoNewPrivs: 1

# Check all capabilities are dropped
kubectl exec -n ex-4-2 defense-in-depth -- cat /proc/1/status | grep CapEff

# Expected: CapEff: 0000000000000000
```

---

### Exercise 4.3

**Objective:** Test privilege escalation behavior with different configurations.

**Setup:**

```bash
kubectl create namespace ex-4-3
```

**Task:**

Create two pods in namespace `ex-4-3` to compare privilege escalation behavior:

1. Pod named `with-escalation`: runs as user 1000, allowPrivilegeEscalation: true (or not specified)
2. Pod named `without-escalation`: runs as user 1000, allowPrivilegeEscalation: false

Both use busybox:1.36 with command `["sleep", "3600"]`.

**Verification:**

```bash
# Verify both pods are running
kubectl get pods -n ex-4-3

# Check NoNewPrivs for both containers
kubectl exec -n ex-4-3 with-escalation -- cat /proc/1/status | grep NoNewPrivs
# Expected: NoNewPrivs: 0 (privilege escalation allowed)

kubectl exec -n ex-4-3 without-escalation -- cat /proc/1/status | grep NoNewPrivs
# Expected: NoNewPrivs: 1 (privilege escalation blocked)
```

---

## Level 5: Complex Scenarios

### Exercise 5.1

**Objective:** Configure minimal capabilities for a network monitoring application.

**Setup:**

```bash
kubectl create namespace ex-5-1
```

**Task:**

Create a pod named `network-monitor` in namespace `ex-5-1` that simulates a network monitoring application. The application needs to:
1. Use ping to check host availability (requires NET_RAW)
2. Inspect network interfaces (requires NET_ADMIN)
3. Run as non-root user 1000
4. Have privilege escalation disabled
5. Drop all other capabilities

Use busybox:1.36 with a command that pings localhost and shows interface info: `["sh", "-c", "ping -c 2 127.0.0.1 && ip link show && sleep 3600"]`

**Verification:**

```bash
# Verify the pod is running (not in CrashLoopBackOff)
kubectl get pod -n ex-5-1 network-monitor

# Check logs for successful ping and ip output
kubectl logs -n ex-5-1 network-monitor

# Expected: Successful ping output and interface list

# Verify capabilities are minimal
kubectl exec -n ex-5-1 network-monitor -- cat /proc/1/status | grep CapEff

# Expected: Only NET_RAW and NET_ADMIN bits should be set

# Verify user is non-root
kubectl exec -n ex-5-1 network-monitor -- id

# Expected: uid=1000
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
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
EOF
```

**Task:**

The pod above has multiple security constraints configured but is failing to run its command. The application needs to:
1. Ping localhost
2. Show network interfaces
3. Write data to /data

Diagnose all issues and fix the configuration while maintaining as much security as possible.

**Verification:**

```bash
# After fixing, verify the pod is running
kubectl get pod -n ex-5-2 constrained-app

# Expected: Running

# Verify all commands succeeded
kubectl logs -n ex-5-2 constrained-app

# Expected: Ping output, interface list

# Verify file was written
kubectl exec -n ex-5-2 constrained-app -- cat /data/output.txt

# Expected: data

# Verify security constraints are still in place
kubectl exec -n ex-5-2 constrained-app -- id
# Expected: uid=1000

kubectl exec -n ex-5-2 constrained-app -- cat /proc/1/status | grep NoNewPrivs
# Expected: NoNewPrivs: 1
```

---

### Exercise 5.3

**Objective:** Design a capability strategy for a multi-container pod.

**Setup:**

```bash
kubectl create namespace ex-5-3
```

**Task:**

Design and implement a pod named `multi-service` in namespace `ex-5-3` with three containers, each with different capability requirements:

1. Container `web-server` (nginx:1.25):
   - Needs NET_BIND_SERVICE to bind to privileged ports (though running as non-root user 101)
   - Should drop all other capabilities
   - Runs as user 101

2. Container `network-probe` (busybox:1.36):
   - Needs NET_RAW for ping operations
   - Should drop all other capabilities
   - Runs as user 1000
   - Command: `["sh", "-c", "while true; do ping -c 1 127.0.0.1 > /dev/null && echo 'probe ok'; sleep 30; done"]`

3. Container `file-processor` (busybox:1.36):
   - Needs no special capabilities
   - Should drop ALL capabilities
   - Runs as user 2000
   - Writes to shared volume
   - Command: `["sh", "-c", "echo 'processed' > /shared/status.txt && sleep 3600"]`

All containers should:
- Have privilege escalation disabled
- Share a volume at /shared

**Verification:**

```bash
# Verify all containers are running
kubectl get pod -n ex-5-3 multi-service
# Expected: All 3 containers Running

# Verify web-server user
kubectl exec -n ex-5-3 multi-service -c web-server -- id
# Expected: uid=101

# Verify network-probe can ping
kubectl exec -n ex-5-3 multi-service -c network-probe -- ping -c 1 127.0.0.1
# Expected: Successful ping

# Verify file-processor wrote to shared volume
kubectl exec -n ex-5-3 multi-service -c file-processor -- cat /shared/status.txt
# Expected: processed

# Verify all containers have NoNewPrivs set
kubectl exec -n ex-5-3 multi-service -c web-server -- cat /proc/1/status | grep NoNewPrivs
kubectl exec -n ex-5-3 multi-service -c network-probe -- cat /proc/1/status | grep NoNewPrivs
kubectl exec -n ex-5-3 multi-service -c file-processor -- cat /proc/1/status | grep NoNewPrivs
# Expected: All show NoNewPrivs: 1
```

---

## Cleanup

Delete all exercise namespaces:

```bash
kubectl delete namespace ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3
```

---

## Key Takeaways

1. **Capabilities** provide fine-grained control over privileges, replacing all-or-nothing root access
2. **Default capabilities** depend on the container runtime and are typically a restricted subset
3. **Privileged containers** have all capabilities and should be avoided in production
4. **Drop ALL, add specific** is the recommended pattern for production containers
5. **allowPrivilegeEscalation: false** prevents processes from gaining new privileges via setuid binaries
6. **Defense in depth** combines runAsNonRoot, allowPrivilegeEscalation: false, and capabilities.drop
7. Capability names in Kubernetes do not include the CAP_ prefix
