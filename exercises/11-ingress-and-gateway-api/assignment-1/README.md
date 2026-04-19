# Assignment 1: Ingress API Fundamentals with Traefik

This is the first of five Ingress and Gateway API assignments. It covers the Ingress v1 API using Traefik v3.6.13 as the controller. The goal is to build fluency with the API itself (rules, paths, path types, host-based routing, IngressClass) while incidentally learning one specific implementation. Assignment 2 covers advanced Ingress patterns (TLS, annotations, rewrite-target) using HAProxy Ingress, reinforcing that the Ingress API is universal across controllers. Assignments 3 and 4 move to Gateway API with Envoy Gateway and NGINX Gateway Fabric. Assignment 5 walks through the Ingress-to-Gateway-API migration using the Ingress2Gateway CLI.

## Files

| File | Purpose |
|---|---|
| `prompt.md` | The generation prompt (input to the homework generator skill) |
| `README.md` | This overview |
| `ingress-and-gateway-api-tutorial.md` | Step-by-step tutorial teaching Ingress v1 with Traefik v3.6.13 |
| `ingress-and-gateway-api-homework.md` | 15 progressive exercises across five difficulty levels |
| `ingress-and-gateway-api-homework-answers.md` | Complete solutions with diagnostic reasoning and common mistakes |

## Recommended Workflow

Work through the tutorial first. It installs Traefik via its official Helm chart, pins the version to v3.6.13, and confirms the controller is watching Ingresses. Then every field of the Ingress v1 API is walked through with spec documentation: `spec.ingressClassName`, `spec.rules[*].host`, `spec.rules[*].http.paths[*].path`, `spec.rules[*].http.paths[*].pathType`, `spec.rules[*].http.paths[*].backend.service`, and `spec.defaultBackend`. The tutorial builds a two-Service backend and routes to it via a single Ingress with path-based rules, then extends to host-based rules and multiple IngressClass scenarios. The homework then exercises each piece.

## Difficulty Progression

Level 1 is basic Ingress creation: deploy a backend Service, create an Ingress with `pathType: Prefix`, verify with `curl -H "Host: ..."`. Level 2 uses multiple paths and multiple hosts on the same Ingress. Level 3 is debugging: an Ingress with no IngressClass match (stays `<none>`), an Ingress pointing at a non-existent Service (404), and a path-type mismatch. Level 4 is design: `defaultBackend` for catch-all traffic, multiple IngressClasses coexisting with Traefik. Level 5 is comprehensive: multi-Service routing with rule ordering, a debugging scenario with three compounding issues, and a production-style pattern with health-check routing.

## Prerequisites

Complete `exercises/services/assignment-1` (ClusterIP Services are the backends that Ingress points to). The exercises assume you can author a Service and a Deployment; this assignment adds the Ingress resource on top.

## Cluster Requirements

A multi-node kind cluster with extraPortMappings for 80 and 443 so that traffic from the host reaches the Traefik controller. See `docs/cluster-setup.md#multi-node-kind-cluster` for the base cluster and the tutorial for the Traefik install (Helm chart, pinned v3.6.13). Gateway API CRDs are not required for this assignment (they are introduced in assignment 3).

## Estimated Time Commitment

The tutorial takes 60 to 90 minutes because installing Traefik, checking its IngressClass, and producing the first working end-to-end Ingress involves several steps. The 15 exercises together take four to six hours. Level 1 runs 15 to 20 minutes per exercise; Level 2 runs 20 to 30 minutes because multi-host verification is verbose; Level 3 debugging runs 20 to 30 minutes per exercise; Level 4 runs 25 to 35 minutes; Level 5 runs 30 to 45 minutes per exercise.

## Scope Boundary and What Comes Next

This assignment covers Ingress API fundamentals only. Advanced Ingress patterns (TLS, annotations, rewrite-target) are covered in `exercises/ingress-and-gateway-api/assignment-2` with HAProxy Ingress. Gateway API resources (`GatewayClass`, `Gateway`, `HTTPRoute`) are covered in assignments 3 and 4. Migration is covered in assignment 5. Services and their selectors are `exercises/services/`. Network Policies that affect ingress traffic are `exercises/network-policies/`. DNS for the Ingress hostname is `exercises/coredns/`; the exercises use `curl -H "Host: ..."` to simulate DNS rather than configure real resolution.

## Key Takeaways After Completing This Assignment

After finishing all 15 exercises you should be able to install Traefik v3.6.13 via Helm and verify its IngressClass is ready, author an Ingress v1 resource with correct `ingressClassName`, `rules[*].host`, `rules[*].http.paths[*].path`, `rules[*].http.paths[*].pathType`, and `rules[*].http.paths[*].backend.service`, distinguish the three path types (`Prefix`, `Exact`, `ImplementationSpecific`) and predict how each routes, verify an Ingress end to end with `curl -H "Host: ..." http://localhost/<path>` and read the status conditions for binding issues, diagnose the three most common Ingress failures (no IngressClass match, backend not found, path mismatch) from describe output, use `spec.defaultBackend` for unmatched-path catch-all routing, and explain why IngressClass makes multiple controllers coexistable on the same cluster.
