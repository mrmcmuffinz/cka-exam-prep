# Prompt: Migration from Ingress to Gateway API (assignment-5)

## Header

- **Series:** Ingress and Gateway API (5 of 5)
- **CKA domain:** Services & Networking (20%)
- **Competencies covered:** Migration from Ingress to Gateway API (explicit 2026 CKA exam content per candidate reports)
- **Course sections referenced:** S9 (lectures 231-240, Ingress and Gateway API)
- **Prerequisites:** `11-ingress-and-gateway-api/assignment-1` (Ingress API with Traefik) and `11-ingress-and-gateway-api/assignment-3` (Gateway API with Envoy Gateway); both sets of installs are reused in this assignment

## Scope declaration

### In scope for this assignment

*Context for the migration*
- The Ingress API is frozen (no new features will be added)
- Kubernetes officially recommends Gateway API for new work
- ingress-nginx is retired as of March 2026 (per the Kubernetes Steering Committee statement of 2026-01-29)
- Gateway API is a superset of Ingress functionality; most Ingress resources can be expressed as Gateway API equivalents

*The Ingress2Gateway CLI*
- Installing the `ingress2gateway` binary (version v1.0.0, released 2026-03-20 per `github.com/kubernetes-sigs/ingress2gateway/releases`)
- Usage: `ingress2gateway print --input-file=<yaml>` and `ingress2gateway print --providers=<list>`
- Supported input sources: ingress-nginx, Kong, Istio, Traefik (via provider flags)
- Reading the generated Gateway API YAML (GatewayClass, Gateway, HTTPRoute)

*Mapping Ingress concepts to Gateway API*
- Ingress `spec.rules[].host` to Gateway listener `hostname` and HTTPRoute `hostnames[]`
- Ingress `pathType: Prefix` to HTTPRoute `matches[].path.type: PathPrefix`
- Ingress `pathType: Exact` to HTTPRoute `matches[].path.type: Exact`
- Ingress `tls[]` to Gateway listener `tls` configuration
- Ingress `defaultBackend` to an HTTPRoute with no match conditions
- Common annotations that have Gateway API equivalents (rewrite, redirect)

*Annotations that do not translate cleanly*
- Controller-specific annotations that map to implementation-specific Gateway API extensions or are best dropped
- Ingress2Gateway's behavior when an annotation has no Gateway API equivalent (it is skipped with a warning)
- When manual migration is necessary

*Side-by-side running during migration*
- Running an Ingress controller and a Gateway API implementation in the same cluster
- Routing a subset of hostnames to Gateway API while the rest remain on Ingress
- Cutover strategies (DNS-based, weight-based, percentage-based)
- Validating both routes return the same response before cutting over

*Diagnostic workflow for migration problems*
- Verifying the generated Gateway API resources produce the same routing behavior as the source Ingress (use curl to compare responses from both ingress points)
- Identifying Ingress features with no Gateway API equivalent
- Rolling back a partial migration

### Out of scope (covered in other assignments, do not include)

- Ingress API fundamentals: covered in assignment-1
- Advanced Ingress patterns and TLS: covered in assignment-2
- Gateway API fundamentals: covered in assignment-3
- Advanced Gateway API routing: covered in assignment-4
- Deep custom migration for service-mesh integrations (Istio, Linkerd): out of CKA scope
- Writing bespoke migration tooling in Go or similar: out of scope (the exam tests the CLI, not authoring)

## Environment requirements

- Multi-node kind cluster from assignment-1 still in place (Traefik installed)
- Envoy Gateway from assignment-3 still installed (or reinstalled)
- Gateway API CRDs v1.5.1 installed per `docs/cluster-setup.md#gateway-api-crds`
- `ingress2gateway` CLI v1.0.0 installed on the host (Linux amd64 binary from the GitHub release; verify against `github.com/kubernetes-sigs/ingress2gateway/releases`)

## Resource gate

All CKA resources are in scope. The assignment uses the Ingress, IngressClass, GatewayClass, Gateway, HTTPRoute, Service, Deployment, Secret, and Pod resources extensively. Some exercises compare Ingress and Gateway API resources side-by-side.

## Topic-specific conventions

- Every migration exercise must have a "before" state (an Ingress) and an "after" state (the equivalent Gateway API resources), and a verification step that confirms both produce the same HTTP responses for the same inputs.
- When showing CLI usage, capture both the command and its actual output; do not describe output in abstract terms.
- Debugging exercises must include at least one scenario where a feature does not translate cleanly (for example, a `rewrite-target` annotation that requires manual recreation as a Gateway API `URLRewrite` filter).
- The tutorial must teach the migration as a three-step workflow: (1) generate Gateway API YAML with ingress2gateway, (2) review and adjust the output, (3) apply and cut over.
- Every exercise that creates Gateway API resources must attach them to a Gateway that already exists (created in the setup) rather than requiring the learner to provision new gateways during the exercise. The focus is migration, not Gateway API provisioning.

## Cross-references

**Prerequisites (must be completed first):**
- `exercises/11-11-ingress-and-gateway-api/assignment-1`: Ingress API fundamentals and Traefik install
- `exercises/11-11-ingress-and-gateway-api/assignment-3`: Gateway API fundamentals and Envoy Gateway install

**Adjacent topics:**
- None at this level; this is the terminal assignment for the ingress-and-gateway-api series

**Forward references:**
- `exercises/19-19-troubleshooting/assignment-4`: network troubleshooting includes migration-related failure modes
