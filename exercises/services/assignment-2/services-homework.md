# Services Homework: External Service Types

This homework contains 15 progressive exercises covering external service types in Kubernetes. Work through the exercises in order, as later exercises build on concepts from earlier ones.

Before starting, ensure you have completed the services-tutorial.md file in this directory and have a multi-node kind cluster with metallb installed.

---

## Level 1: NodePort Services

These exercises cover creating NodePort services with automatic and manual port allocation.

### Exercise 1.1

**Objective:** Create a NodePort service with automatic port allocation.

**Setup:**

```bash
kubectl create namespace ex-1-1
kubectl create deployment app-nodeport --image=nginx:1.25 --replicas=2 -n ex-1-1
kubectl wait --for=condition=available deployment/app-nodeport -n ex-1-1 --timeout=60s
```

**Task:**

Create a NodePort service named `app-svc` that exposes the deployment on port 80. Let Kubernetes automatically allocate the NodePort. Verify the service is accessible via the NodePort.

**Verification:**

```bash
# Service type should be NodePort
kubectl get service app-svc -n ex-1-1 | grep "NodePort" && echo "Type: SUCCESS" || echo "Type: FAILED"

# NodePort should be in valid range
NODEPORT=$(kubectl get service app-svc -n ex-1-1 -o jsonpath='{.spec.ports[0].nodePort}')
[ "$NODEPORT" -ge 30000 ] && [ "$NODEPORT" -le 32767 ] && echo "NodePort in range: SUCCESS" || echo "NodePort in range: FAILED"

# Service should be accessible via NodePort
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-1-1 -- curl -s http://${NODE_IP}:${NODEPORT} | grep -q "nginx" && echo "Access: SUCCESS" || echo "Access: FAILED"
```

---

### Exercise 1.2

**Objective:** Create a NodePort service with a specific NodePort.

**Setup:**

```bash
kubectl create namespace ex-1-2
kubectl create deployment web-server --image=httpd:2.4 --replicas=3 -n ex-1-2
kubectl wait --for=condition=available deployment/web-server -n ex-1-2 --timeout=60s
```

**Task:**

Create a NodePort service named `web-svc` with:
- Service port 8080
- Target port 80 (httpd listens on 80)
- NodePort 30180

**Verification:**

```bash
# NodePort should be exactly 30180
kubectl get service web-svc -n ex-1-2 -o jsonpath='{.spec.ports[0].nodePort}' | grep -q "30180" && echo "NodePort: SUCCESS" || echo "NodePort: FAILED"

# Service port should be 8080
kubectl get service web-svc -n ex-1-2 -o jsonpath='{.spec.ports[0].port}' | grep -q "8080" && echo "Service port: SUCCESS" || echo "Service port: FAILED"

# Target port should be 80
kubectl get service web-svc -n ex-1-2 -o jsonpath='{.spec.ports[0].targetPort}' | grep -q "80" && echo "Target port: SUCCESS" || echo "Target port: FAILED"

# Test access
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-1-2 -- curl -s http://${NODE_IP}:30180 | grep -q "It works" && echo "Access: SUCCESS" || echo "Access: FAILED"
```

---

### Exercise 1.3

**Objective:** Demonstrate that NodePort opens on all nodes.

**Setup:**

```bash
kubectl create namespace ex-1-3
kubectl create deployment single-pod --image=nginx:1.25 --replicas=1 -n ex-1-3
kubectl wait --for=condition=available deployment/single-pod -n ex-1-3 --timeout=60s
kubectl expose deployment single-pod --type=NodePort --port=80 -n ex-1-3
```

**Task:**

The deployment has only one replica, which runs on one node. Verify that the NodePort service is accessible via all node IPs, not just the node where the pod runs.

1. Find which node the pod is running on
2. Get all node IPs
3. Test the NodePort on each node IP
4. Document your findings

**Verification:**

```bash
# Get the NodePort
NODEPORT=$(kubectl get service single-pod -n ex-1-3 -o jsonpath='{.spec.ports[0].nodePort}')

# Test access from all nodes
for NODE_IP in $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'); do
  kubectl run curl-test-$(echo $NODE_IP | tr . -) --image=curlimages/curl:8.5.0 --rm -it -n ex-1-3 -- curl -s --max-time 3 http://${NODE_IP}:${NODEPORT} | grep -q "nginx" && echo "Node $NODE_IP: SUCCESS" || echo "Node $NODE_IP: FAILED"
done
```

---

## Level 2: LoadBalancer and ExternalName

These exercises cover LoadBalancer services with metallb and ExternalName services.

### Exercise 2.1

**Objective:** Create a LoadBalancer service and verify external IP assignment.

**Setup:**

```bash
kubectl create namespace ex-2-1
kubectl create deployment lb-app --image=nginx:1.25 --replicas=2 -n ex-2-1
kubectl wait --for=condition=available deployment/lb-app -n ex-2-1 --timeout=60s
```

**Task:**

Create a LoadBalancer service named `lb-svc` for the deployment. Verify that metallb assigns an external IP and the service is accessible via that IP.

**Verification:**

```bash
# Service type should be LoadBalancer
kubectl get service lb-svc -n ex-2-1 | grep "LoadBalancer" && echo "Type: SUCCESS" || echo "Type: FAILED"

# External IP should be assigned (not pending)
EXTERNAL_IP=$(kubectl get service lb-svc -n ex-2-1 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
[ -n "$EXTERNAL_IP" ] && echo "External IP assigned: SUCCESS ($EXTERNAL_IP)" || echo "External IP assigned: FAILED"

# Service should be accessible via external IP
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-2-1 -- curl -s http://${EXTERNAL_IP} | grep -q "nginx" && echo "Access: SUCCESS" || echo "Access: FAILED"
```

---

### Exercise 2.2

**Objective:** Create an ExternalName service for an external DNS name.

**Setup:**

```bash
kubectl create namespace ex-2-2
```

**Task:**

Create an ExternalName service named `google-dns` that points to `dns.google`. Verify the service was created correctly and DNS resolves as expected.

**Verification:**

```bash
# Service type should be ExternalName
kubectl get service google-dns -n ex-2-2 | grep "ExternalName" && echo "Type: SUCCESS" || echo "Type: FAILED"

# External name should be dns.google
kubectl get service google-dns -n ex-2-2 -o jsonpath='{.spec.externalName}' | grep -q "dns.google" && echo "ExternalName: SUCCESS" || echo "ExternalName: FAILED"

# DNS lookup should return CNAME
kubectl run dns-test --image=busybox:1.36 --rm -it -n ex-2-2 -- nslookup google-dns.ex-2-2.svc.cluster.local 2>/dev/null | grep -q "dns.google" && echo "DNS: SUCCESS" || echo "DNS: FAILED"
```

---

### Exercise 2.3

**Objective:** Compare service types by examining their configurations.

**Setup:**

```bash
kubectl create namespace ex-2-3
kubectl create deployment compare-app --image=nginx:1.25 --replicas=2 -n ex-2-3
kubectl wait --for=condition=available deployment/compare-app -n ex-2-3 --timeout=60s
```

**Task:**

Create three services for the same deployment:
1. `svc-clusterip` (ClusterIP type)
2. `svc-nodeport` (NodePort type)
3. `svc-loadbalancer` (LoadBalancer type)

Then document the differences in their configurations (ClusterIP allocation, ports, external IP).

**Verification:**

```bash
# ClusterIP service should have ClusterIP only
kubectl get service svc-clusterip -n ex-2-3 | grep "ClusterIP" | grep -v "NodePort\|LoadBalancer" && echo "ClusterIP type: SUCCESS" || echo "ClusterIP type: FAILED"

# NodePort service should have ClusterIP and NodePort
kubectl get service svc-nodeport -n ex-2-3 | grep "NodePort" && echo "NodePort type: SUCCESS" || echo "NodePort type: FAILED"
NODEPORT=$(kubectl get service svc-nodeport -n ex-2-3 -o jsonpath='{.spec.ports[0].nodePort}')
[ -n "$NODEPORT" ] && echo "NodePort allocated: SUCCESS" || echo "NodePort allocated: FAILED"

# LoadBalancer service should have ClusterIP, NodePort, and External IP
kubectl get service svc-loadbalancer -n ex-2-3 | grep "LoadBalancer" && echo "LoadBalancer type: SUCCESS" || echo "LoadBalancer type: FAILED"
EXTERNAL_IP=$(kubectl get service svc-loadbalancer -n ex-2-3 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
[ -n "$EXTERNAL_IP" ] && echo "External IP: SUCCESS" || echo "External IP: FAILED"
```

---

## Level 3: Debugging External Service Issues

These exercises present broken external service configurations to diagnose and fix.

### Exercise 3.1

**Objective:** Fix the broken configuration so that the LoadBalancer service receives an external IP.

**Setup:**

```bash
kubectl create namespace ex-3-1
kubectl create deployment lb-debug --image=nginx:1.25 --replicas=2 -n ex-3-1
kubectl wait --for=condition=available deployment/lb-debug -n ex-3-1 --timeout=60s

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: lb-pending
  namespace: ex-3-1
spec:
  type: LoadBalancer
  selector:
    app: lb-debug
  ports:
  - port: 80
    targetPort: 80
  loadBalancerIP: 192.168.100.100
EOF

sleep 5
```

**Task:**

The LoadBalancer service `lb-pending` is stuck with EXTERNAL-IP showing `<pending>`. Diagnose the issue and fix it so the service receives an external IP from metallb.

**Verification:**

```bash
# External IP should not be pending
EXTERNAL_IP=$(kubectl get service lb-pending -n ex-3-1 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
[ -n "$EXTERNAL_IP" ] && echo "External IP assigned: SUCCESS ($EXTERNAL_IP)" || echo "External IP assigned: FAILED"

# Service should be accessible
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-3-1 -- curl -s --max-time 5 http://${EXTERNAL_IP} | grep -q "nginx" && echo "Access: SUCCESS" || echo "Access: FAILED"
```

---

### Exercise 3.2

**Objective:** Fix the broken configuration so that the NodePort service is accessible.

**Setup:**

```bash
kubectl create namespace ex-3-2

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodeport-debug
  namespace: ex-3-2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nodeport-debug
  template:
    metadata:
      labels:
        app: nodeport-debug
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
  name: nodeport-broken
  namespace: ex-3-2
spec:
  type: NodePort
  selector:
    app: nodeport-debug
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30282
EOF

kubectl wait --for=condition=available deployment/nodeport-debug -n ex-3-2 --timeout=60s
```

**Task:**

The NodePort service `nodeport-broken` has endpoints but connections to the NodePort fail. Diagnose the issue and fix it.

**Verification:**

```bash
# Service should be accessible via NodePort
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-3-2 -- curl -s --max-time 5 http://${NODE_IP}:30282 | grep -q "nginx" && echo "Access: SUCCESS" || echo "Access: FAILED"
```

---

### Exercise 3.3

**Objective:** Fix the broken configuration so that the ExternalName service resolves correctly.

**Setup:**

```bash
kubectl create namespace ex-3-3

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: external-broken
  namespace: ex-3-3
spec:
  type: ExternalName
  externalName: 8.8.8.8
EOF
```

**Task:**

The ExternalName service `external-broken` was intended to provide access to an external service, but it is misconfigured. Diagnose and fix the issue so DNS lookups work correctly.

**Verification:**

```bash
# DNS lookup should return a valid response (CNAME to a DNS name)
kubectl run dns-test --image=busybox:1.36 --rm -it -n ex-3-3 -- nslookup external-broken.ex-3-3.svc.cluster.local 2>/dev/null | grep -v "NXDOMAIN" && echo "DNS: SUCCESS" || echo "DNS: FAILED"
```

---

## Level 4: Manual Endpoints

These exercises cover services without selectors and manual endpoint management.

### Exercise 4.1

**Objective:** Create a service without a selector and add manual endpoints.

**Setup:**

```bash
kubectl create namespace ex-4-1
```

**Task:**

Create a service named `manual-svc` without a selector that listens on port 3306. Then create an Endpoints resource that directs traffic to IP addresses 10.10.10.1 and 10.10.10.2 on port 3306.

**Verification:**

```bash
# Service should not have a selector
SELECTOR=$(kubectl get service manual-svc -n ex-4-1 -o jsonpath='{.spec.selector}')
[ -z "$SELECTOR" ] && echo "No selector: SUCCESS" || echo "No selector: FAILED"

# Endpoints should have 2 addresses
ENDPOINT_COUNT=$(kubectl get endpoints manual-svc -n ex-4-1 -o jsonpath='{.subsets[0].addresses}' | jq length 2>/dev/null || echo 0)
[ "$ENDPOINT_COUNT" -eq 2 ] && echo "Endpoint count: SUCCESS" || echo "Endpoint count: FAILED"

# Endpoints should include correct IPs
kubectl get endpoints manual-svc -n ex-4-1 -o jsonpath='{.subsets[0].addresses[*].ip}' | grep -q "10.10.10.1" && echo "IP 1: SUCCESS" || echo "IP 1: FAILED"
kubectl get endpoints manual-svc -n ex-4-1 -o jsonpath='{.subsets[0].addresses[*].ip}' | grep -q "10.10.10.2" && echo "IP 2: SUCCESS" || echo "IP 2: FAILED"
```

---

### Exercise 4.2

**Objective:** Create an EndpointSlice for a service without a selector.

**Setup:**

```bash
kubectl create namespace ex-4-2

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: slice-svc
  namespace: ex-4-2
spec:
  ports:
  - port: 8080
    targetPort: 8080
EOF
```

**Task:**

Create an EndpointSlice named `slice-svc-endpoints` for the service `slice-svc` that includes these endpoints:
- 192.168.1.10:8080 (ready: true)
- 192.168.1.11:8080 (ready: true)
- 192.168.1.12:8080 (ready: false)

Use the addressType `IPv4` and ensure the EndpointSlice is associated with the service.

**Verification:**

```bash
# EndpointSlice should exist
kubectl get endpointslice slice-svc-endpoints -n ex-4-2 && echo "EndpointSlice exists: SUCCESS" || echo "EndpointSlice exists: FAILED"

# Should have 3 endpoints
ENDPOINT_COUNT=$(kubectl get endpointslice slice-svc-endpoints -n ex-4-2 -o jsonpath='{.endpoints}' | jq length 2>/dev/null || echo 0)
[ "$ENDPOINT_COUNT" -eq 3 ] && echo "Endpoint count: SUCCESS" || echo "Endpoint count: FAILED"

# Should be associated with the service
kubectl get endpointslice slice-svc-endpoints -n ex-4-2 -o jsonpath='{.metadata.labels.kubernetes\.io/service-name}' | grep -q "slice-svc" && echo "Service association: SUCCESS" || echo "Service association: FAILED"
```

---

### Exercise 4.3

**Objective:** Update manual endpoints when backend addresses change.

**Setup:**

```bash
kubectl create namespace ex-4-3

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: dynamic-svc
  namespace: ex-4-3
spec:
  ports:
  - port: 443
    targetPort: 443
---
apiVersion: v1
kind: Endpoints
metadata:
  name: dynamic-svc
  namespace: ex-4-3
subsets:
- addresses:
  - ip: 10.0.0.1
  - ip: 10.0.0.2
  ports:
  - port: 443
EOF
```

**Task:**

The backend servers have changed. Update the endpoints to remove the old addresses and add new ones:
- Remove: 10.0.0.1 and 10.0.0.2
- Add: 10.0.1.100, 10.0.1.101, and 10.0.1.102

**Verification:**

```bash
# Should have 3 endpoints
ENDPOINT_COUNT=$(kubectl get endpoints dynamic-svc -n ex-4-3 -o jsonpath='{.subsets[0].addresses}' | jq length 2>/dev/null || echo 0)
[ "$ENDPOINT_COUNT" -eq 3 ] && echo "Endpoint count: SUCCESS" || echo "Endpoint count: FAILED"

# Should include new IPs
kubectl get endpoints dynamic-svc -n ex-4-3 -o jsonpath='{.subsets[0].addresses[*].ip}' | grep -q "10.0.1.100" && echo "IP 100: SUCCESS" || echo "IP 100: FAILED"
kubectl get endpoints dynamic-svc -n ex-4-3 -o jsonpath='{.subsets[0].addresses[*].ip}' | grep -q "10.0.1.101" && echo "IP 101: SUCCESS" || echo "IP 101: FAILED"
kubectl get endpoints dynamic-svc -n ex-4-3 -o jsonpath='{.subsets[0].addresses[*].ip}' | grep -q "10.0.1.102" && echo "IP 102: SUCCESS" || echo "IP 102: FAILED"

# Should not include old IPs
kubectl get endpoints dynamic-svc -n ex-4-3 -o jsonpath='{.subsets[0].addresses[*].ip}' | grep -q "10.0.0.1" && echo "Old IP 1: FAILED" || echo "Old IP 1: SUCCESS (removed)"
kubectl get endpoints dynamic-svc -n ex-4-3 -o jsonpath='{.subsets[0].addresses[*].ip}' | grep -q "10.0.0.2" && echo "Old IP 2: FAILED" || echo "Old IP 2: SUCCESS (removed)"
```

---

## Level 5: Complex Scenarios

These exercises present complex, realistic scenarios.

### Exercise 5.1

**Objective:** Create a service for an external database using manual endpoints.

**Setup:**

```bash
kubectl create namespace ex-5-1
```

**Task:**

Your application needs to connect to an external PostgreSQL database cluster with these servers:
- Primary: 10.100.0.10:5432
- Replica 1: 10.100.0.11:5432
- Replica 2: 10.100.0.12:5432

Create:
1. A service named `postgres-primary` pointing only to the primary
2. A service named `postgres-replicas` pointing to both replicas

Both services should be accessible via DNS within the cluster.

**Verification:**

```bash
# Primary service should have 1 endpoint
PRIMARY_COUNT=$(kubectl get endpoints postgres-primary -n ex-5-1 -o jsonpath='{.subsets[0].addresses}' | jq length 2>/dev/null || echo 0)
[ "$PRIMARY_COUNT" -eq 1 ] && echo "Primary count: SUCCESS" || echo "Primary count: FAILED"
kubectl get endpoints postgres-primary -n ex-5-1 -o jsonpath='{.subsets[0].addresses[0].ip}' | grep -q "10.100.0.10" && echo "Primary IP: SUCCESS" || echo "Primary IP: FAILED"

# Replicas service should have 2 endpoints
REPLICA_COUNT=$(kubectl get endpoints postgres-replicas -n ex-5-1 -o jsonpath='{.subsets[0].addresses}' | jq length 2>/dev/null || echo 0)
[ "$REPLICA_COUNT" -eq 2 ] && echo "Replica count: SUCCESS" || echo "Replica count: FAILED"

# DNS should resolve both services
kubectl run dns-test --image=busybox:1.36 --rm -it -n ex-5-1 -- nslookup postgres-primary 2>/dev/null | grep -q "Address" && echo "Primary DNS: SUCCESS" || echo "Primary DNS: FAILED"
kubectl run dns-test --image=busybox:1.36 --rm -it -n ex-5-1 -- nslookup postgres-replicas 2>/dev/null | grep -q "Address" && echo "Replicas DNS: SUCCESS" || echo "Replicas DNS: FAILED"
```

---

### Exercise 5.2

**Objective:** Migrate a service from NodePort to LoadBalancer without downtime.

**Setup:**

```bash
kubectl create namespace ex-5-2
kubectl create deployment migrate-app --image=nginx:1.25 --replicas=3 -n ex-5-2
kubectl wait --for=condition=available deployment/migrate-app -n ex-5-2 --timeout=60s

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: migrate-svc
  namespace: ex-5-2
spec:
  type: NodePort
  selector:
    app: migrate-app
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30500
EOF
```

**Task:**

The service `migrate-svc` is currently NodePort. Migrate it to LoadBalancer while:
1. Maintaining the existing NodePort 30500
2. Keeping the service accessible throughout the migration
3. Documenting the steps you took

**Verification:**

```bash
# Service should be LoadBalancer type
kubectl get service migrate-svc -n ex-5-2 | grep "LoadBalancer" && echo "Type: SUCCESS" || echo "Type: FAILED"

# NodePort should still be 30500
kubectl get service migrate-svc -n ex-5-2 -o jsonpath='{.spec.ports[0].nodePort}' | grep -q "30500" && echo "NodePort preserved: SUCCESS" || echo "NodePort preserved: FAILED"

# External IP should be assigned
EXTERNAL_IP=$(kubectl get service migrate-svc -n ex-5-2 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
[ -n "$EXTERNAL_IP" ] && echo "External IP: SUCCESS ($EXTERNAL_IP)" || echo "External IP: FAILED"

# Both NodePort and External IP should work
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-5-2 -- curl -s http://${NODE_IP}:30500 | grep -q "nginx" && echo "NodePort access: SUCCESS" || echo "NodePort access: FAILED"
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-5-2 -- curl -s http://${EXTERNAL_IP} | grep -q "nginx" && echo "LoadBalancer access: SUCCESS" || echo "LoadBalancer access: FAILED"
```

---

### Exercise 5.3

**Objective:** Design an external access strategy for a multi-tier application.

**Setup:**

```bash
kubectl create namespace ex-5-3
```

**Task:**

Design and implement services for a three-tier application:

1. **Frontend:** Public-facing web servers. Needs LoadBalancer for external access.
   - Deployment: `frontend` with 3 replicas of nginx:1.25
   - Service: `frontend-svc` LoadBalancer on port 80

2. **API:** Internal API servers. Only internal cluster access needed.
   - Deployment: `api` with 2 replicas of nginx:1.25
   - Service: `api-svc` ClusterIP on port 8080

3. **Legacy Backend:** External legacy system at 10.200.0.50:9000. Needs cluster-internal DNS name.
   - Service: `legacy-backend` with manual endpoints

Create all deployments and services, then verify the architecture works.

**Verification:**

```bash
# Frontend: LoadBalancer with external IP
kubectl get service frontend-svc -n ex-5-3 | grep "LoadBalancer" && echo "Frontend type: SUCCESS" || echo "Frontend type: FAILED"
FRONTEND_IP=$(kubectl get service frontend-svc -n ex-5-3 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
[ -n "$FRONTEND_IP" ] && echo "Frontend external IP: SUCCESS" || echo "Frontend external IP: FAILED"

# API: ClusterIP only
kubectl get service api-svc -n ex-5-3 | grep "ClusterIP" | grep -v "LoadBalancer\|NodePort" && echo "API type: SUCCESS" || echo "API type: FAILED"

# Legacy backend: Manual endpoints
kubectl get endpoints legacy-backend -n ex-5-3 -o jsonpath='{.subsets[0].addresses[0].ip}' | grep -q "10.200.0.50" && echo "Legacy endpoint: SUCCESS" || echo "Legacy endpoint: FAILED"

# All services should have DNS entries
kubectl run dns-test --image=busybox:1.36 --rm -it -n ex-5-3 -- nslookup frontend-svc 2>/dev/null | grep -q "Address" && echo "Frontend DNS: SUCCESS" || echo "Frontend DNS: FAILED"
kubectl run dns-test --image=busybox:1.36 --rm -it -n ex-5-3 -- nslookup api-svc 2>/dev/null | grep -q "Address" && echo "API DNS: SUCCESS" || echo "API DNS: FAILED"
kubectl run dns-test --image=busybox:1.36 --rm -it -n ex-5-3 -- nslookup legacy-backend 2>/dev/null | grep -q "Address" && echo "Legacy DNS: SUCCESS" || echo "Legacy DNS: FAILED"
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

1. **Create NodePort services** with automatic or manual port allocation and understand that NodePort opens on all nodes
2. **Create LoadBalancer services** and understand the role of load balancer providers like metallb
3. **Create ExternalName services** for DNS aliasing of external services
4. **Create services without selectors** and manually manage endpoints
5. **Debug common external service issues:** pending LoadBalancer, wrong ports, invalid ExternalName
6. **Migrate between service types** without downtime
7. **Design external access strategies** using the appropriate service type for each tier
