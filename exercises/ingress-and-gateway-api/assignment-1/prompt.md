# Prompt: Ingress API Fundamentals with Traefik (assignment-1)

## Header

- **Series:** Ingress and Gateway API (1 of 5)
- **CKA domain:** Services & Networking (20%)
- **Competencies covered:** Know how to use Ingress controllers and Ingress resources (the Ingress API is frozen but still tested)
- **Course sections referenced:** S9 (lectures 231-237, Ingress controllers and resources)
- **Prerequisites:** `services/assignment-1`

## Scope declaration

### In scope for this assignment

*Ingress v1 API fundamentals*
- `apiVersion: networking.k8s.io/v1`, `kind: Ingress`
- `spec.ingressClassName` (and the relationship to `IngressClass` resources)
- `spec.rules` structure: `host`, `http.paths[]`, each path with `path`, `pathType`, `backend.service`
- `spec.defaultBackend` for unmatched traffic
- Path types: `Prefix`, `Exact`, `ImplementationSpecific` (and what each means in practice)
- Host-based routing with the `host` field
- Ingress status fields (`status.loadBalancer.ingress[]`)

*IngressClass resource*
- `apiVersion: networking.k8s.io/v1`, `kind: IngressClass`
- `spec.controller` identifies which controller watches
- Default IngressClass via annotation `ingressclass.kubernetes.io/is-default-class: "true"`
- How a pod that creates an Ingress without `ingressClassName` gets the default

*Traefik as the controller*
- Installing Traefik v3.6.13 via Helm chart (see `docs/cluster-setup.md` and the tutorial for the exact install command)
- Traefik's `IngressClass` name (`traefik` by default)
- Exposing Traefik via kind's extraPortMappings on ports 80 and 443
- Verifying Traefik is ready with `kubectl get pods -n <traefik-ns>`

*Backend addressing and verification*
- Creating a Deployment and Service that an Ingress routes to
- Testing routing with `curl -H "Host: <hostname>"` against the node's localhost port
- Reading `kubectl describe ingress` to see the backend resolution and any warnings

*Basic troubleshooting*
- Ingress without a matching IngressClass or controller: stuck with no address
- Ingress pointing at a Service that does not exist or has no endpoints
- Path mismatch between Ingress and application (404 response)

### Out of scope (covered in other assignments, do not include)

- Advanced annotations, rewrite-target, TLS termination: covered in assignment-2 with HAProxy Ingress
- Gateway API resources (`Gateway`, `HTTPRoute`): covered in assignments 3 and 4
- Migration tooling (Ingress2Gateway CLI): covered in assignment-5
- NetworkPolicy affecting ingress traffic: covered in `network-policies/`
- DNS resolution for the Ingress hostname: covered in `coredns/` (exercises use `curl -H "Host: ..."` rather than real DNS)

## Environment requirements

- Multi-node kind cluster with extraPortMappings for 80 and 443 per `docs/cluster-setup.md#multi-node-kind-cluster`, with the additional port mappings documented in the tutorial
- Traefik v3.6.13 installed via its official Helm chart (verify against `github.com/traefik/traefik/releases` at generation time)
- No Gateway API CRDs required for this assignment

## Resource gate

All CKA resources are in scope. Exercises primarily use Ingress, IngressClass, Service, Deployment, and Pod resources. ConfigMaps may appear for nginx configuration on backend Deployments.

## Topic-specific conventions

- Every Ingress exercise must create a backend Deployment with at least 2 replicas to make the "routes to any healthy endpoint" behavior observable.
- Verification uses `curl -H "Host: <hostname>" http://localhost/<path>`. Do not assume DNS resolution works for arbitrary hostnames; the Host header simulates resolution.
- The tutorial must compare imperative Ingress creation (`kubectl create ingress`) with declarative YAML, showing why declarative dominates in production.
- Debugging exercises cover the three most common Ingress failures: no IngressClass match (no address assigned), backend not found (404 or 503), and path type mismatch.
- The `ingressClassName` field must be set explicitly in every Ingress exercise. Do not rely on cluster default behavior because it varies across environments.

## Cross-references

**Prerequisites (must be completed first):**
- `exercises/services/assignment-1`: ClusterIP Services are the backends

**Adjacent topics:**
- `exercises/ingress-and-gateway-api/assignment-2`: advanced Ingress patterns with HAProxy Ingress
- `exercises/ingress-and-gateway-api/assignment-3`: Gateway API fundamentals (the modern replacement)

**Forward references:**
- `exercises/ingress-and-gateway-api/assignment-5`: migration from Ingress to Gateway API
