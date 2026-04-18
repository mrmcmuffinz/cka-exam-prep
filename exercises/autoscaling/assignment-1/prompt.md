# Prompt: Workload Autoscaling (assignment-1)

## Header

- **Series:** Autoscaling (1 of 1)
- **CKA domain:** Workloads & Scheduling (15%)
- **Competencies covered:** Configure workload autoscaling (HorizontalPodAutoscaler, VerticalPodAutoscaler concepts, in-place pod resize)
- **Course sections referenced:** S5 (lectures 122-129, Autoscaling HPA, VPA, in-place resize), S4 (lectures 88-91, metrics-server)
- **Prerequisites:** `pods/assignment-5` (Resources and QoS), `pods/assignment-7` (Workload Controllers)

## Scope declaration

### In scope for this assignment

*metrics-server setup and verification*
- Installing metrics-server with the `--kubelet-insecure-tls` patch required for kind (see `docs/cluster-setup.md#metrics-server`)
- Verifying with `kubectl top nodes` and `kubectl top pods`
- Understanding that HPA depends on metrics-server (without it, HPA cannot fetch CPU or memory metrics)

*HorizontalPodAutoscaler fundamentals*
- `apiVersion: autoscaling/v2` (not the older v1)
- `spec.scaleTargetRef` pointing at a Deployment or StatefulSet
- `spec.minReplicas` and `spec.maxReplicas`
- `spec.metrics` array with `Resource` type metrics
- CPU-based scaling (target average utilization)
- Memory-based scaling (target average value or utilization)
- Relationship between pod resource requests and HPA target utilization (HPA needs requests set to compute utilization)

*HPA behavior configuration*
- `spec.behavior.scaleUp` and `spec.behavior.scaleDown` policies
- `stabilizationWindowSeconds` (prevents thrashing during rapid metric fluctuations)
- `periodSeconds` for policy evaluation windows
- Max scale-up and scale-down rates via `policies` list

*In-place pod resize (Kubernetes 1.33+ GA)*
- `spec.containers[].resizePolicy` (`restartPolicy: NotRequired` or `RestartContainer` per resource)
- Updating `resources.requests` and `resources.limits` on a running pod via `kubectl patch` or `kubectl edit`
- Observing the resize in `kubectl get pod -o yaml` (status.containerStatuses resources)
- Which resources can be resized without restart (CPU, memory) and which require container restart

*VerticalPodAutoscaler concepts*
- What VPA does (recommends or applies resource request changes to pods)
- VPA operating modes (Off, Initial, Auto)
- Why VPA is usually installed separately (not part of core Kubernetes)
- When VPA and HPA can coexist (never target the same resource on the same workload)

*HPA diagnostic workflow*
- Reading `kubectl describe hpa` (conditions, current metrics, target metrics, replica count history)
- `unable to get metrics` and its typical causes (metrics-server down, pod has no resource requests, selector mismatch)
- Observing `ScalingActive` and `AbleToScale` conditions
- Debugging flapping or thrashing behavior

### Out of scope (covered in other assignments, do not include)

- Static resource requests and limits (covered in `pods/assignment-5`)
- Deployment creation and rollouts (covered in `pods/assignment-7`)
- Custom metrics API and external metrics (the API and concept are in scope at a conceptual level; writing a custom metrics adapter is out of scope)
- Cluster-level node autoscaling (requires cloud provider integration, out of CKA)
- PodDisruptionBudget (not on CKA curriculum)
- KEDA or other event-driven autoscalers (out of CKA scope)

## Environment requirements

- Multi-node kind cluster per `docs/cluster-setup.md#multi-node-kind-cluster` so that horizontal scale-out is observable across workers
- metrics-server installed per `docs/cluster-setup.md#metrics-server`
- A CPU-generating workload image for load tests; `registry.k8s.io/hpa-example:latest` is the traditional choice but should be replaced with a pinned equivalent at generation time if possible

## Resource gate

All CKA resources are in scope. The assignment uses Deployments as HPA targets, ConfigMaps for configuration of load-generating clients, and Services to front the workload for curl-based load injection. Optional StatefulSet as a second HPA target for the target-selection exercise.

## Topic-specific conventions

- Every exercise that creates an HPA must also create a workload with explicit `resources.requests` on the container (HPA cannot compute utilization without requests).
- Load generation for scale-up tests should use a short-lived pod running `curl` or `wget` in a loop, not an external tool. The tutorial should show a reproducible load pattern.
- The in-place resize exercises should explicitly demonstrate that the container does not restart when CPU or memory changes with `resizePolicy: NotRequired`, using `kubectl get pod -o jsonpath='{.status.containerStatuses[0].restartCount}'` to verify.
- VPA exercises are conceptual only because VPA is not part of core Kubernetes and installing it in kind adds complexity without teaching value at exam scope. The tutorial should explain VPA with a worked example YAML and the outputs you would see, not actually install VPA.
- Every HPA exercise must include verification that the HPA has observed metrics at least once (`kubectl get hpa` with non-`<unknown>` values in TARGETS column).

## Cross-references

**Prerequisites (must be completed first):**
- `exercises/pods/assignment-5`: requests, limits, QoS classes
- `exercises/pods/assignment-7`: Deployments (HPA's primary target)

**Adjacent topics:**
- `exercises/jobs-and-cronjobs/`: batch workloads that HPA does not target
- `exercises/statefulsets/`: HPA can target StatefulSets; one exercise exercises this

**Forward references:**
- `exercises/troubleshooting/assignment-1`: application troubleshooting will include "HPA not scaling" as a diagnostic scenario
