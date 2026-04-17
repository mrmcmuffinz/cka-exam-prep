# Services

**CKA Domain:** Services & Networking (20%)
**Competencies covered:** Use ClusterIP, NodePort, LoadBalancer service types and
endpoints, understand connectivity between Pods

---

## Why One Assignment

Services are the primary abstraction for exposing pods to other pods and to external
traffic. The CKA tests ClusterIP, NodePort, and LoadBalancer types, along with
endpoints, headless services, and service discovery. This produces roughly 10-12
exercise areas. While services interact heavily with DNS (CoreDNS), Ingress, and
Network Policies, those interactions are covered in their respective topics. The
service assignment focuses on the Service resource itself: creation, configuration,
selector matching, endpoint verification, and the differences between service types.

---

## Assignments

| Assignment | Title | Covers | Prerequisites |
|---|---|---|---|
| assignment-1 | Services | ClusterIP, NodePort, LoadBalancer, service selectors and label matching, Endpoints and EndpointSlices, headless services (ClusterIP: None), service discovery (env vars and DNS), ExternalName services | pods/assignment-7 |

## Scope Boundaries

This topic covers the Service resource. The following related areas are handled by
other topics:

- **CoreDNS** (DNS-based service discovery in depth): covered in `coredns/`
- **Ingress and Gateway API** (L7 routing to backend services): covered in `ingress-and-gateway-api/`
- **Network Policies** (controlling which pods can reach a service): covered in `network-policies/`
- **Service selector mismatches as troubleshooting**: covered in `troubleshooting/assignment-1` and `troubleshooting/assignment-4`

## Cluster Requirements

Multi-node kind cluster. NodePort exercises need multiple nodes to demonstrate external
access patterns. LoadBalancer exercises will be conceptual or use a lightweight
LoadBalancer implementation (like metallb) since kind does not natively provision
external load balancers.

## Recommended Order

Complete pods/assignment-7 (Workload Controllers) first, since services need Deployments
as backends for realistic exercises.
