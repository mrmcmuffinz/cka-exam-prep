# Advanced Gateway API Routing Homework

Fifteen exercises covering NGINX Gateway Fabric v2.5.1, header/query/method matching, traffic splitting, and filters (RequestHeaderModifier, RequestRedirect, URLRewrite, ResponseHeaderModifier). Work through the tutorial first. Assumes Envoy Gateway and NGINX Gateway Fabric are both installed; exercises primarily use NGINX Gateway Fabric.

Namespaces follow `ex-<level>-<exercise>`. The setup blocks create a Gateway per namespace and rely on `kubectl port-forward` to reach the NGINX data-plane Service on localhost.

---

## Level 1: NGF Basics

### Exercise 1.1

**Objective:** Create an HTTPRoute attached to an NGF-managed Gateway and verify end-to-end.

**Setup:**

```bash
kubectl create namespace ex-1-1
kubectl apply -n ex-1-1 -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: gw}
spec:
  gatewayClassName: nginx
  listeners: [{name: http, protocol: HTTP, port: 80, allowedRoutes: {namespaces: {from: Same}}}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: hi}
spec:
  replicas: 1
  selector: {matchLabels: {app: hi}}
  template:
    metadata: {labels: {app: hi}}
    spec:
      containers:
      - {name: n, image: nginx:1.27, volumeMounts: [{name: h, mountPath: /usr/share/nginx/html}]}
      volumes: [{name: h, configMap: {name: hi-html}}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: hi-html}
data: {index.html: "hi-one-one\n"}
---
apiVersion: v1
kind: Service
metadata: {name: hi}
spec: {selector: {app: hi}, ports: [{port: 80, targetPort: 80}]}
EOF
kubectl -n ex-1-1 rollout status deployment/hi --timeout=60s
```

**Task:** Create HTTPRoute `hi-route` in namespace `ex-1-1` attached to `gw`, hostname `hi.example.test`, path `/` prefix, backendRef Service `hi` port 80.

**Verification:**

```bash
sleep 5
kubectl get httproute -n ex-1-1 hi-route \
  -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'
# Expected: True

SVC=$(kubectl get svc -n nginx-gateway -l app.kubernetes.io/instance=ngf -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n nginx-gateway "svc/$SVC" 9010:80 &
sleep 2
curl -s -H "Host: hi.example.test" http://localhost:9010/
# Expected: hi-one-one
pkill -f "port-forward.*$SVC" 2>/dev/null
```

---

### Exercise 1.2

**Objective:** Confirm the NGF GatewayClass is the one named `nginx` with controllerName `gateway.nginx.org/nginx-gateway-controller`.

**Task:** Extract the controllerName for the `nginx` GatewayClass.

**Verification:**

```bash
kubectl get gatewayclass nginx -o jsonpath='{.spec.controllerName}'
# Expected: gateway.nginx.org/nginx-gateway-controller
```

---

### Exercise 1.3

**Objective:** Apply the same HTTPRoute spec under both `eg` and `nginx` Gateways and confirm both respond with the same content.

**Setup:**

```bash
kubectl create namespace ex-1-3
kubectl apply -n ex-1-3 -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: gw-envoy}
spec:
  gatewayClassName: eg
  listeners: [{name: http, protocol: HTTP, port: 80, allowedRoutes: {namespaces: {from: Same}}}]
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: gw-nginx}
spec:
  gatewayClassName: nginx
  listeners: [{name: http, protocol: HTTP, port: 80, allowedRoutes: {namespaces: {from: Same}}}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: same}
spec:
  replicas: 1
  selector: {matchLabels: {app: same}}
  template:
    metadata: {labels: {app: same}}
    spec:
      containers:
      - {name: n, image: nginx:1.27, volumeMounts: [{name: h, mountPath: /usr/share/nginx/html}]}
      volumes: [{name: h, configMap: {name: same-html}}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: same-html}
data: {index.html: "parity\n"}
---
apiVersion: v1
kind: Service
metadata: {name: same}
spec: {selector: {app: same}, ports: [{port: 80, targetPort: 80}]}
EOF
kubectl -n ex-1-3 rollout status deployment/same --timeout=60s
```

**Task:** Create two HTTPRoutes (one per Gateway) with identical specs except for `parentRefs`, hostname `same.example.test`, path `/` -> Service `same`.

**Verification:**

```bash
sleep 5
ENVOY_SVC=$(kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-namespace=ex-1-3 -o jsonpath='{.items[0].metadata.name}')
NGINX_SVC=$(kubectl get svc -n nginx-gateway -l app.kubernetes.io/instance=ngf -o jsonpath='{.items[0].metadata.name}')

kubectl port-forward -n envoy-gateway-system "svc/$ENVOY_SVC" 9020:80 &
kubectl port-forward -n nginx-gateway "svc/$NGINX_SVC" 9021:80 &
sleep 3

curl -s -H "Host: same.example.test" http://localhost:9020/
# Expected: parity

curl -s -H "Host: same.example.test" http://localhost:9021/
# Expected: parity

pkill -f "port-forward" 2>/dev/null
```

---

## Level 2: Advanced Matching

### Exercise 2.1

**Objective:** Route by an `X-Tenant` header value.

**Setup:**

```bash
kubectl create namespace ex-2-1
kubectl apply -n ex-2-1 -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: gw}
spec:
  gatewayClassName: nginx
  listeners: [{name: http, protocol: HTTP, port: 80, allowedRoutes: {namespaces: {from: Same}}}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: red-app}
spec:
  replicas: 1
  selector: {matchLabels: {app: red-app}}
  template:
    metadata: {labels: {app: red-app}}
    spec:
      containers:
      - {name: n, image: nginx:1.27, volumeMounts: [{name: h, mountPath: /usr/share/nginx/html}]}
      volumes: [{name: h, configMap: {name: red-html}}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: red-html}
data: {index.html: "red\n"}
---
apiVersion: v1
kind: Service
metadata: {name: red-app}
spec: {selector: {app: red-app}, ports: [{port: 80, targetPort: 80}]}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: blue-app}
spec:
  replicas: 1
  selector: {matchLabels: {app: blue-app}}
  template:
    metadata: {labels: {app: blue-app}}
    spec:
      containers:
      - {name: n, image: nginx:1.27, volumeMounts: [{name: h, mountPath: /usr/share/nginx/html}]}
      volumes: [{name: h, configMap: {name: blue-html}}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: blue-html}
data: {index.html: "blue\n"}
---
apiVersion: v1
kind: Service
metadata: {name: blue-app}
spec: {selector: {app: blue-app}, ports: [{port: 80, targetPort: 80}]}
EOF
kubectl -n ex-2-1 rollout status deployment/red-app deployment/blue-app --timeout=60s
```

**Task:** Create HTTPRoute `tenant-routing` with two rules: `X-Tenant: red` -> `red-app`, `X-Tenant: blue` -> `blue-app`. Hostname `tenant.example.test`.

**Verification:**

```bash
sleep 5
SVC=$(kubectl get svc -n nginx-gateway -l app.kubernetes.io/instance=ngf -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n nginx-gateway "svc/$SVC" 9030:80 &
sleep 2

curl -s -H "Host: tenant.example.test" -H "X-Tenant: red" http://localhost:9030/
# Expected: red

curl -s -H "Host: tenant.example.test" -H "X-Tenant: blue" http://localhost:9030/
# Expected: blue

curl -sI -H "Host: tenant.example.test" http://localhost:9030/
# Expected: 404 (no header)

pkill -f "port-forward" 2>/dev/null
```

---

### Exercise 2.2

**Objective:** Route by query parameter.

**Setup:** Continue using ex-2-1's Gateway and backends.

```bash
kubectl apply -n ex-2-1 -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: query-routing}
spec:
  parentRefs: [{name: gw}]
  hostnames: ["query.example.test"]
  rules:
  - matches: [{queryParams: [{name: env, value: prod}]}]
    backendRefs: [{name: red-app, port: 80}]
  - matches: [{queryParams: [{name: env, value: staging}]}]
    backendRefs: [{name: blue-app, port: 80}]
EOF
```

**Task:** Verify the routing above.

**Verification:**

```bash
sleep 5
SVC=$(kubectl get svc -n nginx-gateway -l app.kubernetes.io/instance=ngf -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n nginx-gateway "svc/$SVC" 9031:80 &
sleep 2

curl -s -H "Host: query.example.test" "http://localhost:9031/?env=prod"
# Expected: red

curl -s -H "Host: query.example.test" "http://localhost:9031/?env=staging"
# Expected: blue

pkill -f "port-forward" 2>/dev/null
```

---

### Exercise 2.3

**Objective:** Combine path + method + header matches in a single rule (AND semantics).

**Setup:** Continue using ex-2-1's Gateway.

```bash
kubectl apply -n ex-2-1 -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: combined}
spec:
  parentRefs: [{name: gw}]
  hostnames: ["combined.example.test"]
  rules:
  - matches:
    - path: {type: PathPrefix, value: /api}
      method: POST
      headers: [{name: X-API-Key, value: admin}]
    backendRefs: [{name: red-app, port: 80}]
EOF
```

**Task:** Verify all three conditions must hold.

**Verification:**

```bash
sleep 5
SVC=$(kubectl get svc -n nginx-gateway -l app.kubernetes.io/instance=ngf -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n nginx-gateway "svc/$SVC" 9032:80 &
sleep 2

# All three match:
curl -s -X POST -H "Host: combined.example.test" -H "X-API-Key: admin" http://localhost:9032/api
# Expected: red

# Missing header:
curl -sI -X POST -H "Host: combined.example.test" http://localhost:9032/api
# Expected: 404

# Wrong method:
curl -sI -X GET -H "Host: combined.example.test" -H "X-API-Key: admin" http://localhost:9032/api
# Expected: 404

pkill -f "port-forward" 2>/dev/null
```

---

## Level 3: Debugging

### Exercise 3.1

**Objective:** Filter applied in the wrong order: RequestRedirect before URLRewrite means the rewrite never executes. Fix.

**Setup:**

```bash
kubectl create namespace ex-3-1
kubectl apply -n ex-3-1 -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: gw}
spec:
  gatewayClassName: nginx
  listeners: [{name: http, protocol: HTTP, port: 80, allowedRoutes: {namespaces: {from: Same}}}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: app}
spec:
  replicas: 1
  selector: {matchLabels: {app: app}}
  template:
    metadata: {labels: {app: app}}
    spec:
      containers:
      - {name: n, image: nginx:1.27, volumeMounts: [{name: c, mountPath: /etc/nginx/conf.d}]}
      volumes: [{name: c, configMap: {name: app-conf}}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: app-conf}
data:
  default.conf: |
    server {
      listen 80;
      location / { return 200 "app-got: $request_uri\n"; }
    }
---
apiVersion: v1
kind: Service
metadata: {name: app}
spec: {selector: {app: app}, ports: [{port: 80, targetPort: 80}]}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: order-bug}
spec:
  parentRefs: [{name: gw}]
  hostnames: ["order.example.test"]
  rules:
  - matches: [{path: {type: PathPrefix, value: /old}}]
    filters:
    - type: URLRewrite
      urlRewrite:
        path: {type: ReplacePrefixMatch, replacePrefixMatch: /new}
    - type: RequestRedirect
      requestRedirect: {scheme: https, statusCode: 301}
    backendRefs: [{name: app, port: 80}]
EOF
kubectl -n ex-3-1 rollout status deployment/app --timeout=60s
```

**Task:** The intent was to rewrite the path first, then optionally redirect. But with both filters present, only one effectively runs on any given request (a redirect is terminal). Decide: either remove the redirect (the rewrite should run) or move the redirect before the rewrite (but then the rewrite never runs). For this exercise, remove the RequestRedirect; the app should respond with `app-got: /new/items` when `/old/items` is requested.

**Verification:**

```bash
sleep 5
SVC=$(kubectl get svc -n nginx-gateway -l app.kubernetes.io/instance=ngf -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n nginx-gateway "svc/$SVC" 9041:80 &
sleep 2

curl -s -H "Host: order.example.test" http://localhost:9041/old/items
# Expected: app-got: /new/items

pkill -f "port-forward" 2>/dev/null
```

---

### Exercise 3.2

**Objective:** Header match is case-sensitive for values. Fix a case mismatch.

**Setup:**

```bash
kubectl create namespace ex-3-2
kubectl apply -n ex-3-2 -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: gw}
spec:
  gatewayClassName: nginx
  listeners: [{name: http, protocol: HTTP, port: 80, allowedRoutes: {namespaces: {from: Same}}}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: app}
spec:
  replicas: 1
  selector: {matchLabels: {app: app}}
  template:
    metadata: {labels: {app: app}}
    spec:
      containers:
      - {name: n, image: nginx:1.27, volumeMounts: [{name: h, mountPath: /usr/share/nginx/html}]}
      volumes: [{name: h, configMap: {name: app-html}}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: app-html}
data: {index.html: "case-app\n"}
---
apiVersion: v1
kind: Service
metadata: {name: app}
spec: {selector: {app: app}, ports: [{port: 80, targetPort: 80}]}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: case-sensitive}
spec:
  parentRefs: [{name: gw}]
  hostnames: ["case.example.test"]
  rules:
  - matches: [{headers: [{name: X-Env, value: Production}]}]
    backendRefs: [{name: app, port: 80}]
EOF
kubectl -n ex-3-2 rollout status deployment/app --timeout=60s
```

**Task:** A client is sending `X-Env: production` (lowercase) but the rule expects `Production` (capitalized). Fix by adjusting the HTTPRoute's `value` to `production` (matching what the client sends).

**Verification:**

```bash
sleep 5
SVC=$(kubectl get svc -n nginx-gateway -l app.kubernetes.io/instance=ngf -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n nginx-gateway "svc/$SVC" 9042:80 &
sleep 2

curl -s -H "Host: case.example.test" -H "X-Env: production" http://localhost:9042/
# Expected: case-app

pkill -f "port-forward" 2>/dev/null
```

---

### Exercise 3.3

**Objective:** Traffic split with mismatched weights. Fix.

**Setup:**

```bash
kubectl create namespace ex-3-3
kubectl apply -n ex-3-3 -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: gw}
spec:
  gatewayClassName: nginx
  listeners: [{name: http, protocol: HTTP, port: 80, allowedRoutes: {namespaces: {from: Same}}}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: v1-svc}
spec:
  replicas: 1
  selector: {matchLabels: {app: v1-svc}}
  template:
    metadata: {labels: {app: v1-svc}}
    spec:
      containers:
      - {name: n, image: nginx:1.27, volumeMounts: [{name: h, mountPath: /usr/share/nginx/html}]}
      volumes: [{name: h, configMap: {name: v1-html}}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: v1-html}
data: {index.html: "v1\n"}
---
apiVersion: v1
kind: Service
metadata: {name: v1-svc}
spec: {selector: {app: v1-svc}, ports: [{port: 80, targetPort: 80}]}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: v2-svc}
spec:
  replicas: 1
  selector: {matchLabels: {app: v2-svc}}
  template:
    metadata: {labels: {app: v2-svc}}
    spec:
      containers:
      - {name: n, image: nginx:1.27, volumeMounts: [{name: h, mountPath: /usr/share/nginx/html}]}
      volumes: [{name: h, configMap: {name: v2-html}}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: v2-html}
data: {index.html: "v2\n"}
---
apiVersion: v1
kind: Service
metadata: {name: v2-svc}
spec: {selector: {app: v2-svc}, ports: [{port: 80, targetPort: 80}]}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: bad-split}
spec:
  parentRefs: [{name: gw}]
  hostnames: ["split.example.test"]
  rules:
  - backendRefs:
    - {name: v1-svc, port: 80, weight: 0}
    - {name: v2-svc, port: 80, weight: 100}
EOF
kubectl -n ex-3-3 rollout status deployment/v1-svc deployment/v2-svc --timeout=60s
```

**Task:** The current config sends 100% to v2. The intent was a 70/30 split between v1 and v2. Fix.

**Verification:**

```bash
sleep 5
SVC=$(kubectl get svc -n nginx-gateway -l app.kubernetes.io/instance=ngf -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n nginx-gateway "svc/$SVC" 9043:80 &
sleep 2

V1=0; V2=0
for i in $(seq 1 50); do
  r=$(curl -s -H "Host: split.example.test" http://localhost:9043/)
  [ "$r" = "v1" ] && V1=$((V1+1))
  [ "$r" = "v2" ] && V2=$((V2+1))
done
echo "v1: $V1, v2: $V2"
# Expected: roughly 35/15 (with variance; v1 clearly dominates)

pkill -f "port-forward" 2>/dev/null
```

---

## Level 4: Filters

### Exercise 4.1

**Objective:** Apply `RequestHeaderModifier` to add a header to requests before they reach the backend. Verify via backend-reflected header.

**Setup:**

```bash
kubectl create namespace ex-4-1
kubectl apply -n ex-4-1 -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: gw}
spec:
  gatewayClassName: nginx
  listeners: [{name: http, protocol: HTTP, port: 80, allowedRoutes: {namespaces: {from: Same}}}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: echo}
spec:
  replicas: 1
  selector: {matchLabels: {app: echo}}
  template:
    metadata: {labels: {app: echo}}
    spec:
      containers:
      - {name: n, image: nginx:1.27, volumeMounts: [{name: c, mountPath: /etc/nginx/conf.d}]}
      volumes: [{name: c, configMap: {name: echo-conf}}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: echo-conf}
data:
  default.conf: |
    server {
      listen 80;
      location / {
        return 200 "x-source=$http_x_source\n";
      }
    }
---
apiVersion: v1
kind: Service
metadata: {name: echo}
spec: {selector: {app: echo}, ports: [{port: 80, targetPort: 80}]}
EOF
kubectl -n ex-4-1 rollout status deployment/echo --timeout=60s
```

**Task:** Create HTTPRoute `add-hdr` with filter `RequestHeaderModifier` that adds `X-Source: gateway-filter`, hostname `header.example.test`, backend `echo`.

**Verification:**

```bash
sleep 5
SVC=$(kubectl get svc -n nginx-gateway -l app.kubernetes.io/instance=ngf -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n nginx-gateway "svc/$SVC" 9044:80 &
sleep 2

curl -s -H "Host: header.example.test" http://localhost:9044/
# Expected: x-source=gateway-filter

pkill -f "port-forward" 2>/dev/null
```

---

### Exercise 4.2

**Objective:** Redirect HTTP to HTTPS via `RequestRedirect`.

**Setup:**

```bash
kubectl create namespace ex-4-2
kubectl apply -n ex-4-2 -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: gw}
spec:
  gatewayClassName: nginx
  listeners: [{name: http, protocol: HTTP, port: 80, allowedRoutes: {namespaces: {from: Same}}}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: dummy}
spec:
  replicas: 1
  selector: {matchLabels: {app: dummy}}
  template:
    metadata: {labels: {app: dummy}}
    spec:
      containers:
      - {name: n, image: nginx:1.27}
---
apiVersion: v1
kind: Service
metadata: {name: dummy}
spec: {selector: {app: dummy}, ports: [{port: 80, targetPort: 80}]}
EOF
kubectl -n ex-4-2 rollout status deployment/dummy --timeout=60s
```

**Task:** Create HTTPRoute `to-https` that redirects all requests on host `insecure.example.test` to `https://secure.example.test/` with status 301.

**Verification:**

```bash
sleep 5
SVC=$(kubectl get svc -n nginx-gateway -l app.kubernetes.io/instance=ngf -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n nginx-gateway "svc/$SVC" 9045:80 &
sleep 2

curl -sI -H "Host: insecure.example.test" http://localhost:9045/anywhere
# Expected: HTTP/1.1 301 Moved Permanently
# Expected (Location): https://secure.example.test/anywhere

pkill -f "port-forward" 2>/dev/null
```

---

### Exercise 4.3

**Objective:** Use `URLRewrite` with `ReplaceFullPath` to map any request to a fixed path on the backend.

**Setup:**

```bash
kubectl create namespace ex-4-3
kubectl apply -n ex-4-3 -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: gw}
spec:
  gatewayClassName: nginx
  listeners: [{name: http, protocol: HTTP, port: 80, allowedRoutes: {namespaces: {from: Same}}}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: echo}
spec:
  replicas: 1
  selector: {matchLabels: {app: echo}}
  template:
    metadata: {labels: {app: echo}}
    spec:
      containers:
      - {name: n, image: nginx:1.27, volumeMounts: [{name: c, mountPath: /etc/nginx/conf.d}]}
      volumes: [{name: c, configMap: {name: echo-conf}}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: echo-conf}
data:
  default.conf: |
    server {
      listen 80;
      location / { return 200 "path=$request_uri\n"; }
    }
---
apiVersion: v1
kind: Service
metadata: {name: echo}
spec: {selector: {app: echo}, ports: [{port: 80, targetPort: 80}]}
EOF
kubectl -n ex-4-3 rollout status deployment/echo --timeout=60s
```

**Task:** Create HTTPRoute `rewrite-all` that rewrites the full path of any request to `/fixed`, routing to Service `echo`.

**Verification:**

```bash
sleep 5
SVC=$(kubectl get svc -n nginx-gateway -l app.kubernetes.io/instance=ngf -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n nginx-gateway "svc/$SVC" 9046:80 &
sleep 2

curl -s -H "Host: rw.example.test" http://localhost:9046/dynamic/path
# Expected: path=/fixed

curl -s -H "Host: rw.example.test" http://localhost:9046/another
# Expected: path=/fixed

pkill -f "port-forward" 2>/dev/null
```

---

## Level 5: Advanced

### Exercise 5.1

**Objective:** Set up a canary release: 90% of traffic to `v1-app`, 10% to `v2-app`. Then shift to 50/50. Observe the traffic distribution in both states.

**Setup:**

```bash
kubectl create namespace ex-5-1
kubectl apply -n ex-5-1 -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: gw}
spec:
  gatewayClassName: nginx
  listeners: [{name: http, protocol: HTTP, port: 80, allowedRoutes: {namespaces: {from: Same}}}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: v1-app}
spec:
  replicas: 1
  selector: {matchLabels: {app: v1-app}}
  template:
    metadata: {labels: {app: v1-app}}
    spec:
      containers:
      - {name: n, image: nginx:1.27, volumeMounts: [{name: h, mountPath: /usr/share/nginx/html}]}
      volumes: [{name: h, configMap: {name: v1-html}}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: v1-html}
data: {index.html: "v1\n"}
---
apiVersion: v1
kind: Service
metadata: {name: v1-app}
spec: {selector: {app: v1-app}, ports: [{port: 80, targetPort: 80}]}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: v2-app}
spec:
  replicas: 1
  selector: {matchLabels: {app: v2-app}}
  template:
    metadata: {labels: {app: v2-app}}
    spec:
      containers:
      - {name: n, image: nginx:1.27, volumeMounts: [{name: h, mountPath: /usr/share/nginx/html}]}
      volumes: [{name: h, configMap: {name: v2-html}}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: v2-html}
data: {index.html: "v2\n"}
---
apiVersion: v1
kind: Service
metadata: {name: v2-app}
spec: {selector: {app: v2-app}, ports: [{port: 80, targetPort: 80}]}
EOF
kubectl -n ex-5-1 rollout status deployment/v1-app deployment/v2-app --timeout=60s
```

**Task:** Create HTTPRoute `canary` with `backendRefs` v1-app weight 90, v2-app weight 10. Observe 100 requests, confirm ~90/10 split. Then patch to 50/50 and observe again.

**Verification:**

```bash
sleep 5
SVC=$(kubectl get svc -n nginx-gateway -l app.kubernetes.io/instance=ngf -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n nginx-gateway "svc/$SVC" 9051:80 &
sleep 2

echo "Phase 1 (90/10):"
V1=0; V2=0
for i in $(seq 1 100); do
  r=$(curl -s -H "Host: canary.example.test" http://localhost:9051/)
  [ "$r" = "v1" ] && V1=$((V1+1))
  [ "$r" = "v2" ] && V2=$((V2+1))
done
echo "v1: $V1, v2: $V2"
# Expected: v1 around 85-95, v2 around 5-15

kubectl patch httproute -n ex-5-1 canary --type='json' -p='[
  {"op":"replace","path":"/spec/rules/0/backendRefs/0/weight","value":50},
  {"op":"replace","path":"/spec/rules/0/backendRefs/1/weight","value":50}
]'
sleep 3

echo "Phase 2 (50/50):"
V1=0; V2=0
for i in $(seq 1 100); do
  r=$(curl -s -H "Host: canary.example.test" http://localhost:9051/)
  [ "$r" = "v1" ] && V1=$((V1+1))
  [ "$r" = "v2" ] && V2=$((V2+1))
done
echo "v1: $V1, v2: $V2"
# Expected: both in roughly [40, 60] range

pkill -f "port-forward" 2>/dev/null
```

---

### Exercise 5.2

**Objective:** Diagnose a compound filter failure: a URLRewrite that does not reach the backend because a RequestRedirect is earlier in the chain.

**Setup:**

```bash
kubectl create namespace ex-5-2
kubectl apply -n ex-5-2 -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: gw}
spec:
  gatewayClassName: nginx
  listeners: [{name: http, protocol: HTTP, port: 80, allowedRoutes: {namespaces: {from: Same}}}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: app}
spec:
  replicas: 1
  selector: {matchLabels: {app: app}}
  template:
    metadata: {labels: {app: app}}
    spec:
      containers:
      - {name: n, image: nginx:1.27, volumeMounts: [{name: c, mountPath: /etc/nginx/conf.d}]}
      volumes: [{name: c, configMap: {name: app-conf}}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: app-conf}
data:
  default.conf: |
    server {
      listen 80;
      location / { return 200 "final-path=$request_uri\n"; }
    }
---
apiVersion: v1
kind: Service
metadata: {name: app}
spec: {selector: {app: app}, ports: [{port: 80, targetPort: 80}]}
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: bad-order}
spec:
  parentRefs: [{name: gw}]
  hostnames: ["order.example.test"]
  rules:
  - matches: [{path: {type: PathPrefix, value: /old-api}}]
    filters:
    - type: RequestRedirect
      requestRedirect:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /new-api
        statusCode: 302
    - type: URLRewrite
      urlRewrite:
        path: {type: ReplacePrefixMatch, replacePrefixMatch: /v2}
    backendRefs: [{name: app, port: 80}]
EOF
kubectl -n ex-5-2 rollout status deployment/app --timeout=60s
```

**Task:** The client observes a 302 redirect to `/new-api` instead of a 200 with the path `/v2/*`. The intent was to rewrite to `/v2` and forward to the backend; there should be no redirect. Remove the RequestRedirect filter.

**Verification:**

```bash
sleep 5
SVC=$(kubectl get svc -n nginx-gateway -l app.kubernetes.io/instance=ngf -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n nginx-gateway "svc/$SVC" 9052:80 &
sleep 2

curl -s -H "Host: order.example.test" http://localhost:9052/old-api/data
# Expected: final-path=/v2/data

pkill -f "port-forward" 2>/dev/null
```

---

### Exercise 5.3

**Objective:** Apply a production-style pattern: header-based canary routing combined with URL rewrite for the canary path.

**Setup:**

```bash
kubectl create namespace ex-5-3
kubectl apply -n ex-5-3 -f - <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: {name: gw}
spec:
  gatewayClassName: nginx
  listeners: [{name: http, protocol: HTTP, port: 80, allowedRoutes: {namespaces: {from: Same}}}]
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: stable}
spec:
  replicas: 1
  selector: {matchLabels: {app: stable}}
  template:
    metadata: {labels: {app: stable}}
    spec:
      containers:
      - {name: n, image: nginx:1.27, volumeMounts: [{name: c, mountPath: /etc/nginx/conf.d}]}
      volumes: [{name: c, configMap: {name: stable-conf}}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: stable-conf}
data:
  default.conf: |
    server {
      listen 80;
      location / { return 200 "stable path=$request_uri\n"; }
    }
---
apiVersion: v1
kind: Service
metadata: {name: stable}
spec: {selector: {app: stable}, ports: [{port: 80, targetPort: 80}]}
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: canary}
spec:
  replicas: 1
  selector: {matchLabels: {app: canary}}
  template:
    metadata: {labels: {app: canary}}
    spec:
      containers:
      - {name: n, image: nginx:1.27, volumeMounts: [{name: c, mountPath: /etc/nginx/conf.d}]}
      volumes: [{name: c, configMap: {name: canary-conf}}]
---
apiVersion: v1
kind: ConfigMap
metadata: {name: canary-conf}
data:
  default.conf: |
    server {
      listen 80;
      location / { return 200 "canary path=$request_uri\n"; }
    }
---
apiVersion: v1
kind: Service
metadata: {name: canary}
spec: {selector: {app: canary}, ports: [{port: 80, targetPort: 80}]}
EOF
kubectl -n ex-5-3 rollout status deployment/stable deployment/canary --timeout=60s
```

**Task:** Create HTTPRoute `production` with two rules, both on host `prod.example.test`:

1. Requests with header `X-Canary: true` on `/api` are rewritten to `/v2` and routed to `canary`.
2. All other requests on `/api` are routed to `stable` with no rewrite.

**Verification:**

```bash
sleep 5
SVC=$(kubectl get svc -n nginx-gateway -l app.kubernetes.io/instance=ngf -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n nginx-gateway "svc/$SVC" 9053:80 &
sleep 2

curl -s -H "Host: prod.example.test" -H "X-Canary: true" http://localhost:9053/api/data
# Expected: canary path=/v2/data

curl -s -H "Host: prod.example.test" http://localhost:9053/api/data
# Expected: stable path=/api/data

pkill -f "port-forward" 2>/dev/null
```

---

## Cleanup

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-3-1 ex-3-2 ex-3-3 \
         ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3; do
  kubectl delete namespace "$ns" --ignore-not-found
done

pkill -f "port-forward" 2>/dev/null || true
```

## Key Takeaways

HTTPRoute `matches` combine path + headers + queryParams + method (AND within one match object, OR across multiple). Header matching is case-insensitive for names, case-sensitive for values by default. Traffic splitting via `backendRefs[].weight`. Filters (RequestHeaderModifier, RequestRedirect, URLRewrite, ResponseHeaderModifier) execute in list order; a RequestRedirect is terminal. `URLRewrite` supports `ReplacePrefixMatch` and `ReplaceFullPath`. NGINX Gateway Fabric v2.5.1 and Envoy Gateway v1.7.2 both implement this surface; the same YAML works under both.
