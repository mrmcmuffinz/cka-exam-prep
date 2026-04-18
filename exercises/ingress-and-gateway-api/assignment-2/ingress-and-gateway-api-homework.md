# Ingress and Gateway API Homework: Advanced Ingress and TLS

Work through these 15 exercises covering advanced Ingress features.

---

## Level 1: Annotations

### Exercise 1.1

**Objective:** Add ssl-redirect annotation.

**Setup:**

```bash
kubectl create namespace ex-1-1
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: ex-1-1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: app-svc
  namespace: ex-1-1
spec:
  selector:
    app: app
  ports:
  - port: 80
EOF
kubectl wait --for=condition=Ready pods --all -n ex-1-1 --timeout=60s
```

**Task:** Create an Ingress with ssl-redirect disabled.

---

### Exercise 1.2

**Objective:** Configure proxy-body-size annotation.

**Setup:** Same as 1.1 in namespace ex-1-2.

**Task:** Create an Ingress allowing 50MB request bodies.

---

### Exercise 1.3

**Objective:** Test annotation effects.

**Setup:** Same as 1.1 in namespace ex-1-3.

**Task:** Apply an Ingress with proxy-read-timeout of 120 seconds.

---

## Level 2: Rewrite and TLS

### Exercise 2.1

**Objective:** Configure rewrite-target.

**Setup:** In namespace ex-2-1.

**Task:** Create an Ingress where `/app/*` is rewritten to `/*` on the backend.

---

### Exercise 2.2

**Objective:** Create TLS Secret and Ingress.

**Setup:**

```bash
kubectl create namespace ex-2-2
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: ex-2-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secure
  template:
    metadata:
      labels:
        app: secure
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: secure-svc
  namespace: ex-2-2
spec:
  selector:
    app: secure
  ports:
  - port: 80
EOF
kubectl wait --for=condition=Ready pods --all -n ex-2-2 --timeout=60s
```

**Task:** Create a self-signed certificate, TLS secret, and Ingress for `secure.example.com`.

---

### Exercise 2.3

**Objective:** Test HTTPS access.

**Task:** Using the setup from 2.2, test HTTPS access with curl.

---

## Level 3: Debugging Advanced Ingress

### Exercise 3.1

**Objective:** Rewrite not working. Diagnose.

**Setup:**

```bash
kubectl create namespace ex-3-1
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: ex-3-1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: api-svc
  namespace: ex-3-1
spec:
  selector:
    app: api
  ports:
  - port: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: broken-rewrite
  namespace: ex-3-1
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /api
        pathType: Exact
        backend:
          service:
            name: api-svc
            port:
              number: 80
EOF
kubectl wait --for=condition=Ready pods --all -n ex-3-1 --timeout=60s
```

**Task:** `/api/users` returns 404. Diagnose why.

---

### Exercise 3.2

**Objective:** TLS Secret wrong format. Diagnose.

**Setup:**

```bash
kubectl create namespace ex-3-2
# Create secret with wrong keys
kubectl create secret generic bad-tls --from-literal=cert=dummy --from-literal=key=dummy -n ex-3-2
```

**Task:** Identify why this secret cannot be used for TLS.

---

### Exercise 3.3

**Objective:** Annotation typo. Diagnose.

**Setup:** In namespace ex-3-3 with a misspelled annotation.

**Task:** Find the annotation error.

---

## Level 4: Complex Configurations

### Exercise 4.1

**Objective:** Multiple TLS hosts.

**Task:** Create an Ingress with TLS for both `a.example.com` and `b.example.com` using different secrets.

---

### Exercise 4.2

**Objective:** Combine rewrite with TLS.

**Task:** Create an Ingress with both rewrite-target and TLS termination.

---

### Exercise 4.3

**Objective:** Configure default SSL certificate.

**Task:** Research and explain how to configure a default TLS certificate for the nginx-ingress controller.

---

## Level 5: Production Patterns

### Exercise 5.1

**Objective:** Migrate HTTP to HTTPS with redirects.

**Task:** Configure an Ingress that redirects all HTTP to HTTPS.

---

### Exercise 5.2

**Objective:** Debug complex TLS/routing issue.

**Task:** Given a broken TLS configuration, diagnose and fix.

---

### Exercise 5.3

**Objective:** Design production Ingress architecture.

**Task:** Design an Ingress configuration for a production application with:
- TLS termination
- Path-based routing
- Appropriate timeouts and body size limits

---

## Cleanup

```bash
kubectl delete namespace ex-1-1 ex-1-2 ex-1-3
kubectl delete namespace ex-2-1 ex-2-2 ex-2-3
kubectl delete namespace ex-3-1 ex-3-2 ex-3-3
kubectl delete namespace ex-4-1 ex-4-2 ex-4-3
kubectl delete namespace ex-5-1 ex-5-2 ex-5-3
```

---

## Key Takeaways

1. **Annotations are controller-specific.** nginx annotations use `nginx.ingress.kubernetes.io/` prefix.

2. **TLS secrets must be type kubernetes.io/tls** with keys `tls.crt` and `tls.key`.

3. **Rewrite-target changes the path** sent to the backend.

4. **pathType affects rewrite behavior.** Use Prefix for rewrites that need to match subpaths.

5. **Test TLS with curl -k** to ignore self-signed certificate warnings.
