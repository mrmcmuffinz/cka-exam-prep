# Services Homework Answers: Service Fundamentals and Discovery

This file contains complete solutions for all 15 exercises. For debugging exercises, explanations of the issue and diagnostic process are included.

---

## Exercise 1.1 Solution

**Task:** Create a ClusterIP service using the imperative approach.

**Solution:**

```bash
kubectl expose deployment nginx-app --port=80 --target-port=80 -n ex-1-1
```

Since port and targetPort are the same, you can simplify to:

```bash
kubectl expose deployment nginx-app --port=80 -n ex-1-1
```

**Explanation:** The `kubectl expose` command creates a service that selects pods based on the deployment's pod template labels. It automatically uses the deployment's name for the service name and copies the labels as the selector.

---

## Exercise 1.2 Solution

**Task:** Create a ClusterIP service using a declarative YAML manifest with different service and target ports.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: httpd-svc
  namespace: ex-1-2
spec:
  type: ClusterIP
  selector:
    app: httpd-app
  ports:
  - port: 8080
    targetPort: 80
    protocol: TCP
EOF
```

**Explanation:** The service listens on port 8080 and forwards traffic to port 80 on the pods. This is useful when you want to expose a standard port externally while the container uses a different port internally. The deployment created by `kubectl create deployment httpd-app` automatically gets the label `app=httpd-app`.

---

## Exercise 1.3 Solution

**Task:** Examine service endpoints and correlate them with pod IPs.

**Solution:**

```bash
# Get endpoints
kubectl get endpoints web-app -n ex-1-3

# Get detailed endpoint information
kubectl get endpoints web-app -n ex-1-3 -o yaml

# Get pod IPs
kubectl get pods -n ex-1-3 -l app=web-app -o wide

# Alternative: Extract just the IPs from endpoints
kubectl get endpoints web-app -n ex-1-3 -o jsonpath='{.subsets[0].addresses[*].ip}'

# Compare counts
echo "Endpoint count:"
kubectl get endpoints web-app -n ex-1-3 -o jsonpath='{.subsets[0].addresses}' | jq length

echo "Pod count:"
kubectl get pods -n ex-1-3 -l app=web-app --no-headers | wc -l
```

**Explanation:** The Endpoints resource maintains a list of pod IP:port combinations that match the service selector. Each endpoint address corresponds to a Ready pod. The pod IPs visible in `kubectl get pods -o wide` should exactly match the endpoint addresses.

---

## Exercise 2.1 Solution

**Task:** Create a NodePort service with a specific NodePort.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nodeport-svc
  namespace: ex-2-1
spec:
  type: NodePort
  selector:
    app: nodeport-app
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30100
EOF
```

**Alternative imperative approach (cannot specify nodePort):**

```bash
kubectl expose deployment nodeport-app --type=NodePort --port=80 -n ex-2-1 --name=nodeport-svc
# Then patch to set specific nodePort
kubectl patch service nodeport-svc -n ex-2-1 -p '{"spec":{"ports":[{"port":80,"nodePort":30100}]}}'
```

**Explanation:** NodePort services open a port on every node in the cluster. Traffic arriving at any node's IP on that port is forwarded to the service. The nodePort must be in the range 30000-32767.

---

## Exercise 2.2 Solution

**Task:** Create a headless service and verify DNS returns multiple IPs.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: headless-svc
  namespace: ex-2-2
spec:
  clusterIP: None
  selector:
    app: headless-app
  ports:
  - port: 80
    targetPort: 80
EOF
```

**Testing DNS:**

```bash
kubectl run dns-test --image=busybox:1.36 --rm -it -n ex-2-2 -- nslookup headless-svc
```

**Expected output:** You should see multiple IP addresses in the response, one for each pod. A normal ClusterIP service would return a single IP.

**Explanation:** Headless services (clusterIP: None) do not provide load balancing. Instead, DNS returns all pod IPs, and the client is responsible for selecting one. This is used with StatefulSets or when clients need to connect to specific pods.

---

## Exercise 2.3 Solution

**Task:** Demonstrate service discovery using DNS and environment variables.

**Solution:**

```bash
# Create test pod
kubectl run discovery-test --image=busybox:1.36 -n ex-2-3 --command -- sleep 3600
sleep 3

# DNS short name (works within same namespace)
kubectl exec -n ex-2-3 discovery-test -- wget -q -O- http://backend-app

# DNS FQDN
kubectl exec -n ex-2-3 discovery-test -- wget -q -O- http://backend-app.ex-2-3.svc.cluster.local

# Environment variables
kubectl exec -n ex-2-3 discovery-test -- env | grep BACKEND_APP

# Expected environment variables:
# BACKEND_APP_SERVICE_HOST=<ClusterIP>
# BACKEND_APP_SERVICE_PORT=80
```

**Explanation:** DNS is the preferred discovery method because it works for services created after the pod. Environment variables are injected only for services that existed when the pod started.

---

## Exercise 3.1 Solution

**Issue:** Selector mismatch. The service selector `app: debug-application` does not match the deployment's pod label `app: debug-app`.

**Diagnosis:**

```bash
# Check endpoints (empty)
kubectl get endpoints debug-svc -n ex-3-1

# Check service selector
kubectl get svc debug-svc -n ex-3-1 -o jsonpath='{.spec.selector}'

# Check pod labels
kubectl get pods -n ex-3-1 --show-labels
```

**Fix:**

```bash
kubectl patch service debug-svc -n ex-3-1 -p '{"spec":{"selector":{"app":"debug-app"}}}'
```

Or delete and recreate:

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: debug-svc
  namespace: ex-3-1
spec:
  selector:
    app: debug-app
  ports:
  - port: 80
    targetPort: 80
EOF
```

**Explanation:** When endpoints are empty, the first thing to check is whether the service selector matches any pod labels. Use `kubectl get svc -o wide` to see selectors at a glance, then compare with `kubectl get pods --show-labels`.

---

## Exercise 3.2 Solution

**Issue:** Wrong targetPort. The service forwards to port 8080 but the container listens on port 80.

**Diagnosis:**

```bash
# Check endpoints exist
kubectl get endpoints web-svc -n ex-3-2
# Endpoints exist but connections fail

# Check service port configuration
kubectl get svc web-svc -n ex-3-2 -o yaml | grep -A5 ports

# Check container port
kubectl get pods -n ex-3-2 -o jsonpath='{.items[0].spec.containers[0].ports}'
```

**Fix:**

```bash
kubectl patch service web-svc -n ex-3-2 -p '{"spec":{"ports":[{"port":80,"targetPort":80}]}}'
```

**Explanation:** When endpoints exist but connections fail with "Connection refused," the targetPort likely does not match the container's listening port. The service port (what clients connect to) and targetPort (what the container listens on) are independent values.

---

## Exercise 3.3 Solution

**Issue:** Readiness probe fails. The probe checks `/healthz` but nginx does not serve that path by default.

**Diagnosis:**

```bash
# Check pod status
kubectl get pods -n ex-3-3 -l app=ready-app
# Shows 0/1 Ready

# Check pod events
kubectl describe pod -n ex-3-3 -l app=ready-app | grep -A5 "Readiness"
# Shows probe failures

# Check what path the probe is checking
kubectl get deployment ready-app -n ex-3-3 -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}'
```

**Fix:** Change the readiness probe path to `/` (nginx default page):

```bash
kubectl patch deployment ready-app -n ex-3-3 --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}]'
```

Or remove the readiness probe if not needed:

```bash
kubectl patch deployment ready-app -n ex-3-3 --type=json -p='[{"op":"remove","path":"/spec/template/spec/containers/0/readinessProbe"}]'
```

**Explanation:** Services only include Ready pods in their endpoints. When pods fail readiness probes, they are excluded from service endpoints even if the container is running.

---

## Exercise 4.1 Solution

**Task:** Create a multi-port service with named ports.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: multi-port-svc
  namespace: ex-4-1
spec:
  selector:
    app: multi-port-app
  ports:
  - name: http
    port: 80
    targetPort: http
  - name: metrics
    port: 8080
    targetPort: 80
EOF
```

**Explanation:** For multi-port services, each port must have a name. The targetPort can reference a named port from the container spec (like `http`) or use a numeric port. Named ports make configurations more readable and allow port numbers to change without updating the service.

---

## Exercise 4.2 Solution

**Task:** Configure session affinity with a 30-minute timeout.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: affinity-svc
  namespace: ex-4-2
spec:
  type: ClusterIP
  selector:
    app: affinity-app
  ports:
  - port: 80
    targetPort: 80
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 1800
EOF
```

**Explanation:** Session affinity ensures requests from the same client IP go to the same pod. The timeout specifies how long the affinity lasts. This is useful for applications that maintain session state in memory rather than in a shared store.

---

## Exercise 4.3 Solution

**Task:** Create a service without selector and manually define endpoints.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: external-db
  namespace: ex-4-3
spec:
  ports:
  - port: 5432
    targetPort: 5432
---
apiVersion: v1
kind: Endpoints
metadata:
  name: external-db
  namespace: ex-4-3
subsets:
- addresses:
  - ip: 10.0.0.100
  - ip: 10.0.0.101
  ports:
  - port: 5432
EOF
```

**Explanation:** When a service has no selector, Kubernetes does not automatically create endpoints. You must create an Endpoints resource with the same name as the service. This is useful for routing to external services or services outside the cluster. The Endpoints name must exactly match the Service name.

---

## Exercise 5.1 Solution

**Task:** Build a multi-tier application with frontend, backend, and database services.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
# Database tier
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db
  namespace: ex-5-1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: redis
        image: redis:7.2
        ports:
        - containerPort: 6379
---
apiVersion: v1
kind: Service
metadata:
  name: db-svc
  namespace: ex-5-1
spec:
  clusterIP: None
  selector:
    app: db
  ports:
  - port: 6379
    targetPort: 6379
---
# Backend tier
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: ex-5-1
spec:
  replicas: 2
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
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: ex-5-1
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 80
---
# Frontend tier
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
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
  namespace: ex-5-1
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30200
EOF
```

**Explanation:** This three-tier architecture uses different service types based on access requirements. The database uses a headless service for direct pod access (typical for stateful workloads). The backend uses ClusterIP for internal-only access. The frontend uses NodePort for external access.

---

## Exercise 5.2 Solution

**Issues:** Multiple problems:
1. Selector mismatch: service selector `app: api` vs pod label `app: api-server`
2. Wrong targetPort: service uses 8080 but container listens on 80
3. Readiness probe fails: probe checks `/api/health` but nginx does not serve that path

**Diagnosis:**

```bash
# Check endpoints
kubectl get endpoints api-svc -n ex-5-2
# Empty or partial

# Check selector
kubectl get svc api-svc -n ex-5-2 -o jsonpath='{.spec.selector}'
kubectl get pods -n ex-5-2 --show-labels

# Check ports
kubectl get svc api-svc -n ex-5-2 -o jsonpath='{.spec.ports}'
kubectl get pods -n ex-5-2 -o jsonpath='{.items[0].spec.containers[0].ports}'

# Check pod readiness
kubectl get pods -n ex-5-2
kubectl describe pod -n ex-5-2 -l app=api-server | grep -A5 Readiness
```

**Fix:**

```yaml
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
            path: /
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
    app: api-server
  ports:
  - port: 80
    targetPort: 80
EOF
```

**Explanation:** Multi-failure scenarios require systematic debugging. Start with endpoints (are pods being selected?), then check connectivity (can traffic reach the pods?), then check pod health (are pods ready?).

---

## Exercise 5.3 Solution

**Task:** Migrate from ClusterIP to NodePort without downtime.

**Solution:**

```bash
# Verify current service is working
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-5-3 -- curl -s http://migrate-app

# Patch the service to change type and add nodePort
kubectl patch service migrate-app -n ex-5-3 -p '{"spec":{"type":"NodePort","ports":[{"port":80,"targetPort":80,"nodePort":30300}]}}'

# Verify service still works via ClusterIP
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-5-3 -- curl -s http://migrate-app

# Verify service works via NodePort
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-5-3 -- curl -s http://${NODE_IP}:30300
```

**Explanation:** When changing service type from ClusterIP to NodePort, the existing ClusterIP is preserved (NodePort includes ClusterIP functionality). Using `kubectl patch` updates the service in place without deleting it, maintaining continuous availability.

---

## Common Mistakes

### 1. Confusing Service Port and TargetPort

The service port is what clients connect to. The targetPort is what the container listens on. These can be different, and the targetPort must match what the application actually listens on.

**Wrong assumption:** "The targetPort should match the service port"
**Correct understanding:** "The targetPort must match the containerPort"

### 2. Selector Label Mismatch

The service selector must exactly match pod labels. A common mistake is assuming the service inherits labels from the deployment it was created to expose.

**Debugging tip:** Always compare `kubectl get svc -o wide` with `kubectl get pods --show-labels`

### 3. Creating Service Before Deployment

If you create a service before the deployment, pods that start later will have the service environment variables. However, the endpoints will be empty until pods exist.

If you create a pod before a service, that pod will not have environment variables for the service.

### 4. Using LoadBalancer Without a Provisioner

In cloud environments, LoadBalancer services get an external IP from the cloud provider. In kind or bare-metal clusters, you need metallb or a similar provisioner. Without one, the service stays in "Pending" state forever.

### 5. Assuming NodePort is Node-Specific

NodePort opens the port on every node in the cluster, not just nodes running the service's pods. Traffic to any node's IP on that port reaches the service.

### 6. Forgetting That Headless Services Have No ClusterIP

Headless services (clusterIP: None) do not provide load balancing. DNS returns all pod IPs. This is by design, but can be confusing if you expect normal service behavior.

### 7. Not Understanding Session Affinity Scope

Session affinity (ClientIP) works per-service, not cluster-wide. If you have multiple services for the same pods, affinity does not carry across services.

---

## Verification Commands Cheat Sheet

| Task | Command |
|------|---------|
| List services | `kubectl get svc -n <namespace>` |
| List services with selectors | `kubectl get svc -n <namespace> -o wide` |
| Show service details | `kubectl describe svc <name> -n <namespace>` |
| Show endpoints | `kubectl get endpoints <name> -n <namespace>` |
| Show endpoint details | `kubectl get endpoints <name> -n <namespace> -o yaml` |
| Check pod labels | `kubectl get pods -n <namespace> --show-labels` |
| Test connectivity | `kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n <namespace> -- curl http://<service>` |
| DNS lookup | `kubectl run dns-test --image=busybox:1.36 --rm -it -n <namespace> -- nslookup <service>` |
| Check environment variables | `kubectl exec <pod> -n <namespace> -- env \| grep <SERVICE>` |
| Get service ClusterIP | `kubectl get svc <name> -n <namespace> -o jsonpath='{.spec.clusterIP}'` |
| Get NodePort | `kubectl get svc <name> -n <namespace> -o jsonpath='{.spec.ports[0].nodePort}'` |
| Get external IP | `kubectl get svc <name> -n <namespace> -o jsonpath='{.status.loadBalancer.ingress[0].ip}'` |
