# Pod Health and Observability Tutorial

## Introduction

This tutorial walks through a complete workflow for configuring Kubernetes pod health checks, lifecycle hooks, and diagnostic techniques. You will build a realistic pod with probes, deliberately break it in three different ways, and diagnose each failure using the same kubectl tools available during the CKA exam.

By the end of this tutorial you will understand how Kubernetes decides whether a container is alive, ready, and started, how lifecycle hooks run during pod creation and termination, and how to read the diagnostic signals (events, logs, conditions, container statuses) that tell you what went wrong.

### Namespace Setup

All tutorial resources live in a dedicated namespace to avoid conflicts with the exercises.

```bash
kubectl create namespace tutorial-pod-health
kubectl config set-context --current --namespace=tutorial-pod-health
```

---

## Part 1: Understanding Probes

Kubernetes uses three kinds of probes to monitor container health. Each probe runs a handler at regular intervals and takes action based on the result.

### Probe Purposes

**Liveness probe:** Answers "is this container still functioning?" If the liveness probe fails, Kubernetes kills the container and restarts it (subject to the pod's restartPolicy). Use liveness probes to catch deadlocks, infinite loops, or any state where the container is running but no longer doing useful work.

**Readiness probe:** Answers "is this container ready to accept work?" If the readiness probe fails, Kubernetes removes the pod from Service endpoints (the pod stays running, but traffic stops flowing to it). Even without a Service, the pod's Ready condition flips to False, which is observable via `kubectl get pods`. Use readiness probes for containers that need warm-up time, depend on external resources, or should temporarily stop receiving traffic.

**Startup probe:** Answers "has this container finished starting up?" While the startup probe is running, liveness and readiness probes are disabled. Once the startup probe succeeds, Kubernetes hands control to the liveness and readiness probes. If the startup probe never succeeds (exhausts its failureThreshold), Kubernetes kills and restarts the container. Use startup probes for containers with slow or variable initialization times that would otherwise be killed by an aggressive liveness probe.

### Probe Handler Types

Each probe uses one of three handler types to perform its check:

**exec:** Runs a command inside the container. The probe succeeds if the command exits with status 0. Use exec for containers that expose health via files or CLI tools rather than network endpoints.

**httpGet:** Sends an HTTP GET request to a specified path and port on the container. The probe succeeds if the response status code is between 200 and 399. Use httpGet for any container that serves HTTP (web servers, REST APIs).

**tcpSocket:** Attempts to open a TCP connection to a specified port on the container. The probe succeeds if the connection is established. Use tcpSocket for containers that listen on a port but do not serve HTTP (databases, message brokers, raw TCP services).

### Probe Tuning Fields

Every probe supports the same set of tuning fields. Understanding these fields and their defaults is essential for both production work and the CKA exam.

| Field | Default | Description |
|-------|---------|-------------|
| `initialDelaySeconds` | 0 | Seconds to wait after the container starts before running the first probe. Set this to at least your container's minimum startup time to avoid false failures during initialization. |
| `periodSeconds` | 10 | How often (in seconds) to run the probe. Shorter periods detect failures faster but consume more resources. Minimum value is 1. |
| `timeoutSeconds` | 1 | How long to wait for the probe to respond before counting it as a failure. If your health check endpoint is slow, increase this. Must be less than periodSeconds to avoid probe pile-up. |
| `successThreshold` | 1 | How many consecutive successes are needed to transition from failed to succeeded. For liveness and startup probes, this must be 1. For readiness probes, you can require multiple consecutive successes before marking the container ready. |
| `failureThreshold` | 3 | How many consecutive failures before taking action (kill for liveness/startup, unready for readiness). Higher values tolerate transient issues but delay failure detection. |

The total time a probe tolerates failure before acting is `failureThreshold * periodSeconds` seconds (roughly). For startup probes, the total startup window is `initialDelaySeconds + failureThreshold * periodSeconds`.

### Imperative vs. Declarative

Probes and lifecycle hooks cannot be set via `kubectl run` flags. The practical imperative workflow is to generate a skeleton and then edit it:

```bash
kubectl run my-pod --image=nginx:1.25 --dry-run=client -o yaml > pod.yaml
# Edit pod.yaml to add probes and hooks
kubectl apply -f pod.yaml
```

All probe and hook examples in this tutorial use declarative YAML because that is the only way to configure them.

---

## Part 2: Building a Realistic Pod

Let's build a pod step by step that represents a realistic production health configuration. We will use nginx as a web server that takes a few seconds to initialize, needs to signal readiness before accepting requests, should be restarted if it hangs, and should drain connections gracefully before shutting down.

### Step 1: A Basic Liveness Probe (httpGet)

Create a file called `tutorial-web-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-web
  namespace: tutorial-pod-health
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
      initialDelaySeconds: 5
      periodSeconds: 10
      timeoutSeconds: 2
      failureThreshold: 3
```

Apply it and watch:

```bash
kubectl apply -f tutorial-web-pod.yaml
kubectl get pod tutorial-web -w
```

Wait until the pod shows `1/1 Running`. Then inspect the probe configuration:

```bash
kubectl describe pod tutorial-web | grep -A 10 "Liveness:"
```

You should see the httpGet handler targeting port 80, path /, with the tuning values you specified. The Events section at the bottom of `kubectl describe` should show only normal startup events (Scheduled, Pulling, Pulled, Created, Started) with no Unhealthy events.

Check the pod conditions:

```bash
kubectl get pod tutorial-web -o jsonpath='{range .status.conditions[*]}{.type}={.status}{"\n"}{end}'
```

You should see all four conditions as True: PodScheduled, Initialized, ContainersReady, and Ready.

Clean up before the next step:

```bash
kubectl delete pod tutorial-web --namespace=tutorial-pod-health
```

### Step 2: Adding a Readiness Probe

Now add a readiness probe. We will simulate an application that serves HTTP but uses a file to signal when it is ready. This is a common pattern for applications that need to load data or establish connections before accepting traffic.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-web-v2
  namespace: tutorial-pod-health
spec:
  containers:
  - name: web
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
    command: ["/bin/sh", "-c"]
    args:
    - |
      # Simulate slow startup: wait 15 seconds before becoming ready
      (sleep 15 && touch /tmp/ready) &
      nginx -g 'daemon off;'
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 10
      timeoutSeconds: 2
      failureThreshold: 3
    readinessProbe:
      exec:
        command:
        - test
        - -f
        - /tmp/ready
      initialDelaySeconds: 2
      periodSeconds: 5
      timeoutSeconds: 1
      failureThreshold: 1
```

Apply and watch:

```bash
kubectl apply -f tutorial-web-pod.yaml
kubectl get pod tutorial-web-v2 -w
```

Observe the READY column. For the first 15 seconds, you should see `0/1` because the readiness probe is failing (the file `/tmp/ready` does not exist yet). The pod is Running but not Ready. After approximately 15 seconds, the background `sleep && touch` command creates the file, the readiness probe succeeds, and the READY column changes to `1/1`.

Check the Events to see the readiness probe failures:

```bash
kubectl describe pod tutorial-web-v2 | tail -20
```

You should see events with reason "Unhealthy" and message "Readiness probe failed" for the first few checks. Note that the container was NOT restarted (readiness failures do not cause restarts, only liveness failures do).

Verify restartCount is 0:

```bash
kubectl get pod tutorial-web-v2 -o jsonpath='{.status.containerStatuses[0].restartCount}'
```

Clean up:

```bash
kubectl delete pod tutorial-web-v2 --namespace=tutorial-pod-health
```

### Step 3: Adding a Startup Probe

Now let's add a startup probe to protect the container during its slow initialization. Without a startup probe, the liveness probe (initialDelaySeconds: 5) would start checking before the container is fully initialized, and if the container takes longer than expected, the liveness probe would kill it.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-web-v3
  namespace: tutorial-pod-health
spec:
  containers:
  - name: web
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
    command: ["/bin/sh", "-c"]
    args:
    - |
      # Simulate slow startup: 20-second initialization
      sleep 20
      touch /tmp/ready
      nginx -g 'daemon off;'
    startupProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 0
      periodSeconds: 5
      timeoutSeconds: 2
      failureThreshold: 12
      # Total startup window: 12 * 5 = 60 seconds
    livenessProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 10
      timeoutSeconds: 2
      failureThreshold: 3
    readinessProbe:
      exec:
        command:
        - test
        - -f
        - /tmp/ready
      periodSeconds: 5
      timeoutSeconds: 1
      failureThreshold: 1
```

The startup probe gives the container up to 60 seconds (12 failures * 5 second period) to start serving on port 80. During those 60 seconds, the liveness and readiness probes are completely disabled. Once nginx starts (after the 20-second sleep), the startup probe's httpGet to port 80 succeeds, and control passes to the liveness and readiness probes.

Apply and watch:

```bash
kubectl apply -f tutorial-web-pod.yaml
kubectl get pod tutorial-web-v3 -w
```

For the first ~20 seconds the pod shows `0/1 Running` (startup probe is running, liveness and readiness are paused). After nginx starts, the startup probe succeeds, then the readiness probe immediately succeeds (the `touch /tmp/ready` ran before nginx started), and the pod transitions to `1/1 Running`.

```bash
kubectl describe pod tutorial-web-v3 | tail -25
```

You will see startup probe failure events during the first 20 seconds, then a transition to normal operation with no further Unhealthy events.

### Step 4: Adding Lifecycle Hooks and Graceful Termination

Now let's complete the pod with lifecycle hooks and proper termination settings.

Create `tutorial-web-final.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-web-final
  namespace: tutorial-pod-health
spec:
  terminationGracePeriodSeconds: 45
  containers:
  - name: web
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
    command: ["/bin/sh", "-c"]
    args:
    - |
      sleep 20
      touch /tmp/ready
      echo "Application initialization complete"
      nginx -g 'daemon off;'
    startupProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 5
      failureThreshold: 12
    livenessProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 10
      timeoutSeconds: 2
      failureThreshold: 3
    readinessProbe:
      exec:
        command:
        - test
        - -f
        - /tmp/ready
      periodSeconds: 5
      failureThreshold: 1
    lifecycle:
      postStart:
        exec:
          command: ["/bin/sh", "-c", "echo 'postStart hook executed at $(date)' >> /tmp/lifecycle.log"]
      preStop:
        exec:
          command: ["/bin/sh", "-c", "echo 'preStop: beginning graceful shutdown' >> /tmp/lifecycle.log && sleep 10 && echo 'preStop: shutdown complete' >> /tmp/lifecycle.log"]
```

Apply and wait for it to be ready:

```bash
kubectl apply -f tutorial-web-final.yaml
kubectl wait --for=condition=Ready pod/tutorial-web-final --timeout=60s
```

Verify the postStart hook ran:

```bash
kubectl exec tutorial-web-final -- cat /tmp/lifecycle.log
```

You should see the "postStart hook executed" message. The postStart hook runs immediately after the container starts but before the container is considered Running. If the postStart hook fails, the container is killed and restarted.

Now delete the pod and observe the termination sequence:

```bash
kubectl delete pod tutorial-web-final &
kubectl get pod tutorial-web-final -w
```

Watch the STATUS column. When you delete the pod, Kubernetes runs the preStop hook first (which sleeps for 10 seconds in our case), then sends SIGTERM to the container process, then waits up to terminationGracePeriodSeconds (45 seconds total from when deletion started) before sending SIGKILL. You should see the pod in "Terminating" state for at least 10 seconds while the preStop hook runs.

After the pod is gone, recreate it briefly so we can inspect the lifecycle log during a clean termination. (The pod is already deleted, so the log is gone.) This illustrates an important point: if you need to inspect what a preStop hook did, you need logging or external persistence, because the pod is gone after termination.

---

## Part 3: Breaking Things (Diagnostic Practice)

Now comes the most valuable part of this tutorial: deliberately breaking the pod in three different ways and practicing the diagnostic workflow you would use during the CKA exam.

### Failure 1: Liveness Probe Kills a Healthy Container

Create a pod where the liveness probe is misconfigured to hit the wrong port:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-broken-liveness
  namespace: tutorial-pod-health
spec:
  containers:
  - name: web
    image: nginx:1.25-alpine
    ports:
    - containerPort: 80
    livenessProbe:
      httpGet:
        path: /
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 5
      failureThreshold: 3
```

Apply and watch:

```bash
kubectl apply -f tutorial-broken-liveness.yaml
kubectl get pod tutorial-broken-liveness -w
```

After about 20 seconds (5 initial delay + 3 failures * 5 second period), the pod will restart. Watch the RESTARTS column increment.

**Diagnostic workflow:**

```bash
# Step 1: Check pod status and restartCount
kubectl get pod tutorial-broken-liveness
# RESTARTS will be > 0 and climbing

# Step 2: Describe the pod to see Events
kubectl describe pod tutorial-broken-liveness
# Look for: "Unhealthy" events with "Liveness probe failed"
# The message will say something like "connection refused" on port 8080

# Step 3: Check container last termination state
kubectl get pod tutorial-broken-liveness -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
# Should show: Error (the container was killed by the liveness probe)

kubectl get pod tutorial-broken-liveness -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
# Exit code from the killed container

# Step 4: Check logs from the previous container instance
kubectl logs tutorial-broken-liveness --previous
# Shows the logs from the container that was killed

# Step 5: Check current logs
kubectl logs tutorial-broken-liveness
# Shows logs from the currently running (restarted) container
```

The diagnosis: the liveness probe targets port 8080, but the container only listens on port 80. The connection is refused every time, the probe fails three consecutive times, and Kubernetes kills and restarts the container. This cycle repeats indefinitely, eventually resulting in CrashLoopBackOff as Kubernetes adds exponential backoff between restart attempts.

**Fix:** Change the liveness probe port from 8080 to 80.

```bash
kubectl delete pod tutorial-broken-liveness --namespace=tutorial-pod-health
```

### Failure 2: Missing Startup Probe Causes CrashLoopBackOff

Create a pod with a slow-starting application and an aggressive liveness probe but no startup probe to protect it:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-crashloop
  namespace: tutorial-pod-health
spec:
  containers:
  - name: slow-app
    image: busybox:1.36
    command: ["/bin/sh", "-c"]
    args:
    - |
      echo "Starting long initialization..."
      sleep 30
      echo "Initialization complete, starting server"
      while true; do
        echo "healthy" > /tmp/health
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
```

Apply and watch:

```bash
kubectl apply -f tutorial-crashloop.yaml
kubectl get pod tutorial-crashloop -w
```

The container takes 30 seconds to create `/tmp/health`, but the liveness probe starts checking at 5 seconds and fails 3 times by second 20. Kubernetes kills the container, it restarts, and the same cycle repeats. After several restarts, Kubernetes enters CrashLoopBackOff, adding increasing delays between restart attempts.

**Diagnostic workflow:**

```bash
# Step 1: Watch the progression
kubectl get pod tutorial-crashloop
# STATUS will cycle: Running -> CrashLoopBackOff -> Running -> CrashLoopBackOff
# RESTARTS keeps climbing

# Step 2: Check Events
kubectl describe pod tutorial-crashloop | grep -A 5 "Events:"
# You'll see: Unhealthy (liveness probe failed: cat /tmp/health: No such file)
# Then: Killing (container failed liveness probe, will be restarted)
# Then: Started (new container started)
# This pattern repeats.

# Step 3: Check last termination state
kubectl get pod tutorial-crashloop -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
# Exit code 137 = SIGKILL (killed by Kubernetes)

kubectl get pod tutorial-crashloop -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
# "Error"

# Step 4: Check logs from the killed container
kubectl logs tutorial-crashloop --previous
# Shows: "Starting long initialization..." and nothing else
# The container never reached "Initialization complete"

# Step 5: Check current container logs
kubectl logs tutorial-crashloop
# Same: stuck in initialization, about to be killed again
```

The diagnosis: the container needs 30 seconds to initialize, but the liveness probe starts at 5 seconds and kills the container at ~20 seconds (after 3 failures). The container never has time to finish starting.

**Fix:** Add a startup probe that gives the container enough time to initialize, or increase initialDelaySeconds on the liveness probe to at least 30 seconds. The startup probe approach is better because it separates startup tolerance from steady-state health checking.

```bash
kubectl delete pod tutorial-crashloop --namespace=tutorial-pod-health
```

### Failure 3: Pod Appears Healthy but Terminates Abruptly

Create a pod with a preStop hook that needs more time than the grace period allows:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-abrupt-term
  namespace: tutorial-pod-health
spec:
  terminationGracePeriodSeconds: 5
  containers:
  - name: app
    image: busybox:1.36
    command: ["/bin/sh", "-c"]
    args:
    - |
      trap 'echo "Received SIGTERM"' TERM
      echo "Application started"
      while true; do sleep 1; done
    lifecycle:
      preStop:
        exec:
          command:
          - /bin/sh
          - -c
          - |
            echo "preStop: flushing buffers..."
            sleep 15
            echo "preStop: flush complete"
    livenessProbe:
      exec:
        command:
        - echo
        - ok
      periodSeconds: 10
```

Apply and wait:

```bash
kubectl apply -f tutorial-abrupt-term.yaml
kubectl wait --for=condition=Ready pod/tutorial-abrupt-term --timeout=30s
```

The pod is Running and healthy. Now delete it and observe:

```bash
kubectl delete pod tutorial-abrupt-term &
sleep 2
kubectl describe pod tutorial-abrupt-term | tail -10
```

The preStop hook starts a 15-second flush operation, but terminationGracePeriodSeconds is only 5 seconds. After 5 seconds, Kubernetes sends SIGKILL, killing the container mid-flush. The "preStop: flush complete" message never appears.

The diagnosis: the terminationGracePeriodSeconds (5s) is shorter than the preStop hook (15s). The container is killed before graceful shutdown completes. In production, this means data loss, incomplete cleanup, or dropped connections.

**Fix:** Increase terminationGracePeriodSeconds to at least 20 seconds (enough for the 15-second preStop hook plus margin).

Wait for the pod to finish terminating:

```bash
sleep 10
```

---

## Part 4: Probe Tuning Walkthrough

Here is a concrete scenario to practice probe tuning math, the kind of reasoning you need for both the CKA exam and production work.

**Scenario:** You have a container with these characteristics:
- Takes 10 seconds to start serving HTTP on port 8080
- Health check endpoint responds in under 500ms when healthy
- Occasionally hiccups for up to 2 seconds (slow response, not a crash)
- Once healthy, a genuine hang means the container will never recover

**Calculating probe values:**

**Startup probe:** The container takes 10 seconds, but startup times vary in practice. Give it 3x headroom: 30 seconds. With periodSeconds: 2 and failureThreshold: 15, the startup window is 2 * 15 = 30 seconds.

**Liveness probe:** After startup, the container should be checked regularly. Set periodSeconds: 10 for reasonable frequency. The occasional 2-second hiccup means timeoutSeconds should be at least 3 (to tolerate the hiccup). Set failureThreshold: 3 so that a genuine hang is detected after 30 seconds (3 * 10) rather than killed on the first slow response. No initialDelaySeconds needed because the startup probe handles initialization.

**Readiness probe:** Similar to liveness but can be more sensitive since readiness failures do not kill the container. Set periodSeconds: 5 for faster detection, timeoutSeconds: 3 (same hiccup tolerance), failureThreshold: 2 (unready after 10 seconds of failure, faster than liveness), successThreshold: 2 (require two consecutive successes before re-marking ready, to avoid flapping).

```yaml
startupProbe:
  httpGet:
    path: /health
    port: 8080
  periodSeconds: 2
  failureThreshold: 15
  timeoutSeconds: 3
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 2
  successThreshold: 2
```

---

## Part 5: CrashLoopBackOff Deep Dive

CrashLoopBackOff is one of the most common pod states you will encounter, and understanding its progression is essential for the CKA exam. Here is the sequence of events when a container repeatedly fails.

Create a pod that immediately exits:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tutorial-crashloop-demo
  namespace: tutorial-pod-health
spec:
  containers:
  - name: crash
    image: busybox:1.36
    command: ["/bin/sh", "-c", "echo 'starting' && exit 1"]
```

```bash
kubectl apply -f tutorial-crashloop-demo.yaml
```

Watch the progression over 2 to 3 minutes:

```bash
kubectl get pod tutorial-crashloop-demo -w
```

You will see the STATUS cycle through these states:

1. **Running** (briefly, while the container executes)
2. **Error** (container exited with code 1)
3. **CrashLoopBackOff** (Kubernetes is waiting before restarting)
4. Back to **Running** (restarted container)
5. The cycle repeats with increasing backoff: 10s, 20s, 40s, 80s, 160s, capping at 300s (5 minutes)

Inspect the diagnostic signals:

```bash
# restartCount increments each time
kubectl get pod tutorial-crashloop-demo -o jsonpath='{.status.containerStatuses[0].restartCount}'

# Last termination state shows the exit code
kubectl get pod tutorial-crashloop-demo -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
# Returns: 1

kubectl get pod tutorial-crashloop-demo -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
# Returns: Error

# Logs from the most recent crashed container
kubectl logs tutorial-crashloop-demo --previous

# Events show the cycle
kubectl describe pod tutorial-crashloop-demo | tail -20
```

Clean up:

```bash
kubectl delete pod tutorial-crashloop-demo --namespace=tutorial-pod-health
```

---

## Part 6: Pod Conditions and Container Statuses

Understanding the structured status fields on a pod is crucial for both diagnosis and for answering CKA exam questions.

### Pod Conditions

Every pod has four conditions. Each is either True or False:

| Condition | Meaning |
|-----------|---------|
| `PodScheduled` | The pod has been assigned to a node |
| `Initialized` | All init containers have completed |
| `ContainersReady` | All containers in the pod have passed their readiness probes |
| `Ready` | The pod is ready to serve (ContainersReady is True and any readinessGates are satisfied) |

Inspect conditions:

```bash
kubectl get pod <name> -o jsonpath='{range .status.conditions[*]}{.type}={.status} ({.reason}){"\n"}{end}'
```

### Container Statuses

Each container in a pod has a `state` (current) and `lastState` (previous). The state is one of:

| State | Common Reasons |
|-------|---------------|
| `Waiting` | ContainerCreating, CrashLoopBackOff, ImagePullBackOff, ErrImagePull |
| `Running` | (started at a timestamp) |
| `Terminated` | Completed (exit 0), Error (non-zero exit), OOMKilled (out of memory) |

Inspect current state:

```bash
kubectl get pod <name> -o jsonpath='{.status.containerStatuses[0].state}'
```

Inspect last termination:

```bash
kubectl get pod <name> -o jsonpath='{.status.containerStatuses[0].lastState.terminated}'
```

The `lastState.terminated` object includes `exitCode`, `reason`, `startedAt`, and `finishedAt`, which together tell you exactly what happened and when.

---

## Reference Sections

### Probe Tuning Decision Table

| Factor | exec | httpGet | tcpSocket |
|--------|------|---------|-----------|
| When to use | Container exposes health via files or CLI commands, no HTTP endpoint available | Container serves HTTP, health endpoint exists | Container listens on a port but does not serve HTTP |
| Example | `cat /tmp/healthy`, `test -f /tmp/ready`, `pg_isready` | `GET /healthz` on port 8080 | Check port 3306 (MySQL), port 6379 (Redis) |
| Overhead | Spawns a process inside the container each time | HTTP connection each time (lightweight) | TCP connect only (very lightweight) |
| Precision | High (custom logic possible) | Medium (HTTP status codes only) | Low (only checks if port is open, not if app is functioning) |

**Calculating tuning values from container behavior:**

| Container behavior | Probe field | Calculation |
|-------------------|-------------|-------------|
| Startup time N seconds | startup probe failureThreshold * periodSeconds | Must be > N, recommend 2x to 3x headroom |
| Health check takes M ms | timeoutSeconds | Must be > M/1000, add margin for slow responses |
| Transient hiccups last T seconds | failureThreshold * periodSeconds on liveness | Must be > T to avoid restarting on transient issues |
| Need fast failure detection | periodSeconds on liveness | Lower = faster detection, but more overhead |
| Need fast readiness gating | periodSeconds on readiness | Lower = faster traffic removal on failure |

### Pod Termination Sequence

```
kubectl delete pod <name>
        |
        v
+-------------------+
| preStop hook fires |  (exec or httpGet handler runs)
+-------------------+
        |
        | (hook completes or terminationGracePeriodSeconds starts counting)
        v
+-------------------+
| SIGTERM sent to    |  (container's PID 1 receives SIGTERM)
| container process  |
+-------------------+
        |
        | (container should catch SIGTERM and shut down gracefully)
        | (grace period is still counting down)
        v
+-------------------+
| Grace period       |  (terminationGracePeriodSeconds, default 30s)
| expires            |  (counted from when deletion started, not from SIGTERM)
+-------------------+
        |
        v
+-------------------+
| SIGKILL sent       |  (container is forcefully killed)
+-------------------+
        |
        v
+-------------------+
| Pod removed        |
+-------------------+
```

Key points:
- The preStop hook and SIGTERM both happen within the same terminationGracePeriodSeconds window.
- If the preStop hook takes 20 seconds and terminationGracePeriodSeconds is 30, the container gets only 10 seconds after SIGTERM before SIGKILL.
- If the preStop hook takes longer than terminationGracePeriodSeconds, the container is killed mid-hook.

### Diagnostic Workflow Cheat Sheet

**Pod in Pending state:**
```bash
kubectl describe pod <name>   # Check Events for FailedScheduling
kubectl get events --field-selector involvedObject.name=<name>
# Common causes: no nodes with enough resources, unsatisfied node affinity, all nodes tainted
```

**Pod in ImagePullBackOff:**
```bash
kubectl describe pod <name>   # Check Events for Failed to pull image
kubectl get pod <name> -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}'
# Common causes: wrong image name/tag, private registry without imagePullSecret, network issues
```

**Pod in CrashLoopBackOff:**
```bash
kubectl logs <name> --previous            # Logs from the crashed container
kubectl get pod <name> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
kubectl get pod <name> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
kubectl get pod <name> -o jsonpath='{.status.containerStatuses[0].restartCount}'
kubectl describe pod <name>               # Events show the crash cycle
# Common causes: application error (exit 1), liveness probe killing the container,
# missing config, command not found
```

**Pod Running but NotReady (0/1):**
```bash
kubectl describe pod <name>   # Check Events for readiness probe failures
kubectl get pod <name> -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
kubectl get pod <name> -o jsonpath='{.status.conditions[?(@.type=="ContainersReady")].status}'
# Common causes: readiness probe failing, dependency not available, file not created
```

**Pod OOMKilled:**
```bash
kubectl get pod <name> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'
# Returns: OOMKilled
kubectl get pod <name> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
# Returns: 137
# Cause: container exceeded its memory limit (or node memory pressure)
```

**Multi-container pod, one container unhealthy:**
```bash
kubectl logs <name> --container=<container-name>
kubectl logs <name> --container=<container-name> --previous
kubectl get pod <name> -o jsonpath='{.status.containerStatuses[*].name}'
kubectl get pod <name> -o jsonpath='{range .status.containerStatuses[*]}{.name}: ready={.ready}, restartCount={.restartCount}{"\n"}{end}'
```

**General log inspection:**
```bash
kubectl logs <name>                        # Current container logs
kubectl logs <name> --previous             # Previous (crashed) container logs
kubectl logs <name> --follow               # Live tail
kubectl logs <name> --tail=50              # Last 50 lines
kubectl logs <name> --since=5m             # Logs from last 5 minutes
kubectl logs <name> --timestamps           # Include timestamps for correlation
kubectl logs <name> -c <container>         # Specific container in multi-container pod
```

---

## Cleanup

Remove the tutorial namespace and all its resources:

```bash
kubectl delete namespace tutorial-pod-health
```

Restore your default namespace context:

```bash
kubectl config set-context --current --namespace=default
```
