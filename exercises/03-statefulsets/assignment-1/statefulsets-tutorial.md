# StatefulSets Tutorial

StatefulSets are the workload API object for applications that need one or more of stable network identity, ordered pod lifecycle, and per-pod persistent storage. If an application does not care about the name of its pods, their startup order, or whose PersistentVolume each pod gets, use a Deployment. If any of those three things matters, use a StatefulSet. This tutorial builds one complete StatefulSet end to end in a namespace called `tutorial-statefulsets`, starting from the headless Service that the StatefulSet depends on and ending with a partitioned rolling update that staged releases use in production.

The tutorial covers the full CKA-relevant surface: the StatefulSet spec (`serviceName`, `selector`, `template`, `replicas`, `volumeClaimTemplates`, `podManagementPolicy`, `updateStrategy`, `minReadySeconds`, `revisionHistoryLimit`), the headless Service contract (`clusterIP: None`), per-pod DNS resolution through `<pod>.<service>.<namespace>.svc.cluster.local`, ordered creation and reverse-ordered deletion under `OrderedReady`, the `Parallel` alternative, `RollingUpdate` with `partition` for staged rollouts and the v1.35 Beta `maxUnavailable` field, `OnDelete` for manual update control, scaling behavior and the PVC-retention contract, ControllerRevisions for rollback, and the diagnostic workflow for a stuck rollout. Every command is run against a live cluster so the behaviors are visible; a StatefulSet that reads correctly on paper can still misbehave if you do not pair it with a headless Service or if you leave `storageClassName` unset in a cluster without a default.

## Prerequisites

A multi-node kind cluster with the default `rancher.io/local-path` StorageClass is the right environment. The authoritative cluster creation command is in `docs/cluster-setup.md#multi-node-kind-cluster`. Verify your context:

```bash
kubectl config current-context
kubectl get nodes
kubectl get storageclass
```

You should see four nodes (1 control-plane, 3 workers) all `Ready`, and one StorageClass named `standard` with `rancher.io/local-path` as the provisioner.

Create the tutorial namespace:

```bash
kubectl create namespace tutorial-statefulsets
```

## Step 1: The Three Guarantees, and Why They Require a Headless Service

A Deployment gives you N interchangeable pods. Kubernetes is free to kill any of them, create a replacement with a new name, schedule it anywhere, and mount whatever PersistentVolume happens to be convenient. This works perfectly for stateless web front-ends, where pod identity does not matter.

A StatefulSet gives you N pods with identity. Each pod has a predictable name (`<statefulset-name>-<ordinal>`, for example `web-0`, `web-1`, `web-2`), a stable DNS hostname that resolves to its current IP, and its own PersistentVolumeClaim that follows the pod through restarts and reschedules. Those three properties are what let you run a Postgres primary, a sharded Redis cluster, or a ZooKeeper ensemble on Kubernetes: the software inside the pods expects its peers to have stable names, and expects its own storage to still be there after a restart.

The stable DNS property is provided by a paired headless Service. A normal Service has a `clusterIP` (a virtual IP that load-balances across the pods behind it), and its DNS A record resolves to that virtual IP. A headless Service has `clusterIP: None`. It has no virtual IP, no kube-proxy rules, and no load balancing. What it does have is a set of per-pod DNS A records, one per pod, named `<pod-name>.<service-name>.<namespace>.svc.cluster.local`. Those per-pod records are what give StatefulSet pods their stable network identity, and they only exist because the Service is headless. If you pair a StatefulSet with a regular Service, the StatefulSet controller does not fail and pods come up, but per-pod DNS simply does not exist; applications that need to reach `web-0` by name silently fail.

This pairing is the single most common source of silent StatefulSet failures and is why every StatefulSet exercise in this series includes a headless Service alongside the StatefulSet itself.

## Step 2: Create the Headless Service

Start with the Service; the StatefulSet will reference it by name. The headless Service selects the same pods the StatefulSet will create.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-hdr
  namespace: tutorial-statefulsets
  labels:
    app: web
spec:
  clusterIP: None
  ports:
    - port: 80
      name: http
  selector:
    app: web
```

Apply it:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-hdr
  namespace: tutorial-statefulsets
  labels:
    app: web
spec:
  clusterIP: None
  ports:
    - port: 80
      name: http
  selector:
    app: web
EOF
```

Verify that `clusterIP` is `None`:

```bash
kubectl get svc web-hdr -n tutorial-statefulsets
```

Expected output:

```
NAME      TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
web-hdr   ClusterIP   None         <none>        80/TCP    ...
```

The literal `None` in the `CLUSTER-IP` column is what makes this headless. `TYPE: ClusterIP` is still correct; headless is a property of the `clusterIP` field, not a separate type.

Headless Service spec fields relevant to this tutorial:

`spec.clusterIP: None`. This is the field that makes the Service headless. Default when omitted: Kubernetes allocates a virtual IP, which is not what a StatefulSet needs. Failure mode when misconfigured: pods come up, the StatefulSet applies, but per-pod DNS records never get created and `nslookup web-0.web-hdr.tutorial-statefulsets.svc.cluster.local` returns NXDOMAIN.

`spec.selector`. Must match the labels the StatefulSet puts on its pods (through its own `spec.template.metadata.labels`). Default: none; the Service matches nothing. Failure mode when the selector does not match: the Service has no endpoints and DNS resolves nothing, even if the pods are running.

`spec.ports`. Optional for the per-pod DNS contract (DNS works even without ports listed), but ports are necessary if anything actually talks to the Service. Default: empty list.

`metadata.labels`. The StatefulSet does not enforce any labeling, but labeling the Service with the same `app` label as the StatefulSet makes grouping resources easier and is a good habit.

## Step 3: Create the StatefulSet

Now write the StatefulSet itself. The `volumeClaimTemplates` field creates one PVC per pod; the `podManagementPolicy` (`OrderedReady` by default) causes pods to come up one at a time.

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
  namespace: tutorial-statefulsets
  labels:
    app: web
spec:
  serviceName: web-hdr
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      terminationGracePeriodSeconds: 10
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
              name: http
          volumeMounts:
            - name: www
              mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
    - metadata:
        name: www
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 256Mi
```

Apply it:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
  namespace: tutorial-statefulsets
  labels:
    app: web
spec:
  serviceName: web-hdr
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      terminationGracePeriodSeconds: 10
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
              name: http
          volumeMounts:
            - name: www
              mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
    - metadata:
        name: www
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 256Mi
EOF
```

Imperative form: there is no single-line `kubectl create statefulset` command that covers this surface. You can generate a scaffold with `kubectl create deployment web --image=nginx:1.27 --dry-run=client -o yaml` and then hand-convert `kind: Deployment` to `kind: StatefulSet`, add `serviceName` and `volumeClaimTemplates`, and so on. In practice the declarative form is always the right approach.

StatefulSet spec fields relevant to this tutorial:

`apiVersion: apps/v1`. Stable since Kubernetes 1.9; always use it.

`spec.serviceName`. Points at the governing headless Service. The StatefulSet controller uses this name to construct pod DNS names. Default when omitted: field is required; validation fails. Failure mode when the name does not match an existing Service: the StatefulSet applies and pods come up, but DNS records for those pods never exist because the target Service is missing. Failure mode when the target Service is not headless (`clusterIP` is not `None`): same silent DNS failure.

`spec.replicas`. Number of desired pods. Default when omitted: 1. If a HorizontalPodAutoscaler targets the StatefulSet, omit `replicas` so the HPA owns the field.

`spec.selector.matchLabels`. Must match `spec.template.metadata.labels`. Default when omitted: the field is required. Failure mode when the two do not match: the API server rejects the StatefulSet at apply time with a validation error, so this is one of the few StatefulSet mistakes that does not fail silently.

`spec.template`. A pod template. Every field on a pod spec is available here. The pod `restartPolicy` must be `Always` (the default for pod templates); StatefulSets do not accept `OnFailure` or `Never` on the pod template.

`spec.volumeClaimTemplates`. A list of PVC templates. Each element is an embedded PVC spec with its own `metadata.name`, `accessModes`, and `resources.requests.storage`. For each replica the StatefulSet controller creates one PVC per template, named `<volumeclaim-name>-<statefulset-name>-<ordinal>` (so with `volumeClaimTemplates[0].metadata.name: www` and StatefulSet name `web`, the PVCs are `www-web-0`, `www-web-1`, `www-web-2`). Failure mode when `storageClassName` is set to a StorageClass that does not exist in the cluster: PVCs stay in `Pending` indefinitely, and the StatefulSet pods also stay in `Pending`. Default when `storageClassName` is omitted: the cluster's default StorageClass is used (in kind, `rancher.io/local-path`).

`spec.podManagementPolicy`. Controls whether pods start and terminate in order (`OrderedReady`, the default) or in parallel (`Parallel`). With `OrderedReady`, `pod-N` is not created until every lower-ordinal pod is both Running and Ready, and during scale-down `pod-N-1` is not terminated until higher-ordinal pods are fully deleted. With `Parallel`, the controller launches or terminates all affected pods simultaneously. Default when omitted: `OrderedReady`. Failure mode when `OrderedReady` is combined with a broken `pod-0`: the rest of the StatefulSet never starts because the controller waits for `pod-0` to become Ready.

`spec.updateStrategy.type`. Either `RollingUpdate` (the default) or `OnDelete`. Under `RollingUpdate`, a change to the pod template causes the controller to delete and recreate each pod in reverse-ordinal order, waiting for each replacement to become Ready before moving to the next. Under `OnDelete`, template changes are staged but no pods are replaced until you delete them manually; this is useful when you need tight control over exactly when each pod updates, such as a stateful application that needs a specific sequence. Default when omitted: `RollingUpdate`.

`spec.updateStrategy.rollingUpdate.partition`. Only pods with ordinal greater than or equal to the partition are updated when the template changes. Default: 0 (every pod is eligible for update). When set to a value equal to or higher than `replicas`, no pod is updated; this is useful as a pause in the middle of a staged rollout.

`spec.updateStrategy.rollingUpdate.maxUnavailable`. Controls how many pods can be unavailable during a rolling update. Beta and enabled by default in Kubernetes v1.35. Default: 1. The StatefulSet controller terminates and creates up to `maxUnavailable` pods simultaneously when this is greater than 1.

`spec.minReadySeconds`. Minimum time a newly created pod must be Running and Ready before the controller counts it as available. Default: 0 (Ready is enough). Used to check rollout progression.

`spec.revisionHistoryLimit`. Number of ControllerRevision objects the controller retains for rollback. Default: 10. Setting it to 0 disables rollback entirely.

`spec.persistentVolumeClaimRetentionPolicy`. Advanced field (behind the `StatefulSetAutoDeletePVC` feature gate; check your cluster) that controls whether PVCs are deleted when the StatefulSet is deleted or when the StatefulSet is scaled down. Two subfields: `whenDeleted` and `whenScaled`, each accepting `Retain` (the default) or `Delete`. Failure mode when unset and the StatefulSet is deleted: PVCs remain, so storage survives (which is usually desirable for stateful data). This is the intentional default.

## Step 4: Watch Ordered Pod Creation

Watch pods come up one at a time:

```bash
kubectl get pods -n tutorial-statefulsets -l app=web -w
```

In another terminal, observe PVC creation:

```bash
kubectl get pvc -n tutorial-statefulsets -w
```

The expected progression: `web-0` appears as `Pending`, then `ContainerCreating`, then `Running` and `Ready`; only after that does `web-1` appear; and only after `web-1` is Ready does `web-2` appear. On the PVC side, `www-web-0`, `www-web-1`, and `www-web-2` appear in the same order, each transitioning from `Pending` to `Bound` as a PersistentVolume is provisioned by the local-path provisioner.

Confirm the end state:

```bash
kubectl get pods -n tutorial-statefulsets -l app=web -o wide
kubectl get pvc -n tutorial-statefulsets
```

Expected: three pods `web-0`, `web-1`, `web-2`, all `Running` and `1/1 Ready`, each on one of the worker nodes (kind schedules them onto available workers by default). Three PVCs `www-web-0`, `www-web-1`, `www-web-2`, each `Bound` to a dynamically-provisioned PersistentVolume.

## Step 5: Verify Pod Identity

Pods have stable hostnames and stable DNS names. Run a debug pod and use `nslookup` to prove it:

```bash
kubectl run -n tutorial-statefulsets dnsdebug --rm -it --restart=Never \
  --image=busybox:1.36 -- sh
```

Inside the debug pod, look up a specific StatefulSet pod by DNS:

```sh
nslookup web-0.web-hdr
nslookup web-2.web-hdr
nslookup web-hdr
exit
```

Expected: the first two commands return a single A record each, resolving to the specific pod's IP; the third returns three A records (one per replica), because the headless Service's DNS name resolves to the set of pod IPs (used for peer discovery).

The StatefulSet controller labels every pod with `statefulset.kubernetes.io/pod-name` and `apps.kubernetes.io/pod-index`. Inspect them:

```bash
kubectl get pod web-0 -n tutorial-statefulsets \
  -o jsonpath='{.metadata.labels.statefulset\.kubernetes\.io/pod-name}{"\n"}{.metadata.labels.apps\.kubernetes\.io/pod-index}{"\n"}'
```

Expected output:

```
web-0
0
```

The ordinal label is how you target a single pod with a Service or a NetworkPolicy; you cannot rely on pod name selectors in a Service spec, but you can select on the `statefulset.kubernetes.io/pod-name` label to reach exactly one pod.

## Step 6: Verify Per-Pod Storage

The point of `volumeClaimTemplates` is that each pod keeps its own storage across restarts. Prove it:

```bash
kubectl exec -n tutorial-statefulsets web-0 -- \
  sh -c 'echo "hello from web-0" > /usr/share/nginx/html/index.html'
kubectl exec -n tutorial-statefulsets web-1 -- \
  sh -c 'echo "hello from web-1" > /usr/share/nginx/html/index.html'
kubectl exec -n tutorial-statefulsets web-2 -- \
  sh -c 'echo "hello from web-2" > /usr/share/nginx/html/index.html'
```

Confirm each pod reads back its own data:

```bash
kubectl exec -n tutorial-statefulsets web-0 -- cat /usr/share/nginx/html/index.html
kubectl exec -n tutorial-statefulsets web-1 -- cat /usr/share/nginx/html/index.html
kubectl exec -n tutorial-statefulsets web-2 -- cat /usr/share/nginx/html/index.html
```

Expected outputs: `hello from web-0`, `hello from web-1`, `hello from web-2`.

Now delete `web-1` and confirm its data survives the restart:

```bash
kubectl delete pod web-1 -n tutorial-statefulsets
kubectl wait --for=condition=Ready pod/web-1 -n tutorial-statefulsets --timeout=90s
kubectl exec -n tutorial-statefulsets web-1 -- cat /usr/share/nginx/html/index.html
```

Expected: `hello from web-1`. The replacement pod reattached to the same PVC (`www-web-1`) and the file wrote there previously is still present.

This is the single most important StatefulSet guarantee for stateful applications. A database pod can be rescheduled, killed, upgraded, and still find its data exactly where it left it.

## Step 7: Rolling Update with Partition (Staged Rollout)

Scale up to five replicas first so the partition behavior is visible:

```bash
kubectl scale statefulset web -n tutorial-statefulsets --replicas=5
kubectl rollout status statefulset/web -n tutorial-statefulsets
```

Verify five pods and five PVCs now exist. Then set a partition at 3 and update the image:

```bash
kubectl patch statefulset web -n tutorial-statefulsets --type='merge' \
  -p='{"spec":{"updateStrategy":{"type":"RollingUpdate","rollingUpdate":{"partition":3}}}}'

kubectl set image statefulset/web -n tutorial-statefulsets web=nginx:1.27.3
```

Watch the rollout:

```bash
kubectl get pods -n tutorial-statefulsets -l app=web -w
```

The expected behavior is that only `web-3` and `web-4` are replaced with pods running `nginx:1.27.3`. Pods `web-0`, `web-1`, and `web-2` remain on the previous image (`nginx:1.27`). Verify:

```bash
for i in 0 1 2 3 4; do
  kubectl get pod web-$i -n tutorial-statefulsets \
    -o jsonpath="{.metadata.name}:{.spec.containers[0].image}{\"\n\"}"
done
```

Expected output:

```
web-0:nginx:1.27
web-1:nginx:1.27
web-2:nginx:1.27
web-3:nginx:1.27.3
web-4:nginx:1.27.3
```

The partition divides the StatefulSet into a stable lower half (ordinals 0 to partition-1) and an updateable upper half (ordinals partition and above). Dropping the partition to 2 would include `web-2` in the next update; dropping it to 0 updates the whole set. This is the mechanism behind canary rollouts on StatefulSets: set a high partition, push the new image, observe the highest-ordinal pod, then lower the partition one step at a time.

Advance the rollout by lowering the partition:

```bash
kubectl patch statefulset web -n tutorial-statefulsets --type='merge' \
  -p='{"spec":{"updateStrategy":{"rollingUpdate":{"partition":0}}}}'
kubectl rollout status statefulset/web -n tutorial-statefulsets
```

Now all five pods run `nginx:1.27.3`. Ordinal order for the update is reverse: `web-4` was already updated during the partition=3 phase, then the remaining eligible pods updated in order `web-2`, `web-1`, `web-0` as the partition dropped through them.

## Step 8: OnDelete Update Strategy

The `OnDelete` strategy stages template changes but does not update pods automatically; the operator deletes pods manually, which is useful when the application needs a specific update sequence outside of reverse-ordinal.

Switch the StatefulSet to `OnDelete` and change the image again:

```bash
kubectl patch statefulset web -n tutorial-statefulsets --type='merge' \
  -p='{"spec":{"updateStrategy":{"type":"OnDelete"}}}'

kubectl set image statefulset/web -n tutorial-statefulsets web=nginx:1.27.4
```

Confirm that no pod has been replaced yet:

```bash
for i in 0 1 2 3 4; do
  kubectl get pod web-$i -n tutorial-statefulsets \
    -o jsonpath="{.metadata.name}:{.spec.containers[0].image}{\"\n\"}"
done
```

Expected: all five still on `nginx:1.27.3`. The new template is staged but inert. Manually delete a specific pod to trigger its recreation with the new template:

```bash
kubectl delete pod web-2 -n tutorial-statefulsets
kubectl wait --for=condition=Ready pod/web-2 -n tutorial-statefulsets --timeout=90s
kubectl get pod web-2 -n tutorial-statefulsets \
  -o jsonpath='{.metadata.name}:{.spec.containers[0].image}{"\n"}'
```

Expected: `web-2:nginx:1.27.4`. Only the one pod you deleted updated. The others will update only when you delete them individually.

## Step 9: Scale Down and Confirm PVCs Persist

Scale back to 2 replicas and observe the pod deletion order:

```bash
kubectl scale statefulset web -n tutorial-statefulsets --replicas=2
kubectl get pods -n tutorial-statefulsets -l app=web -w
```

Expected: `web-4` terminates first, then `web-3`, then `web-2`, in that reverse-ordinal order. Two pods remain: `web-0` and `web-1`.

Now check the PVCs:

```bash
kubectl get pvc -n tutorial-statefulsets
```

All five PVCs are still present (`www-web-0` through `www-web-4`), even though only two pods remain. This is the intentional StatefulSet behavior: scaling down preserves storage so that scaling back up reattaches the original data. Prove this by scaling back up:

```bash
kubectl scale statefulset web -n tutorial-statefulsets --replicas=5
kubectl wait --for=condition=Ready pod/web-4 -n tutorial-statefulsets --timeout=90s
kubectl exec -n tutorial-statefulsets web-1 -- cat /usr/share/nginx/html/index.html
```

Expected: `hello from web-1`, the same content written in Step 6. The scale-down and scale-up cycle never touched the PVC, so the file is intact.

To opt into automatic PVC cleanup, use `persistentVolumeClaimRetentionPolicy`:

```yaml
spec:
  persistentVolumeClaimRetentionPolicy:
    whenDeleted: Retain
    whenScaled: Delete
```

With `whenScaled: Delete`, a scale-down would delete the PVCs of the scaled-away pods. With `whenDeleted: Delete`, deleting the StatefulSet would also delete all of its PVCs. The defaults (both `Retain`) are the conservative choice and the right default for stateful data. The feature requires the `StatefulSetAutoDeletePVC` feature gate; check your cluster before relying on it for production.

## Step 10: Rollback via ControllerRevision

Every template change produces a ControllerRevision:

```bash
kubectl get controllerrevisions -n tutorial-statefulsets -l app=web
kubectl rollout history statefulset/web -n tutorial-statefulsets
```

Roll back to the first revision (nginx:1.27):

```bash
kubectl rollout undo statefulset/web -n tutorial-statefulsets --to-revision=1
kubectl rollout status statefulset/web -n tutorial-statefulsets
```

Verify all pods are back on `nginx:1.27`:

```bash
for i in 0 1 2 3 4; do
  kubectl get pod web-$i -n tutorial-statefulsets \
    -o jsonpath="{.metadata.name}:{.spec.containers[0].image}{\"\n\"}"
done
```

Rollback is reverse-ordinal under `RollingUpdate`, which is the current `updateStrategy` since the `OnDelete` flip in Step 8 was followed by `rollout undo`. Note that `kubectl rollout undo` does not change the `updateStrategy` itself; if the rollout target was created under `OnDelete`, rolling back still creates a new ControllerRevision but the pods will not be updated until you delete them manually.

## Step 11: Clean Up

Delete the StatefulSet. Pods terminate in reverse-ordinal order; PVCs remain because the default retention policy is `Retain`:

```bash
kubectl delete statefulset web -n tutorial-statefulsets
kubectl get pvc -n tutorial-statefulsets
```

The PVCs are still listed. Delete them explicitly:

```bash
kubectl delete pvc -l app=web -n tutorial-statefulsets
```

Wait, that label selector does not work because the `volumeClaimTemplates`-generated PVCs do not inherit the template's `app: web` label. Use the StatefulSet-specific selector instead:

```bash
kubectl delete pvc -n tutorial-statefulsets www-web-0 www-web-1 www-web-2 www-web-3 www-web-4
```

Alternatively, bulk-delete by selecting all PVCs whose name matches the pattern:

```bash
kubectl delete pvc -n tutorial-statefulsets \
  $(kubectl get pvc -n tutorial-statefulsets -o name | grep '^persistentvolumeclaim/www-web-')
```

Delete the Service and the namespace:

```bash
kubectl delete svc web-hdr -n tutorial-statefulsets
kubectl delete namespace tutorial-statefulsets
```

The namespace delete cascades over any remaining namespaced objects. PVCs inside the namespace would be cleaned up by the namespace delete anyway; the explicit PVC delete before namespace delete is defense in depth and matches what you would do in a real cluster where the namespace is shared.

## Reference Commands

Keep this section open while working through the homework.

### Create and inspect

```bash
# Apply a StatefulSet + headless Service together
kubectl apply -f sts.yaml

# Check rollout status
kubectl rollout status statefulset/NAME -n NS

# Watch ordered creation
kubectl get pods -n NS -l app=NAME -w

# View revision history
kubectl rollout history statefulset/NAME -n NS

# Describe for conditions and events
kubectl describe statefulset NAME -n NS
```

### Scale

```bash
# Scale up or down (scale-up adds new-highest-ordinal pods; scale-down removes from the top)
kubectl scale statefulset NAME -n NS --replicas=N

# List the pods with ordinals visible
kubectl get pods -n NS -l app=NAME \
  -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase
```

### Rolling update

```bash
# Change the image (triggers a rolling update under RollingUpdate strategy)
kubectl set image statefulset/NAME -n NS CONTAINER=IMAGE:TAG

# Stage with partition (only ordinals >= partition update)
kubectl patch statefulset NAME -n NS --type='merge' \
  -p='{"spec":{"updateStrategy":{"type":"RollingUpdate","rollingUpdate":{"partition":P}}}}'

# Switch to OnDelete (template changes only apply to manually deleted pods)
kubectl patch statefulset NAME -n NS --type='merge' \
  -p='{"spec":{"updateStrategy":{"type":"OnDelete"}}}'
```

### Rollback

```bash
# Roll back to the immediately previous revision
kubectl rollout undo statefulset/NAME -n NS

# Roll back to a specific revision
kubectl rollout undo statefulset/NAME -n NS --to-revision=R
```

### Storage

```bash
# List PVCs created by volumeClaimTemplates (pattern: <claim-name>-<sts-name>-<ordinal>)
kubectl get pvc -n NS

# Describe one to see the bound PV
kubectl describe pvc CLAIM-STS-ORDINAL -n NS
```

### DNS

```bash
# From inside another pod, look up a specific StatefulSet pod
nslookup <pod-name>.<service-name>.<namespace>.svc.cluster.local

# Or the shorter form (same namespace):
nslookup <pod-name>.<service-name>
```

### Debugging

```bash
# Why is pod-0 stuck Pending? Check events:
kubectl describe pod NAME-0 -n NS | tail -30

# Why is the StatefulSet stuck? Conditions and events:
kubectl describe statefulset NAME -n NS | tail -30

# What's the pod's PVC status?
kubectl get pvc -n NS

# Is the headless Service actually headless?
kubectl get svc SERVICENAME -n NS   # CLUSTER-IP column must be "None"

# Is the Service serving per-pod DNS? (empty EndpointSlice means no)
kubectl get endpointslices -n NS
```

### StatefulSet spec cheat sheet

| Field | Required | Default | Notes |
|---|---|---|---|
| `spec.serviceName` | yes | n/a | Name of the headless Service; must exist and be headless (`clusterIP: None`). |
| `spec.replicas` | no | 1 | Omit when an HPA manages scaling. |
| `spec.selector.matchLabels` | yes | n/a | Must match `spec.template.metadata.labels` or apply fails. |
| `spec.template` | yes | n/a | Pod template; `restartPolicy` must remain `Always`. |
| `spec.volumeClaimTemplates` | no | empty | One PVC per pod per template; PVCs named `<claim>-<sts>-<ordinal>`. |
| `spec.podManagementPolicy` | no | `OrderedReady` | Alternative: `Parallel`. |
| `spec.updateStrategy.type` | no | `RollingUpdate` | Alternative: `OnDelete`. |
| `spec.updateStrategy.rollingUpdate.partition` | no | 0 | Only ordinals >= partition update. |
| `spec.updateStrategy.rollingUpdate.maxUnavailable` | no | 1 | Beta in v1.35, enabled by default. |
| `spec.minReadySeconds` | no | 0 | Delay before counting a pod ready during rollout. |
| `spec.revisionHistoryLimit` | no | 10 | Number of ControllerRevisions kept. |
| `spec.persistentVolumeClaimRetentionPolicy` | no | `{Retain, Retain}` | Feature gate `StatefulSetAutoDeletePVC` required. |
