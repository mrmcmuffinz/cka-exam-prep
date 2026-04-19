# StatefulSets Homework Answers

Complete solutions for all 15 exercises. Every Level 3 and Level 5 debugging answer follows the three-stage structure: Diagnosis (the exact commands a learner should run and what output to read), What the bug is and why (the underlying cause), and Fix (the corrected configuration). Solutions show a single canonical form per exercise; imperative vs declarative is called out where both are reasonable.

---

## Exercise 1.1 Solution

```yaml
apiVersion: v1
kind: Service
metadata:
  name: app-hdr
  namespace: ex-1-1
  labels:
    app: app
spec:
  clusterIP: None
  ports:
    - port: 80
      name: http
  selector:
    app: app
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: app
  namespace: ex-1-1
  labels:
    app: app
spec:
  serviceName: app-hdr
  replicas: 3
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
              name: http
```

Apply this manifest with `kubectl apply -f` (or via a heredoc). The headless Service must be applied first (or in the same manifest) so that DNS records are ready when the StatefulSet pods come up. The StatefulSet's `spec.selector.matchLabels` must match `spec.template.metadata.labels`; both use `app: app` here, which means the Service's selector matches the same pods.

The `apps.kubernetes.io/pod-index` label is attached by the StatefulSet controller automatically; the verification reads it back from `app-0` to confirm the controller is processing the pods as a StatefulSet and not as some arbitrary set of pods that happen to have the same labels.

---

## Exercise 1.2 Solution

```yaml
apiVersion: v1
kind: Service
metadata:
  name: store-hdr
  namespace: ex-1-2
spec:
  clusterIP: None
  ports:
    - port: 80
      name: http
  selector:
    app: store
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: store
  namespace: ex-1-2
spec:
  serviceName: store-hdr
  replicas: 3
  selector:
    matchLabels:
      app: store
  template:
    metadata:
      labels:
        app: store
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
```

The `volumeClaimTemplates` entry's `metadata.name` becomes the prefix of each PVC name: with `name: data` and StatefulSet name `store`, the controller creates PVCs `data-store-0`, `data-store-1`, `data-store-2`. Omitting `storageClassName` causes the default StorageClass (`standard` in kind, backed by the `rancher.io/local-path` provisioner) to be used. Per-pod storage is realized by the pod spec's `volumeMounts` referencing the volume by the same name (`data`), which the StatefulSet controller wires to the pod's specific PVC automatically.

---

## Exercise 1.3 Solution

```yaml
apiVersion: v1
kind: Service
metadata:
  name: fleet-hdr
  namespace: ex-1-3
spec:
  clusterIP: None
  ports:
    - port: 80
      name: http
  selector:
    app: fleet
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: fleet
  namespace: ex-1-3
spec:
  serviceName: fleet-hdr
  replicas: 4
  podManagementPolicy: Parallel
  selector:
    matchLabels:
      app: fleet
  template:
    metadata:
      labels:
        app: fleet
    spec:
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
              name: http
```

`podManagementPolicy: Parallel` changes the controller's launch and terminate behavior. All four pods are created simultaneously and become Ready independently of each other. The start-time comparison in the verification is the practical way to confirm this: under `OrderedReady`, consecutive pods have start-time gaps of tens of seconds because each waits for its predecessor to become Ready; under `Parallel`, the start times cluster within a few seconds. Pods still have their ordinal identity (`fleet-0` through `fleet-3`) and their stable DNS names; parallel management only affects ordering, not identity or storage.

---

## Exercise 2.1 Solution

```bash
# Write a marker file to each pod's volume:
for i in 0 1 2; do
  kubectl -n ex-2-1 exec files-$i -- \
    sh -c "echo files-$i > /usr/share/nginx/html/marker.txt"
done
```

Delete `files-1` and `files-2` in turn; the StatefulSet controller recreates each one with the same name and the same PVC (`data-files-1`, `data-files-2`). Because the PVC survives the pod deletion and is re-attached to the replacement pod at the same mount path, the marker file is still present. This is the practical demonstration of "stable storage": the pod's identity is stable, its PVC is stable, and the data on the PVC is stable across pod churn.

The key mechanism is in the StatefulSet controller's reconcile loop: when a pod disappears, the controller creates a new pod with the same name and writes the original PVC name into the new pod's `spec.volumes`, pointing the `volumeMount` at the existing PVC. No data is copied; no PV is reprovisioned. Contrast this with a Deployment, which would create a replacement pod with a generated name and no preferred PVC, leaving the storage association to whatever scheduling produced.

---

## Exercise 2.2 Solution

```bash
# Set the partition and update the image in one patch, or as two separate steps:
kubectl -n ex-2-2 patch statefulset service --type='merge' \
  -p='{"spec":{"updateStrategy":{"type":"RollingUpdate","rollingUpdate":{"partition":3}}}}'

kubectl -n ex-2-2 set image statefulset/service web=nginx:1.27.3

# Wait for the controller to reconcile (rollout will report progress):
kubectl -n ex-2-2 rollout status statefulset/service --timeout=180s
```

Only pods with ordinal greater than or equal to the partition (3, 4) update. After the first phase, verify the mixed state with the per-pod image query in the verification block.

Then lower the partition to 0 to complete the rollout:

```bash
kubectl -n ex-2-2 patch statefulset service --type='merge' \
  -p='{"spec":{"updateStrategy":{"rollingUpdate":{"partition":0}}}}'
kubectl -n ex-2-2 rollout status statefulset/service --timeout=180s
```

The controller updates the remaining pods (`service-2`, `service-1`, `service-0`) in reverse-ordinal order. This staged-rollout pattern is the core CKA-relevant use of `partition`: push the new image to the highest-ordinal pod first (the "canary"), confirm it is healthy, then lower the partition step by step until every pod has been updated.

---

## Exercise 2.3 Solution

```bash
kubectl -n ex-2-3 set image statefulset/workers web=nginx:1.27.3

# Under OnDelete, no pod is automatically replaced. Delete workers-1 explicitly:
kubectl -n ex-2-3 delete pod workers-1
kubectl -n ex-2-3 wait --for=condition=Ready pod/workers-1 --timeout=120s
```

Under `updateStrategy.type: OnDelete`, changing the pod template stages a new ControllerRevision but does not drive a rollout. The controller's reconcile loop only recreates a pod when one disappears, and a recreated pod picks up the current template (the new one). Deleting `workers-1` is the trigger for the update to apply to that one pod.

This is the pattern used when a stateful application needs explicit control over which pod updates first, or when the sequence has to follow a business process like "failover master to replica before updating the master." `OnDelete` makes the operator the orchestration engine; the StatefulSet controller is reduced to "keep the current set alive, update each pod to the current template when I delete it."

---

## Exercise 3.1 Solution

### Diagnosis

Confirm the pods are stuck:

```bash
kubectl -n ex-3-1 get pods -l app=vault
```

Expected: zero or one pod listed, all in `Pending` phase. Under `OrderedReady`, only `vault-0` has started (or not started); no higher-ordinal pod appears.

Look at the pod events:

```bash
kubectl -n ex-3-1 describe pod vault-0 | tail -20
```

The Events section shows `FailedScheduling` messages citing "persistentvolumeclaim ... is being processed" or similar. The pod is waiting for its PVC to bind.

Check PVC status:

```bash
kubectl -n ex-3-1 get pvc
```

Expected: at least `data-vault-0` in `Pending` phase. Describe it:

```bash
kubectl -n ex-3-1 describe pvc data-vault-0 | tail -20
```

Events show something like `ProvisioningFailed: storageclass.storage.k8s.io "fast-ssd" not found`. The StorageClass the PVC is asking for does not exist in this cluster.

Confirm what StorageClasses are actually available:

```bash
kubectl get storageclass
```

Expected: one StorageClass named `standard` (the kind default), provisioner `rancher.io/local-path`. There is no `fast-ssd`.

### What the bug is and why it happens

The StatefulSet's `volumeClaimTemplates[0].spec.storageClassName` is set to `fast-ssd`, which does not exist in the cluster. When the StatefulSet controller creates PVCs from the template, those PVCs request a class that no provisioner can satisfy, so they stay `Pending` forever. Under `OrderedReady`, the first pod `vault-0` cannot start without its PVC, which means every subsequent pod is also blocked.

`storageClassName` does not validate against existing StorageClasses at apply time; Kubernetes accepts any string. The class only needs to exist at the moment the PVC is being provisioned. This is a common mistake when pasting a manifest from one cluster into another without checking the target cluster's StorageClass inventory first.

### Fix

The simplest correction is to remove the `storageClassName` field entirely so the default StorageClass is used. However, `volumeClaimTemplates` is immutable on an existing StatefulSet, so editing the field in place does not work. The correct procedure is to delete the StatefulSet and the failed PVCs, then reapply the corrected manifest.

```bash
# Delete the StatefulSet and its existing PVCs.
kubectl -n ex-3-1 delete statefulset vault
kubectl -n ex-3-1 delete pvc -l app=vault --ignore-not-found
kubectl -n ex-3-1 delete pvc data-vault-0 data-vault-1 data-vault-2 --ignore-not-found

# Reapply with storageClassName either set to "standard" or omitted.
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: vault
  namespace: ex-3-1
  labels:
    app: vault
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
        resources:
          requests:
            storage: 256Mi
EOF
```

Three new PVCs bind immediately through the local-path provisioner, and the three StatefulSet pods come up in order.

---

## Exercise 3.2 Solution

### Diagnosis

Confirm the pods are running (they should be, since the bug is only about DNS):

```bash
kubectl -n ex-3-2 get pods -l app=discovery
```

Expected: three pods all `Running` and `Ready`.

Attempt the DNS lookup:

```bash
kubectl -n ex-3-2 run nsprobe --rm -it --restart=Never --image=busybox:1.36 \
  -- nslookup discovery-0.discovery-svc
```

Expected: the lookup fails with NXDOMAIN or similar. The pods exist but their stable DNS names do not resolve.

Inspect the Service:

```bash
kubectl -n ex-3-2 get svc discovery-svc -o jsonpath='{.spec.clusterIP}'
echo
```

Expected: an IP address (for example, `10.96.42.1`), not `None`. The Service is not headless.

Confirm by looking at the whole spec:

```bash
kubectl -n ex-3-2 get svc discovery-svc -o yaml | grep -E 'clusterIP|type'
```

The `clusterIP` field is an auto-assigned IP; the Service was created without `spec.clusterIP: None`.

### What the bug is and why it happens

The Service has no `clusterIP: None` in its spec. Kubernetes auto-allocated a ClusterIP, which makes the Service a normal load-balancing ClusterIP Service. StatefulSets require a headless Service to provide per-pod DNS; a normal ClusterIP Service has a single A record that resolves to the virtual IP, not per-pod records for `discovery-0`, `discovery-1`, `discovery-2`.

This is an easy mistake because every other type of Service leaves `clusterIP` unset and Kubernetes handles it. Headless is the unusual case where the field must be explicitly set to `None` (a literal string, quoted or unquoted).

### Fix

The `clusterIP` field is immutable on an existing Service (you cannot convert a ClusterIP Service into a headless one after creation). Delete the Service and recreate it with `clusterIP: None`.

```bash
kubectl -n ex-3-2 delete svc discovery-svc

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: discovery-svc
  namespace: ex-3-2
  labels:
    app: discovery
spec:
  clusterIP: None
  ports:
    - port: 80
      name: http
  selector:
    app: discovery
EOF
```

Within a few seconds, the CoreDNS configuration picks up the headless Service's endpoints and per-pod DNS begins to resolve. Rerun `nslookup discovery-0.discovery-svc` from the debug pod; it now returns an Address line for the pod.

---

## Exercise 3.3 Solution

### Diagnosis

Confirm the pods are running:

```bash
kubectl -n ex-3-3 get pods -l app=members
```

Expected: three pods `Running`.

Attempt DNS lookup against the Service name the StatefulSet declares:

```bash
kubectl -n ex-3-3 get statefulset members -o jsonpath='{.spec.serviceName}{"\n"}'
```

Expected: `members-headless`.

```bash
kubectl -n ex-3-3 get svc members-headless 2>&1 | head -5
```

Expected: `Error from server (NotFound)`. The Service the StatefulSet names does not exist.

Check what Services actually exist in the namespace:

```bash
kubectl -n ex-3-3 get svc
```

Expected: one Service named `members-gov`, headless (`CLUSTER-IP: None`), selector `app=members`. It is the right kind of Service but has the wrong name.

### What the bug is and why it happens

The StatefulSet's `spec.serviceName` is `members-headless`, but the actual Service is named `members-gov`. The StatefulSet controller does not validate that `serviceName` refers to an existing Service (the Service could be created after the StatefulSet), and CoreDNS only registers per-pod DNS records for Services that do exist. The result is that pods run, but their per-pod DNS records are never generated because the governing Service the StatefulSet believes in does not exist.

This is a more insidious version of the same failure class as 3.2: the Service that exists is correct, but the StatefulSet is not pointing at it by name. In real clusters this mismatch often arises from copy-paste errors between team members or during renames that do not get propagated to every referring object.

### Fix

`spec.serviceName` is immutable on an existing StatefulSet. The cleanest path is to delete the StatefulSet with `--cascade=orphan` to preserve the running pods, recreate the StatefulSet with the correct `serviceName`, and let the controller re-adopt the pods. Alternatively, create a second Service named `members-headless` that matches the StatefulSet's `serviceName`, which avoids touching the StatefulSet at all.

The simpler fix is to create the missing Service:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: members-headless
  namespace: ex-3-3
  labels:
    app: members
spec:
  clusterIP: None
  ports:
    - port: 80
      name: http
  selector:
    app: members
EOF
```

Per-pod DNS now works through the new Service (`members-0.members-headless.ex-3-3.svc.cluster.local` resolves). The `members-gov` Service continues to exist but the StatefulSet does not use it.

The alternative "rename via delete-and-recreate" path is:

```bash
kubectl -n ex-3-3 delete statefulset members --cascade=orphan
kubectl -n ex-3-3 apply -f - <<'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: members
  namespace: ex-3-3
  labels:
    app: members
spec:
  serviceName: members-gov
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
```

The `--cascade=orphan` flag leaves the pods running during the delete; the new StatefulSet adopts them because the pod labels match the new selector. This is the path when you want the StatefulSet to truly use `members-gov` as its governing Service.

Either fix satisfies the verification block. The `members-gov` check in the verification targets the Service name the StatefulSet resolves to after the fix, which the script reads dynamically from `spec.serviceName`; it expects that DNS resolution works against whichever Service that field names.

---

## Exercise 4.1 Solution

First apply the headless Service and StatefulSet:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: db-hdr
  namespace: ex-4-1
  labels:
    app: db
spec:
  clusterIP: None
  ports:
    - port: 80
      name: http
  selector:
    app: db
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
  namespace: ex-4-1
  labels:
    app: db
spec:
  serviceName: db-hdr
  replicas: 3
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
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
```

Wait for the StatefulSet to be Ready, then seed the per-pod content:

```bash
kubectl -n ex-4-1 exec db-0 -- sh -c 'echo primary > /usr/share/nginx/html/index.html'
kubectl -n ex-4-1 exec db-1 -- sh -c 'echo replica-a > /usr/share/nginx/html/index.html'
kubectl -n ex-4-1 exec db-2 -- sh -c 'echo replica-b > /usr/share/nginx/html/index.html'
```

Create the primary-targeting ClusterIP Service (note the `statefulset.kubernetes.io/pod-name: db-0` selector):

```yaml
apiVersion: v1
kind: Service
metadata:
  name: db-primary
  namespace: ex-4-1
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: http
  selector:
    statefulset.kubernetes.io/pod-name: db-0
```

Finally, the Deployment that polls the primary by DNS name:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: ex-4-1
  labels:
    app: app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
        - name: curl
          image: curlimages/curl:8.5.0
          command:
            - sh
            - -c
            - 'while true; do curl -sf http://db-0.db-hdr/ || echo error; sleep 1; done'
```

The `db-primary` Service selects exactly one pod (`db-0`) by the StatefulSet-controller-managed label `statefulset.kubernetes.io/pod-name`. The Deployment's curl loop uses the headless-Service per-pod DNS name `db-0.db-hdr`, which resolves to the current IP of `db-0` even if the pod is rescheduled or replaced. The Deployment's logs show the body of `db-0`'s `index.html` (the string `primary`) on every successful request.

This is the production pattern for "talk to the database primary": expose the primary through a name that is stable under pod churn, either the per-pod DNS name directly or a ClusterIP Service with a pod-name selector. The headless-Service-plus-per-pod-DNS approach is preferred because it does not require a separate Service resource per pod.

---

## Exercise 4.2 Solution

Start with partition at 5 (only `web-5` can update):

```bash
kubectl -n ex-4-2 patch statefulset web --type='merge' \
  -p='{"spec":{"updateStrategy":{"type":"RollingUpdate","rollingUpdate":{"partition":5}}}}'

kubectl -n ex-4-2 set image statefulset/web web=nginx:1.27.3

kubectl -n ex-4-2 rollout status statefulset/web --timeout=180s
```

Only `web-5` updates. Confirm before proceeding.

Lower to partition 3 (now `web-3`, `web-4` also update; `web-5` was already updated):

```bash
kubectl -n ex-4-2 patch statefulset web --type='merge' \
  -p='{"spec":{"updateStrategy":{"rollingUpdate":{"partition":3}}}}'
kubectl -n ex-4-2 rollout status statefulset/web --timeout=180s
```

Confirm that `web-0`, `web-1`, `web-2` still run `nginx:1.27` and `web-3`, `web-4`, `web-5` run `nginx:1.27.3`.

Finally, complete the rollout:

```bash
kubectl -n ex-4-2 patch statefulset web --type='merge' \
  -p='{"spec":{"updateStrategy":{"rollingUpdate":{"partition":0}}}}'
kubectl -n ex-4-2 rollout status statefulset/web --timeout=180s
```

All six pods now run `nginx:1.27.3`. The per-phase verification in the homework exercises the mixed-state visible at each partition boundary, which is useful to see in practice because production canary rollouts depend on this exact behavior.

---

## Exercise 4.3 Solution

Write markers:

```bash
for i in 0 1 2 3; do
  kubectl -n ex-4-3 exec shard-$i -- \
    sh -c "echo 'data for shard-$i' > /usr/share/nginx/html/marker.txt"
done
```

Scale down to 1 and verify PVCs persist:

```bash
kubectl -n ex-4-3 scale statefulset shard --replicas=1
sleep 10
kubectl -n ex-4-3 get pvc
```

Four PVCs remain (`data-shard-0` through `data-shard-3`), all `Bound`. This is the intentional StatefulSet behavior: scale-down terminates pods in reverse order (`shard-3`, `shard-2`, `shard-1` all go; `shard-0` stays) but leaves every PVC in place. Only the `persistentVolumeClaimRetentionPolicy.whenScaled: Delete` option (behind a feature gate) would cause PVCs to go with the pods.

Scale back up and verify the same data reattaches:

```bash
kubectl -n ex-4-3 scale statefulset shard --replicas=4
kubectl -n ex-4-3 rollout status statefulset/shard --timeout=180s

for i in 0 1 2 3; do
  kubectl -n ex-4-3 exec shard-$i -- cat /usr/share/nginx/html/marker.txt
done
```

Every marker file is present with its original content. The `volumeClaimTemplates` mechanism guarantees that pod `shard-N` always attaches to PVC `data-shard-N`; the PVC itself determines which PersistentVolume the pod mounts, and that mapping is stable across the scale-down and scale-up cycle.

---

## Exercise 5.1 Solution

```yaml
apiVersion: v1
kind: Service
metadata:
  name: cluster-hdr
  namespace: ex-5-1
  labels:
    app: cluster
spec:
  clusterIP: None
  ports:
    - port: 80
      name: http
  selector:
    app: cluster
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: cluster
  namespace: ex-5-1
  labels:
    app: cluster
spec:
  serviceName: cluster-hdr
  replicas: 3
  selector:
    matchLabels:
      app: cluster
  template:
    metadata:
      labels:
        app: cluster
    spec:
      initContainers:
        - name: assign-role
          image: busybox:1.36
          command:
            - sh
            - -c
            - 'if echo "$HOSTNAME" | grep -q -- "-0$"; then echo leader > /shared/role; else echo follower > /shared/role; fi'
          volumeMounts:
            - name: shared
              mountPath: /shared
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
              name: http
          volumeMounts:
            - name: shared
              mountPath: /usr/share/nginx/html
      volumes:
        - name: shared
          emptyDir: {}
```

The pattern has three moving parts.

First, the init container reads the pod's hostname (set automatically by the StatefulSet controller to `<pod-name>`, so `cluster-0`, `cluster-1`, `cluster-2`) and writes either `leader` or `follower` to `/shared/role` based on the suffix. The `grep -q -- "-0$"` test isolates pod-0 deterministically because only that pod's hostname ends with `-0`.

Second, the `shared` volume is an `emptyDir`, which is pod-scoped and ephemeral. This is intentional: the role assignment is a per-pod decision that depends on pod identity, not on persisted state; the init container produces the role at pod creation, and the role file lives for the pod's lifetime. If you needed role persistence across pod restarts, you would use `volumeClaimTemplates` instead of `emptyDir` and let each pod keep its role on its own PVC.

Third, the main container serves `/shared/role` as its index page (by mounting `shared` at nginx's default document root). This makes each pod's role reachable by curl to the pod's stable DNS name.

The verification probes each of the three properties independently: the `cat` loop confirms the role file contents per pod, the curl loop confirms the content is served over HTTP and reachable by per-pod DNS name, and the `nslookup cluster-hdr` confirms the headless Service returns all three pod IPs (which is how a real clustered app would discover its peers at startup).

---

## Exercise 5.2 Solution

### Diagnosis

Check pod status:

```bash
kubectl -n ex-5-2 get pods -l app=broker
```

Expected: zero or one pod `Pending`, none `Ready`. Higher-ordinal pods are blocked by `OrderedReady`.

Check PVCs:

```bash
kubectl -n ex-5-2 get pvc
kubectl -n ex-5-2 describe pvc data-broker-0 | tail -10
```

The PVC is `Pending` with a `ProvisioningFailed` event citing `storageclass.storage.k8s.io "fast-tier" not found`. First bug identified: invalid `storageClassName`.

Now check the Service vs. the StatefulSet's `serviceName`:

```bash
kubectl -n ex-5-2 get statefulset broker -o jsonpath='{.spec.serviceName}{"\n"}'
kubectl -n ex-5-2 get svc
```

The StatefulSet names `broker-hdr`, but the only Service in the namespace is `broker-svc`. Second bug identified: `serviceName` mismatch.

Inspect `broker-svc`:

```bash
kubectl -n ex-5-2 get svc broker-svc -o jsonpath='{.spec.clusterIP}'
echo
```

An IP address, not `None`. Third bug identified: Service is not headless.

Three independent silent failures: PVC provisioning stuck, StatefulSet points at a non-existent Service, and the actual Service is not headless even if it had the right name.

### What the bug is and why it happens

Three problems co-exist in this manifest, each fitting a failure class covered earlier in the homework.

First, `storageClassName: fast-tier` does not match any StorageClass in the cluster, so the PVCs stay `Pending` forever. Under `OrderedReady`, `broker-0` cannot start without its PVC, and every higher-ordinal pod is blocked.

Second, the StatefulSet's `spec.serviceName` is `broker-hdr` but the actual Service is named `broker-svc`. Even if the pods came up, per-pod DNS would never resolve because the governing Service the StatefulSet references does not exist.

Third, the existing `broker-svc` Service has no `clusterIP: None`, so Kubernetes assigned it a ClusterIP, making it a normal load-balancing Service rather than a headless one. Per-pod DNS records are not produced for pods behind a non-headless Service.

All three bugs must be fixed for the StatefulSet to deliver its three guarantees (stable identity, per-pod storage, per-pod DNS). Fixing only the storage bug lets pods start but leaves DNS broken. Fixing only the Service bugs produces pods that would resolve by DNS if they were running, but they cannot run without storage.

### Fix

The cleanest path is to delete everything and reapply with all three bugs fixed. Both `volumeClaimTemplates` (on StatefulSet) and `clusterIP` (on Service) are immutable after creation, so neither can be patched in place.

```bash
# Tear down the broken resources and their PVCs.
kubectl -n ex-5-2 delete statefulset broker
kubectl -n ex-5-2 delete svc broker-svc
kubectl -n ex-5-2 delete pvc -l app=broker --ignore-not-found
kubectl -n ex-5-2 delete pvc data-broker-0 data-broker-1 data-broker-2 --ignore-not-found

# Reapply a corrected manifest with a headless Service named to match, and with
# volumeClaimTemplates using the default (or existing) StorageClass.
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: broker-hdr
  namespace: ex-5-2
  labels:
    app: broker
spec:
  clusterIP: None
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
  labels:
    app: broker
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
        resources:
          requests:
            storage: 256Mi
EOF
```

Three things change at once. The Service is now named `broker-hdr` (matching `serviceName`) and has `clusterIP: None`. The StatefulSet's `storageClassName` is omitted, so the default StorageClass `standard` is used. PVCs bind, pods come up in order, per-pod DNS resolves.

---

## Exercise 5.3 Solution

Step 1 (canary fails):

```bash
kubectl -n ex-5-3 patch statefulset api --type='merge' \
  -p='{"spec":{"updateStrategy":{"type":"RollingUpdate","rollingUpdate":{"partition":4}}}}'

kubectl -n ex-5-3 set image statefulset/api web=nginx:1.27.99-does-not-exist

# Wait a moment for the controller to attempt the update on api-4.
sleep 15
kubectl -n ex-5-3 get pod api-4
# Expected: status ImagePullBackOff or ErrImagePull.
```

Step 2 (rollback):

```bash
kubectl -n ex-5-3 rollout undo statefulset/api

# Under OrderedReady with a stuck pod, rollout undo alone usually will not replace
# the stuck pod. Force it by deleting api-4 manually:
kubectl -n ex-5-3 delete pod api-4 --force --grace-period=0
kubectl -n ex-5-3 wait --for=condition=Ready pod/api-4 --timeout=180s

kubectl -n ex-5-3 get pod api-4 \
  -o jsonpath='{.metadata.name}:{.spec.containers[0].image}{"\n"}'
# Expected: api-4:nginx:1.27
```

Step 3 (inspect history):

```bash
kubectl -n ex-5-3 rollout history statefulset/api
# Expected: at least three revisions in the REVISION column (initial create,
# the bad image, the rollback).
```

Step 4 (retry canary with a valid image):

```bash
kubectl -n ex-5-3 set image statefulset/api web=nginx:1.27.3
# Partition is still at 4, so only api-4 is eligible.
kubectl -n ex-5-3 rollout status statefulset/api --timeout=180s

for i in 0 1 2 3 4; do
  kubectl -n ex-5-3 get pod api-$i \
    -o jsonpath="{.metadata.name}:{.spec.containers[0].image}{\"\n\"}"
done
# Expected: api-0..api-3 on nginx:1.27; api-4 on nginx:1.27.3.
```

Step 5 (complete rollout):

```bash
kubectl -n ex-5-3 patch statefulset api --type='merge' \
  -p='{"spec":{"updateStrategy":{"rollingUpdate":{"partition":0}}}}'
kubectl -n ex-5-3 rollout status statefulset/api --timeout=180s

for i in 0 1 2 3 4; do
  kubectl -n ex-5-3 get pod api-$i \
    -o jsonpath="{.metadata.name}:{.spec.containers[0].image}{\"\n\"}"
done
# Expected: all five on nginx:1.27.3.
```

This is the real-world recovery pattern for a failed canary. Upstream Kubernetes documents this under "Forced rollback": a stuck `OrderedReady` rolling update requires both reverting the template (which `kubectl rollout undo` does) and manually deleting the broken pod (because the stuck pod never becomes Ready, so the controller's ordinary reconcile loop never tries to replace it). After the broken pod is gone, the controller recreates it from the reverted template and the StatefulSet recovers.

---

## Common Mistakes

Pairing a StatefulSet with a normal ClusterIP Service instead of a headless one. The StatefulSet applies, pods come up, rollouts complete, and nothing in `kubectl` output warns you that per-pod DNS is broken. The only way the mistake becomes visible is `nslookup pod-name.service-name` from inside a cluster-resident pod, which returns NXDOMAIN. The fix is to set `spec.clusterIP: None` on the Service, which is a field that cannot be changed after Service creation, so fixing this in place requires delete-and-recreate.

Setting `spec.serviceName` on the StatefulSet to a value that does not exactly match an existing headless Service's name. The StatefulSet controller does not validate that the Service exists, so the mismatch applies without error. Pods run; per-pod DNS never resolves. The fix is either to create a Service with the name the StatefulSet expects, or to delete the StatefulSet and recreate it with the correct `serviceName` (since `serviceName` is immutable after creation).

Specifying a `storageClassName` in `volumeClaimTemplates` that does not exist in the cluster. PVCs stay `Pending` forever, and under the default `OrderedReady` policy every pod is blocked by `pod-0` never starting. The apply path accepts any string; the mismatch only manifests at PVC provisioning time. Always check `kubectl get storageclass` against the cluster you are deploying into, and omit `storageClassName` entirely to use the default class when you do not have a specific performance requirement.

Expecting `kubectl rollout undo` to fully recover from a stuck `OrderedReady` rolling update. The `rollout undo` command reverts the template, but the controller's reconcile loop waits for the in-progress pod to become Ready before moving to the next step. If that pod is in `ImagePullBackOff`, it will never become Ready on its own, and the rolling update will stay stuck even after the undo. The fix is to manually delete the broken pod after `rollout undo` so the controller recreates it from the reverted template. Upstream calls this "Forced rollback."

Forgetting that scale-down does not delete PVCs. Scaling a StatefulSet from 5 to 1 terminates pods `-4` through `-1` but leaves their PVCs in place. If the cluster has no persistent-volume quota pressure this is the desirable behavior; if storage is expensive and you genuinely want scale-down to release it, opt into `persistentVolumeClaimRetentionPolicy.whenScaled: Delete` (behind the `StatefulSetAutoDeletePVC` feature gate; verify it is enabled in your cluster).

Treating `podManagementPolicy` as interchangeable with `updateStrategy`. `podManagementPolicy` governs how pods are created and terminated initially (ordered vs parallel); it does not affect how rolling updates proceed. `updateStrategy` governs how template changes propagate to existing pods (`RollingUpdate` vs `OnDelete`). A StatefulSet with `podManagementPolicy: Parallel` and `updateStrategy: RollingUpdate` still updates pods in reverse-ordinal order one at a time (or up to `maxUnavailable` at a time in v1.35+).

Editing `spec.volumeClaimTemplates` on an existing StatefulSet. The field is immutable. Attempting `kubectl edit` or `kubectl apply` with a changed `volumeClaimTemplates` returns a validation error. To change per-pod storage requirements you have to delete the StatefulSet (usually with `--cascade=orphan` if you want pods to survive during the recreate), delete or keep the existing PVCs depending on intent, and recreate with the new template. Plan this carefully in production because the existing PVCs do not resize or reformat on their own.

---

## Verification Commands Cheat Sheet

```bash
# StatefulSet status and progress
kubectl get statefulset NAME -n NS
kubectl rollout status statefulset/NAME -n NS
kubectl describe statefulset NAME -n NS

# Per-pod ordinal and node
kubectl get pods -n NS -l app=APPLABEL \
  -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase,IP:.status.podIP

# Per-pod image (the expression used throughout this assignment)
for i in 0 1 2; do
  kubectl get pod STS-$i -n NS \
    -o jsonpath="{.metadata.name}:{.spec.containers[0].image}{\"\n\"}"
done

# StatefulSet-controller labels on a pod
kubectl get pod STS-0 -n NS \
  -o jsonpath='{.metadata.labels.statefulset\.kubernetes\.io/pod-name}{"\n"}{.metadata.labels.apps\.kubernetes\.io/pod-index}{"\n"}'

# PVC status for the set (should be all Bound)
kubectl get pvc -n NS \
  -o jsonpath='{range .items[*]}{.metadata.name}:{.status.phase}{"\n"}{end}'

# Headless Service confirmation
kubectl get svc HEADLESS_SVC -n NS -o jsonpath='{.spec.clusterIP}'   # expect: None

# Per-pod DNS resolution (requires a debug pod)
kubectl run nsprobe --rm -it --restart=Never --image=busybox:1.36 -n NS \
  -- nslookup POD_NAME.HEADLESS_SVC

# Rollout history (revisions, for rollback)
kubectl rollout history statefulset/NAME -n NS
kubectl rollout undo statefulset/NAME -n NS --to-revision=R

# Partition manipulation (staged rollouts)
kubectl patch statefulset NAME -n NS --type='merge' \
  -p='{"spec":{"updateStrategy":{"type":"RollingUpdate","rollingUpdate":{"partition":P}}}}'

# Switch to OnDelete
kubectl patch statefulset NAME -n NS --type='merge' \
  -p='{"spec":{"updateStrategy":{"type":"OnDelete"}}}'

# Scale (scale-up from ordinal; scale-down in reverse ordinal; PVCs preserved by default)
kubectl scale statefulset NAME -n NS --replicas=N
```

When a StatefulSet does not behave the way you expect, the fastest diagnostic path is almost always the same: start with `kubectl get pods -l app=X -o wide` to see which ordinals are present and on which nodes, then `kubectl describe pod <lowest-pending-ordinal>` to get the events that explain why a specific pod is stuck. Under `OrderedReady`, a single stuck pod blocks every higher-ordinal pod, so focusing on the lowest-ordinal one that is not Ready is always the right starting point.
