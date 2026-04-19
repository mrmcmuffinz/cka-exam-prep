# Assignment 3: Gateway API Fundamentals with Envoy Gateway

This is the third of five Ingress and Gateway API assignments and the first to cover Gateway API. Assignments 1 and 2 covered the Ingress v1 API with Traefik and HAProxy Ingress. This assignment moves to the modern replacement: the Gateway API, using Envoy Gateway v1.7.2 as the implementation. Assignment 4 covers advanced Gateway API routing with NGINX Gateway Fabric. Assignment 5 covers Ingress-to-Gateway-API migration using the Ingress2Gateway CLI.

## Files

| File | Purpose |
|---|---|
| `prompt.md` | The generation prompt (input to the homework generator skill) |
| `README.md` | This overview |
| `ingress-and-gateway-api-tutorial.md` | Step-by-step tutorial teaching GatewayClass, Gateway, HTTPRoute, and ReferenceGrant with Envoy Gateway |
| `ingress-and-gateway-api-homework.md` | 15 progressive exercises across five difficulty levels |
| `ingress-and-gateway-api-homework-answers.md` | Complete solutions with diagnostic reasoning and common mistakes |

## Recommended Workflow

Work through the tutorial first. It installs Envoy Gateway v1.7.2 via Helm, confirms its GatewayClass is ready, and walks through each Gateway API resource: GatewayClass (the controller), Gateway (the listener), HTTPRoute (the routing rules), and ReferenceGrant (cross-namespace references). Every spec field is documented with valid values, defaults, and failure modes. The tutorial then builds a full routing example (Gateway in an infra namespace, HTTPRoutes in app namespaces, ReferenceGrant crossing the boundary) that reflects the persona-separated model Gateway API was designed around. The homework exercises each piece.

## Difficulty Progression

Level 1 is Gateway API basics: confirm the installed GatewayClass, create a minimal Gateway, attach one HTTPRoute. Level 2 adds real routing: host-based HTTPRoute, path-based HTTPRoute, multiple backends. Level 3 is debugging: HTTPRoute stuck `Accepted: False` because of namespace restrictions, Gateway without any attached routes, wrong `parentRefs` kind. Level 4 is persona separation with `ReferenceGrant` for cross-namespace use. Level 5 is comprehensive: design a Gateway API platform for a three-team application, debug a compound failure, and produce the Ingress-equivalent side-by-side as preparation for assignment 5's migration material.

## Prerequisites

Complete `exercises/08-08-services/assignment-1` (Services are the backends that HTTPRoute points at). Complete `exercises/11-11-ingress-and-gateway-api/assignment-2` as well; the persistent Ingress-vs-Gateway-API contrast makes the new model much easier to internalize when you have the old one in recent memory. The Gateway API CRDs must be installed on the cluster (see cluster requirements).

## Cluster Requirements

A multi-node kind cluster with extraPortMappings for 80 and 443. See `docs/cluster-setup.md#multi-node-kind-cluster` for the base cluster and `docs/cluster-setup.md#gateway-api-crds` for the Gateway API CRD install. The tutorial walks through the Envoy Gateway install (Helm, v1.7.2). The CRDs are installed once per cluster and can be shared with the NGINX Gateway Fabric install in assignment 4. Traefik and HAProxy Ingress from assignments 1 and 2 can stay installed or be removed; they do not interfere with Gateway API.

## Estimated Time Commitment

The tutorial takes 60 to 90 minutes. The 15 exercises together take four to six hours. Level 1 runs 15 to 20 minutes per exercise; Level 2 runs 20 to 30 minutes; Level 3 debugging runs 20 to 30 minutes per exercise because the Gateway API has four related resources (GatewayClass, Gateway, HTTPRoute, ReferenceGrant) that can all independently be misconfigured; Level 4 runs 25 to 35 minutes; Level 5 runs 35 to 50 minutes per exercise.

## Scope Boundary and What Comes Next

This assignment covers Gateway API fundamentals. Advanced HTTPRoute matching (header, query-param, traffic splitting, filters) is assignment 4. Migration from Ingress is assignment 5. Experimental Gateway API routes (TCPRoute, TLSRoute, UDPRoute, GRPCRoute) are out of 2026 CKA scope. Service mesh features surfaced through Gateway API (Istio extensions) are out of scope. TLS termination for Gateway API at the listener level appears briefly in the tutorial and is covered more thoroughly in assignment 4.

## Key Takeaways After Completing This Assignment

After finishing all 15 exercises you should be able to install Envoy Gateway v1.7.2 via Helm and confirm its default GatewayClass is ready, describe the Gateway API persona model and why it differs from Ingress (three resources owned by three roles rather than one resource owning everything), author a Gateway with `gatewayClassName` and `listeners[]` correctly, attach one or more HTTPRoutes to a Gateway via `parentRefs`, use `spec.hostnames[]` on HTTPRoute and `spec.listeners[*].hostname` on Gateway for host-based routing, use `matches[].path` on HTTPRoute rules with `PathPrefix` and `Exact` types, read the HTTPRoute `status.parents[*].conditions[]` to confirm `Accepted: True`, use `ReferenceGrant` for cross-namespace references (HTTPRoute in namespace A attaching to a Gateway in namespace B, or pointing at a Service in namespace C), diagnose the three most common Gateway API failures (`Accepted: False` from listener restrictions, orphan HTTPRoute with no matching Gateway, HTTPRoute with no backends), and explain why `allowedRoutes` on a Gateway listener is the controlled-attach mechanism that replaces Ingress's "anyone can create an Ingress" model.
