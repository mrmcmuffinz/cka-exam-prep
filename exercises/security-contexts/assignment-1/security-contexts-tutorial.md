# User and Group Security Contexts Tutorial

Every container process on Linux runs with four identity inputs: a UID, a primary GID, a list of supplementary GIDs, and (for any files created) a default group. Container images ship with a baked-in default for each of these in their OCI manifest, but those defaults are usually wrong for a production Kubernetes cluster. `busybox:1.36` defaults to UID 0 (root) because Dockerfile authors rarely bother to add a `USER` directive, which means that unless you override it, every container you ship runs the application as root, inside a namespace and filesystem that can interact with a kernel the rest of the cluster is also using.

The pod spec's `securityContext` is how you override those defaults. It is the single place you say "run as this UID," "run as this primary GID," "belong to these additional groups," and "make volumes accessible under this group." Get any of those four wrong and the most common symptom is a `Permission denied` error when the application tries to write a log file or open a listening port. This tutorial walks through each of the four identity fields in turn, proving with the output of `id` inside the container exactly what changed, and then pairs them with an `emptyDir` volume so you can see the ownership and setgid-bit interaction end to end.

The CKA exam tests these fields as part of the Domain 2 "Workloads and Scheduling" competency "understand application security mechanisms." Pod Security Admission (covered in a separate assignment) enforces many of these fields cluster-wide under the Restricted profile, so owning the mechanics here is a prerequisite for every later security topic.

## Prerequisites

Any single-node kind cluster works for this tutorial. See `docs/cluster-setup.md#single-node-kind-cluster` for the exact creation command and `kindest/node` version. No CNI, storage, or admission controller changes are required. Verify the cluster is responsive before starting.

```bash
kubectl get nodes
# Expected: STATUS  Ready
```

Create the tutorial namespace and make it the default for this shell so every later command does not need `-n tutorial-security-contexts`.

```bash
kubectl create namespace tutorial-security-contexts
kubectl config set-context --current --namespace=tutorial-security-contexts
```

## Part 1: The Image Default

Before overriding anything, confirm what the image actually runs as by default. Run a `busybox:1.36` pod with no `securityContext` at all.

```bash
kubectl run default-identity --image=busybox:1.36 --restart=Never --command -- sleep 3600
kubectl wait --for=condition=Ready pod/default-identity --timeout=60s
kubectl exec default-identity -- id
```

Expected output:

```
uid=0(root) gid=0(root) groups=0(root),10(wheel)
```

The container is running as root because the `busybox:1.36` image's OCI config did not specify a `USER` field and Kubernetes did not override it. This is the starting point. The rest of the tutorial walks through the fields that change what that line of output looks like. Clean this pod up.

```bash
kubectl delete pod default-identity
```

## Part 2: `runAsUser` (the effective UID)

`runAsUser` is the most direct identity override: it sets the numeric UID the container process runs as. The field lives under `spec.securityContext` (pod level) or `spec.containers[*].securityContext` (container level). Container-level wins when both are set.

**Spec field reference for `runAsUser`:**

- **Type:** `int64` (UID number).
- **Valid values:** any non-negative integer representing a UID on the container's user namespace. UID 0 is root; UIDs 1 to 999 are conventionally reserved for system accounts; 1000+ are typical user accounts.
- **Default:** if omitted and the image has no `USER` directive, the container runs as root. If the image has a `USER`, that USER applies.
- **Failure mode when misconfigured:** if the UID does not exist in `/etc/passwd` inside the image, processes still run with the numeric UID but `id` shows only the number, with no username. If `runAsNonRoot: true` is also set and the value is `0`, the kubelet refuses to start the container with `CreateContainerConfigError`.

Apply a pod that runs as UID 1000.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: user-only
spec:
  securityContext:
    runAsUser: 1000
  containers:
  - name: demo
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
kubectl wait --for=condition=Ready pod/user-only --timeout=60s
kubectl exec user-only -- id
```

Expected output:

```
uid=1000 gid=0(root) groups=0(root)
```

The UID changed to 1000 but the primary GID is still 0 (root). Setting `runAsUser` alone does not change the primary group. That observation matters later, because a process with `uid=1000 gid=0` can still access files owned by root without any supplemental-group tricks, which may or may not be what you want. Also note that `uid=1000` has no username attached (no `(somename)` in parentheses); UID 1000 does not exist in the `busybox` image's `/etc/passwd`, so the kernel reports the bare number.

Delete the pod.

```bash
kubectl delete pod user-only
```

## Part 3: `runAsGroup` (the primary GID)

`runAsGroup` sets the process's primary GID. Files the container creates will be owned by that group, and file-permission checks use that group's access-mode bits.

**Spec field reference for `runAsGroup`:**

- **Type:** `int64` (GID number).
- **Valid values:** any non-negative integer GID. Like UIDs, 1 to 999 are conventionally reserved; 1000+ are typical user groups.
- **Default:** if omitted, the primary group is taken from the image's `USER` directive (`USER 1000:2000` sets GID 2000); if the image has no group specified, the primary GID defaults to 0 (root).
- **Failure mode when misconfigured:** if `runAsGroup` is set but `runAsUser` is not, the container still runs as the image's user (often root), with a mismatched primary group. This is rarely what you want.

Apply a pod setting both `runAsUser` and `runAsGroup`.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: user-and-group
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
  containers:
  - name: demo
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
kubectl wait --for=condition=Ready pod/user-and-group --timeout=60s
kubectl exec user-and-group -- id
```

Expected output:

```
uid=1000 gid=3000 groups=3000
```

The process now has GID 3000 both as its primary group and as its only supplementary group. Create a file and inspect ownership.

```bash
kubectl exec user-and-group -- sh -c 'echo hello > /tmp/file && ls -la /tmp/file'
```

Expected output (formatting approximate):

```
-rw-r--r--    1 1000     3000             6 ... /tmp/file
```

Ownership is `1000:3000`, confirming `runAsGroup` is the primary group for new files. Delete the pod.

```bash
kubectl delete pod user-and-group
```

## Part 4: `runAsNonRoot` (the validator)

`runAsNonRoot` is not an identity setter. It is a boolean gate that runs at container start. The kubelet checks the effective UID (from `runAsUser` first, then the image's `USER` directive second), and if that UID is 0 the kubelet refuses to start the container. This is the fail-closed complement to `runAsUser`: you state the intent and Kubernetes blocks the accidental regression where someone forgets the `runAsUser` override.

**Spec field reference for `runAsNonRoot`:**

- **Type:** `bool`.
- **Valid values:** `true` or `false`.
- **Default:** `false` (unset behaves identically to false).
- **Failure mode when misconfigured:** with `runAsNonRoot: true` and an effective UID of 0, the pod never starts. The container enters `CreateContainerConfigError` or `CreateContainerError` with message `Error: container has runAsNonRoot and image will run as root`. This is the single easiest way to identify the misconfiguration: the error message is literal and specific.

Show the success case: `runAsNonRoot: true` plus an explicit non-root `runAsUser`.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: nonroot-ok
spec:
  securityContext:
    runAsUser: 1000
    runAsNonRoot: true
  containers:
  - name: demo
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
kubectl wait --for=condition=Ready pod/nonroot-ok --timeout=60s
kubectl exec nonroot-ok -- id
```

Expected output:

```
uid=1000 gid=0(root) groups=0(root)
```

Now show the failure case: `runAsNonRoot: true` without a `runAsUser` override.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: nonroot-fail
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: demo
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
sleep 5
kubectl get pod nonroot-fail
```

Expected output (substring):

```
STATUS
CreateContainerConfigError
```

Look at the container status for the literal message.

```bash
kubectl get pod nonroot-fail -o jsonpath='{.status.containerStatuses[0].state.waiting.message}'
```

Expected output:

```
container has runAsNonRoot and image will run as root
```

This error message is intentionally exact. If you see it, the fix is either to set `runAsUser` to a non-zero UID on the pod or container, or to switch to an image whose `USER` is not 0. Delete both pods.

```bash
kubectl delete pod nonroot-ok nonroot-fail
```

## Part 5: `supplementalGroups` (extra memberships)

The UID and primary GID are the identity the container announces when making files. Supplementary groups are additional memberships that get used for permission checks. If a file is owned by `root:5000` and the container is `uid=1000 gid=3000 groups=3000,5000`, the group-mode bits on that file apply (because 5000 is in the process's groups list). Without that supplementary membership, the process would fall through to the file's other-mode bits instead.

**Spec field reference for `supplementalGroups`:**

- **Type:** `[]int64` (array of GID numbers).
- **Valid values:** a list of non-negative GIDs.
- **Default:** empty list. The container only has the primary GID plus the groups declared in the image's `/etc/group` for the image's user.
- **Failure mode when misconfigured:** if an application expects to belong to a specific group (for example, to read a shared-cache directory), but `supplementalGroups` does not include that GID, file access returns `Permission denied`. The symptom is indistinguishable from an `fsGroup` misconfiguration until you run `id` inside the container.

Apply a pod with several supplementary groups.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: supp-groups
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    supplementalGroups: [4000, 5000]
  containers:
  - name: demo
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
kubectl wait --for=condition=Ready pod/supp-groups --timeout=60s
kubectl exec supp-groups -- id
```

Expected output:

```
uid=1000 gid=3000 groups=3000,4000,5000
```

The primary group 3000 appears first, then each supplementary group in order. Delete the pod.

```bash
kubectl delete pod supp-groups
```

## Part 6: `fsGroup` and volume ownership

`fsGroup` is a special field. It does two things at once: (1) it adds a GID to the container's supplementary groups, and (2) it tells Kubernetes to recursively chown the root of every eligible mounted volume to that GID, to set the group-mode bits on those files to be readable and writable by that group, and to set the setgid bit on directories so that any new files created inside them inherit the group ownership automatically.

The volume types that respect `fsGroup` include `emptyDir`, `configMap`, `secret`, `downwardAPI`, `projected`, and PVC-backed volumes whose backing provisioner supports ownership change (most block-storage backends do). `hostPath` does not respect `fsGroup` because the host filesystem is outside Kubernetes's control.

**Spec field reference for `fsGroup`:**

- **Type:** `int64` (GID number).
- **Valid values:** any non-negative GID.
- **Default:** unset. When unset, mounted volume ownership comes from whatever the underlying volume backend sets (typically root:root for `emptyDir`).
- **Failure mode when misconfigured:** a container running as a non-root UID without an `fsGroup` that covers the volume's group ownership cannot write to the volume. Symptom: `touch: /data/file: Permission denied`.

**Spec field reference for `fsGroupChangePolicy`:**

- **Type:** `string`.
- **Valid values:** `OnRootMismatch` or `Always`.
- **Default:** `Always` (if the field is omitted, Kubernetes recursively chowns on every mount, which is slow for volumes with many files).
- **Failure mode when misconfigured:** `OnRootMismatch` skips the chown if the volume root already has the target group. If the volume's contents were previously chowned to a different group below the root, the old group ownership persists. Use `Always` when in doubt; use `OnRootMismatch` only to avoid slow mounts on large volumes.

Apply a pod that has `fsGroup` and an `emptyDir`.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: fsgroup-demo
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
  containers:
  - name: demo
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
EOF
kubectl wait --for=condition=Ready pod/fsgroup-demo --timeout=60s
kubectl exec fsgroup-demo -- id
```

Expected output:

```
uid=1000 gid=3000 groups=2000,3000
```

`fsGroup: 2000` shows up in the supplementary groups list even though it was not in `supplementalGroups`. Now inspect the volume itself.

```bash
kubectl exec fsgroup-demo -- ls -ld /data
```

Expected output (field-for-field):

```
drwxrwsrwx    2 root     2000             ... /data
```

Two things changed from the default: the group is `2000` (the fsGroup), and the group-mode bits include `s` (the setgid bit, the `s` replaces the group `x` character). With setgid on a directory, any file created inside inherits the directory's group, regardless of the creator's primary group. Prove that.

```bash
kubectl exec fsgroup-demo -- sh -c 'echo test > /data/file && ls -la /data/file'
```

Expected output:

```
-rw-r--r--    1 1000     2000             5 ... /data/file
```

File is owned by `1000:2000`: UID from `runAsUser`, group from the setgid directory (which got its group from `fsGroup`). The container's primary GID (3000) is not the group on this file, because the setgid bit is set on the parent. Delete the pod.

```bash
kubectl delete pod fsgroup-demo
```

## Part 7: Pod-level vs container-level precedence

Every identity field (`runAsUser`, `runAsGroup`, `runAsNonRoot`) can be set at pod level (applies to every container) or at container level (applies only to that container). `fsGroup` and `supplementalGroups` live only at pod level, because they affect the pod sandbox and all containers in the pod share it.

The precedence rule is simple: container-level wins if both are set. Apply a pod where the pod sets 1000:3000 but one of the two containers overrides.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: precedence-demo
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
  containers:
  - name: inherits
    image: busybox:1.36
    command: ["sleep", "3600"]
  - name: overrides
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 2000
      runAsGroup: 4000
EOF
kubectl wait --for=condition=Ready pod/precedence-demo --timeout=60s
kubectl exec precedence-demo -c inherits -- id
kubectl exec precedence-demo -c overrides -- id
```

Expected output:

```
uid=1000 gid=3000 groups=3000
uid=2000 gid=4000 groups=4000
```

The `inherits` container took the pod-level settings; the `overrides` container applied its own. Both containers share the same network namespace, filesystem namespace, and (if any) volume mounts; only identity differs. Delete the pod.

```bash
kubectl delete pod precedence-demo
```

## Part 8: Shared volume across two different UIDs

The most instructive scenario for `fsGroup` is a pod with two containers running as different UIDs, sharing one `emptyDir`. Because `fsGroup` recursively owns the volume, and because both containers belong to the fsGroup via the supplementary groups mechanism, both can read and write the same files.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: shared-volume
spec:
  securityContext:
    fsGroup: 2000
  containers:
  - name: writer
    image: busybox:1.36
    command: ["sh", "-c", "echo from-writer > /data/file1 && sleep 3600"]
    securityContext:
      runAsUser: 1000
    volumeMounts:
    - name: data
      mountPath: /data
  - name: reader
    image: busybox:1.36
    command: ["sh", "-c", "sleep 2 && cat /data/file1 && sleep 3600"]
    securityContext:
      runAsUser: 2000
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
EOF
kubectl wait --for=condition=Ready pod/shared-volume --timeout=60s
kubectl logs shared-volume -c reader
```

Expected output:

```
from-writer
```

The reader container (UID 2000) successfully read a file the writer container (UID 1000) created, because both belonged to group 2000 via `fsGroup` and the file inherited that group via the setgid bit. Delete the pod.

```bash
kubectl delete pod shared-volume
```

## Part 9: `fsGroup` does not apply to `hostPath`

For contrast, mount the node's filesystem with `hostPath` and observe that `fsGroup` is ignored.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-demo
spec:
  securityContext:
    runAsUser: 1000
    fsGroup: 2000
  containers:
  - name: demo
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: host
      mountPath: /host
  volumes:
  - name: host
    hostPath:
      path: /tmp
      type: Directory
EOF
kubectl wait --for=condition=Ready pod/hostpath-demo --timeout=60s
kubectl exec hostpath-demo -- ls -ld /host
```

Expected output (contains):

```
drwxrwxrwt    ... root     root             ... /host
```

Ownership is still `root:root`, and the setgid bit is not set. Kubernetes deliberately does not change ownership on `hostPath` volumes because that would mutate the underlying host filesystem. This is a common gotcha: if an application needs `fsGroup` semantics and has to work from a `hostPath`, the host directory must be pre-chowned manually. Delete the pod.

```bash
kubectl delete pod hostpath-demo
```

## Cleanup

Delete the tutorial namespace to remove every resource created in this walkthrough.

```bash
kubectl delete namespace tutorial-security-contexts
kubectl config set-context --current --namespace=default
```

## Reference Commands

| Task | Command |
|---|---|
| Inspect effective identity | `kubectl exec <pod> -- id` |
| Show ownership and mode of a file | `kubectl exec <pod> -- ls -la <path>` |
| Show ownership of a directory (including setgid bit) | `kubectl exec <pod> -- ls -ld <path>` |
| Test write access | `kubectl exec <pod> -- sh -c 'touch <path>/probe && rm <path>/probe'` |
| Show the pod-level and container-level securityContext side by side | `kubectl get pod <pod> -o jsonpath='{.spec.securityContext}{"\n"}{range .spec.containers[*]}{.name}: {.securityContext}{"\n"}{end}'` |
| Read the runAsNonRoot error message | `kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[0].state.waiting.message}'` |

## Key Takeaways

`runAsUser` sets the UID; `runAsGroup` sets the primary GID. Both belong in `spec.securityContext` for a pod-wide default or in `spec.containers[*].securityContext` for per-container overrides. `runAsNonRoot` is a validator, not a setter: it prevents a container from starting as root but does not set a UID itself. `supplementalGroups` adds GIDs to the process for permission checks on files owned by those groups. `fsGroup` does the single most consequential thing in this chapter: it recursively owns the mounted volume to a group, adds that group to the container's supplementary groups, and sets the setgid bit on directories so that files created later inherit the group. `fsGroup` only applies to volume types that Kubernetes can chown (not `hostPath`). Every diagnostic starts with `kubectl exec <pod> -- id`; every file-ownership question ends with `ls -la` on the path in question.
