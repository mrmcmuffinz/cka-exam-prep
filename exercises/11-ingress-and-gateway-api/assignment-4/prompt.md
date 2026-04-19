# Prompt: Advanced Gateway API Routing with NGINX Gateway Fabric (assignment-4)

## Header

- **Series:** Ingress and Gateway API (4 of 5)
- **CKA domain:** Services & Networking (20%)
- **Competencies covered:** Use the Gateway API to manage Ingress traffic (advanced routing patterns); demonstrate that Gateway API is universal across implementations
- **Course sections referenced:** S9 (lectures 238-240, Gateway API)
- **Prerequisites:** `11-ingress-and-gateway-api/assignment-3` (Gateway API fundamentals with Envoy Gateway)

## Scope declaration

### In scope for this assignment

*NGINX Gateway Fabric as the implementation*
- Installing NGINX Gateway Fabric v2.5.1 via Helm (see the tutorial for the exact install command)
- NGINX Gateway Fabric's GatewayClass name (`nginx` by default)
- Running NGINX Gateway Fabric alongside Envoy Gateway (from assignment-3) to reinforce that the same Gateway/HTTPRoute YAML works across implementations

*Advanced HTTPRoute matching*
- Header-based matching (`matches[].headers[]` with `type: Exact` or `RegularExpression`)
- Query parameter matching (`matches[].queryParams[]`)
- Method matching (`matches[].method`)
- Combined match conditions (all matches in one rule must hold)

*Traffic splitting and weighted routing*
- `backendRefs[].weight` for percentage-based splitting
- Canary deployment pattern via weighted backends
- Blue/green pattern via rapid weight flip

*Request and response filters*
- `filters[]` in HTTPRoute rules
- `RequestHeaderModifier` (add, set, remove headers)
- `RequestRedirect` (status code, scheme, hostname, port, path)
- `URLRewrite` (prefix replacement, full replacement)
- `ResponseHeaderModifier` (add, set, remove response headers)

*Observing NGINX Gateway Fabric's translation*
- Viewing the generated NGINX config (inside the controller pod at `/etc/nginx/conf.d/`)
- Understanding how Gateway API HTTPRoutes map to NGINX server and location blocks
- Debugging when the translation does not produce the expected behavior

*Advanced diagnostic workflow*
- HTTPRoute rule ordering semantics (more specific matches take precedence)
- Diagnosing header-match failures (case-insensitivity on header names, case-sensitivity on values)
- Verifying traffic split percentages with repeated requests and response grouping

### Out of scope (covered in other assignments, do not include)

- Gateway API fundamentals (GatewayClass, Gateway, HTTPRoute structure): covered in assignment-3
- Ingress v1 API: covered in assignments 1 and 2
- Migration from Ingress to Gateway API: covered in assignment-5
- TLS termination at the Gateway level: in scope at a basic level, deep TLS work (including SNI across multiple certificates) is out of scope for the 2026 CKA curriculum
- Custom filters beyond the built-in set: out of CKA scope
- NGINX-specific features via `NginxProxy` custom resource: out of scope; the assignment focuses on upstream Gateway API conformance

## Environment requirements

- Multi-node kind cluster with extraPortMappings for 80 and 443
- Gateway API CRDs v1.5.1 installed per `docs/cluster-setup.md#gateway-api-crds` (installed once per cluster; can be shared with assignment-3's Envoy Gateway)
- NGINX Gateway Fabric v2.5.1 installed via Helm; Envoy Gateway from assignment-3 may remain installed for same-cluster comparison exercises

## Resource gate

All CKA resources are in scope. Exercises primarily use GatewayClass, Gateway, HTTPRoute, Service, Deployment, and Pod. Some exercises use multiple backend Deployments to demonstrate weighted routing and canary patterns.

## Topic-specific conventions

- Every traffic-splitting exercise must include a verification script that sends many requests and counts responses by backend, to make the weight distribution empirically observable.
- Header-match exercises must include both the positive case (matching header) and negative case (missing or wrong header) in the same exercise's verification.
- The tutorial must include at least one worked example showing the same HTTPRoute YAML applied under both Envoy Gateway and NGINX Gateway Fabric, with side-by-side verification, to reinforce the implementation-agnostic lesson.
- Debugging exercises should include at least one scenario where a filter is applied in the wrong order or with the wrong type, producing a response that looks correct on first glance but fails a specific verification check.
- Cleanup must uninstall only the assignment's GatewayClass, Gateway, and HTTPRoute resources (not the controller itself, which is shared with assignment-5 if that assignment follows).

## Cross-references

**Prerequisites (must be completed first):**
- `exercises/11-11-ingress-and-gateway-api/assignment-3`: Gateway API fundamentals with Envoy Gateway

**Adjacent topics:**
- `exercises/11-11-ingress-and-gateway-api/assignment-5`: migration from Ingress to Gateway API

**Forward references:**
- `exercises/19-19-troubleshooting/assignment-4`: network troubleshooting including Gateway API failure scenarios
