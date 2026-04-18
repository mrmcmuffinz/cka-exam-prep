# Ingress-to-Gateway-API Migration Homework Answers

Complete solutions. Level 3 and Level 5 debugging answers use the three-stage structure.

---

## Exercise 1.1 Solution

```bash
ingress2gateway --version
```

Output includes `v1.0.0`. If the output shows a different version, re-download the binary from the pinned release URL in the tutorial.

---

## Exercise 1.2 Solution

```bash
ingress2gateway print --input-file=/tmp/ex-1-2.yaml --providers=ingress-nginx > /tmp/ex-1-2-gwapi.yaml
```

The output includes one `Gateway` (listening on HTTP 80 with hostname `basic.example.test`) and one `HTTPRoute` (parentRefs pointing at the generated Gateway, hostnames `[basic.example.test]`, rule with `PathPrefix /` to Service `app`). Names are typically derived from the Ingress: `basic-<classname>` for the Gateway and `basic` for the HTTPRoute, though exact name-generation rules depend on the CLI version.

---

## Exercise 1.3 Solution

```bash
ingress2gateway print --input-file=/tmp/ex-1-3.yaml --providers=ingress-nginx 2>/dev/null | grep -A1 "path:" | grep "type:"
```

The output contains `type: Exact`. The CLI preserves the Ingress `pathType` value exactly; `Exact` in Ingress maps to `path.type: Exact` in HTTPRoute.

---

## Exercise 2.1 Solution

```bash
ingress2gateway print --input-file=/tmp/ex-2-1.yaml --providers=ingress-nginx
```

CLI output shape: one Gateway with two listeners (or two hostnames on one listener depending on CLI version), and two HTTPRoutes (one per host, grouping the paths for that host). `first.example.test` has one rule (`/a`). `second.example.test` has two rules (`/b`, `/c`). The CLI groups per host because HTTPRoute's `hostnames[]` is the key for per-host routing.

---

## Exercise 2.2 Solution

```bash
ingress2gateway print --input-file=/tmp/ex-2-2.yaml --providers=ingress-nginx
```

Output: one Gateway and one HTTPRoute. The HTTPRoute has one rule with no `matches` (catch-all) and `backendRefs[{name: fallback, port: 80}]`. Gateway API models `defaultBackend` as a rule with no match conditions, which acts as the "otherwise" arm.

---

## Exercise 2.3 Solution

```bash
ingress2gateway print --input-file=/tmp/ex-2-3.yaml --providers=ingress-nginx
```

Output: a Gateway with two listeners, one HTTP on 80 and one HTTPS on 443. The HTTPS listener has `tls.certificateRefs[{name: secure-tls}]`. The HTTPRoute attaches to the HTTPS listener (via `parentRefs` with `sectionName` pointing at the HTTPS listener name).

---

## Exercise 3.1 Solution

**Diagnosis.**

```bash
ingress2gateway print --input-file=/tmp/ex-3-1.yaml --providers=ingress-nginx 2>/dev/null | grep -A5 "URLRewrite"
```

The generated HTTPRoute has a `filters: [{type: URLRewrite, urlRewrite: {path: {type: ReplacePrefixMatch, replacePrefixMatch: /}}}]` on the rule. The CLI recognized the `nginx.ingress.kubernetes.io/rewrite-target: /` annotation and translated it to a Gateway API filter.

**What the bug is and why.** This is not a bug; it is a successful translation. The Level 3 exercise frame is "did the CLI produce the correct filter?" The answer: yes, URLRewrite with ReplacePrefixMatch `/`.

**Fix.** None needed. The output is correct.

---

## Exercise 3.2 Solution

**Diagnosis.**

```bash
ingress2gateway print --input-file=/tmp/ex-3-2.yaml --providers=ingress-nginx 2>&1 | grep -i "limit-rps\|unsupported\|unable\|not supported"
```

The CLI emits a warning on stderr or in the output saying something like "annotation limit-rps has no Gateway API equivalent; skipping." The generated HTTPRoute has no rate-limit filter (Gateway API v1.0 does not have a standard rate-limit primitive).

**What the bug is and why.** `nginx.ingress.kubernetes.io/limit-rps` is a feature the CLI knows about but cannot express in standard Gateway API. Different Gateway API implementations provide rate-limiting via their own CRDs (Envoy Gateway's `BackendTrafficPolicy`, NGINX Gateway Fabric's `ClientSettingsPolicy`), but those are implementation-specific and the CLI does not generate them.

**Fix.** After translation, manually author an implementation-specific rate-limit resource alongside the HTTPRoute. For Envoy Gateway, a `BackendTrafficPolicy` with `rateLimit.global` or `rateLimit.local` applies at the HTTPRoute level.

---

## Exercise 3.3 Solution

**Diagnosis.**

```bash
ingress2gateway print --input-file=/tmp/ex-3-3.yaml --providers=ingress-nginx > /tmp/ex-3-3-out.yaml
grep "gatewayClassName" /tmp/ex-3-3-out.yaml
```

Output: `gatewayClassName: enterprise-edge`. No such GatewayClass exists in the cluster.

**What the bug is and why.** The CLI preserves the `ingressClassName` as `gatewayClassName`. Ingress classes and Gateway classes live in different registries; the Ingress class may be valid but the GatewayClass with the same name does not exist.

**Fix.** Edit the output to reference a real GatewayClass before applying.

```bash
sed -i 's/gatewayClassName: enterprise-edge/gatewayClassName: eg/' /tmp/ex-3-3-out.yaml
```

---

## Exercise 4.1 Solution

```bash
kubectl get ingress -n ex-4-1 old -o yaml > /tmp/ex-4-1-ing.yaml

ingress2gateway print --input-file=/tmp/ex-4-1-ing.yaml --providers=ingress-nginx 2>/dev/null \
  | sed 's/gatewayClassName:.*$/gatewayClassName: eg/' \
  | kubectl apply -n ex-4-1 -f -
```

Both the Traefik-served Ingress (on port 80) and the Envoy-Gateway-served HTTPRoute (via port-forward on 9100) return `ex41-content`. The backend Service is the same; only the control-plane path differs.

---

## Exercise 4.2 Solution

Patch the Ingress and the HTTPRoute so they respond to different hostnames. In practice this is closer to a real cutover: DNS directs some clients to the old endpoint and some to the new; as the cutover progresses, more clients resolve to the new endpoint.

```bash
kubectl patch ingress -n ex-4-1 old --type='json' \
  -p='[{"op":"replace","path":"/spec/rules/0/host","value":"old-41.example.test"}]'

# Get the generated HTTPRoute name and patch its hostnames
RT=$(kubectl get httproute -n ex-4-1 -o jsonpath='{.items[0].metadata.name}')
kubectl patch httproute -n ex-4-1 "$RT" --type='json' \
  -p='[{"op":"replace","path":"/spec/hostnames","value":["new-41.example.test"]}]'
```

Each hostname now routes through its respective control plane. A client requesting `old-41.example.test` goes through Traefik; a client requesting `new-41.example.test` goes through Envoy Gateway.

---

## Exercise 4.3 Solution

```bash
kubectl delete httproute,gateway -n ex-4-1 --all
```

The Ingress continues serving. This is the rollback advantage: because the Ingress was never modified during the parallel phase, deleting the Gateway API resources leaves the original path intact.

---

## Exercise 5.1 Solution

```bash
kubectl get ingress -n ex-5-1 multi-tls -o yaml > /tmp/ex-5-1.yaml

ingress2gateway print --input-file=/tmp/ex-5-1.yaml --providers=ingress-nginx 2>/dev/null \
  | sed 's/gatewayClassName:.*$/gatewayClassName: eg/' \
  | kubectl apply -n ex-5-1 -f -
```

Output: a Gateway with three listeners (one HTTPS per host, each with its own `tls.certificateRefs`) plus an HTTP listener (from the rules without explicit TLS). Three HTTPRoutes, one per host, attaching to the corresponding HTTPS listener via `parentRefs.sectionName`. The TLS material is referenced by Secret name; no secret content needs to be re-applied.

---

## Exercise 5.2 Solution

**Diagnosis.**

```bash
ingress2gateway print --input-file=/tmp/ex-5-2.yaml --providers=ingress-nginx 2>&1 | grep -E "limit-rps|ssl-redirect|RequestRedirect"
```

The CLI emits:

- For `ssl-redirect: "true"`: a RequestRedirect HTTPRoute that converts HTTP to HTTPS.
- For `limit-rps: "5"`: a warning about no equivalent.
- The generated Gateway references `gatewayClassName: some-custom-class`, which does not exist.

**What the bug is and why.** Three distinct adjustments are required:

- `gatewayClassName: some-custom-class` -> adjust to `eg`.
- `limit-rps` -> accept the warning or add a controller-specific rate-limit resource manually.
- The cross-namespace backend (`remote-svc` in `ex-5-2-svc`) -> add `namespace: ex-5-2-svc` to `backendRefs[0]` and create a ReferenceGrant.

**Fix.** Produce the adjusted YAML.

```bash
ingress2gateway print --input-file=/tmp/ex-5-2.yaml --providers=ingress-nginx 2>/dev/null \
  | sed 's/gatewayClassName:.*$/gatewayClassName: eg/' \
  > /tmp/ex-5-2-adjusted.yaml

# Add namespace to backendRefs manually (depends on exact structure; edit file)
# For this exercise, we'll add a ReferenceGrant:
kubectl apply -n ex-5-2-svc -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata: {name: grant-complex}
spec:
  from: [{group: gateway.networking.k8s.io, kind: HTTPRoute, namespace: ex-5-2}]
  to: [{group: "", kind: Service, name: remote-svc}]
EOF

# Apply the adjusted Gateway API YAML
kubectl apply -f /tmp/ex-5-2-adjusted.yaml
```

The `limit-rps` is acknowledged as not translating; production practice would add an Envoy Gateway `BackendTrafficPolicy` to restore the rate limit.

---

## Exercise 5.3 Solution

Full cutover sequence:

```bash
# Step 1: Verify Ingress serves
curl -s -H "Host: migrate-53.example.test" http://localhost/
# Expected: prod-content

# Step 2-3: Translate and apply
kubectl get ingress -n ex-5-3 prod -o yaml > /tmp/ex-5-3-in.yaml

ingress2gateway print --input-file=/tmp/ex-5-3-in.yaml --providers=ingress-nginx 2>/dev/null \
  | sed 's/gatewayClassName:.*$/gatewayClassName: eg/' \
  | kubectl apply -n ex-5-3 -f -

sleep 8

# Step 4: Verify Envoy Gateway serves
SVC=$(kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-namespace=ex-5-3 -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n envoy-gateway-system "svc/$SVC" 9110:80 &
sleep 2
curl -s -H "Host: migrate-53.example.test" http://localhost:9110/
# Expected: prod-content

# Step 5: Cut over - delete the Ingress
kubectl delete ingress -n ex-5-3 prod

# Step 6: Confirm only Gateway API serves
sleep 3
curl -s -H "Host: migrate-53.example.test" http://localhost:9110/
# Expected: prod-content

pkill -f "port-forward" 2>/dev/null
```

This is the full migration pattern used in production: apply in parallel, verify parity, cut over by deleting the old path (or shifting DNS away from it).

---

## Common Mistakes

**1. Trusting `gatewayClassName` from the CLI output without checking.** The CLI preserves the Ingress's `ingressClassName` as `gatewayClassName`, but Gateway and Ingress classes live in separate namespaces. Always confirm the generated name corresponds to a real GatewayClass.

**2. Assuming every annotation translates.** Rate-limit, WAF rules, custom configuration snippets have no Gateway API equivalent in v1.0. The CLI drops them with warnings; you must decide whether to reproduce them via implementation-specific CRDs.

**3. Applying the Gateway API output without reviewing.** The CLI is a starting point. Always diff the output, fix `gatewayClassName`, add ReferenceGrants for cross-namespace references, and consider which annotations need manual translation.

**4. Deleting the Ingress before verifying the Gateway API equivalent works.** The correct order is: apply both, verify parity, then delete. Deleting first creates a service-outage window if the Gateway API path is misconfigured.

**5. Not running the translation on the live cluster for complex migrations.** `ingress2gateway print --providers=<list>` (without `--input-file`) reads from the current kubeconfig and translates all Ingresses in the cluster at once. For a large-scale migration this is much more efficient than file-by-file.

**6. Forgetting ReferenceGrants for cross-namespace backends.** Gateway API enforces explicit cross-namespace reference permission. If the Ingress's backend was in the same namespace (common), no ReferenceGrant is needed. If it was cross-namespace (rare with Ingress but common with Gateway API's persona model), you must add one.

**7. Trying to translate `rewrite-target` that ends in `$1`, `$2`, or uses regex captures.** The CLI handles the simple case (`rewrite-target: /`). For regex-based rewrites, the output may be incorrect or incomplete; manual adjustment is required.

**8. Expecting the CLI to generate a full set of controller-specific CRDs.** The CLI produces standard Gateway API resources only. Controller-specific extensions (Envoy Gateway's `BackendTrafficPolicy`, Traefik's `Middleware`, NGINX Gateway Fabric's `ClientSettingsPolicy`) are out of scope for the CLI.

---

## Verification Commands Cheat Sheet

| Check | Command |
|---|---|
| CLI version | `ingress2gateway --version` |
| Translate a file | `ingress2gateway print --input-file=<ing.yaml> --providers=<list>` |
| Translate from cluster | `ingress2gateway print --providers=<list>` |
| Supported providers (v1.0.0) | `ingress-nginx`, `istio`, `kong`, `gce` |
| Save output to a file | `ingress2gateway print ... > /tmp/out.yaml` |
| Diff Ingress and Gateway API output | `diff <(kubectl get ingress X -o yaml) /tmp/out.yaml` |
| Apply with class adjustment | `... \| sed 's/gatewayClassName: .*/gatewayClassName: eg/' \| kubectl apply -f -` |
| Confirm parity | `curl -H "Host: <h>" http://localhost/` and `curl -H "Host: <h>" http://localhost:<gwport>/` |
| Cut over (delete Ingress) | `kubectl delete ingress <name>` |
| Rollback (delete Gateway API) | `kubectl delete httproute,gateway -n <ns> --all` |
