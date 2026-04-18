# Prompt: Gateway API Fundamentals with Envoy Gateway (assignment-3)

## Header

- **Series:** Ingress and Gateway API (3 of 5)
- **CKA domain:** Services & Networking (20%)
- **Competencies covered:** Use the Gateway API to manage Ingress traffic (primary emphasis of the 2026 CKA exam)
- **Course sections referenced:** S9 (lectures 238-240, Gateway API)
- **Prerequisites:** `services/assignment-1`, `ingress-and-gateway-api/assignment-2` recommended (for the Ingress-vs-Gateway contrast)

## Scope declaration

### In scope for this assignment

*Gateway API resources*
- `apiVersion: gateway.networking.k8s.io/v1`, `kind: GatewayClass`
- `apiVersion: gateway.networking.k8s.io/v1`, `kind: Gateway`
- `apiVersion: gateway.networking.k8s.io/v1`, `kind: HTTPRoute`
- `apiVersion: gateway.networking.k8s.io/v1beta1`, `kind: ReferenceGrant` (cross-namespace references)

*Role separation (the persona model)*
- GatewayClass typically owned by the cluster operator
- Gateway owned by the platform/application owner
- HTTPRoute owned by the application team
- Why this separation matters (and how it differs from the single-resource Ingress model)

*Envoy Gateway as the implementation*
- Installing Envoy Gateway v1.7.2 via Helm (see the tutorial for the exact install command)
- Envoy Gateway's default GatewayClass name
- Verifying the Gateway API CRDs are installed (`docs/cluster-setup.md#gateway-api-crds`)

*Gateway spec*
- `spec.gatewayClassName` linking to a GatewayClass
- `spec.listeners[]` with `protocol`, `port`, `hostname`, `allowedRoutes`
- `spec.listeners[].allowedRoutes.namespaces.from` (same, selector, all)
- Gateway status fields (`status.addresses`, `status.listeners[].conditions`)

*HTTPRoute spec*
- `spec.parentRefs[]` attaching the route to one or more Gateways
- `spec.hostnames[]` for host-based routing
- `spec.rules[]` with `matches`, `filters`, `backendRefs`
- Match types: path (with `type: PathPrefix` or `Exact`), method
- `backendRefs[]` with `name`, `port`, `weight`

*Per-path routing*
- Multiple `rules[]` on one HTTPRoute routing different paths to different Services
- Route conflict resolution (more specific match wins)

*Status and condition reading*
- `kubectl get gateway` shows ready status
- `kubectl get httproute` shows parent acceptance status
- Reading `status.conditions[]` on both resources

*Basic diagnostic workflow*
- HTTPRoute stuck in `Accepted: False` because of namespace restrictions on the Gateway
- Gateway listener without a matching route (no 404, traffic just drops)
- Envoy Gateway configuration translation failures (visible in controller logs)

### Out of scope (covered in other assignments, do not include)

- Advanced Gateway API features (header/query matching, traffic splitting, filters): covered in assignment-4 with NGINX Gateway Fabric
- Ingress API resources: covered in assignments 1 and 2
- Migration from Ingress to Gateway API: covered in assignment-5
- Experimental Gateway API routes (TCPRoute, TLSRoute, UDPRoute, GRPCRoute): out of CKA scope for 2026
- Service mesh features available through Gateway API (Istio's extensions, for example): out of CKA scope

## Environment requirements

- Multi-node kind cluster with extraPortMappings for 80 and 443
- Gateway API CRDs v1.5.1 installed per `docs/cluster-setup.md#gateway-api-crds`
- Envoy Gateway v1.7.2 installed via its Helm chart
- Previous Ingress controllers from assignments 1 and 2 are optional; the assignment focuses on Gateway API alone

## Resource gate

All CKA resources are in scope. Exercises primarily use GatewayClass, Gateway, HTTPRoute, Service, Deployment, Pod, and optionally ReferenceGrant for cross-namespace exercises.

## Topic-specific conventions

- Every Gateway exercise must create a matching HTTPRoute. A Gateway without any routes attached is a common source of confusion and should be explained explicitly in the tutorial.
- Verification of HTTPRoute attachment: `kubectl get httproute <name> -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'` should return `True`.
- The tutorial must explicitly contrast the three-resource Gateway API model against the single-resource Ingress model, using side-by-side YAML examples.
- Persona separation exercises should use different namespaces for GatewayClass/Gateway (cluster-infra namespace) and HTTPRoute (application namespace), with `ReferenceGrant` where needed.
- Debugging exercises must include at least one scenario involving `allowedRoutes.namespaces` misconfiguration (a valid HTTPRoute that cannot attach because of namespace restriction).

## Cross-references

**Prerequisites (must be completed first):**
- `exercises/services/assignment-1`: Services are the backends for HTTPRoute
- `exercises/ingress-and-gateway-api/assignment-2` (recommended, not strict): provides the Ingress-API context for appreciating Gateway API improvements

**Adjacent topics:**
- `exercises/ingress-and-gateway-api/assignment-4`: advanced Gateway API routing with NGINX Gateway Fabric
- `exercises/ingress-and-gateway-api/assignment-5`: migration from Ingress to Gateway API

**Forward references:**
- `exercises/troubleshooting/assignment-4`: network troubleshooting including Gateway API failures
