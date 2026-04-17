# Multi-Container Patterns: Homework Exercises

**Assignment 6 | CKA Pod Series**

This file contains 15 exercises organized by difficulty. Complete the tutorial (`multi-container-patterns-tutorial.md`) before starting these exercises. Solutions are in `multi-container-patterns-homework-answers.md`.

Multi-container pods are declarative-only in practice. There is no reasonable imperative path for creating a pod with multiple containers, init containers, shared volumes, and the other features covered here. All exercises use YAML applied with `kubectl apply`.

---

## Exercise Setup

### Cluster Verification

```bash
# Verify your cluster is running
kubectl get nodes

# Check Kubernetes version (1.29+ needed for native sidecar exercises)
kubectl version
```

### Kubernetes Version for Native Sidecars

Exercises marked **(Requires K8s 1.29+)** use native sidecars (`restartPolicy: Always` on init containers). If your cluster is older than 1.29, skip those exercises or upgrade your kind cluster:

```bash
kind create cluster --image kindest/node:v1.33.0
```

### Global Cleanup (Optional)

If you want to start fresh, remove all exercise namespaces:

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3; do
  kubectl delete namespace "$ns" --ignore-not-found
done
```

---

## Level 1: Basic Single-Concept Tasks

### Exercise 1.1

**Objective:** Create a pod with one init container that writes a message to a shared volume, and a main container that reads that message and prints it.

**Setup:**

```bash
kubectl create namespace ex-1-1
```

**Task:**

Create a pod named `init-writer` in namespace `ex-1-1` with the following:

- An init container named `seed` (image: `busybox:1.36`) that writes the text `init-complete` to the file `/work/status.txt` in a shared emptyDir volume, then exits.
- A main container named `reader` (image: `busybox:1.36`) that runs `cat /data/status.txt` and then sleeps for 3600 seconds. The main container mounts the same emptyDir volume at `/data`.
- A single emptyDir volume named `workdir` shared between both containers.

**Verification:**

```bash
# 1. Pod should be Running
kubectl get pod init-writer -n ex-1-1

# 2. Init container should show as completed
kubectl get pod init-writer -n ex-1-1 -o jsonpath='{.status.initContainerStatuses[0].state}'
# Expected: contains "terminated" with "reason":"Completed"

# 3. Main container should have printed the init container's message
kubectl logs init-writer -c reader -n ex-1-1
# Expected output should include: init-complete
```

---

### Exercise 1.2

**Objective:** Create a pod with a classical sidecar pattern where the sidecar writes timestamps to a shared volume and the main container can read them.

**Setup:**

```bash
kubectl create namespace ex-1-2
```

**Task:**

Create a pod named `timestamper` in namespace `ex-1-2` with the following:

- A main container named `app` (image: `busybox:1.36`) that runs `sleep 3600`. It mounts a shared emptyDir volume named `data` at `/app-data`.
- A sidecar container named `clock` (image: `busybox:1.36`) that writes the current date to `/sidecar-data/timestamp.txt` every 5 seconds in an infinite loop, then sleeps 5 seconds between writes. It mounts the same `data` volume at `/sidecar-data`.

**Verification:**

```bash
# 1. Pod should be Running with 2/2 containers ready
kubectl get pod timestamper -n ex-1-2

# 2. The timestamp file should exist and be readable from the main container
kubectl exec timestamper -c app -n ex-1-2 -- cat /app-data/timestamp.txt
# Expected: a date string

# 3. Wait 10 seconds and check again; the timestamp should have updated
sleep 10
kubectl exec timestamper -c app -n ex-1-2 -- cat /app-data/timestamp.txt
# Expected: a newer date string
```

---

### Exercise 1.3

**Objective:** Create a pod with shared process namespace and verify that one container can see the other container's processes.

**Setup:**

```bash
kubectl create namespace ex-1-3
```

**Task:**

Create a pod named `shared-pids` in namespace `ex-1-3` with the following:

- `shareProcessNamespace` set to `true`
- A container named `worker` (image: `busybox:1.36`) that runs the command `sleep 3600`.
- A container named `inspector` (image: `busybox:1.36`) that runs the command `sleep 3600`.

**Verification:**

```bash
# 1. Pod should be Running with 2/2 containers
kubectl get pod shared-pids -n ex-1-3

# 2. From the inspector container, list all processes
kubectl exec shared-pids -c inspector -n ex-1-3 -- ps aux
# Expected: should show sleep processes from BOTH containers, plus the pause process

# 3. Verify shareProcessNamespace is set
kubectl get pod shared-pids -n ex-1-3 -o jsonpath='{.spec.shareProcessNamespace}'
# Expected: true
```

---

## Level 2: Multi-Concept Tasks

### Exercise 2.1

**Objective:** Create a pod with three sequential init containers that each produce a file in a shared volume, and a main container that verifies all three files exist before proceeding.

**Setup:**

```bash
kubectl create namespace ex-2-1
```

**Task:**

Create a pod named `triple-init` in namespace `ex-2-1` with the following:

- Three init containers, all using image `busybox:1.36`, sharing an emptyDir volume named `pipeline` mounted at `/pipeline` in all containers:
  - `stage-a`: writes `alpha` to `/pipeline/a.txt`
  - `stage-b`: writes `bravo` to `/pipeline/b.txt`
  - `stage-c`: writes `charlie` to `/pipeline/c.txt`
- A main container named `verifier` (image: `busybox:1.36`) that checks for all three files. If all three exist, it prints `ALL STAGES COMPLETE` and sleeps. If any file is missing, it prints `MISSING STAGE` and exits with code 1.
- The init containers should be ordered so that `stage-a` runs first, then `stage-b`, then `stage-c`.

**Verification:**

```bash
# 1. Pod should be Running
kubectl get pod triple-init -n ex-2-1

# 2. All three init containers should have completed
kubectl get pod triple-init -n ex-2-1 -o jsonpath='{range .status.initContainerStatuses[*]}{.name}: {.state}{"\n"}{end}'
# Expected: all three show terminated/Completed

# 3. Main container logs should confirm all stages
kubectl logs triple-init -c verifier -n ex-2-1
# Expected: ALL STAGES COMPLETE

# 4. Verify all three files exist from the main container
kubectl exec triple-init -c verifier -n ex-2-1 -- ls /pipeline/
# Expected: a.txt  b.txt  c.txt

# 5. Verify file contents
kubectl exec triple-init -c verifier -n ex-2-1 -- cat /pipeline/a.txt
# Expected: alpha
kubectl exec triple-init -c verifier -n ex-2-1 -- cat /pipeline/b.txt
# Expected: bravo
```

---

### Exercise 2.2

**Objective:** Create a pod with a classical sidecar pattern where the sidecar has a read-only mount of the shared volume and the main container has a read-write mount.

**Setup:**

```bash
kubectl create namespace ex-2-2
```

**Task:**

Create a pod named `readonly-sidecar` in namespace `ex-2-2` with the following:

- An emptyDir volume named `logs`.
- A main container named `producer` (image: `busybox:1.36`) that writes `log-entry-<timestamp>` to `/logs/app.log` every 3 seconds in an infinite loop. It mounts the `logs` volume at `/logs` with read-write access (the default).
- A sidecar container named `consumer` (image: `busybox:1.36`) that waits for `/logs/app.log` to exist and then runs `tail -f /logs/app.log`. It mounts the `logs` volume at `/logs` with `readOnly: true`.

**Verification:**

```bash
# 1. Pod should be Running with 2/2 containers
kubectl get pod readonly-sidecar -n ex-2-2

# 2. The sidecar should be tailing log entries
sleep 10
kubectl logs readonly-sidecar -c consumer -n ex-2-2
# Expected: multiple lines starting with "log-entry-"

# 3. The sidecar should NOT be able to write to the volume
kubectl exec readonly-sidecar -c consumer -n ex-2-2 -- sh -c 'echo test > /logs/test.txt'
# Expected: error about read-only file system

# 4. The producer should be able to write
kubectl exec readonly-sidecar -c producer -n ex-2-2 -- sh -c 'echo test > /logs/test.txt'
# Expected: no error

# 5. Verify the readOnly setting in the spec
kubectl get pod readonly-sidecar -n ex-2-2 -o jsonpath='{.spec.containers[?(@.name=="consumer")].volumeMounts[0].readOnly}'
# Expected: true
```

---

### Exercise 2.3

**Objective:** Create a pod with an adapter sidecar that transforms the main container's output from plain text to a different format, and verify the transformed output.

**Setup:**

```bash
kubectl create namespace ex-2-3
```

**Task:**

Create a pod named `format-adapter` in namespace `ex-2-3` with the following:

- An emptyDir volume named `metrics`.
- A main container named `app` (image: `busybox:1.36`) that writes a line in the format `requests=150 errors=3 latency_ms=42` to `/metrics/raw.txt` every 5 seconds in an infinite loop.
- An adapter container named `json-adapter` (image: `busybox:1.36`) that reads `/metrics/raw.txt` every 5 seconds and outputs each key-value pair as a JSON line to stdout. For example, the raw input above should produce output containing `"requests":"150"`. The adapter mounts the volume at `/metrics` with `readOnly: true`.

**Verification:**

```bash
# 1. Pod should be Running with 2/2 containers
kubectl get pod format-adapter -n ex-2-3

# 2. Raw metrics should be in plain text format
kubectl exec format-adapter -c app -n ex-2-3 -- cat /metrics/raw.txt
# Expected: requests=150 errors=3 latency_ms=42

# 3. Adapter should output JSON
sleep 12
kubectl logs format-adapter -c json-adapter -n ex-2-3
# Expected: lines containing JSON with keys like "requests", "errors", "latency_ms"

# 4. Adapter volume should be read-only
kubectl exec format-adapter -c json-adapter -n ex-2-3 -- sh -c 'echo x > /metrics/test.txt'
# Expected: read-only file system error
```

---

## Level 3: Debugging Broken Configurations

### Exercise 3.1

**Objective:** The setup creates a broken multi-container pod. Fix it so the pod reaches Running state and the main container's logs show the expected greeting message from the init container.

**Setup:**

```bash
kubectl create namespace ex-3-1

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
      echo "Greeting: $(cat /data/welcome.txt)"
      sleep 3600
    volumeMounts:
    - name: shared
      mountPath: /data
  volumes:
  - name: shared
    emptyDir: {}
EOF
```

**Task:**

Investigate why the main container is not showing the expected greeting. Fix the issue so that:

**Verification (after fix):**

```bash
# 1. Pod should be Running
kubectl get pod broken-init -n ex-3-1

# 2. Main container should show the greeting
kubectl logs broken-init -c app -n ex-3-1
# Expected: Greeting: Welcome aboard
```

---

### Exercise 3.2

**Objective:** The setup creates a broken multi-container pod using the ambassador pattern. Fix it so the main container successfully receives a response from the ambassador.

**Setup:**

```bash
kubectl create namespace ex-3-2

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
      echo "Ambassador: starting on port 7070..."
      while true; do
        echo -e "HTTP/1.1 200 OK\r\n\r\nproxied-response" | nc -l -p 7070 -w 1
      done
EOF
```

**Task:**

Investigate why the client container reports `CONNECTION_FAILED`. Fix the issue so that:

**Verification (after fix):**

```bash
# 1. Pod should be Running with 2/2 containers
kubectl get pod broken-ambassador -n ex-3-2

# 2. Client should show the proxied response
kubectl logs broken-ambassador -c client -n ex-3-2
# Expected: Client: got proxied-response
```

---

### Exercise 3.3

**Objective:** The setup creates a broken multi-container pod with a sidecar that is supposed to read the main container's output. Fix it so the sidecar successfully tails the main container's log file.

**Setup:**

```bash
kubectl create namespace ex-3-3

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
      # Archive: copy log content every 30 seconds
      while true; do
        cp /logs/output.log /logs/output.log.bak
        sleep 30
      done
    volumeMounts:
    - name: applog
      mountPath: /logs
      readOnly: true
  volumes:
  - name: applog
    emptyDir: {}
EOF
```

**Task:**

Investigate why the pod is not functioning correctly. One of the containers is failing. Fix the issue so that all three containers reach Running state and the log-reader successfully tails the app's output.

**Verification (after fix):**

```bash
# 1. Pod should be Running with 3/3 containers
kubectl get pod broken-sidecar -n ex-3-3

# 2. log-reader should be showing app output
sleep 10
kubectl logs broken-sidecar -c log-reader -n ex-3-3
# Expected: lines with timestamps and "app is running"

# 3. All containers should be Running (no restarts)
kubectl get pod broken-sidecar -n ex-3-3 -o jsonpath='{range .status.containerStatuses[*]}{.name}: restarts={.restartCount}{"\n"}{end}'
# Expected: all containers show restarts=0
```

---

## Level 4: Complex Real-World Scenarios

### Exercise 4.1

**Objective:** Build a complete log-shipping sidecar composition. The main container runs a web server, the sidecar tails the access logs and transforms each line by prepending a `[SHIPPED]` tag, simulating what a real log shipper would do before forwarding.

**Setup:**

```bash
kubectl create namespace ex-4-1
```

**Task:**

Create a pod named `log-shipper` in namespace `ex-4-1` with the following:

- An emptyDir volume named `nginx-logs`.
- A main container named `web` (image: `nginx:1.25`) that mounts `nginx-logs` at `/var/log/nginx`.
- A sidecar container named `shipper` (image: `busybox:1.36`) that:
  - Mounts `nginx-logs` at `/logs` with `readOnly: true`
  - Waits for `/logs/access.log` to exist
  - Tails the access log and prepends `[SHIPPED]` to each line before printing to stdout
  - Uses `tail -f` piped through `sed` or `awk` to add the prefix

**Verification:**

```bash
# 1. Pod should be Running with 2/2 containers
kubectl get pod log-shipper -n ex-4-1

# 2. Generate traffic
kubectl exec log-shipper -c web -n ex-4-1 -- curl -s http://localhost/ > /dev/null
kubectl exec log-shipper -c web -n ex-4-1 -- curl -s http://localhost/test > /dev/null
kubectl exec log-shipper -c web -n ex-4-1 -- curl -s http://localhost/ > /dev/null
sleep 3

# 3. Shipper should show tagged log lines
kubectl logs log-shipper -c shipper -n ex-4-1
# Expected: lines starting with [SHIPPED] followed by nginx access log entries

# 4. The web container's own logs should show nginx startup, not access logs
kubectl logs log-shipper -c web -n ex-4-1
# Expected: nginx startup messages (access logs go to the file, not stdout)

# 5. Volume should be read-only for the shipper
kubectl exec log-shipper -c shipper -n ex-4-1 -- sh -c 'echo x > /logs/test.txt'
# Expected: read-only file system error

# 6. Raw access log should exist
kubectl exec log-shipper -c web -n ex-4-1 -- cat /var/log/nginx/access.log
# Expected: raw nginx access log lines (no [SHIPPED] tag)

# 7. Verify container names
kubectl get pod log-shipper -n ex-4-1 -o jsonpath='{.spec.containers[*].name}'
# Expected: web shipper

# 8. Verify volume mount paths
kubectl get pod log-shipper -n ex-4-1 -o jsonpath='{.spec.containers[?(@.name=="shipper")].volumeMounts[0].mountPath}'
# Expected: /logs
```

---

### Exercise 4.2

**Objective:** Build an ambassador pattern where a main container connects to a local HTTP endpoint and an ambassador container serves file-backed responses.

**Setup:**

```bash
kubectl create namespace ex-4-2
```

**Task:**

Create a pod named `cache-proxy` in namespace `ex-4-2` with the following:

- An emptyDir volume named `cache-data`.
- An init container named `seed-cache` (image: `busybox:1.36`) that writes `{"status":"fresh","ttl":300}` to `/cache/response.json` in the shared volume, then exits.
- An ambassador container named `proxy` (image: `busybox:1.36`) that:
  - Mounts `cache-data` at `/cache` with `readOnly: true`
  - Listens on port 8080 and serves the content of `/cache/response.json` as an HTTP response
  - Loops so it can serve multiple requests
- A main container named `app` (image: `busybox:1.36`) that:
  - Mounts `cache-data` at `/cache` (read-write, though it does not write in this exercise)
  - Waits 5 seconds for the ambassador to start, then connects to `http://localhost:8080/` and prints the response
  - Then sleeps for 3600 seconds

**Verification:**

```bash
# 1. Pod should be Running with 2/2 containers
kubectl get pod cache-proxy -n ex-4-2

# 2. Init container should have completed
kubectl get pod cache-proxy -n ex-4-2 -o jsonpath='{.status.initContainerStatuses[0].state}'
# Expected: terminated/Completed

# 3. App should have received the cached response
kubectl logs cache-proxy -c app -n ex-4-2
# Expected: output containing {"status":"fresh","ttl":300}

# 4. Cache file should exist
kubectl exec cache-proxy -c app -n ex-4-2 -- cat /cache/response.json
# Expected: {"status":"fresh","ttl":300}

# 5. Ambassador should be serving on port 8080
kubectl exec cache-proxy -c app -n ex-4-2 -- wget -qO- http://localhost:8080/ 2>/dev/null
# Expected: {"status":"fresh","ttl":300}

# 6. Proxy volume should be read-only
kubectl exec cache-proxy -c proxy -n ex-4-2 -- sh -c 'echo x > /cache/test.txt'
# Expected: read-only file system error

# 7. Verify init container name
kubectl get pod cache-proxy -n ex-4-2 -o jsonpath='{.spec.initContainers[*].name}'
# Expected: seed-cache

# 8. Verify there are exactly 2 running containers and 1 init container
kubectl get pod cache-proxy -n ex-4-2 -o jsonpath='containers={.spec.containers[*].name} init={.spec.initContainers[*].name}'
# Expected: containers=proxy app init=seed-cache
```

---

### Exercise 4.3

**(Requires K8s 1.29+)**

**Objective:** Build a native sidecar version of a log-tailing pattern and verify the lifecycle differences compared to a classical sidecar.

**Setup:**

```bash
kubectl create namespace ex-4-3
```

**Task:**

Create a pod named `native-logger` in namespace `ex-4-3` with the following:

- An emptyDir volume named `app-logs`.
- A native sidecar (declared in `initContainers` with `restartPolicy: Always`) named `log-tailer` (image: `busybox:1.36`) that:
  - Mounts `app-logs` at `/logs` with `readOnly: true`
  - Waits for `/logs/app.log` to exist, then runs `tail -f /logs/app.log`
- A main container named `app` (image: `busybox:1.36`) that:
  - Mounts `app-logs` at `/app-logs`
  - Writes `app event at <date>` to `/app-logs/app.log` every 3 seconds in an infinite loop

**Verification:**

```bash
# 1. Pod should be Running
kubectl get pod native-logger -n ex-4-3

# 2. The log-tailer should be in initContainers, not containers
kubectl get pod native-logger -n ex-4-3 -o jsonpath='{.spec.initContainers[*].name}'
# Expected: log-tailer

kubectl get pod native-logger -n ex-4-3 -o jsonpath='{.spec.containers[*].name}'
# Expected: app (only the main container)

# 3. The log-tailer should have restartPolicy: Always
kubectl get pod native-logger -n ex-4-3 -o jsonpath='{.spec.initContainers[0].restartPolicy}'
# Expected: Always

# 4. Log-tailer should be showing app events
sleep 10
kubectl logs native-logger -c log-tailer -n ex-4-3
# Expected: lines with "app event at <timestamp>"

# 5. App container logs should show its own output
kubectl logs native-logger -c app -n ex-4-3
# Expected: (may be empty or show shell output, depending on command)

# 6. Verify the native sidecar's volume is read-only
kubectl exec native-logger -c log-tailer -n ex-4-3 -- sh -c 'echo x > /logs/test.txt'
# Expected: read-only file system error

# 7. Init container status should show it as running (not terminated)
kubectl get pod native-logger -n ex-4-3 -o jsonpath='{.status.initContainerStatuses[0].state}'
# Expected: contains "running"

# 8. Both the init sidecar and the main container should be running simultaneously
kubectl get pod native-logger -n ex-4-3 -o jsonpath='init-state={.status.initContainerStatuses[0].state} container-state={.status.containerStatuses[0].state}'
# Expected: both show "running"
```

---

## Level 5: Advanced Debugging and Comprehensive Tasks

### Exercise 5.1

**Objective:** The setup creates a multi-container pod with multiple issues. Fix all problems so that the pod reaches Running state and functions as intended: the init container seeds a config file, the main container reads it, and the sidecar monitors the main container's output.

**Setup:**

```bash
kubectl create namespace ex-5-1

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
  - name: app
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

**Task:**

The pod above fails to be created. Investigate and fix all issues so that:

**Verification (after fix):**

```bash
# 1. Pod should be Running with 2/2 containers
kubectl get pod broken-multi -n ex-5-1

# 2. Init container should have completed
kubectl get pod broken-multi -n ex-5-1 -o jsonpath='{.status.initContainerStatuses[0].state}'
# Expected: terminated/Completed

# 3. App should show the config
kubectl logs broken-multi -c app -n ex-5-1
# Expected first line: Config: db_host=postgres.svc

# 4. The monitoring sidecar should show activity log entries
sleep 15
kubectl logs broken-multi -c monitor -n ex-5-1
# Expected: lines with timestamps and "processing"

# 5. The app should be writing to the output volume
kubectl exec broken-multi -c app -n ex-5-1 -- cat /output/activity.log
# Expected: multiple lines with timestamps

# 6. The monitor's volume should be read-only
kubectl exec broken-multi -c monitor -n ex-5-1 -- sh -c 'echo x > /watch/test.txt'
# Expected: read-only file system error

# 7. Config volume should be read-only for app
kubectl exec broken-multi -c app -n ex-5-1 -- sh -c 'echo x > /config/test.txt'
# Expected: read-only file system error

# 8. All containers should have unique names
kubectl get pod broken-multi -n ex-5-1 -o jsonpath='{.spec.containers[*].name}'
# Expected: two different names (e.g., "app monitor")

# 9. Verify the init container name
kubectl get pod broken-multi -n ex-5-1 -o jsonpath='{.spec.initContainers[*].name}'
# Expected: config-seed

# 10. No container should be crash-looping
kubectl get pod broken-multi -n ex-5-1 -o jsonpath='{range .status.containerStatuses[*]}{.name}: restarts={.restartCount}{"\n"}{end}'
# Expected: all show restarts=0
```

---

### Exercise 5.2

**(Requires K8s 1.29+)**

**Objective:** The setup creates a pod that attempts to use a native sidecar, but the configuration is wrong. Fix the issues so the native sidecar starts before the main container, runs alongside it, and correctly tails the main container's output.

**Setup:**

```bash
kubectl create namespace ex-5-2

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
  containers:
  - name: web-monitor
    image: busybox:1.36
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

**Task:**

The pod above is intended to have `web-monitor` function as a native sidecar that starts before the `web` container and continues running alongside it. Currently, `web-monitor` is a classical sidecar in the `containers` array. Fix the configuration so that `web-monitor` is a proper native sidecar. After fixing:

**Verification (after fix):**

```bash
# 1. Pod should be Running
kubectl get pod broken-native -n ex-5-2

# 2. web-monitor should be in initContainers with restartPolicy: Always
kubectl get pod broken-native -n ex-5-2 -o jsonpath='{.spec.initContainers[*].name}'
# Expected: should include both "setup" and "web-monitor"

kubectl get pod broken-native -n ex-5-2 -o jsonpath='{.spec.initContainers[?(@.name=="web-monitor")].restartPolicy}'
# Expected: Always

# 3. web should be the only regular container
kubectl get pod broken-native -n ex-5-2 -o jsonpath='{.spec.containers[*].name}'
# Expected: web

# 4. setup init container should have completed
kubectl get pod broken-native -n ex-5-2 -o jsonpath='{.status.initContainerStatuses[?(@.name=="setup")].state}'
# Expected: terminated/Completed

# 5. web-monitor should be running (not terminated)
kubectl get pod broken-native -n ex-5-2 -o jsonpath='{.status.initContainerStatuses[?(@.name=="web-monitor")].state}'
# Expected: running

# 6. web container should show its startup config
kubectl logs broken-native -c web -n ex-5-2
# Expected first line: Web started with: environment=production

# 7. web-monitor should show web log entries
sleep 10
kubectl logs broken-native -c web-monitor -n ex-5-2
# Expected: lines with timestamps and "request handled"

# 8. web-monitor volume should be read-only
kubectl exec broken-native -c web-monitor -n ex-5-2 -- sh -c 'echo x > /monitor/test.txt'
# Expected: read-only file system error

# 9. Verify the init containers are ordered: setup first, then web-monitor
kubectl get pod broken-native -n ex-5-2 -o jsonpath='{.spec.initContainers[0].name}'
# Expected: setup

kubectl get pod broken-native -n ex-5-2 -o jsonpath='{.spec.initContainers[1].name}'
# Expected: web-monitor

# 10. No containers should be crash-looping
kubectl get pod broken-native -n ex-5-2 -o jsonpath='{range .status.containerStatuses[*]}{.name}: restarts={.restartCount}{"\n"}{end}'
# Expected: all show restarts=0
```

---

### Exercise 5.3

**Objective:** Build a comprehensive multi-container pod that represents a realistic observability composition for a web application. The pod should include an init container for setup, a main web server, a log-forwarding native sidecar, and a metrics-adapter sidecar.

**Setup:**

```bash
kubectl create namespace ex-5-3
```

**(Requires K8s 1.29+)**

**Task:**

Create a pod named `obs-stack` in namespace `ex-5-3` with the following:

- **Volumes:**
  - `html` (emptyDir): serves as the web root for nginx
  - `nginx-logs` (emptyDir): holds nginx access and error logs
  - `metrics` (emptyDir): holds raw metrics output from nginx stub_status

- **Init container** named `html-seed` (image: `busybox:1.36`):
  - Mounts `html` at `/seed`
  - Writes `<html><body><h1>Built at TIMESTAMP</h1></body></html>` (where TIMESTAMP is the output of `date`) to `/seed/index.html`
  - Exits after writing

- **Native sidecar** named `log-forwarder` (declared in `initContainers` with `restartPolicy: Always`, image: `busybox:1.36`):
  - Mounts `nginx-logs` at `/logs` with `readOnly: true`
  - Waits for `/logs/access.log` to exist
  - Runs `tail -f /logs/access.log` and pipes each line through `sed 's/^/[FWD] /'` to prepend a forwarding tag
  - Declared after `html-seed` in the initContainers array so it starts after seeding completes

- **Native sidecar** named `metrics-adapter` (declared in `initContainers` with `restartPolicy: Always`, image: `busybox:1.36`):
  - Mounts `metrics` at `/metrics` with `readOnly: true`
  - Reads `/metrics/stub-status.txt` every 5 seconds and outputs a JSON-formatted version to stdout
  - Declared after `log-forwarder` in the initContainers array

- **Main container** named `web` (image: `nginx:1.25`):
  - Mounts `html` at `/usr/share/nginx/html` with `readOnly: true`
  - Mounts `nginx-logs` at `/var/log/nginx`
  - Mounts `metrics` at `/metrics`
  - Runs a background loop that writes simulated stub_status data (`Active connections: N\nserver accepts handled requests\n 100 100 200\nReading: 0 Writing: 1 Waiting: 0`) to `/metrics/stub-status.txt` every 5 seconds (use a custom command that starts nginx and runs the loop)

**Verification:**

```bash
# 1. Pod should be Running
kubectl get pod obs-stack -n ex-5-3

# 2. Init container html-seed should have completed
kubectl get pod obs-stack -n ex-5-3 -o jsonpath='{.status.initContainerStatuses[?(@.name=="html-seed")].state}'
# Expected: terminated/Completed

# 3. Native sidecars should be running
kubectl get pod obs-stack -n ex-5-3 -o jsonpath='{.status.initContainerStatuses[?(@.name=="log-forwarder")].state}'
# Expected: running

kubectl get pod obs-stack -n ex-5-3 -o jsonpath='{.status.initContainerStatuses[?(@.name=="metrics-adapter")].state}'
# Expected: running

# 4. index.html should contain the build timestamp
kubectl exec obs-stack -c web -n ex-5-3 -- cat /usr/share/nginx/html/index.html
# Expected: HTML with "Built at <timestamp>"

# 5. Generate traffic
kubectl exec obs-stack -c web -n ex-5-3 -- curl -s http://localhost/ > /dev/null
kubectl exec obs-stack -c web -n ex-5-3 -- curl -s http://localhost/ > /dev/null
kubectl exec obs-stack -c web -n ex-5-3 -- curl -s http://localhost/ > /dev/null
sleep 5

# 6. Log forwarder should show tagged access logs
kubectl logs obs-stack -c log-forwarder -n ex-5-3
# Expected: lines starting with [FWD] followed by nginx access log entries

# 7. Metrics adapter should show JSON output
kubectl logs obs-stack -c metrics-adapter -n ex-5-3
# Expected: JSON-formatted metrics data

# 8. Verify all three initContainers are declared in order
kubectl get pod obs-stack -n ex-5-3 -o jsonpath='{.spec.initContainers[*].name}'
# Expected: html-seed log-forwarder metrics-adapter

# 9. Verify native sidecars have restartPolicy: Always
kubectl get pod obs-stack -n ex-5-3 -o jsonpath='{.spec.initContainers[?(@.name=="log-forwarder")].restartPolicy}'
# Expected: Always
kubectl get pod obs-stack -n ex-5-3 -o jsonpath='{.spec.initContainers[?(@.name=="metrics-adapter")].restartPolicy}'
# Expected: Always

# 10. html-seed should NOT have restartPolicy Always (it is a normal init)
kubectl get pod obs-stack -n ex-5-3 -o jsonpath='{.spec.initContainers[?(@.name=="html-seed")].restartPolicy}'
# Expected: (empty, no restartPolicy)

# 11. web should be the only regular container
kubectl get pod obs-stack -n ex-5-3 -o jsonpath='{.spec.containers[*].name}'
# Expected: web

# 12. Log forwarder volume should be read-only
kubectl exec obs-stack -c log-forwarder -n ex-5-3 -- sh -c 'echo x > /logs/test.txt'
# Expected: read-only file system error
```

---

## Cleanup

Remove individual exercise namespaces:

```bash
kubectl delete namespace ex-1-1
kubectl delete namespace ex-1-2
# ... etc
```

Or remove all at once:

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3; do
  kubectl delete namespace "$ns" --ignore-not-found
done
```

---

## Key Takeaways

**Pattern Selection Decision Framework.** The most important skill is not building multi-container pods but knowing *when* to build one. Shared lifecycle, shared filesystem, and tight coupling argue for a multi-container pod. Independent scaling, different lifecycles, and loose coupling argue for separate pods. Always ask "should this be a sidecar or a separate pod?" before reaching for a multi-container design.

**Classical vs Native Sidecars.** Classical sidecars (regular containers in the `containers` array) have no startup or shutdown ordering and prevent Job completion. Native sidecars (init containers with `restartPolicy: Always`) start before main containers, shut down after them, and allow Jobs to complete. Use native sidecars when ordering matters or when the pod runs in a Job context.

**emptyDir is the Shared-Medium Workhorse.** Nearly every multi-container pattern relies on emptyDir for inter-container communication. Understanding that different mountPaths in different containers still point to the same underlying volume, that readOnly mounts prevent writes, and that `medium: Memory` trades durability for speed is essential.

**Debugging Toolkit.** When a multi-container pod misbehaves, the diagnostic sequence is: check pod status for which phase is stuck (init or running), describe the pod for events, check per-container logs with `-c`, exec into specific containers to inspect shared volumes and network connectivity, and read the full YAML for container state details. The `-c` flag is your primary tool for isolating which container is the problem.

**Patterns Name Intent.** Sidecar, ambassador, and adapter are mechanically similar (two containers sharing volumes and/or network). The pattern names communicate *why* the second container exists: augmenting (sidecar), proxying (ambassador), or transforming (adapter). Naming the pattern correctly helps other engineers understand your design.
