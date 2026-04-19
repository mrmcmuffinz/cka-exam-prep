# Services Homework Answers: Service Patterns and Troubleshooting

This file contains complete solutions for all 15 exercises. For debugging exercises, explanations of the issue and diagnostic process are included.

---

## Exercise 1.1 Solution

**Task:** Create a multi-port service with named ports.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: ex-1-1
spec:
  selector:
    app: web-app
  ports:
  - name: http
    port: 80
    targetPort: http
  - name: https
    port: 443
    targetPort: https
EOF
```

**Explanation:** For multi-port services, each port must have a unique name. The targetPort can reference the container port by name (matching the container's port name field) or by number.

---

## Exercise 1.2 Solution

**Task:** Create a service with both TCP and UDP ports.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: dns-svc
  namespace: ex-1-2
spec:
  selector:
    app: dns-app
  ports:
  - name: dns-tcp
    port: 53
    targetPort: 53
    protocol: TCP
  - name: dns-udp
    port: 53
    targetPort: 53
    protocol: UDP
EOF
```

**Explanation:** You can define multiple ports with the same port number but different protocols. Each port still needs a unique name.

---

## Exercise 1.3 Solution

**Task:** Access different ports of a multi-port service.

**Solution:**

```bash
# Access app port (80)
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-1-3 -- curl http://multi-svc:80
# Returns nginx welcome page

# Access metrics port (9090) at /metrics
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-1-3 -- curl http://multi-svc:9090/metrics
# Returns "metrics_data"
```

**Explanation:** You access different ports by specifying the port number in the URL. The service routes traffic to the appropriate container port based on the port mapping.

---

## Exercise 2.1 Solution

**Task:** Configure session affinity with 10-minute timeout.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: sticky-svc
  namespace: ex-2-1
spec:
  selector:
    app: sticky-app
  ports:
  - port: 80
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 600
EOF
```

**Explanation:** Session affinity with ClientIP ensures requests from the same source IP go to the same pod. The timeout specifies how long the affinity lasts without traffic before it expires.

---

## Exercise 2.2 Solution

**Task:** Configure external traffic policy to Local.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: source-ip-svc
  namespace: ex-2-2
spec:
  type: NodePort
  selector:
    app: source-ip-app
  ports:
  - port: 80
    nodePort: 30280
  externalTrafficPolicy: Local
EOF
```

**Explanation:** With externalTrafficPolicy: Local, traffic is only routed to pods on the node that received the request. This preserves the original client IP but means requests to nodes without pods will fail.

---

## Exercise 2.3 Solution

**Task:** Create services with different traffic policies and compare behavior.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: policy-cluster-svc
  namespace: ex-2-3
spec:
  type: NodePort
  selector:
    app: policy-app
  ports:
  - port: 80
    nodePort: 30283
  externalTrafficPolicy: Cluster
---
apiVersion: v1
kind: Service
metadata:
  name: policy-local-svc
  namespace: ex-2-3
spec:
  type: NodePort
  selector:
    app: policy-app
  ports:
  - port: 80
    nodePort: 30284
  externalTrafficPolicy: Local
EOF
```

**Comparison:**
- Cluster policy: Traffic to any node reaches all pods. Source IP is lost (SNAT).
- Local policy: Traffic only reaches pods on the receiving node. Source IP is preserved. Traffic to nodes without pods times out.

---

## Exercise 3.1 Solution

**Issue:** Selector mismatch. Service selects `tier: backend`, but pods have `tier: frontend`.

**Diagnosis:**

```bash
kubectl get endpoints selector-svc -n ex-3-1
# Empty

kubectl get svc selector-svc -n ex-3-1 -o wide
# Selector: app=selector-app,tier=backend

kubectl get pods -n ex-3-1 --show-labels
# Shows tier=frontend
```

**Fix:**

```bash
kubectl patch service selector-svc -n ex-3-1 -p '{"spec":{"selector":{"app":"selector-app","tier":"frontend"}}}'
```

**Explanation:** The selector must exactly match pod labels. A mismatch in any label causes empty endpoints.

---

## Exercise 3.2 Solution

**Issue:** Wrong targetPort. Service forwards to 8080, but container listens on 80.

**Diagnosis:**

```bash
kubectl get endpoints port-svc -n ex-3-2
# Endpoints exist

kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-3-2 -- curl -s --max-time 3 http://port-svc:8080
# Connection refused

kubectl get svc port-svc -n ex-3-2 -o jsonpath='{.spec.ports[0].targetPort}'
# 8080

kubectl get pods -n ex-3-2 -o jsonpath='{.items[0].spec.containers[0].ports}'
# containerPort: 80
```

**Fix:**

```bash
kubectl patch service port-svc -n ex-3-2 -p '{"spec":{"ports":[{"port":8080,"targetPort":80}]}}'
```

**Explanation:** The targetPort must match the container's listening port. The service port (what clients connect to) can be different.

---

## Exercise 3.3 Solution

**Issue:** Readiness probe fails. Probe checks /ready, but nginx does not serve that path.

**Diagnosis:**

```bash
kubectl get pods -n ex-3-3 -l app=ready-app
# 0/1 Ready

kubectl describe pod -n ex-3-3 -l app=ready-app | grep -A5 "Readiness"
# httpGet path: /ready

kubectl get endpoints ready-svc -n ex-3-3
# Empty or incomplete
```

**Fix:**

```bash
kubectl patch deployment ready-app -n ex-3-3 --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}]'
kubectl rollout status deployment/ready-app -n ex-3-3
```

**Explanation:** Readiness probes determine whether a pod is included in service endpoints. A failing probe removes the pod from endpoints.

---

## Exercise 4.1 Solution

**Issue:** One pod has its index.html deleted, causing readiness probe failure.

**Diagnosis:**

```bash
kubectl get pods -n ex-4-1 -l app=flaky-app
# One shows 0/1 Ready

kubectl describe pod -n ex-4-1 <not-ready-pod> | grep -A5 "Readiness"
# Probe failing

kubectl get endpoints flaky-svc -n ex-4-1
# Missing one IP
```

**Fix:**

```bash
# Find the failing pod
POD=$(kubectl get pods -n ex-4-1 -l app=flaky-app -o jsonpath='{.items[?(@.status.containerStatuses[0].ready==false)].metadata.name}')

# Restore the index.html
kubectl exec -n ex-4-1 $POD -- /bin/sh -c 'echo "Welcome" > /usr/share/nginx/html/index.html'
```

Or delete the pod and let the deployment recreate it:

```bash
kubectl delete pod $POD -n ex-4-1
```

**Explanation:** When a pod's readiness probe fails, it is removed from service endpoints. This is often caused by application issues, not configuration problems.

---

## Exercise 4.2 Solution

**Issue:** Named port reference mismatch. Service references `http`, but container port is named `web`.

**Diagnosis:**

```bash
kubectl get svc named-port-svc -n ex-4-2 -o jsonpath='{.spec.ports[0].targetPort}'
# http

kubectl get pods -n ex-4-2 -o jsonpath='{.items[0].spec.containers[0].ports[0].name}'
# web
```

**Fix:**

```bash
kubectl patch service named-port-svc -n ex-4-2 -p '{"spec":{"ports":[{"name":"http","port":80,"targetPort":"web"}]}}'
```

Or change to numeric port:

```bash
kubectl patch service named-port-svc -n ex-4-2 -p '{"spec":{"ports":[{"name":"http","port":80,"targetPort":80}]}}'
```

**Explanation:** When using named port references, the targetPort value must match the container port name exactly.

---

## Exercise 4.3 Solution

**Issue:** externalTrafficPolicy: Local with pod only on one node. Traffic to other nodes times out.

**Diagnosis:**

```bash
kubectl get pods -n ex-4-3 -o wide
# Pod is on kind-worker

kubectl get nodes -o jsonpath='{.items[*].metadata.name}'
# kind-control-plane kind-worker kind-worker2 kind-worker3

# Traffic to nodes without the pod times out
```

**Fix option 1:** Change to Cluster policy:

```bash
kubectl patch service single-node-svc -n ex-4-3 -p '{"spec":{"externalTrafficPolicy":"Cluster"}}'
```

**Fix option 2:** Document that this is expected behavior for Local policy.

**Explanation:** With Local policy, traffic is only routed to pods on the node that received the request. If no pods are on that node, the request fails. This is by design for source IP preservation.

---

## Exercise 5.1 Solution

**Task:** Build a multi-tier application with proper service configurations.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
# Database tier - Headless for direct pod access
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: ex-5-1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: redis
        image: redis:7.2
---
apiVersion: v1
kind: Service
metadata:
  name: database-svc
  namespace: ex-5-1
spec:
  clusterIP: None
  selector:
    app: database
  ports:
  - port: 6379
---
# Backend tier - Session affinity for stateful connections
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: ex-5-1
spec:
  replicas: 3
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
  namespace: ex-5-1
spec:
  selector:
    app: backend
  ports:
  - port: 8080
    targetPort: 80
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600
---
# Frontend tier - LoadBalancer for external access
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: ex-5-1
spec:
  replicas: 3
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
  namespace: ex-5-1
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
  - port: 80
EOF
```

---

## Exercise 5.2 Solution

**Issues:** Three problems:
1. Selector mismatch: version: v2 vs pods have version: v1
2. Wrong targetPort: 8080 vs container port 80
3. Readiness probe path: /api/health does not exist

**Diagnosis:**

```bash
# Check endpoints
kubectl get endpoints multi-fail-svc -n ex-5-2
# Empty

# Check selector
kubectl get svc multi-fail-svc -n ex-5-2 -o wide
kubectl get pods -n ex-5-2 --show-labels
# version mismatch

# Check pods
kubectl get pods -n ex-5-2
# 0/1 Ready - readiness failing

# Check targetPort
kubectl get svc multi-fail-svc -n ex-5-2 -o jsonpath='{.spec.ports[0].targetPort}'
# 8080 - wrong
```

**Fix:**

```yaml
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
            path: /
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
    version: v1
  ports:
  - port: 80
    targetPort: 80
EOF
```

---

## Exercise 5.3 Solution

**Task:** Design a resilient API service.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  namespace: ex-5-3
spec:
  replicas: 4
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: api-server
              topologyKey: kubernetes.io/hostname
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: api-svc
  namespace: ex-5-3
spec:
  type: LoadBalancer
  selector:
    app: api-server
  ports:
  - port: 80
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 1800
  externalTrafficPolicy: Cluster
EOF
```

**Design Rationale:**
- 4 replicas: Provides redundancy and horizontal scaling
- Pod anti-affinity: Spreads pods across nodes for fault tolerance
- Readiness probe: Ensures only healthy pods receive traffic
- Session affinity: Maintains client connections for stateful interactions
- Cluster policy: Ensures even distribution across all pods
- LoadBalancer: Provides external access with load balancing

---

## Common Mistakes

### 1. Missing Port Names in Multi-Port Services

Multi-port services require unique names for each port. Forgetting names causes validation errors.

### 2. Session Affinity with Very Short Timeout

Setting a timeout too short (e.g., 10 seconds) causes sessions to break during normal user activity.

### 3. externalTrafficPolicy: Local with Uneven Pod Distribution

If pods are not on every node, some nodes will not serve traffic. This can cause client failures if they connect to those nodes.

### 4. Checking Endpoints Before Checking Selectors

When debugging empty endpoints, check selector match first. This is the most common cause.

### 5. Named Port Reference Typos

When using named targetPort references, the name must exactly match the container port name. Case sensitivity matters.

### 6. Confusing Service Port and TargetPort

Remember: Service port is what clients connect to. TargetPort is what the container listens on. They can be different.

---

## Service Troubleshooting Flowchart

```
Service not working
        |
        v
Does the service exist?
        |
    No -+-> Create service
        |
    Yes
        |
        v
Are endpoints empty?
        |
    Yes -+-> Check selector match
        |       |
        |       v
        |   Do pods match selector?
        |       |
        |   No -+-> Fix selector or pod labels
        |       |
        |   Yes
        |       |
        |       v
        |   Are pods Ready?
        |       |
        |   No -+-> Fix readiness probe
        |
    No (endpoints exist)
        |
        v
Do connections work?
        |
    Yes -+-> Done
        |
    No
        |
        v
Check targetPort matches containerPort
        |
    No -+-> Fix targetPort
        |
    Yes
        |
        v
Check container process is running
        |
    No -+-> Fix container/image
        |
    Yes -+-> Check network policies, CNI
```

---

## Verification Commands Cheat Sheet

| Task | Command |
|------|---------|
| List services | `kubectl get svc -n <namespace>` |
| Show selectors | `kubectl get svc -n <namespace> -o wide` |
| Check endpoints | `kubectl get endpoints <name> -n <namespace>` |
| Check pod labels | `kubectl get pods --show-labels -n <namespace>` |
| Check pod readiness | `kubectl get pods -n <namespace>` |
| Check targetPort | `kubectl get svc <name> -o jsonpath='{.spec.ports}'` |
| Check containerPort | `kubectl get pod <name> -o jsonpath='{.spec.containers[0].ports}'` |
| Check session affinity | `kubectl get svc <name> -o jsonpath='{.spec.sessionAffinity}'` |
| Check traffic policy | `kubectl get svc <name> -o jsonpath='{.spec.externalTrafficPolicy}'` |
| Test connectivity | `kubectl run curl --image=curlimages/curl:8.5.0 --rm -it -- curl <svc>` |
