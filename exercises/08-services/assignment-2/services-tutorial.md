# Services Tutorial: External Service Types

This tutorial covers external service types that enable access from outside the Kubernetes cluster and integration with external resources. You will learn NodePort, LoadBalancer, ExternalName services, and how to create services without selectors using manual endpoints.

## Introduction

ClusterIP services provide internal cluster communication, but many applications need external access. NodePort services open a port on every node, allowing external clients to connect via any node's IP. LoadBalancer services go further by provisioning an external load balancer that distributes traffic across nodes. ExternalName services provide DNS-based abstraction for external services, and services without selectors enable routing to backends outside the cluster.

Understanding when to use each external service type is important for the CKA exam. This tutorial explains the mechanics of each type, their use cases, and how to configure them in kind clusters using metallb.

## Prerequisites

Before starting this tutorial, ensure you have:

- A multi-node kind cluster running (1 control-plane, 3 workers)
- metallb installed for LoadBalancer service testing
- Completed 08-services/assignment-1 (ClusterIP fundamentals)
- kubectl configured to communicate with your cluster

Verify your cluster and metallb are ready:

```bash
kubectl get nodes
kubectl get pods -n metallb-system
```

## Tutorial Setup

Create the tutorial namespace:

```bash
kubectl create namespace tutorial-services
```

## NodePort Services

NodePort services extend ClusterIP by opening a static port (30000-32767) on every node. External clients can access the service by connecting to any node's IP address on the NodePort.

### How NodePort Works

When you create a NodePort service, Kubernetes:
1. Allocates a ClusterIP (just like a ClusterIP service)
2. Opens the specified NodePort on every node
3. Configures kube-proxy to forward traffic from the NodePort to the service backends

Traffic can reach the service via:
- The ClusterIP (from within the cluster)
- Any node's IP on the NodePort (from outside the cluster)

### Creating a NodePort Service

First, create a deployment:

```bash
kubectl create deployment web-nodeport --image=nginx:1.25 --replicas=2 -n tutorial-services
kubectl wait --for=condition=available deployment/web-nodeport -n tutorial-services --timeout=60s
```

Create a NodePort service with automatic port allocation:

```bash
kubectl expose deployment web-nodeport --type=NodePort --port=80 -n tutorial-services
kubectl get service web-nodeport -n tutorial-services
```

The PORT(S) column shows something like `80:31456/TCP`. The number after the colon is the automatically allocated NodePort.

### Specifying a NodePort

To request a specific NodePort, use a YAML manifest:

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport-fixed
  namespace: tutorial-services
spec:
  type: NodePort
  selector:
    app: web-nodeport
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF
```

Verify the port:

```bash
kubectl get service web-nodeport-fixed -n tutorial-services
```

### Port Allocation Rules

The nodePort must be in the range 30000-32767. If you specify a port that is already in use, the service creation fails. When you let Kubernetes allocate automatically, it selects an available port from the range.

### Accessing via NodePort

Every node opens the NodePort, regardless of whether pods are running on that node. In a kind cluster, node IPs are internal to the container network. Test from within the cluster:

```bash
# Get node IPs
kubectl get nodes -o wide

# Test from within cluster
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n tutorial-services -- curl http://${NODE_IP}:30080
```

Any node IP with the NodePort reaches the service, even if the pod is on a different node. Kube-proxy handles routing.

### NodePort and External Traffic

NodePort is the foundation for external access, but it has limitations:
- Clients must know node IPs
- No automatic load balancing across nodes
- Ports must be in the 30000-32767 range
- Not suitable for production without additional load balancing

LoadBalancer services address these limitations.

### Cleanup

```bash
kubectl delete service web-nodeport web-nodeport-fixed -n tutorial-services
kubectl delete deployment web-nodeport -n tutorial-services
```

## LoadBalancer Services

LoadBalancer services extend NodePort by provisioning an external load balancer. In cloud environments, this creates a cloud-native load balancer (AWS ELB, GCP Load Balancer, Azure Load Balancer). In kind clusters, we use metallb to simulate this functionality.

### How LoadBalancer Works

When you create a LoadBalancer service, Kubernetes:
1. Creates a ClusterIP
2. Opens a NodePort on every node
3. Requests an external IP from the cloud provider (or metallb)
4. Configures the load balancer to forward traffic to the NodePort

The external load balancer provides a single entry point that distributes traffic across all nodes.

### Creating a LoadBalancer Service

Create a deployment:

```bash
kubectl create deployment web-lb --image=nginx:1.25 --replicas=3 -n tutorial-services
kubectl wait --for=condition=available deployment/web-lb -n tutorial-services --timeout=60s
```

Create a LoadBalancer service:

```bash
kubectl expose deployment web-lb --type=LoadBalancer --port=80 -n tutorial-services
```

Watch for the external IP assignment:

```bash
kubectl get service web-lb -n tutorial-services -w
```

With metallb installed, the EXTERNAL-IP column shows an IP from your configured pool. Without metallb, it would show `<pending>` indefinitely.

### LoadBalancer Service YAML

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-lb-yaml
  namespace: tutorial-services
spec:
  type: LoadBalancer
  selector:
    app: web-lb
  ports:
  - port: 80
    targetPort: 80
EOF
```

### Testing the External IP

```bash
EXTERNAL_IP=$(kubectl get service web-lb -n tutorial-services -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "External IP: $EXTERNAL_IP"
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n tutorial-services -- curl http://${EXTERNAL_IP}
```

### LoadBalancer Status

The service status shows load balancer details:

```bash
kubectl get service web-lb -n tutorial-services -o yaml | grep -A10 status
```

The `status.loadBalancer.ingress` field contains the external IP or hostname assigned by the load balancer provider.

### LoadBalancer Without a Provider

Without metallb or a cloud provider, LoadBalancer services remain in pending state:

```bash
kubectl get service web-lb -n tutorial-services
# EXTERNAL-IP shows <pending> without a provider
```

This is important to recognize during troubleshooting.

### Cleanup

```bash
kubectl delete service web-lb web-lb-yaml -n tutorial-services
kubectl delete deployment web-lb -n tutorial-services
```

## ExternalName Services

ExternalName services do not proxy traffic or create endpoints. Instead, they create a DNS CNAME record that points to an external DNS name. This provides a cluster-internal alias for external services.

### How ExternalName Works

When you create an ExternalName service:
1. No ClusterIP is allocated
2. No endpoints are created
3. DNS queries for the service name return a CNAME pointing to the externalName

The pod resolves the CNAME and connects directly to the external service.

### Creating an ExternalName Service

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: external-api
  namespace: tutorial-services
spec:
  type: ExternalName
  externalName: httpbin.org
EOF
```

Note: There is no imperative command for creating ExternalName services.

Check the service:

```bash
kubectl get service external-api -n tutorial-services
```

The output shows no ClusterIP (or "None") and the external name in the EXTERNAL-IP column.

### Testing ExternalName

```bash
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n tutorial-services -- curl http://external-api/get
```

DNS resolves `external-api.tutorial-services.svc.cluster.local` to `httpbin.org` via CNAME, and curl connects to httpbin.org.

### ExternalName Limitations

ExternalName services have several limitations:
- The externalName must be a DNS name, not an IP address
- No port mapping (the service does not proxy)
- No health checking (the service does not know if the external service is available)
- TLS certificates must match the external name, not the service name

### Use Cases for ExternalName

ExternalName is useful for:
- Providing a stable cluster-internal name for an external database
- Abstracting third-party APIs behind a local name
- Cross-cluster service references
- Gradual migration (point to external, then internal)

### Cleanup

```bash
kubectl delete service external-api -n tutorial-services
```

## Services Without Selectors

Services without selectors do not automatically discover pods. Instead, you manually create an Endpoints resource that defines the backend addresses. This is useful for routing to external services or custom backends.

### How Selectorless Services Work

When you create a service without a selector:
1. Kubernetes allocates a ClusterIP
2. No endpoints are created automatically
3. You must create an Endpoints resource with the same name as the service
4. The service routes traffic to the addresses in the Endpoints resource

### Creating a Service Without Selector

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: external-db
  namespace: tutorial-services
spec:
  ports:
  - port: 5432
    targetPort: 5432
EOF
```

Notice there is no `selector` field. Check the service:

```bash
kubectl get service external-db -n tutorial-services
kubectl get endpoints external-db -n tutorial-services
```

The service exists, but endpoints show `<none>`.

### Creating Manual Endpoints

Create an Endpoints resource with the same name as the service:

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Endpoints
metadata:
  name: external-db
  namespace: tutorial-services
subsets:
- addresses:
  - ip: 10.0.0.100
  - ip: 10.0.0.101
  ports:
  - port: 5432
EOF
```

Verify the endpoints:

```bash
kubectl get endpoints external-db -n tutorial-services
```

The endpoints now show the manually defined addresses.

### Endpoints Resource Structure

The Endpoints resource has a `subsets` array containing:
- `addresses`: List of IP addresses (each with an `ip` field)
- `ports`: List of ports (each with a `port` field and optional `protocol`)

Multiple addresses provide redundancy. The service load balances across all addresses.

### Updating Manual Endpoints

When your external backends change, update the Endpoints resource:

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Endpoints
metadata:
  name: external-db
  namespace: tutorial-services
subsets:
- addresses:
  - ip: 10.0.0.102
  - ip: 10.0.0.103
  - ip: 10.0.0.104
  ports:
  - port: 5432
EOF
```

Changes take effect immediately.

### Use Cases for Manual Endpoints

Manual endpoints are useful for:
- External databases or services that do not run in Kubernetes
- Legacy systems that cannot be containerized
- Services in other clusters or data centers
- Blue-green deployments with external traffic routing

### Cleanup

```bash
kubectl delete service external-db -n tutorial-services
kubectl delete endpoints external-db -n tutorial-services
```

## Choosing the Right External Service Type

| Requirement | Service Type |
|------------|--------------|
| Internal cluster access only | ClusterIP |
| External access via node ports | NodePort |
| External access with load balancing | LoadBalancer |
| DNS alias for external service | ExternalName |
| Routing to external IPs | No selector + manual Endpoints |

### Decision Factors

**NodePort:**
- Simple external access without cloud integration
- Development and testing environments
- When you manage your own load balancer

**LoadBalancer:**
- Production external access
- Cloud environments with load balancer integration
- When you need automatic health checking and load balancing

**ExternalName:**
- Abstracting external DNS names
- Service migration scenarios
- When you want pods to use a local name for external services

**Manual Endpoints:**
- External services with static IPs
- Hybrid cloud scenarios
- Legacy service integration

## Tutorial Cleanup

Delete all tutorial resources:

```bash
kubectl delete namespace tutorial-services
```

## Reference Commands

### Service Type Comparison

| Type | ClusterIP | NodePort | External Access | Use Case |
|------|-----------|----------|-----------------|----------|
| ClusterIP | Yes | No | No | Internal services |
| NodePort | Yes | Yes (30000-32767) | Via node IP:port | Simple external access |
| LoadBalancer | Yes | Yes | Via external IP | Production external access |
| ExternalName | No | No | DNS CNAME | External service alias |

### Creating Services

| Task | Command or YAML |
|------|-----------------|
| NodePort imperative | `kubectl expose deployment <name> --type=NodePort --port=80` |
| NodePort with specific port | YAML: spec.ports[].nodePort: 30080 |
| LoadBalancer imperative | `kubectl expose deployment <name> --type=LoadBalancer --port=80` |
| ExternalName | YAML only: spec.type: ExternalName, spec.externalName: dns.name |
| Without selector | YAML: omit spec.selector, create Endpoints resource |

### Verification Commands

| Task | Command |
|------|---------|
| Check NodePort | `kubectl get svc <name> -o jsonpath='{.spec.ports[0].nodePort}'` |
| Check external IP | `kubectl get svc <name> -o jsonpath='{.status.loadBalancer.ingress[0].ip}'` |
| Check endpoints | `kubectl get endpoints <name>` |
| Watch for IP assignment | `kubectl get svc <name> -w` |
