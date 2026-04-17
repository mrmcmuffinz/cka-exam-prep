# Multi-Container Patterns: Homework Answers

**Assignment 6 | CKA Pod Series**

Complete solutions for all 15 exercises, plus common mistakes and reference material.

---

## Level 1 Solutions

### Exercise 1.1 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-writer
  namespace: ex-1-1
spec:
  initContainers:
  - name: seed
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "init-complete" > /work/status.txt
    volumeMounts:
    - name: workdir
      mountPath: /work
  containers:
  - name: reader
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      cat /data/status.txt
      sleep 3600
    volumeMounts:
    - name: workdir
      mountPath: /data
  volumes:
  - name: workdir
    emptyDir: {}
```

Apply:

```bash
kubectl apply -f - -n ex-1-1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: init-writer
  namespace: ex-1-1
spec:
  initContainers:
  - name: seed
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "init-complete" > /work/status.txt
    volumeMounts:
    - name: workdir
      mountPath: /work
  containers:
  - name: reader
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      cat /data/status.txt
      sleep 3600
    volumeMounts:
    - name: workdir
      mountPath: /data
  volumes:
  - name: workdir
    emptyDir: {}
EOF
```

**Key points:** The init container writes to `/work/status.txt` and the main container reads from `/data/status.txt`. These are different mount paths but the same volume (`workdir`), so they see the same underlying file. The init container exits 0 after writing, which allows the main container to start.

---

### Exercise 1.2 Solution

```bash
kubectl apply -f - -n ex-1-2 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: timestamper
  namespace: ex-1-2
spec:
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      sleep 3600
    volumeMounts:
    - name: data
      mountPath: /app-data
  - name: clock
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      while true; do
        date > /sidecar-data/timestamp.txt
        sleep 5
      done
    volumeMounts:
    - name: data
      mountPath: /sidecar-data
  volumes:
  - name: data
    emptyDir: {}
EOF
```

**Key points:** This is the simplest sidecar pattern. The clock container continuously updates a file, and the app container can read it at any time. Both mount the same volume at different paths. The sidecar's loop runs indefinitely, which is typical for classical sidecars.

---

### Exercise 1.3 Solution

```bash
kubectl apply -f - -n ex-1-3 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: shared-pids
  namespace: ex-1-3
spec:
  shareProcessNamespace: true
  containers:
  - name: worker
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      sleep 3600
  - name: inspector
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      sleep 3600
EOF
```

**Key points:** The `shareProcessNamespace: true` field is set at the pod spec level, not the container level. It applies to all containers in the pod (there is no per-container toggle). When you run `ps aux` from the inspector container, you will see the worker's `sleep` process, the inspector's own processes, and the infrastructure pause process.

---

## Level 2 Solutions

### Exercise 2.1 Solution

```bash
kubectl apply -f - -n ex-2-1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: triple-init
  namespace: ex-2-1
spec:
  initContainers:
  - name: stage-a
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "alpha" > /pipeline/a.txt
    volumeMounts:
    - name: pipeline
      mountPath: /pipeline
  - name: stage-b
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "bravo" > /pipeline/b.txt
    volumeMounts:
    - name: pipeline
      mountPath: /pipeline
  - name: stage-c
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "charlie" > /pipeline/c.txt
    volumeMounts:
    - name: pipeline
      mountPath: /pipeline
  containers:
  - name: verifier
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      ALL_PRESENT=true
      for f in a.txt b.txt c.txt; do
        if [ ! -f "/pipeline/$f" ]; then
          echo "MISSING STAGE: $f"
          ALL_PRESENT=false
        fi
      done
      if [ "$ALL_PRESENT" = "true" ]; then
        echo "ALL STAGES COMPLETE"
      else
        exit 1
      fi
      sleep 3600
    volumeMounts:
    - name: pipeline
      mountPath: /pipeline
  volumes:
  - name: pipeline
    emptyDir: {}
EOF
```

**Key points:** Init containers run in declaration order: stage-a, then stage-b, then stage-c. Each writes to the same shared volume. The main container checks for all three files. Because init containers have ordering guarantees, all three files will exist when the main container starts (assuming all init containers exit 0).

---

### Exercise 2.2 Solution

```bash
kubectl apply -f - -n ex-2-2 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: readonly-sidecar
  namespace: ex-2-2
spec:
  containers:
  - name: producer
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      while true; do
        echo "log-entry-$(date +%s)" >> /logs/app.log
        sleep 3
      done
    volumeMounts:
    - name: logs
      mountPath: /logs
  - name: consumer
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      while [ ! -f /logs/app.log ]; do
        sleep 1
      done
      tail -f /logs/app.log
    volumeMounts:
    - name: logs
      mountPath: /logs
      readOnly: true
  volumes:
  - name: logs
    emptyDir: {}
EOF
```

**Key points:** The `readOnly: true` on the consumer's volumeMount means it can read from the volume but any write attempt will fail with "Read-only file system". This is a safety mechanism: the log consumer should never modify the producer's log files. Note that `readOnly` is set per-container on the volumeMount, not on the volume definition itself.

---

### Exercise 2.3 Solution

```bash
kubectl apply -f - -n ex-2-3 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: format-adapter
  namespace: ex-2-3
spec:
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      while true; do
        echo "requests=150 errors=3 latency_ms=42" > /metrics/raw.txt
        sleep 5
      done
    volumeMounts:
    - name: metrics
      mountPath: /metrics
  - name: json-adapter
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      while [ ! -f /metrics/raw.txt ]; do
        sleep 1
      done
      while true; do
        RAW=$(cat /metrics/raw.txt)
        JSON=$(echo "$RAW" | awk '{
          for(i=1;i<=NF;i++) {
            split($i,a,"=");
            printf "\"%s\":\"%s\"", a[1], a[2];
            if(i<NF) printf ","
          }
        }')
        echo "{${JSON}}"
        sleep 5
      done
    volumeMounts:
    - name: metrics
      mountPath: /metrics
      readOnly: true
  volumes:
  - name: metrics
    emptyDir: {}
EOF
```

**Key points:** This is the adapter pattern. The main container writes in its native plain-text format. The adapter reads the plain text and converts it to JSON for external consumption. The adapter mounts the volume as read-only because it only reads. The transformation here is trivial (space-delimited key=value to JSON), but the pattern applies to any format conversion.

---

## Level 3 Solutions

### Exercise 3.1 Solution

**The problem:** The init container writes the greeting to `/prepare/greeting.txt`, but the main container tries to read `/data/welcome.txt`. Both mount the same volume, so the file exists, but the *filename* is wrong. The init container creates `greeting.txt` and the main container expects `welcome.txt`.

**How to diagnose:** The pod will be Running (the init container completes successfully), but the main container's logs will show an error because `cat /data/welcome.txt` fails (the file is named `greeting.txt` at that path).

```bash
# Check main container logs
kubectl logs broken-init -c app -n ex-3-1
# You would see: cat: can't open '/data/welcome.txt': No such file or directory

# Exec into the main container to see what file actually exists
kubectl exec broken-init -c app -n ex-3-1 -- ls /data/
# You would see: greeting.txt (not welcome.txt)
```

**The fix:** Either change the init container to write to `welcome.txt`, or change the main container to read `greeting.txt`. The cleanest fix is to align the filenames. Delete and recreate:

```bash
kubectl delete pod broken-init -n ex-3-1

kubectl apply -f - -n ex-3-1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-init
  namespace: ex-3-1
spec:
  initContainers:
  - name: greeter
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "Welcome aboard" > /prepare/greeting.txt
    volumeMounts:
    - name: shared
      mountPath: /prepare
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "Greeting: $(cat /data/greeting.txt)"
      sleep 3600
    volumeMounts:
    - name: shared
      mountPath: /data
  volumes:
  - name: shared
    emptyDir: {}
EOF
```

---

### Exercise 3.2 Solution

**The problem:** The client container connects to `localhost:9090`, but the ambassador container listens on port `7070`. They are in the same pod (shared network namespace), so localhost works, but the port mismatch means the client's connection fails.

**How to diagnose:**

```bash
# Check client logs
kubectl logs broken-ambassador -c client -n ex-3-2
# You would see: Client: got CONNECTION_FAILED

# Check ambassador logs
kubectl logs broken-ambassador -c ambassador -n ex-3-2
# You would see: Ambassador: starting on port 7070...
# The ambassador is listening, just on the wrong port
```

The client expects port 9090, the ambassador listens on 7070. Either change the client or change the ambassador to use the same port.

**The fix:**

```bash
kubectl delete pod broken-ambassador -n ex-3-2

kubectl apply -f - -n ex-3-2 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-ambassador
  namespace: ex-3-2
spec:
  containers:
  - name: client
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      sleep 5
      echo "Client: connecting to ambassador at localhost:9090..."
      RESULT=$(wget -qO- http://localhost:9090/ 2>/dev/null || echo "CONNECTION_FAILED")
      echo "Client: got $RESULT"
      sleep 3600
  - name: ambassador
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "Ambassador: starting on port 9090..."
      while true; do
        echo -e "HTTP/1.1 200 OK\r\n\r\nproxied-response" | nc -l -p 9090 -w 1
      done
EOF
```

---

### Exercise 3.3 Solution

**The problem:** The `log-archiver` container mounts the volume with `readOnly: true` but its command runs `cp /logs/output.log /logs/output.log.bak`, which is a write operation. Writing to a read-only mount causes the container to fail and enter CrashLoopBackOff.

**How to diagnose:**

```bash
# Check which container is failing
kubectl get pod broken-sidecar -n ex-3-3
# You would see 2/3 or similar, with one container restarting

kubectl get pod broken-sidecar -n ex-3-3 -o jsonpath='{range .status.containerStatuses[*]}{.name}: restarts={.restartCount}{"\n"}{end}'
# log-archiver would show increasing restarts

# Check log-archiver logs
kubectl logs broken-sidecar -c log-archiver -n ex-3-3 --previous
# You would see: cp: can't create '/logs/output.log.bak': Read-only file system
```

**The fix:** The log-archiver needs write access to create the backup file. Remove `readOnly: true` from the log-archiver's volumeMount (or give it a separate volume for backups). The simplest fix is to remove the readOnly constraint:

```bash
kubectl delete pod broken-sidecar -n ex-3-3

kubectl apply -f - -n ex-3-3 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-sidecar
  namespace: ex-3-3
spec:
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      while true; do
        echo "$(date): app is running" >> /var/log/app/output.log
        sleep 3
      done
    volumeMounts:
    - name: applog
      mountPath: /var/log/app
  - name: log-reader
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      while [ ! -f /logs/output.log ]; do
        sleep 1
      done
      tail -f /logs/output.log
    volumeMounts:
    - name: applog
      mountPath: /logs
      readOnly: true
  - name: log-archiver
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      while [ ! -f /logs/output.log ]; do
        sleep 1
      done
      while true; do
        cp /logs/output.log /logs/output.log.bak
        sleep 30
      done
    volumeMounts:
    - name: applog
      mountPath: /logs
  volumes:
  - name: applog
    emptyDir: {}
EOF
```

---

## Level 4 Solutions

### Exercise 4.1 Solution

```bash
kubectl apply -f - -n ex-4-1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: log-shipper
  namespace: ex-4-1
spec:
  containers:
  - name: web
    image: nginx:1.25
    volumeMounts:
    - name: nginx-logs
      mountPath: /var/log/nginx
  - name: shipper
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      while [ ! -f /logs/access.log ]; do
        sleep 1
      done
      echo "Shipper: tailing access.log with [SHIPPED] prefix..."
      tail -f /logs/access.log | sed 's/^/[SHIPPED] /'
    volumeMounts:
    - name: nginx-logs
      mountPath: /logs
      readOnly: true
  volumes:
  - name: nginx-logs
    emptyDir: {}
EOF
```

**Key points:** The shipper uses `tail -f` piped through `sed` to prepend the tag. The `sed 's/^/[SHIPPED] /'` replaces the beginning of each line with the prefix. The shipper mounts the volume as read-only. Nginx writes access logs to `/var/log/nginx/access.log` by default when that directory is mounted as a volume (overriding the default symlink to stdout).

---

### Exercise 4.2 Solution

```bash
kubectl apply -f - -n ex-4-2 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: cache-proxy
  namespace: ex-4-2
spec:
  initContainers:
  - name: seed-cache
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo '{"status":"fresh","ttl":300}' > /cache/response.json
    volumeMounts:
    - name: cache-data
      mountPath: /cache
  containers:
  - name: proxy
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "Proxy: serving cached content on port 8080..."
      while true; do
        CONTENT=$(cat /cache/response.json)
        RESPONSE="HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: $(echo -n "$CONTENT" | wc -c)\r\n\r\n${CONTENT}"
        echo -e "$RESPONSE" | nc -l -p 8080 -w 1
      done
    volumeMounts:
    - name: cache-data
      mountPath: /cache
      readOnly: true
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      sleep 5
      echo "App: requesting data from cache proxy..."
      RESULT=$(wget -qO- http://localhost:8080/ 2>/dev/null || echo "FAILED")
      echo "App: received: $RESULT"
      sleep 3600
    volumeMounts:
    - name: cache-data
      mountPath: /cache
  volumes:
  - name: cache-data
    emptyDir: {}
EOF
```

**Key points:** This combines the init container pattern (seed-cache pre-populates the cache file) with the ambassador pattern (proxy serves the cached content on localhost:8080). The main container connects to localhost:8080 without knowing how the data is stored or where it comes from. The proxy has a read-only mount because it only serves the data.

---

### Exercise 4.3 Solution

**(Requires K8s 1.29+)**

```bash
kubectl apply -f - -n ex-4-3 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: native-logger
  namespace: ex-4-3
spec:
  initContainers:
  - name: log-tailer
    image: busybox:1.36
    restartPolicy: Always
    command:
    - sh
    - -c
    - |
      while [ ! -f /logs/app.log ]; do
        sleep 1
      done
      tail -f /logs/app.log
    volumeMounts:
    - name: app-logs
      mountPath: /logs
      readOnly: true
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      while true; do
        echo "app event at $(date)" >> /app-logs/app.log
        sleep 3
      done
    volumeMounts:
    - name: app-logs
      mountPath: /app-logs
  volumes:
  - name: app-logs
    emptyDir: {}
EOF
```

**Key points:** The `log-tailer` is in `initContainers` with `restartPolicy: Always`. This makes it a native sidecar: it starts before the main container (init ordering) but keeps running alongside it (the Always restart policy prevents it from being treated as a one-shot init). In `kubectl get pod -o yaml`, the log-tailer appears under `initContainerStatuses` with a state of `running`, not `terminated`.

---

## Level 5 Solutions

### Exercise 5.1 Solution

**The problems (two issues):**

1. **Duplicate container names.** Both the main container and the sidecar are named `app`. Container names must be unique across the entire pod (both `containers` and `initContainers` arrays). Kubernetes will reject the pod at admission with an error like `Duplicate value: "app"`.

2. Because the pod is rejected at admission, you need to fix the name and resubmit. The second container (the monitor/sidecar) needs a unique name such as `monitor`.

**How to diagnose:**

```bash
# Try to get the pod
kubectl get pod broken-multi -n ex-5-1
# It won't exist because the API server rejected it

# Check the apply output, which would show:
# The Pod "broken-multi" is invalid: spec.containers[1].name: Duplicate value: "app"
```

**The fix:**

```bash
kubectl apply -f - -n ex-5-1 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-multi
  namespace: ex-5-1
spec:
  initContainers:
  - name: config-seed
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "db_host=postgres.svc" > /init-data/app.conf
      echo "Config seeded."
    volumeMounts:
    - name: config
      mountPath: /init-data
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "Config: $(cat /config/app.conf)"
      while true; do
        echo "$(date): processing" >> /output/activity.log
        sleep 5
      done
    volumeMounts:
    - name: config
      mountPath: /config
      readOnly: true
    - name: output
      mountPath: /output
  - name: monitor
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      while [ ! -f /watch/activity.log ]; do
        sleep 1
      done
      tail -f /watch/activity.log
    volumeMounts:
    - name: output
      mountPath: /watch
      readOnly: true
  volumes:
  - name: config
    emptyDir: {}
  - name: output
    emptyDir: {}
EOF
```

**Key lesson:** Container name collisions across the `containers` and `initContainers` arrays are rejected at admission. The error message is clear, but under time pressure on the CKA exam, it is easy to miss when copying and modifying container specs.

---

### Exercise 5.2 Solution

**(Requires K8s 1.29+)**

**The problem:** The `web-monitor` is intended to be a native sidecar but is placed in the `containers` array as a classical sidecar. It needs to be moved to `initContainers` with `restartPolicy: Always` so it starts before the `web` container and behaves as a native sidecar.

**How to diagnose:** The pod as given will actually run (both containers work as classical sidecars). The diagnosis comes from the verification checks: `web-monitor` will not appear in `initContainers`, and it will not have `restartPolicy: Always`. The pod functions, but the lifecycle guarantees are wrong.

**The fix:** Move `web-monitor` from `containers` to `initContainers` (after `setup`), and add `restartPolicy: Always`:

```bash
kubectl delete pod broken-native -n ex-5-2 --ignore-not-found

kubectl apply -f - -n ex-5-2 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-native
  namespace: ex-5-2
spec:
  initContainers:
  - name: setup
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "environment=production" > /work/env.conf
      echo "Setup complete."
    volumeMounts:
    - name: workdir
      mountPath: /work
  - name: web-monitor
    image: busybox:1.36
    restartPolicy: Always
    command:
    - sh
    - -c
    - |
      while [ ! -f /monitor/web.log ]; do
        sleep 1
      done
      tail -f /monitor/web.log
    volumeMounts:
    - name: logs
      mountPath: /monitor
      readOnly: true
  containers:
  - name: web
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      CONFIG=$(cat /config/env.conf)
      echo "Web started with: $CONFIG"
      while true; do
        echo "$(date): request handled" >> /web-logs/web.log
        sleep 3
      done
    volumeMounts:
    - name: workdir
      mountPath: /config
      readOnly: true
    - name: logs
      mountPath: /web-logs
  volumes:
  - name: workdir
    emptyDir: {}
  - name: logs
    emptyDir: {}
EOF
```

**Key lesson:** A native sidecar is an init container with `restartPolicy: Always`. If you put it in `containers`, it is a classical sidecar (no ordering guarantees). If you put it in `initContainers` without `restartPolicy: Always`, it is a normal init container that blocks the main containers indefinitely (because it never exits). The combination of placement in `initContainers` plus `restartPolicy: Always` is what makes it a native sidecar.

---

### Exercise 5.3 Solution

**(Requires K8s 1.29+)**

```bash
kubectl apply -f - -n ex-5-3 <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: obs-stack
  namespace: ex-5-3
spec:
  initContainers:
  - name: html-seed
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "<html><body><h1>Built at $(date)</h1></body></html>" > /seed/index.html
    volumeMounts:
    - name: html
      mountPath: /seed
  - name: log-forwarder
    image: busybox:1.36
    restartPolicy: Always
    command:
    - sh
    - -c
    - |
      while [ ! -f /logs/access.log ]; do
        sleep 1
      done
      tail -f /logs/access.log | sed 's/^/[FWD] /'
    volumeMounts:
    - name: nginx-logs
      mountPath: /logs
      readOnly: true
  - name: metrics-adapter
    image: busybox:1.36
    restartPolicy: Always
    command:
    - sh
    - -c
    - |
      while [ ! -f /metrics/stub-status.txt ]; do
        sleep 1
      done
      while true; do
        RAW=$(cat /metrics/stub-status.txt)
        ACTIVE=$(echo "$RAW" | head -1 | awk '{print $NF}')
        REQUESTS=$(echo "$RAW" | sed -n '3p' | awk '{print $NF}')
        echo "{\"active_connections\":\"${ACTIVE}\",\"total_requests\":\"${REQUESTS}\"}"
        sleep 5
      done
    volumeMounts:
    - name: metrics
      mountPath: /metrics
      readOnly: true
  containers:
  - name: web
    image: nginx:1.25
    command:
    - sh
    - -c
    - |
      # Start nginx in background
      nginx -g 'daemon off;' &
      NGINX_PID=$!
      # Write simulated stub_status data periodically
      while true; do
        cat > /metrics/stub-status.txt <<STUB
Active connections: 3
server accepts handled requests
 100 100 200
Reading: 0 Writing: 1 Waiting: 0
STUB
        sleep 5
      done
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html
      readOnly: true
    - name: nginx-logs
      mountPath: /var/log/nginx
    - name: metrics
      mountPath: /metrics
  volumes:
  - name: html
    emptyDir: {}
  - name: nginx-logs
    emptyDir: {}
  - name: metrics
    emptyDir: {}
EOF
```

**Key points:**

- `html-seed` is a normal init container (no `restartPolicy`). It runs first, writes index.html, and exits.
- `log-forwarder` and `metrics-adapter` are native sidecars (`restartPolicy: Always`). They start in init order (after html-seed, then log-forwarder, then metrics-adapter) and continue running alongside the main container.
- The `web` container uses a custom command to start nginx in the background and run a loop that writes simulated metrics. This is necessary because we need both nginx serving traffic and the metrics data being written.
- The `html` volume is mounted read-only in the web container since the content was seeded by the init container and should not change.
- `nginx-logs` is read-write for web (nginx writes access logs) and read-only for log-forwarder.
- `metrics` is read-write for web (writes stub-status data) and read-only for metrics-adapter.

---

## Common Mistakes

### 1. Different Mount Paths, Same Volume

Two containers mount the same emptyDir volume at different paths (e.g., `/data` and `/output`). A common confusion is thinking the files are at different locations on disk. They are not: both paths point to the same underlying directory. A file written as `/data/report.txt` by container A is visible as `/output/report.txt` to container B. The file is the same; the path is just a different "lens" into the same volume.

### 2. emptyDir Lifetime is Pod-Scoped

If a container crashes and restarts, the emptyDir contents persist. The volume lives as long as the pod lives, not as long as any individual container lives. This is important for sidecars: if the sidecar crashes and restarts, it does not lose the data in the shared volume.

### 3. Native Sidecar in the Wrong Array

Putting a "native sidecar" in the `containers` array instead of `initContainers` makes it a classical sidecar. It will not have startup ordering guarantees and will not be terminated when the main container exits. The distinction is entirely about placement: `initContainers` + `restartPolicy: Always` = native sidecar.

### 4. Long-Running Init Container Without restartPolicy: Always

Putting a long-running process (like `tail -f`) in `initContainers` *without* `restartPolicy: Always` makes it a normal init container. Normal init containers must exit for the next init container (or main containers) to start. A long-running process that never exits will block the pod in `Init` state forever.

### 5. shareProcessNamespace is Pod-Wide

Setting `shareProcessNamespace: true` affects all containers in the pod. There is no way to share processes between only two of three containers. It is all or nothing. If you enable it, every container can see every other container's processes.

### 6. Ambassador Port Mismatch

The ambassador must listen on the port the main container connects to. If the main container sends requests to `localhost:8080` and the ambassador listens on port `9090`, the connection fails. This is the most common ambassador debugging scenario.

### 7. Ambassador Connection Handling

Simple `nc`-based ambassadors can be fragile. The busybox `nc` may not handle concurrent connections, HTTP keep-alive, or large payloads correctly. For tutorial and exam purposes, simple `nc` loops work. In production, use a real proxy (Envoy, nginx, HAProxy).

### 8. Adapter Reads From Wrong Source

A common mistake is building an adapter that reads from stdin when the main container writes to a file, or vice versa. The adapter must match the main container's output mechanism. If the main writes to a file, the adapter reads that file. If the main writes to stdout, the adapter needs a different mechanism (shared process namespace or a log driver).

### 9. Regular Containers Have No Startup Order

Unlike init containers, regular containers in the `containers` array have no guaranteed startup order. Container B might start before container A, even if A is listed first. If your sidecar depends on the main container having created a file, the sidecar must include a wait loop (e.g., `while [ ! -f /path ]; do sleep 1; done`). Native sidecars solve this by starting in init order, but classical sidecars do not have this guarantee.

### 10. Container Name Collisions

Container names must be unique across both `containers` and `initContainers`. You cannot have an init container named `app` and a regular container also named `app`. Kubernetes rejects this at admission with a validation error.

### 11. Image Pull Policies on Sidecars

If a sidecar's image pull policy is set to `Always`, every container restart triggers an image pull. For frequently restarting sidecars, this adds latency and network overhead. Use specific image tags (not `latest`) and the default `IfNotPresent` policy for sidecars.

---

## Pattern Selection Reference

### Sidecar

- **Use when:** The helper augments the main container (log shipping, metric exporting, config reloading, certificate renewal, proxy caching). The helper exists only to serve the main container.
- **Don't use when:** The helper has independent value and could serve multiple consumers. The helper needs to scale independently.
- **Alternative:** A separate Deployment for the helper, communicating over a Service.

### Ambassador

- **Use when:** The main container needs to talk to an external service but should not know about service discovery, connection pooling, or environment-specific endpoints. The ambassador makes the external world look local.
- **Don't use when:** The main container can handle its own connections (simple HTTP calls with retries). The proxy logic is complex enough to warrant a dedicated proxy deployment (e.g., a full service mesh data plane).
- **Alternative:** A shared proxy Deployment (like an ingress controller or API gateway), or client-side connection management in the main container.

### Adapter

- **Use when:** The main container produces output in a format that external consumers do not understand. The adapter transforms the output without modifying the main container.
- **Don't use when:** You control the main container's code and can change its output format directly. The transformation is complex enough to warrant a dedicated service.
- **Alternative:** Modify the main container's output format directly, or use a centralized transformation service.

### Init Container

- **Use when:** A prerequisite must be satisfied before the main application starts (dependency check, volume pre-seeding, migration, configuration fetch). The prerequisite is a one-time setup task.
- **Don't use when:** The helper needs to keep running alongside the main container (use a sidecar or native sidecar). The prerequisite is a recurring task (use a sidecar loop).
- **Alternative:** Application-level startup checks (retry loops in the main container), though init containers provide cleaner separation.

### Native Sidecar

- **Use when:** The sidecar must start before the main container. The pod runs in a Job context and the sidecar should not prevent Job completion. Clean shutdown ordering matters (sidecar should stop after main).
- **Don't use when:** Startup ordering is irrelevant and the pod is not a Job. Your cluster is older than Kubernetes 1.29.
- **Alternative:** Classical sidecar with a startup wait loop (less clean but works on older clusters).

---

## Verification Commands Cheat Sheet

### Per-Container Logs

```bash
# Specific container
kubectl logs <pod> -c <container> -n <ns>

# Previous instance (after crash)
kubectl logs <pod> -c <container> -n <ns> --previous

# All containers
kubectl logs <pod> --all-containers -n <ns>

# Follow/stream
kubectl logs -f <pod> -c <container> -n <ns>
```

### Per-Container Exec

```bash
# Run a command
kubectl exec <pod> -c <container> -n <ns> -- <cmd>

# Interactive shell
kubectl exec -it <pod> -c <container> -n <ns> -- sh

# Check shared volume contents
kubectl exec <pod> -c <container> -n <ns> -- ls /mount/path
kubectl exec <pod> -c <container> -n <ns> -- cat /mount/path/file
```

### Per-Container Status

```bash
# Container states
kubectl get pod <pod> -n <ns> -o jsonpath='{range .status.containerStatuses[*]}{.name}: {.state}{"\n"}{end}'

# Init container states
kubectl get pod <pod> -n <ns> -o jsonpath='{range .status.initContainerStatuses[*]}{.name}: {.state}{"\n"}{end}'

# Restart counts
kubectl get pod <pod> -n <ns> -o jsonpath='{range .status.containerStatuses[*]}{.name}: restarts={.restartCount}{"\n"}{end}'

# Container names
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[*].name}'
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.initContainers[*].name}'
```

### Native Sidecar Verification

```bash
# Check if an init container is a native sidecar
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.initContainers[?(@.name=="<name>")].restartPolicy}'
# Expected for native sidecar: Always

# Verify native sidecar is running (not terminated)
kubectl get pod <pod> -n <ns> -o jsonpath='{.status.initContainerStatuses[?(@.name=="<name>")].state}'
# Expected: {"running":{"startedAt":"..."}}
```

### Volume and Mount Inspection

```bash
# List volumes
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.volumes[*].name}'

# Check a specific container's mounts
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[?(@.name=="<name>")].volumeMounts}'

# Check readOnly setting
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[?(@.name=="<name>")].volumeMounts[0].readOnly}'
```

### Process Namespace

```bash
# Check if shared process namespace is enabled
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.shareProcessNamespace}'

# View cross-container processes
kubectl exec <pod> -c <container> -n <ns> -- ps aux
```
