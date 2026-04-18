# Autoscaling

**CKA Domain:** Workloads & Scheduling (15%)
**Competencies covered:** Configure workload autoscaling (Horizontal Pod Autoscaler, Vertical Pod Autoscaler concepts, in-place pod resize)

---

## Rationale for Number of Assignments

Kubernetes offers three mechanisms for adjusting workload resources in response to demand. HorizontalPodAutoscaler (HPA) scales pod count based on CPU, memory, or custom metrics via the `autoscaling/v2` API. VerticalPodAutoscaler (VPA) scales pod resource requests and limits, and is a concept the exam tests at an introductory level since VPA is not bundled with core Kubernetes. In-place pod resize (GA in Kubernetes 1.33) changes a running pod's resource requests without restarting the container. All three depend on metrics-server for observability, and all three have diagnostic failure modes (no metrics, selector mismatches, thrashing, eviction). The material totals roughly 9 focused subtopics, which fits a single well-scoped assignment since the subtopics are interdependent and best taught together. Splitting into two would break the natural teaching flow from metrics-server to HPA to in-place resize.

---

## Assignment Summary

| Assignment | Description | Prerequisites |
|---|---|---|
| assignment-1 | Workload Autoscaling | metrics-server installation and verification, HPA spec (`autoscaling/v2`, scaleTargetRef, minReplicas, maxReplicas, metrics array), CPU-based HPA, memory-based HPA, HPA behavior configuration (scaleUp/scaleDown policies, stabilizationWindowSeconds), in-place pod resize (resize policies, restartPolicy per-resource), VPA concepts (Auto, Initial, Off update modes), HPA diagnostics (unable to fetch metrics, selector mismatches, scale-to-zero) | pods/assignment-5 (Resources and QoS), pods/assignment-7 (Workload Controllers) |

## Scope Boundaries

This topic covers autoscaling controllers. The following related areas are handled by other topics.

- **Static resource requests and limits, QoS classes**: covered in `pods/assignment-5`
- **Long-running workloads that HPA scales**: covered in `pods/assignment-7`
- **Custom metrics adapters and external metrics**: conceptual only in this assignment; deep custom metrics work is out of CKA scope
- **Cluster autoscaling** (node scaling): out of scope for CKA, relies on cloud-provider integration
- **PodDisruptionBudgets** (coordinate with voluntary disruptions during scale-down): not on the CKA curriculum but worth mentioning as context

## Cluster Requirements

Multi-node kind cluster so that horizontal scaling is observable across workers. metrics-server is required for every exercise. See `docs/cluster-setup.md#multi-node-kind-cluster` and `docs/cluster-setup.md#metrics-server`.

## Recommended Order

Complete `pods/assignment-5` (Resources and QoS) and `pods/assignment-7` (Workload Controllers) before this topic. HPA targets Deployments and StatefulSets, which are taught there. The in-place resize material builds on the requests/limits semantics from assignment-5.

---

## Current Status

Topic scoped on 2026-04-18 as part of Phase 3 of `docs/remediation-plan.md`. Content generation is tracked under Phase 4 of the remediation plan. The `prompt.md` for assignment-1 lives in this directory alongside this README.
