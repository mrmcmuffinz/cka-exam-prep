# Ingress and Gateway API

**CKA Domain:** Services & Networking (20%)
**Competencies covered:** Use the Gateway API to manage Ingress traffic, know how to
use Ingress controllers and Ingress resources

---

## Why One Assignment

Ingress and Gateway API are two approaches to the same problem: managing external
HTTP(S) traffic routing into the cluster. The CKA tests both, and they share enough
conceptual overlap (routing rules, path matching, TLS termination, backend services)
that separating them would create redundancy. Combined, the material produces roughly
12-14 exercise areas: Ingress resource construction, controller deployment, annotations,
path types, TLS, plus Gateway API resources (GatewayClass, Gateway, HTTPRoute) and
the comparison between the two approaches. This fits within one assignment, though
it will be one of the denser ones in the series.

---

## Assignments

| Assignment | Title | Covers | Prerequisites |
|---|---|---|---|
| assignment-1 | Ingress and Gateway API | Ingress resource spec (rules, paths, backends), Ingress controller deployment (nginx-ingress), annotations and rewrite-target, TLS termination, path types, Gateway API resources (GatewayClass, Gateway, HTTPRoute), Gateway API vs Ingress comparison, traffic routing with HTTPRoute | services/assignment-1 |

## Scope Boundaries

This topic covers L7 traffic routing into the cluster. The following related areas
are handled by other topics:

- **Services** (the backends that Ingress/Gateway routes point to): covered in `services/`
- **CoreDNS** (DNS for ingress hostnames): covered in `coredns/`
- **TLS certificate creation** (creating certs for TLS termination): covered in `tls-and-certificates/`
- **Network Policies** (L3/L4 traffic filtering, not L7 routing): covered in `network-policies/`

## Cluster Requirements

Multi-node kind cluster with an Ingress controller installed. The tutorial must include
nginx-ingress installation instructions for kind, and Gateway API CRD installation if
the kind version does not include them by default.

## Recommended Order

Complete services/assignment-1 first. Ingress and Gateway API route traffic to backend
Services, so understanding service types and selectors is prerequisite knowledge.
