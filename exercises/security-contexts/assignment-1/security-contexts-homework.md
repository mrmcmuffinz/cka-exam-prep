# Security Contexts Homework: User and Group Security

This homework contains 15 progressive exercises to practice user and group identity controls in Kubernetes security contexts. Complete the tutorial before attempting these exercises.

---

## Level 1: Basic Identity Controls

### Exercise 1.1

**Objective:** Run a container as a specific non-root user and verify the identity.

**Setup:**

```bash
kubectl create namespace ex-1-1
```

**Task:**

Create a pod named `app-runner` in namespace `ex-1-1` using the `nginx:1.25` image. Configure the pod to run as user ID 1001. The pod should run continuously.

**Verification:**

```bash
# Check the user ID inside the container
kubectl exec -n ex-1-1 app-runner -- id

# Expected: uid=1001

# Verify the pod is running
kubectl get pod -n ex-1-1 app-runner
```

---

### Exercise 1.2

**Objective:** Configure both user and group identity for a container.

**Setup:**

```bash
kubectl create namespace ex-1-2
```

**Task:**

Create a pod named `group-runner` in namespace `ex-1-2` using the `busybox:1.36` image with command `["sleep", "3600"]`. Configure the pod to run as user ID 1002 and primary group ID 3002.

**Verification:**

```bash
# Check both user and group IDs
kubectl exec -n ex-1-2 group-runner -- id

# Expected: uid=1002 gid=3002 groups=3002

# Verify the pod is running
kubectl get pod -n ex-1-2 group-runner
```

---

### Exercise 1.3

**Objective:** Use runAsNonRoot to enforce non-root execution.

**Setup:**

```bash
kubectl create namespace ex-1-3
```

**Task:**

Create a pod named `secure-app` in namespace `ex-1-3` using the `alpine:3.20` image with command `["sleep", "3600"]`. Configure the pod to:
- Run as user ID 1003
- Enforce that the container cannot run as root (runAsNonRoot)

**Verification:**

```bash
# Verify the pod is running (not stuck in error state)
kubectl get pod -n ex-1-3 secure-app

# Expected: STATUS should be Running

# Verify the user is non-root
kubectl exec -n ex-1-3 secure-app -- id

# Expected: uid=1003 (not 0)
```

---

## Level 2: fsGroup and Volumes

### Exercise 2.1

**Objective:** Use fsGroup to set volume ownership for write access.

**Setup:**

```bash
kubectl create namespace ex-2-1
```

**Task:**

Create a pod named `volume-writer` in namespace `ex-2-1` using the `busybox:1.36` image with command `["sleep", "3600"]`. Configure the pod to:
- Run as user ID 1001
- Run as group ID 2001
- Use fsGroup 3001 for volume ownership
- Mount an emptyDir volume at /data

The container must be able to create files in /data.

**Verification:**

```bash
# Check the group memberships
kubectl exec -n ex-2-1 volume-writer -- id

# Expected: groups should include 3001

# Check the ownership of /data
kubectl exec -n ex-2-1 volume-writer -- ls -la /data

# Expected: /data should be owned by group 3001

# Verify write access
kubectl exec -n ex-2-1 volume-writer -- touch /data/testfile
kubectl exec -n ex-2-1 volume-writer -- ls -la /data/testfile

# Expected: file created successfully, owned by user 1001 and group 3001
```

---

### Exercise 2.2

**Objective:** Verify how fsGroup affects file ownership in volumes.

**Setup:**

```bash
kubectl create namespace ex-2-2
```

**Task:**

Create a pod named `ownership-test` in namespace `ex-2-2` using the `busybox:1.36` image. Configure the pod to:
- Run as user ID 1002
- Use fsGroup 4002
- Mount an emptyDir volume at /shared
- Run a command that creates a file, then sleeps: `["sh", "-c", "echo hello > /shared/greeting.txt && sleep 3600"]`

**Verification:**

```bash
# Wait for the pod to be ready
kubectl wait --for=condition=Ready pod/ownership-test -n ex-2-2 --timeout=60s

# Check the file ownership
kubectl exec -n ex-2-2 ownership-test -- ls -la /shared/greeting.txt

# Expected: file should be owned by user 1002 and group 4002

# Verify the file content
kubectl exec -n ex-2-2 ownership-test -- cat /shared/greeting.txt

# Expected: hello
```

---

### Exercise 2.3

**Objective:** Configure supplementalGroups for additional group memberships.

**Setup:**

```bash
kubectl create namespace ex-2-3
```

**Task:**

Create a pod named `multi-group` in namespace `ex-2-3` using the `busybox:1.36` image with command `["sleep", "3600"]`. Configure the pod to:
- Run as user ID 1003
- Run as group ID 3003
- Have supplemental groups 5001, 5002, and 5003

**Verification:**

```bash
# Check all group memberships
kubectl exec -n ex-2-3 multi-group -- id

# Expected: uid=1003 gid=3003 groups=3003,5001,5002,5003

# Verify the pod is running
kubectl get pod -n ex-2-3 multi-group
```

---

## Level 3: Debugging Permission Issues

### Exercise 3.1

**Objective:** A pod is failing to write to its volume. Find and fix the issue.

**Setup:**

```bash
kubectl create namespace ex-3-1

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

**Task:**

The pod above is failing to start properly. Diagnose why the container cannot write to the /data directory and fix the pod configuration so it can write successfully.

**Verification:**

```bash
# After fixing, verify the pod is running
kubectl get pod -n ex-3-1 data-processor

# Expected: STATUS should be Running

# Verify the file was created
kubectl exec -n ex-3-1 data-processor -- cat /data/output.txt

# Expected: processing data
```

---

### Exercise 3.2

**Objective:** A pod with runAsNonRoot is failing to start. Find and fix the issue.

**Setup:**

```bash
kubectl create namespace ex-3-2

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secure-worker
  namespace: ex-3-2
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: worker
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
```

**Task:**

The pod above is stuck and not starting. Diagnose the issue and fix the pod configuration so it starts successfully while still enforcing non-root execution.

**Verification:**

```bash
# After fixing, verify the pod is running
kubectl get pod -n ex-3-2 secure-worker

# Expected: STATUS should be Running

# Verify the user is non-root
kubectl exec -n ex-3-2 secure-worker -- id

# Expected: uid should not be 0
```

---

### Exercise 3.3

**Objective:** A multi-container pod has permission issues with shared storage. Find and fix the issue.

**Setup:**

```bash
kubectl create namespace ex-3-3

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: data-pipeline
  namespace: ex-3-3
spec:
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

**Task:**

The pod above has two containers that need to share data through a volume. The producer writes data and the consumer reads it. However, the consumer may have trouble reading data written by the producer. Diagnose any permission issues and fix the configuration so both containers can reliably share data.

**Verification:**

```bash
# After fixing, verify the pod is running
kubectl get pod -n ex-3-3 data-pipeline

# Expected: Both containers should be Running

# Wait for the consumer to finish its sleep
sleep 15

# Check consumer logs
kubectl logs -n ex-3-3 data-pipeline -c consumer

# Expected: should show "data payload"
```

---

## Level 4: Precedence and Multi-Container

### Exercise 4.1

**Objective:** Override pod-level security settings at the container level.

**Setup:**

```bash
kubectl create namespace ex-4-1
```

**Task:**

Create a pod named `mixed-users` in namespace `ex-4-1` with the following configuration:
- Pod-level runAsUser: 1000
- Pod-level runAsGroup: 2000
- Two containers, both using `busybox:1.36` with command `["sleep", "3600"]`:
  - Container named `default-user` that inherits the pod-level settings
  - Container named `admin-user` that overrides to run as user 3000 and group 4000

**Verification:**

```bash
# Check identity in the default-user container
kubectl exec -n ex-4-1 mixed-users -c default-user -- id

# Expected: uid=1000 gid=2000 groups=2000

# Check identity in the admin-user container
kubectl exec -n ex-4-1 mixed-users -c admin-user -- id

# Expected: uid=3000 gid=4000 groups=4000
```

---

### Exercise 4.2

**Objective:** Configure a pod where different containers have different user identities but share a volume.

**Setup:**

```bash
kubectl create namespace ex-4-2
```

**Task:**

Create a pod named `collaborative-app` in namespace `ex-4-2` with:
- fsGroup: 8000 (for shared volume access)
- Two containers:
  - Container `writer-a` running as user 1001, writes "message from A" to /shared/from-a.txt
  - Container `writer-b` running as user 2002, writes "message from B" to /shared/from-b.txt (after a 5 second delay)
- Both containers mount an emptyDir volume at /shared
- Both containers sleep after writing

Both containers must be able to read files written by the other container.

**Verification:**

```bash
# Wait for the pod to be ready
kubectl wait --for=condition=Ready pod/collaborative-app -n ex-4-2 --timeout=60s

# Wait for writer-b to finish
sleep 10

# Verify writer-a can read writer-b's file
kubectl exec -n ex-4-2 collaborative-app -c writer-a -- cat /shared/from-b.txt

# Expected: message from B

# Verify writer-b can read writer-a's file
kubectl exec -n ex-4-2 collaborative-app -c writer-b -- cat /shared/from-a.txt

# Expected: message from A

# Check that files are owned by the fsGroup
kubectl exec -n ex-4-2 collaborative-app -c writer-a -- ls -la /shared/

# Expected: files should be owned by group 8000
```

---

### Exercise 4.3

**Objective:** Combine fsGroup with supplementalGroups across multiple containers.

**Setup:**

```bash
kubectl create namespace ex-4-3
```

**Task:**

Create a pod named `group-matrix` in namespace `ex-4-3` with:
- Pod-level settings:
  - fsGroup: 9000
  - supplementalGroups: [9001, 9002]
- Container `standard` using busybox:1.36 with command `["sleep", "3600"]`:
  - runAsUser: 1000
  - runAsGroup: 2000
- Container `elevated` using busybox:1.36 with command `["sleep", "3600"]`:
  - runAsUser: 3000
  - runAsGroup: 4000
  - Additional supplementalGroups are NOT specified at container level

Both containers should inherit the pod-level supplementalGroups and fsGroup.

**Verification:**

```bash
# Check identity in the standard container
kubectl exec -n ex-4-3 group-matrix -c standard -- id

# Expected: uid=1000 gid=2000 groups=2000,9000,9001,9002

# Check identity in the elevated container
kubectl exec -n ex-4-3 group-matrix -c elevated -- id

# Expected: uid=3000 gid=4000 groups=4000,9000,9001,9002

# Both should have 9000 (fsGroup), 9001, and 9002 in their groups
```

---

## Level 5: Complex Scenarios

### Exercise 5.1

**Objective:** Configure a pod for an application that requires a specific UID/GID and shared storage.

**Setup:**

```bash
kubectl create namespace ex-5-1
```

**Task:**

Create a pod named `legacy-app` in namespace `ex-5-1` that simulates running a legacy application with specific requirements:
- The application requires UID 1500 and GID 1500
- It writes logs to /var/log/app (must be writable)
- It reads configuration from /etc/app/config (you will use a ConfigMap for this)
- It stores data in /data (must be writable and persist within the pod lifecycle)

Configure:
- A ConfigMap named `app-config` with a key `settings.conf` containing `debug=true`
- A pod with appropriate security context
- Appropriate volumes for logs (emptyDir), config (ConfigMap), and data (emptyDir)
- Container using busybox:1.36 that runs: `["sh", "-c", "cat /etc/app/config/settings.conf && echo 'log entry' > /var/log/app/app.log && echo 'data written' > /data/store.txt && sleep 3600"]`

**Verification:**

```bash
# Verify the pod is running
kubectl get pod -n ex-5-1 legacy-app

# Expected: Running

# Verify the user identity
kubectl exec -n ex-5-1 legacy-app -- id

# Expected: uid=1500 gid=1500

# Verify config was read
kubectl logs -n ex-5-1 legacy-app

# Expected: should show debug=true

# Verify log was written
kubectl exec -n ex-5-1 legacy-app -- cat /var/log/app/app.log

# Expected: log entry

# Verify data was written
kubectl exec -n ex-5-1 legacy-app -- cat /data/store.txt

# Expected: data written

# Verify the app can write to log directory
kubectl exec -n ex-5-1 legacy-app -- ls -la /var/log/app/

# Expected: files owned by user 1500 and appropriate group
```

---

### Exercise 5.2

**Objective:** Debug a multi-container pod with complex permission issues.

**Setup:**

```bash
kubectl create namespace ex-5-2

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
  containers:
  - name: initializer
    image: busybox:1.36
    command: ["sh", "-c", "cp /config/input.txt /work/input.txt && sleep 3600"]
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

**Task:**

The data pipeline pod above has multiple issues preventing it from working correctly. The initializer container should copy input data to a work directory, and the processor container should read and process that data. Fix all issues so the pipeline works correctly.

**Verification:**

```bash
# After fixing, verify the pod is running
kubectl get pod -n ex-5-2 data-pipeline

# Expected: Both containers Running

# Wait for processor to complete its task
sleep 10

# Verify the output file exists and has content
kubectl exec -n ex-5-2 data-pipeline -c processor -- cat /work/output.txt

# Expected: initial data
```

---

### Exercise 5.3

**Objective:** Design a security context strategy for a microservice pod.

**Setup:**

```bash
kubectl create namespace ex-5-3
```

**Task:**

Design and implement a pod named `secure-microservice` in namespace `ex-5-3` that follows security best practices:

1. The pod should have three containers:
   - `api` (nginx:1.25): The main API server, runs as user 101 (nginx user)
   - `sidecar` (busybox:1.36): A log shipper that reads from a shared log directory, runs as user 1000
   - `metrics` (busybox:1.36): A metrics exporter, runs as user 2000

2. Security requirements:
   - All containers must run as non-root (enforce with runAsNonRoot)
   - Shared log volume at /var/log/shared that all containers can write to
   - Each container should have appropriate user and group settings
   - Use fsGroup to enable shared volume access

3. The api container should write "api started" to /var/log/shared/api.log
4. The sidecar should sleep for 5 seconds then read the api log
5. The metrics container should write "metrics: 100" to /var/log/shared/metrics.log

**Verification:**

```bash
# Verify the pod is running
kubectl get pod -n ex-5-3 secure-microservice

# Expected: All containers Running

# Verify each container is running as non-root
kubectl exec -n ex-5-3 secure-microservice -c api -- id
# Expected: uid=101 (not 0)

kubectl exec -n ex-5-3 secure-microservice -c sidecar -- id
# Expected: uid=1000 (not 0)

kubectl exec -n ex-5-3 secure-microservice -c metrics -- id
# Expected: uid=2000 (not 0)

# Wait for containers to write their files
sleep 10

# Verify sidecar can read api log
kubectl exec -n ex-5-3 secure-microservice -c sidecar -- cat /var/log/shared/api.log
# Expected: api started

# Verify api can read metrics log
kubectl exec -n ex-5-3 secure-microservice -c api -- cat /var/log/shared/metrics.log
# Expected: metrics: 100

# Verify all log files are owned by the fsGroup
kubectl exec -n ex-5-3 secure-microservice -c sidecar -- ls -la /var/log/shared/
# Expected: files should be owned by the fsGroup
```

---

## Cleanup

Delete all exercise namespaces:

```bash
kubectl delete namespace ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3
```

---

## Key Takeaways

1. **runAsUser and runAsGroup** control the UID and GID of container processes
2. **fsGroup** is essential for volume write access when running as non-root
3. **runAsNonRoot** validates but does not set the user identity
4. Container-level security contexts override pod-level settings
5. **supplementalGroups** adds extra group memberships beyond the primary group
6. When containers share volumes, use fsGroup to ensure all containers can access the data
7. Always verify security settings with `kubectl exec -- id` inside the container
