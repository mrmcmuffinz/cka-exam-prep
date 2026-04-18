# Advanced Ingress and TLS Homework Answers

Complete solutions. Level 3 and Level 5 debugging answers use the three-stage structure.

---

## Exercise 1.1 Solution

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: ex-1-1-ing, namespace: ex-1-1}
spec:
  ingressClassName: haproxy
  rules:
  - host: one.example.test
    http:
      paths:
      - {path: /, pathType: Prefix, backend: {service: {name: site, port: {number: 80}}}}
```

HAProxy Ingress watches for Ingresses with `ingressClassName: haproxy`. The request to `localhost:8080` (port-forwarded to HAProxy) with the matching Host header routes through to `site`.

---

## Exercise 1.2 Solution

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-rate-limited
  namespace: ex-1-2
  annotations:
    haproxy-ingress.github.io/rate-limit-rpm: "120"
spec:
  ingressClassName: haproxy
  rules:
  - host: api.example.test
    http:
      paths:
      - {path: /, pathType: Prefix, backend: {service: {name: api, port: {number: 80}}}}
```

The rate-limit annotation is applied at the Ingress level, not per-path. HAProxy compiles it into a rate-limiting rule in its generated config.

---

## Exercise 1.3 Solution

```bash
kubectl logs -n haproxy-ingress -l app.kubernetes.io/name=haproxy-ingress --tail=100 | grep "api-rate-limited"
```

The HAProxy controller pod logs reference Ingresses it picks up via reconcile events. The Ingress name appears in lines like `processing ingress ex-1-2/api-rate-limited`.

---

## Exercise 2.1 Solution

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rewrite
  namespace: ex-2-1
  annotations:
    haproxy-ingress.github.io/rewrite-target: /
spec:
  ingressClassName: haproxy
  rules:
  - host: echo.example.test
    http:
      paths:
      - {path: /strip, pathType: Prefix, backend: {service: {name: echo, port: {number: 80}}}}
```

`rewrite-target: /` strips the matched prefix `/strip` and forwards the rest to the backend as `/`. The echo backend reports whatever path it sees in `$request_uri`; the annotation ensures it sees `/`.

---

## Exercise 2.2 Solution

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: with-headers
  namespace: ex-2-2
  annotations:
    haproxy-ingress.github.io/response-headers: "X-App-Name: example"
spec:
  ingressClassName: haproxy
  rules:
  - host: headers.example.test
    http:
      paths:
      - {path: /, pathType: Prefix, backend: {service: {name: web, port: {number: 80}}}}
```

The annotation injects `X-App-Name: example` into every response.

---

## Exercise 2.3 Solution

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: on-traefik, namespace: ex-2-3}
spec:
  ingressClassName: traefik
  rules:
  - host: both.example.test
    http:
      paths:
      - {path: /, pathType: Prefix, backend: {service: {name: both, port: {number: 80}}}}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: on-haproxy, namespace: ex-2-3}
spec:
  ingressClassName: haproxy
  rules:
  - host: both.example.test
    http:
      paths:
      - {path: /, pathType: Prefix, backend: {service: {name: both, port: {number: 80}}}}
```

Two Ingress resources, identical except for `ingressClassName`. Traefik owns one, HAProxy owns the other. Both respond with the same backend content but on different ports; each controller has its own ADDRESS.

---

## Exercise 3.1 Solution

**Diagnosis.**

```bash
kubectl get ingress -n ex-3-1 wrong-annotation -o jsonpath='{.metadata.annotations}'
curl -s -H "Host: wrong.example.test" http://localhost:8080/wrong/hello
```

Annotation is `traefik.ingress.kubernetes.io/router.middlewares: strip-prefix`. The `ingressClassName` is `haproxy`. HAProxy does not recognize Traefik annotations; the rewrite is not applied. The backend echoes the full path.

**What the bug is and why.** Annotations are namespaced by controller. Traefik's middlewares annotation only works when a Traefik controller interprets it. HAProxy's equivalent is `haproxy-ingress.github.io/rewrite-target`. An annotation intended for Traefik silently has no effect under HAProxy.

**Fix.**

```bash
kubectl annotate ingress -n ex-3-1 wrong-annotation \
  traefik.ingress.kubernetes.io/router.middlewares-
kubectl annotate ingress -n ex-3-1 wrong-annotation \
  "haproxy-ingress.github.io/rewrite-target"=/
```

---

## Exercise 3.2 Solution

**Diagnosis.**

```bash
kubectl get secret -n ex-3-2 wrong-secret -o jsonpath='{.type}'
# Opaque (not kubernetes.io/tls)
```

The Secret is `Opaque` and has `certificate.pem` + `private-key.pem` as keys. HAProxy Ingress expects a Secret of type `kubernetes.io/tls` with keys `tls.crt` and `tls.key`. HAProxy falls back to its default cert, which is not the one we generated.

**What the bug is and why.** Ingress TLS requires a `kubernetes.io/tls`-typed Secret with the precise keys `tls.crt` and `tls.key`. Opaque Secrets with arbitrary key names are not recognized. The controller logs a warning and uses its fallback.

**Fix.** Replace the Secret with a TLS-typed one.

```bash
kubectl delete secret -n ex-3-2 wrong-secret
kubectl create secret tls -n ex-3-2 wrong-secret \
  --cert=/tmp/ex32.crt --key=/tmp/ex32.key
```

The Secret name stays the same (the Ingress references `wrong-secret`); only the type and keys change.

---

## Exercise 3.3 Solution

**Diagnosis.**

```bash
kubectl get ingress -n ex-3-3 stuck
kubectl get ingress -n ex-3-3 stuck -o jsonpath='{.spec.ingressClassName}'
```

ADDRESS is empty; `ingressClassName` is empty string. No controller is watching.

**What the bug is and why.** Without `ingressClassName`, Kubernetes tries to apply the default IngressClass. In this cluster, neither `haproxy` nor `traefik` is annotated as default. The Ingress has no controller and sits idle.

**Fix.**

```bash
kubectl patch ingress -n ex-3-3 stuck -p '{"spec":{"ingressClassName":"haproxy"}}'
```

---

## Exercise 4.1 Solution

```bash
kubectl create secret tls -n ex-4-1 one-tls --cert=/tmp/ex41.crt --key=/tmp/ex41.key

kubectl apply -n ex-4-1 -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: one-secure}
spec:
  ingressClassName: haproxy
  tls:
  - hosts: ["one-tls.example.test"]
    secretName: one-tls
  rules:
  - host: one-tls.example.test
    http: {paths: [{path: /, pathType: Prefix, backend: {service: {name: one, port: {number: 80}}}}]}
EOF
```

TLS termination at the controller. The client sees the cert whose CN is `one-tls.example.test`. `-k` is needed because the cert is self-signed.

---

## Exercise 4.2 Solution

```bash
kubectl create secret tls -n ex-4-2 site-a-tls --cert=/tmp/site-a.crt --key=/tmp/site-a.key
kubectl create secret tls -n ex-4-2 site-b-tls --cert=/tmp/site-b.crt --key=/tmp/site-b.key

kubectl apply -n ex-4-2 -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: multi}
spec:
  ingressClassName: haproxy
  tls:
  - hosts: ["site-a.example.test"]
    secretName: site-a-tls
  - hosts: ["site-b.example.test"]
    secretName: site-b-tls
  rules:
  - host: site-a.example.test
    http: {paths: [{path: /, pathType: Prefix, backend: {service: {name: site-a, port: {number: 80}}}}]}
  - host: site-b.example.test
    http: {paths: [{path: /, pathType: Prefix, backend: {service: {name: site-b, port: {number: 80}}}}]}
EOF
```

SNI tells HAProxy which cert to present for each hostname. The client's `--resolve` header forces the TLS handshake to use the specified hostname.

---

## Exercise 4.3 Solution

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: redir
  namespace: ex-4-3
  annotations:
    haproxy-ingress.github.io/ssl-redirect: "true"
spec:
  ingressClassName: haproxy
  tls:
  - hosts: ["redir.example.test"]
    secretName: redir-tls
  rules:
  - host: redir.example.test
    http: {paths: [{path: /, pathType: Prefix, backend: {service: {name: redirect-me, port: {number: 80}}}}]}
```

HAProxy issues a 301 Moved Permanently when HTTP requests arrive, with Location pointing at the HTTPS equivalent. HTTPS requests terminate TLS and forward to the backend.

---

## Exercise 5.1 Solution

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: production
  namespace: ex-5-1
  annotations:
    haproxy-ingress.github.io/ssl-redirect: "true"
    haproxy-ingress.github.io/rewrite-target: /
spec:
  ingressClassName: haproxy
  tls:
  - hosts: ["production.example.test"]
    secretName: prod-tls
  rules:
  - host: production.example.test
    http: {paths: [{path: /api/v2, pathType: Prefix, backend: {service: {name: api-v2, port: {number: 80}}}}]}
```

Three controls stacked in one Ingress. HTTP -> 301 redirect. HTTPS terminates, rewrites `/api/v2/*` to `/*`, forwards to the backend. The backend reports the rewritten path.

---

## Exercise 5.2 Solution

**Diagnosis.**

```bash
kubectl get ingress -n ex-5-2 multi-issue -o jsonpath='{.metadata.annotations}'
kubectl get secret -n ex-5-2 bad-secret -o jsonpath='{.type}'
kubectl get ingress -n ex-5-2 multi-issue -o jsonpath='{.spec.tls[0].hosts}'
```

Three problems:

- Annotation is `traefik.ingress.kubernetes.io/ssl-redirect`. HAProxy ignores it.
- Secret type is `Opaque`, not `kubernetes.io/tls`. HAProxy does not use its cert.
- `spec.tls[0].hosts` is `[other.example.test]` but the rule is on `five-two.example.test`. HAProxy has no TLS config for the request's host.

**What the bug is and why.** All three are silent failures. The Ingress accepts and has an ADDRESS, but nothing works. The annotation is on the wrong controller. The Secret is not correctly typed. The TLS host list does not match the rule.

**Fix.**

```bash
kubectl annotate ingress -n ex-5-2 multi-issue traefik.ingress.kubernetes.io/ssl-redirect-
kubectl annotate ingress -n ex-5-2 multi-issue "haproxy-ingress.github.io/ssl-redirect"=true --overwrite

kubectl delete secret -n ex-5-2 bad-secret
kubectl create secret tls -n ex-5-2 bad-secret --cert=/tmp/ex52.crt --key=/tmp/ex52.key

kubectl patch ingress -n ex-5-2 multi-issue --type='json' \
  -p='[{"op":"replace","path":"/spec/tls/0/hosts/0","value":"five-two.example.test"}]'
```

---

## Exercise 5.3 Solution

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tenants
  namespace: ex-5-3
  annotations:
    haproxy-ingress.github.io/ssl-redirect: "true"
    haproxy-ingress.github.io/rewrite-target: /
spec:
  ingressClassName: haproxy
  tls:
  - hosts: ["t1.example.test"]
    secretName: t1-tls
  - hosts: ["t2.example.test"]
    secretName: t2-tls
  rules:
  - host: t1.example.test
    http: {paths: [{path: /api, pathType: Prefix, backend: {service: {name: t1-app, port: {number: 80}}}}]}
  - host: t2.example.test
    http: {paths: [{path: /api, pathType: Prefix, backend: {service: {name: t2-app, port: {number: 80}}}}]}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: health, namespace: ex-5-3}
spec:
  ingressClassName: haproxy
  rules:
  - host: status.example.test
    http: {paths: [{path: /healthz, pathType: Exact, backend: {service: {name: health, port: {number: 80}}}}]}
```

Per-tenant TLS via SNI on one Ingress. Health is on a separate Ingress without TLS, demonstrating that HTTP-only paths can coexist alongside TLS-forced paths on the same cluster.

---

## Common Mistakes

**1. Using a Traefik annotation on an HAProxy Ingress (or vice versa).** Silently ignored. No error, no warning in the controller log. The desired behavior just does not happen.

**2. Creating a TLS Secret without `kubectl create secret tls`.** An Opaque Secret with the cert in a random key (`certificate.pem`, `ca.crt`) is not recognized by any Ingress controller. Always use `--cert=` and `--key=` flags so Kubernetes applies the `kubernetes.io/tls` type.

**3. Certificate CN mismatch.** A cert generated for `CN=foo.example.com` terminating TLS on `bar.example.com` results in a valid TLS handshake but the client (with `-k` disabled) rejects the cert. Use Subject Alternative Names (SAN) to cover all hostnames.

**4. Forgetting the `spec.tls[].hosts` list.** Some controllers handle an empty list by applying the TLS block globally; others require the hostname to appear in the list. Always include it.

**5. Expecting rate-limit annotations to apply without a rate-limit connection tracking config.** HAProxy's rate-limit typically needs `connection-tracking` enabled in the controller's ConfigMap. Production setups require more than just the annotation.

**6. Port confusion between controllers.** Traefik on :80/:443 via HostPort; HAProxy on :8080/:8443 via kubectl port-forward. Testing the wrong port returns the wrong controller's response (often 404 or empty).

**7. Assuming `curl -k` means "no security checks at all".** It skips certificate validation but still requires the TLS handshake to succeed. A missing Secret or wrong CN still produces a handshake, but with the controller's fallback cert.

**8. Editing a Secret in place after the Ingress is created.** HAProxy watches the Secret and picks up changes within seconds, but some caches linger. Deleting and recreating the Secret (or editing the Ingress to force a reconcile) is the reliable way to apply certificate changes.

---

## Verification Commands Cheat Sheet

| Check | Command |
|---|---|
| TLS handshake succeeds | `curl -ksI --resolve <host>:<port>:127.0.0.1 https://<host>:<port>/` |
| TLS certificate subject | `curl -ksv --resolve <host>:<port>:127.0.0.1 https://<host>:<port>/ 2>&1 | grep "subject"` |
| SNI-selected cert | Compare subject for different `--resolve` hostnames |
| Secret type and keys | `kubectl get secret <name> -o jsonpath='{.type} {.data}'` |
| HAProxy controller logs | `kubectl logs -n haproxy-ingress -l app.kubernetes.io/name=haproxy-ingress --tail=50` |
| Annotation on an Ingress | `kubectl get ingress <name> -o jsonpath='{.metadata.annotations}'` |
| Backend endpoints | `kubectl get endpoints -n <ns> <service>` |
| Remove an annotation | `kubectl annotate ingress <name> <annotation-key>-` |
| Replace a Secret | `kubectl delete secret <name>; kubectl create secret tls <name> --cert=<crt> --key=<key>` |
