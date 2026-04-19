# User and Group Security Contexts Homework

Fifteen exercises covering the identity fields of `spec.securityContext`: `runAsUser`, `runAsGroup`, `runAsNonRoot`, `supplementalGroups`, and `fsGroup`. Work through the tutorial first, since every debugging exercise assumes you can diagnose a permission-denied error by running `id` inside the container and checking volume ownership with `ls -ld`.

Every exercise lives in its own namespace named `ex-<level>-<exercise>` (for example, `ex-3-2`). A cleanup block at the bottom removes all of them.

---

## Level 1: Basic Identity Controls

### Exercise 1.1

**Objective:** Run a long-lived container as a specific non-root UID and confirm the effective UID from inside.

**Setup:**

```bash
kubectl create namespace ex-1-1
```

**Task:** In namespace `ex-1-1`, create a pod named `uid-only` running image `busybox:1.36` with command `["sleep", "3600"]`. Configure the pod spec so the container runs as UID 1001. Do not set a group; leave `runAsGroup` unset.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/uid-only -n ex-1-1 --timeout=60s
kubectl exec -n ex-1-1 uid-only -- id -u
# Expected: 1001

kubectl exec -n ex-1-1 uid-only -- id -g
# Expected: 0

kubectl get pod -n ex-1-1 uid-only -o jsonpath='{.spec.securityContext.runAsUser}'
# Expected: 1001
```

---

### Exercise 1.2

**Objective:** Set both the effective UID and the primary GID for a container and verify both from inside.

**Setup:**

```bash
kubectl create namespace ex-1-2
```

**Task:** In namespace `ex-1-2`, create a pod named `uid-and-gid` running image `busybox:1.36` with command `["sleep", "3600"]`. Configure the pod so the container runs as UID 1002 and primary GID 3002.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/uid-and-gid -n ex-1-2 --timeout=60s
kubectl exec -n ex-1-2 uid-and-gid -- id -u
# Expected: 1002

kubectl exec -n ex-1-2 uid-and-gid -- id -g
# Expected: 3002

kubectl exec -n ex-1-2 uid-and-gid -- sh -c 'echo hello > /tmp/probe && stat -c "%u:%g" /tmp/probe'
# Expected: 1002:3002
```

---

### Exercise 1.3

**Objective:** Pair `runAsUser` with `runAsNonRoot: true` so that the pod fails closed if someone later removes the `runAsUser` override.

**Setup:**

```bash
kubectl create namespace ex-1-3
```

**Task:** In namespace `ex-1-3`, create a pod named `hardened-identity` running image `nginx:1.25`. Configure the pod to run as UID 101 (the non-root UID that the `nginx:1.25` image creates for the `nginx` user) and set `runAsNonRoot: true` at the pod level. The pod must reach `Running` and serve HTTP on port 80.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/hardened-identity -n ex-1-3 --timeout=60s

kubectl get pod -n ex-1-3 hardened-identity -o jsonpath='{.status.phase}'
# Expected: Running

kubectl exec -n ex-1-3 hardened-identity -- id -u
# Expected: 101

kubectl get pod -n ex-1-3 hardened-identity -o jsonpath='{.spec.securityContext.runAsNonRoot}'
# Expected: true
```

---

## Level 2: Volumes, `fsGroup`, and Supplementary Groups

### Exercise 2.1

**Objective:** Mount an `emptyDir` into a non-root container and use `fsGroup` so the container can write to it.

**Setup:**

```bash
kubectl create namespace ex-2-1
```

**Task:** In namespace `ex-2-1`, create a pod named `writable-scratch` running image `busybox:1.36` with command `["sleep", "3600"]`. The pod should run as UID 1000, primary GID 3000, and `fsGroup: 2000`. Mount an `emptyDir` at `/scratch`. The container must be able to create a file there.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/writable-scratch -n ex-2-1 --timeout=60s

kubectl exec -n ex-2-1 writable-scratch -- sh -c 'touch /scratch/ping && echo created'
# Expected: created

kubectl exec -n ex-2-1 writable-scratch -- stat -c "%u:%g %A" /scratch
# Expected: 0:2000 drwxrwsrwx
# (or similar; the key points are the group 2000 and the "s" in the group bits)

kubectl exec -n ex-2-1 writable-scratch -- stat -c "%u:%g" /scratch/ping
# Expected: 1000:2000
```

---

### Exercise 2.2

**Objective:** Combine `fsGroupChangePolicy: OnRootMismatch` with `fsGroup` and observe that the mount-root group is still set correctly on first mount.

**Setup:**

```bash
kubectl create namespace ex-2-2
```

**Task:** In namespace `ex-2-2`, create a pod named `onrootmismatch` running image `busybox:1.36` with command `["sleep", "3600"]`, UID 1000, `fsGroup: 2500`, and `fsGroupChangePolicy: OnRootMismatch`. Mount an `emptyDir` at `/data`. Write one file inside `/data` before verifying.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/onrootmismatch -n ex-2-2 --timeout=60s
kubectl exec -n ex-2-2 onrootmismatch -- sh -c 'echo payload > /data/record'

kubectl exec -n ex-2-2 onrootmismatch -- stat -c "%g" /data
# Expected: 2500

kubectl exec -n ex-2-2 onrootmismatch -- stat -c "%g" /data/record
# Expected: 2500

kubectl get pod -n ex-2-2 onrootmismatch -o jsonpath='{.spec.securityContext.fsGroupChangePolicy}'
# Expected: OnRootMismatch
```

---

### Exercise 2.3

**Objective:** Add extra group memberships via `supplementalGroups` and verify the process belongs to every listed GID.

**Setup:**

```bash
kubectl create namespace ex-2-3
```

**Task:** In namespace `ex-2-3`, create a pod named `many-groups` running image `busybox:1.36` with command `["sleep", "3600"]`. Configure it to run as UID 1010, primary GID 3010, and `supplementalGroups: [4000, 5000, 6000]`.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/many-groups -n ex-2-3 --timeout=60s

kubectl exec -n ex-2-3 many-groups -- id -G
# Expected: 3010 4000 5000 6000

kubectl exec -n ex-2-3 many-groups -- id -u
# Expected: 1010
```

---

## Level 3: Debugging

### Exercise 3.1

**Objective:** Find and fix whatever is preventing the pod below from writing to its mounted volume.

**Setup:**

```bash
kubectl create namespace ex-3-1
kubectl apply -n ex-3-1 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken
spec:
  securityContext:
    runAsUser: 1000
    runAsGroup: 3000
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
EOF
```

**Task:** Diagnose why the pod is restarting and adjust the pod spec so the loop writes to `/work/log` successfully without changing the image, the command, the mountPath, or the volume type.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/broken -n ex-3-1 --timeout=60s

kubectl get pod -n ex-3-1 broken -o jsonpath='{.status.containerStatuses[0].restartCount}'
# Expected: 0 (or low and not increasing)

kubectl exec -n ex-3-1 broken -- test -s /work/log
echo $?
# Expected: 0

kubectl exec -n ex-3-1 broken -- stat -c "%g" /work
# Expected: a non-zero GID (the fsGroup you set)
```

---

### Exercise 3.2

**Objective:** The pod below is stuck at `CreateContainerConfigError`. Adjust the pod spec so it reaches `Running` without allowing it to run as root.

**Setup:**

```bash
kubectl create namespace ex-3-2
kubectl apply -n ex-3-2 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: blocked
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
```

**Task:** Get the pod to `Running` without removing `runAsNonRoot: true` and without changing the image.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/blocked -n ex-3-2 --timeout=60s

kubectl get pod -n ex-3-2 blocked -o jsonpath='{.status.phase}'
# Expected: Running

kubectl exec -n ex-3-2 blocked -- id -u
# Expected: a non-zero UID

kubectl get pod -n ex-3-2 blocked -o jsonpath='{.spec.securityContext.runAsNonRoot}'
# Expected: true
```

---

### Exercise 3.3

**Objective:** The multi-container pod below has two containers that need to share one volume, and one of the two cannot read the files the other writes. Adjust the pod spec so both can read and write the shared volume.

**Setup:**

```bash
kubectl create namespace ex-3-3
kubectl apply -n ex-3-3 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: mismatch
spec:
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
EOF
```

**Task:** Adjust the pod so both containers can read and write the shared volume, without giving either container a UID of 0.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/mismatch -n ex-3-3 --timeout=60s

kubectl logs -n ex-3-3 mismatch -c reader
# Expected: content

kubectl exec -n ex-3-3 mismatch -c reader -- sh -c 'echo response > /shared/reply && cat /shared/reply'
# Expected: response

kubectl exec -n ex-3-3 mismatch -c writer -- cat /shared/reply
# Expected: response
```

---

## Level 4: Precedence and Multi-Container

### Exercise 4.1

**Objective:** Override a pod-level identity for one of two containers.

**Setup:**

```bash
kubectl create namespace ex-4-1
```

**Task:** In namespace `ex-4-1`, create a pod named `mixed-identity` with two containers, both image `busybox:1.36` with command `["sleep", "3600"]`. Container `one` must run with the pod-level settings (UID 1500, GID 2500). Container `two` must override to run as UID 7000, GID 8000.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/mixed-identity -n ex-4-1 --timeout=60s

kubectl exec -n ex-4-1 mixed-identity -c one -- id -u
# Expected: 1500

kubectl exec -n ex-4-1 mixed-identity -c one -- id -g
# Expected: 2500

kubectl exec -n ex-4-1 mixed-identity -c two -- id -u
# Expected: 7000

kubectl exec -n ex-4-1 mixed-identity -c two -- id -g
# Expected: 8000
```

---

### Exercise 4.2

**Objective:** Run three containers with three different UIDs, each producing a file into a shared `emptyDir` that all three can later read.

**Setup:**

```bash
kubectl create namespace ex-4-2
```

**Task:** In namespace `ex-4-2`, create a pod named `three-writers`. All three containers use image `busybox:1.36`. Container `a` runs as UID 1000 and writes `hello-a` to `/shared/a.txt`, then sleeps. Container `b` runs as UID 2000 and writes `hello-b` to `/shared/b.txt`, then sleeps. Container `c` runs as UID 3000 and writes `hello-c` to `/shared/c.txt`, then sleeps. Use `fsGroup: 9000` so all three can access the shared volume, and verify that container `a` can read `c.txt`.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/three-writers -n ex-4-2 --timeout=60s

kubectl exec -n ex-4-2 three-writers -c a -- cat /shared/a.txt
# Expected: hello-a

kubectl exec -n ex-4-2 three-writers -c a -- cat /shared/c.txt
# Expected: hello-c

kubectl exec -n ex-4-2 three-writers -c b -- cat /shared/a.txt
# Expected: hello-a

kubectl exec -n ex-4-2 three-writers -c c -- stat -c "%g" /shared/a.txt
# Expected: 9000
```

---

### Exercise 4.3

**Objective:** Configure an `nginx:1.25` pod for the Restricted-compatible identity pattern (non-root, specific UID/GID, `runAsNonRoot: true` at pod level), and confirm the pod still serves HTTP on port 8080.

**Setup:**

```bash
kubectl create namespace ex-4-3
```

**Task:** In namespace `ex-4-3`, create a pod named `hardened-web` running the `nginx:1.25` image. Use a `ConfigMap` named `nginx-conf` to override the default nginx config so nginx listens on port 8080 (not 80, which requires privileged capability to bind as non-root) and serves a simple static response. Configure the pod with `runAsUser: 101`, `runAsGroup: 101`, `runAsNonRoot: true`, and `fsGroup: 101` at pod level. Mount the ConfigMap at `/etc/nginx/conf.d/` with key `default.conf`.

**Hint:** The nginx:1.25 image's `nginx` user is UID 101.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/hardened-web -n ex-4-3 --timeout=60s

kubectl exec -n ex-4-3 hardened-web -- id -u
# Expected: 101

kubectl get pod -n ex-4-3 hardened-web -o jsonpath='{.spec.securityContext.runAsNonRoot}'
# Expected: true

kubectl exec -n ex-4-3 hardened-web -- wget -qO- http://localhost:8080
# Expected: non-empty response body
```

---

## Level 5: Advanced and Comprehensive

### Exercise 5.1

**Objective:** Design a security context for an application with these documented requirements: effective UID 1042 (`app`), primary GID 2042 (`appgrp`), must belong to group 3042 (`shared-data`) for a shared NFS-style mount modeled here with an `emptyDir`, must fail to start if the image somehow switches to UID 0, and must not be able to accidentally create a file outside the shared group.

**Setup:**

```bash
kubectl create namespace ex-5-1
```

**Task:** In namespace `ex-5-1`, create a pod named `appserver` running `busybox:1.36` with command `["sleep", "3600"]`. Meet every requirement above. Mount an `emptyDir` at `/shared`. Verify from inside that the effective UID is 1042, the effective primary GID is 2042, the process belongs to group 3042, and a file created in `/shared` is group-owned by 3042 even though the primary GID is 2042.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/appserver -n ex-5-1 --timeout=60s

kubectl exec -n ex-5-1 appserver -- id -u
# Expected: 1042

kubectl exec -n ex-5-1 appserver -- id -g
# Expected: 2042

kubectl exec -n ex-5-1 appserver -- id -G
# Expected: 2042 3042 (in some order, must contain both)

kubectl exec -n ex-5-1 appserver -- sh -c 'echo test > /shared/f && stat -c "%g" /shared/f'
# Expected: 3042

kubectl get pod -n ex-5-1 appserver -o jsonpath='{.spec.securityContext.runAsNonRoot}'
# Expected: true
```

---

### Exercise 5.2

**Objective:** The pod below bundles an application, a logs sidecar, and a shared `emptyDir`. Both containers are reporting errors, the application cannot write logs, and the sidecar cannot read them. Diagnose and fix every problem so the application writes logs every 2 seconds and the sidecar reads and prints them continuously.

**Setup:**

```bash
kubectl create namespace ex-5-2
kubectl apply -n ex-5-2 -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: app-plus-logs
spec:
  securityContext:
    runAsUser: 0
    runAsNonRoot: true
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
EOF
```

**Task:** Fix whatever needs fixing. The resulting pod must reach `Running`, both containers must keep `runAsNonRoot: true` effective identity (so no container should run as UID 0), the `app` container must write to `/var/log/app.log`, and the `sidecar` container must be able to tail it. Do not change image versions or commands.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/app-plus-logs -n ex-5-2 --timeout=60s

kubectl exec -n ex-5-2 app-plus-logs -c app -- id -u
# Expected: 1500

kubectl exec -n ex-5-2 app-plus-logs -c sidecar -- id -u
# Expected: 2500

kubectl get pod -n ex-5-2 app-plus-logs -o jsonpath='{.status.containerStatuses[?(@.name=="app")].restartCount}'
# Expected: 0

sleep 5
kubectl logs -n ex-5-2 app-plus-logs -c sidecar --tail=2
# Expected: two most recent date lines from the app
```

---

### Exercise 5.3

**Objective:** Design and apply a security context strategy for a three-tier pod (a `frontend` container, a `backend` container, and an `exporter` sidecar) where every container runs as a different non-root UID, all three share one volume for metrics, and the pod satisfies the Restricted-profile identity rules (`runAsNonRoot: true`; every container has an explicit `runAsUser`).

**Setup:**

```bash
kubectl create namespace ex-5-3
```

**Task:** In namespace `ex-5-3`, create a pod named `three-tier`. `frontend` uses `nginx:1.25`, runs as UID 101, listens on 8080 via a mounted ConfigMap, and writes a heartbeat file every 5 seconds to `/metrics/frontend.ok`. `backend` uses `busybox:1.36`, runs as UID 1020, and writes a heartbeat file every 5 seconds to `/metrics/backend.ok`. `exporter` uses `busybox:1.36`, runs as UID 1030, reads both heartbeat files once per iteration, and prints a summary line. Use `fsGroup: 7000` on the pod so all three can write to `/metrics`. Set `runAsNonRoot: true` at pod level.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/three-tier -n ex-5-3 --timeout=60s

kubectl exec -n ex-5-3 three-tier -c frontend -- id -u
# Expected: 101

kubectl exec -n ex-5-3 three-tier -c backend -- id -u
# Expected: 1020

kubectl exec -n ex-5-3 three-tier -c exporter -- id -u
# Expected: 1030

sleep 10
kubectl exec -n ex-5-3 three-tier -c exporter -- ls /metrics
# Expected: backend.ok  frontend.ok

kubectl logs -n ex-5-3 three-tier -c exporter --tail=1
# Expected: a summary line mentioning both frontend.ok and backend.ok

kubectl get pod -n ex-5-3 three-tier -o jsonpath='{.spec.securityContext.runAsNonRoot}'
# Expected: true
```

---

## Cleanup

Remove every exercise namespace.

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 \
         ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3; do
  kubectl delete namespace "$ns" --ignore-not-found
done
```

## Key Takeaways

The effective UID and primary GID control identity on the process level. Supplementary groups expand the permission surface for reads and writes to files owned by additional groups. `fsGroup` is the single field that makes a non-root container able to write to an `emptyDir`, a `configMap`, a `secret`, or any PVC-backed volume whose backend supports ownership change, because it chowns the mount to that group and sets the setgid bit on directories so created files inherit the group. `runAsNonRoot` is a validator, not a setter: it fails the container at start if the effective UID would be 0. Container-level security contexts override pod-level for the fields that exist at both scopes (`runAsUser`, `runAsGroup`, `runAsNonRoot`). `fsGroup` and `supplementalGroups` are pod-level only.
