# StatefulSets Homework: 15 Progressive Exercises

These exercises build on the concepts covered in `statefulsets-tutorial.md`. Before starting, work through the tutorial or at least read the Reference Commands section at the end of it.

All exercises assume the multi-node kind cluster described in `docs/cluster-setup.md#multi-node-kind-cluster`:

```bash
kubectl config current-context   # should print kind-kind
kubectl get nodes                # expect: 4 nodes (1 control-plane, 3 workers), all Ready
```

Every exercise has its own namespace (`ex-1-1`, `ex-1-2`, and so on) so they do not collide. Each exercise uses distinct StatefulSet and Service base names so PVCs, pod DNS records, and ControllerRevisions stay isolated. Verification blocks use explicit expected outputs with `# Expected:` comments; avoid relying on "looks OK" reasoning.

## Global Setup

Run this once before starting. It creates every exercise namespace:

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 \
          ex-2-1 ex-2-2 ex-2-3 \
          ex-3-1 ex-3-2 ex-3-3 \
          ex-4-1 ex-4-2 ex-4-3 \
          ex-5-1 ex-5-2 ex-5-3; do
  kubectl create namespace $ns
done
```

Per-exercise setup commands follow. Each exercise is self-contained: read the objective, run the setup, solve the task, then run the verification block.

---

## Level 1: Basics

### Exercise 1.1

**Objective:** Create a 3-replica StatefulSet named `app` with a paired headless Service, so that pods come up in order and have stable hostnames.

**Setup:**

```bash
# No pre-existing objects; you will build the StatefulSet + Service from scratch.
kubectl get nodes
```

**Task:**

In namespace `ex-1-1`, create a headless Service named `app-hdr` that selects pods with label `app=app`, exposes port 80 named `http`, and has `clusterIP: None`. Create a StatefulSet named `app` with 3 replicas that uses `app-hdr` as its `serviceName`, runs `nginx:1.27` as a single container on port 80, and labels its pods `app=app`. No `volumeClaimTemplates` for this exercise.

**Verification:**

```bash
kubectl -n ex-1-1 get svc app-hdr -o jsonpath='{.spec.clusterIP}'
echo
# Expected: None

kubectl -n ex-1-1 rollout status statefulset/app --timeout=120s
# Expected: statefulset rolling update complete 3 pods at revision ...

kubectl -n ex-1-1 get pods -l app=app \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.status.phase}{"\n"}{end}'
# Expected (order may vary):
# app-0 Running
# app-1 Running
# app-2 Running

kubectl -n ex-1-1 get pod app-0 \
  -o jsonpath='{.metadata.labels.apps\.kubernetes\.io/pod-index}{"\n"}'
# Expected: 0
```

---

### Exercise 1.2

**Objective:** Create a StatefulSet with `volumeClaimTemplates` so that each pod gets its own PVC.

**Setup:**

```bash
kubectl -n ex-1-2 get storageclass
# Expected: a StorageClass named `standard` (the kind default) listed.
```

**Task:**

In namespace `ex-1-2`, create a headless Service named `store-hdr` (`clusterIP: None`, selector `app=store`). Create a StatefulSet named `store` with 3 replicas that uses `store-hdr` as its `serviceName`, runs `nginx:1.27`, and has a `volumeClaimTemplates` entry named `data` requesting 256Mi with access mode `ReadWriteOnce`, mounted at `/usr/share/nginx/html` inside the container. Omit `storageClassName` so kind's default `standard` class is used.

**Verification:**

```bash
kubectl -n ex-1-2 rollout status statefulset/store --timeout=120s
# Expected: statefulset rolling update complete

kubectl -n ex-1-2 get pvc -l app!= \
  -o jsonpath='{range .items[*]}{.metadata.name}:{.status.phase}{"\n"}{end}'
# Expected (order may vary):
# data-store-0:Bound
# data-store-1:Bound
# data-store-2:Bound

kubectl -n ex-1-2 get pod store-1 \
  -o jsonpath='{.spec.volumes[?(@.name=="data")].persistentVolumeClaim.claimName}{"\n"}'
# Expected: data-store-1
```

---

### Exercise 1.3

**Objective:** Create a StatefulSet that starts its pods in parallel instead of one at a time.

**Setup:**

```bash
# No pre-existing objects.
echo "Namespace ex-1-3 ready."
```

**Task:**

In namespace `ex-1-3`, create a headless Service named `fleet-hdr` and a 4-replica StatefulSet named `fleet` that uses `podManagementPolicy: Parallel` to launch all four pods at once. Use `nginx:1.27` as the container image.

**Verification:**

```bash
# Pods should reach Running close together; capture start times to prove parallel launch.
kubectl -n ex-1-3 rollout status statefulset/fleet --timeout=120s

kubectl -n ex-1-3 get pods -l app=fleet \
  -o jsonpath='{range .items[*]}{.metadata.name}:{.status.startTime}{"\n"}{end}'
# Expected: four lines (fleet-0 through fleet-3) all with start times within a few
# seconds of each other. Under OrderedReady the gaps would be tens of seconds.

kubectl -n ex-1-3 get statefulset fleet \
  -o jsonpath='{.spec.podManagementPolicy}{"\n"}'
# Expected: Parallel
```

---

## Level 2: Multi-Concept

### Exercise 2.1

**Objective:** Demonstrate that per-pod storage survives a pod restart.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: files-hdr
  namespace: ex-2-1
  labels:
    app: files
spec:
  clusterIP: None
  ports:
    - port: 80
      name: http
  selector:
    app: files
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: files
  namespace: ex-2-1
  labels:
    app: files
spec:
  serviceName: files-hdr
  replicas: 3
  selector:
    matchLabels:
      app: files
  template:
    metadata:
      labels:
        app: files
    spec:
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
              name: http
          volumeMounts:
            - name: data
              mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 256Mi
EOF

kubectl -n ex-2-1 rollout status statefulset/files --timeout=120s
```

**Task:**

Write a distinct marker file into each pod's volume (`/usr/share/nginx/html/marker.txt`) containing the pod's own name. Then delete pod `files-1`, wait for it to come back, and confirm the marker file for `files-1` is intact. Do the same for `files-2` (delete and verify).

**Verification:**

```bash
# Marker files for each pod (after you write them):
for i in 0 1 2; do
  kubectl -n ex-2-1 exec files-$i -- cat /usr/share/nginx/html/marker.txt
done
# Expected output (one per line):
# files-0
# files-1
# files-2

# Delete files-1, wait, confirm marker survives:
kubectl -n ex-2-1 delete pod files-1
kubectl -n ex-2-1 wait --for=condition=Ready pod/files-1 --timeout=120s
kubectl -n ex-2-1 exec files-1 -- cat /usr/share/nginx/html/marker.txt
# Expected: files-1

# Same for files-2:
kubectl -n ex-2-1 delete pod files-2
kubectl -n ex-2-1 wait --for=condition=Ready pod/files-2 --timeout=120s
kubectl -n ex-2-1 exec files-2 -- cat /usr/share/nginx/html/marker.txt
# Expected: files-2

# Confirm the PVCs did not change identity:
kubectl -n ex-2-1 get pod files-1 \
  -o jsonpath='{.spec.volumes[?(@.name=="data")].persistentVolumeClaim.claimName}{"\n"}'
# Expected: data-files-1
```

---

### Exercise 2.2

**Objective:** Perform a staged rolling update using `updateStrategy.rollingUpdate.partition`.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: service-hdr
  namespace: ex-2-2
spec:
  clusterIP: None
  ports:
    - port: 80
      name: http
  selector:
    app: service
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: service
  namespace: ex-2-2
spec:
  serviceName: service-hdr
  replicas: 5
  selector:
    matchLabels:
      app: service
  template:
    metadata:
      labels:
        app: service
    spec:
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
              name: http
EOF

kubectl -n ex-2-2 rollout status statefulset/service --timeout=120s
```

**Task:**

Update the StatefulSet so that only pods with ordinal 3 or higher are allowed to change, then change the image from `nginx:1.27` to `nginx:1.27.3`. After the rollout settles, verify that `service-0`, `service-1`, and `service-2` still run `nginx:1.27` while `service-3` and `service-4` run `nginx:1.27.3`. Then lower the partition to 0 and confirm every pod ends up on `nginx:1.27.3`.

**Verification:**

```bash
# After setting partition=3 and updating the image:
for i in 0 1 2 3 4; do
  kubectl -n ex-2-2 get pod service-$i \
    -o jsonpath="{.metadata.name}:{.spec.containers[0].image}{\"\n\"}"
done
# Expected:
# service-0:nginx:1.27
# service-1:nginx:1.27
# service-2:nginx:1.27
# service-3:nginx:1.27.3
# service-4:nginx:1.27.3

# After lowering partition to 0 and the rollout completes:
kubectl -n ex-2-2 rollout status statefulset/service --timeout=180s
for i in 0 1 2 3 4; do
  kubectl -n ex-2-2 get pod service-$i \
    -o jsonpath="{.metadata.name}:{.spec.containers[0].image}{\"\n\"}"
done
# Expected: all five pods on nginx:1.27.3
```

---

### Exercise 2.3

**Objective:** Use the `OnDelete` update strategy so that template changes stage but do not roll automatically.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: workers-hdr
  namespace: ex-2-3
spec:
  clusterIP: None
  ports:
    - port: 80
      name: http
  selector:
    app: workers
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: workers
  namespace: ex-2-3
spec:
  serviceName: workers-hdr
  replicas: 3
  updateStrategy:
    type: OnDelete
  selector:
    matchLabels:
      app: workers
  template:
    metadata:
      labels:
        app: workers
    spec:
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
              name: http
EOF

kubectl -n ex-2-3 rollout status statefulset/workers --timeout=120s || true
# Note: under OnDelete, rollout status reports completion immediately after apply,
# because the strategy does not drive updates.
```

**Task:**

Change the image on the `workers` StatefulSet from `nginx:1.27` to `nginx:1.27.3`. Verify that none of the pods changed. Then delete only pod `workers-1`; wait for its replacement; verify that only `workers-1` now runs `nginx:1.27.3` while `workers-0` and `workers-2` still run `nginx:1.27`.

**Verification:**

```bash
# After setting the image but before deleting any pod:
for i in 0 1 2; do
  kubectl -n ex-2-3 get pod workers-$i \
    -o jsonpath="{.metadata.name}:{.spec.containers[0].image}{\"\n\"}"
done
# Expected: all three still on nginx:1.27

# After deleting workers-1 only:
kubectl -n ex-2-3 delete pod workers-1
kubectl -n ex-2-3 wait --for=condition=Ready pod/workers-1 --timeout=120s
for i in 0 1 2; do
  kubectl -n ex-2-3 get pod workers-$i \
    -o jsonpath="{.metadata.name}:{.spec.containers[0].image}{\"\n\"}"
done
# Expected:
# workers-0:nginx:1.27
# workers-1:nginx:1.27.3
# workers-2:nginx:1.27
```

---

## Level 3: Debugging Broken Configurations

### Exercise 3.1

**Objective:** Fix the broken configuration so that the StatefulSet `vault` successfully runs three pods with persistent storage.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: vault-hdr
  namespace: ex-3-1
spec:
  clusterIP: None
  ports:
    - port: 80
      name: http
  selector:
    app: vault
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: vault
  namespace: ex-3-1
spec:
  serviceName: vault-hdr
  replicas: 3
  selector:
    matchLabels:
      app: vault
  template:
    metadata:
      labels:
        app: vault
    spec:
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
              name: http
          volumeMounts:
            - name: data
              mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: fast-ssd
        resources:
          requests:
            storage: 256Mi
EOF
```

**Task:**

After the objects above apply, the StatefulSet does not come up. Find and fix the single issue so that `vault-0`, `vault-1`, and `vault-2` all reach `Ready`.

**Verification:**

```bash
kubectl -n ex-3-1 rollout status statefulset/vault --timeout=120s
# Expected: statefulset rolling update complete 3 pods

kubectl -n ex-3-1 get pvc \
  -o jsonpath='{range .items[*]}{.metadata.name}:{.status.phase}{"\n"}{end}'
# Expected:
# data-vault-0:Bound
# data-vault-1:Bound
# data-vault-2:Bound
```

---

### Exercise 3.2

**Objective:** Fix the broken configuration so that `discovery-0` is reachable by DNS name from another pod.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: discovery-svc
  namespace: ex-3-2
spec:
  ports:
    - port: 80
      name: http
  selector:
    app: discovery
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: discovery
  namespace: ex-3-2
spec:
  serviceName: discovery-svc
  replicas: 3
  selector:
    matchLabels:
      app: discovery
  template:
    metadata:
      labels:
        app: discovery
    spec:
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
              name: http
EOF

kubectl -n ex-3-2 rollout status statefulset/discovery --timeout=120s
```

**Task:**

The pods come up but `discovery-0.discovery-svc.ex-3-2.svc.cluster.local` does not resolve from other pods in the cluster. Find and fix the single issue so that per-pod DNS works.

**Verification:**

```bash
kubectl -n ex-3-2 get svc discovery-svc \
  -o jsonpath='{.spec.clusterIP}'
echo
# Expected: None

# From a debug pod, nslookup must return a specific IP for discovery-0:
kubectl -n ex-3-2 run nsprobe --rm -it --restart=Never --image=busybox:1.36 \
  -- nslookup discovery-0.discovery-svc
# Expected: a line of the form `Name: discovery-0.discovery-svc...` followed by
# an `Address:` line showing the pod IP. NXDOMAIN is a failure.
```

---

### Exercise 3.3

**Objective:** Fix the broken configuration so that `members-0` resolves by DNS name.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: members-gov
  namespace: ex-3-3
spec:
  clusterIP: None
  ports:
    - port: 80
      name: http
  selector:
    app: members
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: members
  namespace: ex-3-3
spec:
  serviceName: members-headless
  replicas: 3
  selector:
    matchLabels:
      app: members
  template:
    metadata:
      labels:
        app: members
    spec:
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
              name: http
EOF

kubectl -n ex-3-3 rollout status statefulset/members --timeout=120s
```

**Task:**

The StatefulSet applies and pods run, but the DNS name `members-0.members-gov.ex-3-3.svc.cluster.local` does not resolve from other pods in the cluster. Find and fix the single issue so that per-pod DNS works against the existing `members-gov` Service.

**Verification:**

```bash
kubectl -n ex-3-3 get statefulset members \
  -o jsonpath='{.spec.serviceName}{"\n"}'
# Expected: members-gov

# DNS must resolve from a debug pod:
kubectl -n ex-3-3 run nsprobe --rm -it --restart=Never --image=busybox:1.36 \
  -- nslookup members-0.members-gov
# Expected: an Address line for members-0 (pod IP). NXDOMAIN is a failure.
```

---

## Level 4: Complex Real-World Scenarios

### Exercise 4.1

**Objective:** Build a multi-tier application where a Deployment frontend reaches a specific database pod by its stable DNS name.

**Setup:**

```bash
# No pre-existing objects; build everything from scratch.
kubectl -n ex-4-1 get nodes -o name | head -1
```

**Task:**

In namespace `ex-4-1`, build:

1. A headless Service named `db-hdr` (`clusterIP: None`, selector `app=db`, port 80/http).
2. A 3-replica StatefulSet named `db` using `db-hdr` as `serviceName`, running `nginx:1.27`, with a `volumeClaimTemplates` entry named `data` of 256Mi mounted at `/usr/share/nginx/html`.
3. After the StatefulSet is up, write a distinct HTML file to each pod's volume: `db-0` serves `primary`, `db-1` serves `replica-a`, `db-2` serves `replica-b`.
4. A regular Service named `db-primary` (`type: ClusterIP`) whose selector targets only `db-0` by using the `statefulset.kubernetes.io/pod-name: db-0` label.
5. A 1-replica Deployment named `app` running `curlimages/curl:8.5.0` in a pod that curls `db-0.db-hdr` once per second and logs the response. The command can be `["sh", "-c", "while true; do curl -sf http://db-0.db-hdr/ || echo error; sleep 1; done"]`.

**Verification:**

```bash
# StatefulSet pods up and labeled with pod-name:
kubectl -n ex-4-1 get pod db-0 \
  -o jsonpath='{.metadata.labels.statefulset\.kubernetes\.io/pod-name}{"\n"}'
# Expected: db-0

# Content written per-pod:
kubectl -n ex-4-1 exec db-0 -- cat /usr/share/nginx/html/index.html
# Expected: primary
kubectl -n ex-4-1 exec db-1 -- cat /usr/share/nginx/html/index.html
# Expected: replica-a
kubectl -n ex-4-1 exec db-2 -- cat /usr/share/nginx/html/index.html
# Expected: replica-b

# db-primary service targets only db-0:
kubectl -n ex-4-1 get endpointslice -l kubernetes.io/service-name=db-primary \
  -o jsonpath='{.items[0].endpoints[*].targetRef.name}{"\n"}'
# Expected: db-0  (exactly one pod in the endpoint slice)

# Frontend Deployment's logs show responses from db-0 only:
APP_POD=$(kubectl -n ex-4-1 get pods -l app=app -o jsonpath='{.items[0].metadata.name}')
kubectl -n ex-4-1 logs $APP_POD --tail=5
# Expected: five lines each containing "primary" (the body of db-0's index.html),
# interleaved with curl exit messages only if the request failed.
```

---

### Exercise 4.2

**Objective:** Drive a full staged rollout through multiple partition values on a 6-replica StatefulSet.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-hdr
  namespace: ex-4-2
spec:
  clusterIP: None
  ports:
    - port: 80
      name: http
  selector:
    app: web
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
  namespace: ex-4-2
spec:
  serviceName: web-hdr
  replicas: 6
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
              name: http
EOF

kubectl -n ex-4-2 rollout status statefulset/web --timeout=180s
```

**Task:**

Perform a staged rollout from `nginx:1.27` to `nginx:1.27.3` using three phases. In phase 1, set partition to 5 and update the image; only `web-5` should update. In phase 2, set partition to 3; `web-3` and `web-4` should also update. In phase 3, set partition to 0; the remaining pods should update. Wait for each phase to settle before moving to the next.

**Verification:**

```bash
# After phase 1 (partition=5):
for i in 0 1 2 3 4 5; do
  kubectl -n ex-4-2 get pod web-$i \
    -o jsonpath="{.metadata.name}:{.spec.containers[0].image}{\"\n\"}"
done
# Expected:
# web-0:nginx:1.27
# web-1:nginx:1.27
# web-2:nginx:1.27
# web-3:nginx:1.27
# web-4:nginx:1.27
# web-5:nginx:1.27.3

# After phase 2 (partition=3):
for i in 0 1 2 3 4 5; do
  kubectl -n ex-4-2 get pod web-$i \
    -o jsonpath="{.metadata.name}:{.spec.containers[0].image}{\"\n\"}"
done
# Expected:
# web-0:nginx:1.27
# web-1:nginx:1.27
# web-2:nginx:1.27
# web-3:nginx:1.27.3
# web-4:nginx:1.27.3
# web-5:nginx:1.27.3

# After phase 3 (partition=0):
kubectl -n ex-4-2 rollout status statefulset/web --timeout=180s
for i in 0 1 2 3 4 5; do
  kubectl -n ex-4-2 get pod web-$i \
    -o jsonpath="{.metadata.name}:{.spec.containers[0].image}{\"\n\"}"
done
# Expected: all six on nginx:1.27.3.
```

---

### Exercise 4.3

**Objective:** Demonstrate that scale-down preserves PVC identity and that scale-up reattaches the same PVCs with the same data.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: shard-hdr
  namespace: ex-4-3
spec:
  clusterIP: None
  ports:
    - port: 80
      name: http
  selector:
    app: shard
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: shard
  namespace: ex-4-3
spec:
  serviceName: shard-hdr
  replicas: 4
  selector:
    matchLabels:
      app: shard
  template:
    metadata:
      labels:
        app: shard
    spec:
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
              name: http
          volumeMounts:
            - name: data
              mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 256Mi
EOF

kubectl -n ex-4-3 rollout status statefulset/shard --timeout=180s
```

**Task:**

Write a distinct marker file to each pod's volume containing `data for shard-<ordinal>`. Scale the StatefulSet to 1 replica. Verify that four PVCs still exist. Scale it back to 4 replicas. Verify that the marker file for each pod is still there (same content as before).

**Verification:**

```bash
# Marker files written before scaling:
for i in 0 1 2 3; do
  kubectl -n ex-4-3 exec shard-$i -- cat /usr/share/nginx/html/marker.txt
done
# Expected:
# data for shard-0
# data for shard-1
# data for shard-2
# data for shard-3

# After scaling to 1:
kubectl -n ex-4-3 scale statefulset shard --replicas=1
sleep 5
kubectl -n ex-4-3 get pods -l app=shard \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
# Expected: only shard-0 listed (after termination settles)

kubectl -n ex-4-3 get pvc \
  -o jsonpath='{range .items[*]}{.metadata.name}:{.status.phase}{"\n"}{end}'
# Expected: four PVCs all Bound (data-shard-0 through data-shard-3)

# After scaling back to 4:
kubectl -n ex-4-3 scale statefulset shard --replicas=4
kubectl -n ex-4-3 rollout status statefulset/shard --timeout=180s

for i in 0 1 2 3; do
  kubectl -n ex-4-3 exec shard-$i -- cat /usr/share/nginx/html/marker.txt
done
# Expected: each pod reports its original marker content.
```

---

## Level 5: Advanced Debugging and Comprehensive Tasks

### Exercise 5.1

**Objective:** Build a peer-discoverable clustered application in which every pod knows its own role (leader or follower) based on ordinal and resolves its peers by DNS.

**Setup:**

```bash
# No pre-existing objects; build everything from scratch.
kubectl -n ex-5-1 get nodes -o name | head -1
```

**Task:**

In namespace `ex-5-1`, build:

1. A headless Service named `cluster-hdr`.
2. A 3-replica StatefulSet named `cluster`. Use an init container that inspects the pod's hostname (set to `<pod-name>` automatically by the StatefulSet controller; the shell will see it in `$HOSTNAME`). If the hostname ends in `-0`, write `leader` to `/shared/role`; otherwise write `follower`. Use an `emptyDir` volume named `shared` mounted into both the init container and the main container.
3. The main container runs `nginx:1.27`, serves `/shared/role` as its index page (mount `shared` at `/usr/share/nginx/html`).
4. Each pod should be reachable by DNS as `cluster-<N>.cluster-hdr` and return its role when curled on port 80.

**Verification:**

```bash
kubectl -n ex-5-1 rollout status statefulset/cluster --timeout=180s

# Role assignment per pod:
for i in 0 1 2; do
  kubectl -n ex-5-1 exec cluster-$i -- cat /usr/share/nginx/html/role
done
# Expected:
# leader
# follower
# follower

# Peer resolution from a debug pod:
kubectl -n ex-5-1 run clusterprobe --rm -it --restart=Never --image=busybox:1.36 \
  -- sh -c 'for i in 0 1 2; do wget -qO- http://cluster-$i.cluster-hdr/; done'
# Expected output (three lines, in this order):
# leader
# follower
# follower

# Headless Service returns all three pod IPs:
kubectl -n ex-5-1 run srvprobe --rm -it --restart=Never --image=busybox:1.36 \
  -- nslookup cluster-hdr
# Expected: three `Address:` lines, one per pod.
```

---

### Exercise 5.2

**Objective:** Fix the broken configuration so that StatefulSet `broker` runs three pods with persistent storage and per-pod DNS resolution.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: broker-svc
  namespace: ex-5-2
spec:
  ports:
    - port: 80
      name: http
  selector:
    app: broker
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: broker
  namespace: ex-5-2
spec:
  serviceName: broker-hdr
  replicas: 3
  selector:
    matchLabels:
      app: broker
  template:
    metadata:
      labels:
        app: broker
    spec:
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
              name: http
          volumeMounts:
            - name: data
              mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: fast-tier
        resources:
          requests:
            storage: 256Mi
EOF
```

**Task:**

The objects above applied but the StatefulSet is not functional. There are multiple problems in the manifest. Find and fix whatever is needed so that the verification block passes: the three pods must become Ready, each must get a Bound PVC, and DNS resolution for `broker-0.<service>.ex-5-2.svc.cluster.local` must work from another pod.

**Verification:**

```bash
kubectl -n ex-5-2 rollout status statefulset/broker --timeout=180s
# Expected: statefulset rolling update complete 3 pods

kubectl -n ex-5-2 get pvc \
  -o jsonpath='{range .items[*]}{.metadata.name}:{.status.phase}{"\n"}{end}'
# Expected: three PVCs all Bound (data-broker-0, data-broker-1, data-broker-2).

kubectl -n ex-5-2 get statefulset broker \
  -o jsonpath='{.spec.serviceName}{"\n"}'
# Expected: a Service name that actually exists and is headless.

SERVICE=$(kubectl -n ex-5-2 get statefulset broker -o jsonpath='{.spec.serviceName}')
kubectl -n ex-5-2 get svc $SERVICE -o jsonpath='{.spec.clusterIP}{"\n"}'
# Expected: None

kubectl -n ex-5-2 run dnsprobe --rm -it --restart=Never --image=busybox:1.36 \
  -- nslookup broker-0.$SERVICE
# Expected: an Address: line for broker-0.
```

---

### Exercise 5.3

**Objective:** Execute a canary-style rollout that discovers a bad image, roll back using ControllerRevision history, and then complete the rollout with a good image.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: api-hdr
  namespace: ex-5-3
spec:
  clusterIP: None
  ports:
    - port: 80
      name: http
  selector:
    app: api
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: api
  namespace: ex-5-3
spec:
  serviceName: api-hdr
  replicas: 5
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
              name: http
EOF

kubectl -n ex-5-3 rollout status statefulset/api --timeout=180s
```

**Task:**

Execute the following sequence end to end:

1. **Canary**: Set `updateStrategy.rollingUpdate.partition` to 4 so only `api-4` is eligible for update. Update the image to `nginx:1.27.99-does-not-exist`. Observe `api-4` fail with `ImagePullBackOff`. Do not advance the partition.

2. **Rollback**: Use `kubectl rollout undo statefulset/api -n ex-5-3` to revert the template to the original `nginx:1.27`. Because the rolling update is stuck on `api-4`, the rollout undo alone may not be enough; you will likely also need to manually delete `api-4` to force the controller to recreate it with the reverted template. Verify that `api-4` is back on `nginx:1.27` and Ready.

3. **Recover**: Check ControllerRevisions with `kubectl rollout history statefulset/api -n ex-5-3`; multiple revisions should now exist.

4. **Retry with a valid image**: Keep the partition at 4 and update the image again to `nginx:1.27.3`. Verify that only `api-4` changes to the new image.

5. **Complete**: Lower the partition to 0 and wait for the rollout to finish. Verify that all five pods run `nginx:1.27.3`.

**Verification:**

```bash
# After step 1 (canary fails on api-4):
kubectl -n ex-5-3 get pod api-4 \
  -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}{"\n"}'
# Expected: ImagePullBackOff or ErrImagePull

# After step 2 (rollback + delete api-4):
kubectl -n ex-5-3 wait --for=condition=Ready pod/api-4 --timeout=120s
kubectl -n ex-5-3 get pod api-4 \
  -o jsonpath='{.metadata.name}:{.spec.containers[0].image}{"\n"}'
# Expected: api-4:nginx:1.27

# After step 3 (history exists):
kubectl -n ex-5-3 rollout history statefulset/api
# Expected: at least two revisions listed in the REVISION column.

# After step 4 (canary retry with valid image, partition=4):
for i in 0 1 2 3 4; do
  kubectl -n ex-5-3 get pod api-$i \
    -o jsonpath="{.metadata.name}:{.spec.containers[0].image}{\"\n\"}"
done
# Expected:
# api-0:nginx:1.27
# api-1:nginx:1.27
# api-2:nginx:1.27
# api-3:nginx:1.27
# api-4:nginx:1.27.3

# After step 5 (full rollout, partition=0):
kubectl -n ex-5-3 rollout status statefulset/api --timeout=180s
for i in 0 1 2 3 4; do
  kubectl -n ex-5-3 get pod api-$i \
    -o jsonpath="{.metadata.name}:{.spec.containers[0].image}{\"\n\"}"
done
# Expected: all five on nginx:1.27.3.
```

---

## Cleanup

When you finish the homework, tear everything down. StatefulSet deletion leaves PVCs behind; the namespace delete below cascades through PVCs along with everything else inside each namespace.

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 \
          ex-2-1 ex-2-2 ex-2-3 \
          ex-3-1 ex-3-2 ex-3-3 \
          ex-4-1 ex-4-2 ex-4-3 \
          ex-5-1 ex-5-2 ex-5-3; do
  kubectl delete namespace $ns --ignore-not-found
done
```

Confirm there are no leftover PersistentVolumes in `Released` status with a reclaim policy of `Retain`:

```bash
kubectl get pv | grep -E 'Released|Retain' || echo "No leftover PVs"
```

The local-path provisioner's default StorageClass uses `Delete` reclaim policy, so PVs generated during the exercises are deleted automatically when their PVCs go away with the namespace.

---

## Key Takeaways

StatefulSets exist to give workloads three specific guarantees that Deployments cannot provide: stable per-pod network identity (backed by a headless Service and predictable DNS names), ordered pod lifecycle under `OrderedReady` (or explicit parallel launch under `Parallel`), and per-pod persistent storage through `volumeClaimTemplates`. Every real-world use case for StatefulSets in the CKA exam leans on at least one of those three, and most of them lean on all three.

The headless Service pairing is the most common source of silent failures. A StatefulSet needs a Service with `spec.clusterIP: None` whose name matches `spec.serviceName`, whose selector matches the StatefulSet's pod labels, and which exists in the same namespace. Any one of those four conditions being wrong produces pods that run, rollouts that complete, and DNS names that do not resolve, with no error visible anywhere except in `nslookup` output from inside the cluster.

Per-pod storage through `volumeClaimTemplates` is the second source of failures. PVCs are named `<claim-name>-<statefulset-name>-<ordinal>` deterministically; they are not deleted on scale-down; they are not deleted on StatefulSet delete (unless `persistentVolumeClaimRetentionPolicy` opts in). The most common pitfall is specifying a `storageClassName` that does not exist in the cluster, which leaves PVCs stuck `Pending` and (under `OrderedReady`) blocks every pod from starting.

Rolling updates through `updateStrategy.rollingUpdate.partition` are the canonical mechanism for staged rollouts on stateful workloads. Only pods with ordinal greater than or equal to the partition update; lowering the partition one step at a time walks the rollout through the set. Combined with the v1.35 Beta `maxUnavailable` field, partitioned updates can be both staged and faster than the default single-pod-at-a-time pace when the application tolerates it.

`OnDelete` is the right update strategy when the application requires specific sequencing that does not fit the reverse-ordinal model. Under `OnDelete`, template changes are staged silently until the operator deletes the pods that should update; this is common for systems that need manual coordination of master-to-replica failover before an update.

Diagnostic workflow for a StatefulSet in trouble follows the shape you practiced in the pod series: `kubectl describe statefulset` for conditions and events, `kubectl get pods -l <selector> -o wide` for ordinal-by-ordinal status, `kubectl describe pod <name>` for the per-pod Events that explain why a pod is stuck, `kubectl rollout history statefulset/<name>` for revision history, and `kubectl rollout undo` for recovery from a bad template. Under `OrderedReady`, an ImagePullBackOff or CrashLoopBackOff on any pod blocks every higher-ordinal pod from starting; the fix is to unblock the lowest-ordinal broken pod first, then let the controller roll the rest forward.
