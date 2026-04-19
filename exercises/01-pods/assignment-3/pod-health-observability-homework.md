# Pod Health and Observability: Homework Exercises

## Introduction

This file contains 15 exercises covering Kubernetes pod health probes, lifecycle hooks, termination behavior, and diagnostic techniques. Work through the tutorial (`pod-health-observability-tutorial.md`) before attempting these exercises. The exercises are organized by difficulty level and build on each other progressively.

Each exercise uses its own namespace. Debugging exercises (Levels 3 and 5) provide broken YAML in the setup commands so you can focus on diagnosis rather than typing. Many exercises require observing behavior over time (probes fire on intervals, restart counts increment after actual restarts, grace periods take real seconds), so expect to wait 30 to 120 seconds during verification steps.

## Cluster Verification

Before starting, confirm your cluster is working:

```bash
kubectl cluster-info
kubectl get nodes
```

## Optional: Global Cleanup

If you have leftover resources from previous attempts:

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3; do
  kubectl delete namespace "$ns" --ignore-not-found
done
```

---

## Level 1: Basic Single-Concept Tasks

### Exercise 1.1

**Objective:** Create a pod with an HTTP liveness probe that verifies the web server is responding.

**Setup:**

```bash
kubectl create namespace ex-1-1
```

**Task:** Create a pod named `web-live` in namespace `ex-1-1` running `nginx:1.25-alpine` with a liveness probe that sends an HTTP GET request to path `/` on port 80. Use an initialDelaySeconds of 3 and a periodSeconds of 10.

**Verification (run after 30 seconds):**

```bash
# Pod should be Running and Ready
kubectl get pod web-live -n ex-1-1

# Liveness probe should show httpGet on port 80, path /
kubectl describe pod web-live -n ex-1-1 | grep -A 5 "Liveness:"

# restartCount should be 0 (probe is succeeding)
kubectl get pod web-live -n ex-1-1 -o jsonpath='{.status.containerStatuses[0].restartCount}'
# Expected: 0

# No Unhealthy events should be present
kubectl get events -n ex-1-1 --field-selector reason=Unhealthy
# Expected: No resources found
```

---

### Exercise 1.2

**Objective:** Create a pod with an exec readiness probe that gates the pod's Ready condition on the existence of a file.

**Setup:**

```bash
kubectl create namespace ex-1-2
```

**Task:** Create a pod named `ready-file` in namespace `ex-1-2` running `busybox:1.36` with command `["/bin/sh", "-c", "sleep 20 && touch /tmp/ready && sleep 3600"]`. Add a readiness probe using exec that runs `test -f /tmp/ready`. Set periodSeconds to 3 and failureThreshold to 1.

**Verification:**

```bash
# Immediately after creation (within 15 seconds): pod should be Running but NOT Ready
kubectl get pod ready-file -n ex-1-2
# Expected READY: 0/1

# After 30 seconds: pod should be Running and Ready
kubectl get pod ready-file -n ex-1-2
# Expected READY: 1/1

# restartCount should be 0 (readiness failures do not cause restarts)
kubectl get pod ready-file -n ex-1-2 -o jsonpath='{.status.containerStatuses[0].restartCount}'
# Expected: 0
```

---

### Exercise 1.3

**Objective:** Create a pod with a preStop lifecycle hook that logs a message before termination.

**Setup:**

```bash
kubectl create namespace ex-1-3
```

**Task:** Create a pod named `graceful-stop` in namespace `ex-1-3` running `busybox:1.36` with command `["/bin/sh", "-c", "echo 'running' && sleep 3600"]`. Add a preStop lifecycle hook with an exec handler that runs `/bin/sh -c "echo 'preStop hook executing' >> /proc/1/fd/1"`. This writes to the container's stdout so it appears in `kubectl logs`.

**Verification:**

```bash
# Pod should be Running and Ready
kubectl get pod graceful-stop -n ex-1-3

# Delete the pod (do not use --force) and immediately check logs
kubectl delete pod graceful-stop -n ex-1-3 --wait=false
sleep 3
kubectl logs graceful-stop -n ex-1-3
# Expected: logs should contain "preStop hook executing"

# Wait for full deletion
kubectl wait --for=delete pod/graceful-stop -n ex-1-3 --timeout=60s
```

---

## Level 2: Multi-Concept Tasks

### Exercise 2.1

**Objective:** Create a pod with a startup probe that protects a slow-starting container, handing off to a liveness probe once startup completes.

**Setup:**

```bash
kubectl create namespace ex-2-1
```

**Task:** Create a pod named `slow-start` in namespace `ex-2-1` running `busybox:1.36` with command `["/bin/sh", "-c", "sleep 25 && echo healthy > /tmp/health && while true; do sleep 5; done"]`. Configure:

- A startup probe using exec that runs `cat /tmp/health`. Set periodSeconds to 2, failureThreshold to 20, and timeoutSeconds to 1. This gives the container a 40-second startup window.
- A liveness probe using exec that runs `cat /tmp/health`. Set periodSeconds to 10, failureThreshold to 3, and timeoutSeconds to 1.

The startup probe should protect the container during the 25-second initialization. Once `/tmp/health` exists, the startup probe succeeds and the liveness probe takes over.

**Verification (wait 40 seconds after creation):**

```bash
# Pod should be Running and Ready
kubectl get pod slow-start -n ex-2-1

# restartCount should be 0
kubectl get pod slow-start -n ex-2-1 -o jsonpath='{.status.containerStatuses[0].restartCount}'
# Expected: 0

# Startup probe configuration
kubectl get pod slow-start -n ex-2-1 -o jsonpath='{.spec.containers[0].startupProbe.periodSeconds}'
# Expected: 2

kubectl get pod slow-start -n ex-2-1 -o jsonpath='{.spec.containers[0].startupProbe.failureThreshold}'
# Expected: 20

# Liveness probe configuration
kubectl get pod slow-start -n ex-2-1 -o jsonpath='{.spec.containers[0].livenessProbe.periodSeconds}'
# Expected: 10

# Events should show startup probe failures during the first 25 seconds, then no more Unhealthy events
kubectl describe pod slow-start -n ex-2-1 | tail -20
```

---

### Exercise 2.2

**Objective:** Create a pod with both an httpGet liveness probe and an exec readiness probe, each with non-default tuning.

**Setup:**

```bash
kubectl create namespace ex-2-2
```

**Task:** Create a pod named `dual-probe` in namespace `ex-2-2` running `nginx:1.25-alpine`. Add a custom command that creates a readiness file after a delay: `["/bin/sh", "-c", "(sleep 10 && touch /tmp/ready) & nginx -g 'daemon off;'"]`. Configure:

- An httpGet liveness probe on port 80, path `/`, with periodSeconds 15, timeoutSeconds 3, and failureThreshold 2.
- An exec readiness probe that runs `test -f /tmp/ready`, with periodSeconds 3, timeoutSeconds 1, successThreshold 2, and failureThreshold 1.

**Verification:**

```bash
# Within 10 seconds of creation: pod Running but NOT Ready
kubectl get pod dual-probe -n ex-2-2
# Expected READY: 0/1

# After 20 seconds: pod Running and Ready
kubectl get pod dual-probe -n ex-2-2
# Expected READY: 1/1

# Check liveness probe tuning
kubectl get pod dual-probe -n ex-2-2 -o jsonpath='{.spec.containers[0].livenessProbe.periodSeconds}'
# Expected: 15

kubectl get pod dual-probe -n ex-2-2 -o jsonpath='{.spec.containers[0].livenessProbe.timeoutSeconds}'
# Expected: 3

# Check readiness probe tuning
kubectl get pod dual-probe -n ex-2-2 -o jsonpath='{.spec.containers[0].readinessProbe.successThreshold}'
# Expected: 2

# restartCount should be 0
kubectl get pod dual-probe -n ex-2-2 -o jsonpath='{.status.containerStatuses[0].restartCount}'
# Expected: 0
```

---

### Exercise 2.3

**Objective:** Create a pod with a preStop hook and a terminationGracePeriodSeconds tuned to allow the hook to complete.

**Setup:**

```bash
kubectl create namespace ex-2-3
```

**Task:** Create a pod named `graceful-shutdown` in namespace `ex-2-3` running `nginx:1.25-alpine`. Configure:

- A preStop lifecycle hook with an exec handler that runs `/bin/sh -c "sleep 10 && echo done"`.
- Set terminationGracePeriodSeconds to 30 (enough time for the 10-second hook plus SIGTERM handling).
- An httpGet liveness probe on port 80, path `/`, with periodSeconds 10.

**Verification:**

```bash
# Pod should be Running and Ready
kubectl get pod graceful-shutdown -n ex-2-3

# Check terminationGracePeriodSeconds
kubectl get pod graceful-shutdown -n ex-2-3 -o jsonpath='{.spec.terminationGracePeriodSeconds}'
# Expected: 30

# Check preStop hook configuration
kubectl get pod graceful-shutdown -n ex-2-3 -o jsonpath='{.spec.containers[0].lifecycle.preStop.exec.command}'
# Expected: ["/bin/sh","-c","sleep 10 && echo done"]

# Delete the pod and time how long it takes (should take at least 10 seconds due to preStop)
time kubectl delete pod graceful-shutdown -n ex-2-3
# Expected: real time >= 10 seconds
```

---

## Level 3: Debugging Broken Configurations

### Exercise 3.1

**Setup:**

```bash
kubectl create namespace ex-3-1
cat <<'EOF' | kubectl apply -f -
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
        path: /healthz
        port: 80
      initialDelaySeconds: 2
      periodSeconds: 5
      failureThreshold: 3
EOF
```

**Objective:** The pod above should be Running and Ready with restartCount 0 after 60 seconds. Investigate why it is failing, fix the issue, and verify the fix.

**Verification (after fix, wait 30 seconds):**

```bash
kubectl get pod broken-web -n ex-3-1
# Expected: Running, 1/1 Ready, RESTARTS 0

kubectl get pod broken-web -n ex-3-1 -o jsonpath='{.status.containerStatuses[0].restartCount}'
# Expected: 0
```

---

### Exercise 3.2

**Setup:**

```bash
kubectl create namespace ex-3-2
cat <<'EOF' | kubectl apply -f -
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
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/health
      initialDelaySeconds: 5
      periodSeconds: 5
      failureThreshold: 3
EOF
```

**Objective:** The pod above should reach Running and Ready with restartCount 0 after 60 seconds. Investigate why it keeps restarting, fix the issue, and verify stability.

**Verification (after fix, wait 60 seconds):**

```bash
kubectl get pod slow-boot -n ex-3-2
# Expected: Running, 1/1 Ready, RESTARTS 0

kubectl get pod slow-boot -n ex-3-2 -o jsonpath='{.status.containerStatuses[0].restartCount}'
# Expected: 0
```

---

### Exercise 3.3

**Setup:**

```bash
kubectl create namespace ex-3-3
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: hook-pod
  namespace: ex-3-3
spec:
  terminationGracePeriodSeconds: 3
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

**Objective:** The pod above is configured so that when deleted, its preStop cleanup hook runs to completion. Delete the pod, observe the termination, and determine whether the cleanup finishes. If it does not, fix the configuration, recreate the pod, and verify that the full cleanup completes during termination.

**Verification (after fix):**

```bash
# Apply the fixed pod, wait for it to be Ready
kubectl get pod hook-pod -n ex-3-3
# Expected: Running, 1/1 Ready

# Delete and check logs during termination
kubectl delete pod hook-pod -n ex-3-3 --wait=false
sleep 18
kubectl logs hook-pod -n ex-3-3
# Expected: logs should contain both "cleanup starting" AND "cleanup done"
```

---

## Level 4: Complex Real-World Scenarios

### Exercise 4.1

**Objective:** Build a production-style web server pod with comprehensive health checking. The container runs nginx with a simulated 15-second startup delay. It needs:

- A startup probe that allows up to 45 seconds for initialization (httpGet on port 80, path `/`)
- A liveness probe that detects hangs within 30 seconds after startup (httpGet on port 80, path `/`, periodSeconds 10, failureThreshold 3)
- A readiness probe that detects unavailability within 10 seconds (exec checking for `/tmp/ready`, periodSeconds 5, failureThreshold 2)
- All probes should have timeoutSeconds of 2

**Setup:**

```bash
kubectl create namespace ex-4-1
```

**Task:** Create a pod named `prod-web` in namespace `ex-4-1` running `nginx:1.25-alpine` with command `["/bin/sh", "-c", "sleep 15 && touch /tmp/ready && nginx -g 'daemon off;'"]`. Configure all three probes as described above. The startup probe should use periodSeconds 3 and failureThreshold 15 to achieve the 45-second window.

**Verification (wait 30 seconds after creation):**

```bash
# Pod should be Running and Ready
kubectl get pod prod-web -n ex-4-1
# Expected: 1/1 Running

# Startup probe config
kubectl get pod prod-web -n ex-4-1 -o jsonpath='{.spec.containers[0].startupProbe.failureThreshold}'
# Expected: 15

kubectl get pod prod-web -n ex-4-1 -o jsonpath='{.spec.containers[0].startupProbe.periodSeconds}'
# Expected: 3

# Liveness probe config
kubectl get pod prod-web -n ex-4-1 -o jsonpath='{.spec.containers[0].livenessProbe.periodSeconds}'
# Expected: 10

kubectl get pod prod-web -n ex-4-1 -o jsonpath='{.spec.containers[0].livenessProbe.failureThreshold}'
# Expected: 3

# Readiness probe config
kubectl get pod prod-web -n ex-4-1 -o jsonpath='{.spec.containers[0].readinessProbe.periodSeconds}'
# Expected: 5

kubectl get pod prod-web -n ex-4-1 -o jsonpath='{.spec.containers[0].readinessProbe.failureThreshold}'
# Expected: 2

# All probe timeouts should be 2
kubectl get pod prod-web -n ex-4-1 -o jsonpath='{.spec.containers[0].startupProbe.timeoutSeconds}'
# Expected: 2

# restartCount should be 0
kubectl get pod prod-web -n ex-4-1 -o jsonpath='{.status.containerStatuses[0].restartCount}'
# Expected: 0

# All conditions should be True
kubectl get pod prod-web -n ex-4-1 -o jsonpath='{range .status.conditions[*]}{.type}={.status}{"\n"}{end}'
# Expected: all True
```

---

### Exercise 4.2

**Objective:** Build a pod with a preStop hook that performs graceful shutdown and a terminationGracePeriodSeconds long enough to accommodate it. The container simulates an application that needs 20 seconds to flush pending work before stopping.

**Setup:**

```bash
kubectl create namespace ex-4-2
```

**Task:** Create a pod named `drain-pod` in namespace `ex-4-2` running `busybox:1.36` with command `["/bin/sh", "-c", "echo 'app started' && while true; do sleep 1; done"]`. Configure:

- A preStop lifecycle hook with exec handler that runs: `/bin/sh -c "echo 'draining...' >> /proc/1/fd/1 && sleep 20 && echo 'drain complete' >> /proc/1/fd/1"`
- terminationGracePeriodSeconds of 35 (20 seconds for drain plus 15 seconds margin for SIGTERM handling)
- An exec liveness probe that runs `echo ok`, with periodSeconds 10

**Verification:**

```bash
# Pod should be Running and Ready
kubectl get pod drain-pod -n ex-4-2

# Check terminationGracePeriodSeconds
kubectl get pod drain-pod -n ex-4-2 -o jsonpath='{.spec.terminationGracePeriodSeconds}'
# Expected: 35

# Check preStop hook exists
kubectl get pod drain-pod -n ex-4-2 -o jsonpath='{.spec.containers[0].lifecycle.preStop.exec.command}'
# Should show the drain command

# Delete the pod, time the termination
time kubectl delete pod drain-pod -n ex-4-2
# Expected: takes at least 20 seconds (preStop sleep)

# During deletion (run in another terminal before the pod is fully gone):
# kubectl logs drain-pod -n ex-4-2
# Expected: should contain "draining..." and "drain complete"
```

---

### Exercise 4.3

**Objective:** Build a multi-container pod where each container has its own health configuration, and observe each container's health state independently.

**Setup:**

```bash
kubectl create namespace ex-4-3
```

**Task:** Create a pod named `multi-health` in namespace `ex-4-3` with two containers:

**Container 1: "web"**
- Image: `nginx:1.25-alpine`
- httpGet liveness probe on port 80, path `/`, periodSeconds 10, failureThreshold 3
- httpGet readiness probe on port 80, path `/`, periodSeconds 5, failureThreshold 2

**Container 2: "sidecar"**
- Image: `busybox:1.36`
- Command: `["/bin/sh", "-c", "sleep 15 && touch /tmp/sidecar-ready && while true; do sleep 5; done"]`
- exec readiness probe that runs `test -f /tmp/sidecar-ready`, periodSeconds 3, failureThreshold 1
- exec liveness probe that runs `test -f /tmp/sidecar-ready`, periodSeconds 10, failureThreshold 3

**Verification:**

```bash
# Immediately after creation (within 10 seconds): pod should show 1/2 Ready
# (web is ready, sidecar is not yet)
kubectl get pod multi-health -n ex-4-3
# Expected READY: 1/2

# After 20 seconds: pod should show 2/2 Ready
kubectl get pod multi-health -n ex-4-3
# Expected READY: 2/2

# Check each container's readiness independently
kubectl get pod multi-health -n ex-4-3 -o jsonpath='{range .status.containerStatuses[*]}{.name}: ready={.ready}{"\n"}{end}'
# Expected: web: ready=true, sidecar: ready=true

# Check each container's restartCount
kubectl get pod multi-health -n ex-4-3 -o jsonpath='{range .status.containerStatuses[*]}{.name}: restarts={.restartCount}{"\n"}{end}'
# Expected: web: restarts=0, sidecar: restarts=0

# Check logs for each container
kubectl logs multi-health -n ex-4-3 -c web --tail=5
kubectl logs multi-health -n ex-4-3 -c sidecar --tail=5

# Pod conditions: Ready should be True only after ALL containers are ready
kubectl get pod multi-health -n ex-4-3 -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Expected: True

kubectl get pod multi-health -n ex-4-3 -o jsonpath='{.status.conditions[?(@.type=="ContainersReady")].status}'
# Expected: True
```

---

## Level 5: Advanced Debugging and Comprehensive Tasks

### Exercise 5.1

**Setup:**

```bash
kubectl create namespace ex-5-1
cat <<'EOF' | kubectl apply -f -
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
      failureThreshold: 5
      timeoutSeconds: 1
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/health
      periodSeconds: 5
      failureThreshold: 1
      timeoutSeconds: 1
    readinessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      periodSeconds: 3
      failureThreshold: 1
EOF
```

**Objective:** The pod above should reach Running and Ready with restartCount 0 and stay healthy for at least 2 minutes. Investigate all issues, fix them, and verify stability.

**Verification (after fix, wait 2 minutes):**

```bash
kubectl get pod flaky-app -n ex-5-1
# Expected: Running, 1/1 Ready, RESTARTS 0

kubectl get pod flaky-app -n ex-5-1 -o jsonpath='{.status.containerStatuses[0].restartCount}'
# Expected: 0

kubectl get pod flaky-app -n ex-5-1 -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Expected: True

# No Unhealthy events in the last 2 minutes
kubectl get events -n ex-5-1 --field-selector reason=Unhealthy --sort-by='.lastTimestamp'
# Expected: no recent events (only old ones from before the fix)
```

---

### Exercise 5.2

**Setup:**

```bash
kubectl create namespace ex-5-2
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: web-complex
  namespace: ex-5-2
spec:
  terminationGracePeriodSeconds: 5
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
      timeoutSeconds: 8
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

**Objective:** The pod above should reach Running and Ready, stay stable, and when deleted, its preStop hook should complete fully before the container is killed. There are multiple issues. Find and fix all of them so the pod is healthy in steady state and shuts down gracefully.

**Verification (after fix):**

```bash
# Pod should be Running and Ready after 30 seconds
kubectl get pod web-complex -n ex-5-2
# Expected: Running, 1/1 Ready, RESTARTS 0

kubectl get pod web-complex -n ex-5-2 -o jsonpath='{.status.containerStatuses[0].restartCount}'
# Expected: 0

# Liveness probe timeoutSeconds should be less than periodSeconds
kubectl get pod web-complex -n ex-5-2 -o jsonpath='{.spec.containers[0].livenessProbe.timeoutSeconds}'
kubectl get pod web-complex -n ex-5-2 -o jsonpath='{.spec.containers[0].livenessProbe.periodSeconds}'
# Expected: timeoutSeconds < periodSeconds

# terminationGracePeriodSeconds should be long enough for preStop hook
kubectl get pod web-complex -n ex-5-2 -o jsonpath='{.spec.terminationGracePeriodSeconds}'
# Expected: >= 25

# Delete the pod and verify graceful shutdown
time kubectl delete pod web-complex -n ex-5-2
# Expected: takes >= 20 seconds (preStop hook completes)
```

---

### Exercise 5.3

**Objective:** Build a pod from scratch that meets these production requirements. No broken YAML is provided; you must translate the requirements into a correctly-tuned pod spec.

**Setup:**

```bash
kubectl create namespace ex-5-3
```

**Task:** Create a pod named `prod-app` in namespace `ex-5-3` with the following requirements:

**Container spec:**
- Image: `nginx:1.25-alpine`
- Command: `["/bin/sh", "-c", "sleep 25 && touch /tmp/ready && nginx -g 'daemon off;'"]`
- The container takes 25 seconds to start and begin serving HTTP on port 80

**Health check requirements:**
- The container must be given at least 60 seconds to start (use a startup probe with httpGet on port 80 path `/`)
- After startup, hang detection must trigger within 20 seconds of a genuine failure (use a liveness probe with httpGet on port 80, path `/`)
- The pod should be marked NotReady within 10 seconds if the container stops being available (use a readiness probe with exec checking `test -f /tmp/ready`)
- All probe timeoutSeconds should be 2
- Liveness failureThreshold should be 2, with periodSeconds 10 (2 * 10 = 20 second detection)
- Readiness failureThreshold should be 2, with periodSeconds 5 (2 * 5 = 10 second detection)
- Startup probe should use periodSeconds 5 and failureThreshold 12 (5 * 12 = 60 second window)

**Lifecycle and termination requirements:**
- A postStart hook that writes "Container started at $(date)" to /tmp/lifecycle.log using exec
- A preStop hook that runs `/bin/sh -c "echo 'shutting down' >> /proc/1/fd/1 && sleep 15"` using exec
- terminationGracePeriodSeconds of 30 (15 seconds for preStop plus 15 seconds margin)

**Verification (wait 40 seconds after creation):**

```bash
# Pod should be Running and Ready
kubectl get pod prod-app -n ex-5-3
# Expected: Running, 1/1 Ready, RESTARTS 0

# All conditions True
kubectl get pod prod-app -n ex-5-3 -o jsonpath='{range .status.conditions[*]}{.type}={.status}{"\n"}{end}'
# Expected: all True

# Startup probe window = periodSeconds * failureThreshold
kubectl get pod prod-app -n ex-5-3 -o jsonpath='{.spec.containers[0].startupProbe.periodSeconds}'
# Expected: 5
kubectl get pod prod-app -n ex-5-3 -o jsonpath='{.spec.containers[0].startupProbe.failureThreshold}'
# Expected: 12

# Liveness detection window = periodSeconds * failureThreshold
kubectl get pod prod-app -n ex-5-3 -o jsonpath='{.spec.containers[0].livenessProbe.periodSeconds}'
# Expected: 10
kubectl get pod prod-app -n ex-5-3 -o jsonpath='{.spec.containers[0].livenessProbe.failureThreshold}'
# Expected: 2

# Readiness detection window = periodSeconds * failureThreshold
kubectl get pod prod-app -n ex-5-3 -o jsonpath='{.spec.containers[0].readinessProbe.periodSeconds}'
# Expected: 5
kubectl get pod prod-app -n ex-5-3 -o jsonpath='{.spec.containers[0].readinessProbe.failureThreshold}'
# Expected: 2

# All timeouts should be 2
kubectl get pod prod-app -n ex-5-3 -o jsonpath='{.spec.containers[0].startupProbe.timeoutSeconds}'
kubectl get pod prod-app -n ex-5-3 -o jsonpath='{.spec.containers[0].livenessProbe.timeoutSeconds}'
kubectl get pod prod-app -n ex-5-3 -o jsonpath='{.spec.containers[0].readinessProbe.timeoutSeconds}'
# Expected: 2, 2, 2

# postStart hook wrote lifecycle log
kubectl exec prod-app -n ex-5-3 -- cat /tmp/lifecycle.log
# Expected: "Container started at <date>"

# terminationGracePeriodSeconds
kubectl get pod prod-app -n ex-5-3 -o jsonpath='{.spec.terminationGracePeriodSeconds}'
# Expected: 30

# Graceful shutdown test
kubectl delete pod prod-app -n ex-5-3 --wait=false
sleep 2
kubectl logs prod-app -n ex-5-3
# Expected: should contain "shutting down"
```

---

## Cleanup

### Per-Exercise Cleanup

Delete a specific exercise namespace:

```bash
kubectl delete namespace ex-1-1
```

### Full Cleanup

Remove all exercise namespaces:

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3; do
  kubectl delete namespace "$ns" --ignore-not-found
done
```

Restore default namespace:

```bash
kubectl config set-context --current --namespace=default
```

---

## Key Takeaways

### Probe Purpose Differences

Liveness probes answer "should Kubernetes restart this container?" A failed liveness probe kills and restarts the container. Use liveness probes for deadlocks, hangs, and unrecoverable states.

Readiness probes answer "should this container receive traffic?" A failed readiness probe removes the pod from Service endpoints and sets the Ready condition to False, but does NOT restart the container. Use readiness probes for warm-up delays, dependency checks, and temporary unavailability.

Startup probes answer "has this container finished initializing?" While the startup probe is active, liveness and readiness probes are disabled. Once the startup probe succeeds, it never runs again for that container. Use startup probes for containers with slow or variable startup times that would be killed by an aggressive liveness probe.

### Probe Tuning Math

The total time a probe tolerates consecutive failures before acting is approximately `failureThreshold * periodSeconds`. The startup window for a startup probe is `initialDelaySeconds + failureThreshold * periodSeconds`. Always set timeoutSeconds lower than periodSeconds to avoid overlapping probes. Set failureThreshold to at least 2 for liveness probes to avoid killing containers on transient issues.

### The Termination Sequence

When a pod is deleted: (1) preStop hook fires, (2) SIGTERM is sent to PID 1 after the hook completes, (3) the terminationGracePeriodSeconds countdown runs from when deletion started (not from SIGTERM), (4) SIGKILL is sent when the grace period expires. Always set terminationGracePeriodSeconds to at least the time your preStop hook needs plus margin for SIGTERM handling.

### The Diagnostic Command Toolbox

| Command | What it tells you |
|---------|-------------------|
| `kubectl get pod <n>` | STATUS, READY, RESTARTS at a glance |
| `kubectl describe pod <n>` | Events (Unhealthy, Killing, BackOff), probe config, conditions |
| `kubectl logs <n>` | Container stdout/stderr |
| `kubectl logs <n> --previous` | Logs from the crashed/killed container |
| `kubectl logs <n> -c <container>` | Specific container in multi-container pod |
| `kubectl get pod <n> -o jsonpath='{...}'` | Structured access to conditions, statuses, restartCount |
| `kubectl get events -n <ns>` | Namespace-wide events sorted by time |
