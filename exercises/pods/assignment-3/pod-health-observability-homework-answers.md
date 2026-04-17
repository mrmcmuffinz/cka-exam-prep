# Pod Health and Observability: Homework Answers

## Exercise 1.1 Solution

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-live
  namespace: ex-1-1
spec:
  containers:
  - name: web
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 3
      periodSeconds: 10
```

Apply:

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: web-live
  namespace: ex-1-1
spec:
  containers:
  - name: web
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 3
      periodSeconds: 10
EOF
```

This is a straightforward httpGet liveness probe. Nginx serves a 200 OK response on `/` by default, so the probe succeeds every time. The initialDelaySeconds of 3 gives nginx a moment to start before the first check.

---

## Exercise 1.2 Solution

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: ready-file
  namespace: ex-1-2
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh", "-c", "sleep 20 && touch /tmp/ready && sleep 3600"]
    readinessProbe:
      exec:
        command:
        - test
        - -f
        - /tmp/ready
      periodSeconds: 3
      failureThreshold: 1
EOF
```

The key observation is that the pod transitions from `0/1` to `1/1` after about 20 seconds. During that time, readiness probe failures appear in Events as "Unhealthy" with type "Readiness," but the container is never restarted. The restartCount stays at 0 throughout. This demonstrates the fundamental difference between readiness and liveness: readiness failures affect the Ready condition but do not trigger container restarts.

---

## Exercise 1.3 Solution

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: graceful-stop
  namespace: ex-1-3
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh", "-c", "echo 'running' && sleep 3600"]
    lifecycle:
      preStop:
        exec:
          command:
          - /bin/sh
          - -c
          - "echo 'preStop hook executing' >> /proc/1/fd/1"
EOF
```

The trick here is writing to `/proc/1/fd/1`, which is the stdout file descriptor of PID 1 (the container's main process). This makes the preStop output appear in `kubectl logs`. Writing to a regular file would work too, but since the pod is being deleted, you would not be able to read it after termination. The `/proc/1/fd/1` approach ensures the message is captured in the container log before the pod disappears.

When you run `kubectl delete pod graceful-stop -n ex-1-3 --wait=false` and immediately check logs, you should see "preStop hook executing" in the output.

---

## Exercise 2.1 Solution

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: slow-start
  namespace: ex-2-1
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh", "-c", "sleep 25 && echo healthy > /tmp/health && while true; do sleep 5; done"]
    startupProbe:
      exec:
        command:
        - cat
        - /tmp/health
      periodSeconds: 2
      failureThreshold: 20
      timeoutSeconds: 1
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/health
      periodSeconds: 10
      failureThreshold: 3
      timeoutSeconds: 1
EOF
```

The startup probe gives the container a 40-second window (2 * 20) to create `/tmp/health`. During those 40 seconds, the liveness probe is completely inactive. After 25 seconds, `sleep 25` completes, the file is created, the startup probe succeeds on its next check, and control transfers to the liveness probe. Without the startup probe, the liveness probe would start checking immediately and kill the container before initialization finishes.

---

## Exercise 2.2 Solution

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: dual-probe
  namespace: ex-2-2
spec:
  containers:
  - name: web
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
    command: ["/bin/sh", "-c", "(sleep 10 && touch /tmp/ready) & nginx -g 'daemon off;'"]
    livenessProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 15
      timeoutSeconds: 3
      failureThreshold: 2
    readinessProbe:
      exec:
        command:
        - test
        - -f
        - /tmp/ready
      periodSeconds: 3
      timeoutSeconds: 1
      successThreshold: 2
      failureThreshold: 1
EOF
```

This exercise combines two different handler types (httpGet for liveness, exec for readiness) with non-default tuning values. The liveness probe checks nginx directly via HTTP, while the readiness probe checks for a file that appears after a 10-second delay. The successThreshold of 2 on the readiness probe means the file must exist for two consecutive checks (6 seconds apart at periodSeconds 3) before the pod is marked Ready. This prevents flapping if the file briefly appears and disappears.

---

## Exercise 2.3 Solution

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: graceful-shutdown
  namespace: ex-2-3
spec:
  terminationGracePeriodSeconds: 30
  containers:
  - name: web
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 10
    lifecycle:
      preStop:
        exec:
          command: ["/bin/sh", "-c", "sleep 10 && echo done"]
EOF
```

When you run `time kubectl delete pod graceful-shutdown -n ex-2-3`, the deletion should take at least 10 seconds because the preStop hook sleeps for 10 seconds before the container receives SIGTERM. The terminationGracePeriodSeconds of 30 gives plenty of room: 10 seconds for the hook plus 20 seconds for nginx to handle SIGTERM and shut down.

---

## Exercise 3.1 Solution

**Diagnosis:**

```bash
kubectl describe pod broken-web -n ex-3-1 | tail -15
```

The Events show "Unhealthy" events with "Liveness probe failed: HTTP probe failed with statuscode: 404". The liveness probe hits `/healthz` on port 80, but nginx does not serve a `/healthz` endpoint by default. It returns a 404, which is outside the 200-399 success range, so the probe fails.

After 3 consecutive failures (failureThreshold: 3), Kubernetes kills and restarts the container. The restartCount climbs steadily.

**What was wrong:** The liveness probe path is `/healthz`, but nginx only serves `/` (and `/index.html`) by default. The probe gets a 404 every time.

**Fix:** Change the probe path from `/healthz` to `/`:

```bash
kubectl delete pod broken-web -n ex-3-1
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: broken-web
  namespace: ex-3-1
spec:
  containers:
  - name: web
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 2
      periodSeconds: 5
      failureThreshold: 3
EOF
```

---

## Exercise 3.2 Solution

**Diagnosis:**

```bash
kubectl get pod slow-boot -n ex-3-2
# RESTARTS keeps incrementing
kubectl describe pod slow-boot -n ex-3-2 | tail -15
# Events: Unhealthy - Liveness probe failed: cat: can't open '/tmp/health': No such file or directory
# Events: Killing - Container app failed liveness probe, will be restarted
kubectl logs slow-boot -n ex-3-2 --previous
# Shows only: "Initializing..."
# The container never reaches "Ready" because it is killed after ~20 seconds
```

**What was wrong:** The container takes 30 seconds to create `/tmp/health`, but the liveness probe starts at 5 seconds (initialDelaySeconds) and fails 3 times by approximately second 20 (5 + 3 * 5). The container is killed before initialization completes. This is a classic case where a startup probe is needed.

**Fix:** Add a startup probe to protect the container during initialization. The startup probe gives the container enough time to finish its 30-second startup before the liveness probe takes over:

```bash
kubectl delete pod slow-boot -n ex-3-2
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: slow-boot
  namespace: ex-3-2
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh", "-c"]
    args:
    - |
      echo "Initializing..."
      sleep 30
      echo "Ready"
      while true; do
        echo "ok" > /tmp/health
        sleep 5
      done
    startupProbe:
      exec:
        command:
        - cat
        - /tmp/health
      periodSeconds: 5
      failureThreshold: 12
      timeoutSeconds: 1
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/health
      initialDelaySeconds: 0
      periodSeconds: 5
      failureThreshold: 3
EOF
```

The startup probe gives a 60-second window (5 * 12). During that window, the liveness probe is disabled. After the container creates `/tmp/health` at 30 seconds, the startup probe succeeds, and the liveness probe takes over.

An alternative fix would be to increase initialDelaySeconds on the liveness probe to 35 or more, but this is less clean because it couples the liveness probe tuning to startup behavior.

---

## Exercise 3.3 Solution

**Diagnosis:**

```bash
kubectl delete pod hook-pod -n ex-3-3 --wait=false
sleep 5
kubectl logs hook-pod -n ex-3-3
# Shows: "cleanup starting" but NOT "cleanup done"
```

The preStop hook sleeps for 15 seconds, but terminationGracePeriodSeconds is only 3. After 3 seconds, Kubernetes sends SIGKILL, killing the container in the middle of the cleanup. The "cleanup done" message never appears.

**What was wrong:** terminationGracePeriodSeconds (3 seconds) is shorter than the preStop hook needs (15 seconds). The container is forcefully killed before cleanup completes.

**Fix:** Increase terminationGracePeriodSeconds to at least 20 seconds (15 for the hook plus margin):

```bash
kubectl delete pod hook-pod -n ex-3-3 --ignore-not-found
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: hook-pod
  namespace: ex-3-3
spec:
  terminationGracePeriodSeconds: 25
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh", "-c", "echo started && sleep 3600"]
    lifecycle:
      preStop:
        exec:
          command:
          - /bin/sh
          - -c
          - "echo 'cleanup starting' >> /proc/1/fd/1 && sleep 15 && echo 'cleanup done' >> /proc/1/fd/1"
EOF
```

Now when you delete the pod, the preStop hook has 25 seconds to complete its 15-second cleanup before SIGKILL fires.

---

## Exercise 4.1 Solution

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: prod-web
  namespace: ex-4-1
spec:
  containers:
  - name: web
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
    command: ["/bin/sh", "-c", "sleep 15 && touch /tmp/ready && nginx -g 'daemon off;'"]
    startupProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 3
      failureThreshold: 15
      timeoutSeconds: 2
    livenessProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 10
      failureThreshold: 3
      timeoutSeconds: 2
    readinessProbe:
      exec:
        command:
        - test
        - -f
        - /tmp/ready
      periodSeconds: 5
      failureThreshold: 2
      timeoutSeconds: 2
EOF
```

The probe tuning math:
- Startup window: 3 * 15 = 45 seconds (container needs 15, so 3x headroom)
- Liveness detection: 10 * 3 = 30 seconds after startup (specified as detecting within 30 seconds)
- Readiness detection: 5 * 2 = 10 seconds (specified as detecting within 10 seconds)

The startup probe fires every 3 seconds and tolerates 15 consecutive failures, giving a total window of 45 seconds. The container starts nginx at 15 seconds, the startup probe succeeds on the next check, and control passes to liveness and readiness probes. The readiness probe immediately finds `/tmp/ready` (created before nginx started), so the pod becomes Ready shortly after startup completes.

---

## Exercise 4.2 Solution

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: drain-pod
  namespace: ex-4-2
spec:
  terminationGracePeriodSeconds: 35
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh", "-c", "echo 'app started' && while true; do sleep 1; done"]
    livenessProbe:
      exec:
        command:
        - echo
        - ok
      periodSeconds: 10
    lifecycle:
      preStop:
        exec:
          command:
          - /bin/sh
          - -c
          - "echo 'draining...' >> /proc/1/fd/1 && sleep 20 && echo 'drain complete' >> /proc/1/fd/1"
EOF
```

The terminationGracePeriodSeconds of 35 gives the preStop hook 20 seconds for the drain plus 15 seconds of margin for SIGTERM handling. When you run `time kubectl delete pod drain-pod -n ex-4-2`, the command takes about 20 to 25 seconds. If you check logs during deletion (from another terminal: `kubectl logs drain-pod -n ex-4-2`), you should see "draining..." and eventually "drain complete" before the pod disappears.

---

## Exercise 4.3 Solution

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: multi-health
  namespace: ex-4-3
spec:
  containers:
  - name: web
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 10
      failureThreshold: 3
    readinessProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 5
      failureThreshold: 2
  - name: sidecar
    image: busybox:1.36
    command: ["/bin/sh", "-c", "sleep 15 && touch /tmp/sidecar-ready && while true; do sleep 5; done"]
    readinessProbe:
      exec:
        command:
        - test
        - -f
        - /tmp/sidecar-ready
      periodSeconds: 3
      failureThreshold: 1
    livenessProbe:
      exec:
        command:
        - test
        - -f
        - /tmp/sidecar-ready
      periodSeconds: 10
      failureThreshold: 3
EOF
```

The key observation is the `1/2` to `2/2` transition. The pod's overall Ready condition is True only when ALL containers are ready. The web container becomes ready almost immediately (nginx starts fast and serves HTTP), but the sidecar does not create `/tmp/sidecar-ready` until after 15 seconds. During that window, the pod shows `1/2` Ready.

Use `kubectl get pod multi-health -n ex-4-3 -o jsonpath='{range .status.containerStatuses[*]}{.name}: ready={.ready}{"\n"}{end}'` to inspect each container independently. Use `kubectl logs multi-health -n ex-4-3 -c sidecar` to check the sidecar specifically.

---

## Exercise 5.1 Solution

**Diagnosis:**

```bash
kubectl get pod flaky-app -n ex-5-1
# Either CrashLoopBackOff or Running with high RESTARTS

kubectl describe pod flaky-app -n ex-5-1 | tail -20
# Events: Unhealthy - Startup probe failed: cat: can't open '/tmp/health': No such file or directory
# Events: Killing
```

Three issues:

**Issue 1: Startup probe window too short.** The startup probe has periodSeconds 2 and failureThreshold 5, giving a 10-second window. The container takes 20 seconds to create `/tmp/health`. The startup probe exhausts its failures at 10 seconds and kills the container before it finishes initializing. Fix: increase failureThreshold to at least 15 (2 * 15 = 30 seconds, enough for the 20-second startup).

**Issue 2: Liveness probe failureThreshold of 1.** With failureThreshold 1, a single failed probe (any transient issue, slow response, momentary load spike) kills the container immediately. This makes the pod flaky in steady state. Fix: increase failureThreshold to at least 3.

**Issue 3: Readiness probe checks wrong file.** The readiness probe checks `/tmp/healthy`, but the container creates `/tmp/health`. The readiness probe will never succeed, so the pod will never be Ready even if the other issues are fixed. Fix: change the readiness probe command to `cat /tmp/health`.

**Fix:**

```bash
kubectl delete pod flaky-app -n ex-5-1
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: flaky-app
  namespace: ex-5-1
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh", "-c"]
    args:
    - |
      echo "Starting app..."
      sleep 20
      echo "App ready"
      while true; do
        echo "ok" > /tmp/health
        sleep 5
      done
    startupProbe:
      exec:
        command:
        - cat
        - /tmp/health
      periodSeconds: 2
      failureThreshold: 15
      timeoutSeconds: 1
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/health
      periodSeconds: 5
      failureThreshold: 3
      timeoutSeconds: 1
    readinessProbe:
      exec:
        command:
        - cat
        - /tmp/health
      periodSeconds: 3
      failureThreshold: 1
EOF
```

---

## Exercise 5.2 Solution

**Diagnosis:**

```bash
kubectl get pod web-complex -n ex-5-2
kubectl describe pod web-complex -n ex-5-2 | tail -20
```

Three issues:

**Issue 1: Liveness probe timeoutSeconds (8) exceeds periodSeconds (5).** When the timeout is longer than the period, the next probe fires before the current one has timed out. This can lead to overlapping probes and excessive connection usage. More practically, it means probe results can become unpredictable. Fix: reduce timeoutSeconds to a value less than periodSeconds (e.g., 2).

**Issue 2: terminationGracePeriodSeconds (5) is shorter than the preStop hook (sleep 20).** When the pod is deleted, the preStop hook starts sleeping for 20 seconds, but the grace period expires after 5 seconds. Kubernetes sends SIGKILL at 5 seconds, killing the container mid-cleanup. Fix: increase terminationGracePeriodSeconds to at least 30 (20 for the hook plus margin).

**Issue 3: The liveness probe configuration is overly aggressive together.** With periodSeconds 5, timeoutSeconds 8, and failureThreshold 2, even after fixing the timeout, the liveness probe will kill the container after just 10 seconds (2 * 5) of failure. Depending on the application, this may be fine, but combined with the timeout issue, the pod can be unstable. The primary fix is ensuring timeoutSeconds < periodSeconds.

**Fix:**

```bash
kubectl delete pod web-complex -n ex-5-2
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: web-complex
  namespace: ex-5-2
spec:
  terminationGracePeriodSeconds: 30
  containers:
  - name: web
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
    command: ["/bin/sh", "-c"]
    args:
    - |
      sleep 10
      touch /tmp/ready
      nginx -g 'daemon off;'
    startupProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 3
      failureThreshold: 10
    livenessProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 5
      timeoutSeconds: 2
      failureThreshold: 2
    readinessProbe:
      exec:
        command:
        - test
        - -f
        - /tmp/ready
      periodSeconds: 3
      failureThreshold: 1
    lifecycle:
      preStop:
        exec:
          command:
          - /bin/sh
          - -c
          - "sleep 20 && echo 'shutdown complete'"
EOF
```

---

## Exercise 5.3 Solution

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: prod-app
  namespace: ex-5-3
spec:
  terminationGracePeriodSeconds: 30
  containers:
  - name: app
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
    command: ["/bin/sh", "-c", "sleep 25 && touch /tmp/ready && nginx -g 'daemon off;'"]
    startupProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 5
      failureThreshold: 12
      timeoutSeconds: 2
    livenessProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 10
      failureThreshold: 2
      timeoutSeconds: 2
    readinessProbe:
      exec:
        command:
        - test
        - -f
        - /tmp/ready
      periodSeconds: 5
      failureThreshold: 2
      timeoutSeconds: 2
    lifecycle:
      postStart:
        exec:
          command: ["/bin/sh", "-c", "echo 'Container started at $(date)' > /tmp/lifecycle.log"]
      preStop:
        exec:
          command: ["/bin/sh", "-c", "echo 'shutting down' >> /proc/1/fd/1 && sleep 15"]
EOF
```

Tuning breakdown:

- **Startup window:** 5 * 12 = 60 seconds. Container takes 25 seconds, so 2.4x headroom.
- **Liveness detection:** 10 * 2 = 20 seconds. Specified as "within 20 seconds."
- **Readiness detection:** 5 * 2 = 10 seconds. Specified as "within 10 seconds."
- **All timeouts:** 2 seconds as required.
- **terminationGracePeriodSeconds:** 30 seconds (15 for preStop sleep + 15 margin).
- **postStart:** Writes to `/tmp/lifecycle.log` using exec, which runs as soon as the container starts. Note that postStart runs before the startup probe begins, so it executes during the sleep 25 initialization period. The file is created by the shell before the main command finishes, which is fine because `/tmp` is already available.

---

## Common Mistakes

### Using liveness when readiness is needed (or vice versa)

Liveness probes restart the container. Readiness probes remove it from traffic without restarting. If your container is temporarily unavailable (loading data, waiting for a dependency), use a readiness probe. If you use a liveness probe for temporary unavailability, Kubernetes will kill and restart the container, which may make the problem worse (the container has to reinitialize, which takes even longer).

### initialDelaySeconds too short

If the liveness probe starts checking before the container has finished initializing, the probe fails, and Kubernetes kills the container before it has a chance to start. The container restarts, initializes again, gets killed again, and enters CrashLoopBackOff. The fix is to use a startup probe (preferred) or increase initialDelaySeconds to be longer than the container's startup time.

### timeoutSeconds >= periodSeconds

When the timeout is as long as or longer than the period, the next probe fires before the current one has completed. This can cause overlapping probes, exhaust connection pools, and produce unpredictable behavior. Always set timeoutSeconds to a value lower than periodSeconds.

### failureThreshold of 1

A failureThreshold of 1 means any single probe failure triggers action (restart for liveness, unready for readiness). In practice, transient network issues, garbage collection pauses, or brief CPU spikes can cause a single probe to fail. A failureThreshold of at least 2 (preferably 3) for liveness probes prevents killing containers on transient issues.

### Forgetting that startup probe must succeed first

While the startup probe is running, liveness and readiness probes are completely disabled. If the startup probe never succeeds (failureThreshold exceeded), the container is killed. If the startup probe is misconfigured (wrong port, wrong path, window too short), neither the liveness nor readiness probe ever gets a chance to run.

### preStop hook with non-zero exit status

The preStop hook is always honored regardless of its exit status. However, a non-zero exit is logged in Events, which can be confusing during diagnosis. If your preStop hook exits with an error, the container still proceeds to SIGTERM and eventual SIGKILL.

### terminationGracePeriodSeconds shorter than preStop hook duration

The terminationGracePeriodSeconds countdown starts when the pod is marked for deletion, not when SIGTERM is sent. If the preStop hook takes 20 seconds and terminationGracePeriodSeconds is 15, the container is killed at 15 seconds, 5 seconds before the hook finishes. Always set the grace period to at least the preStop duration plus margin.

### Probe handler referencing wrong port or path

An httpGet probe hitting a path the container does not serve (e.g., `/healthz` on nginx, which only serves `/`) returns 404, which is a failure. A tcpSocket probe targeting a port the container does not listen on gets a connection refused error. Always verify that the probe handler matches what the container actually provides.

### Exec probe with unavailable command

If the exec probe command does not exist in the container image (e.g., using `curl` in a busybox image that does not have curl), the probe fails every time with "executable not found." Use tools that are known to exist in the container: `cat`, `test`, `echo`, `wget` for busybox/alpine; `curl` only in images that include it.

### Confusing restartPolicy with probe-induced restarts

Probes cause container restarts within the pod. The pod itself stays on the same node with the same IP. The restartPolicy (Always, OnFailure, Never) governs whether the kubelet restarts a container that exits on its own. With restartPolicy Always (the default), a container killed by a failed liveness probe is always restarted. With restartPolicy Never, a container killed by a liveness probe is NOT restarted, and the pod transitions to Failed. This is rarely what you want for long-running applications.

---

## Verification Commands Cheat Sheet

### Probe configuration inspection

```bash
# Liveness probe summary
kubectl describe pod <n> -n <ns> | grep -A 10 "Liveness:"

# Readiness probe summary
kubectl describe pod <n> -n <ns> | grep -A 10 "Readiness:"

# Startup probe summary
kubectl describe pod <n> -n <ns> | grep -A 10 "Startup:"

# Specific probe fields via jsonpath
kubectl get pod <n> -n <ns> -o jsonpath='{.spec.containers[0].livenessProbe.periodSeconds}'
kubectl get pod <n> -n <ns> -o jsonpath='{.spec.containers[0].readinessProbe.failureThreshold}'
kubectl get pod <n> -n <ns> -o jsonpath='{.spec.containers[0].startupProbe.timeoutSeconds}'
```

### Pod conditions

```bash
# All conditions
kubectl get pod <n> -n <ns> -o jsonpath='{range .status.conditions[*]}{.type}={.status}{"\n"}{end}'

# Specific condition
kubectl get pod <n> -n <ns> -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
```

### Container statuses

```bash
# restartCount
kubectl get pod <n> -n <ns> -o jsonpath='{.status.containerStatuses[0].restartCount}'

# Current state
kubectl get pod <n> -n <ns> -o jsonpath='{.status.containerStatuses[0].state}'

# Last termination reason and exit code
kubectl get pod <n> -n <ns> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
kubectl get pod <n> -n <ns> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'

# Multi-container: all containers at once
kubectl get pod <n> -n <ns> -o jsonpath='{range .status.containerStatuses[*]}{.name}: ready={.ready}, restarts={.restartCount}{"\n"}{end}'
```

### Events

```bash
# Pod events (via describe)
kubectl describe pod <n> -n <ns> | tail -20

# Namespace events filtered by reason
kubectl get events -n <ns> --field-selector reason=Unhealthy
kubectl get events -n <ns> --field-selector reason=Killing
kubectl get events -n <ns> --field-selector reason=BackOff

# Events for a specific pod
kubectl get events -n <ns> --field-selector involvedObject.name=<n>
```

### Logs

```bash
kubectl logs <n> -n <ns>                          # Current container
kubectl logs <n> -n <ns> --previous                # Previous (crashed) container
kubectl logs <n> -n <ns> -c <container>            # Specific container
kubectl logs <n> -n <ns> --tail=20                 # Last 20 lines
kubectl logs <n> -n <ns> --since=2m                # Last 2 minutes
kubectl logs <n> -n <ns> --timestamps              # With timestamps
kubectl logs <n> -n <ns> --follow                  # Live tail
```

### Lifecycle and termination

```bash
# terminationGracePeriodSeconds
kubectl get pod <n> -n <ns> -o jsonpath='{.spec.terminationGracePeriodSeconds}'

# preStop hook configuration
kubectl get pod <n> -n <ns> -o jsonpath='{.spec.containers[0].lifecycle.preStop}'

# postStart hook configuration
kubectl get pod <n> -n <ns> -o jsonpath='{.spec.containers[0].lifecycle.postStart}'
```
