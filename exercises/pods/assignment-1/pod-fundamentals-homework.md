# Pod Fundamentals Homework

This homework file contains 15 progressive exercises organized into five difficulty levels. The exercises assume you have worked through `pod-fundamentals-tutorial.md`. Each exercise uses its own namespace so that working on one exercise does not disturb any of the others. Complete the exercises in order; the progression is designed to build the diagnostic instincts needed for Level 5. Use `pod-fundamentals-homework-answers.md` only after a genuine attempt at each exercise.

## Setup

Verify that your cluster is running and `kubectl` is working.

```bash
kubectl get nodes
kubectl cluster-info
```

If you want to clear out any leftover exercise namespaces from a previous attempt before you start, run the following global cleanup.

```bash
for i in 1 2 3 4 5; do
  for j in 1 2 3; do
    kubectl delete namespace ex-${i}-${j} --ignore-not-found --wait=false
  done
done
```

You can safely run this at any point to reset, but you do not need to run it now if this is your first time.

-----

## Level 1: Basic Single-Concept Tasks

### Exercise 1.1

**Objective:** Create a pod named `web` that runs `nginx:1.25` in namespace `ex-1-1`.

**Setup:**

```bash
kubectl create namespace ex-1-1
```

**Task:**

Create the pod so that it reaches `Running` state. Use whichever approach you prefer (imperative or declarative).

**Verification:**

```bash
# phase should be Running
kubectl get pod web -n ex-1-1 -o jsonpath='{.status.phase}'; echo

# image should be nginx:1.25
kubectl get pod web -n ex-1-1 -o jsonpath='{.spec.containers[0].image}'; echo

# ready count should be 1/1
kubectl get pod web -n ex-1-1
```

Expected: phase `Running`, image `nginx:1.25`, READY `1/1`.

-----

### Exercise 1.2

**Objective:** Create a pod named `greeter` in namespace `ex-1-2` that runs `echo hello world`, exits once, and does not get restarted.

**Setup:**

```bash
kubectl create namespace ex-1-2
```

**Task:**

The pod must use the `busybox:1.36` image and a `restartPolicy` that lets it complete and stay completed. After creation, the pod's final phase should be `Succeeded`.

**Verification:**

```bash
# wait for the pod to finish
sleep 10

# phase should be Succeeded
kubectl get pod greeter -n ex-1-2 -o jsonpath='{.status.phase}'; echo

# restartPolicy should be Never
kubectl get pod greeter -n ex-1-2 -o jsonpath='{.spec.restartPolicy}'; echo

# logs should contain "hello world"
kubectl logs greeter -n ex-1-2
```

Expected: phase `Succeeded`, restartPolicy `Never`, logs contain `hello world`.

-----

### Exercise 1.3

**Objective:** Create a pod named `envpod` in namespace `ex-1-3` with two literal environment variables.

**Setup:**

```bash
kubectl create namespace ex-1-3
```

**Task:**

The pod should use `busybox:1.36`, run a command that keeps it alive long enough to inspect (for example, `sleep 300` or an `env` dump followed by `sleep`), and have two env vars set to literal values: `APP_NAME=demo` and `APP_TIER=frontend`.

**Verification:**

```bash
# pod should be Running
kubectl get pod envpod -n ex-1-3

# env vars should be present with correct values
kubectl exec envpod -n ex-1-3 -- env | grep -E '^APP_(NAME|TIER)='
```

Expected: `APP_NAME=demo` and `APP_TIER=frontend` both appear in the output.

-----

## Level 2: Multi-Concept Tasks

### Exercise 2.1

**Objective:** Create a pod named `runner` in namespace `ex-2-1` that runs a specific command with arguments, carries three labels, and uses a non-default restart policy.

**Setup:**

```bash
kubectl create namespace ex-2-1
```

**Task:**

The pod must use `busybox:1.36`, run `sh -c "echo starting; sleep 3; echo finishing"` (using `command` and `args` so both override the image defaults), carry labels `app=runner`, `tier=batch`, and `environment=homework`, and use `restartPolicy: OnFailure`.

**Verification:**

```bash
sleep 10

# phase should be Succeeded (clean exit 0 with OnFailure does not restart)
kubectl get pod runner -n ex-2-1 -o jsonpath='{.status.phase}'; echo

# labels should match
kubectl get pod runner -n ex-2-1 -o jsonpath='{.metadata.labels}'; echo

# restartPolicy
kubectl get pod runner -n ex-2-1 -o jsonpath='{.spec.restartPolicy}'; echo

# logs should contain both starting and finishing
kubectl logs runner -n ex-2-1

# command and args should be set
kubectl get pod runner -n ex-2-1 -o jsonpath='{.spec.containers[0].command}'; echo
kubectl get pod runner -n ex-2-1 -o jsonpath='{.spec.containers[0].args}'; echo
```

Expected: phase `Succeeded`, labels include `app=runner`, `tier=batch`, `environment=homework`, restartPolicy `OnFailure`, logs contain both `starting` and `finishing`, command is `["sh","-c"]`, args contains the echo/sleep/echo string.

-----

### Exercise 2.2

**Objective:** Create a multi-container pod named `sharers` in namespace `ex-2-2` where two containers share an `emptyDir` volume and each runs a different command.

**Setup:**

```bash
kubectl create namespace ex-2-2
```

**Task:**

Build a pod with two containers named `producer` and `consumer`, both using `busybox:1.36`. The `producer` container should write the string `hello from producer` to a file in the shared volume, then sleep. The `consumer` container should sleep briefly to let the producer write, then read the file and print its contents, then sleep. Both containers mount the same `emptyDir` volume at any path you choose. Pick a `restartPolicy` that will not keep restarting cleanly-exited containers, so the pod can reach a terminal state after the consumer reads and exits (or choose a restartPolicy and command strategy that keeps the pod Running during verification).

**Verification:**

```bash
sleep 15

# pod should have 2 containers
kubectl get pod sharers -n ex-2-2 -o jsonpath='{.spec.containers[*].name}'; echo

# consumer logs should contain the producer's message
kubectl logs sharers -n ex-2-2 -c consumer | grep "hello from producer"

# the shared volume should be an emptyDir
kubectl get pod sharers -n ex-2-2 -o jsonpath='{.spec.volumes[0].emptyDir}'; echo

# both containers should have a volumeMount for the same volume
kubectl get pod sharers -n ex-2-2 -o jsonpath='{.spec.containers[0].volumeMounts[0].name}'; echo
kubectl get pod sharers -n ex-2-2 -o jsonpath='{.spec.containers[1].volumeMounts[0].name}'; echo
```

Expected: two container names (`producer` and `consumer`), consumer logs contain `hello from producer`, volume is an `emptyDir`, both containers mount the same volume name.

-----

### Exercise 2.3

**Objective:** Create a pod named `metapod` in namespace `ex-2-3` with three environment variables sourced from the downward API.

**Setup:**

```bash
kubectl create namespace ex-2-3
```

**Task:**

The pod must use `busybox:1.36`, run a command that dumps the environment and stays alive long enough for inspection, and have three downward API env vars: `POD_NAME` from `metadata.name`, `POD_NAMESPACE` from `metadata.namespace`, and `NODE_NAME` from `spec.nodeName`. No literal env vars are required.

**Verification:**

```bash
sleep 10

# pod should be Running
kubectl get pod metapod -n ex-2-3

# env vars should be injected with correct values
kubectl exec metapod -n ex-2-3 -- env | grep -E '^(POD_NAME|POD_NAMESPACE|NODE_NAME)='
```

Expected: `POD_NAME=metapod`, `POD_NAMESPACE=ex-2-3`, and `NODE_NAME=<actual-node-name>` all appear.

-----

## Level 3: Debugging Broken Configurations

### Exercise 3.1

**Objective:** The setup below creates a pod that is not running correctly. Diagnose the problem, fix it, and make the pod reach `Running` state with the intended behavior.

**Setup:**

```bash
kubectl create namespace ex-3-1

cat <<'EOF' | kubectl apply -n ex-3-1 -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-1
spec:
  containers:
  - name: web
    image: nginx:1.25-nonexistent-tag
EOF
```

**Task:**

Investigate the pod and resolve whatever is preventing it from running. The fixed pod must keep the name `broken-1` in namespace `ex-3-1`, still use an nginx image, and reach `Running` with `1/1` ready.

**Verification:**

```bash
kubectl get pod broken-1 -n ex-3-1
kubectl get pod broken-1 -n ex-3-1 -o jsonpath='{.status.phase}'; echo
```

Expected: phase `Running`, READY `1/1`.

-----

### Exercise 3.2

**Objective:** The setup below creates a pod that fails to run as intended. Diagnose and fix it.

**Setup:**

```bash
kubectl create namespace ex-3-2

cat <<'EOF' | kubectl apply -n ex-3-2 -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-2
spec:
  restartPolicy: Never
  containers:
  - name: worker
    image: busybox:1.36
    command: ["echo hello world && sleep 30"]
EOF
```

**Task:**

The intent is for the container to print `hello world` and then stay alive for 30 seconds. Fix the pod so that it reaches `Running`, prints `hello world` in its logs, and does not immediately crash. You may edit the spec however you need as long as the pod keeps the name `broken-2` in namespace `ex-3-2` and still uses `busybox:1.36`.

**Verification:**

```bash
sleep 5

# pod should be Running (not CrashLoopBackOff or similar)
kubectl get pod broken-2 -n ex-3-2

# logs should contain hello world
kubectl logs broken-2 -n ex-3-2
```

Expected: phase `Running` with status `Running` (no CrashLoopBackOff), logs contain `hello world`.

-----

### Exercise 3.3

**Objective:** The setup below creates a pod that does not start correctly. Diagnose and fix it so the main container runs.

**Setup:**

```bash
kubectl create namespace ex-3-3

cat <<'EOF' | kubectl apply -n ex-3-3 -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-3
spec:
  restartPolicy: Never
  volumes:
  - name: shared
    emptyDir: {}
  initContainers:
  - name: setup
    image: busybox:1.36
    command: ["sh", "-c"]
    args: ["echo init working; exit 1"]
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

**Task:**

Inspect the pod, determine why the main container is not running, and adjust the spec so that the main container starts successfully and prints `main running` in its logs. The pod must keep the name `broken-3` in namespace `ex-3-3`.

**Verification:**

```bash
sleep 10

# main container should have run
kubectl logs broken-3 -n ex-3-3 -c main

# pod should not be in Init:Error or Init:CrashLoopBackOff
kubectl get pod broken-3 -n ex-3-3
```

Expected: `main running` appears in the `main` container logs, pod status is `Running` or `Completed` (not `Init:Error`, not `Init:CrashLoopBackOff`).

-----

## Level 4: Complex Real-World Scenarios

### Exercise 4.1

**Objective:** Build a pod named `pipeline` in namespace `ex-4-1` that uses an init container to prepare a data file for a main container to consume via a shared `emptyDir`.

**Setup:**

```bash
kubectl create namespace ex-4-1
```

**Task:**

Build a pod with the following properties. The pod uses `restartPolicy: Never`. It has an init container named `loader` using `busybox:1.36` that creates a file at `/data/records.txt` containing exactly three lines: `record-1`, `record-2`, `record-3`. It has a main container named `processor` using `busybox:1.36` that reads `/data/records.txt`, prints the total line count (using `wc -l`) followed by the contents, then exits. Both containers mount the same `emptyDir` volume at `/data`. The pod carries labels `app=pipeline`, `stage=homework`, and `level=4`.

**Verification:**

```bash
sleep 15

# pod should have Succeeded
kubectl get pod pipeline -n ex-4-1 -o jsonpath='{.status.phase}'; echo

# init container should exist and have completed
kubectl get pod pipeline -n ex-4-1 -o jsonpath='{.spec.initContainers[0].name}'; echo
kubectl get pod pipeline -n ex-4-1 -o jsonpath='{.status.initContainerStatuses[0].state}'; echo

# main container should exist and have completed
kubectl get pod pipeline -n ex-4-1 -o jsonpath='{.spec.containers[0].name}'; echo

# loader logs should be clean
kubectl logs pipeline -n ex-4-1 -c loader

# processor logs should show line count 3 and the three records
kubectl logs pipeline -n ex-4-1 -c processor

# labels should be present
kubectl get pod pipeline -n ex-4-1 --show-labels

# volume is emptyDir
kubectl get pod pipeline -n ex-4-1 -o jsonpath='{.spec.volumes[0].emptyDir}'; echo

# both containers mount the same volume
kubectl get pod pipeline -n ex-4-1 -o jsonpath='{.spec.initContainers[0].volumeMounts[0].mountPath}'; echo
kubectl get pod pipeline -n ex-4-1 -o jsonpath='{.spec.containers[0].volumeMounts[0].mountPath}'; echo
```

Expected: phase `Succeeded`, init container named `loader` in terminated state, main container named `processor`, processor logs contain `3` and the three record lines, labels include `app=pipeline`, `stage=homework`, `level=4`, volume is `emptyDir`, both mounts at `/data`.

-----

### Exercise 4.2

**Objective:** Build a pod named `idbox` in namespace `ex-4-2` that combines downward API env vars, literal env vars, and a multi-container layout.

**Setup:**

```bash
kubectl create namespace ex-4-2
```

**Task:**

Build a pod with two containers named `inspector-a` and `inspector-b`, both using `busybox:1.36`. Each container runs `sh -c "env | sort | grep -E '^(POD|NODE|APP)_' ; sleep 300"`. Both containers receive these environment variables: `POD_NAME` from `metadata.name`, `POD_NAMESPACE` from `metadata.namespace`, `NODE_NAME` from `spec.nodeName`, and a literal `APP_ROLE` with different values per container (`inspector-a` gets `APP_ROLE=primary`, `inspector-b` gets `APP_ROLE=secondary`). The pod carries labels `app=idbox` and `tier=demo`, uses `restartPolicy: Always`, and sets `imagePullPolicy: IfNotPresent` on both containers.

**Verification:**

```bash
sleep 10

# phase should be Running
kubectl get pod idbox -n ex-4-2 -o jsonpath='{.status.phase}'; echo

# two containers present with the right names
kubectl get pod idbox -n ex-4-2 -o jsonpath='{.spec.containers[*].name}'; echo

# inspector-a env
kubectl exec idbox -n ex-4-2 -c inspector-a -- env | grep -E '^(POD_NAME|POD_NAMESPACE|NODE_NAME|APP_ROLE)='

# inspector-b env
kubectl exec idbox -n ex-4-2 -c inspector-b -- env | grep -E '^(POD_NAME|POD_NAMESPACE|NODE_NAME|APP_ROLE)='

# labels
kubectl get pod idbox -n ex-4-2 --show-labels

# restartPolicy
kubectl get pod idbox -n ex-4-2 -o jsonpath='{.spec.restartPolicy}'; echo

# imagePullPolicy
kubectl get pod idbox -n ex-4-2 -o jsonpath='{.spec.containers[0].imagePullPolicy}'; echo
kubectl get pod idbox -n ex-4-2 -o jsonpath='{.spec.containers[1].imagePullPolicy}'; echo
```

Expected: phase `Running`, two containers named `inspector-a` and `inspector-b`, each container shows `POD_NAME=idbox`, `POD_NAMESPACE=ex-4-2`, `NODE_NAME=<node>`, with `inspector-a` showing `APP_ROLE=primary` and `inspector-b` showing `APP_ROLE=secondary`, labels include `app=idbox` and `tier=demo`, restartPolicy `Always`, both imagePullPolicy `IfNotPresent`.

-----

### Exercise 4.3

**Objective:** Build a pod named `report` in namespace `ex-4-3` that uses two sequential init containers followed by a main container, coordinating via an `emptyDir`.

**Setup:**

```bash
kubectl create namespace ex-4-3
```

**Task:**

Build a pod where two init containers run in sequence before the main container starts. The first init container `fetcher` (using `busybox:1.36`) writes a file at `/work/raw.txt` containing three lines: `alpha`, `beta`, `gamma`. The second init container `transformer` (using `busybox:1.36`) reads `/work/raw.txt` and writes a transformed file at `/work/final.txt` where every line is uppercased (for example, using `tr a-z A-Z`). The main container `printer` (using `busybox:1.36`) reads and prints `/work/final.txt`, then exits. All three containers share the same `emptyDir` volume mounted at `/work`. Use `restartPolicy: OnFailure`.

**Verification:**

```bash
sleep 15

# phase should be Succeeded
kubectl get pod report -n ex-4-3 -o jsonpath='{.status.phase}'; echo

# two init containers named fetcher and transformer, in that order
kubectl get pod report -n ex-4-3 -o jsonpath='{.spec.initContainers[*].name}'; echo

# main container named printer
kubectl get pod report -n ex-4-3 -o jsonpath='{.spec.containers[0].name}'; echo

# fetcher init container should have Completed
kubectl get pod report -n ex-4-3 -o jsonpath='{.status.initContainerStatuses[0].state.terminated.reason}'; echo

# transformer init container should have Completed
kubectl get pod report -n ex-4-3 -o jsonpath='{.status.initContainerStatuses[1].state.terminated.reason}'; echo

# printer should show the uppercased lines
kubectl logs report -n ex-4-3 -c printer

# volume is emptyDir
kubectl get pod report -n ex-4-3 -o jsonpath='{.spec.volumes[0].emptyDir}'; echo

# all three containers mount /work
kubectl get pod report -n ex-4-3 -o jsonpath='{.spec.initContainers[0].volumeMounts[0].mountPath}'; echo
kubectl get pod report -n ex-4-3 -o jsonpath='{.spec.initContainers[1].volumeMounts[0].mountPath}'; echo
kubectl get pod report -n ex-4-3 -o jsonpath='{.spec.containers[0].volumeMounts[0].mountPath}'; echo

# restartPolicy
kubectl get pod report -n ex-4-3 -o jsonpath='{.spec.restartPolicy}'; echo
```

Expected: phase `Succeeded`; init containers in order `fetcher transformer`; main container `printer`; both init containers terminated with reason `Completed`; printer logs contain `ALPHA`, `BETA`, `GAMMA`; volume is `emptyDir`; all three mounts at `/work`; restartPolicy `OnFailure`.

-----

## Level 5: Advanced Debugging and Comprehensive Tasks

### Exercise 5.1

**Objective:** The setup below creates a pod that is failing for more than one reason. Diagnose every problem, fix them all, and get the pod into the intended working state.

**Setup:**

```bash
kubectl create namespace ex-5-1

cat <<'EOF' | kubectl apply -n ex-5-1 -f -
apiVersion: v1
kind: Pod
metadata:
  name: multibug
spec:
  restartPolicy: Never
  containers:
  - name: app
    image: busybox:2.99
    command: ["echo; sleep 30"]
    args: ["starting multibug"]
    env:
    - name: APP_NAME
      value: multibug
    - name: APP_TIER
      valueFrom:
        fieldRef:
          fieldPath: metadata.labels.tier
EOF
```

**Task:**

The intent for this pod is as follows. It should use a real `busybox` image tag. It should print `starting multibug` in its logs, then sleep long enough for you to inspect it (30 seconds is fine). It should carry at least one label `tier=backend`, and `APP_TIER` should resolve to `backend` via the downward API. You may edit the spec however you need. The pod must keep the name `multibug` in namespace `ex-5-1`.

**Verification:**

```bash
sleep 5

# pod should reach Running
kubectl get pod multibug -n ex-5-1 -o jsonpath='{.status.phase}'; echo

# pod should not be Waiting on image
kubectl get pod multibug -n ex-5-1 -o jsonpath='{.status.containerStatuses[0].state}'; echo

# logs should contain "starting multibug"
kubectl logs multibug -n ex-5-1

# label tier=backend should exist
kubectl get pod multibug -n ex-5-1 -o jsonpath='{.metadata.labels.tier}'; echo

# APP_NAME env var should be multibug
kubectl exec multibug -n ex-5-1 -- env | grep '^APP_NAME='

# APP_TIER env var should be backend
kubectl exec multibug -n ex-5-1 -- env | grep '^APP_TIER='

# image should be a valid busybox tag (not 2.99)
kubectl get pod multibug -n ex-5-1 -o jsonpath='{.spec.containers[0].image}'; echo
```

Expected: phase `Running`, container state is `running` (not waiting), logs contain `starting multibug`, label `tier=backend` exists, `APP_NAME=multibug`, `APP_TIER=backend`, image is a valid busybox tag that exists in registries (for example `busybox:1.36`).

-----

### Exercise 5.2

**Objective:** The setup below creates a pod whose main container never produces the expected output. Diagnose the coordination issue, fix it, and verify that the main container reads the data produced by the init container.

**Setup:**

```bash
kubectl create namespace ex-5-2

cat <<'EOF' | kubectl apply -n ex-5-2 -f -
apiVersion: v1
kind: Pod
metadata:
  name: coord
spec:
  restartPolicy: Never
  volumes:
  - name: work
    emptyDir: {}
  initContainers:
  - name: preparer
    image: busybox:1.36
    command: ["sh", "-c"]
    args: ["echo payload-ready > /tmp/payload.txt; echo preparer done"]
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

**Task:**

The intent is for the init container to write `payload-ready` to a file on the shared volume, and for the main container to read that file and print its contents followed by `consumer done`. Fix the spec so the coordination works. The pod must keep the name `coord` in namespace `ex-5-2`, both containers must keep their names, and the init container must keep writing a file containing `payload-ready` that the main container reads through the shared `emptyDir`.

**Verification:**

```bash
sleep 10

# phase should be Succeeded
kubectl get pod coord -n ex-5-2 -o jsonpath='{.status.phase}'; echo

# init container preparer should be Completed
kubectl get pod coord -n ex-5-2 -o jsonpath='{.status.initContainerStatuses[0].state.terminated.reason}'; echo

# consumer logs should contain payload-ready AND consumer done
kubectl logs coord -n ex-5-2 -c consumer

# consumer exit code should be 0
kubectl get pod coord -n ex-5-2 -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}'; echo

# consumer logs must not contain "No such file or directory"
kubectl logs coord -n ex-5-2 -c consumer | grep -c "No such file" || echo "clean"
```

Expected: phase `Succeeded`, preparer terminated with reason `Completed`, consumer logs contain both `payload-ready` and `consumer done`, exit code `0`, and no `No such file or directory` errors.

-----

### Exercise 5.3

**Objective:** The setup below creates a pod that does not behave as intended. Diagnose and fix whatever is wrong so the pod completes as described.

**Setup:**

```bash
kubectl create namespace ex-5-3

cat <<'EOF' | kubectl apply -n ex-5-3 -f -
apiVersion: v1
kind: Pod
metadata:
  name: subtle
  labels:
    app: subtle
spec:
  restartPolicy: Always
  volumes:
  - name: scratch
    emptyDir: {}
  initContainers:
  - name: seed
    image: busybox:1.36
    command: ["/bin/true"]
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

**Task:**

The intent is that the init container creates `/scratch/marker.txt` with contents `seeded` on the shared volume, and the main container finds that marker, prints `found marker: seeded`, and then idles for 30 seconds. The pod should reach a terminal state (`Succeeded`) after the worker completes. Adjust the spec however is necessary so the intent is realized. The pod must keep the name `subtle` in namespace `ex-5-3`, use the same two containers (`seed` init and `worker` main), and use an `emptyDir` for sharing.

**Verification:**

```bash
sleep 45

# init container should be Completed
kubectl get pod subtle -n ex-5-3 -o jsonpath='{.status.initContainerStatuses[0].state.terminated.reason}'; echo

# worker logs should show "found marker: seeded"
kubectl logs subtle -n ex-5-3 -c worker

# worker logs must not contain "no marker present"
kubectl logs subtle -n ex-5-3 -c worker | grep -c "no marker" || echo "clean"

# pod should end in Succeeded, not keep restarting
kubectl get pod subtle -n ex-5-3 -o jsonpath='{.status.phase}'; echo

# worker should have terminated with exit code 0
kubectl get pod subtle -n ex-5-3 -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}'; echo

# restart count on worker should be low (ideally 0)
kubectl get pod subtle -n ex-5-3 -o jsonpath='{.status.containerStatuses[0].restartCount}'; echo

# volume is emptyDir
kubectl get pod subtle -n ex-5-3 -o jsonpath='{.spec.volumes[0].emptyDir}'; echo

# init container still named seed
kubectl get pod subtle -n ex-5-3 -o jsonpath='{.spec.initContainers[0].name}'; echo

# main container still named worker
kubectl get pod subtle -n ex-5-3 -o jsonpath='{.spec.containers[0].name}'; echo

# label app=subtle still present
kubectl get pod subtle -n ex-5-3 -o jsonpath='{.metadata.labels.app}'; echo
```

Expected: init container terminated with reason `Completed`, worker logs show `found marker: seeded` and no `no marker` lines, pod phase `Succeeded`, worker exit code `0`, restart count low (ideally 0), volume is `emptyDir`, container names unchanged, label `app=subtle` preserved.

-----

## Cleanup

Delete the namespaces from specific exercises you are finished with.

```bash
# one at a time
kubectl delete namespace ex-1-1
kubectl delete namespace ex-1-2
# ...
```

Or clean everything at once.

```bash
for i in 1 2 3 4 5; do
  for j in 1 2 3; do
    kubectl delete namespace ex-${i}-${j} --ignore-not-found --wait=false
  done
done
```

-----

## Key Takeaways

Pod construction is the base skill on top of which every other Kubernetes workload type is built. A Deployment is ultimately a controller that creates pods from a template, and that template is a pod spec. Getting fluent with the pod spec is what makes the rest of Kubernetes feel simple rather than mysterious, and on the CKA exam the time you save by writing pod specs quickly and correctly is time you have to solve harder problems elsewhere.

A few specific lessons from these 15 exercises are worth internalizing. The `command` and `args` fields override Docker's `ENTRYPOINT` and `CMD` respectively, and they each take a list of strings, not a single shell command string; when you want shell behavior, you explicitly use `sh -c` and put the shell command string in `args`. Restart policy interacts with init container failures in a way that is easy to miss: `Never` turns an init failure into a permanent `Init:Error`, while `OnFailure` and `Always` both cause it to retry and produce `Init:CrashLoopBackOff`. The downward API via `fieldRef` is the only clean way to inject a pod's own identity (name, namespace, node) into its containers at runtime. Multi-container pods share a network namespace and can share volumes, with `emptyDir` being the simplest shared volume type and the only one in scope for this assignment; each container must have a unique name, and `kubectl logs` requires `-c` to pick one. The three pieces of output you rely on for diagnosing any broken pod are `kubectl get pod` for the high-level status, `kubectl describe pod` for the events and container-level detail, and `kubectl logs` (with `--previous` and `-c` as needed) for what the code actually said.

Move on to the answer key only after you have a complete attempt on every exercise. The answer key explains both what the correct solution is and how you would have arrived at it diagnostically, which is the skill the exam actually tests.
