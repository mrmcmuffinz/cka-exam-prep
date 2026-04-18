# Ingress and Gateway API Tutorial: Gateway API

## Introduction

Gateway API is the successor to Ingress, providing a more expressive, extensible, and role-oriented approach to routing. While Ingress uses a single resource with annotations for customization, Gateway API uses multiple purpose-built resources that separate infrastructure concerns from application routing.

The Gateway API resource model:
- **GatewayClass:** Defines the controller implementation (infrastructure team)
- **Gateway:** Defines listeners, ports, and protocols (platform team)
- **HTTPRoute:** Defines routing rules (application team)

This separation enables better multi-tenancy and clearer responsibility boundaries.

## Prerequisites

Kind cluster from previous assignments.

## Install Gateway API CRDs

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

## Install a Gateway Controller

For kind, use nginx-gateway-fabric:

```bash
kubectl apply -f https://github.com/nginxinc/nginx-gateway-fabric/releases/download/v1.1.0/crds.yaml
kubectl apply -f https://github.com/nginxinc/nginx-gateway-fabric/releases/download/v1.1.0/nginx-gateway.yaml
```

Wait for the controller:

```bash
kubectl wait --for=condition=Available deployment/nginx-gateway -n nginx-gateway --timeout=120s
```

## Setup

```bash
kubectl create namespace tutorial-ingress

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: tutorial-ingress
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
  namespace: tutorial-ingress
spec:
  selector:
    app: web
  ports:
  - port: 80
EOF

kubectl wait --for=condition=Ready pods --all -n tutorial-ingress --timeout=60s
```

## GatewayClass

GatewayClass defines which controller handles Gateways:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: nginx
spec:
  controllerName: gateway.nginx.org/nginx-gateway-controller
```

List GatewayClasses:

```bash
kubectl get gatewayclass
```

## Gateway

Gateway defines listeners (ports, protocols, hostnames):

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: example-gateway
  namespace: tutorial-ingress
spec:
  gatewayClassName: nginx
  listeners:
  - name: http
    port: 80
    protocol: HTTP
```

Check Gateway status:

```bash
kubectl get gateway -n tutorial-ingress
kubectl describe gateway example-gateway -n tutorial-ingress
```

## HTTPRoute

HTTPRoute defines routing rules that attach to Gateways:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web-route
  namespace: tutorial-ingress
spec:
  parentRefs:
  - name: example-gateway
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: web-svc
      port: 80
```

The `parentRefs` field specifies which Gateway this route attaches to.

## Path Matching

HTTPRoute supports multiple path types:

```yaml
matches:
- path:
    type: PathPrefix
    value: /api
```

- **PathPrefix:** Matches path prefix (like Ingress pathType: Prefix)
- **Exact:** Matches exact path
- **RegularExpression:** Regex matching

## Header-Based Routing

```yaml
matches:
- headers:
  - name: version
    value: v2
```

Routes requests with `version: v2` header.

## Traffic Splitting

```yaml
backendRefs:
- name: web-v1
  port: 80
  weight: 90
- name: web-v2
  port: 80
  weight: 10
```

Routes 90% to v1, 10% to v2.

## Gateway API vs Ingress

| Feature | Ingress | Gateway API |
|---------|---------|-------------|
| Role separation | No | Yes (GatewayClass/Gateway/Route) |
| Multi-tenancy | Limited | Built-in |
| Header routing | Annotation | Native |
| Traffic splitting | Annotation | Native |
| TLS config | In Ingress | In Gateway listener |

## Troubleshooting

### Gateway Not Ready

```bash
kubectl describe gateway <name>
# Check Status.Conditions
```

### HTTPRoute Not Attached

```bash
kubectl describe httproute <name>
# Check Status.Parents
```

Common issues:
- Wrong parentRef name or namespace
- Gateway does not accept routes from this namespace
- GatewayClass does not exist

## Cleanup

```bash
kubectl delete namespace tutorial-ingress
```

## Reference Commands

| Task | Command |
|------|---------|
| List GatewayClasses | `kubectl get gatewayclass` |
| List Gateways | `kubectl get gateway -A` |
| List HTTPRoutes | `kubectl get httproute -A` |
| Describe Gateway | `kubectl describe gateway <name> -n <ns>` |
| Describe HTTPRoute | `kubectl describe httproute <name> -n <ns>` |
