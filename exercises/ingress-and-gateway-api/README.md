# Ingress and Gateway API

**CKA Domain:** Services & Networking (20%)
**Competencies covered:** Use the Gateway API to manage Ingress traffic, know how to use Ingress controllers and Ingress resources

---

## Rationale for Number of Assignments

Ingress and Gateway API are complementary approaches to L7 traffic routing into the cluster. The material encompasses Ingress resource construction, controller deployment, annotations and rewrite rules, TLS termination, Gateway API resources (GatewayClass, Gateway, HTTPRoute), and the comparison between approaches. This produces roughly 16-18 distinct subtopics. The material splits naturally into three focused progressions: Ingress fundamentals with controller setup, advanced Ingress patterns with TLS, and Gateway API resources with routing strategies. Each assignment delivers 5-6 subtopics at depth, building from basic HTTP routing through secure TLS termination to next-generation Gateway API patterns.

---

## Assignment Summary

| Assignment | Description | Prerequisites |
|---|---|---|
| assignment-1 | Ingress Fundamentals | Ingress resource spec (rules, paths, backends, defaultBackend), Ingress controller deployment (nginx-ingress), path types (Prefix, Exact, ImplementationSpecific), host-based routing, Ingress creation and verification, basic troubleshooting (backend not found) | services/assignment-1 |
| assignment-2 | Advanced Ingress and TLS | Ingress annotations and rewrite-target, TLS termination with Ingress, certificate management for Ingress, multi-host and multi-path rules, default backend configuration, Ingress controller customization | ingress-and-gateway-api/assignment-1 |
| assignment-3 | Gateway API | Gateway API resources (GatewayClass, Gateway, HTTPRoute), Gateway API vs Ingress comparison, traffic routing with HTTPRoute, header-based routing, Gateway API path matching, Gateway API troubleshooting | ingress-and-gateway-api/assignment-2 |

## Scope Boundaries

This topic covers L7 traffic routing into the cluster. The following related areas are handled by other topics:

- **Services** (the backends that Ingress/Gateway routes point to): covered in `services/`
- **CoreDNS** (DNS for ingress hostnames): covered in `coredns/`
- **TLS certificate creation** (creating certs for TLS termination): covered in `tls-and-certificates/`
- **Network Policies** (L3/L4 traffic filtering, not L7 routing): covered in `network-policies/`

Assignment-1 focuses on basic Ingress resources and controllers. Assignment-2 focuses on advanced Ingress patterns with TLS. Assignment-3 focuses on Gateway API as the next-generation approach.

## Cluster Requirements

Multi-node kind cluster for all three assignments. Assignment-1 tutorial must include nginx-ingress installation instructions for kind. Assignment-3 requires Gateway API CRD installation if the kind version does not include them by default.

## Recommended Order

1. Complete `services/assignment-1` first (Ingress and Gateway API route traffic to backend Services)
2. Work through assignments 1, 2, 3 sequentially
3. Assignment-2 assumes understanding of basic Ingress mechanics from assignment-1
4. Assignment-3 assumes understanding of Ingress patterns from assignments 1 and 2, providing context for Gateway API improvements
