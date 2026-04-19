# Assignment 2: Advanced Ingress and TLS with HAProxy Ingress

This is the second of five Ingress and Gateway API assignments. Assignment 1 covered Ingress v1 fundamentals using Traefik v3.6.13. This assignment covers advanced Ingress patterns, TLS termination, and controller-specific annotation behavior using HAProxy Kubernetes Ingress Controller v3.2.6 as a second implementation. Running both Traefik and HAProxy Ingress in the same cluster reinforces the "IngressClass scopes ownership" lesson. Assignments 3 and 4 move to Gateway API; assignment 5 covers migration.

## Files

| File | Purpose |
|---|---|
| `prompt.md` | The generation prompt (input to the homework generator skill) |
| `README.md` | This overview |
| `ingress-and-gateway-api-tutorial.md` | Step-by-step tutorial teaching HAProxy Ingress, annotations, rewrite-target, TLS |
| `ingress-and-gateway-api-homework.md` | 15 progressive exercises across five difficulty levels |
| `ingress-and-gateway-api-homework-answers.md` | Complete solutions with diagnostic reasoning and common mistakes |

## Recommended Workflow

Work through the tutorial first. It installs HAProxy Ingress v3.2.6 via Helm alongside the Traefik install from assignment 1. Each controller gets its own `IngressClass`, and both watch Ingresses on the same cluster. Then the tutorial walks through annotations (`haproxy-ingress.github.io/*`), rewrite-target, TLS termination via `spec.tls[]` plus a `kubernetes.io/tls`-typed Secret, multi-host and multi-path rules, and a worked example of the same YAML (with only `ingressClassName` changed) working under Traefik and HAProxy to reinforce API universality. The homework then exercises each piece.

## Difficulty Progression

Level 1 is HAProxy basics: deploy an Ingress under the `haproxy` IngressClass, verify routing, read HAProxy controller logs. Level 2 is annotations and rewrite-target: apply a rewrite via an HAProxy annotation, test the path transformation, then switch to a second annotation for response headers. Level 3 is debugging: annotation in the wrong namespace, wrong controller for the annotation (a Traefik annotation on an HAProxy Ingress), TLS Secret missing or empty. Level 4 is TLS termination: create a self-signed certificate with openssl, create the `kubernetes.io/tls` Secret, configure `spec.tls[]`, verify with `curl -k --resolve`. Level 5 is comprehensive: a multi-host TLS configuration, a debugging scenario where annotations from the wrong controller produce a misleading partial-success, and a production pattern with redirect + TLS + rewrite.

## Prerequisites

Complete `exercises/11-11-ingress-and-gateway-api/assignment-1` (Ingress v1 with Traefik) first; this assignment assumes you can author Ingresses, debug routing, and read HAProxy controller logs with the same fluency. Complete `exercises/18-18-tls-and-certificates/assignment-1` (certificate creation with openssl) because the TLS exercises here consume certificates without reteaching their creation in detail.

## Cluster Requirements

A multi-node kind cluster with extraPortMappings for 80 and 443. The same cluster from assignment 1 works; leave Traefik installed so the same-YAML-under-both-controllers examples can run. See `docs/cluster-setup.md#multi-node-kind-cluster` for the base cluster. The tutorial walks through the HAProxy Ingress install (Helm chart, v3.2.6). TLS exercises produce self-signed certificates on the fly via openssl; no external CA is involved.

## Estimated Time Commitment

The tutorial takes 60 to 90 minutes. The 15 exercises together take four to six hours. Levels 1 and 2 run 15 to 25 minutes per exercise; Level 3 debugging runs 20 to 30 minutes per exercise; Level 4 TLS exercises run 25 to 35 minutes per exercise because generating certificates and verifying TLS handshakes adds overhead; Level 5 comprehensive exercises run 35 to 50 minutes per exercise.

## Scope Boundary and What Comes Next

This assignment covers advanced Ingress patterns, TLS, and HAProxy-specific annotations. Gateway API resources are assignment 3. Migration from Ingress to Gateway API is assignment 5. Detailed certificate creation with openssl is `exercises/18-18-tls-and-certificates/assignment-1`. Certificate rotation and expiry troubleshooting are `exercises/18-18-tls-and-certificates/assignment-3`. HAProxy-specific advanced features (TCP/UDP services, ModSecurity) are out of CKA scope.

## Key Takeaways After Completing This Assignment

After finishing all 15 exercises you should be able to install HAProxy Ingress v3.2.6 via Helm and confirm its `haproxy` IngressClass is ready, author an Ingress with `haproxy-ingress.github.io/*` annotations and understand that these differ from Traefik's `traefik.ingress.kubernetes.io/*` annotations, apply a rewrite-target to strip a path prefix before forwarding to the backend, create a TLS Secret from an openssl-generated key and certificate (`kubectl create secret tls`), configure `spec.tls[]` with `hosts` and `secretName` on an Ingress, verify TLS termination with `curl -k -v --resolve`, diagnose the failure mode when a controller-specific annotation is placed on an Ingress from a different IngressClass, run both Traefik and HAProxy Ingress in the same cluster with each owning Ingresses of its own class, and produce a production-style Ingress stack with HTTPS redirect, TLS, and path rewrite in a single Ingress.
