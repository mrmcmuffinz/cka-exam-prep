# Pod Fundamentals Tutorial

This tutorial walks you through building and inspecting a pod end to end. It starts with the simplest possible single-container pod, adds fields one at a time with an explanation of what each field does and why you would change it, then builds up to a multi-container pod that uses an init container to prepare data on an `emptyDir` volume for the main container to consume. Along the way you will see both the imperative kubectl approach (`kubectl run`, `kubectl create`) and the declarative YAML approach, and you will learn the imperative-to-declarative workflow where you generate a YAML skeleton with `--dry-run=client -o yaml`, edit it, and then apply it. You will also practice the inspection commands (`kubectl describe`, `kubectl logs` with its variants, `kubectl get pod -o yaml`) that you will use constantly during the CKA exam and in real work.

All tutorial resources go into a dedicated namespace called `tutorial-pod-fundamentals` so they will not collide with anything the exercises create.

## Prerequisites

Verify your cluster is up and kubectl is working before you start.

```bash
kubectl get nodes
kubectl cluster-info
```

You should see at least one node in `Ready` state and the cluster endpoints should be reachable. If that is not the case, fix the cluster first. Then create the tutorial namespace.

```bash
kubectl create namespace tutorial-pod-fundamentals
kubectl config set-context --current --namespace=tutorial-pod-fundamentals
```

The second command sets your default namespace for this terminal session so you do not have to type `-n tutorial-pod-fundamentals` on every command. If you prefer to be explicit, skip it and include `-n tutorial-pod-fundamentals` on each command instead.

## Part 1: The Simplest Pod

The absolute minimum pod spec needs four things: the `apiVersion`, the `kind`, a `metadata.name`, and a `spec.containers` list with at least one container that has a `name` and an `image`. Everything else has a default. Let us start with the imperative command.

```bash
kubectl run hello --image=nginx:1.25
```

That one command generates a pod spec behind the scenes and submits it to the API server. Check that it is running.

```bash
kubectl get pod hello
```

Within a few seconds the `STATUS` column should show `Running` and `READY` should show `1/1`. To see the full spec that was generated, ask for the YAML back.

```bash
kubectl get pod hello -o yaml
```

The output will have a lot of fields you did not specify, because Kubernetes fills in defaults for everything that matters. Notice `restartPolicy: Always`, `dnsPolicy: ClusterFirst`, `imagePullPolicy: IfNotPresent` (because the image tag is not `latest`), and `terminationGracePeriodSeconds: 30`. You did not set any of those, but they all got reasonable defaults. Understanding what those defaults are is just as important as knowing which fields you can set, because most of the time you inherit the defaults and only change the ones that matter.

Delete this pod before moving on so the namespace stays tidy.

```bash
kubectl delete pod hello
```

## Part 2: Imperative to Declarative

The imperative commands are fast for one-off tasks, but for anything you want to version-control or reason about carefully, you want YAML. The standard workflow is to use `kubectl run` (or `kubectl create`) with `--dry-run=client -o yaml` to generate a starting YAML skeleton, then edit the skeleton and apply it.

```bash
kubectl run web --image=nginx:1.25 --dry-run=client -o yaml > web-pod.yaml
cat web-pod.yaml
```

The file you get looks something like this, with a few managed-fields annotations that you can safely delete.

```yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    run: web
  name: web
spec:
  containers:
  - image: nginx:1.25
    name: web
    resources: {}
  dnsPolicy: ClusterFirst
  restartPolicy: Always
status: {}
```

Clean it up by removing `creationTimestamp`, the empty `resources: {}` block, and the `status: {}` at the bottom. Those are artifacts of how the template is generated and they are not useful in a source file. Apply it.

```bash
kubectl apply -f web-pod.yaml
kubectl get pod web
```

This is the workflow you will use constantly. Generate the skeleton, edit it, apply it. On the exam, it saves you from typing the `apiVersion`, `kind`, and nested `spec` structure from memory, which matters when you are under time pressure.

Clean up before the next part.

```bash
kubectl delete pod web
rm web-pod.yaml
```

## Part 3: Commands, Arguments, and Restart Policy

By default a container runs whatever command its image baked in via `ENTRYPOINT` and `CMD`. You can override either of those at the pod spec level. The mapping is worth memorizing because it comes up constantly in both real work and the exam. The pod spec's `command` field overrides the Docker `ENTRYPOINT`. The pod spec's `args` field overrides the Docker `CMD`. They are not the same field, and putting your command line in the wrong one is the most common pod bug you will encounter.

Create a pod that runs a shell command and exits immediately. Because it will exit on its own, you need a `restartPolicy` that does not keep restarting it, otherwise it will loop forever.

```yaml
cat > greeter-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: greeter
spec:
  restartPolicy: Never
  containers:
  - name: greeter
    image: busybox:1.36
    command: ["sh", "-c"]
    args: ["echo Hello from the tutorial; sleep 5; echo Goodbye"]
EOF

kubectl apply -f greeter-pod.yaml
```

Watch the pod go through its lifecycle.

```bash
kubectl get pod greeter -w
```

You will see it go from `Pending` (while the image pulls and the container is created), to `Running` (while the sleep is happening), to `Completed` (once the shell exits with code 0). Press Ctrl-C to stop watching. Read the logs.

```bash
kubectl logs greeter
```

You should see the Hello line, then the Goodbye line. The pod phase after completion is `Succeeded` because the container exited with code 0 and `restartPolicy` is not `Always`. If the exit code had been nonzero, the phase would be `Failed`.

A few field-by-field notes. The `command` field takes a list of strings and becomes the container's process argv. In this case, `sh -c` tells the shell to read a command string from the next argument. The `args` field provides that command string. You could instead put everything in `command` and leave `args` empty, or put the binary in `command` and the flags in `args`; both are valid, as long as the total argv is right. What you cannot do is put the whole command line as a single string in `command` without the `sh -c` wrapper, because Kubernetes will try to exec that literal string as a binary, fail to find it, and the container will crash.

The `restartPolicy: Never` is critical here. If you had left the default of `Always`, Kubernetes would keep restarting the container every time it exited, turning a one-shot greeter into an infinite loop. The three valid values are `Always` (the default, restart on any exit including clean exits), `OnFailure` (restart only if the exit code is nonzero, which is what you want for a retryable batch job), and `Never` (do not restart regardless of exit code, which is what you want for a one-shot that should complete and stop).

Clean up.

```bash
kubectl delete pod greeter
rm greeter-pod.yaml
```

## Part 4: Pod Phases and Container Statuses

Pod phase and container status are two separate things, and understanding the distinction is essential. The pod phase is one of `Pending`, `Running`, `Succeeded`, `Failed`, or `Unknown`, and it describes the pod as a whole. Container status is either `Waiting`, `Running`, or `Terminated`, and each container in the pod has its own status independently.

Let us see a few of these in action.

### A Running pod

Create a long-running pod.

```bash
kubectl run runner --image=nginx:1.25
kubectl get pod runner
```

Phase is `Running`. Container status is `Running`. Normal case.

### A Pending pod

Create a pod that references an image that does not exist, so the image pull will fail and the container will never start.

```bash
kubectl run pending-demo --image=nginx:this-tag-does-not-exist-12345
kubectl get pod pending-demo
```

After a few seconds the pod will show `Pending` or `ImagePullBackOff`. Describe it to see why.

```bash
kubectl describe pod pending-demo
```

The `Events` section at the bottom will show messages like `Failed to pull image ... manifest for nginx:this-tag-does-not-exist-12345 not found`. The container status (under `Containers:`) will show `Waiting` with a reason of `ImagePullBackOff` or `ErrImagePull`. The pod phase stays `Pending` until at least one container starts, and this one never will.

### A CrashLoopBackOff pod

Create a pod whose command exits with an error code immediately. With the default `restartPolicy: Always`, Kubernetes keeps restarting it, and after a few fast restarts starts backing off.

```yaml
cat > crasher-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: crasher
spec:
  containers:
  - name: crasher
    image: busybox:1.36
    command: ["sh", "-c", "echo starting; sleep 2; exit 1"]
EOF

kubectl apply -f crasher-pod.yaml
```

Wait about thirty seconds and check the status.

```bash
kubectl get pod crasher
kubectl describe pod crasher
```

The pod phase will be `Running` (because containers have run, the pod is not Pending), but the container status will be `Waiting` with a reason of `CrashLoopBackOff`. The describe output shows the restart count climbing and the event log showing the back-off intervals getting longer. You can read the logs from the most recent attempt with `kubectl logs crasher`, and from the previous attempt (before the current restart) with `kubectl logs crasher --previous`. The `--previous` flag is essential when the current container has not started yet because the previous one is the one that actually holds the interesting output.

### A Succeeded pod

Create a pod that does some work and exits cleanly, with `restartPolicy: Never` so it stays in the completed state.

```yaml
cat > oneshot-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: oneshot
spec:
  restartPolicy: Never
  containers:
  - name: oneshot
    image: busybox:1.36
    command: ["sh", "-c", "echo one-shot work done; exit 0"]
EOF

kubectl apply -f oneshot-pod.yaml
sleep 5
kubectl get pod oneshot
```

Phase is `Succeeded`, container status is `Terminated` with a reason of `Completed` and an exit code of 0.

Clean up the demo pods before moving on.

```bash
kubectl delete pod runner pending-demo crasher oneshot
rm crasher-pod.yaml oneshot-pod.yaml
```

## Part 5: Labels, Annotations, and Image Pull Policy

Labels are key-value pairs used for identification and selection. Annotations are key-value pairs used for arbitrary metadata that is not used for selection. Both live under `metadata`, and together they form the pod's identity and descriptive metadata.

Here is a pod with a few of each, along with an explicit `imagePullPolicy`.

```yaml
cat > labeled-pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: labeled
  labels:
    app: demo
    tier: frontend
    environment: tutorial
  annotations:
    owner: abe
    purpose: "pod fundamentals tutorial"
spec:
  containers:
  - name: web
    image: nginx:1.25
    imagePullPolicy: IfNotPresent
EOF

kubectl apply -f labeled-pod.yaml
```

Inspect the labels.

```bash
kubectl get pod labeled --show-labels
kubectl get pods -l app=demo
kubectl get pods -l tier=frontend,environment=tutorial
```

The `-l` flag lets you filter by label selector, which is how every controller (ReplicaSets, Deployments, Services) finds the pods it cares about. You will rely on this constantly.

The `imagePullPolicy` field has three valid values. `Always` means the kubelet contacts the registry on every container start to check for a newer image matching the tag, which is what you want if you are deploying a mutable tag like `latest` (or any tag you are actively pushing to during development). `IfNotPresent` means the kubelet only pulls the image if it is not already cached on the node, which is the sensible default for any immutable, specifically-tagged image like `nginx:1.25`. `Never` means the kubelet will never pull and will fail if the image is not already on the node; this is almost never what you want except for testing with locally-loaded images.

If you do not specify `imagePullPolicy`, Kubernetes picks a default based on the tag. An image with the tag `latest` (or no tag at all, which also means `latest`) defaults to `Always`. Any other tag defaults to `IfNotPresent`. This is one of several reasons why you should never use `:latest` in serious specs.

Clean up.

```bash
kubectl delete pod labeled
rm labeled-pod.yaml
```

## Part 6: Environment Variables, Literal and Downward API

Environment variables are configured under `spec.containers[].env`. Each entry is a `name` and either a `value` (for a literal) or a `valueFrom` (for a reference). In this assignment, the only kinds of references in scope are the downward API sources `fieldRef` (for pod-level metadata like name, namespace, and node name) and `resourceFieldRef` (for container resource values). ConfigMap and Secret references come in the next assignment.

Build a pod that uses both literal env vars and downward API env vars.

```yaml
cat > envpod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: envpod
spec:
  restartPolicy: Never
  containers:
  - name: envpod
    image: busybox:1.36
    command: ["sh", "-c"]
    args: ["env | sort; sleep 30"]
    env:
    - name: APP_NAME
      value: "tutorial-env-demo"
    - name: APP_TIER
      value: "demo"
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
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP
EOF

kubectl apply -f envpod.yaml
```

Wait a few seconds for the pod to reach `Running`, then check the logs.

```bash
kubectl get pod envpod
kubectl logs envpod
```

You should see all six env vars in the output, with `APP_NAME` and `APP_TIER` set to the literals and `POD_NAME`, `POD_NAMESPACE`, `NODE_NAME`, and `POD_IP` set to the actual runtime values that Kubernetes injected at container start time.

Two things about the downward API are worth understanding. First, the field paths must match fields that actually exist in the pod spec or status at the moment of container start; `spec.nodeName` works because the scheduler has already bound the pod to a node by the time the container starts, but there are fields (like `status.phase`) that are not stable and are not intended to be exposed this way. Second, the downward API is the only way to get these pod-level values into the container without baking them into the image or shipping them via a ConfigMap, and for pod identity values (name, namespace, node) it is almost always the right choice because nothing else in the system knows what they will be at deployment time.

Clean up.

```bash
kubectl delete pod envpod
rm envpod.yaml
```

## Part 7: Multi-Container Pods and emptyDir

A pod can have more than one container. The containers share a network namespace (they can reach each other on `localhost`) and they can share a filesystem if you mount the same volume into both of them. The simplest shared volume is `emptyDir`, which is an empty directory created when the pod starts and deleted when the pod ends. Its lifetime is tied to the pod, not to any single container, which is exactly what you need for inter-container file sharing.

A note on scope. `emptyDir` is the only volume type used in this assignment, and it only appears when multi-container file sharing is genuinely needed. PersistentVolumes, hostPath, and other volume types belong to a later topic. Use `emptyDir` here because it is the simplest thing that demonstrates container coordination.

Build a two-container pod where both containers write to the same `emptyDir` and can read each other's output.

```yaml
cat > twinpod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: twinpod
spec:
  restartPolicy: Never
  volumes:
  - name: shared
    emptyDir: {}
  containers:
  - name: writer
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      for i in 1 2 3 4 5; do
        echo "writer line $i" >> /data/writer.log
        sleep 2
      done
      echo writer done
      sleep 30
    volumeMounts:
    - name: shared
      mountPath: /data
  - name: reader
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      for i in 1 2 3 4 5; do
        echo "reader sees at tick $i:"
        cat /data/writer.log 2>/dev/null || echo "  (nothing yet)"
        sleep 3
      done
    volumeMounts:
    - name: shared
      mountPath: /data
EOF

kubectl apply -f twinpod.yaml
```

Watch the pod start.

```bash
kubectl get pod twinpod
```

Once both containers are running, you can read each container's logs separately. Because a pod has multiple containers, you must use `-c` to pick one.

```bash
kubectl logs twinpod -c writer
kubectl logs twinpod -c reader
```

The reader's logs should show it reading the writer's file as it gets populated. That is the fundamental mechanism behind every multi-container pod pattern: shared volume, shared network, coordinated containers.

A couple of practical notes. Each container in a pod must have a unique `name`; if you try to give two containers the same name, the API server will reject the spec. Every time you run `kubectl logs` on a multi-container pod without `-c`, you get an error telling you to pick a container; there is no default. The `-f` flag follows log output in real time, `-c name` picks a specific container, and `--previous` (or `-p`) reads the logs of the previous container instance in case the current one has not started yet or has replaced a crashed instance.

Clean up.

```bash
kubectl delete pod twinpod
rm twinpod.yaml
```

## Part 8: Init Containers

Init containers run before the main containers start. They run in sequence (one at a time, in the order defined), and each one must complete successfully before the next one starts. If any init container fails, the pod does not proceed to the main containers; depending on `restartPolicy`, the init container is either retried or the pod is marked as failed.

The classic use case, and the one you will see on the exam, is using an init container to prepare data on an `emptyDir` that the main container then consumes. Let us build that.

```yaml
cat > prepmain.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: prepmain
spec:
  restartPolicy: Never
  volumes:
  - name: work
    emptyDir: {}
  initContainers:
  - name: preparer
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      echo "preparer starting"
      mkdir -p /work/input
      echo "line one" > /work/input/data.txt
      echo "line two" >> /work/input/data.txt
      echo "line three" >> /work/input/data.txt
      echo "preparer done"
    volumeMounts:
    - name: work
      mountPath: /work
  containers:
  - name: consumer
    image: busybox:1.36
    command: ["sh", "-c"]
    args:
    - |
      echo "consumer starting"
      echo "file contents:"
      cat /work/input/data.txt
      echo "consumer done"
    volumeMounts:
    - name: work
      mountPath: /work
EOF

kubectl apply -f prepmain.yaml
```

Watch it run and then read the logs from each container separately. The init container's logs are accessed by name just like a main container, but the main container will not start until the init container has succeeded.

```bash
kubectl get pod prepmain -w
# wait until Completed, then Ctrl-C
kubectl logs prepmain -c preparer
kubectl logs prepmain -c consumer
```

The consumer should print the three lines that the preparer wrote. That is the full init-container-prepares-data pattern.

### What happens when an init container fails

Try the same pattern but with an init container that exits with an error. The main container should never run.

```yaml
cat > failpod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: failpod
spec:
  restartPolicy: Never
  initContainers:
  - name: failer
    image: busybox:1.36
    command: ["sh", "-c"]
    args: ["echo init running; sleep 2; echo init about to fail; exit 1"]
  containers:
  - name: main
    image: busybox:1.36
    command: ["sh", "-c"]
    args: ["echo main should never print this"]
EOF

kubectl apply -f failpod.yaml
sleep 10
kubectl get pod failpod
kubectl describe pod failpod
kubectl logs failpod -c failer
kubectl logs failpod -c main
```

A few things to notice. The pod phase with `restartPolicy: Never` goes to `Failed` once the init container exits nonzero. The `kubectl get pod failpod` output shows a status of `Init:Error` (or after several restart attempts with `restartPolicy: OnFailure` or `Always`, you would see `Init:CrashLoopBackOff`). The `failer` logs show the init container's output. The `main` logs error out because the main container was never started, so there are no logs for it. The describe output shows under `Init Containers:` that `failer` is in a `Terminated` state with exit code 1, and under `Containers:` that `main` is in a `Waiting` state with reason `PodInitializing`.

If you change `restartPolicy` to `OnFailure` or `Always`, Kubernetes will keep retrying the init container, and you will see the restart count climb in `kubectl describe` while the main container stays in `PodInitializing`. This is the `Init:CrashLoopBackOff` pattern.

Clean up.

```bash
kubectl delete pod prepmain failpod
rm prepmain.yaml failpod.yaml
```

## Part 9: The Capstone Pod

Now build one pod that combines everything from the tutorial: an init container that prepares data on an `emptyDir`, a main container that consumes it, labels and annotations, env vars mixing literals and downward API sources, a clear `restartPolicy`, and explicit `imagePullPolicy` on both containers.

```yaml
cat > capstone.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: capstone
  labels:
    app: capstone
    tier: batch
    tutorial: pod-fundamentals
  annotations:
    owner: abe
    description: "tutorial capstone pod combining init, main, env, and labels"
spec:
  restartPolicy: OnFailure
  volumes:
  - name: prepared
    emptyDir: {}
  initContainers:
  - name: seeder
    image: busybox:1.36
    imagePullPolicy: IfNotPresent
    command: ["sh", "-c"]
    args:
    - |
      echo "seeder running on node $MY_NODE for pod $MY_POD"
      mkdir -p /out
      echo "seeded at $(date -u +%FT%TZ) by $MY_POD in $MY_NS on $MY_NODE" > /out/seed.txt
      echo "seeder done"
    env:
    - name: MY_POD
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: MY_NS
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: MY_NODE
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    volumeMounts:
    - name: prepared
      mountPath: /out
  containers:
  - name: worker
    image: busybox:1.36
    imagePullPolicy: IfNotPresent
    command: ["sh", "-c"]
    args:
    - |
      echo "worker starting on node $MY_NODE as $MY_POD in $MY_NS"
      echo "seed file contents:"
      cat /in/seed.txt
      echo "worker done"
    env:
    - name: APP_NAME
      value: capstone
    - name: APP_ENV
      value: tutorial
    - name: MY_POD
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    - name: MY_NS
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: MY_NODE
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    volumeMounts:
    - name: prepared
      mountPath: /in
EOF

kubectl apply -f capstone.yaml
```

Watch it run through init and then into the main container.

```bash
kubectl get pod capstone -w
# wait for Completed, Ctrl-C
```

Inspect every part of it.

```bash
kubectl describe pod capstone
kubectl get pod capstone -o yaml
kubectl logs capstone -c seeder
kubectl logs capstone -c worker
kubectl get pod capstone --show-labels
```

Walk through the `kubectl describe` output carefully. The top of the output shows pod-level metadata: name, namespace, labels, annotations, status, IP, node. The `Init Containers:` section shows the `seeder` container, its image, command, args, env, mounts, and current state (which will be `Terminated` with reason `Completed` and exit code 0 after it succeeds). The `Containers:` section shows the `worker` container with the same kind of detail for the main container. The `Conditions:` section shows `Initialized`, `Ready`, `ContainersReady`, and `PodScheduled` as true/false flags. The `Volumes:` section lists the `prepared` volume. At the bottom, `Events:` shows the history of everything that has happened to this pod (scheduled, pulled images, created containers, started containers, etc.) in chronological order. This section is where you go first whenever something is wrong.

Clean up.

```bash
kubectl delete pod capstone
rm capstone.yaml
```

## Part 10: Cleaning Up the Tutorial

Delete the tutorial namespace to remove everything you created.

```bash
kubectl config set-context --current --namespace=default
kubectl delete namespace tutorial-pod-fundamentals
```

## Reference Commands

### Imperative pod creation

```bash
# simplest possible pod
kubectl run NAME --image=IMAGE

# with command override (positional args after -- become the container command)
kubectl run NAME --image=busybox:1.36 --restart=Never -- sh -c "echo hello; sleep 5"

# with labels
kubectl run NAME --image=IMAGE --labels="app=foo,tier=web"

# with env vars (literal only)
kubectl run NAME --image=IMAGE --env="APP_NAME=demo" --env="APP_TIER=dev"

# generate YAML without creating anything
kubectl run NAME --image=IMAGE --dry-run=client -o yaml > pod.yaml
```

The `--restart` flag on `kubectl run` maps to `restartPolicy`: `Never` becomes `Never`, `OnFailure` becomes `OnFailure`, and omitting it (or setting `Always`) becomes `Always`.

### Declarative skeleton

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: NAME
  namespace: NS
  labels:
    key: value
  annotations:
    key: value
spec:
  restartPolicy: Always | OnFailure | Never
  volumes:
  - name: VOLNAME
    emptyDir: {}
  initContainers:
  - name: INITNAME
    image: IMAGE
    imagePullPolicy: Always | IfNotPresent | Never
    command: ["binary"]
    args: ["arg1", "arg2"]
    env:
    - name: KEY
      value: literal
    - name: KEY2
      valueFrom:
        fieldRef:
          fieldPath: metadata.name
    volumeMounts:
    - name: VOLNAME
      mountPath: /some/path
  containers:
  - name: MAINNAME
    image: IMAGE
    imagePullPolicy: IfNotPresent
    command: ["binary"]
    args: ["arg1", "arg2"]
    env:
    - name: KEY
      value: literal
    volumeMounts:
    - name: VOLNAME
      mountPath: /some/path
```

### Inspection commands

```bash
kubectl get pod NAME
kubectl get pod NAME -o wide               # adds node, IP
kubectl get pod NAME -o yaml               # full spec plus live status
kubectl get pod NAME --show-labels         # labels in output
kubectl get pods -l key=value              # filter by label
kubectl describe pod NAME                  # human-readable detail with events
kubectl logs NAME                          # current container logs (single-container pod)
kubectl logs NAME -c CONTAINER             # specific container in multi-container pod
kubectl logs NAME --previous               # previous container instance
kubectl logs NAME -c CONTAINER -f          # follow
kubectl exec NAME -- COMMAND               # single-container pod
kubectl exec NAME -c CONTAINER -- COMMAND  # multi-container pod
```

## Pod Phases and Container Statuses

| Pod phase | Meaning |
|---|---|
| Pending | Pod accepted by the API server, but at least one container has not started (image pulling, waiting to be scheduled, init containers running) |
| Running | Pod bound to a node, all init containers succeeded, at least one main container is Running, Starting, or Restarting |
| Succeeded | All containers terminated successfully (exit code 0) and will not be restarted (restartPolicy Never or OnFailure with clean exits) |
| Failed | All containers terminated and at least one exited with nonzero code, and will not be restarted |
| Unknown | Pod state could not be determined (usually node communication failure) |

| Container status | Meaning |
|---|---|
| Waiting | Container not yet running; common reasons are `ContainerCreating`, `ImagePullBackOff`, `ErrImagePull`, `CrashLoopBackOff`, `CreateContainerConfigError`, `PodInitializing` (for main containers waiting on init containers) |
| Running | Container is executing normally |
| Terminated | Container has finished; reason is `Completed` for exit 0 or `Error` for nonzero exit or `OOMKilled` for memory-kill |

| Common init-container-related states | Meaning |
|---|---|
| Init:0/N | Init container 0 of N is running (or waiting to run) |
| Init:Error | The current init container exited nonzero with `restartPolicy: Never` |
| Init:CrashLoopBackOff | The current init container is failing repeatedly under `restartPolicy: OnFailure` or `Always` |
| PodInitializing | Main container is waiting for init containers to finish |

| Restart policy | Behavior |
|---|---|
| Always (default) | Restart any container that exits, including exit 0 |
| OnFailure | Restart only if exit code is nonzero |
| Never | Never restart; pod transitions to Succeeded or Failed based on exit codes |

| Image pull policy | Behavior |
|---|---|
| Always | Pull from registry on every container start |
| IfNotPresent | Pull only if image not cached on node (default for non-latest tags) |
| Never | Fail if image not already on node |

## Where to Go Next

With the tutorial complete, work through `pod-fundamentals-homework.md` starting at Level 1. Use this tutorial as a reference when you are stuck. The `Reference Commands` and `Pod Phases and Container Statuses` sections above are the most useful quick-lookup material while doing the exercises.
