# Ingress and Gateway API Homework: Gateway API

Work through these 15 exercises covering Gateway API.

---

## Level 1: Gateway API Basics

### Exercise 1.1

**Objective:** List GatewayClasses in the cluster.

**Task:** List all GatewayClasses and identify which controller handles each.

**Verification:**

```bash
kubectl get gatewayclass
```

---

### Exercise 1.2

**Objective:** Create a Gateway resource.

**Setup:**

```bash
kubectl create namespace ex-1-2
```

**Task:** Create a Gateway named `my-gateway` listening on port 80 HTTP.

---

### Exercise 1.3

**Objective:** Create an HTTPRoute with simple path routing.

**Setup:**

```bash
kubectl create namespace ex-1-3
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: ex-1-3
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
  namespace: ex-1-3
spec:
  selector:
    app: app
  ports:
  - port: 80
EOF
kubectl wait --for=condition=Ready pods --all -n ex-1-3 --timeout=60s
```

**Task:** Create a Gateway and HTTPRoute to route `/` to app-svc.

---

## Level 2: HTTPRoute Routing

### Exercise 2.1

**Objective:** Configure path-based routing.

**Task:** Create an HTTPRoute with `/api` and `/web` paths routing to different services.

---

### Exercise 2.2

**Objective:** Configure header-based routing.

**Task:** Create an HTTPRoute that routes requests with header `env: staging` to a staging backend.

---

### Exercise 2.3

**Objective:** Route to multiple backends.

**Task:** Create an HTTPRoute that splits traffic 80/20 between two backends.

---

## Level 3: Debugging Gateway API

### Exercise 3.1

**Objective:** HTTPRoute not attached.

**Setup:** Create an HTTPRoute referencing a non-existent Gateway.

**Task:** Diagnose why the route is not working.

---

### Exercise 3.2

**Objective:** Gateway not ready.

**Task:** Create a Gateway with wrong gatewayClassName and diagnose.

---

### Exercise 3.3

**Objective:** Backend not found.

**Task:** Diagnose an HTTPRoute with wrong service name.

---

## Level 4: Advanced Routing

### Exercise 4.1

**Objective:** Configure traffic splitting.

**Task:** Split traffic 90/10 between v1 and v2 of a service.

---

### Exercise 4.2

**Objective:** Use multiple matches in a rule.

**Task:** Create a rule matching both path AND header.

---

### Exercise 4.3

**Objective:** Configure TLS on Gateway.

**Task:** Create a Gateway with HTTPS listener and TLS certificate.

---

## Level 5: Migration and Design

### Exercise 5.1

**Objective:** Migrate Ingress to Gateway API.

**Task:** Given an Ingress resource, create equivalent Gateway API resources.

---

### Exercise 5.2

**Objective:** Debug complex routing issue.

**Task:** Given a broken Gateway API configuration, diagnose and fix.

---

### Exercise 5.3

**Objective:** Design Gateway API architecture for an organization.

**Task:** Design a Gateway API architecture with:
- Shared GatewayClass for the organization
- Per-team Gateways
- Application HTTPRoutes

Document the design and implement key resources.

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

1. **Gateway API separates concerns:** Infrastructure (GatewayClass), Platform (Gateway), Application (HTTPRoute).

2. **HTTPRoute attaches to Gateway** via parentRefs.

3. **Check Status conditions** for troubleshooting.

4. **Traffic splitting is native** with weight field.

5. **More expressive than Ingress** for complex routing needs.
