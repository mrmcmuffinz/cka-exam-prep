# Services

**CKA Domain:** Services & Networking (20%)
**Competencies covered:** Use ClusterIP, NodePort, LoadBalancer service types and endpoints, understand connectivity between Pods

---

## Rationale for Number of Assignments

Services are the primary abstraction for exposing pods to other pods and to external traffic. The material encompasses ClusterIP services with selectors and endpoints, NodePort and LoadBalancer external access patterns, service discovery mechanisms, headless services, ExternalName services, and service troubleshooting. This produces roughly 16-18 distinct subtopics. The material splits naturally into three focused progressions: ClusterIP services with internal discovery, external service types (NodePort, LoadBalancer, ExternalName), and advanced service patterns with troubleshooting. Each assignment delivers 5-6 subtopics at depth, building from basic internal services through external exposure to comprehensive service debugging.

---

## Assignment Summary

| Assignment | Description | Prerequisites |
|---|---|---|
| assignment-1 | ClusterIP Services | ClusterIP service type (default, internal access), service selectors and label matching, Endpoints and EndpointSlices, service creation (imperative vs declarative), service discovery via environment variables, headless services (ClusterIP: None) | pods/assignment-7 |
| assignment-2 | External Service Types | NodePort services (external access on static port), NodePort port allocation and kube-proxy behavior, LoadBalancer services (cloud provider integration), LoadBalancer vs NodePort in kind clusters, ExternalName services (DNS CNAME mapping), services without selectors (manual endpoint management) | services/assignment-1 |
| assignment-3 | Service Patterns and Troubleshooting | Multi-port services, session affinity (ClientIP), service topology and traffic policies, troubleshooting empty endpoints, troubleshooting selector mismatches, service readiness and endpoint removal | services/assignment-2 |

## Scope Boundaries

This topic covers the Service resource. The following related areas are handled by other topics:

- **CoreDNS** (DNS-based service discovery in depth, service DNS format): covered in `coredns/`
- **Ingress and Gateway API** (L7 routing to backend services): covered in `ingress-and-gateway-api/`
- **Network Policies** (controlling which pods can reach a service): covered in `network-policies/`
- **Service selector mismatches in cross-domain troubleshooting**: covered in `troubleshooting/assignment-1` and `troubleshooting/assignment-4`

Assignment-1 focuses on internal ClusterIP services. Assignment-2 focuses on external service types. Assignment-3 focuses on advanced patterns and debugging.

## Cluster Requirements

Multi-node kind cluster for all three assignments. NodePort exercises need multiple nodes to demonstrate external access patterns. LoadBalancer exercises in assignment-2 will be conceptual or use a lightweight LoadBalancer implementation (like metallb) since kind does not natively provision external load balancers.

## Recommended Order

1. Complete `pods/assignment-7` (Workload Controllers) first, since services need Deployments as backends for realistic exercises
2. Work through assignments 1, 2, 3 sequentially
3. Assignment-2 assumes understanding of ClusterIP services and endpoint mechanics from assignment-1
4. Assignment-3 assumes understanding of all service types from assignments 1 and 2
5. Complete this series before `coredns`, `ingress-and-gateway-api`, and `network-policies` (they all build on service fundamentals)
