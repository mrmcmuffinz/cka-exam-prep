# Ingress and Gateway API

**CKA Domain:** Services & Networking (20%)
**Competencies covered:** Use the Gateway API to manage Ingress traffic (primary emphasis), know how to use Ingress controllers and Ingress resources

---

## Rationale for Number of Assignments

This topic was restructured on 2026-04-18 to reflect two changes in the Kubernetes ecosystem. First, the Ingress API was officially frozen, with Gateway API promoted as the modern replacement; the CKA allowed documentation set now includes `gateway-api.sigs.k8s.io/` as a dedicated URL while no longer listing the NGINX Ingress Controller documentation (which moved to the CKS exam only). Second, the ingress-nginx project is retiring in March 2026, along with its intended successor InGate. For details of the rationale, see `docs/remediation-plan.md` decision D8 and the January 2026 Kubernetes Steering Committee statement.

The five-assignment structure is deliberate. Learners gain breadth across multiple actively-maintained implementations rather than depth in any single one, which aligns with the reality that the CKA exam tests the API spec rather than a specific controller. Assignments 1 and 2 cover the frozen Ingress v1 API with two different controllers, reinforcing that the API is universal. Assignments 3 and 4 cover Gateway API with two different implementations for the same reason. Assignment 5 covers the migration from Ingress to Gateway API, which the 2026 CKA exam tests explicitly.

The total subtopic count across the five assignments is approximately 28, well within the 2-3 exercises per subtopic ratio targeted by the 15-exercise assignment format.

---

## Assignment Summary

| Assignment | API | Controller | Focus | Prerequisites |
|---|---|---|---|---|
| assignment-1 | Ingress v1 | Traefik | Ingress API fundamentals (rules, paths, backends, path types, host-based routing, IngressClass) | `services/assignment-1` |
| assignment-2 | Ingress v1 | HAProxy Ingress | Advanced Ingress patterns with a second implementation (annotations, rewrite-target, TLS termination, multi-host and multi-path rules, default backends) | assignment-1 |
| assignment-3 | Gateway API | Envoy Gateway | Gateway API fundamentals (GatewayClass, Gateway, HTTPRoute, ReferenceGrant, per-path routing) | `services/assignment-1`, assignment-2 recommended |
| assignment-4 | Gateway API | NGINX Gateway Fabric | Advanced Gateway API routing with a second implementation (header and query-parameter matching, traffic splitting via weighted HTTPRoute backends, request/response filters) | assignment-3 |
| assignment-5 | Both | Uses installations from assignments 1 and 3; introduces the `Ingress2Gateway` CLI | Migration from Ingress to Gateway API (translating Ingress resources, gap analysis, side-by-side running during migration) | assignments 1 and 3 |

## Scope Boundaries

This topic covers L7 traffic routing into the cluster. The following related areas are handled by other topics.

- **Services** (the backends that Ingress and HTTPRoute point to): covered in `services/`
- **CoreDNS** (DNS for ingress hostnames): covered in `coredns/`
- **TLS certificate creation** (creating certs for TLS termination, as opposed to consuming them): covered in `tls-and-certificates/`
- **Network Policies** (L3/L4 traffic filtering, not L7 routing): covered in `network-policies/`

Assignments 1 and 2 focus on the Ingress v1 API across two controllers. Assignments 3 and 4 focus on the Gateway API across two implementations. Assignment 5 focuses specifically on migration and is the only place the `Ingress2Gateway` CLI appears.

## Cluster Requirements

Multi-node kind cluster for all five assignments, with kind's extraPortMappings for ports 80 and 443 so that ingress traffic from the host reaches the controller. Each assignment installs a different controller; the tutorial for each assignment documents the controller install. See `docs/cluster-setup.md#multi-node-kind-cluster` for the base cluster and `docs/cluster-setup.md#gateway-api-crds` for the Gateway API CRD install that assignments 3 through 5 need.

Gateway API CRDs must be installed before any controller that consumes them. CRDs are installed once per cluster and shared across all Gateway API implementations.

## Recommended Order

1. Complete `services/assignment-1` first. Ingress and Gateway API route traffic to backend Services, which must be understood first.
2. Work through assignments 1 through 5 in order. Each builds on the vocabulary of the previous assignment.
3. Assignment 5 requires that assignments 1 and 3 have been completed because it uses the Traefik and Envoy Gateway installations from those assignments to demonstrate side-by-side running during migration.

## Controller Versions

Each controller is pinned per assignment in the tutorial file of that assignment. The docs/cluster-setup.md version matrix tracks the pinned versions centrally. As of the 2026-04-18 scoping:

| Assignment | Controller | Pinned Version |
|---|---|---|
| assignment-1 | Traefik | v3.6.13 (verified against `github.com/traefik/traefik/releases`) |
| assignment-2 | HAProxy Ingress | v3.2.6 (verified against `github.com/haproxytech/kubernetes-ingress/releases`) |
| assignment-3 | Envoy Gateway | v1.7.2 (verified against `github.com/envoyproxy/gateway/releases`) |
| assignment-4 | NGINX Gateway Fabric | v2.5.1 (verified against `github.com/nginx/nginx-gateway-fabric/releases`) |
| assignment-5 | Ingress2Gateway CLI | v1.0.0 (verified against `github.com/kubernetes-sigs/ingress2gateway/releases`) |

Version verification date: 2026-04-18. Before generating content, re-verify each version against the upstream project per decision D7 in `docs/remediation-plan.md`.

---

## Current Status

All five ingress assignments are content-complete as of 2026-04-18. Phase 3 produced the topic scope and the five `prompt.md` files on 2026-04-18; Phase 4 content regeneration produced the four content files per assignment on 2026-04-18 (P4.9 through P4.13 in `docs/remediation-plan.md`). Each assignment uses its pinned per-assignment controller: Traefik v3.6.13 for assignment-1, HAProxy Ingress v3.2.6 for assignment-2, Envoy Gateway v1.7.2 for assignment-3, NGINX Gateway Fabric v2.5.1 for assignment-4, and the Ingress2Gateway CLI v1.0.0 plus reused Traefik + Envoy Gateway installs for assignment-5. The previous transitional `ingress-nginx controller-v1.15.1` pin is no longer referenced by any content file.
