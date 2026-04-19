# User and Group Security Contexts Homework Answers

Complete solutions for all 15 exercises. Every debugging answer at Level 3 and Level 5 follows the three-stage structure (diagnosis, what the bug is and why, fix). The `Common Mistakes` section at the end documents the failure modes that surface repeatedly on the exam.

---

## Exercise 1.1 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: uid-only
  namespace: ex-1-1
spec:
  securityContext:
    runAsUser: 1001
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
```

Apply with `kubectl apply -f <file>.yaml` or pipe the manifest into `kubectl apply -f -`. The only identity field set is `runAsUser: 1001`. Because `runAsGroup` is left unset, the primary GID is the image default (0 for `busybox:1.36`). Confirmation via `id -u` returns 1001 and `id -g` returns 0.

---

## Exercise 1.2 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: uid-and-gid
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

`runAsGroup: 3002` sets the primary GID for the process. Files the container creates are owned by 3002, which is what the `stat -c "%u:%g"` verification prints.

---

## Exercise 1.3 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hardened-identity
  namespace: ex-1-3
spec:
  securityContext:
    runAsUser: 101
    runAsNonRoot: true
  containers:
  - name: web
    image: nginx:1.25
    ports:
    - containerPort: 80
```

The `nginx:1.25` image defines its `nginx` user at UID 101. Because `runAsUser: 101` is non-root and `runAsNonRoot: true` checks the effective UID against 0, admission allows the container to start. If you set `runAsNonRoot: true` without also setting `runAsUser`, the image default (root for most `nginx` base layers) trips the `CreateContainerConfigError` seen in Exercise 3.2. `nginx:1.25` will still listen on port 80 because the stock image is built to gracefully fall back to non-privileged start when not running as root, but the CKA-relevant insight is that `runAsNonRoot` is purely a validator.

---

## Exercise 2.1 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: writable-scratch
  namespace: ex-2-1
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: scratch
      mountPath: /scratch
  volumes:
  - name: scratch
    emptyDir: {}
```

`fsGroup: 2000` chowns `/scratch` to `root:2000`, sets the setgid bit (the `s` in `drwxrwsrwx`), and adds group 2000 to the container's supplementary groups. A file created later is owned by `1000:2000` (UID from `runAsUser`, GID inherited from the setgid directory).

---

## Exercise 2.2 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: onrootmismatch
  namespace: ex-2-2
spec:
  securityContext:
    runAsUser: 1000
    fsGroup: 2500
    fsGroupChangePolicy: OnRootMismatch
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    emptyDir: {}
```

On the first mount, the volume root does not have group 2500, so `OnRootMismatch` triggers the recursive chown just like `Always` would. The verification confirms both `/data` and `/data/record` report GID 2500. The distinction between `OnRootMismatch` and `Always` shows up on subsequent mounts of the same volume (PVC case), where `OnRootMismatch` skips the chown if the root already matches. For an `emptyDir`, which is fresh per pod start, the behavior is the same as `Always`.

---

## Exercise 2.3 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: many-groups
  namespace: ex-2-3
spec:
  securityContext:
    runAsUser: 1010
    runAsGroup: 3010
    supplementalGroups: [4000, 5000, 6000]
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
```

`id -G` prints the group list separated by spaces, showing the primary GID first (3010) and every supplementary GID after. Order of supplementary groups is deterministic based on the order in the spec.

---

## Exercise 3.1 Solution

**Diagnosis.** The symptom to look for is restarts or a non-zero exit code from the app container.

```bash
kubectl get pod -n ex-3-1 broken
kubectl logs -n ex-3-1 broken --previous
kubectl exec -n ex-3-1 broken -- sh -c 'ls -ld /work' 2>/dev/null || true
```

The previous-restart logs show `sh: can't create /work/log: Permission denied`. Inspecting the mount shows `/work` is owned by `root:root` with mode `0755`, which the non-root container (UID 1000 primary GID 3000) cannot write to.

**What the bug is and why.** The pod spec sets `runAsUser: 1000` and `runAsGroup: 3000` but omits `fsGroup`. Without `fsGroup`, an `emptyDir` mounts with owner `root:root` and is only writable by root. A non-root container has no way to write to it. The command writes to `/work/log`, so the loop fails on the first iteration; Kubernetes restarts the pod; the loop fails again. The restart count climbs steadily.

**Fix.** Add `fsGroup` at pod level so the mount is chowned to a group the container belongs to and so the setgid bit is set.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: broken
  namespace: ex-3-1
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 3000
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "while true; do date >> /work/log; sleep 2; done"]
    volumeMounts:
    - name: work
      mountPath: /work
  volumes:
  - name: work
    emptyDir: {}
```

Apply the fix with `kubectl delete pod -n ex-3-1 broken && kubectl apply -n ex-3-1 -f fixed.yaml`. The restart count stays at zero because the loop writes cleanly.

---

## Exercise 3.2 Solution

**Diagnosis.**

```bash
kubectl get pod -n ex-3-2 blocked
kubectl get pod -n ex-3-2 blocked -o jsonpath='{.status.containerStatuses[0].state.waiting.message}'
```

The waiting message is `container has runAsNonRoot and image will run as root`. The pod spec has `runAsNonRoot: true` but no `runAsUser`, and the `busybox:1.36` image defaults to root. The kubelet fails the admission gate before the container process starts.

**What the bug is and why.** `runAsNonRoot` is a validator, not a setter. It checks the effective UID (either the value of `runAsUser` or the image's `USER` directive) against zero. Because `busybox:1.36` has no `USER`, the image default is zero, which is root, which fails the check. Removing `runAsNonRoot: true` would "fix" the symptom but violates the constraint in the task.

**Fix.** Add a non-zero `runAsUser`.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: blocked
  namespace: ex-3-2
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
```

Recreate the pod: `kubectl delete pod -n ex-3-2 blocked && kubectl apply -n ex-3-2 -f fixed.yaml`.

---

## Exercise 3.3 Solution

**Diagnosis.**

```bash
kubectl logs -n ex-3-3 mismatch -c reader
kubectl exec -n ex-3-3 mismatch -c writer -- sh -c 'ls -la /shared/file' 2>/dev/null || true
kubectl exec -n ex-3-3 mismatch -c writer -- id
kubectl exec -n ex-3-3 mismatch -c reader -- id
```

The reader's `cat /shared/file` fails with `Permission denied`. The file on disk is owned by `1000:3000` with mode `0640` (from the default umask of a non-root shell). The reader runs as UID 2000, GID 4000, which matches neither the user nor the group on the file.

**What the bug is and why.** The pod has no `fsGroup` and no common group across the two containers. `emptyDir` mounts with ownership `root:root`; the writer chooses its own UID/GID when creating files, so `/shared/file` ends up `1000:3000`. The reader (UID 2000, GID 4000) has no membership in group 3000 and is not the owner, so the file-mode other bits apply. For a default-shell-created file, other bits are usually read-execute, which means the cat succeeds there, but the bigger problem emerges when the reader tries to write: `touch: /shared/reply: Permission denied` because other-mode is not writable.

**Fix.** Add `fsGroup` at pod level. Now `/shared` is chowned to the shared group, the setgid bit ensures every file created inside inherits that group, and both containers belong to the group via the implicit supplementary-group addition.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mismatch
  namespace: ex-3-3
spec:
  securityContext:
    fsGroup: 9999
  containers:
  - name: writer
    image: busybox:1.36
    command: ["sh", "-c", "echo content > /shared/file && sleep 3600"]
    securityContext:
      runAsUser: 1000
      runAsGroup: 3000
    volumeMounts:
    - name: shared
      mountPath: /shared
  - name: reader
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3 && cat /shared/file && sleep 3600"]
    securityContext:
      runAsUser: 2000
      runAsGroup: 4000
    volumeMounts:
    - name: shared
      mountPath: /shared
  volumes:
  - name: shared
    emptyDir: {}
```

Recreate the pod. The reader's log now prints `content` and the reader can also write.

---

## Exercise 4.1 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mixed-identity
  namespace: ex-4-1
spec:
  securityContext:
    runAsUser: 1500
    runAsGroup: 2500
  containers:
  - name: one
    image: busybox:1.36
    command: ["sleep", "3600"]
  - name: two
    image: busybox:1.36
    command: ["sleep", "3600"]
    securityContext:
      runAsUser: 7000
      runAsGroup: 8000
```

Container `one` inherits pod-level settings. Container `two` overrides both fields. Precedence rule: container-level wins for the fields it sets; other fields fall through to pod-level.

---

## Exercise 4.2 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: three-writers
  namespace: ex-4-2
spec:
  securityContext:
    fsGroup: 9000
  containers:
  - name: a
    image: busybox:1.36
    command: ["sh", "-c", "echo hello-a > /shared/a.txt && sleep 3600"]
    securityContext:
      runAsUser: 1000
    volumeMounts:
    - name: shared
      mountPath: /shared
  - name: b
    image: busybox:1.36
    command: ["sh", "-c", "echo hello-b > /shared/b.txt && sleep 3600"]
    securityContext:
      runAsUser: 2000
    volumeMounts:
    - name: shared
      mountPath: /shared
  - name: c
    image: busybox:1.36
    command: ["sh", "-c", "echo hello-c > /shared/c.txt && sleep 3600"]
    securityContext:
      runAsUser: 3000
    volumeMounts:
    - name: shared
      mountPath: /shared
  volumes:
  - name: shared
    emptyDir: {}
```

All three containers belong to group 9000 via `fsGroup`. The setgid bit on `/shared` guarantees every file created inherits group 9000, so all containers can read each other's files.

---

## Exercise 4.3 Solution

Create the ConfigMap first, then the pod.

```bash
kubectl create namespace ex-4-3 2>/dev/null || true

kubectl apply -n ex-4-3 -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-conf
data:
  default.conf: |
    server {
      listen 8080;
      location / {
        return 200 "hardened-web\n";
      }
    }
EOF

kubectl apply -n ex-4-3 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: hardened-web
spec:
  securityContext:
    runAsUser: 101
    runAsGroup: 101
    runAsNonRoot: true
    fsGroup: 101
  containers:
  - name: web
    image: nginx:1.25
    ports:
    - containerPort: 8080
    volumeMounts:
    - name: conf
      mountPath: /etc/nginx/conf.d
  volumes:
  - name: conf
    configMap:
      name: nginx-conf
      items:
      - key: default.conf
        path: default.conf
EOF
```

The nginx image's `nginx` user is UID 101. Running as that UID is sufficient for nginx to bind to unprivileged port 8080 and read its config from the ConfigMap. Port 80 would require `NET_BIND_SERVICE` capability, which is outside this assignment's scope and is covered in assignment-2. `fsGroup: 101` sets the group on the mounted ConfigMap so nginx (group 101) can always read the config file.

---

## Exercise 5.1 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: appserver
  namespace: ex-5-1
spec:
  securityContext:
    runAsUser: 1042
    runAsGroup: 2042
    runAsNonRoot: true
    fsGroup: 3042
    supplementalGroups: [3042]
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    volumeMounts:
    - name: shared
      mountPath: /shared
  volumes:
  - name: shared
    emptyDir: {}
```

Mapping requirements to fields. "Effective UID 1042" is `runAsUser: 1042`. "Primary GID 2042" is `runAsGroup: 2042`. "Must belong to group 3042" could be satisfied by either `supplementalGroups` or by `fsGroup`, and since the volume also needs the group on files, `fsGroup: 3042` is the right fit (it also adds 3042 to the supplementary groups list automatically). The `supplementalGroups: [3042]` line is redundant in practice but documents intent. "Fail closed if the image switches to UID 0" is `runAsNonRoot: true`. "Must not accidentally create a file outside the shared group" is achieved by the setgid bit `fsGroup` places on `/shared`; every new file inherits group 3042 regardless of the process's primary GID.

---

## Exercise 5.2 Solution

**Diagnosis.**

```bash
kubectl get pod -n ex-5-2 app-plus-logs
kubectl get pod -n ex-5-2 app-plus-logs -o jsonpath='{.status.containerStatuses[*].state}'
kubectl logs -n ex-5-2 app-plus-logs -c app --previous
```

The pod is stuck and the container statuses show either `CreateContainerConfigError` or Pending. Reading the raw spec also reveals the pod-level `runAsUser: 0` combined with `runAsNonRoot: true`: a contradiction at pod level. Once that is resolved, the second symptom is that the app cannot write to `/var/log/app.log` (permission denied) because there is no `fsGroup` and neither container owns the mount.

**What the bug is and why.** Two compounding problems. First, `spec.securityContext.runAsUser: 0` plus `spec.securityContext.runAsNonRoot: true` at pod level contradict: the pod-level `runAsUser: 0` is a default for any container that does not override, and the validator rejects it. Both the `app` and `sidecar` containers override `runAsUser` at container level, so the validator is comparing against the container-level value, but some Kubernetes versions evaluate the pod-level value too. Either way, `runAsUser: 0` at pod level is a time bomb: if someone ever removes the container-level override, the pod will fail. Second, the `emptyDir` has no `fsGroup`, so neither non-root container can write to `/var/log`.

**Fix.** Remove the pod-level `runAsUser: 0`, keep `runAsNonRoot: true`, and add `fsGroup` so both containers can read and write `/var/log`.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-plus-logs
  namespace: ex-5-2
spec:
  securityContext:
    runAsNonRoot: true
    fsGroup: 8000
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "while true; do date >> /var/log/app.log; sleep 2; done"]
    securityContext:
      runAsUser: 1500
    volumeMounts:
    - name: logs
      mountPath: /var/log
  - name: sidecar
    image: busybox:1.36
    command: ["sh", "-c", "sleep 4 && tail -f /var/log/app.log"]
    securityContext:
      runAsUser: 2500
    volumeMounts:
    - name: logs
      mountPath: /var/log
  volumes:
  - name: logs
    emptyDir: {}
```

Recreate the pod. `kubectl logs -c sidecar --tail=2` now prints the two most recent date lines.

---

## Exercise 5.3 Solution

Create the ConfigMap for the frontend, then the pod.

```bash
kubectl apply -n ex-5-3 -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-conf
data:
  default.conf: |
    server {
      listen 8080;
      location / {
        return 200 "frontend\n";
      }
    }
EOF

kubectl apply -n ex-5-3 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: three-tier
spec:
  securityContext:
    runAsNonRoot: true
    fsGroup: 7000
  containers:
  - name: frontend
    image: nginx:1.25
    securityContext:
      runAsUser: 101
      runAsGroup: 101
    command:
    - sh
    - -c
    - |
      nginx -g 'daemon off;' &
      while true; do
        date > /metrics/frontend.ok
        sleep 5
      done
    volumeMounts:
    - name: conf
      mountPath: /etc/nginx/conf.d
    - name: metrics
      mountPath: /metrics
    ports:
    - containerPort: 8080
  - name: backend
    image: busybox:1.36
    securityContext:
      runAsUser: 1020
    command:
    - sh
    - -c
    - |
      while true; do
        date > /metrics/backend.ok
        sleep 5
      done
    volumeMounts:
    - name: metrics
      mountPath: /metrics
  - name: exporter
    image: busybox:1.36
    securityContext:
      runAsUser: 1030
    command:
    - sh
    - -c
    - |
      while true; do
        sleep 6
        fe=$(cat /metrics/frontend.ok 2>/dev/null || echo missing)
        be=$(cat /metrics/backend.ok 2>/dev/null || echo missing)
        echo "frontend.ok=$fe backend.ok=$be"
      done
    volumeMounts:
    - name: metrics
      mountPath: /metrics
  volumes:
  - name: conf
    configMap:
      name: frontend-conf
  - name: metrics
    emptyDir: {}
EOF
```

Every container has its own `runAsUser` at container level so the identity is explicit per container. `fsGroup: 7000` makes the `/metrics` `emptyDir` writable by all three through the shared group. `runAsNonRoot: true` at pod level is satisfied because every container's `runAsUser` is non-zero. The frontend container runs nginx in the background and writes a heartbeat file in the same shell loop, so `runAsUser: 101` applies to both the nginx master and the heartbeat loop.

---

## Common Mistakes

**1. Setting `runAsNonRoot: true` without `runAsUser`.** This is the top Level-3-class failure. `runAsNonRoot` checks the effective UID, which without `runAsUser` falls through to the image's `USER` directive, which for most base images is root. The error message is the exact string `container has runAsNonRoot and image will run as root`. The fix is either to set a non-zero `runAsUser` or to switch to an image whose `USER` is not root.

**2. Forgetting `fsGroup` when the container is non-root and uses an `emptyDir`.** An `emptyDir` mounts with owner `root:root` and mode `0755`. A non-root container cannot write into it. The symptom is `Permission denied` on the first write, usually surfacing as a `CrashLoopBackOff` or a silent log-write failure. Adding `fsGroup` chowns the mount to that group and sets the setgid bit.

**3. Confusing `supplementalGroups` with `fsGroup`.** Both add the GID to the container's supplementary-groups list, but only `fsGroup` chowns volumes and sets the setgid bit. If you use `supplementalGroups` alone expecting volume permissions to work, the mount root stays `root:root` and the non-root container cannot write, even though `id` shows the expected group membership.

**4. Pod-level `runAsUser: 0` with container-level overrides.** This configuration "works" as long as every container overrides `runAsUser`, but if one container ever removes its override, the pod-level zero takes effect and the validator rejects the pod. Always keep pod-level `runAsUser` non-zero or omit it entirely.

**5. `fsGroup` does not apply to `hostPath`.** Kubernetes explicitly does not chown `hostPath` volumes because they live outside Kubernetes's control. The symptom: the container still gets the GID added to its supplementary groups (from `fsGroup`'s implicit supplementary-group addition), but the mount's ownership is whatever the host directory already has. For `hostPath` to work with a non-root container, the host directory must be pre-chowned.

**6. `runAsGroup` without `runAsUser`.** Setting only the primary GID while the UID falls through to the image default is almost never what anyone wants. The container runs as root with a custom primary group, which looks wrong in audits but is not well-detected by `runAsNonRoot`.

**7. Mistaking `runAsUser: 0` with `uid=0(root)` in `id` output as acceptable because "the image handles it".** `runAsUser: 0` is root. If the goal is "non-root," the image default will almost never save you. Always be explicit with `runAsUser` when security matters.

**8. Not accounting for the setgid bit when validating `fsGroup`.** Learners sometimes configure `fsGroup` correctly and then write a file directly with `cat > /path/file`. The file is group-owned by the setgid-bit-selected group, not by the process's primary GID. If you test group ownership using a stat check and expect `runAsGroup`, you will see `fsGroup` instead and mistake the working configuration for broken.

---

## Verification Commands Cheat Sheet

| Check | Command |
|---|---|
| Effective UID inside the container | `kubectl exec <pod> -c <container> -- id -u` |
| Effective primary GID | `kubectl exec <pod> -c <container> -- id -g` |
| Full group list (primary + supplementary) | `kubectl exec <pod> -c <container> -- id -G` |
| Directory ownership and mode (including setgid) | `kubectl exec <pod> -c <container> -- ls -ld <path>` |
| File ownership and mode | `kubectl exec <pod> -c <container> -- stat -c "%u:%g %A" <path>` |
| runAsNonRoot error message (if stuck) | `kubectl get pod <pod> -o jsonpath='{.status.containerStatuses[0].state.waiting.message}'` |
| Pod-level and container-level security context side by side | `kubectl get pod <pod> -o jsonpath='{.spec.securityContext}{"\n---\n"}{range .spec.containers[*]}{.name}: {.securityContext}{"\n"}{end}'` |
| Restart counts for every container | `kubectl get pod <pod> -o jsonpath='{range .status.containerStatuses[*]}{.name}: {.restartCount}{"\n"}{end}'` |
