# Application Troubleshooting Tutorial

This tutorial teaches systematic application troubleshooting in Kubernetes. You will learn to diagnose pod failure states, analyze logs and events, identify resource issues, and fix common configuration problems. The methodology here applies to the CKA exam and real-world operations.

All tutorial examples use a dedicated namespace called `tutorial-troubleshooting`.

## Prerequisites

Verify your cluster is up with multiple nodes.

```bash
kubectl get nodes
```

You should see multiple nodes (1 control-plane, 3 workers for optimal practice). Create the tutorial namespace.

```bash
kubectl create namespace tutorial-troubleshooting
```

## Part 1: Troubleshooting Methodology

Effective troubleshooting follows a systematic approach. Do not jump to conclusions. Gather data first.

### The Diagnostic Sequence

When a pod is not working as expected, run these commands in order.

1. Get pod status overview.

```bash
kubectl get pod <name> -n <namespace>
```

This shows STATUS (Running, Pending, CrashLoopBackOff, etc.), READY count, and RESTARTS.

2. Describe the pod for details and events.

```bash
kubectl describe pod <name> -n <namespace>
```

Look at: Conditions, Container statuses (State, Last State, Reason), and Events at the bottom.

3. Check logs.

```bash
kubectl logs <name> -n <namespace>
```

For crashed containers, use --previous to see the last run's logs.

```bash
kubectl logs <name> -n <namespace> --previous
```

For multi-container pods, specify the container.

```bash
kubectl logs <name> -n <namespace> -c <container>
```

4. Get the full YAML for detailed inspection.

```bash
kubectl get pod <name> -n <namespace> -o yaml
```

### Event Analysis

Events are critical for troubleshooting. They show what Kubernetes tried to do and what failed.

```bash
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

This shows events sorted by time, most recent last.

## Part 2: Pod Failure States

### CrashLoopBackOff

The container keeps crashing and Kubernetes keeps restarting it with exponential backoff.

Create an example.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: crasher
  namespace: tutorial-troubleshooting
spec:
  containers:
  - name: crasher
    image: busybox:1.36
    command: ["sh", "-c", "exit 1"]
EOF
```

Wait 30 seconds, then check status.

```bash
kubectl get pod crasher -n tutorial-troubleshooting
```

You will see CrashLoopBackOff status with increasing restart count.

Diagnose it.

```bash
kubectl describe pod crasher -n tutorial-troubleshooting
kubectl logs crasher -n tutorial-troubleshooting --previous
```

The describe shows Last State with exit code 1. The previous logs show what happened before the crash.

Fix: correct the command so it does not exit immediately with an error.

```bash
kubectl delete pod crasher -n tutorial-troubleshooting
```

### ImagePullBackOff

The container image cannot be pulled.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: bad-image
  namespace: tutorial-troubleshooting
spec:
  containers:
  - name: app
    image: nginx:nonexistent-tag-xyz123
EOF
```

Check status.

```bash
kubectl get pod bad-image -n tutorial-troubleshooting
kubectl describe pod bad-image -n tutorial-troubleshooting
```

Events show "Failed to pull image" with the specific error. Common causes: typo in image name or tag, private registry without credentials, network issues.

```bash
kubectl delete pod bad-image -n tutorial-troubleshooting
```

### Pending

The pod cannot be scheduled.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pending-demo
  namespace: tutorial-troubleshooting
spec:
  containers:
  - name: app
    image: nginx:1.25
  nodeSelector:
    disktype: ssd
EOF
```

Check status.

```bash
kubectl get pod pending-demo -n tutorial-troubleshooting
kubectl describe pod pending-demo -n tutorial-troubleshooting
```

Events show "FailedScheduling" with reason "node(s) didn't match Pod's node affinity/selector". The nodeSelector requires a label that no node has.

Common Pending causes: insufficient resources on nodes, nodeSelector or affinity not matching, taints without tolerations, PVC not bound.

```bash
kubectl delete pod pending-demo -n tutorial-troubleshooting
```

## Part 3: Crash Diagnosis from Logs

Logs are essential for understanding why containers crash.

### Exit Codes

Common exit codes and their meanings.

0 = Success (but if restartPolicy is Always, it restarts anyway)
1 = General error
137 = Killed by SIGKILL (often OOMKilled)
143 = Killed by SIGTERM (graceful shutdown)

### Using --previous

When a container crashes and restarts, current logs show the new run. Use --previous for the crashed run.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: log-demo
  namespace: tutorial-troubleshooting
spec:
  containers:
  - name: logger
    image: busybox:1.36
    command: ["sh", "-c", "echo 'Starting...'; sleep 5; echo 'About to fail'; exit 1"]
EOF
```

Wait for it to crash and restart.

```bash
sleep 20
kubectl logs log-demo -n tutorial-troubleshooting --previous
```

You see the output from before the crash: "Starting...", then "About to fail".

```bash
kubectl delete pod log-demo -n tutorial-troubleshooting
```

## Part 4: Resource Exhaustion

### OOMKilled

When a container exceeds its memory limit, it gets killed.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: memory-hog
  namespace: tutorial-troubleshooting
spec:
  containers:
  - name: hog
    image: busybox:1.36
    command: ["sh", "-c", "dd if=/dev/zero of=/dev/null bs=1M"]
    resources:
      limits:
        memory: 10Mi
EOF
```

Wait and check.

```bash
sleep 30
kubectl get pod memory-hog -n tutorial-troubleshooting
kubectl describe pod memory-hog -n tutorial-troubleshooting
```

The Last State shows Reason: OOMKilled. This means the container exceeded its memory limit.

```bash
kubectl delete pod memory-hog -n tutorial-troubleshooting
```

### Checking Resource Usage

Use kubectl top to see actual resource consumption.

```bash
kubectl top pods -n tutorial-troubleshooting
```

This requires metrics-server to be installed. If pods are using memory close to their limits, they are at risk of OOMKilled.

## Part 5: Configuration Issues

### Missing ConfigMap

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: missing-config
  namespace: tutorial-troubleshooting
spec:
  containers:
  - name: app
    image: nginx:1.25
    envFrom:
    - configMapRef:
        name: app-config
EOF
```

Check status.

```bash
kubectl get pod missing-config -n tutorial-troubleshooting
kubectl describe pod missing-config -n tutorial-troubleshooting
```

Events show "configmap 'app-config' not found". The pod cannot start because it references a ConfigMap that does not exist.

Fix by creating the ConfigMap.

```bash
kubectl create configmap app-config --from-literal=KEY=value -n tutorial-troubleshooting
kubectl delete pod missing-config -n tutorial-troubleshooting
# Recreate the pod
```

```bash
kubectl delete pod missing-config -n tutorial-troubleshooting --force --grace-period=0
kubectl delete configmap app-config -n tutorial-troubleshooting
```

### Wrong Key in Secret

```bash
kubectl create secret generic db-secret --from-literal=password=secret123 -n tutorial-troubleshooting

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: wrong-key
  namespace: tutorial-troubleshooting
spec:
  containers:
  - name: app
    image: nginx:1.25
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: wrongkey
EOF
```

Check events.

```bash
kubectl describe pod wrong-key -n tutorial-troubleshooting
```

The error shows the key "wrongkey" is not found in the secret. Fix by using the correct key "password".

```bash
kubectl delete pod wrong-key -n tutorial-troubleshooting
kubectl delete secret db-secret -n tutorial-troubleshooting
```

## Part 6: Volume Mount Failures

### PVC Not Bound

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: unbound-pvc
  namespace: tutorial-troubleshooting
spec:
  containers:
  - name: app
    image: nginx:1.25
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: nonexistent-pvc
EOF
```

Check status.

```bash
kubectl get pod unbound-pvc -n tutorial-troubleshooting
kubectl describe pod unbound-pvc -n tutorial-troubleshooting
```

The pod is Pending because the PVC does not exist. Events show "persistentvolumeclaim 'nonexistent-pvc' not found".

```bash
kubectl delete pod unbound-pvc -n tutorial-troubleshooting
```

## Part 7: Service Selector Mismatches

Services select pods by labels. If selectors do not match, the service has no endpoints.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: tutorial-troubleshooting
  labels:
    app: web
spec:
  containers:
  - name: nginx
    image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: tutorial-troubleshooting
spec:
  selector:
    app: wronglabel
  ports:
  - port: 80
EOF
```

Check endpoints.

```bash
kubectl get endpoints web-svc -n tutorial-troubleshooting
```

The endpoints are empty because no pods match the selector "app: wronglabel".

Diagnose by comparing.

```bash
kubectl get pod web -n tutorial-troubleshooting --show-labels
kubectl get svc web-svc -n tutorial-troubleshooting -o jsonpath='{.spec.selector}'
```

Fix by updating the service selector to match the pod label.

```bash
kubectl delete svc web-svc -n tutorial-troubleshooting
kubectl delete pod web -n tutorial-troubleshooting
```

## Part 8: Debugging with Ephemeral Containers

Sometimes logs and describe are not enough. You need to run commands inside a running pod, but the container lacks debugging tools like curl, netcat, or a shell. Ephemeral containers solve this by injecting a temporary debugging container into an already-running pod without restarting it.

### When to Use kubectl debug

Use `kubectl debug` when the pod is running but misbehaving and you need to inspect its environment, network connectivity, or filesystem without disturbing the running workload. Common scenarios include containers built from distroless or minimal images that lack shells, networking issues where you need to test connectivity from inside the pod's network namespace, or filesystem inspection when you need to examine mounted volumes or application state.

### Basic Pod Debugging

Create a pod with a minimal image that lacks debugging tools.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: minimal-app
  namespace: tutorial-troubleshooting
spec:
  containers:
  - name: app
    image: gcr.io/distroless/static-debian12:nonroot
    command: ["sleep", "infinity"]
EOF
```

Wait for the pod to be running.

```bash
kubectl wait --for=condition=Ready pod/minimal-app -n tutorial-troubleshooting --timeout=60s
```

Try to exec into it.

```bash
kubectl exec -it minimal-app -n tutorial-troubleshooting -- sh
```

This fails because the distroless image contains no shell. Now use kubectl debug to add an ephemeral debugging container.

```bash
kubectl debug minimal-app -n tutorial-troubleshooting -it --image=busybox:1.36 --target=app
```

This launches an interactive busybox container that shares the process namespace with the target container. The `--target=app` flag means the ephemeral container shares the PID namespace of the "app" container, allowing you to see its processes via `ps` and inspect its filesystem at `/proc/<pid>/root`.

Inside the debug session, list processes.

```bash
ps aux
```

You see both the sleep process from the original container and the sh process from the debugging container. Exit the debug session.

```bash
exit
```

The ephemeral container remains attached to the pod. Check it.

```bash
kubectl describe pod minimal-app -n tutorial-troubleshooting
```

You see an Ephemeral Containers section listing the debugging container. Ephemeral containers persist for the pod's lifetime. They cannot be removed or restarted individually. To clean up, delete the pod.

```bash
kubectl delete pod minimal-app -n tutorial-troubleshooting
```

### Debugging Without Targeting a Container

If you omit the `--target` flag, the ephemeral container runs in the pod but does not share the PID namespace with any specific container. This is useful for network debugging where you need the pod's network namespace but not its process space.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: network-test
  namespace: tutorial-troubleshooting
  labels:
    app: network-test
spec:
  containers:
  - name: app
    image: nginx:1.27
---
apiVersion: v1
kind: Service
metadata:
  name: network-test-svc
  namespace: tutorial-troubleshooting
spec:
  selector:
    app: network-test
  ports:
  - port: 80
EOF
```

Wait for the pod.

```bash
kubectl wait --for=condition=Ready pod/network-test -n tutorial-troubleshooting --timeout=60s
```

Debug it without targeting.

```bash
kubectl debug network-test -n tutorial-troubleshooting -it --image=curlimages/curl:8.5.0 -- sh
```

Inside the debug container, test the service.

```bash
curl http://network-test-svc
# You should see the nginx welcome page HTML

exit
```

The debug container sees the same network namespace as the pod, so it can reach localhost and the pod's IP, but it does not share the PID namespace.

```bash
kubectl delete pod network-test -n tutorial-troubleshooting
kubectl delete svc network-test-svc -n tutorial-troubleshooting
```

### Ephemeral Container Limitations

Ephemeral containers cannot be removed or restarted once added. They do not count toward the pod's resource requests or limits. They cannot have ports, probes, or lifecycle hooks. If you need to run a new debug session with different settings, you must delete and recreate the pod. Ephemeral containers are designed for temporary interactive debugging, not long-running sidecars.

### Copy Mode: Debugging by Pod Duplication

If ephemeral containers are too limiting, use `kubectl debug --copy-to` to create a modified copy of the pod. This mode duplicates the pod with changes such as a different image or command, allowing you to troubleshoot without affecting the original.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: crasher-original
  namespace: tutorial-troubleshooting
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "exit 1"]
  restartPolicy: Never
EOF
```

Wait for it to crash.

```bash
sleep 10
kubectl get pod crasher-original -n tutorial-troubleshooting
```

Now create a copy with a different command to prevent the crash.

```bash
kubectl debug crasher-original -n tutorial-troubleshooting --copy-to=crasher-debug --container=app -- sh -c "sleep 3600"
```

This creates a new pod named crasher-debug with the same spec but replaces the app container's command. Check both pods.

```bash
kubectl get pods -n tutorial-troubleshooting
```

The original is in Error or CrashLoopBackOff. The copy is Running. You can now exec into the copy to investigate.

```bash
kubectl exec -it crasher-debug -n tutorial-troubleshooting -- sh -c "echo 'Debug session active'; exit"
```

Clean up both.

```bash
kubectl delete pod crasher-original crasher-debug -n tutorial-troubleshooting
```

Copy mode is useful when you need to change the pod spec or when the original pod is in a state that prevents exec or ephemeral container injection.

## Cleanup

Remove all tutorial resources.

```bash
kubectl delete namespace tutorial-troubleshooting
```

## Troubleshooting Quick Reference

| Symptom | First Commands | Common Causes |
|---------|----------------|---------------|
| CrashLoopBackOff | `logs --previous`, `describe` | Wrong command, missing dependency, crash on startup |
| ImagePullBackOff | `describe` events | Wrong image name/tag, private registry, network |
| Pending | `describe` events | Resources, nodeSelector, taints, unbound PVC |
| OOMKilled | `describe` Last State | Memory limit too low, memory leak |
| CreateContainerError | `describe` events | Missing ConfigMap/Secret, invalid mount |
| Empty Endpoints | Compare pod labels and service selector | Selector mismatch, pods not ready |

## Diagnostic Commands Cheat Sheet

| Task | Command |
|------|---------|
| Pod status | `kubectl get pod <name> -n <ns>` |
| Pod details | `kubectl describe pod <name> -n <ns>` |
| Current logs | `kubectl logs <name> -n <ns>` |
| Previous logs | `kubectl logs <name> -n <ns> --previous` |
| Container logs | `kubectl logs <name> -n <ns> -c <container>` |
| Events sorted | `kubectl get events -n <ns> --sort-by='.lastTimestamp'` |
| Resource usage | `kubectl top pods -n <ns>` |
| Pod labels | `kubectl get pod -n <ns> --show-labels` |
| Service selector | `kubectl get svc <name> -n <ns> -o jsonpath='{.spec.selector}'` |
| Endpoints | `kubectl get endpoints <name> -n <ns>` |
| Debug with ephemeral container | `kubectl debug <pod> -n <ns> -it --image=<img> --target=<container>` |
| Debug without targeting | `kubectl debug <pod> -n <ns> -it --image=<img>` |
| Debug by copying pod | `kubectl debug <pod> -n <ns> --copy-to=<new-name> --container=<c> -- <cmd>` |
