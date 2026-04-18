# Services Homework Answers: External Service Types

This file contains complete solutions for all 15 exercises. For debugging exercises, explanations of the issue and diagnostic process are included.

---

## Exercise 1.1 Solution

**Task:** Create a NodePort service with automatic port allocation.

**Solution:**

```bash
kubectl expose deployment app-nodeport --type=NodePort --port=80 --name=app-svc -n ex-1-1
```

**Verification:**

```bash
kubectl get service app-svc -n ex-1-1
NODEPORT=$(kubectl get service app-svc -n ex-1-1 -o jsonpath='{.spec.ports[0].nodePort}')
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-1-1 -- curl http://${NODE_IP}:${NODEPORT}
```

**Explanation:** When you specify `--type=NodePort`, Kubernetes automatically allocates a port in the 30000-32767 range if you do not specify one.

---

## Exercise 1.2 Solution

**Task:** Create a NodePort service with specific ports.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: ex-1-2
spec:
  type: NodePort
  selector:
    app: web-server
  ports:
  - port: 8080
    targetPort: 80
    nodePort: 30180
EOF
```

**Explanation:** The declarative YAML allows specifying all three port values: the service port (what clients connect to), targetPort (what the container listens on), and nodePort (the external port on nodes).

---

## Exercise 1.3 Solution

**Task:** Demonstrate that NodePort opens on all nodes.

**Solution:**

```bash
# Find which node the pod is running on
kubectl get pods -n ex-1-3 -o wide

# Get the NodePort
NODEPORT=$(kubectl get service single-pod -n ex-1-3 -o jsonpath='{.spec.ports[0].nodePort}')

# Test from each node
for NODE_IP in $(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'); do
  echo "Testing $NODE_IP:$NODEPORT"
  kubectl run curl-$(echo $NODE_IP | tr . -) --image=curlimages/curl:8.5.0 --rm -it -n ex-1-3 -- curl -s http://${NODE_IP}:${NODEPORT}
done
```

**Explanation:** Even though the pod runs on only one node, kube-proxy configures iptables/ipvs rules on every node to forward traffic to the service. This means any node IP with the NodePort reaches the service.

---

## Exercise 2.1 Solution

**Task:** Create a LoadBalancer service with metallb.

**Solution:**

```bash
kubectl expose deployment lb-app --type=LoadBalancer --port=80 --name=lb-svc -n ex-2-1
```

Or declaratively:

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: lb-svc
  namespace: ex-2-1
spec:
  type: LoadBalancer
  selector:
    app: lb-app
  ports:
  - port: 80
    targetPort: 80
EOF
```

**Verification:**

```bash
# Wait for external IP
kubectl get service lb-svc -n ex-2-1 -w

# Test access
EXTERNAL_IP=$(kubectl get service lb-svc -n ex-2-1 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-2-1 -- curl http://${EXTERNAL_IP}
```

**Explanation:** With metallb installed and configured with an IP pool, LoadBalancer services receive an external IP from that pool.

---

## Exercise 2.2 Solution

**Task:** Create an ExternalName service.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: google-dns
  namespace: ex-2-2
spec:
  type: ExternalName
  externalName: dns.google
EOF
```

**Verification:**

```bash
kubectl get service google-dns -n ex-2-2
kubectl run dns-test --image=busybox:1.36 --rm -it -n ex-2-2 -- nslookup google-dns.ex-2-2.svc.cluster.local
```

**Explanation:** ExternalName services create a CNAME DNS record. When you resolve the service name, DNS returns a CNAME pointing to the externalName value.

---

## Exercise 2.3 Solution

**Task:** Create and compare three service types.

**Solution:**

```bash
kubectl expose deployment compare-app --port=80 --name=svc-clusterip -n ex-2-3
kubectl expose deployment compare-app --type=NodePort --port=80 --name=svc-nodeport -n ex-2-3
kubectl expose deployment compare-app --type=LoadBalancer --port=80 --name=svc-loadbalancer -n ex-2-3
```

**Comparison:**

```bash
kubectl get services -n ex-2-3 -o wide
```

| Service | Type | ClusterIP | NodePort | External IP |
|---------|------|-----------|----------|-------------|
| svc-clusterip | ClusterIP | Yes | No | No |
| svc-nodeport | NodePort | Yes | Yes | No |
| svc-loadbalancer | LoadBalancer | Yes | Yes | Yes |

**Explanation:** Each service type builds on the previous. NodePort adds a node port to ClusterIP. LoadBalancer adds an external IP to NodePort.

---

## Exercise 3.1 Solution

**Issue:** The loadBalancerIP 192.168.100.100 is outside the metallb IP pool.

**Diagnosis:**

```bash
kubectl describe service lb-pending -n ex-3-1
# Look for events about IP allocation failure

kubectl get ipaddresspool -n metallb-system -o yaml
# Check the configured IP range
```

**Fix:**

```bash
# Remove the specific IP request
kubectl patch service lb-pending -n ex-3-1 --type=json -p='[{"op":"remove","path":"/spec/loadBalancerIP"}]'
```

Or recreate without specifying loadBalancerIP:

```yaml
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
EOF
```

**Explanation:** When you specify a loadBalancerIP that is not in the metallb pool, metallb cannot assign it, and the service stays pending. Either use an IP from the pool or let metallb allocate automatically.

---

## Exercise 3.2 Solution

**Issue:** The targetPort (8080) does not match the container port (80).

**Diagnosis:**

```bash
kubectl get endpoints nodeport-broken -n ex-3-2
# Endpoints exist

kubectl get service nodeport-broken -n ex-3-2 -o yaml | grep targetPort
# targetPort: 8080

kubectl get pods -n ex-3-2 -o jsonpath='{.items[0].spec.containers[0].ports}'
# containerPort: 80
```

**Fix:**

```bash
kubectl patch service nodeport-broken -n ex-3-2 -p '{"spec":{"ports":[{"port":80,"targetPort":80,"nodePort":30282}]}}'
```

**Explanation:** When endpoints exist but connections fail with "Connection refused," the targetPort likely does not match the actual port the container is listening on.

---

## Exercise 3.3 Solution

**Issue:** The externalName uses an IP address (8.8.8.8) instead of a DNS name.

**Diagnosis:**

```bash
kubectl get service external-broken -n ex-3-3 -o yaml
# externalName: 8.8.8.8 (this is an IP, not a DNS name)

kubectl run dns-test --image=busybox:1.36 --rm -it -n ex-3-3 -- nslookup external-broken
# Fails because CNAME must point to a DNS name
```

**Fix:**

ExternalName must be a DNS name. Replace the IP with a DNS name:

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: external-broken
  namespace: ex-3-3
spec:
  type: ExternalName
  externalName: dns.google
EOF
```

If you need to point to an IP address, use a service without selector with manual endpoints instead.

**Explanation:** ExternalName creates a DNS CNAME record. CNAME records must point to another DNS name, not an IP address. This is a DNS protocol requirement.

---

## Exercise 4.1 Solution

**Task:** Create a service without selector with manual endpoints.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: manual-svc
  namespace: ex-4-1
spec:
  ports:
  - port: 3306
    targetPort: 3306
---
apiVersion: v1
kind: Endpoints
metadata:
  name: manual-svc
  namespace: ex-4-1
subsets:
- addresses:
  - ip: 10.10.10.1
  - ip: 10.10.10.2
  ports:
  - port: 3306
EOF
```

**Explanation:** The Service name and Endpoints name must match exactly. The Endpoints resource defines the backend IP:port combinations that the service routes to.

---

## Exercise 4.2 Solution

**Task:** Create an EndpointSlice for a selectorless service.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: slice-svc-endpoints
  namespace: ex-4-2
  labels:
    kubernetes.io/service-name: slice-svc
addressType: IPv4
ports:
- port: 8080
endpoints:
- addresses:
  - 192.168.1.10
  conditions:
    ready: true
- addresses:
  - 192.168.1.11
  conditions:
    ready: true
- addresses:
  - 192.168.1.12
  conditions:
    ready: false
EOF
```

**Explanation:** EndpointSlices are the newer, more scalable replacement for Endpoints. The `kubernetes.io/service-name` label associates the EndpointSlice with a service. Each endpoint has a conditions block where you can specify readiness.

---

## Exercise 4.3 Solution

**Task:** Update manual endpoints with new addresses.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Endpoints
metadata:
  name: dynamic-svc
  namespace: ex-4-3
subsets:
- addresses:
  - ip: 10.0.1.100
  - ip: 10.0.1.101
  - ip: 10.0.1.102
  ports:
  - port: 443
EOF
```

**Explanation:** Applying a new Endpoints resource replaces the existing one. This is how you update backend addresses for services without selectors.

---

## Exercise 5.1 Solution

**Task:** Create services for an external PostgreSQL cluster.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
# Primary service
apiVersion: v1
kind: Service
metadata:
  name: postgres-primary
  namespace: ex-5-1
spec:
  ports:
  - port: 5432
    targetPort: 5432
---
apiVersion: v1
kind: Endpoints
metadata:
  name: postgres-primary
  namespace: ex-5-1
subsets:
- addresses:
  - ip: 10.100.0.10
  ports:
  - port: 5432
---
# Replicas service
apiVersion: v1
kind: Service
metadata:
  name: postgres-replicas
  namespace: ex-5-1
spec:
  ports:
  - port: 5432
    targetPort: 5432
---
apiVersion: v1
kind: Endpoints
metadata:
  name: postgres-replicas
  namespace: ex-5-1
subsets:
- addresses:
  - ip: 10.100.0.11
  - ip: 10.100.0.12
  ports:
  - port: 5432
EOF
```

**Explanation:** Separating primary and replica services allows applications to direct writes to the primary and reads to replicas. The replicas service load balances across both replicas.

---

## Exercise 5.2 Solution

**Task:** Migrate from NodePort to LoadBalancer while preserving NodePort.

**Solution:**

```bash
# Verify current access
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-5-2 -- curl http://${NODE_IP}:30500

# Patch to change type while preserving NodePort
kubectl patch service migrate-svc -n ex-5-2 -p '{"spec":{"type":"LoadBalancer"}}'

# Verify both access methods work
EXTERNAL_IP=$(kubectl get service migrate-svc -n ex-5-2 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-5-2 -- curl http://${EXTERNAL_IP}
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n ex-5-2 -- curl http://${NODE_IP}:30500
```

**Explanation:** Changing the type from NodePort to LoadBalancer preserves the existing ClusterIP and NodePort while adding an external IP. This maintains backward compatibility for clients using the NodePort.

---

## Exercise 5.3 Solution

**Task:** Design an external access strategy for a multi-tier application.

**Solution:**

```yaml
cat <<EOF | kubectl apply -f -
# Frontend: LoadBalancer for external access
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: ex-5-3
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
  namespace: ex-5-3
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
---
# API: ClusterIP for internal access
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: ex-5-3
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
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: api-svc
  namespace: ex-5-3
spec:
  type: ClusterIP
  selector:
    app: api
  ports:
  - port: 8080
    targetPort: 80
---
# Legacy backend: Manual endpoints for external system
apiVersion: v1
kind: Service
metadata:
  name: legacy-backend
  namespace: ex-5-3
spec:
  ports:
  - port: 9000
    targetPort: 9000
---
apiVersion: v1
kind: Endpoints
metadata:
  name: legacy-backend
  namespace: ex-5-3
subsets:
- addresses:
  - ip: 10.200.0.50
  ports:
  - port: 9000
EOF
```

**Explanation:** This architecture uses:
- LoadBalancer for public-facing services that need external access
- ClusterIP for internal services that should not be externally accessible
- Manual endpoints for external services that need cluster-internal DNS names

---

## Common Mistakes

### 1. NodePort Outside Valid Range

NodePorts must be in the range 30000-32767. Specifying a port outside this range fails with an error.

### 2. LoadBalancer Without Provider

In environments without a cloud provider or metallb, LoadBalancer services stay in "Pending" state forever. This is expected behavior, not a bug.

### 3. ExternalName with IP Address

ExternalName must be a DNS name, not an IP address. CNAME records cannot point to IP addresses. Use a selectorless service with manual endpoints for IP addresses.

### 4. Endpoints Not Matching Service Port

When creating manual endpoints, the port in the Endpoints resource must match the targetPort in the Service. A mismatch causes connections to fail.

### 5. Forgetting NodePort Opens on All Nodes

Traffic to any node's IP on the NodePort reaches the service, even if no pods run on that node. This is often surprising but is by design.

### 6. Endpoints Name Mismatch

The Endpoints resource name must exactly match the Service name. This is how Kubernetes associates them.

### 7. Not Specifying Port Names in EndpointSlices

While optional for single-port services, port names are required when a service has multiple ports.

---

## External Service Commands Cheat Sheet

| Task | Command |
|------|---------|
| Create NodePort | `kubectl expose deployment <name> --type=NodePort --port=80` |
| Get NodePort value | `kubectl get svc <name> -o jsonpath='{.spec.ports[0].nodePort}'` |
| Create LoadBalancer | `kubectl expose deployment <name> --type=LoadBalancer --port=80` |
| Get external IP | `kubectl get svc <name> -o jsonpath='{.status.loadBalancer.ingress[0].ip}'` |
| Watch for IP | `kubectl get svc <name> -w` |
| Create ExternalName | YAML only (no imperative command) |
| Create manual endpoints | YAML only (no imperative command) |
| Get endpoints | `kubectl get endpoints <name>` |
| Get endpointslices | `kubectl get endpointslices -l kubernetes.io/service-name=<name>` |
| Patch service type | `kubectl patch svc <name> -p '{"spec":{"type":"LoadBalancer"}}'` |
| Get all node IPs | `kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'` |
