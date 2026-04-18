# Ingress and Gateway API Homework Answers: Gateway API

---

## Exercise 1.1 Solution

```bash
kubectl get gatewayclass
```

Look at the `CONTROLLER` column to see which controller handles each class.

---

## Exercise 1.2 Solution

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
  namespace: ex-1-2
spec:
  gatewayClassName: nginx
  listeners:
  - name: http
    port: 80
    protocol: HTTP
```

---

## Exercise 1.3 Solution

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: app-gateway
  namespace: ex-1-3
spec:
  gatewayClassName: nginx
  listeners:
  - name: http
    port: 80
    protocol: HTTP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route
  namespace: ex-1-3
spec:
  parentRefs:
  - name: app-gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: app-svc
      port: 80
```

---

## Exercise 2.1 Solution

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: multi-path
spec:
  parentRefs:
  - name: gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api
    backendRefs:
    - name: api-svc
      port: 80
  - matches:
    - path:
        type: PathPrefix
        value: /web
    backendRefs:
    - name: web-svc
      port: 80
```

---

## Exercise 2.2 Solution

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: header-route
spec:
  parentRefs:
  - name: gateway
  rules:
  - matches:
    - headers:
      - name: env
        value: staging
    backendRefs:
    - name: staging-svc
      port: 80
```

---

## Exercise 2.3 Solution

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: split-route
spec:
  parentRefs:
  - name: gateway
  rules:
  - backendRefs:
    - name: svc-v1
      port: 80
      weight: 80
    - name: svc-v2
      port: 80
      weight: 20
```

---

## Exercise 3.1 Solution

**Diagnosis:**

```bash
kubectl describe httproute <name>
# Check Status.Parents for "Accepted: False"
```

**Root Cause:** parentRef references non-existent Gateway.

**Fix:** Correct the Gateway name in parentRefs.

---

## Exercise 3.2 Solution

**Diagnosis:**

```bash
kubectl describe gateway <name>
# Check Status.Conditions
```

**Root Cause:** gatewayClassName does not match any GatewayClass.

**Fix:** Use correct gatewayClassName.

---

## Exercise 3.3 Solution

**Diagnosis:**

```bash
kubectl describe httproute <name>
# Check backendRefs status
```

**Root Cause:** Service name is wrong.

**Fix:** Correct service name in backendRefs.

---

## Exercise 4.1 Solution

```yaml
backendRefs:
- name: v1-svc
  port: 80
  weight: 90
- name: v2-svc
  port: 80
  weight: 10
```

---

## Exercise 4.2 Solution

```yaml
rules:
- matches:
  - path:
      type: PathPrefix
      value: /api
    headers:
    - name: version
      value: v2
  backendRefs:
  - name: api-v2
    port: 80
```

Both path AND header must match.

---

## Exercise 4.3 Solution

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: secure-gateway
spec:
  gatewayClassName: nginx
  listeners:
  - name: https
    port: 443
    protocol: HTTPS
    tls:
      mode: Terminate
      certificateRefs:
      - name: tls-secret
```

---

## Exercise 5.1 Solution

**Ingress:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-svc
            port:
              number: 80
```

**Gateway API equivalent:**
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: app-gateway
spec:
  gatewayClassName: nginx
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    hostname: app.example.com
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route
spec:
  parentRefs:
  - name: app-gateway
  hostnames:
  - app.example.com
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: app-svc
      port: 80
```

---

## Exercise 5.2 Solution

Check:
1. GatewayClass exists and controller is running
2. Gateway references correct GatewayClass
3. HTTPRoute parentRefs match Gateway
4. Services exist with correct ports

---

## Exercise 5.3 Solution

**Architecture:**

1. **Shared GatewayClass:** One per cluster, managed by platform team
2. **Per-team Gateways:** Each team gets a Gateway in their namespace
3. **HTTPRoutes:** Applications create routes in their namespaces

```yaml
# Platform-managed GatewayClass
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: org-gateway-class
spec:
  controllerName: gateway.nginx.org/nginx-gateway-controller
---
# Team A Gateway
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: team-a-gateway
  namespace: team-a
spec:
  gatewayClassName: org-gateway-class
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    hostname: "*.team-a.company.com"
```

---

## Common Mistakes

- **Wrong GatewayClass name:** Must match existing GatewayClass
- **parentRef in wrong namespace:** Default is same namespace as HTTPRoute
- **Missing CRDs:** Must install Gateway API CRDs first
- **Controller not installed:** GatewayClass needs a running controller

---

## Gateway API Cheat Sheet

| Task | Command |
|------|---------|
| List GatewayClasses | `kubectl get gatewayclass` |
| List Gateways | `kubectl get gateway -A` |
| List HTTPRoutes | `kubectl get httproute -A` |
| Check Gateway status | `kubectl describe gateway <name>` |
| Check HTTPRoute status | `kubectl describe httproute <name>` |
