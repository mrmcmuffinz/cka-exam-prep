# Workload Autoscaling Homework Answers

Complete solutions for all 15 exercises. Level 3 and the Level 5 debugging exercise (5.2) follow the three-stage structure (Diagnosis, What the bug is and why, Fix). The build and design exercises (Levels 1, 2, 4, 5.1, 5.3) show the canonical solution with notes on the spec choices.

---

## Exercise 1.1 Solution

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-hpa
  namespace: ex-1-1
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web
  minReplicas: 1
  maxReplicas: 4
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

Or imperatively:

```bash
kubectl -n ex-1-1 autoscale deployment web --min=1 --max=4 --cpu-percent=50
```

Note that `kubectl autoscale` may generate `apiVersion: autoscaling/v1`, which is functionally compatible but lacks the `metrics` array shape. For exam questions that specify behavior tuning or memory targets, use the declarative `autoscaling/v2` form.

---

## Exercise 1.2 Solution

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: cache-hpa
  namespace: ex-1-2
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: cache
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 70
```

Memory-based HPAs work the same way as CPU-based ones; the target percentage is computed against `resources.requests.memory`. Memory-triggered scale-up is typically secondary to CPU-triggered; a workload that is rising in memory but steady in CPU is a sign of a cache fill or a memory leak.

---

## Exercise 1.3 Solution

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
  namespace: ex-1-3
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  minReplicas: 1
  maxReplicas: 6
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 120
```

`scaleDown.stabilizationWindowSeconds: 120` means the HPA looks at the most recent 120 seconds of scale-down recommendations and picks the most cautious (highest replica count) within that window. A dip that lasts 60 seconds is smoothed out; a drop that persists for two minutes triggers an actual reduction.

Leaving `scaleUp` unset keeps its defaults (zero stabilization, 100% or 4 pods per 15 seconds), which is the "react quickly to bursts" behavior that production usually wants paired with slower scale-down.

---

## Exercise 2.1 Solution

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: worker-hpa
  namespace: ex-2-1
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: StatefulSet
    name: worker
  minReplicas: 1
  maxReplicas: 4
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

The only change from a Deployment-targeting HPA is `scaleTargetRef.kind: StatefulSet`. HPA targets anything that exposes a `scale` subresource: Deployments, StatefulSets, ReplicaSets, and ReplicationControllers. DaemonSets do not have a scale subresource (their replica count is determined by node selectors, not a user-set number), so DaemonSets cannot be HPA targets.

The StatefulSet in the setup pairs with a headless Service because StatefulSets require one; the HPA itself does not care about the Service.

---

## Exercise 2.2 Solution

```bash
kubectl patch pod sizer -n ex-2-2 --subresource=resize --patch '
spec:
  containers:
    - name: app
      resources:
        requests:
          cpu: 250m
        limits:
          cpu: 750m
'
```

The `--subresource=resize` flag is the path the API server uses for in-place resize in Kubernetes 1.33+. Without that flag, kubectl would patch the `pods` resource directly, which refuses updates to running pod resources unless the resize subresource is specifically addressed.

Because the pod's `resizePolicy` for CPU is `NotRequired`, kubelet applies the change by updating the container's cgroup limits in place. The container does not restart, and `restartCount` stays at zero. Only memory resizes on this pod would restart (per the setup's `resizePolicy[1].restartPolicy: NotRequired` for memory; in Exercise 2.3 the memory policy is `RestartContainer`).

---

## Exercise 2.3 Solution

```bash
kubectl patch pod memsizer -n ex-2-3 --subresource=resize --patch '
spec:
  containers:
    - name: app
      resources:
        requests:
          memory: 128Mi
        limits:
          memory: 256Mi
'
```

Because `memory` has `restartPolicy: RestartContainer`, kubelet stops and restarts the container to apply the new memory limits. The restart increments `restartCount` by one; the pod briefly goes to `NotReady`; after the nginx process starts again the pod is `Ready`.

This is the right choice when the process in the container must re-observe its resource limits at startup. Many memory-tuned runtimes (JVM with `-XX:MaxRAMPercentage`, for example) read environment variables or cgroup limits once at startup and cache them; an in-place memory change without a restart would not take effect in such a runtime. Setting `restartPolicy: RestartContainer` on memory is the explicit signal that the process needs to re-initialize.

---

## Exercise 3.1 Solution

### Diagnosis

Check the HPA's TARGETS column:

```bash
kubectl get hpa svc-hpa -n ex-3-1
```

Expected: `TARGETS` shows `<unknown>/50%` even after waiting 45 seconds.

Read the full HPA status:

```bash
kubectl describe hpa svc-hpa -n ex-3-1 | tail -20
```

Expected: `Conditions` show `AbleToScale: True` (the target Deployment exists) but `ScalingActive: False` with reason `FailedGetResourceMetric`. The message typically reads like `failed to get cpu utilization: missing request for cpu`.

Check the target Deployment's pod template:

```bash
kubectl get deployment svc -n ex-3-1 \
  -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
```

Expected: `{}` (empty). The pod template has no `resources` block, so no CPU request is set.

### What the bug is and why it happens

HPA computes CPU utilization as (observed CPU / requested CPU) × 100. With no `resources.requests.cpu` on the target pod, the denominator is zero and utilization is undefined; the HPA flags `ScalingActive: False` and never scales. The target pods run fine otherwise because Kubernetes does not require resource requests for a workload to execute; it only requires them for autoscaling on utilization.

This is the single most common "my HPA is not scaling" cause in production. Templates copied from a tutorial that targets a preset image often omit resource requests; the HPA is added later and appears broken.

### Fix

Patch the Deployment to add a CPU request:

```bash
kubectl -n ex-3-1 set resources deployment svc \
  --containers=nginx --requests=cpu=100m,memory=64Mi \
  --limits=cpu=500m,memory=128Mi
```

Or edit the Deployment and add a full `resources` block to the pod template. Wait 30 to 45 seconds for the new pods to roll out and for metrics-server to scrape them; the HPA's TARGETS column transitions from `<unknown>` to a numeric utilization, and `ScalingActive: True`.

---

## Exercise 3.2 Solution

### Diagnosis

Read the HPA conditions:

```bash
kubectl describe hpa api2-hpa -n ex-3-2 | grep -A1 'Conditions:'
```

Expected: `AbleToScale: False` with reason `FailedGetScale` and a message like `deployments.apps "api2-deployment" not found`.

Check what Deployments actually exist:

```bash
kubectl get deployments -n ex-3-2
```

Expected: one Deployment named `api2`. The HPA is pointing at `api2-deployment`, which does not exist.

Confirm by reading the HPA's scaleTargetRef:

```bash
kubectl get hpa api2-hpa -n ex-3-2 \
  -o jsonpath='{.spec.scaleTargetRef.name}{"\n"}'
```

Expected: `api2-deployment`.

### What the bug is and why it happens

The HPA's `spec.scaleTargetRef.name` is `api2-deployment`, but the actual Deployment in the namespace is named `api2`. The HPA controller attempts to look up the `api2-deployment` scale subresource at every reconciliation; the lookup returns `NotFound`; `AbleToScale` transitions to `False`; no scaling happens. Kubernetes does not validate referential integrity on HPA create (the target does not need to exist at apply time, which is why stale references survive), so the HPA applies cleanly and the mismatch is silent.

This is the second most common HPA failure after missing resource requests. It usually arises from a rename or a copy-paste between environments where the Deployment naming convention differs.

### Fix

`scaleTargetRef` is mutable on an HPA, so the fix is a single patch:

```bash
kubectl patch hpa api2-hpa -n ex-3-2 --type=merge --patch '
spec:
  scaleTargetRef:
    name: api2
'
```

Or delete and recreate the HPA with the corrected name (either works; the patch is faster). Wait a few seconds for the next reconcile and `AbleToScale` flips to `True`.

---

## Exercise 3.3 Solution

### Diagnosis

Check HPA status:

```bash
kubectl describe hpa load-hpa -n ex-3-3 | grep -E 'Conditions:|ScalingActive' -A1
```

Expected: `AbleToScale: True` (the target Deployment exists and is reachable) but `ScalingActive: False` with a reason and message that cite missing CPU metrics. The message often reads `failed to get cpu utilization: missing request for cpu`.

Read the target Deployment's container resources:

```bash
kubectl get deployment load -n ex-3-3 \
  -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'
```

Expected: the resources block has `requests.memory: 64Mi` and `limits.memory: 128Mi` but no `requests.cpu` or `limits.cpu`. Memory is fully specified; CPU is unspecified.

### What the bug is and why it happens

The HPA is CPU-based (`metrics[0].resource.name: cpu`), but the target pod template sets only memory requests and limits. No CPU request means the utilization calculation for CPU has no denominator, and the HPA flags `ScalingActive: False` for `FailedGetResourceMetric`. The pod runs fine because CPU without a request is simply best-effort for CPU; only the HPA notices the missing request.

This bug is subtly different from Exercise 3.1's "no resources at all." Here the Deployment was partially configured: the operator thought about memory but forgot CPU. The symptom is the same (`<unknown>/50%`) but the narrative diagnosis leads somewhere different: the fix is to add CPU alongside the existing memory spec, not to add a complete resources block from scratch.

### Fix

Add a CPU request and limit to the Deployment:

```bash
kubectl -n ex-3-3 set resources deployment load \
  --containers=nginx \
  --requests=cpu=100m,memory=64Mi \
  --limits=cpu=500m,memory=128Mi
```

Or patch more surgically to preserve the existing memory values:

```bash
kubectl -n ex-3-3 patch deployment load --type=strategic --patch '
spec:
  template:
    spec:
      containers:
        - name: nginx
          resources:
            requests:
              cpu: 100m
            limits:
              cpu: 500m
'
```

Wait for the rolling update and the next metrics-server scrape. The HPA's `ScalingActive` transitions to `True` and TARGETS reports a numeric utilization.

---

## Exercise 4.1 Solution

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: multi-hpa
  namespace: ex-4-1
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: multi
  minReplicas: 2
  maxReplicas: 8
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 75
```

Multi-metric HPAs evaluate each metric independently and take the maximum of the implied replica counts. If CPU utilization says "scale to 5" and memory utilization says "scale to 3," the HPA uses 5. The maximum-wins rule guarantees the workload will not be under-provisioned for whichever resource is most constrained.

The common mistake with multi-metric HPAs is assuming the metrics produce an average or a weighted combination; they do not. A memory metric with a tight target (low percentage) combined with a loose CPU metric means memory will dominate scaling decisions during normal operation, and CPU only kicks in during CPU-heavy bursts.

---

## Exercise 4.2 Solution

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: burst-hpa
  namespace: ex-4-2
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: burst
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
```

This configuration expresses "react fast to bursts, drain slowly afterwards." The scale-up path is the HPA default (zero stabilization, double-per-15-seconds). The scale-down path is much more conservative than the default (300-second window instead of 300, and only 10% per 60 seconds instead of 100% per 15 seconds). A workload that spikes for 60 seconds and then falls will add replicas within a few evaluation cycles and keep most of those replicas for at least five minutes before shedding them.

Note that the default scale-up behavior is already equivalent to what this HPA specifies for scale-up; writing the policy explicitly makes intent clearer on the YAML and is recommended when the policy matters.

---

## Exercise 4.3 Solution

Generate load first:

```bash
# In one terminal:
kubectl run loadgen -n ex-4-3 \
  --image=busybox:1.36 \
  --restart=Never \
  --rm -it \
  -- sh -c 'while true; do wget -q -O- http://combo/ > /dev/null; done'
```

In another terminal, watch the HPA and deployment:

```bash
kubectl get hpa combo-hpa -n ex-4-3 -w
```

Expected: within 30 to 60 seconds, the HPA's REPLICAS column climbs from 1 to 2 or more.

Identify the lowest-ordinal pod and resize its CPU:

```bash
TARGET=$(kubectl get pods -n ex-4-3 -l app=combo \
           -o jsonpath='{.items[0].metadata.name}')

kubectl patch pod $TARGET -n ex-4-3 --subresource=resize --patch '
spec:
  containers:
    - name: nginx
      resources:
        requests:
          cpu: 200m
        limits:
          cpu: 500m
'
```

The resize happens in place because `resizePolicy.cpu: NotRequired` (set in the setup manifest). The pod's `restartCount` stays at zero; the container keeps running. The HPA continues to evaluate its scale decisions based on utilization; a pod with `200m` requests at the same absolute CPU usage will report a lower utilization percentage than before, which may cause the HPA to scale back. The interplay is a real phenomenon in production and is one reason "HPA on CPU, in-place resize for memory" is a cleaner pairing than letting both touch the same resource.

Stop the loadgen pod (Ctrl+C in its terminal).

---

## Exercise 5.1 Solution

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: sla-hpa
  namespace: ex-5-1
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: sla
  minReplicas: 3
  maxReplicas: 30
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0
      selectPolicy: Max
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
        - type: Pods
          value: 4
          periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 20
          periodSeconds: 60
```

The scale-up design uses `selectPolicy: Max` across two policies: 100% per 15 seconds (doubling) and 4 pods per 15 seconds (absolute). For small replica counts (below 4), the Pods policy dominates; for larger replica counts, the Percent policy dominates. This ensures the HPA can respond meaningfully at any scale: starting from 3 pods, a burst allows jumping to 7 pods (3 + 4) in one evaluation; at 20 pods, a burst allows jumping to 40 pods (20 × 2) in one evaluation, though `maxReplicas: 30` caps the growth.

The scale-down design uses a single `Percent: 20` per 60 seconds policy with a 300-second stabilization window. This drains slowly and smoothly: the fastest the HPA can remove pods is 20% per minute, and no scale-down decisions are counted until the stabilization window has passed.

The design satisfies the SLA: scale-up latency is effectively one HPA sync interval (up to 15 seconds) once the metric crosses 70%, and scale-down is paced at one-fifth the current pod count per minute, which translates to roughly five minutes to drain the workload back to its minimum from a fully scaled-out state.

---

## Exercise 5.2 Solution

### Diagnosis

Watch the HPA's REPLICAS column over a few minutes:

```bash
kubectl get hpa flap-hpa -n ex-5-2 -w
```

Expected under oscillating load: REPLICAS climbs rapidly to `maxReplicas` (10), then within one or two evaluation cycles of a dip it drops to `minReplicas` (2), then climbs back to 10, and so on. This is the classic flapping signature.

Read the HPA's scale-down behavior:

```bash
kubectl get hpa flap-hpa -n ex-5-2 \
  -o jsonpath='{.spec.behavior.scaleDown.stabilizationWindowSeconds}:{.spec.behavior.scaleDown.policies[0].type}={.spec.behavior.scaleDown.policies[0].value}/{.spec.behavior.scaleDown.policies[0].periodSeconds}{"\n"}'
```

Expected: `0:Percent=100/15`. No stabilization window and a policy that permits removing every excess pod in a single 15-second evaluation.

Read the HPA's scale-up behavior:

```bash
kubectl get hpa flap-hpa -n ex-5-2 \
  -o jsonpath='{.spec.behavior.scaleUp.stabilizationWindowSeconds}{"\n"}'
```

Expected: `0`. Zero-stabilization scale-up combined with zero-stabilization scale-down means the HPA reacts to every metric sample in both directions, with no smoothing.

### What the bug is and why it happens

The HPA's scale-down is configured to react instantly and aggressively to any CPU dip, while the scale-up is also zero-stabilization. Under oscillating load (where CPU swings above and below 50% on a 30-to-60-second period), the HPA adds pods during each up-crossing and removes them during each down-crossing. The removal is large (up to 100% of the excess per 15 seconds), so the pod count swings between `minReplicas` and whatever scale-up has reached in the previous cycle. The result is constant churn: pods are scheduled, start up, serve a few seconds of traffic, and are terminated before they finish warming up.

This is an anti-pattern that arises when operators "tune" the HPA by copying the scale-up defaults to scale-down under the (wrong) intuition that "symmetry is good." The Kubernetes defaults (scale-up fast, scale-down slow) exist because pod startup time is usually longer than the metric evaluation cycle; removing a pod that is still spinning up is wasteful.

### Fix

Increase the scale-down stabilization window and tighten the scale-down policy:

```bash
kubectl patch hpa flap-hpa -n ex-5-2 --type=merge --patch '
spec:
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 180
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
'
```

Now the HPA only considers scale-down recommendations that have persisted for at least three minutes, and even then it can remove at most 10% of the pods per minute. Flapping stops; the workload's replica count tracks the smoothed load curve rather than each oscillation.

Leaving `scaleUp.stabilizationWindowSeconds: 0` is intentional: bursts should still be absorbed quickly. The asymmetry (react-fast, drain-slow) is the right production default.

---

## Exercise 5.3 Solution

Create the YAML file:

```bash
cat > /tmp/ex-5-3-vpa.yaml <<'EOF'
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: vpa-target-vpa
  namespace: ex-5-3
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: vpa-target
  updatePolicy:
    updateMode: "Off"
  resourcePolicy:
    containerPolicies:
      - containerName: "*"
        minAllowed:
          cpu: 50m
          memory: 64Mi
        maxAllowed:
          cpu: "2"
          memory: 1Gi
        controlledResources: ["cpu", "memory"]
EOF
```

Validate with dry-run:

```bash
kubectl apply --dry-run=client --validate=false -f /tmp/ex-5-3-vpa.yaml
```

Expected output: `verticalpodautoscaler.autoscaling.k8s.io/vpa-target-vpa created (dry run)`.

Spec choices with explanation:

`spec.targetRef` points at the existing `vpa-target` Deployment. VPA targets have the same kind set HPA targets do (Deployment, StatefulSet, ReplicaSet), exposed through the `scale` subresource.

`spec.updatePolicy.updateMode: "Off"` makes VPA observe without applying. VPA recommendations appear in the VPA's `status.recommendation` field but pods are not evicted or modified. This is the right mode for establishing a baseline: learn what VPA recommends for the workload, review the numbers, then decide whether to switch to `Initial` (apply at pod create only) or `Auto` (continuously apply by evicting pods, or by in-place resize where supported).

`spec.resourcePolicy.containerPolicies[0].containerName: "*"` applies the bounds to every container in the pod. Per-container overrides with specific container names are also valid.

`minAllowed` and `maxAllowed` clamp VPA's recommendations: VPA will never recommend less than `50m` CPU or `64Mi` memory, and never more than `2` full cores or `1Gi` memory. This prevents VPA from running unreasonable values under extreme load or idle conditions.

`controlledResources: ["cpu", "memory"]` restricts VPA to CPU and memory. The field is a list because future versions of VPA may support additional resources (ephemeral storage, for example). Leaving it unset allows VPA to touch every resource it recognizes.

The `--validate=false` flag is necessary because the VPA CustomResourceDefinition is not installed in this cluster; without it, kubectl would fail the client-side schema validation for the unknown CRD. In a cluster where VPA is installed, `--validate=false` is unnecessary.

---

## Common Mistakes

Forgetting that HPA requires resource requests on the target workload. An HPA targeting CPU utilization cannot compute a utilization percentage without a CPU request on the target's pod template; the TARGETS column stays at `<unknown>/X%` and no scaling happens. The symptom is identical whether the entire resources block is missing (Exercise 3.1) or only CPU is missing (Exercise 3.3). When an HPA is not scaling, the second thing to check (after metrics-server health) is `kubectl get deployment X -o jsonpath='{.spec.template.spec.containers[0].resources}'`; empty output or a block without `requests.cpu` is the root cause.

Trusting that `kubectl autoscale` produces the spec you want. The imperative command generates a minimal HPA object with `apiVersion: autoscaling/v1`, which supports only a single CPU target. Any question that requires memory metrics, behavior tuning, or multiple metrics must be answered declaratively with `autoscaling/v2`.

Setting `scaleDown.stabilizationWindowSeconds: 0` in an attempt to make the HPA "responsive." Zero-stabilization scale-down combined with any oscillating workload causes flapping between minimum and maximum replica counts, which is strictly worse than the conservative default. Five minutes (300 seconds) is the default for a good reason; if you tune it, tune downward cautiously and in proportion to how long your workload's metric dips actually last.

Confusing `Utilization` with `AverageValue` in the metric target. `Utilization` is a percentage computed against the pod's `resources.requests`; `AverageValue` is an absolute quantity per pod (`500m` CPU, for example). A Deployment with `requests.cpu: 100m` and an HPA target of `Utilization: 50` triggers at `50m` average CPU per pod. The same Deployment with `AverageValue: 50m` triggers at the same threshold, but decoupled from requests. The two produce equivalent behavior until someone changes the pod's requests, at which point `Utilization` tracks the change and `AverageValue` does not.

Running HPA and VPA on the same resource on the same workload. If both target CPU on the same Deployment, VPA lowering requests based on observed usage makes HPA see higher utilization and scale out further, which makes each pod's load lower, which makes VPA lower requests more. The feedback loop oscillates. The canonical pairing is HPA on one resource (typically CPU) and VPA on the other (typically memory), or one or the other, not both on the same resource.

Expecting in-place resize to take effect in Kubernetes versions below 1.33. In-place pod resize reached GA in 1.33; clusters running 1.32 or earlier treat `resizePolicy` as a structural field that validates (and persists in the spec) but the subresource `resize` is not available, so `kubectl patch pod --subresource=resize` returns an error. For the CKA exam (K8s 1.35), in-place resize is fully GA; for production clusters below 1.33, plan around pod restart.

Forgetting to restart a container that caches its memory limit at startup when memory is resized. The `RestartContainer` resize policy exists specifically so that memory-tuned runtimes (JVM, some Python memory managers, manually-capped processes) can re-initialize with the new limit. Setting `resizePolicy.memory.restartPolicy: NotRequired` on a pod whose process caches the old limit does not produce an error; the new limit lives in the cgroup, but the process inside the container still thinks it has the old limit and may OOM or underutilize. Match the policy to the process's behavior, not the Kubernetes default.

---

## Verification Commands Cheat Sheet

```bash
# HPA state and events
kubectl get hpa HPA_NAME -n NS
kubectl describe hpa HPA_NAME -n NS
kubectl get hpa HPA_NAME -n NS -w

# HPA condition fields
kubectl get hpa HPA_NAME -n NS \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status}({.reason}){"\n"}{end}'

# HPA current metrics
kubectl get hpa HPA_NAME -n NS \
  -o jsonpath='{range .status.currentMetrics[*]}{.resource.name}={.resource.current.averageUtilization}{"\n"}{end}'

# Metrics-server health
kubectl top nodes
kubectl top pods -n NS
kubectl top pods -n NS -l app=LABEL
kubectl get apiservice v1beta1.metrics.k8s.io

# Target Deployment's resources
kubectl get deployment DEPLOY_NAME -n NS \
  -o jsonpath='{.spec.template.spec.containers[0].resources}{"\n"}'

# In-place resize
kubectl patch pod POD_NAME -n NS --subresource=resize --patch '
spec:
  containers:
    - name: CONTAINER
      resources:
        requests:
          cpu: NEW_VALUE
'

kubectl get pod POD_NAME -n NS \
  -o jsonpath='{.status.containerStatuses[0].restartCount}{"\n"}'

kubectl get pod POD_NAME -n NS \
  -o jsonpath='{.spec.containers[0].resources}{"\n"}'

# VPA (client-side validation without installing the CRD)
kubectl apply --dry-run=client --validate=false -f vpa.yaml
```

When an HPA is not scaling, the fast diagnostic loop is: run `kubectl get hpa HPA_NAME -n NS` to read TARGETS, then `kubectl describe hpa HPA_NAME -n NS` to read Conditions, then `kubectl top pod -l app=X -n NS` to verify metrics-server is seeing the target. Those three commands identify the cause of almost every HPA failure in under thirty seconds.
