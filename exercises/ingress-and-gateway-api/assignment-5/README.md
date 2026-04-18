# Assignment 5: Migration from Ingress to Gateway API with Ingress2Gateway

This is the fifth and final Ingress and Gateway API assignment. Assignments 1 and 2 covered the Ingress v1 API with Traefik and HAProxy Ingress. Assignments 3 and 4 covered Gateway API with Envoy Gateway and NGINX Gateway Fabric. This assignment covers the migration from Ingress to Gateway API using the `Ingress2Gateway` CLI v1.0.0. The 2026 CKA exam explicitly tests migration knowledge per candidate reports, and this assignment is the capstone for the series.

## Files

| File | Purpose |
|---|---|
| `prompt.md` | The generation prompt |
| `README.md` | This overview |
| `ingress-and-gateway-api-tutorial.md` | Step-by-step tutorial teaching the Ingress2Gateway CLI and the migration workflow |
| `ingress-and-gateway-api-homework.md` | 15 progressive exercises across five difficulty levels |
| `ingress-and-gateway-api-homework-answers.md` | Complete solutions with diagnostic reasoning and common mistakes |

## Recommended Workflow

Work through the tutorial first. It installs the `ingress2gateway` CLI v1.0.0, walks through the translation for progressively complex Ingress resources (basic routing, path types, TLS, annotations, default backend), and frames the three-step migration workflow: (1) generate Gateway API YAML with the CLI, (2) review and adjust manually where annotations do not translate cleanly, (3) apply and cut over. The tutorial uses the Traefik install from assignment 1 and the Envoy Gateway install from assignment 3 side by side, so you can apply the original Ingress, then the generated Gateway API resources, and verify both routes serve equivalent traffic before cutting over.

## Difficulty Progression

Level 1 is CLI familiarity: install the binary, translate simple Ingresses, read the output. Level 2 covers path-type translation (Prefix -> PathPrefix, Exact -> Exact), host translation, and the `defaultBackend` -> catch-all HTTPRoute pattern. Level 3 is debugging translation gaps: rewrite-target annotations, controller-specific annotations that do not translate, TLS with SNI. Level 4 is side-by-side running: apply both the Ingress and the Gateway API equivalent, route a percentage to each, verify parity. Level 5 is comprehensive migration scenarios: a multi-host production Ingress with TLS, a compound failure where the CLI output needs manual adjustment, and a rollback scenario.

## Prerequisites

Complete `exercises/ingress-and-gateway-api/assignment-1` (Traefik install required for Ingress-side testing) and `exercises/ingress-and-gateway-api/assignment-3` (Envoy Gateway install required for Gateway-API-side testing). Complete assignments 2 and 4 as well for the annotation and advanced-routing material referenced in Level 3 and Level 5 exercises. The `ingress2gateway` CLI is a standalone Go binary installed locally on the host, not in the cluster.

## Cluster Requirements

The same multi-node kind cluster from earlier assignments. Traefik from assignment 1 must be installed (the Ingress side of the migration); Envoy Gateway from assignment 3 must be installed (the Gateway API side). Gateway API CRDs v1.5.1 must be installed. See `docs/cluster-setup.md#multi-node-kind-cluster` and `docs/cluster-setup.md#gateway-api-crds`. The Ingress2Gateway CLI v1.0.0 is installed on the host from GitHub releases (`github.com/kubernetes-sigs/ingress2gateway/releases/tag/v1.0.0`).

## Estimated Time Commitment

The tutorial takes 60 to 90 minutes. The 15 exercises together take four to six hours. Levels 1 and 2 run 15 to 20 minutes per exercise (mostly running the CLI and diffing output); Level 3 debugging runs 20 to 30 minutes because identifying what does not translate requires reading the generated YAML carefully; Level 4 side-by-side verification runs 25 to 35 minutes per exercise; Level 5 comprehensive migrations run 35 to 50 minutes per exercise.

## Scope Boundary and What Comes Next

This assignment is the terminal assignment for the ingress-and-gateway-api series. Its scope is the migration workflow specifically; deep Gateway API patterns are covered in assignments 3 and 4. Ingress fundamentals and TLS are in assignments 1 and 2. Network policy that affects migration traffic is `exercises/network-policies/`. The 2026 CKA exam is expected to include migration content directly; candidate reports confirm the exam asks learners to translate Ingress YAML to Gateway API resources and reason about what does not translate cleanly.

## Key Takeaways After Completing This Assignment

After finishing all 15 exercises you should be able to install the `ingress2gateway` CLI v1.0.0 and confirm the version, run `ingress2gateway print --input-file=<ingress.yaml>` and read the generated Gateway API YAML, translate an Ingress spec mentally (host -> `hostnames`, path -> `matches[].path`, `pathType: Prefix` -> `path.type: PathPrefix`, backend -> `backendRefs[]`, `tls[]` -> Gateway listener `tls` plus HTTPRoute), identify which annotations the CLI drops with a warning and plan the manual translation (rewrite-target becomes `URLRewrite` filter; ssl-redirect becomes a separate `RequestRedirect` route; rate-limit becomes implementation-specific so no automatic translation), apply both the original Ingress and the translated Gateway API resources in parallel and verify identical HTTP responses, choose a cutover strategy (DNS-based, weight-based with overlap, or percentage-based through an L4 load balancer), roll back a partial migration cleanly, and explain why `Ingress2Gateway` is a translation tool and not an end-to-end migrator (the annotation gap and controller-specific extensions require human judgment).
