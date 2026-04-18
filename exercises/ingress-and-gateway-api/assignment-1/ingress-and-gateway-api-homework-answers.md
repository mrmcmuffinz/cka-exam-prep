# Ingress and Gateway API Homework Answers: Ingress Fundamentals

Complete solutions for all 15 exercises with explanations.

---

## Exercise 1.1 Solution

**Task:** Create an Ingress with a single backend.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webapp-ingress
  namespace: ex-1-1
spec:
  ingressClassName: nginx
  rules:
  - host: ex-1-1.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: webapp-svc
            port:
              number: 80
EOF
```

---

## Exercise 1.2 Solution

**Task:** Verify Ingress address assignment.

**Solution:**

Check the Ingress status:

```bash
kubectl get ingress app-ingress -n ex-1-2
```

The ADDRESS column should show `localhost`. If empty, check:
1. Is nginx-ingress controller running?
2. Does the Ingress have ingressClassName: nginx?

---

## Exercise 1.3 Solution

**Task:** Test with curl and Host header.

**Solution:**

```bash
curl -H "Host: hello.test" http://localhost/
```

This sends the request to localhost but with the Host header set to `hello.test`, which the Ingress controller uses for routing.

---

## Exercise 2.1 Solution

**Task:** Create Ingress with multiple path routes.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-path
  namespace: ex-2-1
spec:
  ingressClassName: nginx
  rules:
  - host: ex-2-1.local
    http:
      paths:
      - path: /frontend
        pathType: Prefix
        backend:
          service:
            name: frontend-svc
            port:
              number: 80
      - path: /backend
        pathType: Prefix
        backend:
          service:
            name: backend-svc
            port:
              number: 80
EOF
```

---

## Exercise 2.2 Solution

**Task:** Create Ingress with multiple host routes.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-host
  namespace: ex-2-2
spec:
  ingressClassName: nginx
  rules:
  - host: a.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: site-a-svc
            port:
              number: 80
  - host: b.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: site-b-svc
            port:
              number: 80
EOF
```

---

## Exercise 2.3 Solution

**Task:** Test different path types.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prefix-ingress
  namespace: ex-2-3
spec:
  ingressClassName: nginx
  rules:
  - host: ex-2-3.local
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-svc
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: exact-ingress
  namespace: ex-2-3
spec:
  ingressClassName: nginx
  rules:
  - host: ex-2-3.local
    http:
      paths:
      - path: /exact
        pathType: Exact
        backend:
          service:
            name: api-svc
            port:
              number: 80
EOF
```

**Behavior:**
- Prefix `/api`: matches `/api`, `/api/`, `/api/anything`
- Exact `/exact`: matches only `/exact`, not `/exact/more`

---

## Exercise 3.1 Solution

**Task:** Diagnose backend service not found.

**Diagnosis:**

```bash
kubectl get svc -n ex-3-1
# Shows: application-svc

kubectl describe ingress broken-ingress -n ex-3-1
# Backend: app-svc (does not exist!)
```

**Root Cause:** Ingress references `app-svc` but the service is named `application-svc`.

**Fix:** Change the Ingress backend service name to `application-svc`.

---

## Exercise 3.2 Solution

**Task:** Diagnose path not matching.

**Diagnosis:**

```bash
kubectl describe ingress path-issue -n ex-3-2
# Path: api (missing leading /)
```

**Root Cause:** Path is `api` instead of `/api`. Paths must start with `/`.

**Fix:** Change path to `/api`.

---

## Exercise 3.3 Solution

**Task:** Diagnose no address assigned.

**Diagnosis:**

```bash
kubectl describe ingress no-class -n ex-3-3
# No ingressClassName specified
```

**Root Cause:** The Ingress does not have `ingressClassName: nginx`. Without this, no controller picks it up.

**Fix:** Add `spec.ingressClassName: nginx`.

---

## Exercise 4.1 Solution

**Task:** Configure default backend.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: with-default
  namespace: ex-4-1
spec:
  ingressClassName: nginx
  defaultBackend:
    service:
      name: default-svc
      port:
        number: 80
  rules:
  - host: ex-4-1.local
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-svc
            port:
              number: 80
EOF
```

---

## Exercise 4.2 Solution

**Task:** Use wildcard host.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wildcard
  namespace: ex-4-2
spec:
  ingressClassName: nginx
  rules:
  - host: "*.example.com"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: wildcard-svc
            port:
              number: 80
EOF
```

Note: The wildcard `*` only matches one subdomain level.

---

## Exercise 4.3 Solution

**Task:** Route multiple services on different paths.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-api
  namespace: ex-4-3
spec:
  ingressClassName: nginx
  rules:
  - host: ex-4-3.local
    http:
      paths:
      - path: /api/users
        pathType: Prefix
        backend:
          service:
            name: users-svc
            port:
              number: 80
      - path: /api/products
        pathType: Prefix
        backend:
          service:
            name: products-svc
            port:
              number: 80
      - path: /api/orders
        pathType: Prefix
        backend:
          service:
            name: orders-svc
            port:
              number: 80
EOF
```

---

## Exercise 5.1 Solution

**Task:** Multi-service application with path routing.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: ex-5-1
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-svc
            port:
              number: 80
      - path: /static
        pathType: Prefix
        backend:
          service:
            name: static-svc
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-svc
            port:
              number: 80
EOF
```

Note: More specific paths (`/api`, `/static`) should come before the catch-all `/`.

---

## Exercise 5.2 Solution

**Task:** Debug complex routing issue.

**Diagnosis:**

```bash
kubectl get svc main-svc -n ex-5-2 -o yaml
# port: 8080 (service port)
# targetPort: 80 (pod port)

kubectl describe ingress complex-routing -n ex-5-2
# Backend port: 80
```

**Root Cause:** The Ingress references port 80, but the service exposes port 8080.

**Fix:** Change the Ingress backend port to 8080:

```yaml
backend:
  service:
    name: main-svc
    port:
      number: 8080
```

---

## Exercise 5.3 Solution

**Task:** Design Ingress for microservices.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: microservices
  namespace: ex-5-3
spec:
  ingressClassName: nginx
  defaultBackend:
    service:
      name: error-svc
      port:
        number: 80
  rules:
  - host: api.company.com
    http:
      paths:
      - path: /v1/users
        pathType: Prefix
        backend:
          service:
            name: users-svc
            port:
              number: 80
      - path: /v1/products
        pathType: Prefix
        backend:
          service:
            name: products-svc
            port:
              number: 80
  - host: www.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-svc
            port:
              number: 80
EOF
```

**Design Decisions:**

1. **Separate hosts for API and web:** Clean separation of concerns
2. **Versioned API paths:** `/v1/` allows future API versions
3. **Default backend:** Handles unknown hosts/paths gracefully

---

## Common Mistakes

### Ingress Controller Not Installed

**Mistake:** Creating Ingress without installing nginx-ingress.

**Fix:** `kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/kind/deploy.yaml`

### Service Name or Port Wrong

**Mistake:** Typo in service name or using wrong port.

**Fix:** Verify with `kubectl get svc -n <namespace>`.

### PathType Mismatch

**Mistake:** Using Exact when Prefix is needed.

**Fix:** Understand Exact matches only exact path, Prefix matches path and subpaths.

### Host Not Matching Request

**Mistake:** Ingress has host but request does not match.

**Fix:** Use `curl -H "Host: hostname" http://localhost/`.

### Backend Service Has No Endpoints

**Mistake:** Service selector does not match pods.

**Fix:** `kubectl get endpoints <service> -n <namespace>`.

---

## Ingress Debugging Cheat Sheet

| Task | Command |
|------|---------|
| List Ingresses | `kubectl get ingress -n <ns>` |
| Describe Ingress | `kubectl describe ingress <name> -n <ns>` |
| Check controller | `kubectl get pods -n ingress-nginx` |
| Check endpoints | `kubectl get endpoints <svc> -n <ns>` |
| Test with host | `curl -H "Host: name" http://localhost/path` |
| Controller logs | `kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller` |
