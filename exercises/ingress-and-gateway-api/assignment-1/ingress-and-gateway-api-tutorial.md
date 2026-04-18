# Ingress and Gateway API Tutorial: Ingress Fundamentals

## Introduction

Ingress provides HTTP and HTTPS routing from outside the cluster to services within. While Services with type LoadBalancer or NodePort can expose individual applications, Ingress allows you to route traffic to multiple backend services based on URL paths or hostnames. This makes Ingress essential for hosting multiple applications behind a single external IP address.

Ingress resources by themselves do nothing. They require an Ingress controller to watch Ingress resources and configure the underlying load balancer or proxy. The most common Ingress controller is nginx-ingress, which uses NGINX as the reverse proxy. This tutorial uses nginx-ingress for all examples.

This tutorial covers the Ingress resource structure, installing nginx-ingress in a kind cluster, path-based and host-based routing, path types, and basic troubleshooting.

## Prerequisites

You need a kind cluster with port mappings configured for Ingress. Create the cluster:

```bash
cat <<EOF | KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
EOF
```

The `extraPortMappings` make ports 80 and 443 on the kind node accessible from your host.

## Install nginx-ingress Controller

Install the nginx-ingress controller configured for kind:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

Wait for the controller to be ready:

```bash
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
```

Verify installation:

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

## Setup

Create the tutorial namespace and test services:

```bash
kubectl create namespace tutorial-ingress

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-v1
  namespace: tutorial-ingress
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
      version: v1
  template:
    metadata:
      labels:
        app: web
        version: v1
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
  name: web-v1-svc
  namespace: tutorial-ingress
spec:
  selector:
    app: web
    version: v1
  ports:
  - port: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-v1
  namespace: tutorial-ingress
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
      version: v1
  template:
    metadata:
      labels:
        app: api
        version: v1
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
  name: api-v1-svc
  namespace: tutorial-ingress
spec:
  selector:
    app: api
    version: v1
  ports:
  - port: 80
EOF

kubectl wait --for=condition=Ready pods --all -n tutorial-ingress --timeout=60s
```

## Ingress Resource Structure

An Ingress resource has this structure:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
  namespace: tutorial-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-v1-svc
            port:
              number: 80
```

### Key Fields

**spec.ingressClassName:** Identifies which Ingress controller should handle this Ingress. For nginx-ingress, use `nginx`.

**spec.rules:** List of routing rules. Each rule can specify a hostname and paths.

**spec.rules[].host:** Optional hostname for this rule. If omitted, the rule matches all hosts.

**spec.rules[].http.paths:** List of path-based routes within this rule.

**spec.rules[].http.paths[].path:** URL path to match.

**spec.rules[].http.paths[].pathType:** How to match the path (Prefix, Exact, or ImplementationSpecific).

**spec.rules[].http.paths[].backend:** The service to route matching traffic to.

## Creating Your First Ingress

Create a simple Ingress that routes all traffic to web-v1-svc:

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: simple-ingress
  namespace: tutorial-ingress
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-v1-svc
            port:
              number: 80
EOF
```

Check the Ingress:

```bash
kubectl get ingress -n tutorial-ingress
```

Output shows the Ingress with an ADDRESS (may take a moment to populate):

```
NAME             CLASS   HOSTS   ADDRESS     PORTS   AGE
simple-ingress   nginx   *       localhost   80      30s
```

Test it:

```bash
curl http://localhost/
```

You should see the nginx welcome page.

## Path Types

The `pathType` field controls how path matching works:

### Prefix

Matches if the URL path starts with the specified path:

```yaml
path: /api
pathType: Prefix
```

Matches: `/api`, `/api/`, `/api/users`, `/api/v1/users`

### Exact

Matches only if the URL path exactly equals the specified path:

```yaml
path: /api
pathType: Exact
```

Matches: `/api` only
Does not match: `/api/`, `/api/users`

### ImplementationSpecific

The controller decides how to match. Behavior varies by controller.

### Path Matching Priority

When multiple paths could match, Kubernetes uses these rules:

1. Exact matches take precedence over Prefix matches
2. Longer Prefix paths take precedence over shorter ones

Example:

```yaml
paths:
- path: /api
  pathType: Prefix
  backend:
    service:
      name: general-api
- path: /api/v2
  pathType: Prefix
  backend:
    service:
      name: v2-api
```

Request to `/api/v2/users` goes to `v2-api` (longer prefix wins).

## Path-Based Routing

Route different paths to different services:

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-routing
  namespace: tutorial-ingress
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /web
        pathType: Prefix
        backend:
          service:
            name: web-v1-svc
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-v1-svc
            port:
              number: 80
EOF
```

Test both paths:

```bash
curl http://localhost/web
curl http://localhost/api
```

Both should return the nginx welcome page (since both services run nginx).

## Host-Based Routing

Route different hostnames to different services:

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: host-routing
  namespace: tutorial-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: web.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-v1-svc
            port:
              number: 80
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-v1-svc
            port:
              number: 80
EOF
```

Test with the Host header:

```bash
curl -H "Host: web.example.com" http://localhost/
curl -H "Host: api.example.com" http://localhost/
```

### Wildcard Hosts

Use `*` to match subdomains:

```yaml
- host: "*.example.com"
```

Matches: `web.example.com`, `api.example.com`, `anything.example.com`
Does not match: `example.com` (no subdomain)

## Default Backend

A default backend handles requests that do not match any rule:

```yaml
spec:
  defaultBackend:
    service:
      name: default-svc
      port:
        number: 80
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-svc
            port:
              number: 80
```

Requests to hosts other than `api.example.com` go to `default-svc`.

## Ingress Verification

Check Ingress status:

```bash
kubectl get ingress -n tutorial-ingress
kubectl describe ingress path-routing -n tutorial-ingress
```

The describe output shows:

- Rules and backends
- Default backend (if any)
- Events (errors if misconfigured)

## Basic Troubleshooting

### No ADDRESS Assigned

If the Ingress shows no ADDRESS:

```bash
# Check if controller is running
kubectl get pods -n ingress-nginx

# Check controller logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

### Backend Not Found

If you see "service not found" errors:

```bash
# Verify service exists
kubectl get svc -n tutorial-ingress

# Check service name matches Ingress
kubectl describe ingress <name> -n tutorial-ingress
```

### No Endpoints

If the service has no endpoints:

```bash
# Check service has endpoints
kubectl get endpoints <service-name> -n tutorial-ingress

# Verify pods are running and ready
kubectl get pods -n tutorial-ingress
```

### Path Not Matching

If requests do not route as expected:

```bash
# Check pathType
kubectl describe ingress <name> -n tutorial-ingress

# Verify path starts with /
# Common mistake: path: api instead of path: /api
```

## Verification

Test the setup:

```bash
# Ingress controller running
kubectl get pods -n ingress-nginx

# Services have endpoints
kubectl get endpoints -n tutorial-ingress

# Ingress has address
kubectl get ingress -n tutorial-ingress

# Curl test
curl http://localhost/
```

## Cleanup

Delete the tutorial namespace:

```bash
kubectl delete namespace tutorial-ingress
```

## Reference Commands

| Task | Command |
|------|---------|
| List Ingresses | `kubectl get ingress -n <namespace>` |
| Describe Ingress | `kubectl describe ingress <name> -n <namespace>` |
| Check controller | `kubectl get pods -n ingress-nginx` |
| Controller logs | `kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller` |
| Check endpoints | `kubectl get endpoints <service> -n <namespace>` |
| Test with Host header | `curl -H "Host: hostname" http://localhost/` |
| Test path | `curl http://localhost/path` |
