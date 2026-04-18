# Services Homework: Service Patterns and Troubleshooting

This homework contains 15 progressive exercises covering advanced service patterns and troubleshooting techniques. Work through the exercises in order, as later exercises build on concepts from earlier ones.

Before starting, ensure you have completed the services-tutorial.md file in this directory and have a multi-node kind cluster running.

---

## Level 1: Multi-Port Services

These exercises cover creating and using services with multiple ports.

### Exercise 1.1

**Objective:** Create a multi-port service with named ports.

**Setup:**

```bash
kubectl create namespace ex-1-1

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: ex-1-1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
          name: http
        - containerPort: 443
          name: https
EOF

kubectl wait --for=condition=available deployment/web-app -n ex-1-1 --timeout=60s
```

**Task:**

Create a service named `web-svc` that exposes both ports with these specifications:
- Port 80 named "http" forwarding to container port "http"
- Port 443 named "https" forwarding to container port "https"

**Verification:**

```bash
# Service should have two ports
kubectl get service web-svc -n ex-1-1 -o jsonpath='{.spec.ports}' | jq length | grep -q "2" && echo "Port count: SUCCESS" || echo "Port count: FAILED"

# Ports should be named
kubectl get service web-svc -n ex-1-1 -o jsonpath='{.spec.ports[0].name}' | grep -q "http" && echo "HTTP name: SUCCESS" || echo "HTTP name: FAILED"
kubectl get service web-svc -n ex-1-1 -o jsonpath='{.spec.ports[1].name}' | grep -q "https" && echo "HTTPS name: SUCCESS" || echo "HTTPS name: FAILED"

# HTTP port should be accessible
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-1-1 -- curl -s http://web-svc:80 | grep -q "nginx" && echo "HTTP access: SUCCESS" || echo "HTTP access: FAILED"
```

---

### Exercise 1.2

**Objective:** Create a service with both TCP and UDP ports.

**Setup:**

```bash
kubectl create namespace ex-1-2

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dns-app
  namespace: ex-1-2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: dns-app
  template:
    metadata:
      labels:
        app: dns-app
    spec:
      containers:
      - name: dns
        image: coredns/coredns:1.11.1
        args: ["-conf", "/dev/null"]
        ports:
        - containerPort: 53
          protocol: TCP
        - containerPort: 53
          protocol: UDP
EOF

kubectl wait --for=condition=available deployment/dns-app -n ex-1-2 --timeout=60s
```

**Task:**

Create a service named `dns-svc` that exposes port 53 for both TCP and UDP protocols. Use named ports "dns-tcp" and "dns-udp".

**Verification:**

```bash
# Service should have two ports
kubectl get service dns-svc -n ex-1-2 -o jsonpath='{.spec.ports}' | jq length | grep -q "2" && echo "Port count: SUCCESS" || echo "Port count: FAILED"

# Should have both TCP and UDP
kubectl get service dns-svc -n ex-1-2 -o jsonpath='{.spec.ports[*].protocol}' | grep -q "TCP" && echo "TCP protocol: SUCCESS" || echo "TCP protocol: FAILED"
kubectl get service dns-svc -n ex-1-2 -o jsonpath='{.spec.ports[*].protocol}' | grep -q "UDP" && echo "UDP protocol: SUCCESS" || echo "UDP protocol: FAILED"
```

---

### Exercise 1.3

**Objective:** Access different ports of a multi-port service.

**Setup:**

```bash
kubectl create namespace ex-1-3

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-app
  namespace: ex-1-3
spec:
  replicas: 2
  selector:
    matchLabels:
      app: multi-app
  template:
    metadata:
      labels:
        app: multi-app
    spec:
      containers:
      - name: app
        image: nginx:1.25
        ports:
        - containerPort: 80
          name: app
      - name: metrics
        image: nginx:1.25
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo "server { listen 9090; location /metrics { return 200 'metrics_data'; } }" > /etc/nginx/conf.d/metrics.conf
          nginx -g 'daemon off;'
        ports:
        - containerPort: 9090
          name: metrics
---
apiVersion: v1
kind: Service
metadata:
  name: multi-svc
  namespace: ex-1-3
spec:
  selector:
    app: multi-app
  ports:
  - name: app
    port: 80
    targetPort: app
  - name: metrics
    port: 9090
    targetPort: metrics
EOF

kubectl wait --for=condition=available deployment/multi-app -n ex-1-3 --timeout=60s
```

**Task:**

Test access to both ports of the `multi-svc` service:
1. Access the app port (80) and verify you get the nginx welcome page
2. Access the metrics port (9090) at path /metrics and verify you get metrics data

Document the commands you use.

**Verification:**

```bash
# App port should return nginx welcome page
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-1-3 -- curl -s http://multi-svc:80 | grep -q "nginx" && echo "App port: SUCCESS" || echo "App port: FAILED"

# Metrics port should return metrics data
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-1-3 -- curl -s http://multi-svc:9090/metrics | grep -q "metrics_data" && echo "Metrics port: SUCCESS" || echo "Metrics port: FAILED"
```

---

## Level 2: Session Affinity and Traffic Policies

These exercises cover session affinity configuration and traffic policy effects.

### Exercise 2.1

**Objective:** Configure and test session affinity.

**Setup:**

```bash
kubectl create namespace ex-2-1

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sticky-app
  namespace: ex-2-1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: sticky-app
  template:
    metadata:
      labels:
        app: sticky-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        command: ["/bin/sh", "-c"]
        args:
        - echo "Pod: \$POD_NAME" > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'
EOF

kubectl wait --for=condition=available deployment/sticky-app -n ex-2-1 --timeout=60s
```

**Task:**

Create a service named `sticky-svc` with:
- Type ClusterIP
- Session affinity enabled (ClientIP)
- Timeout of 600 seconds (10 minutes)

Then verify that multiple requests from the same client go to the same pod.

**Verification:**

```bash
# Session affinity should be ClientIP
kubectl get service sticky-svc -n ex-2-1 -o jsonpath='{.spec.sessionAffinity}' | grep -q "ClientIP" && echo "Affinity type: SUCCESS" || echo "Affinity type: FAILED"

# Timeout should be 600
kubectl get service sticky-svc -n ex-2-1 -o jsonpath='{.spec.sessionAffinityConfig.clientIP.timeoutSeconds}' | grep -q "600" && echo "Timeout: SUCCESS" || echo "Timeout: FAILED"

# Multiple requests should go to same pod
kubectl run sticky-test --image=curlimages/curl:8.5.0 -n ex-2-1 --command -- sleep 3600
sleep 2
FIRST=$(kubectl exec -n ex-2-1 sticky-test -- curl -s http://sticky-svc 2>/dev/null)
SECOND=$(kubectl exec -n ex-2-1 sticky-test -- curl -s http://sticky-svc 2>/dev/null)
THIRD=$(kubectl exec -n ex-2-1 sticky-test -- curl -s http://sticky-svc 2>/dev/null)
kubectl delete pod sticky-test -n ex-2-1 --force --grace-period=0
[ "$FIRST" = "$SECOND" ] && [ "$SECOND" = "$THIRD" ] && echo "Sticky: SUCCESS" || echo "Sticky: FAILED"
```

---

### Exercise 2.2

**Objective:** Configure external traffic policy to preserve source IP.

**Setup:**

```bash
kubectl create namespace ex-2-2

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: source-ip-app
  namespace: ex-2-2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: source-ip-app
  template:
    metadata:
      labels:
        app: source-ip-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
EOF

kubectl wait --for=condition=available deployment/source-ip-app -n ex-2-2 --timeout=60s
```

**Task:**

Create a NodePort service named `source-ip-svc` with:
- Port 80
- NodePort 30280
- External traffic policy set to Local (to preserve source IP)

**Verification:**

```bash
# Service should be NodePort
kubectl get service source-ip-svc -n ex-2-2 | grep "NodePort" && echo "Type: SUCCESS" || echo "Type: FAILED"

# External traffic policy should be Local
kubectl get service source-ip-svc -n ex-2-2 -o jsonpath='{.spec.externalTrafficPolicy}' | grep -q "Local" && echo "Policy: SUCCESS" || echo "Policy: FAILED"

# NodePort should be 30280
kubectl get service source-ip-svc -n ex-2-2 -o jsonpath='{.spec.ports[0].nodePort}' | grep -q "30280" && echo "NodePort: SUCCESS" || echo "NodePort: FAILED"
```

---

### Exercise 2.3

**Objective:** Observe the effect of traffic policies on load distribution.

**Setup:**

```bash
kubectl create namespace ex-2-3

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: policy-app
  namespace: ex-2-3
spec:
  replicas: 3
  selector:
    matchLabels:
      app: policy-app
  template:
    metadata:
      labels:
        app: policy-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        command: ["/bin/sh", "-c"]
        args:
        - echo "Pod: \$POD_NAME" > /usr/share/nginx/html/index.html && nginx -g 'daemon off;'
EOF

kubectl wait --for=condition=available deployment/policy-app -n ex-2-3 --timeout=60s
```

**Task:**

Create two NodePort services for the same deployment:
1. `policy-cluster-svc` with externalTrafficPolicy: Cluster on NodePort 30283
2. `policy-local-svc` with externalTrafficPolicy: Local on NodePort 30284

Then test both services and document the difference in behavior regarding which pods receive traffic.

**Verification:**

```bash
# Cluster policy service
kubectl get service policy-cluster-svc -n ex-2-3 -o jsonpath='{.spec.externalTrafficPolicy}' | grep -q "Cluster" && echo "Cluster policy: SUCCESS" || echo "Cluster policy: FAILED"

# Local policy service
kubectl get service policy-local-svc -n ex-2-3 -o jsonpath='{.spec.externalTrafficPolicy}' | grep -q "Local" && echo "Local policy: SUCCESS" || echo "Local policy: FAILED"

# Both should be accessible (Cluster always works, Local depends on pod placement)
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-2-3 -- curl -s --max-time 3 http://${NODE_IP}:30283 | grep -q "Pod" && echo "Cluster access: SUCCESS" || echo "Cluster access: FAILED"
```

---

## Level 3: Debugging Service Issues

These exercises present broken configurations to diagnose and fix.

### Exercise 3.1

**Objective:** Fix the broken configuration so that the service has endpoints.

**Setup:**

```bash
kubectl create namespace ex-3-1

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: selector-app
  namespace: ex-3-1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: selector-app
      tier: frontend
  template:
    metadata:
      labels:
        app: selector-app
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: selector-svc
  namespace: ex-3-1
spec:
  selector:
    app: selector-app
    tier: backend
  ports:
  - port: 80
EOF

kubectl wait --for=condition=available deployment/selector-app -n ex-3-1 --timeout=60s
```

**Task:**

The service `selector-svc` has no endpoints. Diagnose the issue and fix it so the service routes traffic to the deployment's pods.

**Verification:**

```bash
# Endpoints should exist after fix
kubectl get endpoints selector-svc -n ex-3-1 | grep -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:80" && echo "Endpoints: SUCCESS" || echo "Endpoints: FAILED"

# Connectivity should work
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-3-1 -- curl -s http://selector-svc | grep -q "nginx" && echo "Access: SUCCESS" || echo "Access: FAILED"
```

---

### Exercise 3.2

**Objective:** Fix the broken configuration so that connections succeed.

**Setup:**

```bash
kubectl create namespace ex-3-2

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: port-app
  namespace: ex-3-2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: port-app
  template:
    metadata:
      labels:
        app: port-app
    spec:
      containers:
      - name: httpd
        image: httpd:2.4
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: port-svc
  namespace: ex-3-2
spec:
  selector:
    app: port-app
  ports:
  - port: 8080
    targetPort: 8080
EOF

kubectl wait --for=condition=available deployment/port-app -n ex-3-2 --timeout=60s
```

**Task:**

The service `port-svc` has endpoints but connections fail. Diagnose the issue and fix it.

**Verification:**

```bash
# Connectivity should work after fix
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-3-2 -- curl -s --max-time 5 http://port-svc:8080 | grep -q "It works" && echo "Access: SUCCESS" || echo "Access: FAILED"
```

---

### Exercise 3.3

**Objective:** Fix the broken configuration so that all pods are in the service endpoints.

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
            path: /ready
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
EOF

sleep 15
```

**Task:**

The service `ready-svc` has fewer endpoints than expected (should have 3 but has none). Diagnose why pods are not becoming ready and fix it.

**Verification:**

```bash
# All 3 pods should be ready
kubectl get pods -n ex-3-3 -l app=ready-app --no-headers | grep -c "1/1" | grep -q "3" && echo "Pods ready: SUCCESS" || echo "Pods ready: FAILED"

# Endpoints should have 3 addresses
ENDPOINT_COUNT=$(kubectl get endpoints ready-svc -n ex-3-3 -o jsonpath='{.subsets[0].addresses}' | jq length 2>/dev/null || echo 0)
[ "$ENDPOINT_COUNT" -eq 3 ] && echo "Endpoints: SUCCESS" || echo "Endpoints: FAILED"
```

---

## Level 4: Advanced Troubleshooting

These exercises cover more complex troubleshooting scenarios.

### Exercise 4.1

**Objective:** Diagnose why a service intermittently fails.

**Setup:**

```bash
kubectl create namespace ex-4-1

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flaky-app
  namespace: ex-4-1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: flaky-app
  template:
    metadata:
      labels:
        app: flaky-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 3
---
apiVersion: v1
kind: Service
metadata:
  name: flaky-svc
  namespace: ex-4-1
spec:
  selector:
    app: flaky-app
  ports:
  - port: 80
EOF

kubectl wait --for=condition=available deployment/flaky-app -n ex-4-1 --timeout=60s

# Make one pod fail readiness
POD=$(kubectl get pods -n ex-4-1 -l app=flaky-app -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n ex-4-1 $POD -- rm /usr/share/nginx/html/index.html
sleep 10
```

**Task:**

The service `flaky-svc` works sometimes but not always. One of the pods keeps dropping out of the endpoints. Diagnose which pod is problematic and why, then fix it.

**Verification:**

```bash
# All 3 pods should be ready
kubectl get pods -n ex-4-1 -l app=flaky-app --no-headers | grep -c "1/1" | grep -q "3" && echo "All pods ready: SUCCESS" || echo "All pods ready: FAILED"

# Endpoints should have 3 addresses
ENDPOINT_COUNT=$(kubectl get endpoints flaky-svc -n ex-4-1 -o jsonpath='{.subsets[0].addresses}' | jq length 2>/dev/null || echo 0)
[ "$ENDPOINT_COUNT" -eq 3 ] && echo "Endpoints: SUCCESS" || echo "Endpoints: FAILED"
```

---

### Exercise 4.2

**Objective:** Fix a named port reference error.

**Setup:**

```bash
kubectl create namespace ex-4-2

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: named-port-app
  namespace: ex-4-2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: named-port-app
  template:
    metadata:
      labels:
        app: named-port-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
          name: web
---
apiVersion: v1
kind: Service
metadata:
  name: named-port-svc
  namespace: ex-4-2
spec:
  selector:
    app: named-port-app
  ports:
  - name: http
    port: 80
    targetPort: http
EOF

kubectl wait --for=condition=available deployment/named-port-app -n ex-4-2 --timeout=60s
```

**Task:**

The service `named-port-svc` is not working correctly. Diagnose the named port reference issue and fix it.

**Verification:**

```bash
# Connectivity should work after fix
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-4-2 -- curl -s http://named-port-svc | grep -q "nginx" && echo "Access: SUCCESS" || echo "Access: FAILED"
```

---

### Exercise 4.3

**Objective:** Trace and fix traffic policy effects.

**Setup:**

```bash
kubectl create namespace ex-4-3

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: single-node-app
  namespace: ex-4-3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: single-node-app
  template:
    metadata:
      labels:
        app: single-node-app
    spec:
      nodeSelector:
        kubernetes.io/hostname: kind-worker
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: single-node-svc
  namespace: ex-4-3
spec:
  type: NodePort
  selector:
    app: single-node-app
  ports:
  - port: 80
    nodePort: 30430
  externalTrafficPolicy: Local
EOF

kubectl wait --for=condition=available deployment/single-node-app -n ex-4-3 --timeout=60s
```

**Task:**

The NodePort service `single-node-svc` is only accessible from some nodes. Traffic to the NodePort on nodes without the pod times out. Diagnose why this happens and either document the expected behavior or adjust the configuration so the service is accessible from all nodes.

**Verification:**

```bash
# After fix, service should be accessible from any node
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-4-3 -- curl -s --max-time 5 http://${NODE_IP}:30430 | grep -q "nginx" && echo "Access: SUCCESS" || echo "Access: FAILED"
```

---

## Level 5: Complex Scenarios

These exercises present complex, realistic scenarios.

### Exercise 5.1

**Objective:** Build and configure services for a multi-tier application.

**Setup:**

```bash
kubectl create namespace ex-5-1
```

**Task:**

Create a three-tier application with proper service configurations:

1. **Database tier:**
   - Deployment named `database` with 1 replica running redis:7.2
   - Headless service named `database-svc` for direct pod access

2. **Backend tier:**
   - Deployment named `backend` with 3 replicas running nginx:1.25
   - ClusterIP service named `backend-svc` on port 8080 (forwarding to 80)
   - Session affinity enabled with 1 hour timeout

3. **Frontend tier:**
   - Deployment named `frontend` with 3 replicas running nginx:1.25
   - LoadBalancer service named `frontend-svc` on port 80

Verify all services are working and correctly configured.

**Verification:**

```bash
# Database headless service
kubectl get service database-svc -n ex-5-1 -o jsonpath='{.spec.clusterIP}' | grep -q "None" && echo "Database headless: SUCCESS" || echo "Database headless: FAILED"

# Backend session affinity
kubectl get service backend-svc -n ex-5-1 -o jsonpath='{.spec.sessionAffinity}' | grep -q "ClientIP" && echo "Backend affinity: SUCCESS" || echo "Backend affinity: FAILED"
kubectl get service backend-svc -n ex-5-1 -o jsonpath='{.spec.sessionAffinityConfig.clientIP.timeoutSeconds}' | grep -q "3600" && echo "Backend timeout: SUCCESS" || echo "Backend timeout: FAILED"

# Frontend LoadBalancer
kubectl get service frontend-svc -n ex-5-1 | grep "LoadBalancer" && echo "Frontend type: SUCCESS" || echo "Frontend type: FAILED"
EXTERNAL_IP=$(kubectl get service frontend-svc -n ex-5-1 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
[ -n "$EXTERNAL_IP" ] && echo "Frontend IP: SUCCESS" || echo "Frontend IP: FAILED"
```

---

### Exercise 5.2

**Objective:** Debug a service with multiple failure modes.

**Setup:**

```bash
kubectl create namespace ex-5-2

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-fail
  namespace: ex-5-2
spec:
  replicas: 3
  selector:
    matchLabels:
      app: multi-fail
      version: v1
  template:
    metadata:
      labels:
        app: multi-fail
        version: v1
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
          name: http
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
  name: multi-fail-svc
  namespace: ex-5-2
spec:
  selector:
    app: multi-fail
    version: v2
  ports:
  - port: 80
    targetPort: 8080
EOF

sleep 15
```

**Task:**

The service `multi-fail-svc` is completely broken. There are multiple issues preventing it from working. Find and fix all issues so that curl requests to the service succeed.

**Verification:**

```bash
# All pods should be ready
kubectl get pods -n ex-5-2 -l app=multi-fail --no-headers | grep -c "1/1" | grep -q "3" && echo "Pods ready: SUCCESS" || echo "Pods ready: FAILED"

# Endpoints should exist
kubectl get endpoints multi-fail-svc -n ex-5-2 | grep -E "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:80" && echo "Endpoints: SUCCESS" || echo "Endpoints: FAILED"

# Connectivity should work
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-5-2 -- curl -s http://multi-fail-svc | grep -q "nginx" && echo "Access: SUCCESS" || echo "Access: FAILED"
```

---

### Exercise 5.3

**Objective:** Design a resilient service configuration.

**Setup:**

```bash
kubectl create namespace ex-5-3
```

**Task:**

Design and implement a highly available API service with these requirements:

1. **Deployment:**
   - Named `api-server`
   - 4 replicas running nginx:1.25
   - Readiness probe checking / on port 80
   - Pods spread across nodes (use pod anti-affinity with preferred during scheduling)

2. **Service:**
   - Named `api-svc`
   - Type: LoadBalancer
   - Port 80
   - Session affinity enabled (30 minute timeout)
   - External traffic policy: Cluster (for even distribution)

3. **Documentation:**
   - Document why each configuration choice was made

**Verification:**

```bash
# Deployment has 4 replicas
kubectl get deployment api-server -n ex-5-3 -o jsonpath='{.spec.replicas}' | grep -q "4" && echo "Replicas: SUCCESS" || echo "Replicas: FAILED"

# Readiness probe configured
kubectl get deployment api-server -n ex-5-3 -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' | grep -q "httpGet" && echo "Readiness: SUCCESS" || echo "Readiness: FAILED"

# Service is LoadBalancer
kubectl get service api-svc -n ex-5-3 | grep "LoadBalancer" && echo "Type: SUCCESS" || echo "Type: FAILED"

# Session affinity configured
kubectl get service api-svc -n ex-5-3 -o jsonpath='{.spec.sessionAffinity}' | grep -q "ClientIP" && echo "Affinity: SUCCESS" || echo "Affinity: FAILED"

# External traffic policy is Cluster
kubectl get service api-svc -n ex-5-3 -o jsonpath='{.spec.externalTrafficPolicy}' | grep -q "Cluster" && echo "Policy: SUCCESS" || echo "Policy: FAILED"

# All pods ready
kubectl get pods -n ex-5-3 -l app=api-server --no-headers | grep -c "1/1" | grep -q "4" && echo "Pods ready: SUCCESS" || echo "Pods ready: FAILED"
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

1. **Create multi-port services** with named ports and mixed protocols
2. **Configure session affinity** for sticky sessions with appropriate timeouts
3. **Understand traffic policies:** Cluster for even distribution, Local for source IP preservation
4. **Debug empty endpoints:** Trace selector mismatches and label issues
5. **Debug connection failures:** Identify targetPort mismatches and named port reference errors
6. **Debug readiness issues:** Understand how readiness probes affect service endpoints
7. **Design resilient services:** Combine readiness probes, session affinity, and traffic policies for production use
