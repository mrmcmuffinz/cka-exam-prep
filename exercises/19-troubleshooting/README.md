# Troubleshooting

**CKA Domain:** Troubleshooting (30%)
**Competencies covered:** Troubleshoot clusters and nodes, troubleshoot cluster components, monitor cluster and application resource usage, manage and evaluate container output streams, troubleshoot services and networking

---

## Rationale for Number of Assignments

Troubleshooting is the largest CKA domain at 30% of the exam weight and is inherently cross-domain. A single troubleshooting scenario might involve a broken Deployment, a misconfigured Service selector, a DNS resolution failure, and an expired certificate. The material naturally decomposes by failure layer, matching how an administrator would mentally triage a production problem: is the application broken, is the control plane down, is a node unhealthy, or is the network misconfigured. Four assignments organized by these failure domains provide focused diagnostic skill development while allowing cross-layer scenarios in advanced exercises.

---

## Assignment Summary

| Assignment | Description | Prerequisites |
|---|---|---|
| assignment-1 | Application Troubleshooting | Pod failure states (CrashLoopBackOff, ImagePullBackOff, ErrImagePull, CreateContainerError), crash diagnosis from logs and events, resource exhaustion (OOMKilled, CPU throttling, eviction), kubectl top for resource monitoring, metrics-server verification, incorrect commands/args/env, missing or misconfigured ConfigMaps/Secrets, volume mount failures, service selector mismatches leading to empty endpoints | All previous topics |
| assignment-2 | Control Plane Troubleshooting | API server failures (static pod manifest errors, certificate issues, port conflicts), scheduler failures (not running, misconfigured), controller manager failures (not running, RBAC issues), etcd failures (not running, data corruption, connectivity), static pod manifest debugging in /etc/kubernetes/manifests/, certificate expiration and verification, control plane component logs | cluster-lifecycle, tls-and-certificates |
| assignment-3 | Node and Kubelet Troubleshooting | Node NotReady diagnosis (kubectl describe node, conditions), kubelet not running (systemctl status, journalctl), container runtime issues, node conditions (MemoryPressure, DiskPressure, PIDPressure), taints applied automatically by node conditions, node drain and recovery, kubelet configuration issues | cluster-lifecycle |
| assignment-4 | Network Troubleshooting | Service not reachable (empty endpoints, selector mismatch, wrong port), DNS resolution failures (CoreDNS not running, misconfigured, pod DNS policy issues), network policy blocking expected traffic, kube-proxy issues (not running, wrong mode), pod-to-pod connectivity failures, cross-namespace connectivity issues, external access failures (NodePort, Ingress) | services, coredns, network-policies |

## Scope Boundaries

Troubleshooting exercises intentionally combine failures from multiple topic areas. However, the exercises assume the learner has already practiced the individual topics in their dedicated assignments. The troubleshooting series adds the diagnostic skill (identifying what is wrong from symptoms) on top of the configuration skill (knowing how to fix it).

Every other assignment in the repository also includes debugging exercises at Levels 3 and 5, providing distributed troubleshooting practice within single-domain contexts. The troubleshooting series is distinct in that it focuses on cross-domain scenarios and realistic failure combinations rather than single-concept debugging.

## Cluster Requirements

Multi-node kind cluster for all four assignments. Assignments 2 and 3 involve control plane and node-level operations. Assignment 4 requires a CNI with NetworkPolicy support (Calico) for network policy debugging scenarios.

**Kind cluster note:** Some control plane and node failure scenarios may be limited in kind (where nodes are containers rather than VMs or bare-metal). The tutorials should clearly identify which scenarios work hands-on in kind and which are conceptual or require documented workarounds.

## Recommended Order

1. Complete all other topic assignments before starting the troubleshooting series (these are cross-domain capstone assignments)
2. Work through assignments 1, 2, 3, 4 sequentially
3. Assignment-1 is most accessible (application-layer troubleshooting)
4. Assignments 2 and 3 require understanding of cluster architecture from cluster-lifecycle and tls-and-certificates
5. Assignment-4 is most complex (network-layer troubleshooting across multiple systems)
