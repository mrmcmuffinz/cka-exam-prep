# Multi-Container Patterns: Tutorial

**Assignment 6 Tutorial | CKA Pod Series**

This tutorial walks through the complete family of multi-container pod patterns. Each section builds a working example in the `tutorial-multi-container` namespace. By the end, you will understand when to use each pattern, how they differ in lifecycle and structure, and how to debug multi-container pods effectively.

All resources in this tutorial use the `tutorial-multi-container` namespace to avoid conflicts with exercises in the homework file.

---

## Table of Contents

1. [Setup](#1-setup)
2. [The Decision Framework: Multi-Container Pod or Separate Pods?](#2-the-decision-framework-multi-container-pod-or-separate-pods)
3. [Shared Storage with emptyDir](#3-shared-storage-with-emptydir)
4. [Init Containers as a Pattern](#4-init-containers-as-a-pattern)
5. [Classical Sidecar Pattern](#5-classical-sidecar-pattern)
6. [Ambassador Pattern](#6-ambassador-pattern)
7. [Adapter Pattern](#7-adapter-pattern)
8. [Native Sidecars](#8-native-sidecars)
9. [Shared Process Namespace](#9-shared-process-namespace)
10. [Debugging Multi-Container Pods](#10-debugging-multi-container-pods)
11. [Pattern Selection Decision Tree](#11-pattern-selection-decision-tree)
12. [Classical vs Native Sidecar Comparison](#12-classical-vs-native-sidecar-comparison)
13. [Reference Commands](#13-reference-commands)
14. [Cleanup](#14-cleanup)

---

## 1. Setup

Create the tutorial namespace:

```bash
kubectl create namespace tutorial-multi-container
```

Verify your cluster is running and check the Kubernetes version (needed for native sidecar exercises later):

```bash
kubectl version
kubectl get nodes
```

If your cluster reports a version of 1.29 or later, native sidecars are supported.

---

## 2. The Decision Framework: Multi-Container Pod or Separate Pods?

Before learning the patterns, you need the most important skill: knowing when *not* to use a multi-container pod. Containers in the same pod share a network namespace (they can reach each other on localhost), can share storage volumes, and are scheduled together on the same node. They also share a lifecycle: if the pod is evicted, all containers go down together. If one container consumes too many resources, it can affect the others.

**Use a multi-container pod when:**

- The containers have a tightly coupled lifecycle. They must start together, run together, and die together. A log forwarder that must see the exact same filesystem as the application is a classic example. If the application moves to a new node, the log forwarder must follow it.
- The helper container exists *only* to serve the main container. It has no independent purpose. A format-converting adapter that reads one container's output and reformats it is useless without the container it adapts.
- The containers need to communicate over localhost or share files through a local volume. An ambassador proxy that makes an external service appear local to the main container works because they share a network namespace.
- The helper container is an operational concern (logging, monitoring, proxying), not a business logic concern. Keeping it in the same pod separates operational infrastructure from application code without separating their runtime context.

**Use separate pods when:**

- The components need to scale independently. A web frontend and a database are separate concerns. If you need 10 frontends but only 1 database, they cannot share a pod.
- The components have different lifecycle requirements. If you need to update the cache layer without restarting the web server, they should be separate pods.
- The coupling is loose. If the components communicate over a network API and either one could be replaced with a different implementation, that is a service boundary, not a sidecar relationship.
- One component is shared by many consumers. A centralized logging service that collects from many applications is a separate deployment, not a sidecar in every pod (though a per-pod log *forwarder* sidecar that sends to the centralized service is a valid pattern).
- Failure isolation matters. If a crash in the helper should not bring down the main application, separate pods with independent restart behavior give you that isolation.

**A concrete example to test your judgment:** You have an nginx web server and a Redis cache. Should they share a pod? No. They scale independently (you might want 5 nginx replicas but 1 Redis), they have different data persistence requirements, and nginx communicates with Redis over a network API that could point anywhere. Now consider nginx and a log-tailing sidecar that reads nginx's access log file. Should they share a pod? Yes. The sidecar exists only to serve nginx, must see the same filesystem, and has no independent scaling need.

---

## 3. Shared Storage with emptyDir

The emptyDir volume is the workhorse of multi-container communication. It creates a temporary directory on the node that exists for the lifetime of the pod. All containers in the pod can mount it, and writes from any container are immediately visible to all others.

### Basic emptyDir

When you declare an emptyDir volume and mount it in two containers, both containers see the same underlying directory. The `mountPath` in each container can differ: container A might mount the volume at `/data` while container B mounts it at `/output`, but they are looking at the same storage.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: tut-shared-vol
  namespace: tutorial-multi-container
spec:
  containers:
  - name: writer
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "hello from writer" > /data/message.txt
      sleep 3600
    volumeMounts:
    - name: shared
      mountPath: /data
  - name: reader
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      # Wait briefly for writer to create the file
      sleep 2
      cat /output/message.txt
      sleep 3600
    volumeMounts:
    - name: shared
      mountPath: /output
  volumes:
  - name: shared
    emptyDir: {}
```

Apply and verify:

```bash
kubectl apply -f - -n tutorial-multi-container <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: tut-shared-vol
  namespace: tutorial-multi-container
spec:
  containers:
  - name: writer
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "hello from writer" > /data/message.txt
      sleep 3600
    volumeMounts:
    - name: shared
      mountPath: /data
  - name: reader
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      sleep 2
      cat /output/message.txt
      sleep 3600
    volumeMounts:
    - name: shared
      mountPath: /output
  volumes:
  - name: shared
    emptyDir: {}
EOF

# Wait for pod to be running
kubectl wait --for=condition=Ready pod/tut-shared-vol -n tutorial-multi-container --timeout=60s

# Verify the reader saw the writer's file
kubectl logs tut-shared-vol -c reader -n tutorial-multi-container
# Expected: hello from writer

# Verify the file exists from the writer's perspective too
kubectl exec tut-shared-vol -c writer -n tutorial-multi-container -- cat /data/message.txt
# Expected: hello from writer
```

Notice that the writer sees the file at `/data/message.txt` and the reader sees the same file at `/output/message.txt`. Different paths, same content, because both mount the same volume named `shared`.

### Read-Only Mounts

You can mount a volume as read-only in one container by setting `readOnly: true` on that container's volumeMount. This is useful when a sidecar should read the main container's output but never modify it:

```yaml
    volumeMounts:
    - name: shared
      mountPath: /output
      readOnly: true
```

A container with a read-only mount will get a "Read-only file system" error if it tries to write to that path. This is a useful safety mechanism: the adapter or log shipper reads but never corrupts the main container's data.

### Memory-Backed emptyDir

By default, emptyDir uses the node's disk. You can request a memory-backed emptyDir by setting `emptyDir.medium` to `"Memory"`. This creates a tmpfs mount, which is faster but volatile (data is lost on pod restart) and counts against the container's memory limit:

```yaml
  volumes:
  - name: fast-scratch
    emptyDir:
      medium: Memory
```

The `medium: Memory` field tells Kubernetes to back the volume with RAM instead of disk. Use this for scratch space that needs high throughput (temporary computation results, in-memory caches) where durability is not needed. Be aware that the data stored here counts against the pod's memory resource accounting.

---

## 4. Init Containers as a Pattern

Assignment 1 covered the mechanics: init containers run sequentially before main containers start, they must exit 0 for the pod to proceed, and a failure in any init container blocks everything after it. This section focuses on init containers as a *design pattern* for establishing prerequisites.

### The Pattern: Sequential Prerequisites

Init containers answer the question: "What must be true before my application can start?" Common uses include waiting for a dependency to become available, pre-seeding a volume with data, running database migrations, and fetching configuration from an external source.

The key property that makes init containers useful as a pattern is their *ordering guarantee*. Regular containers in a pod have no startup ordering. Init containers run one at a time, in the order they are declared in the `initContainers` array. This means init container 0 completes before init container 1 starts, which completes before init container 2 starts, and so on. You can build a pipeline of prerequisite steps.

### Example: File-Based Dependency Wait

Here is a pod with an init container that waits for a file to exist in a shared volume. The main container will not start until the init container finds the file and exits. You will manually create the file to unblock the init container, simulating an external dependency becoming ready:

```bash
kubectl apply -f - -n tutorial-multi-container <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: tut-init-wait
  namespace: tutorial-multi-container
spec:
  initContainers:
  - name: wait-for-config
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "Waiting for /shared/config-ready..."
      while [ ! -f /shared/config-ready ]; do
        sleep 1
      done
      echo "Config is ready, proceeding."
    volumeMounts:
    - name: shared
      mountPath: /shared
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "App started. Config says: $(cat /shared/config-ready)"
      sleep 3600
    volumeMounts:
    - name: shared
      mountPath: /shared
  volumes:
  - name: shared
    emptyDir: {}
EOF
```

Watch the pod status. It will stay in `Init:0/1` because the init container is waiting:

```bash
kubectl get pod tut-init-wait -n tutorial-multi-container
# STATUS should be Init:0/1
```

Now exec into the init container and create the file it is waiting for. Note that you can exec into a running init container using `-c`:

```bash
kubectl exec tut-init-wait -c wait-for-config -n tutorial-multi-container -- sh -c 'echo "database=ready" > /shared/config-ready'
```

Watch the pod transition:

```bash
kubectl get pod tut-init-wait -n tutorial-multi-container -w
# After a moment, STATUS should change from Init:0/1 to Running
```

Verify the main container started and read the config:

```bash
kubectl logs tut-init-wait -c app -n tutorial-multi-container
# Expected: App started. Config says: database=ready
```

### Example: Multiple Init Containers with Ordering

When you have multiple init containers, they run in strict declaration order. This pod has three init containers that each write a different file, and the main container verifies all three exist:

```bash
kubectl apply -f - -n tutorial-multi-container <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: tut-multi-init
  namespace: tutorial-multi-container
spec:
  initContainers:
  - name: step-one
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "Step 1 complete" > /work/step1.txt
      echo "Init step-one finished"
    volumeMounts:
    - name: work
      mountPath: /work
  - name: step-two
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      # Verify step 1 ran first
      cat /work/step1.txt
      echo "Step 2 complete" > /work/step2.txt
      echo "Init step-two finished"
    volumeMounts:
    - name: work
      mountPath: /work
  - name: step-three
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      # Verify steps 1 and 2 ran
      cat /work/step1.txt
      cat /work/step2.txt
      echo "Step 3 complete" > /work/step3.txt
      echo "Init step-three finished"
    volumeMounts:
    - name: work
      mountPath: /work
  containers:
  - name: main
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "Checking prerequisites..."
      for f in step1.txt step2.txt step3.txt; do
        if [ -f "/work/$f" ]; then
          echo "  $f: $(cat /work/$f)"
        else
          echo "  $f: MISSING" && exit 1
        fi
      done
      echo "All prerequisites met."
      sleep 3600
    volumeMounts:
    - name: work
      mountPath: /work
  volumes:
  - name: work
    emptyDir: {}
EOF
```

Verify:

```bash
kubectl wait --for=condition=Ready pod/tut-multi-init -n tutorial-multi-container --timeout=60s

kubectl logs tut-multi-init -c main -n tutorial-multi-container
# Expected:
# Checking prerequisites...
#   step1.txt: Step 1 complete
#   step2.txt: Step 2 complete
#   step3.txt: Step 3 complete
# All prerequisites met.
```

You can also check the init container logs to see they ran in order:

```bash
kubectl logs tut-multi-init -c step-one -n tutorial-multi-container
kubectl logs tut-multi-init -c step-two -n tutorial-multi-container
kubectl logs tut-multi-init -c step-three -n tutorial-multi-container
```

### Init Container Failure Semantics

If an init container exits with a nonzero code, Kubernetes restarts it (subject to the pod's `restartPolicy`). The subsequent init containers and main containers never start until the failed init container succeeds. This is by design: the whole point is to block the application from starting until prerequisites are met.

---

## 5. Classical Sidecar Pattern

The sidecar pattern attaches a helper container to a main application container. The sidecar augments the main container's capabilities without modifying the main container's code or image. The canonical example is a log shipper: the main application writes logs to a file, and a sidecar tails that file and forwards the logs to a centralized system.

### The Canonical Log-Shipper Sidecar

This example runs nginx as the main container and a busybox sidecar that tails nginx's access log from a shared emptyDir. The sidecar reads the log file and echoes each line to its own stdout, which means `kubectl logs -c log-shipper` shows the access log stream without touching nginx's own stdout:

```bash
kubectl apply -f - -n tutorial-multi-container <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: tut-sidecar-logs
  namespace: tutorial-multi-container
spec:
  containers:
  - name: webserver
    image: nginx:1.25
    volumeMounts:
    - name: logs
      mountPath: /var/log/nginx
  - name: log-shipper
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      # Wait for nginx to create the log file
      while [ ! -f /logs/access.log ]; do
        sleep 1
      done
      echo "Log shipper started, tailing access.log..."
      tail -f /logs/access.log
    volumeMounts:
    - name: logs
      mountPath: /logs
      readOnly: true
  volumes:
  - name: logs
    emptyDir: {}
EOF
```

Wait for the pod to be ready, then generate some traffic:

```bash
kubectl wait --for=condition=Ready pod/tut-sidecar-logs -n tutorial-multi-container --timeout=60s

# Generate a few requests to nginx (hitting it from within the cluster)
kubectl exec tut-sidecar-logs -c webserver -n tutorial-multi-container -- curl -s http://localhost/ > /dev/null
kubectl exec tut-sidecar-logs -c webserver -n tutorial-multi-container -- curl -s http://localhost/ > /dev/null
kubectl exec tut-sidecar-logs -c webserver -n tutorial-multi-container -- curl -s http://localhost/ > /dev/null

# Check the sidecar's logs: it should show the access log entries
kubectl logs tut-sidecar-logs -c log-shipper -n tutorial-multi-container
```

You should see the nginx access log lines in the sidecar's output. The webserver container's own stdout (`kubectl logs -c webserver`) shows nginx's startup messages, while the sidecar's stdout shows the access log. This separation is the point of the pattern: the main container does not need to know about log shipping, and the log shipping mechanism can be changed by swapping the sidecar without modifying the main container.

**Extending to a real log shipper.** In production, you would replace the `tail -f` command with a real log forwarding agent (Fluentd, Fluent Bit, Filebeat) configured to read from `/logs/access.log` and ship to Elasticsearch, CloudWatch, or another log backend. The pattern is identical: the main container writes to a file, the sidecar reads it. The sidecar's image and configuration change, but the volume-sharing structure stays the same.

**Key observations about classical sidecars:**

- Both containers are listed in the `containers` array. There is no startup ordering between them; Kubernetes may start them in any order.
- The sidecar includes a `while [ ! -f ... ]` wait loop to handle the race condition where the sidecar might start before nginx creates the log file. This is a common pattern in classical sidecars.
- The sidecar mounts the volume with `readOnly: true`. It only needs to read the logs, never write. This is a good practice for clarity and safety.
- If the main container (nginx) exits, the sidecar keeps running. The pod does not complete until all containers exit. This is a key limitation of classical sidecars, especially relevant for Jobs (covered in a later assignment).

---

## 6. Ambassador Pattern

The ambassador pattern places a proxy container alongside the main container. The main container talks to localhost on a well-known port, and the ambassador handles the complexity of connecting to the actual external service. The main container does not need to know about service discovery, connection pooling, TLS termination, or environment-specific endpoints.

Think of the ambassador as a local representative of a remote service. The main container says "connect to localhost:6379 for caching" and the ambassador takes care of routing that connection to the right Redis cluster, handling authentication, managing connection pools, or whatever else the real world demands.

### Example: A Simple Ambassador Proxy

This example creates a main container that connects to localhost:8080 expecting an HTTP response, and an ambassador container that listens on port 8080 and serves a response. In a real system, the ambassador would proxy to an external service; here we simulate it with a simple nc-based listener to demonstrate the pattern:

```bash
kubectl apply -f - -n tutorial-multi-container <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: tut-ambassador
  namespace: tutorial-multi-container
spec:
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      # Wait for the ambassador to start listening
      sleep 3
      echo "App: connecting to cache at localhost:8080..."
      RESPONSE=$(wget -qO- http://localhost:8080/ 2>/dev/null || echo "FAILED")
      echo "App: received response: $RESPONSE"
      sleep 3600
    volumeMounts:
    - name: shared
      mountPath: /shared
  - name: ambassador
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      # Simple HTTP responder simulating a proxy to an external cache
      echo "Ambassador: starting proxy on port 8080..."
      while true; do
        echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\ncached-value-42" | nc -l -p 8080 -w 1
      done
    volumeMounts:
    - name: shared
      mountPath: /shared
  volumes:
  - name: shared
    emptyDir: {}
EOF
```

Verify:

```bash
kubectl wait --for=condition=Ready pod/tut-ambassador -n tutorial-multi-container --timeout=60s

# Check the app's logs to see if it connected to the ambassador
kubectl logs tut-ambassador -c app -n tutorial-multi-container
# Expected: 
# App: connecting to cache at localhost:8080...
# App: received response: cached-value-42

# Check the ambassador's logs
kubectl logs tut-ambassador -c ambassador -n tutorial-multi-container
# Expected: Ambassador: starting proxy on port 8080...
```

The main container thinks it is talking to a local cache. It has no awareness that the ambassador could be routing to a remote Redis cluster, handling TLS, or doing anything else. If you need to change the backend, you swap the ambassador container; the main container's code does not change.

**Real-world ambassador examples** include Envoy sidecar proxies (the foundation of service meshes like Istio), pgbouncer as a database connection pooler, and oauth2-proxy for authentication. The pattern is the same in each case: the main container connects to localhost, and the ambassador handles the external complexity.

---

## 7. Adapter Pattern

The adapter pattern transforms the main container's output into a format expected by an external consumer. The main container produces data in its native format, and the adapter reads that data and converts it. This is useful when you cannot modify the main container's output format (perhaps it is a third-party application) but an external system expects a different format.

Common examples include converting application-specific metrics into Prometheus format, normalizing log formats from legacy applications, and transforming health check output into a standard schema.

### Example: Plain Text to JSON Adapter

This example has a main container that writes status information in plain text to a shared volume, and an adapter container that reads that file and outputs JSON-formatted status to its own stdout:

```bash
kubectl apply -f - -n tutorial-multi-container <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: tut-adapter
  namespace: tutorial-multi-container
spec:
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      # Simulate an app that writes status in plain text
      while true; do
        TIMESTAMP=$(date +%s)
        echo "status=healthy uptime=${TIMESTAMP} connections=42" > /status/app-status.txt
        sleep 5
      done
    volumeMounts:
    - name: status
      mountPath: /status
  - name: adapter
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      # Wait for the status file to appear
      while [ ! -f /status/app-status.txt ]; do
        sleep 1
      done
      echo "Adapter: converting status to JSON format..."
      while true; do
        RAW=$(cat /status/app-status.txt)
        # Parse the space-delimited key=value pairs into JSON
        STATUS=$(echo "$RAW" | awk '{
          for(i=1;i<=NF;i++) {
            split($i,a,"=");
            printf "\"%s\":\"%s\"", a[1], a[2];
            if(i<NF) printf ","
          }
        }')
        echo "{${STATUS}}"
        sleep 5
      done
    volumeMounts:
    - name: status
      mountPath: /status
      readOnly: true
  volumes:
  - name: status
    emptyDir: {}
EOF
```

Verify:

```bash
kubectl wait --for=condition=Ready pod/tut-adapter -n tutorial-multi-container --timeout=60s

# Check the raw status from the main container
kubectl exec tut-adapter -c app -n tutorial-multi-container -- cat /status/app-status.txt
# Expected: status=healthy uptime=<timestamp> connections=42

# Check the adapter's JSON output
kubectl logs tut-adapter -c adapter -n tutorial-multi-container
# Expected: Lines like {"status":"healthy","uptime":"<timestamp>","connections":"42"}
```

The main container produces plain text. An external monitoring system that expects JSON can consume the adapter's stdout. The main container never needed to change.

**The difference between sidecar and adapter** can be subtle. The key distinction is directionality and purpose. A sidecar *augments* the main container (ships its logs, refreshes its config, manages its certificates). An adapter *transforms* the main container's output for an external consumer. In practice, the mechanical implementation is similar (two containers sharing a volume), but naming the pattern correctly helps communicate intent to other engineers.

---

## 8. Native Sidecars

*Requires Kubernetes 1.29+ (beta) or 1.33+ (stable).*

Classical sidecars have a fundamental limitation: there is no way to guarantee that the sidecar starts before the main container, and no way to guarantee that the sidecar shuts down after the main container. Both are regular containers in the `containers` array, and Kubernetes does not enforce ordering between them.

This causes real problems. A main container that depends on its sidecar (for example, an application that needs an Envoy proxy to reach the network) might start before the sidecar is ready, causing connection failures on startup. And when the pod shuts down, the sidecar might terminate before the main container finishes its graceful shutdown. For Jobs, the problem is even worse: when the main container completes its work and exits, the classical sidecar keeps running, and the Job never completes because the pod still has a running container.

**Native sidecars** solve these problems by introducing a new field: `restartPolicy: Always` on init containers. An init container with `restartPolicy: Always` behaves differently from a normal init container:

- It starts in init container order (before regular containers), just like a normal init container.
- Instead of exiting and letting the next init container or main containers start, it *keeps running* alongside the main containers.
- When the main containers exit, the native sidecar is terminated automatically.
- For pod Ready status, native sidecars with readiness probes are considered, but a native sidecar does not block Job completion when the main container finishes.

The `restartPolicy` field on init containers is the distinguishing feature. A normal init container has no `restartPolicy` field (or implicitly has the default behavior of "run once, exit, proceed"). A native sidecar sets `restartPolicy: Always`, which tells Kubernetes "start this in init order, but keep it running."

### Converting the Classical Log-Shipper to a Native Sidecar

Let us take the classical log-shipper sidecar from Section 5 and convert it to a native sidecar. The sidecar moves from the `containers` array to the `initContainers` array, and gets `restartPolicy: Always`:

```bash
kubectl apply -f - -n tutorial-multi-container <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: tut-native-sidecar
  namespace: tutorial-multi-container
spec:
  initContainers:
  - name: log-shipper
    image: busybox:1.36
    restartPolicy: Always
    command:
    - sh
    - -c
    - |
      while [ ! -f /logs/access.log ]; do
        sleep 1
      done
      echo "Native sidecar log-shipper started, tailing access.log..."
      tail -f /logs/access.log
    volumeMounts:
    - name: logs
      mountPath: /logs
      readOnly: true
  containers:
  - name: webserver
    image: nginx:1.25
    volumeMounts:
    - name: logs
      mountPath: /var/log/nginx
  volumes:
  - name: logs
    emptyDir: {}
EOF
```

Wait and verify:

```bash
kubectl wait --for=condition=Ready pod/tut-native-sidecar -n tutorial-multi-container --timeout=60s

# Verify the native sidecar appears in initContainers, not containers
kubectl get pod tut-native-sidecar -n tutorial-multi-container -o jsonpath='{.spec.initContainers[*].name}'
# Expected: log-shipper

# Verify it has restartPolicy: Always
kubectl get pod tut-native-sidecar -n tutorial-multi-container -o jsonpath='{.spec.initContainers[0].restartPolicy}'
# Expected: Always

# Generate traffic
kubectl exec tut-native-sidecar -c webserver -n tutorial-multi-container -- curl -s http://localhost/ > /dev/null
kubectl exec tut-native-sidecar -c webserver -n tutorial-multi-container -- curl -s http://localhost/ > /dev/null

# Check the native sidecar's logs
kubectl logs tut-native-sidecar -c log-shipper -n tutorial-multi-container
# Expected: access log lines from nginx
```

The behavior is functionally identical to the classical sidecar, but with better lifecycle guarantees. The log-shipper started before nginx (as an init container), and if the webserver exits, the log-shipper will be terminated automatically rather than keeping the pod alive.

**When native sidecars matter most: Jobs.** When a Job's main container completes its work and exits 0, the Job should be marked as complete. With a classical sidecar, the sidecar keeps running, the pod never reaches Succeeded status, and the Job hangs indefinitely. A native sidecar is automatically terminated when the main container exits, allowing the Job to complete. Jobs are covered in a later assignment, but this is the primary motivation for native sidecars.

---

## 9. Shared Process Namespace

By default, each container in a pod has its own PID namespace. Container A cannot see container B's processes. You can change this by setting `spec.shareProcessNamespace: true` on the pod. When enabled, all containers share a single PID namespace: processes from every container are visible to every other container.

### Example: Viewing Cross-Container Processes

```bash
kubectl apply -f - -n tutorial-multi-container <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: tut-shared-pid
  namespace: tutorial-multi-container
spec:
  shareProcessNamespace: true
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "App container running"
      sleep 3600
  - name: debug
    image: busybox:1.36
    command:
    - sh
    - -c
    - |
      echo "Debug container running"
      sleep 3600
EOF
```

Verify:

```bash
kubectl wait --for=condition=Ready pod/tut-shared-pid -n tutorial-multi-container --timeout=60s

# From the debug container, list all processes (including app container's)
kubectl exec tut-shared-pid -c debug -n tutorial-multi-container -- ps aux
```

You should see processes from both containers in the output. Without `shareProcessNamespace: true`, the debug container would only see its own `sh` and `sleep` processes.

**Why share the process namespace?** It is useful for debugging sidecars that need to observe or signal the main container's processes. A monitoring sidecar could check if a specific process is running. A debugging container could send `SIGHUP` to trigger a config reload in the main container. Process-sharing is also required for some security scanning sidecars.

**The trade-off: reduced isolation.** With shared PID namespace, any container can send signals to any other container's processes. Container A can `kill -9` a process belonging to container B. The process numbered 1 (PID 1) is no longer the container's own entrypoint but the pod's infrastructure process. This means that if your application relies on being PID 1 for signal handling, it will behave differently. Only enable `shareProcessNamespace` when you have a concrete need for cross-container process visibility.

---

## 10. Debugging Multi-Container Pods

Multi-container pods have unique debugging challenges because a failure in one container can manifest as symptoms in another. The core skill is isolating which container is the problem and why.

### Step 1: Check Pod Status and Container States

```bash
kubectl get pod <pod-name> -n <namespace>
```

The STATUS column shows information about init containers and regular containers. `Init:0/2` means two init containers exist and zero have completed. `Init:Error` or `Init:CrashLoopBackOff` means an init container is failing. Once init containers pass, you will see `Running`, `Error`, or `CrashLoopBackOff` for regular containers.

### Step 2: Describe the Pod for Events

```bash
kubectl describe pod <pod-name> -n <namespace>
```

The Events section at the bottom shows per-container pull, start, and failure events. Look for `Back-off restarting failed container` messages that name the specific container.

### Step 3: Check Per-Container Logs

```bash
# Logs from a specific container
kubectl logs <pod-name> -c <container-name> -n <namespace>

# Logs from a previous crashed instance of a container
kubectl logs <pod-name> -c <container-name> -n <namespace> --previous

# Logs from an init container
kubectl logs <pod-name> -c <init-container-name> -n <namespace>
```

### Step 4: Inspect Container State via YAML

```bash
# Full pod YAML with runtime status
kubectl get pod <pod-name> -n <namespace> -o yaml
```

Look at `.status.containerStatuses` for regular containers and `.status.initContainerStatuses` for init containers. Each entry shows the container's state (waiting, running, terminated), the reason for waiting or termination, and the exit code.

Useful jsonpath queries:

```bash
# Per-container states
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{range .status.containerStatuses[*]}{.name}: {.state}{"\n"}{end}'

# Init container states
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{range .status.initContainerStatuses[*]}{.name}: {.state}{"\n"}{end}'

# Check restart counts
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{range .status.containerStatuses[*]}{.name}: restarts={.restartCount}{"\n"}{end}'
```

### Step 5: Exec into a Running Container

```bash
kubectl exec <pod-name> -c <container-name> -n <namespace> -- <command>

# Interactive shell
kubectl exec -it <pod-name> -c <container-name> -n <namespace> -- sh
```

For debugging shared volume issues, exec into each container and check what is at the expected mount path. For debugging ambassador issues, exec into the main container and try connecting to the ambassador's port.

### Common Diagnostic Patterns

| Symptom | Likely Cause | Check |
|---------|-------------|-------|
| Pod stuck in `Init:0/N` | First init container is failing or hanging | `kubectl logs -c <init-0-name>` |
| Pod stuck in `Init:M/N` (M > 0) | Init container M+1 is failing | `kubectl logs -c <init-M-name>` |
| One container CrashLoopBackOff | That container's command is failing | `kubectl logs -c <name> --previous` |
| Pod Running but main app fails | Sidecar/ambassador issue (wrong port, missing file) | Exec into main, check connectivity |
| All containers running but no data flow | Volume mount path mismatch | Exec into each container, check paths |

---

## 11. Pattern Selection Decision Tree

When you need helper functionality for your application pod, walk through these questions:

**1. Does the helper need to run before the application starts?**
- Yes, and it should exit when done: **Init container**.
- Yes, and it should keep running alongside the application: **Native sidecar** (init container with `restartPolicy: Always`).
- No, it runs alongside the application: proceed to question 2.

**2. What is the helper's relationship to the main container?**
- It augments the main container (ships logs, refreshes certs, exports metrics): **Sidecar**.
- It proxies the main container's outbound connections (database proxy, auth proxy): **Ambassador**.
- It transforms the main container's output for external consumers (format conversion): **Adapter**.

**3. Should this be a sidecar at all, or a separate pod?**
- Sidecar if: shared lifecycle, shared filesystem, tightly coupled, no independent scaling need.
- Separate pod if: independent scaling, different lifecycle, loose coupling, shared by many consumers.

---

## 12. Classical vs Native Sidecar Comparison

| Aspect | Classical Sidecar | Native Sidecar |
|--------|------------------|----------------|
| Declared in | `spec.containers` | `spec.initContainers` |
| Special field | None | `restartPolicy: Always` |
| Startup ordering | No guarantee (may start before or after main) | Starts before main containers (init container ordering) |
| Shutdown ordering | No guarantee (may stop before or after main) | Stops after main containers exit |
| Job completion | Prevents Job completion (keeps running after main exits) | Does not prevent Job completion (terminated when main exits) |
| Pod Ready | Counts toward Ready if it has a readiness probe | Counts toward Ready if it has a readiness probe |
| Minimum K8s version | Any | 1.29 (beta), 1.33 (stable) |
| Use when | Simple sidecars with no ordering dependency | Sidecar must start before main, or pod runs in a Job, or clean shutdown ordering matters |

---

## 13. Reference Commands

### Multi-Container Specific kubectl Flags

```bash
# Logs from a specific container
kubectl logs <pod> -c <container>

# Previous instance logs (after a crash)
kubectl logs <pod> -c <container> --previous

# Exec into a specific container
kubectl exec <pod> -c <container> -- <command>

# Interactive shell in a specific container
kubectl exec -it <pod> -c <container> -- sh

# Stream logs from a specific container
kubectl logs -f <pod> -c <container>

# Logs from all containers at once
kubectl logs <pod> --all-containers
```

### Jsonpath Queries for Per-Container State

```bash
# List all container names
kubectl get pod <pod> -o jsonpath='{.spec.containers[*].name}'

# List all init container names
kubectl get pod <pod> -o jsonpath='{.spec.initContainers[*].name}'

# Container states
kubectl get pod <pod> -o jsonpath='{range .status.containerStatuses[*]}{.name}: {.state}{"\n"}{end}'

# Init container states
kubectl get pod <pod> -o jsonpath='{range .status.initContainerStatuses[*]}{.name}: {.state}{"\n"}{end}'

# Check if a specific init container has restartPolicy Always (native sidecar)
kubectl get pod <pod> -o jsonpath='{.spec.initContainers[0].restartPolicy}'

# Volume mounts for a specific container
kubectl get pod <pod> -o jsonpath='{.spec.containers[?(@.name=="<container>")].volumeMounts}'
```

### Debugging Workflow Cheat Sheet

```bash
# 1. What is the pod status?
kubectl get pod <pod> -n <ns>

# 2. What do the events say?
kubectl describe pod <pod> -n <ns> | tail -20

# 3. Which container is failing?
kubectl get pod <pod> -n <ns> -o jsonpath='{range .status.containerStatuses[*]}{.name}: {.state}{"\n"}{end}'

# 4. What did it log before crashing?
kubectl logs <pod> -c <failing-container> -n <ns> --previous

# 5. Can I exec in and look around?
kubectl exec <pod> -c <container> -n <ns> -- ls /expected/path

# 6. What does the full YAML show?
kubectl get pod <pod> -n <ns> -o yaml | less
```

---

## 14. Cleanup

Remove all tutorial resources:

```bash
kubectl delete namespace tutorial-multi-container
```
