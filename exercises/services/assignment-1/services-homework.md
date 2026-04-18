# Services Homework: Service Fundamentals and Discovery

This homework contains 15 progressive exercises covering Kubernetes Services. Work through the exercises in order, as later exercises build on concepts from earlier ones. Each exercise is self-contained with its own namespace and setup commands.

Before starting, ensure you have completed the services-tutorial.md file in this directory. You should have a multi-node kind cluster running with metallb installed for LoadBalancer services.

---

## Level 1: Basic Service Creation

These exercises cover creating ClusterIP services using imperative and declarative approaches, verifying service configuration, and testing connectivity.

### Exercise 1.1

**Objective:** Create a ClusterIP service using the imperative approach and verify connectivity.

**Setup:**

```bash
kubectl create namespace ex-1-1
kubectl create deployment nginx-app --image=nginx:1.25 --replicas=2 -n ex-1-1
kubectl wait --for=condition=available deployment/nginx-app -n ex-1-1 --timeout=60s
```

**Task:**

Using `kubectl expose`, create a ClusterIP service named `nginx-app` that exposes port 80 and forwards to port 80 on the pods. Then verify the service is working correctly.

**Verification:**

```bash
# Check service exists with correct type
kubectl get service nginx-app -n ex-1-1 | grep ClusterIP

# Check endpoints have two addresses
kubectl get endpoints nginx-app -n ex-1-1 | grep -E "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:80,?)+"

# Test connectivity returns nginx welcome page
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-1-1 -- curl -s http://nginx-app | grep -q "Welcome to nginx" && echo "SUCCESS" || echo "FAILED"
```

---

### Exercise 1.2

**Objective:** Create a ClusterIP service using a declarative YAML manifest.

**Setup:**

```bash
kubectl create namespace ex-1-2
kubectl create deployment httpd-app --image=httpd:2.4 --replicas=3 -n ex-1-2
kubectl wait --for=condition=available deployment/httpd-app -n ex-1-2 --timeout=60s
```

**Task:**

Create a Service YAML manifest that:
- Is named `httpd-svc`
- Is of type ClusterIP
- Selects pods with label `app=httpd-app`
- Exposes port 8080 on the service and forwards to port 80 on the pods
- Uses TCP protocol

Apply the manifest and verify the service works correctly.

**Verification:**

```bash
# Check service exists with correct port mapping
kubectl get service httpd-svc -n ex-1-2 | grep "8080"

# Check endpoints exist
kubectl get endpoints httpd-svc -n ex-1-2 | grep -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:80"

# Test connectivity on service port 8080
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-1-2 -- curl -s http://httpd-svc:8080 | grep -q "It works" && echo "SUCCESS" || echo "FAILED"
```

---

### Exercise 1.3

**Objective:** Examine service endpoints and correlate them with pod IPs.

**Setup:**

```bash
kubectl create namespace ex-1-3
kubectl create deployment web-app --image=nginx:1.25 --replicas=4 -n ex-1-3
kubectl wait --for=condition=available deployment/web-app -n ex-1-3 --timeout=60s
kubectl expose deployment web-app --port=80 -n ex-1-3
```

**Task:**

Without using kubectl describe, determine:
1. How many endpoints the service has
2. The IP addresses of all endpoints
3. Whether all pod IPs are present in the endpoints

Document your findings and the commands you used.

**Verification:**

```bash
# Endpoint count should equal pod count
ENDPOINT_COUNT=$(kubectl get endpoints web-app -n ex-1-3 -o jsonpath='{.subsets[0].addresses}' | jq length)
POD_COUNT=$(kubectl get pods -n ex-1-3 -l app=web-app --no-headers | wc -l)
[ "$ENDPOINT_COUNT" -eq "$POD_COUNT" ] && echo "SUCCESS: $ENDPOINT_COUNT endpoints match $POD_COUNT pods" || echo "FAILED"

# All pod IPs should be in endpoints
for IP in $(kubectl get pods -n ex-1-3 -l app=web-app -o jsonpath='{.items[*].status.podIP}'); do
  kubectl get endpoints web-app -n ex-1-3 -o jsonpath='{.subsets[0].addresses[*].ip}' | grep -q $IP && echo "Pod IP $IP found in endpoints" || echo "Pod IP $IP MISSING from endpoints"
done
```

---

## Level 2: Service Types and Discovery

These exercises cover different service types and service discovery mechanisms.

### Exercise 2.1

**Objective:** Create a NodePort service and access it via the node IP.

**Setup:**

```bash
kubectl create namespace ex-2-1
kubectl create deployment nodeport-app --image=nginx:1.25 --replicas=2 -n ex-2-1
kubectl wait --for=condition=available deployment/nodeport-app -n ex-2-1 --timeout=60s
```

**Task:**

Create a NodePort service named `nodeport-svc` that:
- Exposes the deployment on port 80
- Uses NodePort 30100

Then access the service from within the cluster using a node IP and the NodePort.

**Verification:**

```bash
# Check service is NodePort type with correct port
kubectl get service nodeport-svc -n ex-2-1 | grep "NodePort" | grep "30100"

# Get a node IP and test access via NodePort
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-2-1 -- curl -s http://${NODE_IP}:30100 | grep -q "Welcome to nginx" && echo "SUCCESS" || echo "FAILED"
```

---

### Exercise 2.2

**Objective:** Create a headless service and observe DNS returning multiple pod IPs.

**Setup:**

```bash
kubectl create namespace ex-2-2
kubectl create deployment headless-app --image=nginx:1.25 --replicas=3 -n ex-2-2
kubectl wait --for=condition=available deployment/headless-app -n ex-2-2 --timeout=60s
```

**Task:**

Create a headless service named `headless-svc` (ClusterIP set to None) that selects pods with label `app=headless-app`. Then perform a DNS lookup to confirm it returns multiple A records.

**Verification:**

```bash
# Check service has ClusterIP None
kubectl get service headless-svc -n ex-2-2 | grep "None"

# DNS should return multiple IPs (one per pod)
kubectl run dns-test --image=busybox:1.36 --rm -it -n ex-2-2 -- nslookup headless-svc 2>/dev/null | grep -c "Address" | grep -q "3" && echo "SUCCESS: 3 IPs returned" || echo "CHECK: Verify multiple IPs returned"
```

---

### Exercise 2.3

**Objective:** Test service discovery using both DNS and environment variables.

**Setup:**

```bash
kubectl create namespace ex-2-3
kubectl create deployment backend-app --image=nginx:1.25 --replicas=2 -n ex-2-3
kubectl wait --for=condition=available deployment/backend-app -n ex-2-3 --timeout=60s
kubectl expose deployment backend-app --port=80 -n ex-2-3
```

**Task:**

1. Create a pod named `discovery-test` that runs `sleep 3600`
2. From within the pod, demonstrate service discovery using:
   - DNS short name
   - DNS FQDN
   - Environment variables

Document the DNS names and environment variable names you use.

**Verification:**

```bash
# Create test pod
kubectl run discovery-test --image=busybox:1.36 -n ex-2-3 --command -- sleep 3600
sleep 3

# DNS short name works
kubectl exec -n ex-2-3 discovery-test -- wget -q -O- http://backend-app 2>/dev/null | grep -q "nginx" && echo "DNS short name: SUCCESS" || echo "DNS short name: FAILED"

# DNS FQDN works
kubectl exec -n ex-2-3 discovery-test -- wget -q -O- http://backend-app.ex-2-3.svc.cluster.local 2>/dev/null | grep -q "nginx" && echo "DNS FQDN: SUCCESS" || echo "DNS FQDN: FAILED"

# Environment variables exist
kubectl exec -n ex-2-3 discovery-test -- env | grep -q "BACKEND_APP_SERVICE_HOST" && echo "Env vars: SUCCESS" || echo "Env vars: FAILED"

# Cleanup test pod
kubectl delete pod discovery-test -n ex-2-3 --force --grace-period=0
```

---

## Level 3: Debugging Broken Services

These exercises present broken service configurations that you must diagnose and fix.

### Exercise 3.1

**Objective:** Fix the broken configuration so that the service routes traffic to the pods.

**Setup:**

```bash
kubectl create namespace ex-3-1
kubectl create deployment debug-app --image=nginx:1.25 --replicas=2 -n ex-3-1
kubectl wait --for=condition=available deployment/debug-app -n ex-3-1 --timeout=60s

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: debug-svc
  namespace: ex-3-1
spec:
  selector:
    app: debug-application
  ports:
  - port: 80
    targetPort: 80
EOF
```

**Task:**

The service `debug-svc` was created but is not routing traffic to the pods. Diagnose the issue and fix it so that curl requests to the service succeed.

**Verification:**

```bash
# Endpoints should exist after fix
kubectl get endpoints debug-svc -n ex-3-1 | grep -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:80" && echo "Endpoints: SUCCESS" || echo "Endpoints: FAILED"

# Connectivity should work after fix
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-3-1 -- curl -s http://debug-svc | grep -q "Welcome to nginx" && echo "Connectivity: SUCCESS" || echo "Connectivity: FAILED"
```

---

### Exercise 3.2

**Objective:** Fix the broken configuration so that the service accepts connections.

**Setup:**

```bash
kubectl create namespace ex-3-2

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-server
  namespace: ex-3-2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-server
  template:
    metadata:
      labels:
        app: web-server
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
  name: web-svc
  namespace: ex-3-2
spec:
  selector:
    app: web-server
  ports:
  - port: 80
    targetPort: 8080
EOF

kubectl wait --for=condition=available deployment/web-server -n ex-3-2 --timeout=60s
```

**Task:**

The service `web-svc` has endpoints but connections to it fail. Diagnose the issue and fix it so that curl requests succeed.

**Verification:**

```bash
# Connectivity should work after fix
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-3-2 -- curl -s --max-time 5 http://web-svc | grep -q "Welcome to nginx" && echo "SUCCESS" || echo "FAILED"
```

---

### Exercise 3.3

**Objective:** Fix the broken configuration so that all pods receive traffic.

**Setup:**

```bash
kubectl create namespace ex-3-3

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ready-app
  namespace: ex-3-3
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ready-app
  template:
    metadata:
      labels:
        app: ready-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        readinessProbe:
          httpGet:
            path: /healthz
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: ready-svc
  namespace: ex-3-3
spec:
  selector:
    app: ready-app
  ports:
  - port: 80
    targetPort: 80
EOF

sleep 10
```

**Task:**

The service `ready-svc` should have three endpoints but currently has none or fewer than expected. Diagnose why pods are not becoming ready and fix it so all three pods are included in the service endpoints.

**Verification:**

```bash
# All 3 pods should be ready
kubectl get pods -n ex-3-3 -l app=ready-app --no-headers | grep -c "1/1" | grep -q "3" && echo "Pods ready: SUCCESS" || echo "Pods ready: FAILED"

# Endpoints should have 3 addresses
ENDPOINT_COUNT=$(kubectl get endpoints ready-svc -n ex-3-3 -o jsonpath='{.subsets[0].addresses}' | jq length 2>/dev/null || echo 0)
[ "$ENDPOINT_COUNT" -eq 3 ] && echo "Endpoints: SUCCESS" || echo "Endpoints: FAILED (got $ENDPOINT_COUNT)"
```

---

## Level 4: Multi-Port Services and Advanced Configuration

These exercises cover advanced service configurations.

### Exercise 4.1

**Objective:** Create a multi-port service with named ports.

**Setup:**

```bash
kubectl create namespace ex-4-1

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-port-app
  namespace: ex-4-1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: multi-port-app
  template:
    metadata:
      labels:
        app: multi-port-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
          name: http
      - name: metrics
        image: nginx:1.25
        command: ["/bin/sh", "-c", "nginx -c /etc/nginx/nginx.conf && sleep infinity"]
        ports:
        - containerPort: 8080
          name: metrics
EOF

kubectl wait --for=condition=available deployment/multi-port-app -n ex-4-1 --timeout=60s
```

**Task:**

Create a service named `multi-port-svc` that exposes both ports:
- Port 80 named "http" forwarding to container port "http"
- Port 8080 named "metrics" forwarding to container port 80 (the nginx default port in the metrics container)

**Verification:**

```bash
# Service should have two ports
kubectl get service multi-port-svc -n ex-4-1 -o jsonpath='{.spec.ports}' | jq length | grep -q "2" && echo "Port count: SUCCESS" || echo "Port count: FAILED"

# Port names should be correct
kubectl get service multi-port-svc -n ex-4-1 -o jsonpath='{.spec.ports[*].name}' | grep -q "http" && echo "HTTP port named: SUCCESS" || echo "HTTP port named: FAILED"
kubectl get service multi-port-svc -n ex-4-1 -o jsonpath='{.spec.ports[*].name}' | grep -q "metrics" && echo "Metrics port named: SUCCESS" || echo "Metrics port named: FAILED"

# Both ports should be accessible
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-4-1 -- curl -s http://multi-port-svc:80 | grep -q "nginx" && echo "Port 80: SUCCESS" || echo "Port 80: FAILED"
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-4-1 -- curl -s http://multi-port-svc:8080 | grep -q "nginx" && echo "Port 8080: SUCCESS" || echo "Port 8080: FAILED"
```

---

### Exercise 4.2

**Objective:** Configure session affinity for sticky sessions.

**Setup:**

```bash
kubectl create namespace ex-4-2
kubectl create deployment affinity-app --image=nginx:1.25 --replicas=3 -n ex-4-2
kubectl wait --for=condition=available deployment/affinity-app -n ex-4-2 --timeout=60s
```

**Task:**

Create a service named `affinity-svc` with:
- Type ClusterIP
- Selector matching `app=affinity-app`
- Port 80
- Session affinity set to ClientIP with a timeout of 1800 seconds (30 minutes)

**Verification:**

```bash
# Session affinity should be ClientIP
kubectl get service affinity-svc -n ex-4-2 -o jsonpath='{.spec.sessionAffinity}' | grep -q "ClientIP" && echo "Session affinity: SUCCESS" || echo "Session affinity: FAILED"

# Timeout should be 1800
kubectl get service affinity-svc -n ex-4-2 -o jsonpath='{.spec.sessionAffinityConfig.clientIP.timeoutSeconds}' | grep -q "1800" && echo "Timeout: SUCCESS" || echo "Timeout: FAILED"
```

---

### Exercise 4.3

**Objective:** Create a service without a selector and manually define endpoints.

**Setup:**

```bash
kubectl create namespace ex-4-3
```

**Task:**

Create a service named `external-db` that:
- Has no selector
- Exposes port 5432

Then create an Endpoints resource that directs traffic to these external addresses:
- 10.0.0.100:5432
- 10.0.0.101:5432

**Verification:**

```bash
# Service should have no selector
kubectl get service external-db -n ex-4-3 -o jsonpath='{.spec.selector}' | grep -q "null\|^$" || [ -z "$(kubectl get service external-db -n ex-4-3 -o jsonpath='{.spec.selector}')" ] && echo "No selector: SUCCESS" || echo "No selector: FAILED"

# Endpoints should have two addresses
ENDPOINT_COUNT=$(kubectl get endpoints external-db -n ex-4-3 -o jsonpath='{.subsets[0].addresses}' | jq length 2>/dev/null || echo 0)
[ "$ENDPOINT_COUNT" -eq 2 ] && echo "Endpoint count: SUCCESS" || echo "Endpoint count: FAILED"

# Endpoints should include correct IPs
kubectl get endpoints external-db -n ex-4-3 -o jsonpath='{.subsets[0].addresses[*].ip}' | grep -q "10.0.0.100" && echo "IP 10.0.0.100: SUCCESS" || echo "IP 10.0.0.100: FAILED"
kubectl get endpoints external-db -n ex-4-3 -o jsonpath='{.subsets[0].addresses[*].ip}' | grep -q "10.0.0.101" && echo "IP 10.0.0.101: SUCCESS" || echo "IP 10.0.0.101: FAILED"
```

---

## Level 5: Complex Scenarios

These exercises present complex, realistic scenarios requiring multiple skills.

### Exercise 5.1

**Objective:** Build a multi-tier application with frontend, backend, and database services.

**Setup:**

```bash
kubectl create namespace ex-5-1
```

**Task:**

Create a three-tier application architecture:

1. **Database tier:** 
   - Deployment named `db` with 1 replica using `redis:7.2`
   - Headless service named `db-svc` for direct pod access

2. **Backend tier:**
   - Deployment named `backend` with 2 replicas using `nginx:1.25`
   - ClusterIP service named `backend-svc` on port 80

3. **Frontend tier:**
   - Deployment named `frontend` with 3 replicas using `nginx:1.25`
   - NodePort service named `frontend-svc` on port 80 with NodePort 30200

**Verification:**

```bash
# Database headless service
kubectl get service db-svc -n ex-5-1 | grep "None" && echo "DB headless: SUCCESS" || echo "DB headless: FAILED"

# Backend ClusterIP service
kubectl get service backend-svc -n ex-5-1 | grep "ClusterIP" && echo "Backend ClusterIP: SUCCESS" || echo "Backend ClusterIP: FAILED"
kubectl get endpoints backend-svc -n ex-5-1 | grep -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:80.*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:80" && echo "Backend 2 endpoints: SUCCESS" || echo "Backend 2 endpoints: FAILED"

# Frontend NodePort service
kubectl get service frontend-svc -n ex-5-1 | grep "NodePort" | grep "30200" && echo "Frontend NodePort: SUCCESS" || echo "Frontend NodePort: FAILED"
kubectl get endpoints frontend-svc -n ex-5-1 | grep -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:80" && echo "Frontend endpoints: SUCCESS" || echo "Frontend endpoints: FAILED"

# Test connectivity
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-5-1 -- curl -s http://frontend-svc | grep -q "nginx" && echo "Frontend connectivity: SUCCESS" || echo "Frontend connectivity: FAILED"
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-5-1 -- curl -s http://backend-svc | grep -q "nginx" && echo "Backend connectivity: SUCCESS" || echo "Backend connectivity: FAILED"
```

---

### Exercise 5.2

**Objective:** Fix the broken multi-service configuration.

**Setup:**

```bash
kubectl create namespace ex-5-2

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  namespace: ex-5-2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api-server
      tier: backend
  template:
    metadata:
      labels:
        app: api-server
        tier: backend
    spec:
      containers:
      - name: api
        image: nginx:1.25
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /api/health
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: api-svc
  namespace: ex-5-2
spec:
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 8080
EOF

sleep 10
```

**Task:**

The `api-svc` service is not working correctly. There are multiple issues preventing traffic from reaching the pods. Diagnose and fix all issues so that curl requests to the service succeed.

**Verification:**

```bash
# Pods should be ready
kubectl get pods -n ex-5-2 -l app=api-server --no-headers | grep -c "1/1" | grep -q "2" && echo "Pods ready: SUCCESS" || echo "Pods ready: FAILED"

# Endpoints should exist
kubectl get endpoints api-svc -n ex-5-2 | grep -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:80" && echo "Endpoints: SUCCESS" || echo "Endpoints: FAILED"

# Connectivity should work
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-5-2 -- curl -s --max-time 5 http://api-svc | grep -q "nginx" && echo "Connectivity: SUCCESS" || echo "Connectivity: FAILED"
```

---

### Exercise 5.3

**Objective:** Migrate a service from ClusterIP to NodePort without downtime.

**Setup:**

```bash
kubectl create namespace ex-5-3
kubectl create deployment migrate-app --image=nginx:1.25 --replicas=3 -n ex-5-3
kubectl wait --for=condition=available deployment/migrate-app -n ex-5-3 --timeout=60s
kubectl expose deployment migrate-app --port=80 -n ex-5-3
```

**Task:**

The `migrate-app` service is currently a ClusterIP service. Your task is to:
1. Verify the current ClusterIP service is working
2. Change the service type to NodePort with port 30300
3. Verify the service still works via both ClusterIP and NodePort
4. Document the steps you took

The service should remain accessible throughout the migration (no service deletion allowed).

**Verification:**

```bash
# Service should be NodePort type
kubectl get service migrate-app -n ex-5-3 | grep "NodePort" && echo "Type changed: SUCCESS" || echo "Type changed: FAILED"

# NodePort should be 30300
kubectl get service migrate-app -n ex-5-3 | grep "30300" && echo "NodePort correct: SUCCESS" || echo "NodePort correct: FAILED"

# ClusterIP should still be assigned (not None)
CLUSTER_IP=$(kubectl get service migrate-app -n ex-5-3 -o jsonpath='{.spec.clusterIP}')
[ "$CLUSTER_IP" != "None" ] && [ -n "$CLUSTER_IP" ] && echo "ClusterIP exists: SUCCESS" || echo "ClusterIP exists: FAILED"

# Connectivity via ClusterIP
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-5-3 -- curl -s http://migrate-app | grep -q "nginx" && echo "ClusterIP access: SUCCESS" || echo "ClusterIP access: FAILED"

# Connectivity via NodePort
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-5-3 -- curl -s http://${NODE_IP}:30300 | grep -q "nginx" && echo "NodePort access: SUCCESS" || echo "NodePort access: FAILED"
```

---

## Cleanup

Delete all exercise namespaces:

```bash
kubectl delete namespace ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3
```

---

## Key Takeaways

After completing these exercises, you should be able to:

1. **Create services** using both imperative (`kubectl expose`) and declarative (YAML) approaches
2. **Understand service types:** ClusterIP for internal access, NodePort for external access via node ports, LoadBalancer for cloud load balancers, ExternalName for DNS aliases, and headless for direct pod access
3. **Configure port mappings:** Understand the difference between service port, targetPort, and nodePort
4. **Use service discovery:** Access services via DNS (short name, namespace-qualified, FQDN) and environment variables
5. **Inspect endpoints:** Verify that services have the correct backends and diagnose selector mismatches
6. **Debug service issues:** Identify problems with selectors, ports, and pod readiness
7. **Configure advanced options:** Multi-port services, session affinity, services without selectors
