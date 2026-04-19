# Workload Autoscaling Tutorial

Three scaling mechanisms are relevant for the CKA. HorizontalPodAutoscaler (HPA) scales the number of replicas in a workload controller based on observed metrics. In-place pod resize changes a running pod's CPU and memory requests without restarting the container (stable since Kubernetes 1.33). VerticalPodAutoscaler (VPA) recommends or applies resource-request changes to pods and is treated at a concept level on the exam because it is not bundled with core Kubernetes. This tutorial builds one complete HPA workflow end to end, demonstrates in-place resize on a running pod, and walks through a VPA spec without installing the VPA controller.

The tutorial depends on a running metrics-server. Every HPA in this topic depends on metrics-server, and every kubectl top command depends on metrics-server. Before creating the first HPA, the tutorial confirms metrics-server is healthy; without that confirmation, later steps appear broken for reasons that have nothing to do with the HPA spec.

The tutorial namespace is `tutorial-autoscaling`.

## Prerequisites

A multi-node kind cluster with metrics-server installed. The authoritative setup is at `docs/cluster-setup.md#multi-node-kind-cluster` and `docs/cluster-setup.md#metrics-server`. Verify:

```bash
kubectl config current-context               # expect: kind-kind
kubectl get nodes                            # expect: 4 nodes, all Ready
kubectl top nodes                            # expect: rows with CPU and MEMORY columns populated
kubectl top pods -n kube-system              # expect: rows for kube-system pods
```

If `kubectl top nodes` reports `error: Metrics API not available`, metrics-server is either not installed or not patched with `--kubelet-insecure-tls`. Install or re-patch per the cluster-setup document before continuing. No HPA in this tutorial works until `kubectl top nodes` succeeds.

Create the tutorial namespace:

```bash
kubectl create namespace tutorial-autoscaling
```

## Step 1: Deploy a Target Workload with Explicit Resource Requests

HPA computes CPU utilization as a percentage of the container's CPU request. A pod with no `requests.cpu` cannot be autoscaled on CPU; the HPA's target-utilization calculation divides by zero and the TARGETS column stays at `<unknown>` forever. Every HPA target must set resource requests in its pod template.

Create the deployment:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: tutorial-autoscaling
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
              name: http
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: webapp
  namespace: tutorial-autoscaling
spec:
  ports:
    - port: 80
      targetPort: http
  selector:
    app: webapp
EOF
```

Verify it is running and that metrics-server has observed it:

```bash
kubectl rollout status deployment/webapp -n tutorial-autoscaling --timeout=60s
kubectl top pods -n tutorial-autoscaling
```

Expected: one row for a `webapp-...` pod with small CPU (a few m) and memory (a few Mi) values. If the row shows `<unknown>` values, wait 15 to 30 seconds for metrics-server's next scrape cycle.

## Step 2: Create a CPU-Based HPA

The HPA object is a control loop; it reads metrics on a fixed schedule (default 15 seconds), computes the desired replica count, and updates the target controller's `spec.replicas`. The control loop runs in the kube-controller-manager, not in a separate deployment.

Create an HPA targeting 50% CPU utilization with 1 to 5 replicas:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: webapp-hpa
  namespace: tutorial-autoscaling
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
EOF
```

Imperative form using `kubectl autoscale`:

```bash
kubectl -n tutorial-autoscaling autoscale deployment webapp --min=1 --max=5 --cpu-percent=50
```

The imperative form produces the same object (minus the explicit `apiVersion: autoscaling/v2`; some kubectl versions still generate v1 for this subcommand, which is why the declarative form is preferred when the exam question asks for specific behavior tuning).

Wait for the HPA to observe the first metric:

```bash
kubectl get hpa webapp-hpa -n tutorial-autoscaling
```

Expected (after 30 seconds): the TARGETS column shows a number like `2%/50%` or similar (the first value is observed CPU as a percentage of requests; the second is the target). If TARGETS still reads `<unknown>/50%`, metrics-server has not yet scraped; wait another 15 seconds.

HPA spec fields relevant to this tutorial:

`spec.scaleTargetRef`. The controller that HPA scales. Three required subfields: `apiVersion` (for a Deployment, `apps/v1`; for a StatefulSet, also `apps/v1`), `kind` (`Deployment`, `StatefulSet`, `ReplicaSet`), and `name`. Default when omitted: the field is required; validation fails. Failure mode when the named target does not exist: the HPA applies but the `AbleToScale` condition reports `False` with reason `FailedGetScale`.

`spec.minReplicas`. Lower bound on the replica count. Default when omitted: defaults to 1 (cannot be omitted in the object; if unset it is set to 1 by the validation). Values below 1 require the `HPAScaleToZero` feature gate which is beta and enabled by default since 1.24; setting `minReplicas: 0` lets the HPA scale a workload to zero when the metric allows it.

`spec.maxReplicas`. Upper bound. Default when omitted: the field is required. Failure mode when unreasonably high: the cluster tries to admit many pods; if they cannot be scheduled the HPA reports `ScalingLimited` with reason `DesiredWithinRange`.

`spec.metrics`. A list of metric sources. Each entry is one of `Resource` (built-in, CPU or memory), `Pods` (custom, per-pod value), `Object` (custom, on a single target object), or `External` (arbitrary external source). For `Resource` with CPU or memory, the `target` subfield specifies `type: Utilization` with `averageUtilization` (a percentage), or `type: AverageValue` with `averageValue` (an absolute quantity like `200m` or `300Mi`). Default when omitted: the field is required for any real HPA. Failure mode when the target metric cannot be computed (for example, `Utilization` but the pod has no `requests.cpu`): HPA `ScalingActive` condition goes to `False` with reason `FailedGetResourceMetric`.

`spec.behavior`. Optional block tuning scale-up and scale-down behavior independently. Introduced later in this tutorial.

## Step 3: Generate Load and Observe Scale-Out

Generate CPU load by running a short-lived pod that hits the webapp Service in a tight loop. In a separate terminal so you can watch the HPA react:

```bash
kubectl -n tutorial-autoscaling run loadgen \
  --image=busybox:1.36 \
  --restart=Never \
  --rm -it \
  -- sh -c 'while true; do wget -q -O- http://webapp/ > /dev/null; done'
```

Leave this command running. In the original terminal, watch the HPA:

```bash
kubectl get hpa webapp-hpa -n tutorial-autoscaling -w
```

Expected: the TARGETS column's first value rises above 50% within 30 seconds; the REPLICAS column climbs from 1 toward the current MAX of 5 over the next minute. The HPA scales up in steps controlled by default behavior: at most 4 pods or 100% per 15 seconds (whichever is larger).

Observe the deployment:

```bash
kubectl get deployment webapp -n tutorial-autoscaling
kubectl get pods -n tutorial-autoscaling -l app=webapp
```

Expected: `READY` column grows (for example, `3/3`, `4/4`) as the scale-out proceeds and the new pods finish their rollout.

Stop the load generator (Ctrl+C in the loadgen terminal). The pod exits with `--rm` and is deleted.

Watch the HPA scale down:

```bash
kubectl get hpa webapp-hpa -n tutorial-autoscaling -w
```

Expected: CPU utilization drops to near zero; after the default scale-down stabilization window of 300 seconds (five minutes), the REPLICAS column starts dropping toward 1. This long stabilization is intentional: scaling down too aggressively in response to transient dips causes thrashing in production.

## Step 4: Tune HPA Behavior

Default HPA behavior is scaling-up-fast (100% in 15 seconds) and scaling-down-cautious (10% or one pod per 15 seconds, plus a 300-second stabilization window). The `spec.behavior` block lets you tune both directions independently. A common production pattern is "react quickly to bursts, drain slowly afterward," which is the default; the opposite pattern (react cautiously, drain quickly) is useful for cost-sensitive workloads that tolerate latency during scale-up.

Reshape the HPA's behavior:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: webapp-hpa
  namespace: tutorial-autoscaling
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  minReplicas: 1
  maxReplicas: 5
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
      stabilizationWindowSeconds: 60
      policies:
        - type: Percent
          value: 25
          periodSeconds: 15
EOF
```

This configuration scales up aggressively (up to doubling the pod count every 15 seconds, no stabilization) and scales down more quickly than the default (one-minute stabilization instead of five, and 25% per 15 seconds).

`spec.behavior.scaleUp` and `spec.behavior.scaleDown` sub-blocks take three kinds of settings:

`stabilizationWindowSeconds`. Smoothing window for the direction. The HPA considers the recent metric history inside the window and chooses the most cautious replica count that satisfies the policy. For scale-up, the default is 0 (no smoothing; scale up on the latest observation). For scale-down, the default is 300 seconds (five minutes). Larger values smooth out spikes and dips; smaller values react faster.

`policies`. A list of rate caps. Each policy has `type` (`Percent` or `Pods`), `value` (a number), and `periodSeconds` (the evaluation window, usually 15). The most restrictive policy wins by default, or you can set `selectPolicy: Max` to use the most permissive. A typical production scale-up policy caps growth at `Percent: 100, periodSeconds: 15` to double the pod count per evaluation; a scale-down policy caps shrinkage at `Percent: 10, periodSeconds: 15` to avoid removing pods faster than they can drain.

`selectPolicy`. Either `Max` (use the most aggressive policy among the list) or `Min` (use the most conservative; this is the default). `Disabled` disables the direction entirely, which is useful when you want HPA to only scale one way.

## Step 5: Memory-Based HPA

HPA can also target memory utilization. The calculation is the same as CPU: observed memory usage divided by `resources.requests.memory`, as a percentage. The mechanics of `AverageUtilization` versus `AverageValue` also mirror CPU. The only real difference is that memory is less bursty than CPU in typical workloads; memory-based HPAs are usually secondary signals behind CPU-based ones.

Add a second metric to the existing HPA so it scales on the highest of CPU or memory utilization:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: webapp-hpa
  namespace: tutorial-autoscaling
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 75
EOF
```

With a multi-metric HPA, each evaluation computes the desired replica count for each metric and uses the maximum. In other words, whichever metric is most under pressure drives the scale decision. Verify:

```bash
kubectl describe hpa webapp-hpa -n tutorial-autoscaling | head -40
```

Expected: both Metrics entries appear under `Metrics`, each reporting its current-vs-target value. Current values typically sit well below target when no load is applied.

## Step 6: In-Place Pod Resize

In-place pod resize (stable since Kubernetes 1.33) changes a running pod's `resources.requests` and `resources.limits` without restarting its container, for resources that declare `resizePolicy.restartPolicy: NotRequired`. CPU and memory default to `NotRequired`, which means updates propagate without restart. Setting `restartPolicy: RestartContainer` for a specific resource forces a container restart on update.

Create a pod with explicit resize policies:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: resizer
  namespace: tutorial-autoscaling
spec:
  containers:
    - name: app
      image: nginx:1.27
      resources:
        requests:
          cpu: 100m
          memory: 64Mi
        limits:
          cpu: 500m
          memory: 128Mi
      resizePolicy:
        - resourceName: cpu
          restartPolicy: NotRequired
        - resourceName: memory
          restartPolicy: RestartContainer
EOF

kubectl wait --for=condition=Ready pod/resizer -n tutorial-autoscaling --timeout=60s
```

Capture the initial restart count and resources:

```bash
kubectl get pod resizer -n tutorial-autoscaling \
  -o jsonpath='{.status.containerStatuses[0].restartCount}{"\n"}'
# Expected: 0

kubectl get pod resizer -n tutorial-autoscaling \
  -o jsonpath='{.spec.containers[0].resources.requests.cpu}{"\n"}'
# Expected: 100m
```

Resize CPU upward via `kubectl patch`:

```bash
kubectl patch pod resizer -n tutorial-autoscaling --subresource=resize --patch '
spec:
  containers:
    - name: app
      resources:
        requests:
          cpu: 200m
        limits:
          cpu: 500m
'
```

The `--subresource=resize` flag targets the pod's `resize` subresource, which is the path v1.33+ supports for in-place resize. Check the restart count and the new CPU request:

```bash
kubectl get pod resizer -n tutorial-autoscaling \
  -o jsonpath='{.status.containerStatuses[0].restartCount}{"\n"}'
# Expected: 0  (still zero; CPU change did not restart)

kubectl get pod resizer -n tutorial-autoscaling \
  -o jsonpath='{.spec.containers[0].resources.requests.cpu}{"\n"}'
# Expected: 200m
```

Now resize memory upward. Because memory's `restartPolicy` is `RestartContainer`, this forces a restart:

```bash
kubectl patch pod resizer -n tutorial-autoscaling --subresource=resize --patch '
spec:
  containers:
    - name: app
      resources:
        requests:
          memory: 96Mi
        limits:
          memory: 192Mi
'

kubectl wait --for=condition=Ready pod/resizer -n tutorial-autoscaling --timeout=60s

kubectl get pod resizer -n tutorial-autoscaling \
  -o jsonpath='{.status.containerStatuses[0].restartCount}{"\n"}'
# Expected: 1  (restart count incremented because memory resize requires restart)
```

Resize spec fields relevant to this tutorial:

`spec.containers[].resizePolicy`. A list, one entry per resource that should have a non-default policy. Each entry has `resourceName` (`cpu` or `memory`) and `restartPolicy` (`NotRequired` or `RestartContainer`). Default when omitted: both CPU and memory are `NotRequired` as of 1.33+, so in-place resize works without restart unless you opt in to restart-on-change.

Observe the same resources in the pod's status (what is actually being applied):

```bash
kubectl get pod resizer -n tutorial-autoscaling -o yaml \
  | grep -A8 '^status:'
```

Look for `containerStatuses[0].resources` and `allocatedResources` fields, which report what the pod is actually running with (may momentarily differ from `spec.containers[0].resources` during a resize).

## Step 7: VerticalPodAutoscaler Concepts

VPA is not bundled with core Kubernetes; in production clusters it is installed as a separate component from the `kubernetes/autoscaler` repository. The CKA exam treats it at a concept level: know what it does, know its three update modes, and know why it conflicts with HPA on the same resource.

A typical VPA spec looks like this:

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: webapp-vpa
  namespace: tutorial-autoscaling
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
      - containerName: "*"
        minAllowed:
          cpu: 50m
          memory: 64Mi
        maxAllowed:
          cpu: 2000m
          memory: 2Gi
        controlledResources: ["cpu", "memory"]
```

VPA fields relevant at concept level:

`spec.targetRef`. The workload the VPA watches. Same fields as HPA's `scaleTargetRef`.

`spec.updatePolicy.updateMode`. Three values:

- `Off`: VPA observes and records recommendations but does not change anything. Use when you want recommendations without automatic application; read the VPA status with `kubectl describe vpa` to see what it would do.
- `Initial`: VPA applies recommendations only when pods are created. Useful when you do not want running pods disturbed.
- `Auto`: VPA applies recommendations by evicting pods so the controller recreates them at the new sizes. In 1.33+ clusters with VPA's `InPlaceOrRecreate` support enabled, VPA can use in-place resize instead of eviction, but the default behavior remains eviction.

`spec.resourcePolicy`. Per-container policy for which resources VPA may adjust and within what bounds. `controlledResources` limits which resources VPA touches; `minAllowed` and `maxAllowed` set bounds on recommendations.

Why VPA and HPA conflict on the same resource: VPA adjusts `resources.requests` to make each pod the right size for its load; HPA scales the pod count based on utilization relative to requests. If both target CPU on the same workload, VPA lowering requests makes HPA see higher utilization and scale out further, which causes VPA to lower requests more, and so on. The general rule is: HPA on one resource (usually CPU), VPA on the other (usually memory), never both on the same resource on the same workload.

Do not apply the VPA YAML above; VPA is not installed in this tutorial. The purpose of this step is to recognize the VPA object and explain its behavior, not to exercise it.

## Step 8: The HPA Diagnostic Workflow

When an HPA is not scaling as expected, the canonical sequence is:

1. Read the `TARGETS` column in `kubectl get hpa`. If it shows `<unknown>`, metrics-server has not scraped or the target has no resource requests. If it shows current/target values but REPLICAS is not changing, check `Conditions` in `kubectl describe hpa`.

2. Read `kubectl describe hpa <name>` in full. The `Conditions` block has three important conditions:

    - `AbleToScale`: `True` when the HPA can interact with the target's scale subresource. `False` with reason `FailedGetScale` usually means `scaleTargetRef.name` is wrong.
    - `ScalingActive`: `True` when the HPA has a current metric and is making scaling decisions. `False` with reason `FailedGetResourceMetric` typically means the target has no resource requests, or metrics-server is not available.
    - `ScalingLimited`: `False` during normal operation; `True` when the HPA is clamped at `minReplicas` or `maxReplicas`.

3. Inspect the `Events` block of the HPA. Events describe every scale decision the HPA made (or tried to make) in the last hour.

4. Run `kubectl top pod -l <selector>` against the same labels the HPA target uses. If `kubectl top` shows `<unknown>` for the target pods, metrics-server cannot reach their kubelet; confirm metrics-server is running and patched with `--kubelet-insecure-tls` in kind.

Demonstrate the workflow on the existing HPA:

```bash
kubectl describe hpa webapp-hpa -n tutorial-autoscaling
```

Expected: Conditions shows `AbleToScale: True`, `ScalingActive: True`, `ScalingLimited: True` (if current replicas equals `minReplicas` or `maxReplicas`) or `False` otherwise. Events lists the last few reconciliation decisions.

## Step 9: Clean Up

Stop any running load generator (Ctrl+C if it is still running). Delete the tutorial namespace:

```bash
kubectl delete namespace tutorial-autoscaling
```

The namespace delete cascades through the Deployment, Service, HPA, and resizer pod. No cluster-level cleanup is needed; metrics-server stays installed for the homework exercises.

## Reference Commands

### Create, inspect, tune

```bash
# Create HPA imperatively (basic CPU target)
kubectl -n NS autoscale deployment NAME --min=1 --max=10 --cpu-percent=50

# Declarative HPA
kubectl apply -f hpa.yaml

# List HPAs
kubectl get hpa -n NS

# Full HPA status (Conditions and Events)
kubectl describe hpa HPA_NAME -n NS

# Watch an HPA react
kubectl get hpa HPA_NAME -n NS -w
```

### Metrics-server checks

```bash
# Install or verify metrics-server is responding
kubectl top nodes
kubectl top pods -n NS
kubectl top pods -n NS -l app=LABEL

# Verify deployment readiness in kube-system
kubectl get deployment metrics-server -n kube-system
kubectl wait --for=condition=Available deployment/metrics-server -n kube-system --timeout=60s
```

### In-place resize

```bash
# Patch a pod's requests in place (CPU, no restart by default)
kubectl patch pod POD_NAME -n NS --subresource=resize --patch '
spec:
  containers:
    - name: CONTAINER_NAME
      resources:
        requests:
          cpu: NEW_VALUE
'

# Observe the restart count (proof that CPU resize did not restart)
kubectl get pod POD_NAME -n NS -o jsonpath='{.status.containerStatuses[0].restartCount}{"\n"}'

# Full resources view (what the container is actually running with)
kubectl get pod POD_NAME -n NS -o jsonpath='{.status.containerStatuses[0].resources}{"\n"}'
```

### HPA diagnostic one-liners

```bash
# Full HPA text dump
kubectl describe hpa HPA_NAME -n NS

# Just the conditions
kubectl get hpa HPA_NAME -n NS -o jsonpath='{range .status.conditions[*]}{.type}={.status}({.reason}){"\n"}{end}'

# Target's pod count (what HPA is actually setting)
kubectl get deployment DEPLOY_NAME -n NS -o jsonpath='{.spec.replicas}{"\n"}'

# Metrics-server endpoint health
kubectl get apiservice v1beta1.metrics.k8s.io
```

### HPA spec templates

Basic CPU-only:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: NAME
  namespace: NS
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: TARGET_NAME
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

Multi-metric with behavior tuning:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: NAME
  namespace: NS
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: TARGET_NAME
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
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

### Common failure signatures

| Symptom | Cause | First command |
|---|---|---|
| `TARGETS: <unknown>/X%` | metrics-server not ready, or target has no resource requests | `kubectl top pod -l app=X -n NS` |
| `TARGETS: <unknown>/X%` persists after 60s | target pod template missing `resources.requests.cpu` | `kubectl get deployment X -o jsonpath='{.spec.template.spec.containers[0].resources}'` |
| `AbleToScale: False`, `FailedGetScale` | `scaleTargetRef.name` does not match any workload | `kubectl get hpa X -o yaml` then check the ref |
| HPA flapping between min and max | workload metric is oscillating at the target threshold | increase `scaleDown.stabilizationWindowSeconds` |
| HPA at `maxReplicas`, not growing further | actual upper bound; raise `maxReplicas` or address the root cause | `kubectl describe hpa X` and inspect Events |
| In-place resize not taking effect | `resizePolicy` is `RestartContainer` and pod has not restarted, or cluster version below 1.33 | check pod `restartCount` and `.status.containerStatuses[0].resources` |
