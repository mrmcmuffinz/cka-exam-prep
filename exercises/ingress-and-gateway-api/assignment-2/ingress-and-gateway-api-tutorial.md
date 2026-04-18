# Ingress and Gateway API Tutorial: Advanced Ingress and TLS

## Introduction

Building on Ingress fundamentals, this tutorial covers advanced features: controller-specific annotations that customize behavior, URL rewriting for path manipulation, and TLS termination for HTTPS. These features are essential for production deployments where you need fine-grained control over traffic handling.

## Prerequisites

Kind cluster with nginx-ingress from assignment 1.

## Setup

```bash
kubectl create namespace tutorial-ingress

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: tutorial-ingress
spec:
  replicas: 1
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
  namespace: tutorial-ingress
spec:
  selector:
    app: backend
  ports:
  - port: 80
EOF

kubectl wait --for=condition=Ready pods --all -n tutorial-ingress --timeout=60s
```

## Ingress Annotations

Annotations customize nginx-ingress behavior. Common annotations:

### ssl-redirect

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
```

Set to "false" to allow HTTP access (default is "true" which redirects to HTTPS).

### rewrite-target

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
```

Rewrites the URL path before forwarding to the backend.

### proxy-body-size

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
```

Limits request body size.

## Rewrite-Target

Rewrite-target transforms the URL path. Without rewrite, `/app/api` is forwarded as `/app/api`. With rewrite-target: `/`, it becomes `/`.

### Basic Rewrite

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rewrite-example
  namespace: tutorial-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /app
        pathType: Prefix
        backend:
          service:
            name: backend-svc
            port:
              number: 80
```

Request `/app/users` becomes `/users` on the backend.

### Capturing Groups

Use regex captures for complex rewrites:

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  rules:
  - http:
      paths:
      - path: /app(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: backend-svc
            port:
              number: 80
```

`$2` captures everything after `/app/`.

## TLS Termination

TLS terminates HTTPS at the Ingress controller, forwarding plain HTTP to backends.

### Create a Self-Signed Certificate

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=example.com/O=example"
```

### Create TLS Secret

```bash
kubectl create secret tls example-tls \
  --cert=tls.crt --key=tls.key \
  -n tutorial-ingress
```

Or declaratively:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: example-tls
  namespace: tutorial-ingress
type: kubernetes.io/tls
data:
  tls.crt: <base64-encoded-cert>
  tls.key: <base64-encoded-key>
```

### Ingress with TLS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
  namespace: tutorial-ingress
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - example.com
    secretName: example-tls
  rules:
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: backend-svc
            port:
              number: 80
```

### Test HTTPS

```bash
curl -k -H "Host: example.com" https://localhost/
```

The `-k` flag ignores certificate verification (for self-signed certs).

## Multiple TLS Hosts

```yaml
spec:
  tls:
  - hosts:
    - site-a.example.com
    secretName: site-a-tls
  - hosts:
    - site-b.example.com
    secretName: site-b-tls
  rules:
  - host: site-a.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: site-a-svc
            port:
              number: 80
  - host: site-b.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: site-b-svc
            port:
              number: 80
```

## Cleanup

```bash
kubectl delete namespace tutorial-ingress
rm -f tls.key tls.crt
```

## Reference Commands

| Task | Command |
|------|---------|
| Generate self-signed cert | `openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=example.com"` |
| Create TLS secret | `kubectl create secret tls <name> --cert=tls.crt --key=tls.key -n <ns>` |
| Test HTTPS | `curl -k -H "Host: name" https://localhost/` |
| View secret | `kubectl get secret <name> -n <ns> -o yaml` |
