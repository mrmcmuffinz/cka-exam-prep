# Pod Fundamentals Homework Answers

This file contains complete solutions for all 15 exercises in `pod-fundamentals-homework.md`, along with diagnostic reasoning for the debugging exercises, a common mistakes section, and a verification cheat sheet. Where both imperative and declarative approaches are reasonable, both are shown. For multi-container pods, init container pods, and anything with downward API or volume mounts, declarative YAML is the only realistic approach, and this is called out where it applies.

-----

## Exercise 1.1 Solution

### Imperative

```bash
kubectl run web --image=nginx:1.25 -n ex-1-1
```

### Declarative

```bash
kubectl run web --image=nginx:1.25 -n ex-1-1 --dry-run=client -o yaml > pod.yaml
# (optionally edit pod.yaml)
kubectl apply -f pod.yaml
```

Equivalent YAML:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: ex-1-1
spec:
  containers:
  - name: web
    image: nginx:1.25
```

The simplest possible pod needs a name, a container name, and an image. Everything else defaults. Nginx listens on port 80 and stays running, so the pod reaches `Running` and stays there under the default `restartPolicy: Always`.

-----

## Exercise 1.2 Solution

### Imperative

```bash
kubectl run greeter --image=busybox:1.36 --restart=Never -n ex-1-2 -- echo hello world
```

The `--restart=Never` flag maps to `restartPolicy: Never`. Everything after `--` becomes the container command.

### Declarative

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: greeter
  namespace: ex-1-2
spec:
  restartPolicy: Never
  containers:
  - name: greeter
    image: busybox:1.36
    command: ["echo", "hello", "world"]
```

Because `restartPolicy: Never` is used and the command exits with code 0, the pod's final phase is `Succeeded`. With the default `Always`, the pod would keep restarting the echo command forever, which is not what you want for a one-shot task.

-----

## Exercise 1.3 Solution

### Imperative

```bash
kubectl run envpod --image=busybox:1.36 -n ex-1-3 \
  --env="APP_NAME=demo" --env="APP_TIER=frontend" \
  -- sh -c "env; sleep 300"
```

### Declarative

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: envpod
  namespace: ex-1-3
spec:
  containers:
  - name: envpod
    image: busybox:1.36
    command: ["sh", "-c"]
    args: ["env; sleep 300"]
    env:
    - name: APP_NAME
      value: demo
    - name: APP_TIER
      value: frontend
```

The container needs something that keeps it alive long enough for `kubectl exec` to work (`sleep 300` is fine). Without that, busybox would exit immediately after `env` runs, and the default `restartPolicy: Always` would put it in `CrashLoopBackOff` since each run exits cleanly but very fast.

-----

## Exercise 2.1 Solution

Declarative is the cleanest approach here because of the labels and command/args split.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: runner
  namespace: ex-2-1
  labels:
    app: runner
    tier: batch
    environment: homework
spec:
  restartPolicy: OnFailure
  containers:
  - name: runner
    image: busybox:1.36
    command: ["sh", "-c"]
    args: ["echo starting; sleep 3; echo finishing"]
```

The `command` list is `["sh", "-c"]` and the shell command string goes in `args`. Because the shell command exits cleanly (exit 0) and `restartPolicy` is `OnFailure`, the pod reaches `Succeeded` and stays there. If `restartPolicy` had been `Always`, the pod would have cycled forever. If it had been `Never`, the same `Succeeded` outcome would result, but `OnFailure` is what was asked for.

-----

## Exercise 2.2 Solution

Declarative is required for multi-container pods with shared volumes.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sharers
  namespace: ex-2-2
spec:
  restartPolicy: Never
  volumes:
  - name: shared
    emptyDir: {}
  containers:
  - name: producer
    image: busybox:1.36
    command: ["sh", "-c"]
    args: ["echo 'hello from producer' > /data/message.txt; sleep 300"]
    volumeMounts:
    - name: shared
      mountPath: /data
  - name: consumer
    image: busybox:1.36
    command: ["sh", "-c"]
    args: ["sleep 3; cat /data/message.txt; sleep 300"]
    volumeMounts:
    - name: shared
      mountPath: /data
```

Two container names (`producer` and `consumer`), both mount the same `shared` emptyDir at `/data`, and the consumer sleeps briefly before reading to give the producer a chance to write. The `sleep 300` tails keep both containers alive for verification. `restartPolicy: Never` is chosen so that if anything does exit, it stays exited rather than looping.

An alternative is to pick `restartPolicy: OnFailure` with a cleaner consumer that exits after reading; this also works as long as the consumer's exit code is 0, because `OnFailure` does not restart on clean exit. Either is acceptable.

-----

## Exercise 2.3 Solution

Declarative is the natural choice for downward API env vars. (`kubectl run` can set literal env vars but not downward API references.)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: metapod
  namespace: ex-2-3
spec:
  containers:
  - name: metapod
    image: busybox:1.36
    command: ["sh", "-c"]
    args: ["env; sleep 300"]
    env:
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
```

Each env var uses `valueFrom.fieldRef.fieldPath` to pull a runtime value out of the pod's metadata or spec. `metadata.name`, `metadata.namespace`, and `spec.nodeName` are the three most commonly used fields. `spec.nodeName` is populated by the scheduler before the container starts.

-----

## Exercise 3.1 Solution

### Diagnosis

```bash
kubectl get pod broken-1 -n ex-3-1
# shows STATUS = ErrImagePull or ImagePullBackOff

kubectl describe pod broken-1 -n ex-3-1
# Events section shows: "Failed to pull image nginx:1.25-nonexistent-tag"
```

The image tag `nginx:1.25-nonexistent-tag` does not exist in Docker Hub, so the container runtime cannot pull it. The pod stays in `Pending` phase with container status `Waiting` and reason `ErrImagePull` or `ImagePullBackOff`.

### Fix

Edit the pod to use a valid tag. Because pods are largely immutable, the easiest fix is delete and recreate.

```bash
kubectl delete pod broken-1 -n ex-3-1

cat <<'EOF' | kubectl apply -n ex-3-1 -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-1
spec:
  containers:
  - name: web
    image: nginx:1.25
EOF
```

You could also `kubectl edit pod broken-1 -n ex-3-1` and change the image in place; for an image field, that works because image changes are one of the few mutable fields on a running pod. Either approach is acceptable on the exam, though delete-and-recreate is faster and more predictable.

-----

## Exercise 3.2 Solution

### Diagnosis

```bash
kubectl get pod broken-2 -n ex-3-2
# shows STATUS = Error or CrashLoopBackOff (with restartPolicy Never it stays Error/Failed)

kubectl describe pod broken-2 -n ex-3-2
# Last State: Terminated, Reason: StartError or exit code 127

kubectl logs broken-2 -n ex-3-2
# may show nothing or an exec error
```

The issue is that `command: ["echo hello world && sleep 30"]` treats the entire string as a single argv[0], meaning the container runtime tries to execute a binary literally named `echo hello world && sleep 30`. No such binary exists, so the container fails immediately with an exec error. The `&&` shell operator is meaningless outside a shell; you need to run a shell explicitly with `sh -c`.

### Fix

```bash
kubectl delete pod broken-2 -n ex-3-2

cat <<'EOF' | kubectl apply -n ex-3-2 -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-2
  namespace: ex-3-2
spec:
  restartPolicy: Never
  containers:
  - name: worker
    image: busybox:1.36
    command: ["sh", "-c"]
    args: ["echo hello world && sleep 30"]
EOF
```

The `command` field now contains `sh -c` (a real binary with a real flag), and the shell command string goes in `args`. The shell interprets `&&` correctly, prints `hello world`, and then sleeps 30 seconds. The pod reaches `Running` while sleeping and then `Succeeded` after the sleep.

A second correct variant keeps everything in `command`:

```yaml
command: ["sh", "-c", "echo hello world && sleep 30"]
```

Either works; both produce the same argv.

-----

## Exercise 3.3 Solution

### Diagnosis

```bash
kubectl get pod broken-3 -n ex-3-3
# shows STATUS = Init:Error (because restartPolicy is Never and init exited 1)

kubectl describe pod broken-3 -n ex-3-3
# Init Containers / setup: State Terminated, Reason Error, Exit Code 1
# Containers / main: State Waiting, Reason PodInitializing

kubectl logs broken-3 -n ex-3-3 -c setup
# shows "init working" (the last line before exit 1)
```

The init container runs `echo init working; exit 1`, which exits with code 1. Because `restartPolicy: Never` does not retry init containers, the pod is stuck permanently in `Init:Error`, and the main container never starts. The fix is to make the init container exit successfully.

### Fix

```bash
kubectl delete pod broken-3 -n ex-3-3

cat <<'EOF' | kubectl apply -n ex-3-3 -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-3
  namespace: ex-3-3
spec:
  restartPolicy: Never
  volumes:
  - name: shared
    emptyDir: {}
  initContainers:
  - name: setup
    image: busybox:1.36
    command: ["sh", "-c"]
    args: ["echo init working; exit 0"]
    volumeMounts:
    - name: shared
      mountPath: /work
  containers:
  - name: main
    image: busybox:1.36
    command: ["sh", "-c"]
    args: ["echo main running; sleep 30"]
    volumeMounts:
    - name: shared
      mountPath: /work
EOF
```

Changing `exit 1` to `exit 0` (or simply omitting the explicit exit, which defaults to exit 0) allows the init container to terminate with reason `Completed`. The main container then starts, prints `main running`, and sleeps for 30 seconds. After the sleep, the pod reaches `Succeeded`.

-----

## Exercise 4.1 Solution

Declarative only.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pipeline
  namespace: ex-4-1
  labels:
    app: pipeline
    stage: homework
    level: "4"
spec:
  restartPolicy: Never
  volumes:
  - name: data
    emptyDir: {}
  initContainers:
  - name: loader
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      echo record-1 > /data/records.txt
      echo record-2 >> /data/records.txt
      echo record-3 >> /data/records.txt
    volumeMounts:
    - name: data
      mountPath: /data
  containers:
  - name: processor
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      wc -l /data/records.txt
      cat /data/records.txt
    volumeMounts:
    - name: data
      mountPath: /data
```

A couple of notes. The `level` label value must be a string (`"4"` in quotes), because label values are strings even when they look like numbers; unquoted `4` would be a YAML parse error or a schema rejection. The init container uses `>` for the first line to truncate any existing file, then `>>` to append. The processor uses `wc -l` first so the line count shows in logs, then `cat` to show the contents.

-----

## Exercise 4.2 Solution

Declarative only.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: idbox
  namespace: ex-4-2
  labels:
    app: idbox
    tier: demo
spec:
  restartPolicy: Always
  containers:
  - name: inspector-a
    image: busybox:1.36
    imagePullPolicy: IfNotPresent
    command: ["sh", "-c"]
    args: ["env | sort | grep -E '^(POD|NODE|APP)_' ; sleep 300"]
    env:
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    - name: APP_ROLE
      value: primary
  - name: inspector-b
    image: busybox:1.36
    imagePullPolicy: IfNotPresent
    command: ["sh", "-c"]
    args: ["env | sort | grep -E '^(POD|NODE|APP)_' ; sleep 300"]
    env:
    - name: POD_NAME
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: NODE_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    - name: APP_ROLE
      value: secondary
```

Both containers have the same three downward API env vars but differ in the literal `APP_ROLE`. Both use `imagePullPolicy: IfNotPresent` (which is the default for non-`latest` tags, so setting it explicitly is redundant but required by the exercise). The `sleep 300` keeps both containers alive under `restartPolicy: Always` without triggering a restart loop; if the containers exited, `Always` would restart them repeatedly.

-----

## Exercise 4.3 Solution

Declarative only.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: report
  namespace: ex-4-3
spec:
  restartPolicy: OnFailure
  volumes:
  - name: work
    emptyDir: {}
  initContainers:
  - name: fetcher
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      echo alpha > /work/raw.txt
      echo beta >> /work/raw.txt
      echo gamma >> /work/raw.txt
    volumeMounts:
    - name: work
      mountPath: /work
  - name: transformer
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      tr a-z A-Z < /work/raw.txt > /work/final.txt
    volumeMounts:
    - name: work
      mountPath: /work
  containers:
  - name: printer
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      cat /work/final.txt
    volumeMounts:
    - name: work
      mountPath: /work
```

Init containers run sequentially in the order they appear in the list, so `fetcher` runs first, and only after it exits with code 0 does `transformer` start. Both must complete before `printer` runs. All three containers mount the same `work` emptyDir at `/work`. The `tr a-z A-Z` command translates lowercase to uppercase, so the printer's output is `ALPHA`, `BETA`, `GAMMA`.

-----

## Exercise 5.1 Solution

### Diagnosis

```bash
kubectl get pod multibug -n ex-5-1
# STATUS likely ErrImagePull or CreateContainerConfigError

kubectl describe pod multibug -n ex-5-1
# Events: "Failed to pull image busybox:2.99" (tag does not exist)
# Error: referenced label not found (labels.tier does not exist)
```

There are three separate problems in this pod. First, `busybox:2.99` is not a real tag and the image pull fails, so the pod never reaches `Running`. Second, the `APP_TIER` env var uses `fieldRef: metadata.labels.tier`, but the pod has no label `tier`, so that reference fails. Third, the `command` and `args` are swapped in meaning: `command: ["echo; sleep 30"]` is a single literal string meant to be the argv[0] of a binary named `echo; sleep 30`, and `args: ["starting multibug"]` would be its only argument. No such binary exists. The intended behavior is to run a shell command, which needs `sh -c` in `command`.

### Fix

```bash
kubectl delete pod multibug -n ex-5-1

cat <<'EOF' | kubectl apply -n ex-5-1 -f -
apiVersion: v1
kind: Pod
metadata:
  name: multibug
  namespace: ex-5-1
  labels:
    tier: backend
spec:
  restartPolicy: Never
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c"]
    args: ["echo starting multibug; sleep 30"]
    env:
    - name: APP_NAME
      value: multibug
    - name: APP_TIER
      valueFrom:
        fieldRef:
          fieldPath: metadata.labels['tier']
EOF
```

Three fixes in one spec. The image becomes `busybox:1.36` (a real tag). The pod gets the label `tier: backend` so the downward API reference resolves. The command structure becomes `sh -c` with the shell command string in `args`. Note the `metadata.labels['tier']` syntax with brackets, which is the correct form for accessing a specific label via the downward API; `metadata.labels.tier` with a dot is not a valid field path for labels because labels is a map, not a struct.

-----

## Exercise 5.2 Solution

### Diagnosis

```bash
kubectl get pod coord -n ex-5-2
# phase may be Failed (consumer exited nonzero because file missing)

kubectl logs coord -n ex-5-2 -c preparer
# "preparer done"

kubectl logs coord -n ex-5-2 -c consumer
# "cat: can't open '/data/payload.txt': No such file or directory"

kubectl describe pod coord -n ex-5-2
# preparer mounts emptyDir at /data
# consumer mounts emptyDir at /data
# but preparer writes to /tmp/payload.txt, not /data
```

The init container mounts the shared volume at `/data`, but it writes to `/tmp/payload.txt`. `/tmp` is in the container's own ephemeral filesystem, not on the shared volume, so the file never lands on the `emptyDir`. When the init container exits, its entire filesystem is thrown away, including `/tmp/payload.txt`. The main container mounts the (now empty) shared volume at `/data` and fails to find the file.

### Fix

```bash
kubectl delete pod coord -n ex-5-2

cat <<'EOF' | kubectl apply -n ex-5-2 -f -
apiVersion: v1
kind: Pod
metadata:
  name: coord
  namespace: ex-5-2
spec:
  restartPolicy: Never
  volumes:
  - name: work
    emptyDir: {}
  initContainers:
  - name: preparer
    image: busybox:1.36
    command: ["sh", "-c"]
    args: ["echo payload-ready > /data/payload.txt; echo preparer done"]
    volumeMounts:
    - name: work
      mountPath: /data
  containers:
  - name: consumer
    image: busybox:1.36
    command: ["sh", "-c"]
    args: ["cat /data/payload.txt; echo consumer done"]
    volumeMounts:
    - name: work
      mountPath: /data
EOF
```

The init container now writes to `/data/payload.txt`, which is on the shared volume (because the volume is mounted at `/data`). The main container reads from the same path. This is the subtle coordination bug the exercise is designed to train you to spot: the write path and the mount path must line up, or the main container finds an empty directory.

-----

## Exercise 5.3 Solution

### Diagnosis

```bash
kubectl get pod subtle -n ex-5-3
# status shows restartCount climbing on worker
# pod phase Running (because worker is in a restart loop)

kubectl describe pod subtle -n ex-5-3
# init container seed: State Terminated, Reason Completed
# but its command is /bin/true which takes no args and ignores args
# so it never actually wrote the marker file
# worker container: repeatedly exiting with code 2
# Last State Terminated, Reason Error, Exit Code 2

kubectl logs subtle -n ex-5-3 -c seed
# (empty, /bin/true produces no output)

kubectl logs subtle -n ex-5-3 -c worker
# "no marker present" over and over
```

Two subtle issues compound here. First, the init container's `command: ["/bin/true"]` runs the `true` binary, which always exits 0 and completely ignores any `args`. The script in `args` (the `mkdir` and the `echo`) never executes, so `/scratch/marker.txt` is never created. The init container succeeds with reason `Completed`, so the main container does start, but it finds no marker and runs `exit 2`. Second, the pod's `restartPolicy: Always` means the worker gets restarted every time it fails with exit code 2, creating an endless loop of failures. Even if the init container is fixed to run the intended script, the `Always` restart policy is wrong for a workload that is supposed to complete and stop after the sleep; the correct policy for a completing workload is `OnFailure` (which does not restart clean exits) or `Never`.

### Fix

```bash
kubectl delete pod subtle -n ex-5-3

cat <<'EOF' | kubectl apply -n ex-5-3 -f -
apiVersion: v1
kind: Pod
metadata:
  name: subtle
  namespace: ex-5-3
  labels:
    app: subtle
spec:
  restartPolicy: OnFailure
  volumes:
  - name: scratch
    emptyDir: {}
  initContainers:
  - name: seed
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      mkdir -p /scratch
      echo "seeded" > /scratch/marker.txt
    volumeMounts:
    - name: scratch
      mountPath: /scratch
  containers:
  - name: worker
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      if [ -f /scratch/marker.txt ]; then
        echo "found marker: $(cat /scratch/marker.txt)"
      else
        echo "no marker present"
        exit 2
      fi
      echo "worker idling"
      sleep 30
    volumeMounts:
    - name: scratch
      mountPath: /scratch
EOF
```

Two fixes. The init container now runs `sh -c` with the script in `args`, so the `mkdir` and `echo` actually execute. The restart policy is now `OnFailure`, so the worker's successful clean exit after the 30-second sleep leaves the pod in `Succeeded` rather than getting restarted. (`Never` is also a valid fix; both meet the requirement.) With these two fixes, the init container writes the marker file, the worker finds it, prints `found marker: seeded`, idles 30 seconds, and exits cleanly.

-----

## Common Mistakes

### command vs args confusion

This is by far the most common pod bug on the exam and in the wild. In Kubernetes, `command` overrides Docker's `ENTRYPOINT` and `args` overrides Docker's `CMD`. Both are lists of strings. The final container argv is `command` followed by `args`. When you want shell semantics (pipes, redirects, `&&`, variable expansion), you need to explicitly run a shell: `command: ["sh", "-c"]` with the shell string in `args`. Putting the whole shell command line in `command` as a single string (e.g., `command: ["echo hello && sleep 30"]`) causes the runtime to try to exec a binary literally named `echo hello && sleep 30`, which does not exist.

### restartPolicy interaction with init container failures

`restartPolicy: Never` combined with an init container that exits nonzero produces `Init:Error` permanently; there is no retry. `restartPolicy: OnFailure` or `Always` both retry a failing init container, producing `Init:CrashLoopBackOff` as the backoff kicks in. This matters because a learner debugging an `Init:Error` pod sometimes assumes the pod is retrying and waits; it is not retrying, and the only fix is to delete and recreate with a working init container. It also matters for the opposite case: a one-shot pod that should complete and stop needs `Never` or `OnFailure`, not `Always`, because `Always` restarts even on clean exit 0, producing a `Completed`-then-`Running`-then-`Completed` loop.

### Why `:latest` tags cause reproducibility problems

Images tagged `:latest` (and images with no tag, which is the same thing) default to `imagePullPolicy: Always`, meaning the kubelet contacts the registry on every container start. Worse, the tag's contents can change under you: the same pod spec can produce different images on different days as `:latest` gets updated. For reproducibility, and for exam answers, always pin to a specific version like `nginx:1.25` or `busybox:1.36`. On the exam, `:latest` will not fail you explicitly, but in real work it produces mystery bugs that are infuriating to debug.

### Multi-container pods need unique container names

Every container in a pod, including init containers, must have a unique name within the pod. The API server rejects specs with duplicates before they reach the scheduler. If you copy-paste a container block in YAML and forget to change the name, you get a validation error that clearly says so, but the mistake is easy to make during a timed exam.

### emptyDir lifetime

`emptyDir` is created when the pod is assigned to a node and destroyed when the pod is removed from the node. Its lifetime is tied to the pod, not to individual containers. If a container in the pod dies and restarts, the `emptyDir` persists and the restarted container sees the same files. If the pod is deleted and recreated (even with the same name), a fresh empty `emptyDir` is allocated. This matters for init container patterns: the main container sees the files the init container wrote because they persist in the `emptyDir`, not because there is any container-to-container IPC going on.

### Downward API label access syntax

To read a specific label via the downward API, the correct field path is `metadata.labels['key-name']` with bracket notation and single quotes, not `metadata.labels.key-name` with dot notation. The dot syntax does not work for map fields. The same applies to annotations: use `metadata.annotations['key-name']`. For top-level fields like `metadata.name` and `spec.nodeName`, dot notation is fine because those are struct fields.

### Forgetting to keep the pod alive during inspection

A container like `busybox` with a command of `env` or `echo hello` exits immediately after its command runs. Under `restartPolicy: Always` (the default), this produces a `CrashLoopBackOff` as the container keeps exiting and getting restarted. Under `Never`, the pod reaches `Succeeded` after the first run, and `kubectl exec` no longer works because the container is not running. When you need to inspect the container with `kubectl exec`, append a `sleep` to keep it alive: `command: ["sh", "-c"]; args: ["env; sleep 300"]`.

-----

## Verification Commands Cheat Sheet

### Basic status

```bash
kubectl get pod NAME -n NS                           # overall status line
kubectl get pod NAME -n NS -o wide                   # adds node and pod IP
kubectl get pod NAME -n NS -o yaml                   # full spec and live status
kubectl get pods -n NS --show-labels                 # labels in output
kubectl get pods -n NS -l key=value                  # filter by label selector
```

### Deep inspection

```bash
kubectl describe pod NAME -n NS                      # human-readable; read Events section
kubectl get pod NAME -n NS -o jsonpath='{.status.phase}'
kubectl get pod NAME -n NS -o jsonpath='{.status.containerStatuses[0].state}'
kubectl get pod NAME -n NS -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}'
kubectl get pod NAME -n NS -o jsonpath='{.status.containerStatuses[0].restartCount}'
kubectl get pod NAME -n NS -o jsonpath='{.status.initContainerStatuses[0].state.terminated.reason}'
```

### Logs

```bash
kubectl logs NAME -n NS                              # single-container pod, current instance
kubectl logs NAME -n NS -c CONTAINER                 # specific container in multi-container pod
kubectl logs NAME -n NS --previous                   # previous container instance (useful on CrashLoopBackOff)
kubectl logs NAME -n NS -c CONTAINER --previous      # both flags combined
kubectl logs NAME -n NS -c CONTAINER -f              # follow (stream)
kubectl logs NAME -n NS --all-containers             # every container's logs interleaved
```

### Exec into a container

```bash
kubectl exec NAME -n NS -- COMMAND                   # single-container pod
kubectl exec NAME -n NS -c CONTAINER -- COMMAND      # multi-container pod
kubectl exec -it NAME -n NS -- sh                    # interactive shell (single-container)
kubectl exec -it NAME -n NS -c CONTAINER -- sh       # interactive shell (multi-container)
```

### Useful jsonpath one-liners

```bash
# list all container images in a pod
kubectl get pod NAME -n NS -o jsonpath='{.spec.containers[*].image}'; echo

# list all container names
kubectl get pod NAME -n NS -o jsonpath='{.spec.containers[*].name}'; echo

# list init container names in order
kubectl get pod NAME -n NS -o jsonpath='{.spec.initContainers[*].name}'; echo

# get pod phase
kubectl get pod NAME -n NS -o jsonpath='{.status.phase}'; echo

# get pod IP
kubectl get pod NAME -n NS -o jsonpath='{.status.podIP}'; echo

# get node name
kubectl get pod NAME -n NS -o jsonpath='{.spec.nodeName}'; echo
```

### Generating YAML skeletons

```bash
kubectl run NAME --image=IMAGE --dry-run=client -o yaml > pod.yaml
kubectl run NAME --image=IMAGE --restart=Never --dry-run=client -o yaml > pod.yaml
kubectl run NAME --image=IMAGE --labels="a=b,c=d" --dry-run=client -o yaml > pod.yaml
kubectl run NAME --image=IMAGE --env="FOO=bar" --dry-run=client -o yaml > pod.yaml
kubectl run NAME --image=IMAGE --dry-run=client -o yaml -- sh -c "echo hi; sleep 300" > pod.yaml
```

### Diagnostic workflow for a broken pod

When a pod is not behaving as expected, follow this sequence in order. Run `kubectl get pod NAME -n NS` first to see the high-level phase and status; the STATUS column tells you whether it is `ImagePullBackOff`, `CrashLoopBackOff`, `Init:Error`, `Completed`, `Running`, or something else, and each of those points to a different class of problem. Next run `kubectl describe pod NAME -n NS` and read the Events section at the bottom; events are chronological and they tell you exactly what the scheduler and kubelet have tried to do. Check the container status details (under `Containers:` and `Init Containers:`) for exit codes, reasons, and restart counts. If the container has run at all, use `kubectl logs NAME -n NS` (with `-c CONTAINER` for multi-container pods, `--previous` if the current instance has not produced output yet) to see what the application said. Finally, when everything else fails, `kubectl get pod NAME -n NS -o yaml` shows you the full live spec and status, which can reveal things (like an env var resolution failure or a mount path mismatch) that the other commands do not show directly.
