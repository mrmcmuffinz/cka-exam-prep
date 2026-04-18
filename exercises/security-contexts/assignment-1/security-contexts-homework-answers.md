# Security Contexts Homework Answers: User and Group Security

This file contains complete solutions for all 15 exercises on user and group security contexts.

---

## Exercise 1.1 Solution

**Task:** Run a container as user ID 1001.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-runner
  namespace: ex-1-1
spec:
  securityContext:
    runAsUser: 1001
  containers:
  - name: nginx
    image: nginx:1.25
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: app-runner
  namespace: ex-1-1
spec:
  securityContext:
    runAsUser: 1001
  containers:
  - name: nginx
    image: nginx:1.25
EOF
```

**Explanation:** The runAsUser field at the pod level sets the UID for all containers in the pod. The nginx container will run as UID 1001 instead of its default user.

---

## Exercise 1.2 Solution

**Task:** Run a container as user 1002 and group 3002.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: group-runner
  namespace: ex-1-2
spec:
  securityContext:
    runAsUser: 1002
    runAsGroup: 3002
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: group-runner
  namespace: ex-1-2
spec:
  securityContext:
    runAsUser: 1002
    runAsGroup: 3002
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
```

**Explanation:** Setting both runAsUser and runAsGroup ensures the container process runs with the specified UID and primary GID. Without runAsGroup, the primary GID would default to 0 (root).

---

## Exercise 1.3 Solution

**Task:** Use runAsNonRoot with a specific user.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: ex-1-3
spec:
  securityContext:
    runAsUser: 1003
    runAsNonRoot: true
  containers:
  - name: app
    image: alpine:3.20
    command: ["sleep", "3600"]
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
  namespace: ex-1-3
spec:
  securityContext:
    runAsUser: 1003
    runAsNonRoot: true
  containers:
  - name: app
    image: alpine:3.20
    command: ["sleep", "3600"]
EOF
```

**Explanation:** runAsNonRoot is a validation that rejects containers attempting to run as UID 0. Combined with runAsUser: 1003, this ensures the container runs as a non-root user and validates that requirement.

---

## Exercise 2.1 Solution

**Task:** Use fsGroup for volume ownership.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: volume-writer
  namespace: ex-2-1
spec:
  securityContext:
    runAsUser: 1001
    runAsGroup: 2001
    fsGroup: 3001
  containers:
  - name: writer
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: volume-writer
  namespace: ex-2-1
spec:
  securityContext:
    runAsUser: 1001
    runAsGroup: 2001
    fsGroup: 3001
  containers:
  - name: writer
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

**Explanation:** fsGroup sets the group ownership of mounted volumes to GID 3001. The container process belongs to group 3001 as a supplemental group, enabling write access to the volume even though the primary GID is 2001.

---

## Exercise 2.2 Solution

**Task:** Verify fsGroup affects file ownership.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ownership-test
  namespace: ex-2-2
spec:
  securityContext:
    runAsUser: 1002
    fsGroup: 4002
  containers:
  - name: test
    image: busybox:1.36
    command: ["sh", "-c", "echo hello > /shared/greeting.txt && sleep 3600"]
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
  name: ownership-test
  namespace: ex-2-2
spec:
  securityContext:
    runAsUser: 1002
    fsGroup: 4002
  containers:
  - name: test
    image: busybox:1.36
    command: ["sh", "-c", "echo hello > /shared/greeting.txt && sleep 3600"]
    volumeMounts:
    - name: shared
      mountPath: /shared
  volumes:
  - name: shared
    emptyDir: {}
EOF
```

**Explanation:** Files created in the volume are owned by the running user (1002) and the fsGroup (4002). This demonstrates how fsGroup propagates to newly created files.

---

## Exercise 2.3 Solution

**Task:** Configure supplementalGroups.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-group
  namespace: ex-2-3
spec:
  securityContext:
    runAsUser: 1003
    runAsGroup: 3003
    supplementalGroups: [5001, 5002, 5003]
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: multi-group
  namespace: ex-2-3
spec:
  securityContext:
    runAsUser: 1003
    runAsGroup: 3003
    supplementalGroups: [5001, 5002, 5003]
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
```

**Explanation:** supplementalGroups adds additional group memberships beyond the primary group. The process will have access to files owned by groups 3003, 5001, 5002, and 5003.

---

## Exercise 3.1 Solution

**Problem:** The pod cannot write to the /data directory because there is no fsGroup configured for volume ownership.

**Fix:** Add fsGroup to the security context so the volume is writable by the non-root user.

```bash
kubectl delete pod -n ex-3-1 data-processor

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: data-processor
  namespace: ex-3-1
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
  containers:
  - name: processor
    image: busybox:1.36
    command: ["sh", "-c", "echo 'processing data' > /data/output.txt && sleep 3600"]
    volumeMounts:
    - name: data-volume
      mountPath: /data
  volumes:
  - name: data-volume
    emptyDir: {}
EOF
```

**Explanation:** Without fsGroup, the emptyDir volume is owned by root:root, making it unwritable by user 1000. Adding fsGroup: 1000 changes the volume ownership to root:1000 and adds group 1000 to the process's supplemental groups, enabling write access.

---

## Exercise 3.2 Solution

**Problem:** The pod has runAsNonRoot: true but no runAsUser specified. The busybox image defaults to running as root, which violates the runAsNonRoot constraint.

**Fix:** Add a runAsUser that specifies a non-root UID.

```bash
kubectl delete pod -n ex-3-2 secure-worker

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secure-worker
  namespace: ex-3-2
spec:
  securityContext:
    runAsUser: 1000
    runAsNonRoot: true
  containers:
  - name: worker
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
```

**Explanation:** runAsNonRoot is a validation, not a configuration. It checks that the container will not run as root, but it does not change the user. You must also specify runAsUser with a non-zero UID.

---

## Exercise 3.3 Solution

**Problem:** Two containers with different UIDs share a volume, but without fsGroup, the producer's files may not be readable/writable by the consumer.

**Fix:** Add fsGroup at the pod level so both containers can access the shared volume.

```bash
kubectl delete pod -n ex-3-3 data-pipeline

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: data-pipeline
  namespace: ex-3-3
spec:
  securityContext:
    fsGroup: 3000
  containers:
  - name: producer
    image: busybox:1.36
    command: ["sh", "-c", "echo 'data payload' > /shared/data.txt && sleep 3600"]
    securityContext:
      runAsUser: 1001
    volumeMounts:
    - name: shared-data
      mountPath: /shared
  - name: consumer
    image: busybox:1.36
    command: ["sh", "-c", "sleep 10 && cat /shared/data.txt && sleep 3600"]
    securityContext:
      runAsUser: 2001
    volumeMounts:
    - name: shared-data
      mountPath: /shared
  volumes:
  - name: shared-data
    emptyDir: {}
EOF
```

**Explanation:** With fsGroup: 3000, both containers belong to group 3000 and can access files in the shared volume. Files created by either container are group-owned by 3000.

---

## Exercise 4.1 Solution

**Task:** Override pod-level settings at container level.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mixed-users
  namespace: ex-4-1
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 2000
  containers:
  - name: default-user
    image: busybox:1.36
    command: ["sleep", "3600"]
  - name: admin-user
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 3000
      runAsGroup: 4000
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: mixed-users
  namespace: ex-4-1
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 2000
  containers:
  - name: default-user
    image: busybox:1.36
    command: ["sleep", "3600"]
  - name: admin-user
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 3000
      runAsGroup: 4000
EOF
```

**Explanation:** Container-level securityContext overrides pod-level settings for that specific container. The default-user container inherits the pod settings, while admin-user uses its own overrides.

---

## Exercise 4.2 Solution

**Task:** Different users sharing a volume with fsGroup.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: collaborative-app
  namespace: ex-4-2
spec:
  securityContext:
    fsGroup: 8000
  containers:
  - name: writer-a
    image: busybox:1.36
    command: ["sh", "-c", "echo 'message from A' > /shared/from-a.txt && sleep 3600"]
    securityContext:
      runAsUser: 1001
    volumeMounts:
    - name: shared
      mountPath: /shared
  - name: writer-b
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5 && echo 'message from B' > /shared/from-b.txt && sleep 3600"]
    securityContext:
      runAsUser: 2002
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
  name: collaborative-app
  namespace: ex-4-2
spec:
  securityContext:
    fsGroup: 8000
  containers:
  - name: writer-a
    image: busybox:1.36
    command: ["sh", "-c", "echo 'message from A' > /shared/from-a.txt && sleep 3600"]
    securityContext:
      runAsUser: 1001
    volumeMounts:
    - name: shared
      mountPath: /shared
  - name: writer-b
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5 && echo 'message from B' > /shared/from-b.txt && sleep 3600"]
    securityContext:
      runAsUser: 2002
    volumeMounts:
    - name: shared
      mountPath: /shared
  volumes:
  - name: shared
    emptyDir: {}
EOF
```

**Explanation:** Even though the containers run as different users, fsGroup: 8000 ensures all containers can read and write to the shared volume because they all belong to group 8000.

---

## Exercise 4.3 Solution

**Task:** Combine fsGroup with supplementalGroups.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: group-matrix
  namespace: ex-4-3
spec:
  securityContext:
    fsGroup: 9000
    supplementalGroups: [9001, 9002]
  containers:
  - name: standard
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 1000
      runAsGroup: 2000
  - name: elevated
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 3000
      runAsGroup: 4000
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: group-matrix
  namespace: ex-4-3
spec:
  securityContext:
    fsGroup: 9000
    supplementalGroups: [9001, 9002]
  containers:
  - name: standard
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 1000
      runAsGroup: 2000
  - name: elevated
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 3000
      runAsGroup: 4000
EOF
```

**Explanation:** Both containers inherit the pod-level fsGroup and supplementalGroups. The standard container will have groups: 2000,9000,9001,9002 and the elevated container will have groups: 4000,9000,9001,9002.

---

## Exercise 5.1 Solution

**Task:** Configure a pod for an application with specific UID/GID requirements.

```bash
# Create the ConfigMap first
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: ex-5-1
data:
  settings.conf: "debug=true"
EOF

# Create the pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: legacy-app
  namespace: ex-5-1
spec:
  securityContext:
    runAsUser: 1500
    runAsGroup: 1500
    fsGroup: 1500
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "cat /etc/app/config/settings.conf && echo 'log entry' > /var/log/app/app.log && echo 'data written' > /data/store.txt && sleep 3600"]
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
    - name: config
      mountPath: /etc/app/config
    - name: data
      mountPath: /data
  volumes:
  - name: logs
    emptyDir: {}
  - name: config
    configMap:
      name: app-config
  - name: data
    emptyDir: {}
EOF
```

**Explanation:** This solution configures the pod to run as UID/GID 1500 with fsGroup 1500 for volume write access. The ConfigMap provides read-only configuration, while emptyDir volumes provide writable storage for logs and data.

---

## Exercise 5.2 Solution

**Problem:** Multiple issues:
1. runAsNonRoot: true is set at pod level but the initializer container has no runAsUser
2. Without fsGroup, the two containers (running as different users) cannot share the workdir

**Fix:**

```bash
kubectl delete pod -n ex-5-2 data-pipeline

kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: pipeline-config
  namespace: ex-5-2
data:
  input.txt: "initial data"
---
apiVersion: v1
kind: Pod
metadata:
  name: data-pipeline
  namespace: ex-5-2
spec:
  securityContext:
    runAsNonRoot: true
    fsGroup: 5000
  containers:
  - name: initializer
    image: busybox:1.36
    command: ["sh", "-c", "cp /config/input.txt /work/input.txt && sleep 3600"]
    securityContext:
      runAsUser: 1000
    volumeMounts:
    - name: config
      mountPath: /config
    - name: workdir
      mountPath: /work
  - name: processor
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5 && cat /work/input.txt > /work/output.txt && sleep 3600"]
    securityContext:
      runAsUser: 2000
    volumeMounts:
    - name: workdir
      mountPath: /work
  volumes:
  - name: config
    configMap:
      name: pipeline-config
  - name: workdir
    emptyDir: {}
EOF
```

**Explanation:** The initializer container needed a runAsUser to satisfy runAsNonRoot. Adding fsGroup: 5000 ensures both containers (running as different users) can access the shared workdir volume.

---

## Exercise 5.3 Solution

**Task:** Design a secure microservice pod with multiple containers.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-microservice
  namespace: ex-5-3
spec:
  securityContext:
    runAsNonRoot: true
    fsGroup: 10000
  containers:
  - name: api
    image: nginx:1.25
    command: ["sh", "-c", "echo 'api started' > /var/log/shared/api.log && nginx -g 'daemon off;'"]
    securityContext:
      runAsUser: 101
      runAsGroup: 101
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/shared
  - name: sidecar
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5 && cat /var/log/shared/api.log && sleep 3600"]
    securityContext:
      runAsUser: 1000
      runAsGroup: 1000
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/shared
  - name: metrics
    image: busybox:1.36
    command: ["sh", "-c", "echo 'metrics: 100' > /var/log/shared/metrics.log && sleep 3600"]
    securityContext:
      runAsUser: 2000
      runAsGroup: 2000
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/shared
  volumes:
  - name: shared-logs
    emptyDir: {}
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secure-microservice
  namespace: ex-5-3
spec:
  securityContext:
    runAsNonRoot: true
    fsGroup: 10000
  containers:
  - name: api
    image: nginx:1.25
    command: ["sh", "-c", "echo 'api started' > /var/log/shared/api.log && nginx -g 'daemon off;'"]
    securityContext:
      runAsUser: 101
      runAsGroup: 101
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/shared
  - name: sidecar
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5 && cat /var/log/shared/api.log && sleep 3600"]
    securityContext:
      runAsUser: 1000
      runAsGroup: 1000
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/shared
  - name: metrics
    image: busybox:1.36
    command: ["sh", "-c", "echo 'metrics: 100' > /var/log/shared/metrics.log && sleep 3600"]
    securityContext:
      runAsUser: 2000
      runAsGroup: 2000
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/shared
  volumes:
  - name: shared-logs
    emptyDir: {}
EOF
```

**Explanation:** This solution implements a secure microservice pattern:
- runAsNonRoot at pod level ensures all containers are non-root
- Each container has its own runAsUser for isolation
- fsGroup: 10000 enables all containers to share the log volume
- The nginx image's user 101 is the standard nginx non-root user

---

## Common Mistakes

### Confusing runAsUser (UID) with runAsGroup (GID)

runAsUser sets the user ID, runAsGroup sets the group ID. They are independent settings. Setting only runAsUser leaves the group as root (0).

### Forgetting fsGroup for volume write access

When running as non-root, containers often cannot write to mounted volumes without fsGroup. The volume is owned by root by default, and a non-root user has no write permission unless they belong to the owning group.

### runAsNonRoot with image that defaults to root

runAsNonRoot is a validation, not a configuration. If the container image defaults to running as root (like busybox or nginx), you must also specify runAsUser with a non-zero UID.

### fsGroup not taking effect on read-only volumes

fsGroup changes group ownership of volumes, but this only matters for writable volumes. ConfigMap and Secret volumes are mounted read-only by default and their permissions are controlled by defaultMode, not fsGroup.

### Container-level settings not overriding as expected

Container-level securityContext only overrides pod-level settings for fields that are specified. If you omit a field at container level, the pod-level value is used. This can lead to unexpected combinations.

### Expecting supplementalGroups to include fsGroup

fsGroup is automatically added to the supplemental groups. You do not need to list it in supplementalGroups as well.

---

## Verification Commands Cheat Sheet

| Task | Command |
|------|---------|
| Check container user/group identity | `kubectl exec <pod> -- id` |
| Check file ownership | `kubectl exec <pod> -- ls -la <path>` |
| Test write permission | `kubectl exec <pod> -- touch <path>/test` |
| View pod security context | `kubectl get pod <pod> -o yaml | grep -A 15 securityContext` |
| Check pod events | `kubectl describe pod <pod>` |
| View container logs | `kubectl logs <pod> -c <container>` |
| Check running processes | `kubectl exec <pod> -- ps aux` |
| Check process capabilities | `kubectl exec <pod> -- cat /proc/1/status | grep -i cap` |
