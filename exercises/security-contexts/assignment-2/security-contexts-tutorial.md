# Capabilities and Privilege Control Tutorial

Linux capabilities split what used to be a single "root" privilege into about forty fine-grained permissions, each one guarding a specific class of system call. `CAP_NET_ADMIN` guards network-configuration syscalls; `CAP_NET_RAW` guards raw sockets; `CAP_SYS_TIME` guards clock changes; `CAP_CHOWN` guards changing file ownership across UIDs. A process with `CAP_NET_ADMIN` can do everything root can do with the network but cannot change the wall-clock time (that requires `CAP_SYS_TIME`). The complete list lives in `man 7 capabilities`.

When containerd launches a container, it starts the process with a default subset of capabilities (what the OCI spec calls the "bounding set"). That default is usually too generous for the workload at hand. Kubernetes security contexts expose two fields for managing this: `capabilities.add` adds specific capabilities that are not in the default, and `capabilities.drop` removes capabilities. The hardened baseline (which Pod Security Admission's Restricted profile enforces) is `drop: [ALL]` plus a short `add: []` list containing only the capabilities the workload truly needs.

The companion field `allowPrivilegeEscalation` is a simple Linux kernel knob: `no_new_privs`. When `allowPrivilegeEscalation: false`, the process (and any descendants) can never gain more privileges than it has at start, even if it executes a setuid binary. This blocks `sudo`, `su`, and setuid escalation, and is required by Restricted.

This tutorial walks through each field with a running container so you can prove for yourself exactly which operations each capability gates and how `allowPrivilegeEscalation` interacts with the `nosuid` semantics.

## Prerequisites

Any single-node kind cluster works. See `docs/cluster-setup.md#single-node-kind-cluster` for the creation command and the pinned `kindest/node` version. No additional components are required. Verify the cluster is responsive.

```bash
kubectl get nodes
# Expected: STATUS  Ready
```

Create the tutorial namespace.

```bash
kubectl create namespace tutorial-security-contexts
kubectl config set-context --current --namespace=tutorial-security-contexts
```

## Part 1: The Default Capability Set

Run an unprivileged container with no `securityContext` and read its capability set from `/proc/self/status`. The `CapBnd` (bounding) and `CapEff` (effective) lines are the ones that matter. Each is a bitmask; you can decode it with `capsh`.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: default-caps
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
EOF
kubectl wait --for=condition=Ready pod/default-caps --timeout=60s
kubectl exec default-caps -- sh -c 'apk add --no-cache libcap > /dev/null 2>&1 && grep -E "^Cap(Bnd|Eff|Prm|Inh|Amb)" /proc/self/status'
```

Expected output shape (hex values vary by containerd/kernel version but are consistent across a cluster):

```
CapInh: 0000000000000000
CapPrm: 00000000a80425fb
CapEff: 00000000a80425fb
CapBnd: 00000000a80425fb
CapAmb: 0000000000000000
```

Decode the bounding set.

```bash
kubectl exec default-caps -- capsh --decode=00000000a80425fb
```

Expected output (a single comma-separated string):

```
0x00000000a80425fb=cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,
cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service,cap_net_raw,cap_sys_chroot,
cap_mknod,cap_audit_write,cap_setfcap
```

These are the fourteen capabilities containerd grants by default to an unprivileged container. They are a safer default than full root but still too broad for most workloads. Critically, the set includes `CAP_NET_RAW` (raw sockets, which `ping` uses) and several setid/chown operations. It excludes `CAP_NET_ADMIN`, `CAP_SYS_ADMIN`, `CAP_SYS_TIME`, `CAP_SYS_MODULE`, `CAP_BPF`, and the other dangerous ones. Delete the pod.

```bash
kubectl delete pod default-caps
```

**Spec field reference for `capabilities`:**

- **Type:** object with two fields: `add` and `drop`, each an array of strings.
- **Valid values (strings):** capability names without the `CAP_` prefix. Kubernetes accepts `NET_ADMIN`, not `CAP_NET_ADMIN`. A special value `ALL` in the `drop` list drops every capability.
- **Default:** no `add` or `drop`. Container inherits containerd's default bounding set.
- **Failure mode when misconfigured:** capability names including the `CAP_` prefix silently fail (the controller does not reject the spec; the capability is not in the final set). Adding a capability at pod level has no effect because `capabilities` is a container-level field only. If `capabilities.add` lists a capability that is not in the container's bounding set, adding it is a no-op.

Note: `capabilities` is a container-level field, not a pod-level field. Setting it on `spec.securityContext` has no effect; it must go on `spec.containers[*].securityContext`.

## Part 2: Adding `NET_ADMIN`

Apply a pod that adds `NET_ADMIN` at container level, then use it to configure a network interface, which requires that capability.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: net-admin-demo
spec:
  containers:
  - name: probe
    image: nicolaka/netshoot:v0.13
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        add: ["NET_ADMIN"]
EOF
kubectl wait --for=condition=Ready pod/net-admin-demo --timeout=60s
kubectl exec net-admin-demo -- sh -c 'grep "^CapEff" /proc/self/status && capsh --decode=$(awk "/^CapEff/ {print \$2}" /proc/self/status)'
```

Look for `cap_net_admin` in the decoded list (among others). With `NET_ADMIN` granted, the container can bring an interface down.

```bash
kubectl exec net-admin-demo -- ip link set lo down
kubectl exec net-admin-demo -- ip link show lo
```

Expected output for `ip link show lo`: state `DOWN`. Bring it back up so the verification later succeeds.

```bash
kubectl exec net-admin-demo -- ip link set lo up
```

Delete the pod.

```bash
kubectl delete pod net-admin-demo
```

## Part 3: Dropping `NET_RAW`

`NET_RAW` gates raw-socket creation, which is what `ping` uses to build ICMP packets. Drop it and watch `ping` fail.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: no-net-raw
spec:
  containers:
  - name: probe
    image: nicolaka/netshoot:v0.13
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        drop: ["NET_RAW"]
EOF
kubectl wait --for=condition=Ready pod/no-net-raw --timeout=60s
kubectl exec no-net-raw -- ping -c 1 -W 2 127.0.0.1 2>&1 || true
```

Expected output (exact wording varies by ping version):

```
ping: socket: Operation not permitted
```

The ping binary opened a raw socket, the kernel checked for `CAP_NET_RAW`, the check failed, and the syscall returned `EPERM`. That exact error signature is the key for future debugging: `Operation not permitted` from a network tool almost always means a missing capability rather than a missing permission on a file. Delete the pod.

```bash
kubectl delete pod no-net-raw
```

## Part 4: Drop ALL, Add What You Need

The Restricted-profile pattern is to drop every capability and then add only those the workload specifically needs. Apply a pod that drops all and adds nothing, so the process has no capabilities at all.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: drop-all
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        drop: ["ALL"]
EOF
kubectl wait --for=condition=Ready pod/drop-all --timeout=60s
kubectl exec drop-all -- grep "^CapEff" /proc/self/status
```

Expected output:

```
CapEff: 0000000000000000
```

All zeros. The container has no capabilities. In practice some workloads break (any that try to `chown` a file, bind to a port below 1024 as root, or similar). Add `NET_BIND_SERVICE` if you need the latter.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: drop-all-add-one
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      capabilities:
        drop: ["ALL"]
        add: ["NET_BIND_SERVICE"]
EOF
kubectl wait --for=condition=Ready pod/drop-all-add-one --timeout=60s
kubectl exec drop-all-add-one -- sh -c 'apk add --no-cache libcap > /dev/null 2>&1 && capsh --decode=$(awk "/^CapEff/ {print \$2}" /proc/self/status)'
```

Expected output contains `cap_net_bind_service` and nothing else. Delete both pods.

```bash
kubectl delete pod drop-all drop-all-add-one
```

## Part 5: `allowPrivilegeEscalation: false`

`allowPrivilegeEscalation` is a boolean that sets the Linux `no_new_privs` bit on the container process. When `no_new_privs` is set, `execve` calls cannot gain new privileges, which means setuid binaries do not elevate and capability-granting techniques (such as setcap-flagged executables) do not work.

**Spec field reference for `allowPrivilegeEscalation`:**

- **Type:** `bool`.
- **Valid values:** `true` or `false`.
- **Default:** `true` when not set and the container runs as root; `false` when the container has `privileged: true` (irrelevant interaction) or when the Restricted profile forces it. The OCI default is `true` for backward compatibility.
- **Failure mode when misconfigured:** setting `false` breaks any workload that relies on setuid binaries to elevate (for example, custom container images that use `sudo`, or utilities like `ping` in some distributions that rely on setuid root instead of `cap_net_raw+ep` file capabilities).

Show the effect. Apply a pod that runs as a non-root user with `allowPrivilegeEscalation: false`, then try to use a setuid binary.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: nnp-demo
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 1000
      allowPrivilegeEscalation: false
EOF
kubectl wait --for=condition=Ready pod/nnp-demo --timeout=60s
kubectl exec nnp-demo -- sh -c 'grep "^NoNewPrivs" /proc/self/status'
```

Expected output:

```
NoNewPrivs:	1
```

The kernel has set `no_new_privs`. A setuid binary would have no effect.

```bash
kubectl exec nnp-demo -- sh -c 'cat /proc/self/status | grep -E "^CapEff|^NoNewPrivs"'
```

Expected output: `NoNewPrivs: 1` and `CapEff` that includes the default non-root capability set (no `cap_setuid` elevation path). Delete the pod.

```bash
kubectl delete pod nnp-demo
```

## Part 6: Privileged Containers for Contrast

`privileged: true` is the big hammer: it grants every capability, disables `no_new_privs`, and mounts many of the host's namespaces read-writable. It is almost never the right choice for workloads.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: privileged-demo
spec:
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
EOF
kubectl wait --for=condition=Ready pod/privileged-demo --timeout=60s
kubectl exec privileged-demo -- grep "^CapEff" /proc/self/status
```

Expected output (a mask with every bit set, typically `000001ffffffffff` or similar):

```
CapEff: 000001ffffffffff
```

Decode confirms the process has every capability, including `cap_sys_admin`, `cap_sys_module`, and `cap_sys_rawio`, which are kernel-level privileges. Delete the pod.

```bash
kubectl delete pod privileged-demo
```

**Spec field reference for `privileged`:**

- **Type:** `bool`.
- **Valid values:** `true` or `false`.
- **Default:** `false`.
- **Failure mode when misconfigured:** `privileged: true` is rarely blocked by the runtime but is blocked by Pod Security Admission's Baseline profile. Use it for CNI pods, CSI plugins, and similar node-level infrastructure. Use `capabilities.add` for workloads that need one or two specific privileges; do not reach for `privileged` as a shortcut.

## Part 7: Defense in Depth

The hardened baseline combines several fields. Apply it.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: hardened
spec:
  securityContext:
    runAsUser: 1000
    runAsNonRoot: true
  containers:
  - name: probe
    image: alpine:3.20
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
EOF
kubectl wait --for=condition=Ready pod/hardened --timeout=60s
kubectl exec hardened -- sh -c 'id && grep -E "^CapEff|^NoNewPrivs" /proc/self/status'
```

Expected output:

```
uid=1000 gid=0(root) groups=0(root)
CapEff: 0000000000000000
NoNewPrivs:	1
```

A non-root process, no capabilities, no elevation path. This is the shape Pod Security Admission's Restricted profile enforces. Delete the pod.

```bash
kubectl delete pod hardened
```

## Part 8: Diagnosing Capability Failures

The diagnostic workflow for "operation X fails, probably a capability":

1. Reproduce the failure and capture the exact error.
2. Run `grep "^CapEff" /proc/self/status` inside the container and decode with `capsh`.
3. Look up which capability the failing syscall requires in `man 2 <syscall>` or `man 7 capabilities`.
4. If the capability is missing, add it via `capabilities.add`.
5. If the capability is present but the operation still fails, look at filesystem permissions (identity), `no_new_privs`, seccomp, and AppArmor in that order.

The common mapping:

- `EPERM` on `ioctl(SIOCSIFNETMASK)` or similar network config call: `NET_ADMIN`.
- `EPERM` on `socket(AF_INET, SOCK_RAW, ...)`: `NET_RAW`.
- `EPERM` on `chown`: `CHOWN` (if changing to a different UID), otherwise the operation does not need a capability.
- `EPERM` on `bind(2)` to a port below 1024: `NET_BIND_SERVICE`.
- `EPERM` on `settimeofday` or `clock_settime`: `SYS_TIME`.
- `EPERM` on `mount`, `umount`, `pivot_root`: `SYS_ADMIN`.

## Cleanup

Delete the tutorial namespace to remove every resource created in this walkthrough.

```bash
kubectl delete namespace tutorial-security-contexts
kubectl config set-context --current --namespace=default
```

## Reference Commands

| Task | Command |
|---|---|
| Read the effective capability set | `kubectl exec <pod> -- grep "^CapEff" /proc/self/status` |
| Decode a capability bitmask | `kubectl exec <pod> -- capsh --decode=<hex>` |
| List capabilities on a binary | `kubectl exec <pod> -- getcap /path/to/binary` |
| Check `no_new_privs` | `kubectl exec <pod> -- grep "^NoNewPrivs" /proc/self/status` |
| Show all container securityContexts in a pod | `kubectl get pod <pod> -o jsonpath='{range .spec.containers[*]}{.name}: {.securityContext}{"\n"}{end}'` |

## Key Takeaways

Containerd grants fourteen capabilities by default; the bounding-set hex is `0x00000000a80425fb`. `capabilities.add` adds to that set; `capabilities.drop` removes from it. `drop: [ALL]` is the Restricted-profile starting point; `add` only what is needed. Capability names in Kubernetes omit the `CAP_` prefix. `capabilities` is container-level only, not pod-level. `allowPrivilegeEscalation: false` sets the kernel `no_new_privs` bit, which blocks setuid escalation and similar privilege-gaining mechanisms. The hardened baseline is `runAsNonRoot: true`, `runAsUser` explicit, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`. `privileged: true` grants every capability and is the opposite of hardened; reserve it for node-level infrastructure. The diagnostic path for "operation X fails" starts with `/proc/self/status` CapEff and decodes from there.
