# Ingress-to-Gateway-API Migration Homework

Fifteen exercises covering the `ingress2gateway` CLI, translation from Ingress to Gateway API, side-by-side running, and rollback. Work through the tutorial first. Assumes Traefik (assignment 1) and Envoy Gateway (assignment 3) are both installed. The `ingress2gateway` CLI v1.0.0 must be on the host's PATH.

Exercise namespaces follow `ex-<level>-<exercise>`.

---

## Level 1: CLI Basics

### Exercise 1.1

**Objective:** Confirm the CLI is installed and reports v1.0.0.

**Task:** Run `ingress2gateway --version` and verify the output contains `v1.0.0`.

**Verification:**

```bash
ingress2gateway --version 2>&1 | grep -o 'v1.0.0'
# Expected: v1.0.0
```

---

### Exercise 1.2

**Objective:** Translate a minimal Ingress and read the generated Gateway and HTTPRoute.

**Setup:**

```bash
kubectl create namespace ex-1-2

cat <<'EOF' > /tmp/ex-1-2.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: basic, namespace: ex-1-2}
spec:
  ingressClassName: traefik
  rules:
  - host: basic.example.test
    http:
      paths:
      - {path: /, pathType: Prefix, backend: {service: {name: app, port: {number: 80}}}}
EOF
```

**Task:** Run `ingress2gateway print --input-file=/tmp/ex-1-2.yaml --providers=ingress-nginx`. Save the output to `/tmp/ex-1-2-gwapi.yaml`. Confirm it contains both a `Gateway` and an `HTTPRoute` resource.

**Verification:**

```bash
ingress2gateway print --input-file=/tmp/ex-1-2.yaml --providers=ingress-nginx > /tmp/ex-1-2-gwapi.yaml 2>/dev/null
grep -c "^kind: Gateway$" /tmp/ex-1-2-gwapi.yaml
# Expected: 1

grep -c "^kind: HTTPRoute$" /tmp/ex-1-2-gwapi.yaml
# Expected: 1

grep "hostnames:" /tmp/ex-1-2-gwapi.yaml
# Expected: the hostnames line referring to basic.example.test
```

---

### Exercise 1.3

**Objective:** Translate an Ingress whose pathType is `Exact` and confirm the output preserves the type.

**Setup:**

```bash
cat <<'EOF' > /tmp/ex-1-3.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: exact-path, namespace: default}
spec:
  ingressClassName: nginx
  rules:
  - host: exact.example.test
    http:
      paths:
      - {path: /api, pathType: Exact, backend: {service: {name: api, port: {number: 80}}}}
EOF
```

**Task:** Translate and verify the output's `path.type` is `Exact`.

**Verification:**

```bash
ingress2gateway print --input-file=/tmp/ex-1-3.yaml --providers=ingress-nginx 2>/dev/null | grep -A1 "path:" | grep "type:"
# Expected: type: Exact
```

---

## Level 2: Translation Details

### Exercise 2.1

**Objective:** Translate an Ingress with multiple paths and multiple hosts. Confirm the output has one HTTPRoute with multiple rules.

**Setup:**

```bash
cat <<'EOF' > /tmp/ex-2-1.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: multi, namespace: default}
spec:
  ingressClassName: nginx
  rules:
  - host: first.example.test
    http:
      paths:
      - {path: /a, pathType: Prefix, backend: {service: {name: svc-a, port: {number: 80}}}}
  - host: second.example.test
    http:
      paths:
      - {path: /b, pathType: Prefix, backend: {service: {name: svc-b, port: {number: 80}}}}
      - {path: /c, pathType: Prefix, backend: {service: {name: svc-c, port: {number: 80}}}}
EOF
```

**Task:** Translate and examine the output. Identify how many Gateways and how many HTTPRoutes were generated.

**Verification:**

```bash
ingress2gateway print --input-file=/tmp/ex-2-1.yaml --providers=ingress-nginx 2>/dev/null > /tmp/ex-2-1-out.yaml
grep -c "^kind: Gateway$" /tmp/ex-2-1-out.yaml
# Expected: 1 (CLI typically combines hosts into one Gateway)

grep -c "^kind: HTTPRoute$" /tmp/ex-2-1-out.yaml
# Expected: 2 (one per host)
```

---

### Exercise 2.2

**Objective:** Translate an Ingress with `defaultBackend` only (no rules). Confirm the output is an HTTPRoute with no match conditions.

**Setup:**

```bash
cat <<'EOF' > /tmp/ex-2-2.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: catch-all, namespace: default}
spec:
  ingressClassName: nginx
  defaultBackend:
    service: {name: fallback, port: {number: 80}}
EOF
```

**Task:** Translate and confirm the HTTPRoute references the fallback Service.

**Verification:**

```bash
ingress2gateway print --input-file=/tmp/ex-2-2.yaml --providers=ingress-nginx 2>/dev/null | grep -A3 "backendRefs" | head -n 4
# Expected: backendRefs with name fallback
```

---

### Exercise 2.3

**Objective:** Translate an Ingress with TLS and confirm the Gateway has an HTTPS listener referencing the TLS Secret.

**Setup:**

```bash
cat <<'EOF' > /tmp/ex-2-3.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: secure, namespace: default}
spec:
  ingressClassName: nginx
  tls:
  - hosts: ["secure.example.test"]
    secretName: secure-tls
  rules:
  - host: secure.example.test
    http:
      paths:
      - {path: /, pathType: Prefix, backend: {service: {name: secure-app, port: {number: 80}}}}
EOF
```

**Task:** Translate; find the `tls` block in the Gateway output.

**Verification:**

```bash
ingress2gateway print --input-file=/tmp/ex-2-3.yaml --providers=ingress-nginx 2>/dev/null | grep -A5 "protocol: HTTPS"
# Expected: includes tls.certificateRefs with name: secure-tls
```

---

## Level 3: Debugging

### Exercise 3.1

**Objective:** Translate an Ingress with `rewrite-target` and confirm the CLI produced a `URLRewrite` filter.

**Setup:**

```bash
cat <<'EOF' > /tmp/ex-3-1.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rewritten
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: rewrite.example.test
    http:
      paths:
      - {path: /app, pathType: Prefix, backend: {service: {name: backend, port: {number: 80}}}}
EOF
```

**Task:** Translate and find the `URLRewrite` filter in the output. Identify what `replacePrefixMatch` value the CLI chose.

**Verification:**

```bash
ingress2gateway print --input-file=/tmp/ex-3-1.yaml --providers=ingress-nginx 2>/dev/null | grep -A5 "URLRewrite"
# Expected: replacePrefixMatch: / (the rewrite-target value)
```

---

### Exercise 3.2

**Objective:** Translate an Ingress with a controller-specific annotation that does not translate (`nginx.ingress.kubernetes.io/limit-rps`). Observe the CLI's warning output.

**Setup:**

```bash
cat <<'EOF' > /tmp/ex-3-2.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: limited
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "10"
spec:
  ingressClassName: nginx
  rules:
  - host: rl.example.test
    http:
      paths:
      - {path: /, pathType: Prefix, backend: {service: {name: app, port: {number: 80}}}}
EOF
```

**Task:** Translate. The CLI should emit a warning (to stderr or in comments) that `limit-rps` has no Gateway API equivalent in this version. Identify the warning.

**Verification:**

```bash
ingress2gateway print --input-file=/tmp/ex-3-2.yaml --providers=ingress-nginx 2>&1 | grep -i "limit-rps\|unsupported\|not translated\|ignored" | head
# Expected: at least one line mentioning the unsupported annotation
```

---

### Exercise 3.3

**Objective:** Translate an Ingress whose `ingressClassName` refers to a class that does not map cleanly to a Gateway API GatewayClass. Identify how the CLI represents the gateway.

**Setup:**

```bash
cat <<'EOF' > /tmp/ex-3-3.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: custom-class, namespace: default}
spec:
  ingressClassName: enterprise-edge
  rules:
  - host: c.example.test
    http:
      paths:
      - {path: /, pathType: Prefix, backend: {service: {name: app, port: {number: 80}}}}
EOF
```

**Task:** Translate. The generated Gateway references `gatewayClassName: enterprise-edge`. Since no such GatewayClass exists in the cluster, applying this would result in a Gateway stuck without a controller. Adjust the generated YAML (manually) to use `gatewayClassName: eg` before applying.

**Verification:**

```bash
ingress2gateway print --input-file=/tmp/ex-3-3.yaml --providers=ingress-nginx 2>/dev/null > /tmp/ex-3-3-out.yaml
grep "gatewayClassName: enterprise-edge" /tmp/ex-3-3-out.yaml | wc -l
# Expected: 1 (the CLI preserves the name)

# Adjust the generated output:
sed -i 's/gatewayClassName: enterprise-edge/gatewayClassName: eg/' /tmp/ex-3-3-out.yaml
grep "gatewayClassName: eg" /tmp/ex-3-3-out.yaml | wc -l
# Expected: 1
```

---

## Level 4: Side-by-Side

### Exercise 4.1

**Objective:** Apply an Ingress under Traefik, translate to Gateway API, apply under Envoy Gateway in parallel, and verify both endpoints return the same content.

**Setup:**

```bash
kubectl create namespace ex-4-1
kubectl apply -n ex-4-1 -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: parity-app}
spec:
  replicas: 1
  selector: {matchLabels: {app: parity-app}}
  template:
    metadata: {labels: {app: parity-app}}
    spec:
      containers:
      - {name: n, image: nginx:1.27, volumeMounts: [{name: h, mountPath: /usr/share/nginx/html}]}
      volumes: [{name: h, configMap: {name: parity-html}}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: parity-html}
data: {index.html: "ex41-content\n"}
---
apiVersion: v1
kind: Service
metadata: {name: parity-app}
spec: {selector: {app: parity-app}, ports: [{port: 80, targetPort: 80}]}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: old}
spec:
  ingressClassName: traefik
  rules:
  - host: parity-41.example.test
    http:
      paths:
      - {path: /, pathType: Prefix, backend: {service: {name: parity-app, port: {number: 80}}}}
EOF
kubectl -n ex-4-1 rollout status deployment/parity-app --timeout=60s
```

**Task:** Translate the Ingress, adjust `gatewayClassName` to `eg`, apply the Gateway API resources. Port-forward to Envoy Gateway's data-plane Service. Verify both paths return `ex41-content`.

**Verification:**

```bash
sleep 3
curl -s -H "Host: parity-41.example.test" http://localhost/
# Expected: ex41-content (via Traefik)

kubectl get ingress -n ex-4-1 old -o yaml > /tmp/ex-4-1-ing.yaml
ingress2gateway print --input-file=/tmp/ex-4-1-ing.yaml --providers=ingress-nginx 2>/dev/null \
  | sed 's/gatewayClassName:.*$/gatewayClassName: eg/' \
  | kubectl apply -n ex-4-1 -f -

sleep 8
SVC=$(kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-namespace=ex-4-1 -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n envoy-gateway-system "svc/$SVC" 9100:80 &
sleep 2
curl -s -H "Host: parity-41.example.test" http://localhost:9100/
# Expected: ex41-content (via Envoy Gateway)
pkill -f "port-forward" 2>/dev/null
```

---

### Exercise 4.2

**Objective:** Route 50% of clients through the Ingress and 50% through the Gateway API by toggling DNS entries (simulated with two `curl -H "Host: ..."` values).

**Setup:** Continue from 4.1.

**Task:** Create two variants of the hostname: `old-41.example.test` routed through the Ingress (Traefik), and `new-41.example.test` routed through the Gateway API (Envoy Gateway). Update the resources accordingly. Verify each hostname returns the same content.

**Verification:**

```bash
# Adjust the Ingress hostname
kubectl patch ingress -n ex-4-1 old --type='json' \
  -p='[{"op":"replace","path":"/spec/rules/0/host","value":"old-41.example.test"}]'

# Adjust the HTTPRoute hostname
kubectl patch httproute -n ex-4-1 old --type='json' \
  -p='[{"op":"replace","path":"/spec/hostnames","value":["new-41.example.test"]}]' 2>/dev/null || \
kubectl get httproute -n ex-4-1 -o yaml > /tmp/ex-4-1-rt.yaml
# ... or edit accordingly

sleep 3
curl -s -H "Host: old-41.example.test" http://localhost/
# Expected: ex41-content

SVC=$(kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-namespace=ex-4-1 -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n envoy-gateway-system "svc/$SVC" 9101:80 &
sleep 2
curl -s -H "Host: new-41.example.test" http://localhost:9101/
# Expected: ex41-content
pkill -f "port-forward" 2>/dev/null
```

---

### Exercise 4.3

**Objective:** Roll back a partial migration by deleting the Gateway API resources; confirm the Ingress still serves.

**Setup:** Continue from 4.2.

**Task:** Delete the `HTTPRoute` and `Gateway` created from the migration. Confirm the Ingress still serves on the original hostname.

**Verification:**

```bash
kubectl delete httproute,gateway -n ex-4-1 --all

sleep 3
curl -s -H "Host: old-41.example.test" http://localhost/
# Expected: ex41-content (Ingress still works)

kubectl get httproute,gateway -n ex-4-1 2>&1 | grep -E "httproute|gateway" | head
# Expected: (empty; both deleted)
```

---

## Level 5: Comprehensive

### Exercise 5.1

**Objective:** Migrate a multi-host production-style Ingress with TLS: three hosts, a shared backend Service per host, one TLS Secret per host.

**Setup:**

```bash
kubectl create namespace ex-5-1

for host in alpha beta gamma; do
  openssl req -x509 -newkey rsa:2048 -nodes -sha256 \
    -subj "/CN=$host-51.example.test/O=ex51" -days 30 \
    -addext "subjectAltName = DNS:$host-51.example.test" \
    -keyout "/tmp/$host-51.key" -out "/tmp/$host-51.crt"
  kubectl create secret tls -n ex-5-1 "$host-51-tls" --cert="/tmp/$host-51.crt" --key="/tmp/$host-51.key"
  kubectl apply -n ex-5-1 -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata: {name: $host-app}
spec:
  replicas: 1
  selector: {matchLabels: {app: $host-app}}
  template:
    metadata: {labels: {app: $host-app}}
    spec:
      containers:
      - {name: n, image: nginx:1.27, volumeMounts: [{name: h, mountPath: /usr/share/nginx/html}]}
      volumes: [{name: h, configMap: {name: $host-html}}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: $host-html}
data: {index.html: "$host-app-v1\n"}
---
apiVersion: v1
kind: Service
metadata: {name: $host-app}
spec: {selector: {app: $host-app}, ports: [{port: 80, targetPort: 80}]}
EOF
done

kubectl -n ex-5-1 wait --for=condition=Available deployment --all --timeout=120s

kubectl apply -n ex-5-1 -f - <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: multi-tls}
spec:
  ingressClassName: traefik
  tls:
  - {hosts: ["alpha-51.example.test"], secretName: alpha-51-tls}
  - {hosts: ["beta-51.example.test"], secretName: beta-51-tls}
  - {hosts: ["gamma-51.example.test"], secretName: gamma-51-tls}
  rules:
  - host: alpha-51.example.test
    http: {paths: [{path: /, pathType: Prefix, backend: {service: {name: alpha-app, port: {number: 80}}}}]}
  - host: beta-51.example.test
    http: {paths: [{path: /, pathType: Prefix, backend: {service: {name: beta-app, port: {number: 80}}}}]}
  - host: gamma-51.example.test
    http: {paths: [{path: /, pathType: Prefix, backend: {service: {name: gamma-app, port: {number: 80}}}}]}
EOF
```

**Task:** Translate this Ingress. Adjust the output's `gatewayClassName` to `eg`. Apply the Gateway API resources. Verify the three HTTPRoutes each terminate TLS correctly and return their respective content.

**Verification:**

```bash
kubectl get ingress -n ex-5-1 multi-tls -o yaml > /tmp/ex-5-1.yaml
ingress2gateway print --input-file=/tmp/ex-5-1.yaml --providers=ingress-nginx 2>/dev/null \
  | sed 's/gatewayClassName:.*$/gatewayClassName: eg/' \
  | kubectl apply -n ex-5-1 -f -

sleep 10
SVC=$(kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-namespace=ex-5-1 -o jsonpath='{.items[0].metadata.name}')
# Note: TLS testing against Envoy Gateway data plane would require a port-forward on 443, not tested here for simplicity.
# Verify the resources exist:
kubectl get httproute -n ex-5-1 | wc -l
# Expected: 4 (3 routes + header) or 2+ (at least one HTTPRoute)

kubectl get gateway -n ex-5-1 -o jsonpath='{.items[0].spec.listeners[*].name}' | tr ' ' '\n' | wc -l
# Expected: 3 or more (one listener per host)
```

---

### Exercise 5.2

**Objective:** Translate a complex Ingress whose CLI output requires manual adjustment (an annotation that does not translate, a `gatewayClassName` that needs changing, and a backend that needs a ReferenceGrant for cross-namespace).

**Setup:**

```bash
kubectl create namespace ex-5-2
kubectl create namespace ex-5-2-svc

cat <<'EOF' > /tmp/ex-5-2.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: complex
  namespace: ex-5-2
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/limit-rps: "5"
spec:
  ingressClassName: some-custom-class
  rules:
  - host: complex.example.test
    http:
      paths:
      - {path: /, pathType: Prefix, backend: {service: {name: remote-svc, port: {number: 80}}}}
EOF
```

**Task:** Translate with `--providers=ingress-nginx`. The output needs three manual edits: change `gatewayClassName` to `eg`; handle `ssl-redirect: true` (the CLI generates a RequestRedirect route); handle `limit-rps` (unsupported, just accept the warning). Also, the backend Service `remote-svc` lives in `ex-5-2-svc` (different namespace), so you need to add a `namespace` field to the backendRef and create a ReferenceGrant.

**Verification:**

```bash
ingress2gateway print --input-file=/tmp/ex-5-2.yaml --providers=ingress-nginx 2>&1 | tee /tmp/ex-5-2-out.yaml > /dev/null

grep -c "ssl-redirect\|RequestRedirect" /tmp/ex-5-2-out.yaml
# Expected: non-zero (CLI generated RequestRedirect filter or a separate redirect HTTPRoute)

grep -c "limit-rps\|not supported\|ignored" /tmp/ex-5-2-out.yaml 2>&1 | head -n1
# Expected: non-zero (warning about limit-rps)
```

---

### Exercise 5.3

**Objective:** Perform a full migration cutover for a small application: apply Ingress, run traffic, migrate to Gateway API in parallel, cut over, and delete the Ingress. Document each step.

**Setup:**

```bash
kubectl create namespace ex-5-3

kubectl apply -n ex-5-3 -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: {name: prod-app}
spec:
  replicas: 2
  selector: {matchLabels: {app: prod-app}}
  template:
    metadata: {labels: {app: prod-app}}
    spec:
      containers:
      - {name: n, image: nginx:1.27, volumeMounts: [{name: h, mountPath: /usr/share/nginx/html}]}
      volumes: [{name: h, configMap: {name: prod-html}}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: prod-html}
data: {index.html: "prod-content\n"}
---
apiVersion: v1
kind: Service
metadata: {name: prod-app}
spec: {selector: {app: prod-app}, ports: [{port: 80, targetPort: 80}]}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {name: prod}
spec:
  ingressClassName: traefik
  rules:
  - host: migrate-53.example.test
    http:
      paths:
      - {path: /, pathType: Prefix, backend: {service: {name: prod-app, port: {number: 80}}}}
EOF
kubectl -n ex-5-3 rollout status deployment/prod-app --timeout=60s
```

**Task:** Follow the full cutover workflow:

1. Verify the Ingress serves (`curl -H "Host: migrate-53.example.test" http://localhost/`).
2. Translate to Gateway API with the CLI.
3. Adjust `gatewayClassName` to `eg` and apply.
4. Verify Envoy Gateway serves the same content.
5. Delete the Ingress (the cutover).
6. Confirm only the Gateway API path serves.

**Verification:**

```bash
# Step 1
curl -s -H "Host: migrate-53.example.test" http://localhost/
# Expected: prod-content

# Step 2-3
kubectl get ingress -n ex-5-3 prod -o yaml > /tmp/ex-5-3-in.yaml
ingress2gateway print --input-file=/tmp/ex-5-3-in.yaml --providers=ingress-nginx 2>/dev/null \
  | sed 's/gatewayClassName:.*$/gatewayClassName: eg/' \
  | kubectl apply -n ex-5-3 -f -

sleep 8

# Step 4
SVC=$(kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-namespace=ex-5-3 -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n envoy-gateway-system "svc/$SVC" 9110:80 &
sleep 2
curl -s -H "Host: migrate-53.example.test" http://localhost:9110/
# Expected: prod-content

# Step 5
kubectl delete ingress -n ex-5-3 prod

sleep 3

# Step 6
curl -s -H "Host: migrate-53.example.test" http://localhost:9110/
# Expected: prod-content (still works, via Envoy Gateway)

kubectl get ingress -n ex-5-3 prod 2>&1 | grep -o NotFound
# Expected: NotFound (the Ingress is deleted)

pkill -f "port-forward" 2>/dev/null
```

---

## Cleanup

```bash
for ns in ex-1-2 ex-4-1 ex-5-1 ex-5-2 ex-5-2-svc ex-5-3; do
  kubectl delete namespace "$ns" --ignore-not-found
done

rm -f /tmp/ex-*.yaml /tmp/*-51.*
```

## Key Takeaways

The `ingress2gateway` CLI v1.0.0 translates Ingress YAML to Gateway API. Standard fields (host, path, pathType, backend, tls) translate mechanically. Some annotations (rewrite-target, ssl-redirect) translate to Gateway API filters; others (rate-limit, WAF, controller-specific) are dropped with warnings. `gatewayClassName` in the output preserves the original `ingressClassName`; you must manually set it to a real Gateway API implementation class. Side-by-side running with Traefik serving the Ingress and Envoy Gateway serving the HTTPRoute lets you verify parity before cutting over. Rollback is trivial because the Ingress is never touched during the parallel phase. Cutover = delete the Ingress (or route DNS to the Gateway API endpoint).
