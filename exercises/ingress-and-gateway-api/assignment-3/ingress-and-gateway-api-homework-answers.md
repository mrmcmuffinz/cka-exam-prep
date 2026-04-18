# Gateway API Fundamentals Homework Answers

Complete solutions. Level 3 and Level 5 debugging answers use the three-stage structure.

---

## Exercise 1.1 Solution

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: basic-gw, namespace: ex-1-1}
spec:
  gatewayClassName: eg
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces: {from: All}
```

`eg` is the GatewayClass that Envoy Gateway provides out of the box. `allowedRoutes.namespaces.from: All` permits HTTPRoutes in any namespace to attach. The Gateway's `Programmed: True` status confirms the controller has configured the data plane.

---

## Exercise 1.2 Solution

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: app-route, namespace: ex-1-1}
spec:
  parentRefs:
  - name: basic-gw
  hostnames: ["hello.example.test"]
  rules:
  - matches:
    - path: {type: PathPrefix, value: /}
    backendRefs:
    - {name: app, port: 80}
```

`parentRefs: [{name: basic-gw}]` attaches to the Gateway in the same namespace (namespace defaults to the HTTPRoute's own). Path `/` with PathPrefix catches every path.

---

## Exercise 1.3 Solution

```bash
kubectl get gatewayclass -o jsonpath='{range .items[?(@.spec.controllerName=="gateway.envoyproxy.io/gatewayclass-controller")]}{.metadata.name}{"\n"}{end}'
```

The filter selects GatewayClasses whose `controllerName` matches Envoy Gateway's unique identifier. Exactly one class (`eg`) satisfies the filter in a clean install.

---

## Exercise 2.1 Solution

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: paths, namespace: ex-2-1}
spec:
  parentRefs: [{name: paths-gw}]
  hostnames: ["paths.example.test"]
  rules:
  - matches: [{path: {type: PathPrefix, value: /a}}]
    backendRefs: [{name: svc-a, port: 80}]
  - matches: [{path: {type: PathPrefix, value: /b}}]
    backendRefs: [{name: svc-b, port: 80}]
```

Two rules on one HTTPRoute, each matching a different path prefix. The more-specific path wins when multiple rules could match. `/c` matches no rule and returns 404.

---

## Exercise 2.2 Solution

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: red-route, namespace: ex-2-2}
spec:
  parentRefs: [{name: hosts-gw}]
  hostnames: ["red.example.test"]
  rules:
  - backendRefs: [{name: red, port: 80}]
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: blue-route, namespace: ex-2-2}
spec:
  parentRefs: [{name: hosts-gw}]
  hostnames: ["blue.example.test"]
  rules:
  - backendRefs: [{name: blue, port: 80}]
```

Two separate HTTPRoutes, both attached to the same Gateway. Each has its own `hostnames[]`. A request is routed based on which HTTPRoute's hostnames match the Host header.

---

## Exercise 2.3 Solution

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: split, namespace: ex-2-3}
spec:
  parentRefs: [{name: split-gw}]
  hostnames: ["split.example.test"]
  rules:
  - backendRefs:
    - {name: v1-app, port: 80, weight: 50}
    - {name: v2-app, port: 80, weight: 50}
```

`backendRefs[].weight` is the primitive for traffic splitting. Envoy distributes requests according to the weights; sending 20 requests typically yields ~10 each with some variance.

---

## Exercise 3.1 Solution

**Diagnosis.**

```bash
kubectl get httproute -n ex-3-1-other blocked -o yaml | grep -A2 "type: Accepted"
kubectl get gateway -n ex-3-1 gw -o jsonpath='{.spec.listeners[0].allowedRoutes}'
```

The HTTPRoute's `Accepted: False` with reason `NotAllowedByListeners`. The Gateway listener's `allowedRoutes.namespaces.from: Same` restricts attachment to the Gateway's own namespace (`ex-3-1`). The HTTPRoute lives in `ex-3-1-other` and is not allowed.

**What the bug is and why.** `from: Same` is the default. When the HTTPRoute's namespace differs from the Gateway's, the listener rejects the attachment. The HTTPRoute is authored correctly; the restriction is on the Gateway.

**Fix.** Change the Gateway's `allowedRoutes.namespaces.from` to `All`, or use a `Selector`.

```bash
kubectl patch gateway -n ex-3-1 gw --type='json' \
  -p='[{"op":"replace","path":"/spec/listeners/0/allowedRoutes","value":{"namespaces":{"from":"All"}}}]'
```

---

## Exercise 3.2 Solution

**Diagnosis.**

```bash
kubectl get httproute -n ex-3-2 unresolved -o yaml | grep -A2 "type: ResolvedRefs"
kubectl get svc -n ex-3-2
```

`ResolvedRefs: False` with reason `BackendNotFound`. The HTTPRoute references Service `nonexistent`, which does not exist in the namespace.

**What the bug is and why.** Gateway API's typed conditions make this failure mode explicit: `ResolvedRefs` tracks whether all referenced backends exist and are reachable. A reference to a non-existent Service sets it to False.

**Fix.**

```bash
kubectl patch httproute -n ex-3-2 unresolved --type='json' \
  -p='[{"op":"replace","path":"/spec/rules/0/backendRefs/0/name","value":"real"}]'
```

---

## Exercise 3.3 Solution

**Diagnosis.**

```bash
kubectl get httproute -n ex-3-3 orphan -o yaml | grep -A5 "parentRefs"
kubectl get gateway -A | grep shared-gw
```

The HTTPRoute's `parentRefs` is `[{name: shared-gw}]` with no namespace. The default namespace for parentRefs is the HTTPRoute's own (`ex-3-3`). There is no `shared-gw` Gateway in `ex-3-3`; the actual Gateway is in `ex-3-3-gw`.

**What the bug is and why.** Cross-namespace Gateway attachment requires explicit `namespace` in `parentRefs`. The default is the HTTPRoute's own namespace, which silently produces a "no such Gateway" failure.

**Fix.**

```bash
kubectl patch httproute -n ex-3-3 orphan --type='json' \
  -p='[{"op":"replace","path":"/spec/parentRefs/0","value":{"name":"shared-gw","namespace":"ex-3-3-gw"}}]'
```

---

## Exercise 4.1 Solution

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: platform, namespace: ex-4-1-infra}
spec:
  gatewayClassName: eg
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            tier: app
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: demo, namespace: ex-4-1-app}
spec:
  replicas: 1
  selector: {matchLabels: {app: demo}}
  template:
    metadata: {labels: {app: demo}}
    spec:
      containers:
      - {name: n, image: nginx:1.27, volumeMounts: [{name: h, mountPath: /usr/share/nginx/html}]}
      volumes: [{name: h, configMap: {name: demo-html, namespace: ex-4-1-app}}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: demo-html, namespace: ex-4-1-app}
data: {index.html: "ok-4-1\n"}
---
apiVersion: v1
kind: Service
metadata: {name: demo, namespace: ex-4-1-app}
spec: {selector: {app: demo}, ports: [{port: 80, targetPort: 80}]}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: tenant-route, namespace: ex-4-1-app}
spec:
  parentRefs: [{name: platform, namespace: ex-4-1-infra}]
  hostnames: ["tenant.example.test"]
  rules:
  - backendRefs: [{name: demo, port: 80}]
```

The Gateway's listener admits only HTTPRoutes from namespaces labeled `tier=app`. The app namespace has that label; the HTTPRoute attaches.

---

## Exercise 4.2 Solution

```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata: {name: route-to-shared, namespace: ex-4-2-svc}
spec:
  from:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    namespace: ex-4-2-route
  to:
  - group: ""
    kind: Service
    name: shared
```

The ReferenceGrant lives in the destination namespace. The `from` block names the kind and namespace that is granted the reference permission; the `to` block names the exact kind and (optional) name it is allowed to reference. Without this grant, the HTTPRoute's `ResolvedRefs` is `False`.

---

## Exercise 4.3 Solution

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: both-gateways, namespace: ex-4-3}
spec:
  parentRefs:
  - {name: gw-a}
  - {name: gw-b}
  hostnames: ["multi.example.test"]
  rules:
  - backendRefs: [{name: multi, port: 80}]
```

`status.parents[]` reports one entry per parent. Both show `Accepted: True`. Each Gateway serves the HTTPRoute independently; a request to either Gateway's data plane gets routed through.

---

## Exercise 5.1 Solution

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: shared, namespace: ex-5-1-platform}
spec:
  gatewayClassName: eg
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: Selector
        selector: {matchLabels: {gateway-attach: allowed}}
```

For each team namespace, a similar Service+Deployment, and:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: route, namespace: ex-5-1-api}
spec:
  parentRefs: [{name: shared, namespace: ex-5-1-platform}]
  hostnames: ["api.ex-5-1.test"]
  rules:
  - backendRefs: [{name: api, port: 80}]
```

(analogous for `ui` and `admin`). The Gateway's label selector admits only namespaces labeled `gateway-attach=allowed`, so a rogue namespace without that label cannot attach. Each team owns only its own HTTPRoute.

---

## Exercise 5.2 Solution

**Diagnosis.**

```bash
kubectl get gateway -n ex-5-2-gw gw -o yaml | head -n 30
kubectl get httproute -n ex-5-2-route three-bugs -o yaml | grep -A3 "conditions"
```

Three problems visible:

1. Gateway's `gatewayClassName: nonexistent-class` matches no GatewayClass. No controller picks up the Gateway.
2. Even with the class fixed, listener `allowedRoutes.namespaces.from: Same` rejects the cross-namespace HTTPRoute.
3. Even with the attachment fixed, the `backendRefs[]` references `ex-5-2-svc/backend`, a cross-namespace Service. Without a ReferenceGrant in `ex-5-2-svc`, `ResolvedRefs: False`.

**What the bug is and why.** Three distinct-but-compounding failures. Fixing any one still leaves the others. The typed status conditions make each failure surface separately once the preceding one is fixed.

**Fix.**

```bash
kubectl patch gateway -n ex-5-2-gw gw --type='json' -p='[
  {"op":"replace","path":"/spec/gatewayClassName","value":"eg"},
  {"op":"replace","path":"/spec/listeners/0/allowedRoutes/namespaces/from","value":"All"}
]'

kubectl apply -n ex-5-2-svc -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata: {name: grant-5-2}
spec:
  from: [{group: gateway.networking.k8s.io, kind: HTTPRoute, namespace: ex-5-2-route}]
  to: [{group: "", kind: Service, name: backend}]
EOF
```

---

## Exercise 5.3 Solution

Gateway API equivalent of the Ingress:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: modern-gw, namespace: ex-5-3}
spec:
  gatewayClassName: eg
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes: {namespaces: {from: Same}}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: modern-route, namespace: ex-5-3}
spec:
  parentRefs: [{name: modern-gw}]
  hostnames: ["legacy.example.test"]
  rules:
  - matches: [{path: {type: PathPrefix, value: /api}}]
    backendRefs: [{name: legacy-api, port: 80}]
```

Mapping: `spec.ingressClassName: traefik` disappears (Gateway chooses via `gatewayClassName`). `spec.rules[].host` becomes `spec.hostnames[]` on the HTTPRoute. `spec.rules[].http.paths[].path` and `pathType` become `spec.rules[].matches[].path`. `spec.rules[].http.paths[].backend.service` becomes `spec.rules[].backendRefs[]`. Traffic served by Traefik (via Ingress) and by Envoy Gateway (via HTTPRoute) is indistinguishable at the HTTP level.

---

## Common Mistakes

**1. Omitting `namespace` on `parentRefs`.** The default is the HTTPRoute's namespace. Cross-namespace attachment requires explicit `namespace` on the parentRef.

**2. Assuming `allowedRoutes.namespaces.from: Same` is the default (which it is), and then wondering why routes in other namespaces do not attach.** Set `All` or `Selector` explicitly when persona separation is needed.

**3. Cross-namespace `backendRefs` without a ReferenceGrant.** The HTTPRoute is accepted by the Gateway, but traffic fails with `ResolvedRefs: False`. The ReferenceGrant lives in the destination namespace, not the source.

**4. Confusing `Accepted` with `ResolvedRefs`.** Two separate conditions. Attachment (did the Gateway accept you?) is `Accepted`. Backends (do the Services exist?) is `ResolvedRefs`. Both must be True for traffic to flow.

**5. Using `kind: Ingress` annotations or field names on Gateway API resources.** Gateway API has its own field vocabulary. `ingressClassName` becomes `gatewayClassName`. `pathType: Prefix` becomes `path.type: PathPrefix` (one word prefix, not two).

**6. Missing `controllerName` match on a custom GatewayClass.** If you create a GatewayClass whose `controllerName` does not match any running controller, no controller picks it up and the class has no status.

**7. Forgetting that Gateways are programmed asynchronously.** `kubectl apply` returns success immediately; the Gateway's data-plane pod may take 30 seconds to come up. Wait for `Programmed: True` before expecting traffic to flow.

**8. Treating `hostnames` on the HTTPRoute as independent of the Gateway listener's `hostname`.** The HTTPRoute's hostnames must intersect with the listener's `hostname` field. If the listener has `hostname: *.example.test` and the HTTPRoute has `hostnames: [other.test]`, the route attaches with no effective hostnames.

---

## Verification Commands Cheat Sheet

| Check | Command |
|---|---|
| GatewayClass state | `kubectl get gatewayclass <name> -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}'` |
| Gateway programmed | `kubectl get gateway -n <ns> <name> -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}'` |
| HTTPRoute accepted per parent | `kubectl get httproute -n <ns> <name> -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'` |
| HTTPRoute resolved refs | `kubectl get httproute -n <ns> <name> -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}'` |
| Find data-plane Service for a Gateway | `kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-namespace=<ns>` |
| Port-forward to the data plane | `kubectl port-forward -n envoy-gateway-system svc/<svc> 8090:80` |
| Envoy Gateway controller logs | `kubectl logs -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gatewayclass=eg` |
| List all HTTPRoutes in cluster | `kubectl get httproute -A` |
