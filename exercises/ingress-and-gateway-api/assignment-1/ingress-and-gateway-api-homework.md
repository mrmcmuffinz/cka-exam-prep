# Ingress and Gateway API Homework: Ingress Fundamentals

Work through these 15 exercises to build practical skills with Kubernetes Ingress. Complete the tutorial (ingress-and-gateway-api-tutorial.md) before starting these exercises.

**Important:** These exercises require a kind cluster with nginx-ingress installed. See the README for setup instructions.

---

## Level 1: Basic Ingress Creation

These exercises focus on creating simple Ingress resources.

### Exercise 1.1

**Objective:** Create an Ingress with a single backend.

**Setup:**

```bash
kubectl create namespace ex-1-1

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: ex-1-1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-svc
  namespace: ex-1-1
spec:
  selector:
    app: webapp
  ports:
  - port: 80
EOF

kubectl wait --for=condition=Ready pods --all -n ex-1-1 --timeout=60s
```

**Task:** Create an Ingress named `webapp-ingress` in ex-1-1 namespace that routes all traffic (path `/`) to the webapp-svc service on port 80.

**Verification:**

```bash
# Ingress should exist
kubectl get ingress webapp-ingress -n ex-1-1

# Should route to webapp
curl -s http://localhost/ -H "Host: ex-1-1.local" | head -5
```

---

### Exercise 1.2

**Objective:** Verify Ingress address assignment.

**Setup:**

```bash
kubectl create namespace ex-1-2

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: ex-1-2
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
  namespace: ex-1-2
spec:
  selector:
    app: app
  ports:
  - port: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: ex-1-2
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-svc
            port:
              number: 80
EOF

kubectl wait --for=condition=Ready pods --all -n ex-1-2 --timeout=60s
```

**Task:** Verify the Ingress has an ADDRESS assigned. If not, troubleshoot why.

**Verification:**

```bash
# Check ADDRESS column
kubectl get ingress app-ingress -n ex-1-2

# ADDRESS should show localhost or an IP
kubectl get ingress app-ingress -n ex-1-2 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' && echo ""
```

---

### Exercise 1.3

**Objective:** Test Ingress with curl.

**Setup:**

```bash
kubectl create namespace ex-1-3

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello
  namespace: ex-1-3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: hello-svc
  namespace: ex-1-3
spec:
  selector:
    app: hello
  ports:
  - port: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-ingress
  namespace: ex-1-3
spec:
  ingressClassName: nginx
  rules:
  - host: hello.test
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-svc
            port:
              number: 80
EOF

kubectl wait --for=condition=Ready pods --all -n ex-1-3 --timeout=60s
```

**Task:** Use curl to test the Ingress works by using the Host header.

**Verification:**

```bash
# Test with Host header
curl -s -H "Host: hello.test" http://localhost/ | head -10
```

---

## Level 2: Path and Host Routing

These exercises explore routing configuration.

### Exercise 2.1

**Objective:** Create an Ingress with multiple path routes.

**Setup:**

```bash
kubectl create namespace ex-2-1

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: ex-2-1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
  namespace: ex-2-1
spec:
  selector:
    app: frontend
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: ex-2-1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: ex-2-1
spec:
  selector:
    app: backend
  ports:
  - port: 80
EOF

kubectl wait --for=condition=Ready pods --all -n ex-2-1 --timeout=60s
```

**Task:** Create an Ingress named `multi-path` that routes `/frontend` to frontend-svc and `/backend` to backend-svc.

**Verification:**

```bash
# Both paths should work
curl -s http://localhost/frontend -H "Host: ex-2-1.local" | head -3
curl -s http://localhost/backend -H "Host: ex-2-1.local" | head -3
```

---

### Exercise 2.2

**Objective:** Create an Ingress with multiple host routes.

**Setup:**

```bash
kubectl create namespace ex-2-2

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: site-a
  namespace: ex-2-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: site-a
  template:
    metadata:
      labels:
        app: site-a
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: site-a-svc
  namespace: ex-2-2
spec:
  selector:
    app: site-a
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: site-b
  namespace: ex-2-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: site-b
  template:
    metadata:
      labels:
        app: site-b
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: site-b-svc
  namespace: ex-2-2
spec:
  selector:
    app: site-b
  ports:
  - port: 80
EOF

kubectl wait --for=condition=Ready pods --all -n ex-2-2 --timeout=60s
```

**Task:** Create an Ingress named `multi-host` that routes `a.example.com` to site-a-svc and `b.example.com` to site-b-svc.

**Verification:**

```bash
curl -s -H "Host: a.example.com" http://localhost/ | head -3
curl -s -H "Host: b.example.com" http://localhost/ | head -3
```

---

### Exercise 2.3

**Objective:** Test different path types.

**Setup:**

```bash
kubectl create namespace ex-2-3

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: ex-2-3
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
  namespace: ex-2-3
spec:
  selector:
    app: api
  ports:
  - port: 80
EOF

kubectl wait --for=condition=Ready pods --all -n ex-2-3 --timeout=60s
```

**Task:** Create two Ingress resources: one with pathType `Prefix` for `/api` and one with pathType `Exact` for `/exact`. Test which paths match each type.

**Verification:**

```bash
# Prefix matches /api and /api/anything
curl -s -H "Host: ex-2-3.local" http://localhost/api | head -3
curl -s -H "Host: ex-2-3.local" http://localhost/api/users | head -3

# Exact only matches /exact exactly
curl -s -H "Host: ex-2-3.local" http://localhost/exact | head -3
curl -s -H "Host: ex-2-3.local" http://localhost/exact/more 2>&1 | head -3
```

---

## Level 3: Debugging Ingress Issues

These exercises present broken configurations to diagnose.

### Exercise 3.1

**Objective:** The backend service does not exist. Diagnose and fix.

**Setup:**

```bash
kubectl create namespace ex-3-1

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: ex-3-1
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
  name: application-svc
  namespace: ex-3-1
spec:
  selector:
    app: app
  ports:
  - port: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: broken-ingress
  namespace: ex-3-1
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-svc
            port:
              number: 80
EOF

kubectl wait --for=condition=Ready pods --all -n ex-3-1 --timeout=60s
```

**Task:** The Ingress returns 503 errors. Diagnose and identify the issue.

**Verification:**

```bash
# Returns 503
curl -s -H "Host: ex-3-1.local" http://localhost/ | head -5

# Diagnose
kubectl describe ingress broken-ingress -n ex-3-1
kubectl get svc -n ex-3-1
```

---

### Exercise 3.2

**Objective:** Path is not matching as expected. Diagnose and fix.

**Setup:**

```bash
kubectl create namespace ex-3-2

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: ex-3-2
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
  namespace: ex-3-2
spec:
  selector:
    app: api
  ports:
  - port: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-issue
  namespace: ex-3-2
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: api
        pathType: Prefix
        backend:
          service:
            name: api-svc
            port:
              number: 80
EOF

kubectl wait --for=condition=Ready pods --all -n ex-3-2 --timeout=60s
```

**Task:** Requests to `/api` return 404. Diagnose and identify the issue.

**Verification:**

```bash
curl -s -H "Host: ex-3-2.local" http://localhost/api

# Check the path in the Ingress
kubectl describe ingress path-issue -n ex-3-2 | grep -A3 "Rules"
```

---

### Exercise 3.3

**Objective:** Ingress has no address assigned. Diagnose and fix.

**Setup:**

```bash
kubectl create namespace ex-3-3

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: ex-3-3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: ex-3-3
spec:
  selector:
    app: web
  ports:
  - port: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: no-class
  namespace: ex-3-3
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-svc
            port:
              number: 80
EOF

kubectl wait --for=condition=Ready pods --all -n ex-3-3 --timeout=60s
```

**Task:** The Ingress has no ADDRESS. Diagnose why.

**Verification:**

```bash
kubectl get ingress no-class -n ex-3-3

# Check what is missing
kubectl describe ingress no-class -n ex-3-3
```

---

## Level 4: Advanced Routing

These exercises cover more complex routing scenarios.

### Exercise 4.1

**Objective:** Configure a default backend.

**Setup:**

```bash
kubectl create namespace ex-4-1

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: default-app
  namespace: ex-4-1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: default
  template:
    metadata:
      labels:
        app: default
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: default-svc
  namespace: ex-4-1
spec:
  selector:
    app: default
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: ex-4-1
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
  namespace: ex-4-1
spec:
  selector:
    app: api
  ports:
  - port: 80
EOF

kubectl wait --for=condition=Ready pods --all -n ex-4-1 --timeout=60s
```

**Task:** Create an Ingress with `/api` routing to api-svc and a default backend routing to default-svc for all other paths.

**Verification:**

```bash
# /api goes to api
curl -s -H "Host: ex-4-1.local" http://localhost/api | head -3

# Other paths go to default
curl -s -H "Host: ex-4-1.local" http://localhost/something | head -3
curl -s -H "Host: ex-4-1.local" http://localhost/ | head -3
```

---

### Exercise 4.2

**Objective:** Use wildcard hosts.

**Setup:**

```bash
kubectl create namespace ex-4-2

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wildcard-app
  namespace: ex-4-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wildcard
  template:
    metadata:
      labels:
        app: wildcard
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: wildcard-svc
  namespace: ex-4-2
spec:
  selector:
    app: wildcard
  ports:
  - port: 80
EOF

kubectl wait --for=condition=Ready pods --all -n ex-4-2 --timeout=60s
```

**Task:** Create an Ingress with a wildcard host `*.example.com` that routes to wildcard-svc.

**Verification:**

```bash
# Any subdomain should work
curl -s -H "Host: foo.example.com" http://localhost/ | head -3
curl -s -H "Host: bar.example.com" http://localhost/ | head -3
curl -s -H "Host: anything.example.com" http://localhost/ | head -3
```

---

### Exercise 4.3

**Objective:** Route multiple services on different paths.

**Setup:**

```bash
kubectl create namespace ex-4-3

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: users-api
  namespace: ex-4-3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: users
  template:
    metadata:
      labels:
        app: users
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: users-svc
  namespace: ex-4-3
spec:
  selector:
    app: users
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: products-api
  namespace: ex-4-3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: products
  template:
    metadata:
      labels:
        app: products
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: products-svc
  namespace: ex-4-3
spec:
  selector:
    app: products
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders-api
  namespace: ex-4-3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: orders
  template:
    metadata:
      labels:
        app: orders
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: orders-svc
  namespace: ex-4-3
spec:
  selector:
    app: orders
  ports:
  - port: 80
EOF

kubectl wait --for=condition=Ready pods --all -n ex-4-3 --timeout=60s
```

**Task:** Create an Ingress that routes `/api/users` to users-svc, `/api/products` to products-svc, and `/api/orders` to orders-svc.

**Verification:**

```bash
curl -s -H "Host: ex-4-3.local" http://localhost/api/users | head -3
curl -s -H "Host: ex-4-3.local" http://localhost/api/products | head -3
curl -s -H "Host: ex-4-3.local" http://localhost/api/orders | head -3
```

---

## Level 5: Application Scenarios

These exercises present realistic application scenarios.

### Exercise 5.1

**Objective:** Create Ingress for a multi-service application with path routing.

**Setup:**

```bash
kubectl create namespace ex-5-1

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: ex-5-1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: ex-5-1
spec:
  selector:
    app: web
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: ex-5-1
spec:
  replicas: 2
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
  namespace: ex-5-1
spec:
  selector:
    app: api
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: static
  namespace: ex-5-1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: static
  template:
    metadata:
      labels:
        app: static
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: static-svc
  namespace: ex-5-1
spec:
  selector:
    app: static
  ports:
  - port: 80
EOF

kubectl wait --for=condition=Ready pods --all -n ex-5-1 --timeout=60s
```

**Task:** Create an Ingress for `app.example.com` with:
- `/` routes to web-svc
- `/api` routes to api-svc
- `/static` routes to static-svc

**Verification:**

```bash
curl -s -H "Host: app.example.com" http://localhost/ | head -3
curl -s -H "Host: app.example.com" http://localhost/api | head -3
curl -s -H "Host: app.example.com" http://localhost/static | head -3
```

---

### Exercise 5.2

**Objective:** Debug a complex routing issue.

**Setup:**

```bash
kubectl create namespace ex-5-2

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: main-app
  namespace: ex-5-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: main
  template:
    metadata:
      labels:
        app: main
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: main-svc
  namespace: ex-5-2
spec:
  selector:
    app: main
  ports:
  - port: 8080
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: complex-routing
  namespace: ex-5-2
spec:
  ingressClassName: nginx
  rules:
  - host: app.test
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: main-svc
            port:
              number: 80
EOF

kubectl wait --for=condition=Ready pods --all -n ex-5-2 --timeout=60s
```

**Task:** The Ingress returns errors. Diagnose and identify the issue.

**Verification:**

```bash
curl -s -H "Host: app.test" http://localhost/ | head -5

# Diagnose
kubectl describe ingress complex-routing -n ex-5-2
kubectl get svc main-svc -n ex-5-2 -o yaml
```

---

### Exercise 5.3

**Objective:** Design an Ingress strategy for microservices.

**Setup:**

```bash
kubectl create namespace ex-5-3
```

**Task:** Design and implement an Ingress configuration for a microservices application with:
- `api.company.com` for all API services
  - `/v1/users` -> users-svc
  - `/v1/products` -> products-svc
- `www.company.com` for web frontend -> frontend-svc
- Default backend for unmatched requests -> error-svc

Create the services and Ingress. Document your design decisions.

**Verification:**

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: users
  namespace: ex-5-3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: users
  template:
    metadata:
      labels:
        app: users
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: users-svc
  namespace: ex-5-3
spec:
  selector:
    app: users
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: products
  namespace: ex-5-3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: products
  template:
    metadata:
      labels:
        app: products
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: products-svc
  namespace: ex-5-3
spec:
  selector:
    app: products
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: ex-5-3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
  namespace: ex-5-3
spec:
  selector:
    app: frontend
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: error
  namespace: ex-5-3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: error
  template:
    metadata:
      labels:
        app: error
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: error-svc
  namespace: ex-5-3
spec:
  selector:
    app: error
  ports:
  - port: 80
EOF

kubectl wait --for=condition=Ready pods --all -n ex-5-3 --timeout=60s

# Test your Ingress
curl -s -H "Host: api.company.com" http://localhost/v1/users | head -3
curl -s -H "Host: api.company.com" http://localhost/v1/products | head -3
curl -s -H "Host: www.company.com" http://localhost/ | head -3
```

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

1. **Ingress requires an Ingress controller** (like nginx-ingress) to function.

2. **ingressClassName** specifies which controller handles the Ingress.

3. **Path must start with /**: `path: api` is wrong, `path: /api` is correct.

4. **pathType matters:** Prefix matches path prefixes, Exact matches exactly.

5. **Service must exist** and have endpoints for routing to work.

6. **Port must match** the service port, not the container port.

7. **Use Host header** when testing host-based routing: `curl -H "Host: example.com" http://localhost/`
