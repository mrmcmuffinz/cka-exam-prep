# Security Contexts Tutorial: User and Group Security

## Introduction

Kubernetes security contexts let you control the security settings for pods and containers. This tutorial focuses on user and group identity controls, which determine the Linux user and group that your containers run as. Understanding these settings is essential for the CKA exam and for running secure workloads in production.

By default, containers often run as root (UID 0), which poses security risks if an attacker compromises the container. Security contexts let you specify that containers should run as non-root users, set specific user and group IDs, and control how volumes are owned. These settings form the foundation of container security in Kubernetes.

In this tutorial, you will create pods with specific user and group settings, verify those settings from inside the containers, and understand how fsGroup controls volume ownership.

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

## Understanding User and Group Identity

Every process in Linux runs with a user ID (UID) and a group ID (GID). The UID determines what files the process can access and what system calls it can make. When a container runs as root (UID 0), it has elevated privileges that could be dangerous if exploited.

Kubernetes security contexts let you specify:

- **runAsUser:** The UID the container process runs as
- **runAsGroup:** The primary GID for the container process
- **supplementalGroups:** Additional GIDs the process belongs to
- **fsGroup:** A special group that owns mounted volumes
- **runAsNonRoot:** A validation that rejects containers attempting to run as root

These settings can be specified at the pod level (applying to all containers) or at the container level (overriding pod-level settings).

## Running a Container as a Specific User

Let us start by running a container as a specific user. Create a pod that runs as UID 1000:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: user-demo
  namespace: tutorial-security-contexts
spec:
  securityContext:
    runAsUser: 1000
  containers:
  - name: demo
    image: busybox:1.36
    command: ["sleep", "3600"]
```

Apply this manifest:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: user-demo
  namespace: tutorial-security-contexts
spec:
  securityContext:
    runAsUser: 1000
  containers:
  - name: demo
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
```

Wait for the pod to start:

```bash
kubectl wait --for=condition=Ready pod/user-demo --timeout=60s
```

Now verify the user identity inside the container:

```bash
kubectl exec user-demo -- id
```

The output shows:

```
uid=1000 gid=0(root) groups=0(root)
```

Notice that while the UID is 1000, the primary GID is still 0 (root). This is because we only set runAsUser, not runAsGroup.

## Setting Both User and Group

To control both the user and group identity, set both runAsUser and runAsGroup:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: user-group-demo
  namespace: tutorial-security-contexts
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
  containers:
  - name: demo
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
```

Wait for the pod and verify:

```bash
kubectl wait --for=condition=Ready pod/user-group-demo --timeout=60s
kubectl exec user-group-demo -- id
```

The output now shows:

```
uid=1000 gid=3000 groups=3000
```

The container runs as UID 1000 with primary GID 3000.

## Using runAsNonRoot for Validation

The runAsNonRoot field does not set a user ID. Instead, it validates that the container does not run as root. If the container image defaults to root and you set runAsNonRoot: true without also setting runAsUser, the pod will fail to start.

Create a pod with runAsNonRoot that will succeed:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nonroot-demo
  namespace: tutorial-security-contexts
spec:
  securityContext:
    runAsUser: 1000
    runAsNonRoot: true
  containers:
  - name: demo
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
```

This pod starts successfully because runAsUser is set to a non-root UID.

Now try creating a pod where runAsNonRoot will fail:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nonroot-fail-demo
  namespace: tutorial-security-contexts
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: demo
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
```

Check the pod status:

```bash
kubectl get pod nonroot-fail-demo
```

The pod shows CreateContainerConfigError because the busybox image defaults to running as root, and runAsNonRoot rejects this.

Delete the failed pod:

```bash
kubectl delete pod nonroot-fail-demo
```

## Understanding fsGroup for Volume Ownership

When you mount a volume into a container, the volume files have specific ownership. If your container runs as a non-root user, it may not be able to write to the volume unless you configure ownership appropriately.

The fsGroup field tells Kubernetes to change the group ownership of all files in mounted volumes to the specified GID, and to set the setgid bit on the volume root. This means new files created in the volume will also be owned by that group.

Create a pod with an emptyDir volume and fsGroup:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: fsgroup-demo
  namespace: tutorial-security-contexts
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
```

Wait for the pod and check the identity:

```bash
kubectl wait --for=condition=Ready pod/fsgroup-demo --timeout=60s
kubectl exec fsgroup-demo -- id
```

The output shows:

```
uid=1000 gid=3000 groups=2000,3000
```

Notice that 2000 appears in the groups list even though we did not explicitly add it as a supplemental group. This is because fsGroup is automatically added to the supplemental groups.

Check the ownership of the mounted volume:

```bash
kubectl exec fsgroup-demo -- ls -la /data
```

The output shows that /data is owned by root:2000 (the fsGroup). The container can write to this directory because it belongs to group 2000.

Create a file in the volume:

```bash
kubectl exec fsgroup-demo -- touch /data/testfile
kubectl exec fsgroup-demo -- ls -la /data/testfile
```

The new file is owned by user 1000 and group 2000 (the fsGroup).

## Using supplementalGroups

The supplementalGroups field adds additional group memberships to the container process. This is useful when you need access to files owned by multiple groups.

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: supplemental-demo
  namespace: tutorial-security-contexts
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
```

Wait and verify:

```bash
kubectl wait --for=condition=Ready pod/supplemental-demo --timeout=60s
kubectl exec supplemental-demo -- id
```

The output shows:

```
uid=1000 gid=3000 groups=3000,4000,5000
```

The process now belongs to groups 3000, 4000, and 5000.

## Container-Level Overrides

Security context settings can be specified at two levels: pod level and container level. Container-level settings override pod-level settings for that specific container.

Create a pod with different users for different containers:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: override-demo
  namespace: tutorial-security-contexts
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
  containers:
  - name: default-user
    image: busybox:1.36
    command: ["sleep", "3600"]
  - name: override-user
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 2000
      runAsGroup: 4000
EOF
```

Wait for the pod:

```bash
kubectl wait --for=condition=Ready pod/override-demo --timeout=60s
```

Check the identity in each container:

```bash
kubectl exec override-demo -c default-user -- id
kubectl exec override-demo -c override-user -- id
```

The default-user container runs as uid=1000 gid=3000, inheriting from the pod-level settings. The override-user container runs as uid=2000 gid=4000, using the container-level overrides.

## fsGroup with Multiple Containers

When multiple containers share a volume, fsGroup ensures they can all access it. Create a pod where two containers write to the same volume:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: shared-volume-demo
  namespace: tutorial-security-contexts
spec:
  securityContext:
    fsGroup: 2000
  containers:
  - name: writer-one
    image: busybox:1.36
    command: ["sh", "-c", "echo 'from writer-one' > /data/file1.txt && sleep 3600"]
    securityContext:
      runAsUser: 1000
    volumeMounts:
    - name: shared
      mountPath: /data
  - name: writer-two
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5 && echo 'from writer-two' > /data/file2.txt && sleep 3600"]
    securityContext:
      runAsUser: 2000
    volumeMounts:
    - name: shared
      mountPath: /data
  volumes:
  - name: shared
    emptyDir: {}
EOF
```

Wait for the pod:

```bash
kubectl wait --for=condition=Ready pod/shared-volume-demo --timeout=60s
```

Check that both containers can read both files:

```bash
kubectl exec shared-volume-demo -c writer-one -- cat /data/file2.txt
kubectl exec shared-volume-demo -c writer-two -- cat /data/file1.txt
```

Both containers can access files written by the other because they share the fsGroup.

## Verification Techniques

When troubleshooting security context issues, use these commands inside the container:

**Check user and group identity:**
```bash
kubectl exec <pod-name> -- id
```

**Check file ownership:**
```bash
kubectl exec <pod-name> -- ls -la /path/to/check
```

**Test write access:**
```bash
kubectl exec <pod-name> -- touch /path/to/test
```

**Check process user:**
```bash
kubectl exec <pod-name> -- ps aux
```

## Cleanup

Delete the tutorial namespace and all resources:

```bash
kubectl delete namespace tutorial-security-contexts
```

## Reference Commands

| Task | Command |
|------|---------|
| Check container identity | `kubectl exec <pod> -- id` |
| Check file ownership | `kubectl exec <pod> -- ls -la <path>` |
| Test write access | `kubectl exec <pod> -- touch <path>/testfile` |
| View pod security context | `kubectl get pod <pod> -o yaml | grep -A 20 securityContext` |
| Describe pod for events | `kubectl describe pod <pod>` |

## Key Takeaways

1. **runAsUser** sets the UID for container processes
2. **runAsGroup** sets the primary GID for container processes
3. **fsGroup** sets group ownership on mounted volumes and is added to supplemental groups
4. **supplementalGroups** adds additional group memberships
5. **runAsNonRoot** validates (but does not set) that the container runs as non-root
6. Container-level security contexts override pod-level settings
7. When multiple containers share a volume, use fsGroup to ensure they can all access it
