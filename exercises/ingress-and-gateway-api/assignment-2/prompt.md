# Prompt: Advanced Ingress and TLS with HAProxy Ingress (assignment-2)

## Header

- **Series:** Ingress and Gateway API (2 of 5)
- **CKA domain:** Services & Networking (20%)
- **Competencies covered:** Know how to use Ingress controllers and Ingress resources, with emphasis on annotations, rewrite rules, and TLS termination; demonstrate that the Ingress API is universal across controller implementations
- **Course sections referenced:** S9 (lectures 231-237, Ingress controllers and resources)
- **Prerequisites:** `ingress-and-gateway-api/assignment-1` (Traefik fundamentals), `tls-and-certificates/assignment-1` (certificate creation)

## Scope declaration

### In scope for this assignment

*HAProxy Ingress as the controller*
- Installing HAProxy Kubernetes Ingress Controller v3.2.6 via Helm (see `docs/cluster-setup.md` and the tutorial for the install command)
- HAProxy Ingress's IngressClass name (`haproxy` by default) and how it differs from Traefik's
- Running both Traefik (from assignment-1) and HAProxy Ingress in the same cluster to reinforce that IngressClass scopes ownership

*Annotations and controller-specific extensions*
- Annotation namespace pattern (`haproxy-ingress.github.io/*` for HAProxy Ingress, in contrast to `traefik.ingress.kubernetes.io/*` for Traefik)
- Why annotations are controller-specific and why Gateway API was created to address this
- Common annotations the learner will encounter: rewrite path, SSL redirect, timeout, backend protocol

*Rewrite-target*
- The rewrite-target annotation pattern (and that the exact annotation key differs per controller)
- Path rewrite use cases: stripping a path prefix before forwarding to the backend
- Debugging a rewrite rule that does not produce the expected backend URL

*TLS termination*
- `spec.tls[]` structure on the Ingress resource
- `hosts[]` and `secretName` pairing
- Creating a TLS Secret with `kubectl create secret tls`
- Self-signed certificate for the exercise (produced with `openssl` per the TLS fundamentals assignment)
- Verifying TLS termination with `curl -k --resolve <host>:443:127.0.0.1` or similar

*Multi-host and multi-path rules*
- Single Ingress with multiple `rules[]` entries (different hosts)
- Single Ingress with multiple `paths[]` under one host
- `pathType` interactions between `Prefix` and `Exact` when rules overlap

*Default backend configuration*
- `spec.defaultBackend` for traffic that matches no rule
- Use case: a catch-all 404 page or health check response

*Diagnostic workflow*
- Reading controller logs (`kubectl logs -n <ns> <haproxy-pod>`) for rejected configurations
- Reading `kubectl describe ingress` for the list of resolved backends and any warnings
- Distinguishing between controller-side failures (syntax error in annotation) and backend failures (Service has no endpoints)

### Out of scope (covered in other assignments, do not include)

- Ingress API fundamentals: covered in assignment-1
- Gateway API resources: covered in assignments 3 and 4
- Migration from Ingress to Gateway API: covered in assignment-5
- Detailed certificate creation with openssl: covered in `tls-and-certificates/assignment-1` (this assignment consumes the certs but does not reteach creation)
- Certificate rotation and expiry troubleshooting: covered in `tls-and-certificates/assignment-3`
- Advanced HAProxy-specific features beyond common Ingress annotations (TCP/UDP services, ModSecurity, etc.): out of CKA scope

## Environment requirements

- Multi-node kind cluster with extraPortMappings for 80 and 443 per `docs/cluster-setup.md#multi-node-kind-cluster`
- Traefik from assignment-1 optionally still installed (some exercises benefit from having both controllers running to see IngressClass selection)
- HAProxy Ingress v3.2.6 installed via Helm

## Resource gate

All CKA resources are in scope. Exercises use Ingress, IngressClass, Service, Deployment, Pod, and Secret (of `kubernetes.io/tls` type).

## Topic-specific conventions

- Every TLS exercise must use a self-signed certificate generated on demand (via `openssl` in the setup block). Do not check-in certificate material.
- `curl -k` is the default for verification since the self-signed certificate will not validate against the default trust store.
- Verification of TLS termination must include both the HTTP response body and the `-v` output showing the TLS handshake completed with the correct host.
- The tutorial must demonstrate the same Ingress YAML (with only the `ingressClassName` changed) working under both Traefik and HAProxy Ingress for basic cases, then show where annotations diverge.
- Debugging exercises must include one scenario where the wrong controller-specific annotation is used (for example, a Traefik annotation on an HAProxy Ingress Ingress) to reinforce the annotation-namespace lesson.

## Cross-references

**Prerequisites (must be completed first):**
- `exercises/ingress-and-gateway-api/assignment-1`: Ingress API fundamentals and Traefik
- `exercises/tls-and-certificates/assignment-1`: certificate creation with openssl

**Adjacent topics:**
- `exercises/ingress-and-gateway-api/assignment-3`: Gateway API, which eliminates controller-specific annotations

**Forward references:**
- `exercises/ingress-and-gateway-api/assignment-5`: migration from Ingress to Gateway API
- `exercises/troubleshooting/assignment-4`: network troubleshooting including Ingress failures
