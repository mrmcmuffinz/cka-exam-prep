# Services Tutorial: Service Patterns and Troubleshooting

This tutorial covers advanced service patterns and systematic troubleshooting techniques. You will learn to configure multi-port services, session affinity, traffic policies, and how to diagnose and resolve common service issues.

## Introduction

Basic service configuration gets you connectivity, but production applications often require more sophisticated patterns. Multi-port services expose multiple endpoints through a single service. Session affinity ensures sticky sessions for stateful applications. Traffic policies control load balancing behavior and source IP preservation.

Equally important is the ability to troubleshoot service issues systematically. When a service is not working, you need to trace the problem through multiple layers: service configuration, selectors, endpoints, and pod readiness. This tutorial teaches both the advanced patterns and the troubleshooting methodology.

## Prerequisites

Before starting this tutorial, ensure you have:

- A multi-node kind cluster running (1 control-plane, 3 workers)
- Completed services/assignment-1 and assignment-2
- kubectl configured to communicate with your cluster

## Tutorial Setup

Create the tutorial namespace:

```bash
kubectl create namespace tutorial-services
```

## Multi-Port Services

Many applications expose multiple ports: an HTTP port and an HTTPS port, an application port and a metrics port, or primary and replica ports. Multi-port services allow you to expose all of these through a single service.

### Creating a Multi-Port Service

First, create a deployment with a container exposing multiple ports:

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multi-port-app
  namespace: tutorial-services
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
      - name: main
        image: nginx:1.25
        ports:
        - containerPort: 80
          name: http
        - containerPort: 443
          name: https
EOF

kubectl wait --for=condition=available deployment/multi-port-app -n tutorial-services --timeout=60s
```

Create a multi-port service:

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: multi-port-svc
  namespace: tutorial-services
spec:
  selector:
    app: multi-port-app
  ports:
  - name: http
    port: 80
    targetPort: http
  - name: https
    port: 443
    targetPort: https
EOF
```

### Port Naming Requirements

For multi-port services, each port MUST have a unique name. Without names, Kubernetes cannot distinguish between ports. The naming is also required when using Ingress resources.

```bash
kubectl get service multi-port-svc -n tutorial-services
kubectl describe service multi-port-svc -n tutorial-services
```

### Accessing Different Ports

You can access different ports using the port number:

```bash
# Access HTTP port
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n tutorial-services -- curl http://multi-port-svc:80

# Access HTTPS port (will fail SSL verification without proper certs)
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n tutorial-services -- curl -k https://multi-port-svc:443
```

### Named Port References

The targetPort can reference the container port by name instead of number:

```yaml
ports:
- name: http
  port: 80
  targetPort: http  # References the named port in container spec
```

This allows the container port number to change without updating the service. The container just needs to maintain the same port name.

### Different Protocols

You can mix TCP and UDP protocols in a multi-port service:

```yaml
ports:
- name: tcp-port
  port: 53
  targetPort: 53
  protocol: TCP
- name: udp-port
  port: 53
  targetPort: 53
  protocol: UDP
```

### Cleanup

```bash
kubectl delete service multi-port-svc -n tutorial-services
kubectl delete deployment multi-port-app -n tutorial-services
```

## Session Affinity

By default, services distribute requests across all endpoints using round-robin. Session affinity ensures that requests from the same client go to the same backend pod.

### ClientIP Affinity

The only supported affinity mode is `ClientIP`, which routes requests from the same client IP to the same pod:

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: affinity-app
  namespace: tutorial-services
spec:
  replicas: 3
  selector:
    matchLabels:
      app: affinity-app
  template:
    metadata:
      labels:
        app: affinity-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: affinity-svc
  namespace: tutorial-services
spec:
  selector:
    app: affinity-app
  ports:
  - port: 80
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600
EOF

kubectl wait --for=condition=available deployment/affinity-app -n tutorial-services --timeout=60s
```

### Session Affinity Configuration

The sessionAffinityConfig.clientIP.timeoutSeconds field sets how long the affinity lasts. After this timeout without requests from the client, the affinity expires and the next request may go to a different pod.

```bash
kubectl get service affinity-svc -n tutorial-services -o yaml | grep -A5 sessionAffinity
```

### Testing Session Affinity

Make multiple requests from the same pod:

```bash
kubectl run affinity-test --image=curlimages/curl:8.5.0 -n tutorial-services --command -- sleep 3600
sleep 2

# Multiple requests should go to the same backend
for i in 1 2 3 4 5; do
  kubectl exec -n tutorial-services affinity-test -- curl -s http://affinity-svc 2>/dev/null | head -1
done

kubectl delete pod affinity-test -n tutorial-services --force --grace-period=0
```

Without session affinity, requests would be distributed across all pods.

### When to Use Session Affinity

Session affinity is useful for:
- Applications storing session state in memory
- Connections that need to maintain state
- Debugging by isolating traffic to one pod

However, session affinity has limitations:
- Does not work across service types
- Based on client IP, not HTTP session cookies
- Can cause uneven load distribution

### Cleanup

```bash
kubectl delete service affinity-svc -n tutorial-services
kubectl delete deployment affinity-app -n tutorial-services
```

## Traffic Policies

Traffic policies control how traffic is distributed to pods and whether source IP addresses are preserved.

### External Traffic Policy

The externalTrafficPolicy field applies to NodePort and LoadBalancer services. It has two values:

**Cluster (default):** Traffic is distributed to all pods in the cluster, regardless of which node received it. This provides even distribution but loses the original client IP.

**Local:** Traffic is only routed to pods on the node that received the request. This preserves the client IP but can cause uneven distribution if pods are not evenly spread across nodes.

### Demonstrating Traffic Policies

Create a deployment with pods showing which node they run on:

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: policy-app
  namespace: tutorial-services
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
---
apiVersion: v1
kind: Service
metadata:
  name: policy-cluster
  namespace: tutorial-services
spec:
  type: NodePort
  selector:
    app: policy-app
  ports:
  - port: 80
    nodePort: 30081
  externalTrafficPolicy: Cluster
---
apiVersion: v1
kind: Service
metadata:
  name: policy-local
  namespace: tutorial-services
spec:
  type: NodePort
  selector:
    app: policy-app
  ports:
  - port: 80
    nodePort: 30082
  externalTrafficPolicy: Local
EOF

kubectl wait --for=condition=available deployment/policy-app -n tutorial-services --timeout=60s
```

### Testing Cluster vs Local

With Cluster policy, traffic to any node reaches all pods:

```bash
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

# Cluster policy: traffic reaches all pods
for i in 1 2 3 4 5; do
  kubectl run curl-$i --image=curlimages/curl:8.5.0 --rm -it -n tutorial-services -- curl -s http://${NODE_IP}:30081 2>/dev/null | head -1
done
```

With Local policy, traffic only reaches pods on the node that received it:

```bash
# Local policy: traffic only reaches pods on the same node
# If no pods on that node, request may time out
for i in 1 2 3 4 5; do
  kubectl run curl-$i --image=curlimages/curl:8.5.0 --rm -it -n tutorial-services -- curl -s --max-time 2 http://${NODE_IP}:30082 2>/dev/null | head -1
done
```

### Internal Traffic Policy

Kubernetes 1.21+ supports internalTrafficPolicy for ClusterIP services. Like externalTrafficPolicy, it can be Cluster (default) or Local.

### Traffic Policy Considerations

**Use Cluster when:**
- You need even distribution across all pods
- Client IP preservation is not required
- Pods may not be on every node

**Use Local when:**
- You need to preserve client IP addresses
- Pods are evenly distributed across nodes
- You accept potential uneven distribution

### Cleanup

```bash
kubectl delete service policy-cluster policy-local -n tutorial-services
kubectl delete deployment policy-app -n tutorial-services
```

## Troubleshooting Empty Endpoints

Empty endpoints are the most common service issue. When a service has no endpoints, pods are either not matching the selector or not in Ready state.

### Creating an Empty Endpoint Scenario

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: debug-app
  namespace: tutorial-services
spec:
  replicas: 2
  selector:
    matchLabels:
      app: debug-app
      version: v1
  template:
    metadata:
      labels:
        app: debug-app
        version: v1
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: debug-svc
  namespace: tutorial-services
spec:
  selector:
    app: debug-app
    version: v2
  ports:
  - port: 80
EOF

kubectl wait --for=condition=available deployment/debug-app -n tutorial-services --timeout=60s
```

### Diagnosing Empty Endpoints

Step 1: Check endpoints

```bash
kubectl get endpoints debug-svc -n tutorial-services
# Shows <none>
```

Step 2: Check the service selector

```bash
kubectl get service debug-svc -n tutorial-services -o wide
# Shows selector app=debug-app,version=v2
```

Step 3: Check pod labels

```bash
kubectl get pods -n tutorial-services -l app=debug-app --show-labels
# Shows version=v1, not v2
```

Step 4: Compare and fix

The service selector requires version=v2, but pods have version=v1. Fix by matching the service selector to pod labels:

```bash
kubectl patch service debug-svc -n tutorial-services -p '{"spec":{"selector":{"app":"debug-app","version":"v1"}}}'
kubectl get endpoints debug-svc -n tutorial-services
```

### Cleanup

```bash
kubectl delete service debug-svc -n tutorial-services
kubectl delete deployment debug-app -n tutorial-services
```

## Troubleshooting Port Issues

When endpoints exist but connections fail, the targetPort is often wrong.

### Creating a Port Issue

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: port-debug
  namespace: tutorial-services
spec:
  replicas: 2
  selector:
    matchLabels:
      app: port-debug
  template:
    metadata:
      labels:
        app: port-debug
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
  name: port-svc
  namespace: tutorial-services
spec:
  selector:
    app: port-debug
  ports:
  - port: 80
    targetPort: 8080
EOF

kubectl wait --for=condition=available deployment/port-debug -n tutorial-services --timeout=60s
```

### Diagnosing Port Issues

Step 1: Check endpoints exist

```bash
kubectl get endpoints port-svc -n tutorial-services
# Shows endpoints
```

Step 2: Try to connect

```bash
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n tutorial-services -- curl -s --max-time 5 http://port-svc
# Connection refused
```

Step 3: Check the targetPort

```bash
kubectl get service port-svc -n tutorial-services -o jsonpath='{.spec.ports[0].targetPort}'
# Shows 8080
```

Step 4: Check the container port

```bash
kubectl get pods -n tutorial-services -l app=port-debug -o jsonpath='{.items[0].spec.containers[0].ports[0].containerPort}'
# Shows 80
```

Step 5: Fix the mismatch

```bash
kubectl patch service port-svc -n tutorial-services -p '{"spec":{"ports":[{"port":80,"targetPort":80}]}}'
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n tutorial-services -- curl -s http://port-svc
```

### Cleanup

```bash
kubectl delete service port-svc -n tutorial-services
kubectl delete deployment port-debug -n tutorial-services
```

## Troubleshooting Readiness Issues

Services only include Ready pods in endpoints. Readiness probe failures cause pods to be excluded.

### Creating a Readiness Issue

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ready-debug
  namespace: tutorial-services
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ready-debug
  template:
    metadata:
      labels:
        app: ready-debug
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
  namespace: tutorial-services
spec:
  selector:
    app: ready-debug
  ports:
  - port: 80
EOF

sleep 10
```

### Diagnosing Readiness Issues

Step 1: Check pod status

```bash
kubectl get pods -n tutorial-services -l app=ready-debug
# Shows 0/1 Ready
```

Step 2: Check endpoints

```bash
kubectl get endpoints ready-svc -n tutorial-services
# Shows <none> or partial endpoints
```

Step 3: Check why pods are not ready

```bash
kubectl describe pod -n tutorial-services -l app=ready-debug | grep -A10 "Conditions:"
# Ready: False

kubectl describe pod -n tutorial-services -l app=ready-debug | grep -A5 "Readiness"
# Shows probe failure
```

Step 4: Understand the probe configuration

```bash
kubectl get deployment ready-debug -n tutorial-services -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}'
# Shows httpGet path: /healthz
```

Step 5: Fix (change probe path to one that exists)

```bash
kubectl patch deployment ready-debug -n tutorial-services --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}]'

# Wait for rollout
kubectl rollout status deployment/ready-debug -n tutorial-services

kubectl get pods -n tutorial-services -l app=ready-debug
kubectl get endpoints ready-svc -n tutorial-services
```

### Cleanup

```bash
kubectl delete service ready-svc -n tutorial-services
kubectl delete deployment ready-debug -n tutorial-services
```

## Troubleshooting Workflow

Follow this systematic approach when debugging service issues:

### Step 1: Check Service Exists

```bash
kubectl get service <name> -n <namespace>
```

If the service does not exist, create it.

### Step 2: Check Endpoints

```bash
kubectl get endpoints <name> -n <namespace>
```

If endpoints are empty, proceed to Step 3. If endpoints exist but connections fail, skip to Step 4.

### Step 3: Debug Empty Endpoints

Check the selector:
```bash
kubectl get svc <name> -n <namespace> -o wide
kubectl get pods -l <selector> -n <namespace> --show-labels
```

If no pods match the selector, either fix the selector or fix the pod labels.

If pods exist, check readiness:
```bash
kubectl get pods -l <selector> -n <namespace>
```

If pods show 0/X Ready, investigate readiness probe failures.

### Step 4: Debug Connection Failures

Check targetPort:
```bash
kubectl get svc <name> -n <namespace> -o jsonpath='{.spec.ports[*].targetPort}'
kubectl get pods -l <selector> -n <namespace> -o jsonpath='{.items[0].spec.containers[0].ports}'
```

If targetPort does not match containerPort, fix the service.

If ports match, check if the container process is running:
```bash
kubectl exec <pod> -n <namespace> -- netstat -tlnp
```

### Step 5: Verify Resolution

```bash
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n <namespace> -- curl http://<service>
```

## Tutorial Cleanup

Delete all tutorial resources:

```bash
kubectl delete namespace tutorial-services
```

## Reference Commands

### Multi-Port Services

```yaml
spec:
  ports:
  - name: http      # Required for multi-port
    port: 80
    targetPort: http
  - name: https
    port: 443
    targetPort: https
```

### Session Affinity

```yaml
spec:
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600
```

### Traffic Policies

```yaml
spec:
  type: NodePort  # or LoadBalancer
  externalTrafficPolicy: Local  # or Cluster (default)
```

### Troubleshooting Commands

| Symptom | Command |
|---------|---------|
| Check endpoints | `kubectl get endpoints <name> -n <namespace>` |
| Check selector | `kubectl get svc <name> -o wide` |
| Check pod labels | `kubectl get pods --show-labels` |
| Check pod readiness | `kubectl get pods` |
| Check probe config | `kubectl describe pod <name> \| grep -A5 Readiness` |
| Check targetPort | `kubectl get svc <name> -o jsonpath='{.spec.ports}'` |
| Check containerPort | `kubectl get pod <name> -o jsonpath='{.spec.containers[0].ports}'` |
| Test connectivity | `kubectl run curl --image=curlimages/curl:8.5.0 --rm -it -- curl <svc>` |
