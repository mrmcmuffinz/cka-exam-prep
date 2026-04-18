# Assignment 4: Network Troubleshooting

This is the fourth and final assignment in the Troubleshooting series. Where Assignment 1 covered application failures, Assignment 2 covered the control plane, and Assignment 3 covered nodes and the kubelet, Assignment 4 covers the network layer: Services that show up in kubectl with no endpoints, DNS lookups that fail for subtle reasons, NetworkPolicies that block traffic the operator expected to flow, kube-proxy issues that leave traffic unrouted, pod-to-pod connectivity failures across nodes, cross-namespace reachability problems, and external access via NodePort, LoadBalancer, and Ingress. Every exercise is a cross-domain debugging scenario; the fixes exercise the same diagnostic muscle the CKA exam tests, which is the ability to walk from "curl fails" to "this specific object has this specific misconfiguration" without guessing.

## Files

| File | Purpose |
|---|---|
| `prompt.md` | The generation prompt (input to the homework generator skill) |
| `README.md` | This overview |
| `troubleshooting-tutorial.md` | Tutorial teaching the network diagnostic layers: pod, Service, DNS, NetworkPolicy, external access |
| `troubleshooting-homework.md` | 15 debugging exercises across five difficulty levels |
| `troubleshooting-homework-answers.md` | Complete solutions using the three-stage debugging structure |

## Recommended Workflow

Work through the tutorial with a live cluster. It builds a single small application (a web frontend and a backend) and walks every network-layer debugging skill on that application: confirm the pods are Ready, confirm the Service has endpoints, confirm DNS resolves the Service name, confirm pod-to-pod connectivity with and without NetworkPolicy, and confirm external reachability through NodePort, LoadBalancer (via MetalLB), and Ingress (via Traefik). Once the tutorial is complete, work through the 15 exercises in order. Every exercise is a debugging task; there are no build-from-scratch exercises at this level. Level 1 covers Service issues (empty endpoints, wrong port, selector mismatch). Level 2 covers DNS failures. Level 3 covers NetworkPolicy blocking traffic. Level 4 covers external access (NodePort, Ingress, LoadBalancer). Level 5 combines multiple failure modes in one cascading scenario.

## Difficulty Progression

Level 1 practices the three canonical Service failures: a selector that does not match any pod (empty endpoints), a `targetPort` that does not match the container's listening port (endpoints exist but connections hang), and a protocol mismatch between the Service and the pod. Level 2 covers DNS resolution failures: CoreDNS not running, a client using the wrong DNS name format, and a NetworkPolicy that blocks egress to the cluster DNS service. Level 3 covers NetworkPolicy specifically: a default-deny policy with no exceptions that blocks expected traffic, a policy that forgets to allow egress (especially to DNS), and a policy with a cross-namespace `namespaceSelector` that does not match the source namespace. Level 4 covers external access: a NodePort Service that is not exposed on the right port, an Ingress that does not route (wrong `ingressClassName` or a wrong host header), and a LoadBalancer stuck in `Pending` because MetalLB is not installed. Level 5 combines failure modes: one exercise with three simultaneous issues on the same request path, one with a cascading failure across Services, DNS, and NetworkPolicy, and one production-style incident where the student must write a runbook describing the diagnostic path.

## Prerequisites

Complete `exercises/services/` (all assignments) so that Service types, selectors, ports, and endpoints are familiar. Complete `exercises/coredns/` for DNS resolution mechanics and the CoreDNS Corefile. Complete `exercises/network-policies/` for NetworkPolicy spec structure and default-deny patterns. Complete at least one of the `exercises/ingress-and-gateway-api/` assignments for Ingress resource basics. Complete `exercises/troubleshooting/assignment-1` first; the diagnostic sequence from that assignment (`get pod` then `describe pod` then `logs` then `get events`) is the base pattern extended across the network layer here.

## Cluster Requirements

A multi-node kind cluster with Calico installed for NetworkPolicy enforcement (kindnet, the default CNI, does not enforce NetworkPolicy resources), MetalLB for LoadBalancer Services, and the Traefik Ingress controller for Ingress exercises. See `docs/cluster-setup.md#multi-node-with-calico-networkpolicy-support`, `docs/cluster-setup.md#metallb-for-loadbalancer-services`, and the per-assignment Traefik install in the tutorial file. Cluster creation is a one-time setup at the start of the assignment; no exercise re-creates it.

Recovery discipline matters because some exercises temporarily disable a namespace's NetworkPolicy environment or delete a Service. Every exercise includes an explicit revert or recovery step; follow it before moving on. If the cluster is contaminated past recovery, delete it with `kind delete cluster` and rebuild per the cluster-setup document.

## Estimated Time Commitment

Plan for 60 to 90 minutes on the tutorial. The 15 exercises together take six to eight hours. Level 1 runs about 15 to 20 minutes each. Level 2 runs 20 to 30 minutes each because DNS debugging involves `nslookup` from a debug pod and reading CoreDNS logs. Level 3 runs 25 to 40 minutes each because NetworkPolicy effects take a few seconds to propagate and each test involves a connectivity probe from a specific source pod. Level 4 runs 30 to 45 minutes each because external access has several possible root causes and the diagnostic path has to rule them out in order. Level 5 runs 45 to 60 minutes per exercise; the production-incident scenario is intentionally open-ended.

## Scope Boundary and What Comes Next

This assignment covers network-layer troubleshooting: Services, DNS, NetworkPolicy, kube-proxy, pod-to-pod connectivity, and external access. It does not cover application troubleshooting (pod failure states, resource exhaustion, configuration errors), which is `exercises/troubleshooting/assignment-1`. It does not cover control plane troubleshooting (API server, scheduler, controller manager, etcd, certificates), which is `exercises/troubleshooting/assignment-2`. It does not cover node or kubelet troubleshooting (node NotReady, DiskPressure, kubelet service failures), which is `exercises/troubleshooting/assignment-3`. It does not teach CNI plugin internals beyond a conceptual level (this assignment assumes Calico is installed and working; debugging a broken Calico install is a plugin-specific topic out of CKA scope). Gateway API troubleshooting at depth is not covered beyond the Ingress API; the Gateway API assignments in `exercises/ingress-and-gateway-api/` include their own debug material.

## Key Takeaways After Completing This Assignment

By the time you finish all 15 exercises, you should be able to run a layered network diagnostic without thinking: pods Ready, Service endpoints populated, DNS resolving the Service name, client pod able to reach the Service IP with curl, NetworkPolicy not blocking the flow, external ingress path intact. You should know that an empty `kubectl get endpoints <svc>` points at a Service selector problem and that a populated endpoints list with curl timeouts points at a targetPort or protocol problem. You should know that a fast DNS failure (`nslookup` returning NXDOMAIN immediately) points at a DNS name typo or a wrong search-domain, and that a slow DNS failure (`nslookup` hanging) points at CoreDNS being down or DNS egress being blocked by a NetworkPolicy. You should know that NetworkPolicy blocks apply only in namespaces where a policy targets a given pod and that a default-deny-all policy blocks everything including DNS unless explicit egress allows it; you should know to add `- to: - namespaceSelector: matchLabels: kubernetes.io/metadata.name: kube-system` with port 53 UDP as the canonical DNS egress exception. You should know that a NodePort Service is reachable from outside on each node's IP at the NodePort (not at the Service port) and that an Ingress without a matching `ingressClassName` is silently ignored by every controller. Finally, you should be comfortable writing a runbook for a production network incident: start with the symptom, name the diagnostic command for each layer in order, and escalate only when the symptom does not match the expected output for that layer.
