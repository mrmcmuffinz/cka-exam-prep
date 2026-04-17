# Troubleshooting

**CKA Domain:** Troubleshooting (30%)
**Competencies covered:** Troubleshoot clusters and nodes, troubleshoot cluster
components, monitor resource usage, manage container output streams, troubleshoot
services and networking

---

## Why Four Assignments

Troubleshooting is the largest CKA domain at 30% of the exam. It is also inherently
cross-domain: a single troubleshooting scenario might involve a broken Deployment,
a misconfigured Service selector, a DNS resolution failure, and a certificate that
has expired. Cramming all of that into one assignment would either produce shallow
exercises or an unworkable 15-exercise set that tries to cover too many failure
domains at once.

The four assignments decompose troubleshooting by failure layer, matching how an
administrator would mentally triage a problem in production: is the application
itself broken (assignment 1), is the control plane down (assignment 2), is a node
unhealthy (assignment 3), or is the network misconfigured (assignment 4). Each
assignment focuses on one layer but allows cross-layer scenarios in its Level 4 and
Level 5 exercises.

---

## Assignments

| Assignment | Title | Covers | Prerequisites |
|---|---|---|---|
| assignment-1 | Application Troubleshooting | Pod failures (CrashLoopBackOff, ImagePullBackOff, ErrImagePull), crash diagnosis from logs/events, resource exhaustion (OOMKilled, throttling), incorrect commands/args/env, missing ConfigMaps/Secrets, volume mount failures, service selector mismatches | All previous topics |
| assignment-2 | Control Plane Troubleshooting | API server failures (static pod manifest errors, cert issues, port conflicts), scheduler/controller-manager failures, etcd failures, static pod manifest debugging, certificate expiration, control plane logs | cluster-lifecycle, tls-and-certificates |
| assignment-3 | Node and Kubelet Troubleshooting | Node NotReady diagnosis, kubelet status/logs, container runtime issues, node conditions (MemoryPressure, DiskPressure, PIDPressure), automatic taints, node drain/recovery, kubelet configuration | cluster-lifecycle |
| assignment-4 | Network Troubleshooting | Service unreachable (empty endpoints, selector mismatch, wrong port), DNS resolution failures, network policy blocking traffic, kube-proxy issues, pod-to-pod connectivity, cross-namespace connectivity, external access failures | services, coredns, network-policies |

## Scope Boundaries

Troubleshooting exercises intentionally combine failures from multiple topic areas.
However, the exercises assume the learner has already practiced the individual topics
in their dedicated assignments. The troubleshooting series adds the diagnostic skill
(identifying what is wrong from symptoms) on top of the configuration skill (knowing
how to fix it).

Every other assignment in the repository also includes debugging exercises at Levels
3 and 5, providing distributed troubleshooting practice. The troubleshooting series
is distinct in that it focuses on cross-domain scenarios and realistic failure
combinations rather than single-concept debugging.

## Cluster Requirements

Multi-node kind cluster for all four assignments. Assignments 2 and 3 involve control
plane and node-level operations. Assignment 4 requires a CNI with NetworkPolicy support
(Calico) for network policy debugging scenarios.

Some control plane and node failure scenarios may be limited in kind (where nodes are
containers rather than VMs or bare-metal). The prompts should identify which scenarios
work in kind and which are conceptual or require workarounds.

## Recommended Order

Complete all other topic assignments before starting the troubleshooting series. Work
through assignments 1-4 in order, since they progress from application-level (most
accessible) to network-level (most complex) troubleshooting.
