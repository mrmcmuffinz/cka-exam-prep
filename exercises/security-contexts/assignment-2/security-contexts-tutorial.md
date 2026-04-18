# Security Contexts Tutorial: Capabilities and Privilege Control

## Introduction

Linux capabilities provide a way to grant specific privileges to processes without giving them full root access. Instead of the traditional all-or-nothing model where a process either runs as root with all privileges or as a regular user with limited privileges, capabilities break down root's powers into distinct units that can be independently enabled or disabled.

Understanding capabilities is essential for securing containers in Kubernetes. By default, containers receive a set of capabilities from the container runtime. You can add capabilities when an application needs specific privileges, or drop capabilities to reduce the attack surface. Combined with allowPrivilegeEscalation controls, capabilities form a key part of container security.

In this tutorial, you will learn how capabilities work, how to inspect them in containers, how to add and drop specific capabilities, and how to prevent privilege escalation.

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

## Understanding Linux Capabilities

Traditionally, Linux processes were either privileged (running as root with UID 0) or unprivileged. Root processes could do anything: bind to privileged ports, modify the system clock, load kernel modules, and more.

Capabilities split these root privileges into distinct units. Some common capabilities include:

| Capability | What it allows |
|------------|----------------|
| NET_ADMIN | Configure network interfaces, routing tables, firewalls |
| NET_BIND_SERVICE | Bind to ports below 1024 |
| NET_RAW | Use raw sockets (for ping, packet capture) |
| SYS_TIME | Set the system clock |
| SYS_ADMIN | A broad capability for system administration tasks |
| SETUID | Change user IDs |
| SETGID | Change group IDs |
| CHOWN | Change file ownership |
| DAC_OVERRIDE | Bypass file permission checks |

In Kubernetes, capability names are specified without the CAP_ prefix. You write NET_ADMIN, not CAP_NET_ADMIN.

## Inspecting Default Capabilities

Let us start by examining what capabilities a container receives by default. Create a pod and check its capabilities:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: default-caps
  namespace: tutorial-security-contexts
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
```

Wait for the pod to start:

```bash
kubectl wait --for=condition=Ready pod/default-caps --timeout=60s
```

Check the capabilities using /proc/self/status:

```bash
kubectl exec default-caps -- cat /proc/1/status | grep -i cap
```

The output shows capability sets in hexadecimal format:

```
CapInh: 0000000000000000
CapPrm: 00000000a80425fb
CapEff: 00000000a80425fb
CapBnd: 00000000a80425fb
CapAmb: 0000000000000000
```

These hexadecimal values represent bitmasks of enabled capabilities. The specific capabilities depend on your container runtime's default configuration.

To decode these, you can use the capsh utility if available, or compare against known capability values. The key point is that unprivileged containers receive a limited set of capabilities by default.

## Running a Privileged Container

Privileged containers receive all capabilities. This is dangerous in production but useful for understanding the difference:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: privileged-caps
  namespace: tutorial-security-contexts
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
EOF
```

Wait for the pod:

```bash
kubectl wait --for=condition=Ready pod/privileged-caps --timeout=60s
```

Compare the capabilities:

```bash
kubectl exec privileged-caps -- cat /proc/1/status | grep -i cap
```

The privileged container shows all capabilities enabled (CapEff and CapPrm show all bits set). This demonstrates why privileged mode is dangerous: it grants complete access to the host system.

## Adding Capabilities

Sometimes an application needs a specific capability that is not in the default set. You can add individual capabilities without granting full privileged access.

For example, suppose you need to configure network interfaces. This requires NET_ADMIN capability. Create a pod that adds this capability:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: net-admin-demo
  namespace: tutorial-security-contexts
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

Wait for the pod:

```bash
kubectl wait --for=condition=Ready pod/net-admin-demo --timeout=60s
```

Now test network administration capabilities. The ip command requires NET_ADMIN to modify interfaces:

```bash
kubectl exec net-admin-demo -- ip link set lo down
kubectl exec net-admin-demo -- ip link set lo up
```

These commands succeed because NET_ADMIN is granted. Without this capability, they would fail with "Operation not permitted."

## Dropping Capabilities

Dropping capabilities reduces the attack surface by removing privileges the application does not need. The most secure pattern is to drop ALL capabilities and then add back only what is required.

Create a pod that drops all capabilities:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: no-caps-demo
  namespace: tutorial-security-contexts
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        drop: ["ALL"]
EOF
```

Wait for the pod:

```bash
kubectl wait --for=condition=Ready pod/no-caps-demo --timeout=60s
```

Check the capabilities:

```bash
kubectl exec no-caps-demo -- cat /proc/1/status | grep -i cap
```

All capability sets show 0000000000000000, meaning no capabilities are granted.

Try to ping, which requires NET_RAW:

```bash
kubectl exec no-caps-demo -- ping -c 1 127.0.0.1
```

This fails with "Operation not permitted" because NET_RAW was dropped along with all other capabilities.

## Drop All, Add Specific

The recommended pattern for production containers is to drop all capabilities and add back only what the application needs:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: minimal-caps
  namespace: tutorial-security-contexts
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        drop: ["ALL"]
        add: ["NET_RAW"]
EOF
```

Wait for the pod:

```bash
kubectl wait --for=condition=Ready pod/minimal-caps --timeout=60s
```

Now ping works:

```bash
kubectl exec minimal-caps -- ping -c 1 127.0.0.1
```

But network administration does not:

```bash
kubectl exec minimal-caps -- ip link set lo down
```

This approach gives the container exactly the capabilities it needs and nothing more.

## Understanding allowPrivilegeEscalation

The allowPrivilegeEscalation field controls whether a process can gain more privileges than its parent process. This affects setuid binaries, which are executables that run with the privileges of their owner (often root) regardless of who executes them.

When allowPrivilegeEscalation is false:
- Setuid binaries cannot elevate privileges
- The no_new_privs flag is set on the process
- Capabilities cannot be gained through execution

Create a pod with privilege escalation disabled:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: no-escalation
  namespace: tutorial-security-contexts
spec:
  containers:
  - name: test
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
EOF
```

Wait for the pod:

```bash
kubectl wait --for=condition=Ready pod/no-escalation --timeout=60s
```

Check that no_new_privs is set:

```bash
kubectl exec no-escalation -- cat /proc/1/status | grep NoNewPrivs
```

You should see NoNewPrivs: 1, indicating privilege escalation is blocked.

## Defense in Depth: Combining Security Controls

The most secure containers combine multiple security controls. A good baseline configuration includes:

- **runAsNonRoot: true** to prevent running as root
- **allowPrivilegeEscalation: false** to prevent privilege escalation
- **capabilities.drop: ["ALL"]** to remove all capabilities
- Only add back specific capabilities that are absolutely required

Create a hardened container:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: hardened-demo
  namespace: tutorial-security-contexts
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

Wait for the pod:

```bash
kubectl wait --for=condition=Ready pod/hardened-demo --timeout=60s
```

Verify all security settings:

```bash
# Check user identity
kubectl exec hardened-demo -- id

# Check capabilities (should all be zero)
kubectl exec hardened-demo -- cat /proc/1/status | grep -i cap

# Check no_new_privs
kubectl exec hardened-demo -- cat /proc/1/status | grep NoNewPrivs
```

This container runs as a non-root user with no capabilities and cannot escalate privileges. An attacker who compromises this container has very limited options.

## Verifying Capabilities

When troubleshooting capability issues, you need to identify which capabilities a container has and which ones an operation requires.

To check current capabilities:

```bash
kubectl exec <pod-name> -- cat /proc/1/status | grep -i cap
```

To decode capability values, you can use the capsh command if available in the container:

```bash
kubectl exec <pod-name> -- capsh --decode=<hex-value>
```

Common capability-related error messages:
- "Operation not permitted" often indicates a missing capability
- "Permission denied" could be a capability issue or a file permission issue

To identify which capability an operation needs, consult the Linux capabilities man page (man 7 capabilities) or experiment by adding capabilities one at a time.

## Cleanup

Delete the tutorial namespace and all resources:

```bash
kubectl delete namespace tutorial-security-contexts
```

## Reference Commands

| Task | Command |
|------|---------|
| Check container capabilities | `kubectl exec <pod> -- cat /proc/1/status | grep -i cap` |
| Check no_new_privs flag | `kubectl exec <pod> -- cat /proc/1/status | grep NoNewPrivs` |
| Test network admin capability | `kubectl exec <pod> -- ip link show` |
| Test raw socket capability | `kubectl exec <pod> -- ping -c 1 127.0.0.1` |
| View pod security context | `kubectl get pod <pod> -o yaml | grep -A 20 securityContext` |

## Key Takeaways

1. **Capabilities** provide fine-grained privileges instead of all-or-nothing root access
2. **Default capabilities** are granted by the container runtime and vary by runtime
3. **Privileged mode** grants all capabilities and should be avoided in production
4. **Drop ALL capabilities** and add back only what is needed for defense in depth
5. **allowPrivilegeEscalation: false** prevents processes from gaining new privileges
6. **Combine multiple controls** for defense in depth: runAsNonRoot, allowPrivilegeEscalation, and capabilities.drop
7. **Capability names** in Kubernetes do not include the CAP_ prefix
