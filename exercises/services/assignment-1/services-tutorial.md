# Services Tutorial: Service Fundamentals and Discovery

This tutorial teaches you how Kubernetes Services provide stable network endpoints for pod-based applications. You will learn to create services of each type, understand service discovery mechanisms, inspect endpoints, and debug common issues.

## Introduction

In Kubernetes, pods are ephemeral. They can be created, destroyed, and rescheduled at any time, and each time a pod is created it receives a new IP address. This creates a problem: how do you reliably connect to a set of pods that provide a service when their IP addresses keep changing?

Kubernetes Services solve this problem by providing a stable virtual IP address (the ClusterIP) that acts as a front-end for a set of pods. The Service uses label selectors to identify which pods should receive traffic, and it automatically updates its endpoint list as pods come and go. Clients connect to the Service IP, and kube-proxy handles routing traffic to one of the backing pods.

Understanding Services is critical for the CKA exam. You need to know how to create services, verify their configuration, test connectivity, and troubleshoot issues. This tutorial covers all service types (ClusterIP, NodePort, LoadBalancer, ExternalName, and headless) along with service discovery via DNS and environment variables.

## Prerequisites

Before starting this tutorial, ensure you have:

- A multi-node kind cluster running (1 control-plane, 3 workers)
- metallb installed for LoadBalancer service testing (see README.md for setup)
- kubectl configured to communicate with your cluster

Verify your cluster is ready:

```bash
kubectl get nodes
```

You should see one control-plane node and three worker nodes, all in Ready status.

## Tutorial Setup

Create the tutorial namespace and verify it exists:

```bash
kubectl create namespace tutorial-services
kubectl get namespace tutorial-services
```

All resources in this tutorial will be created in this namespace.

## ClusterIP Services

ClusterIP is the default service type. It creates a virtual IP address that is only accessible from within the cluster. Pods can connect to this IP to reach the service backends.

### Creating a Backend Deployment

First, create a Deployment that will serve as the backend for our services:

```bash
kubectl create deployment web-backend --image=nginx:1.25 --replicas=3 -n tutorial-services
```

Wait for the pods to be ready:

```bash
kubectl get pods -n tutorial-services -l app=web-backend
```

You should see three pods running. Note their IP addresses:

```bash
kubectl get pods -n tutorial-services -l app=web-backend -o wide
```

These pod IPs will change if the pods are recreated. The Service provides a stable alternative.

### Creating a ClusterIP Service Imperatively

The simplest way to create a service is using `kubectl expose`:

```bash
kubectl expose deployment web-backend --port=80 --target-port=80 -n tutorial-services
```

This creates a ClusterIP service named `web-backend` that forwards traffic from port 80 to port 80 on the pods. Verify the service was created:

```bash
kubectl get service web-backend -n tutorial-services
```

The output shows the service type (ClusterIP), the cluster IP address, and the port mapping. The service uses the same labels as the Deployment (app=web-backend) to select its backends.

### Examining Service Details

Use `kubectl describe` to see the full service configuration:

```bash
kubectl describe service web-backend -n tutorial-services
```

The output includes the selector, endpoints (the pod IPs receiving traffic), and session affinity settings. The Endpoints line shows the IP:port combinations of the backing pods. If this line shows `<none>`, no pods match the selector.

### Testing Connectivity

To test connectivity to a ClusterIP service, you need to connect from within the cluster. Create a temporary pod with curl:

```bash
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n tutorial-services -- curl http://web-backend
```

This runs a temporary pod, executes curl against the service, and deletes the pod when done. You should see the nginx welcome page HTML. The service name `web-backend` resolves to the ClusterIP via cluster DNS.

### Creating a ClusterIP Service Declaratively

For production use, declarative YAML provides better control. Delete the existing service first:

```bash
kubectl delete service web-backend -n tutorial-services
```

Now create it with YAML:

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-backend
  namespace: tutorial-services
spec:
  type: ClusterIP
  selector:
    app: web-backend
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
EOF
```

The spec fields are:
- **type:** ClusterIP (this is the default, so it can be omitted)
- **selector:** Label selector matching pods to include in endpoints
- **ports:** Array of port mappings
  - **port:** The port the service listens on
  - **targetPort:** The port on the pod to forward to (can be a number or named port)
  - **protocol:** TCP (default) or UDP

Verify the service is working:

```bash
kubectl get service web-backend -n tutorial-services
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n tutorial-services -- curl http://web-backend
```

### Understanding Port vs. TargetPort

The service port and targetPort can differ. The service port is what clients connect to. The targetPort is what the pod listens on. For example, you might expose a service on port 80 while the container listens on port 8080:

```yaml
ports:
- port: 80
  targetPort: 8080
```

This is common when running non-root containers that cannot bind to privileged ports.

### Cleanup

Delete the service and deployment:

```bash
kubectl delete service web-backend -n tutorial-services
kubectl delete deployment web-backend -n tutorial-services
```

## NodePort Services

NodePort services build on ClusterIP. In addition to creating a ClusterIP, they expose the service on a static port (30000-32767) on every node in the cluster. External clients can access the service via any node's IP address and the NodePort.

### Creating a NodePort Service

Create a deployment and expose it as a NodePort service:

```bash
kubectl create deployment web-nodeport --image=nginx:1.25 --replicas=2 -n tutorial-services
kubectl expose deployment web-nodeport --type=NodePort --port=80 -n tutorial-services
```

Examine the service:

```bash
kubectl get service web-nodeport -n tutorial-services
```

The PORT(S) column shows something like `80:31234/TCP`. The number after the colon (31234) is the NodePort. Kubernetes automatically allocated a port in the 30000-32767 range.

### Specifying a NodePort

You can specify a particular NodePort in the YAML:

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-nodeport-specific
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

Verify the port was assigned:

```bash
kubectl get service web-nodeport-specific -n tutorial-services
```

### Accessing via NodePort

Every node in the cluster opens the NodePort, regardless of whether pods are running on that node. Get a node IP:

```bash
kubectl get nodes -o wide
```

In a kind cluster, the node IPs are internal to the container network. From outside the cluster (your host machine), you typically cannot reach these IPs directly. However, you can test from inside the cluster:

```bash
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n tutorial-services -- curl http://${NODE_IP}:30080
```

### Cleanup

```bash
kubectl delete service web-nodeport web-nodeport-specific -n tutorial-services
kubectl delete deployment web-nodeport -n tutorial-services
```

## LoadBalancer Services

LoadBalancer services extend NodePort by provisioning an external load balancer. In cloud environments, this creates a cloud load balancer (AWS ELB, GCP Load Balancer, etc.) that routes traffic to your nodes. In kind, we use metallb to simulate this behavior.

### Creating a LoadBalancer Service

Create a deployment and LoadBalancer service:

```bash
kubectl create deployment web-lb --image=nginx:1.25 --replicas=2 -n tutorial-services
kubectl expose deployment web-lb --type=LoadBalancer --port=80 -n tutorial-services
```

Check the service:

```bash
kubectl get service web-lb -n tutorial-services
```

With metallb installed, the EXTERNAL-IP column should show an IP address from your configured pool. Without metallb, it would show `<pending>` indefinitely.

### LoadBalancer Service YAML

The declarative form:

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

If metallb assigned an external IP, you can test connectivity:

```bash
EXTERNAL_IP=$(kubectl get service web-lb -n tutorial-services -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n tutorial-services -- curl http://${EXTERNAL_IP}
```

### Cleanup

```bash
kubectl delete service web-lb web-lb-yaml -n tutorial-services
kubectl delete deployment web-lb -n tutorial-services
```

## ExternalName Services

ExternalName services do not create endpoints or proxy traffic. Instead, they create a DNS CNAME record that points to an external DNS name. This is useful for providing a cluster-internal alias for an external service.

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
  externalName: api.example.com
EOF
```

There is no imperative command for creating ExternalName services.

### How ExternalName Works

When a pod in the cluster looks up `external-api.tutorial-services.svc.cluster.local`, DNS returns a CNAME pointing to `api.example.com`. The pod then resolves `api.example.com` normally.

```bash
kubectl get service external-api -n tutorial-services
```

Notice there is no ClusterIP (it shows as empty or "None"). ExternalName services do not have a selector or endpoints.

### Use Cases for ExternalName

ExternalName services are useful when you want to give an external service a cluster-internal name. For example, you might have a database running outside the cluster at `db.mycompany.internal`. Creating an ExternalName service called `database` allows pods to connect to `database` rather than hardcoding the external name.

### Cleanup

```bash
kubectl delete service external-api -n tutorial-services
```

## Headless Services

A headless service has its ClusterIP set to `None`. Instead of returning a single virtual IP, DNS queries for the service return the IP addresses of all backing pods. This is useful for clients that want to handle load balancing themselves or need to connect to specific pods.

### Creating a Headless Service

First, create a deployment:

```bash
kubectl create deployment web-headless --image=nginx:1.25 --replicas=3 -n tutorial-services
```

Then create a headless service:

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-headless
  namespace: tutorial-services
spec:
  clusterIP: None
  selector:
    app: web-headless
  ports:
  - port: 80
    targetPort: 80
EOF
```

Check the service:

```bash
kubectl get service web-headless -n tutorial-services
```

The CLUSTER-IP column shows `None`.

### DNS Behavior for Headless Services

A headless service returns multiple A records, one for each pod IP. Test this with a DNS lookup:

```bash
kubectl run dns-test --image=busybox:1.36 --rm -it -n tutorial-services -- nslookup web-headless
```

You should see multiple IP addresses in the response, one for each pod. This differs from a normal ClusterIP service, which returns a single IP.

### Use Cases for Headless Services

Headless services are commonly used with StatefulSets where clients need to connect to specific pods. They are also useful for service mesh integration or when you want client-side load balancing.

### Cleanup

```bash
kubectl delete service web-headless -n tutorial-services
kubectl delete deployment web-headless -n tutorial-services
```

## Service Discovery

Kubernetes provides two mechanisms for pods to discover services: DNS and environment variables.

### DNS-Based Discovery

Every service is registered with the cluster DNS (CoreDNS). Services can be reached using various DNS name formats:

- **Short name (within same namespace):** `<service-name>`
- **Namespace-qualified:** `<service-name>.<namespace>`
- **Service-qualified:** `<service-name>.<namespace>.svc`
- **Fully qualified:** `<service-name>.<namespace>.svc.cluster.local`

Create a service to test:

```bash
kubectl create deployment web-dns --image=nginx:1.25 --replicas=2 -n tutorial-services
kubectl expose deployment web-dns --port=80 -n tutorial-services
```

Test each DNS format from within the namespace:

```bash
kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -n tutorial-services -- /bin/sh -c "
  echo 'Testing short name:'
  curl -s http://web-dns | head -1
  echo 'Testing namespace-qualified:'
  curl -s http://web-dns.tutorial-services | head -1
  echo 'Testing FQDN:'
  curl -s http://web-dns.tutorial-services.svc.cluster.local | head -1
"
```

When accessing services from a different namespace, you must use at least the namespace-qualified name (`<service>.<namespace>`).

### Environment Variable Discovery

When a pod starts, Kubernetes injects environment variables for each service that existed at the time. The format is:

- `<SERVICE_NAME>_SERVICE_HOST`: The ClusterIP
- `<SERVICE_NAME>_SERVICE_PORT`: The port

Service names are uppercased and dashes are replaced with underscores.

Create a pod to examine the environment:

```bash
kubectl run env-test --image=busybox:1.36 -n tutorial-services --command -- sleep 3600
sleep 2
kubectl exec -n tutorial-services env-test -- env | grep -i web
```

You should see environment variables like `WEB_DNS_SERVICE_HOST` and `WEB_DNS_SERVICE_PORT`.

### When to Use Each Discovery Method

Environment variables have a significant limitation: they are only injected for services that exist when the pod starts. If a service is created after the pod, the environment variables will not be present. DNS discovery does not have this limitation.

DNS is generally preferred because:
- It works for services created after the pod
- It is more intuitive and readable
- It supports namespace-qualified names

Environment variables are useful when:
- You need compatibility with legacy applications
- You want to avoid DNS lookups

### Cleanup

```bash
kubectl delete pod env-test -n tutorial-services --force --grace-period=0
kubectl delete service web-dns -n tutorial-services
kubectl delete deployment web-dns -n tutorial-services
```

## Endpoints and EndpointSlices

The Service controller watches for pods matching the service selector and maintains an Endpoints resource containing their IP addresses.

### Inspecting Endpoints

Create a service and examine its endpoints:

```bash
kubectl create deployment web-endpoints --image=nginx:1.25 --replicas=3 -n tutorial-services
kubectl expose deployment web-endpoints --port=80 -n tutorial-services
kubectl get endpoints web-endpoints -n tutorial-services
```

The output shows the IP:port combinations of pods receiving traffic. Compare with the pod IPs:

```bash
kubectl get pods -n tutorial-services -l app=web-endpoints -o wide
```

The endpoint IPs should match the pod IPs.

### Empty Endpoints

If endpoints show `<none>`, no pods match the selector. This is often a symptom of a selector mismatch. Let's create a broken service:

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: broken-selector
  namespace: tutorial-services
spec:
  selector:
    app: wrong-label
  ports:
  - port: 80
EOF
```

Check the endpoints:

```bash
kubectl get endpoints broken-selector -n tutorial-services
```

The ENDPOINTS column shows `<none>` because no pods have `app=wrong-label`.

### EndpointSlices

EndpointSlices are a more scalable replacement for Endpoints, designed for services with many backends. They split endpoint information across multiple resources. You can view them with:

```bash
kubectl get endpointslices -n tutorial-services
```

For most debugging purposes, the Endpoints resource is sufficient, but understanding that EndpointSlices exist is useful for large-scale clusters.

### Cleanup

```bash
kubectl delete service web-endpoints broken-selector -n tutorial-services
kubectl delete deployment web-endpoints -n tutorial-services
```

## Pod Readiness and Service Endpoints

Services only include pods that are in the Ready state. When a pod's readiness probe fails, it is removed from the service endpoints.

### Demonstrating Readiness Impact

Create a deployment with a readiness probe:

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-ready
  namespace: tutorial-services
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-ready
  template:
    metadata:
      labels:
        app: web-ready
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 2
          periodSeconds: 5
EOF
```

Create a service:

```bash
kubectl expose deployment web-ready --port=80 -n tutorial-services
```

Wait for pods to be ready and check endpoints:

```bash
kubectl get pods -n tutorial-services -l app=web-ready
kubectl get endpoints web-ready -n tutorial-services
```

Both pod IPs should be in the endpoints. Now simulate a readiness failure by deleting the nginx default page in one pod:

```bash
POD=$(kubectl get pods -n tutorial-services -l app=web-ready -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n tutorial-services $POD -- rm /usr/share/nginx/html/index.html
```

Wait a few seconds for the readiness probe to fail:

```bash
kubectl get pods -n tutorial-services -l app=web-ready
kubectl get endpoints web-ready -n tutorial-services
```

The pod shows READY 0/1, and its IP is removed from endpoints. The service now only routes to the healthy pod.

### Cleanup

```bash
kubectl delete service web-ready -n tutorial-services
kubectl delete deployment web-ready -n tutorial-services
```

## Debugging Service Issues

Common service issues include selector mismatches, port errors, and pods not being ready. Here is a systematic debugging approach.

### Issue: Empty Endpoints

Symptoms: Service exists but has no endpoints. Curl to service times out or connection refused.

Diagnosis:

```bash
kubectl get endpoints <service-name> -n <namespace>
kubectl get svc <service-name> -n <namespace> -o wide  # Shows selector
kubectl get pods -l <selector-labels> -n <namespace>   # Check if pods match
```

Common causes:
- Selector labels do not match pod labels (typo in label key or value)
- Pods are in a different namespace
- No pods with the matching labels exist

### Issue: Connection Refused

Symptoms: Endpoints exist but curl to service returns "Connection refused".

Diagnosis:

```bash
kubectl get endpoints <service-name> -n <namespace>   # Endpoints exist
kubectl describe svc <service-name> -n <namespace>    # Check targetPort
kubectl get pods -l <selector> -n <namespace> -o jsonpath='{.items[0].spec.containers[0].ports}'
```

Common causes:
- targetPort does not match container port
- Container is not listening on the expected port
- Container process crashed

### Issue: Service Created After Pods

Symptoms: Environment variables for the service are not available in pods.

Diagnosis: Check when the pod and service were created. Environment variables are only injected for services that existed when the pod started.

Solution: Use DNS-based discovery or restart the pods.

### Debugging Commands Summary

| Command | Purpose |
|---------|---------|
| `kubectl get svc` | List services |
| `kubectl get svc -o wide` | List services with selectors |
| `kubectl describe svc <name>` | Full service details including endpoints |
| `kubectl get endpoints <name>` | Show endpoint IP:port pairs |
| `kubectl get pods -l <selector>` | Find pods matching a selector |
| `kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -- curl <target>` | Test connectivity |

## Testing Services with kubectl port-forward

While ClusterIP services are only accessible from within the cluster, you can temporarily expose them to your local machine using `kubectl port-forward`. This is a powerful debugging and development technique that lets you test services and pods without creating NodePort or LoadBalancer services. Port forwarding creates a tunnel from your local machine to the Kubernetes cluster, forwarding traffic from a local port to a port on a service or pod.

### When to Use Port Forwarding

Port forwarding is useful when you need to test a ClusterIP service from your local machine without exposing it externally, when you want to access an internal service for debugging or inspection without modifying its configuration, when you are developing locally and need quick access to cluster services, or when troubleshooting connectivity issues and you want to isolate whether the problem is with the service or with external access layers like Ingress or LoadBalancer. Port forwarding is not suitable for production traffic or long-running connections, as it terminates if the kubectl process exits or the network connection is interrupted.

### Port Forwarding to a Service

Create a deployment and service for demonstration.

```bash
kubectl create deployment port-forward-demo --image=nginx:1.27 --replicas=2 -n tutorial-services
kubectl expose deployment port-forward-demo --port=80 --target-port=80 -n tutorial-services
```

Wait for the pods to be ready.

```bash
kubectl wait --for=condition=available deployment/port-forward-demo -n tutorial-services --timeout=60s
```

Now forward a local port to the service.

```bash
kubectl port-forward service/port-forward-demo 8080:80 -n tutorial-services
```

This forwards your local port 8080 to port 80 on the service. The format is `local-port:service-port`. The command runs in the foreground and shows connection logs. Leave it running and open a new terminal to test connectivity.

In a new terminal, test the forwarded port.

```bash
curl http://localhost:8080
```

You should see the nginx welcome page HTML. This traffic is being forwarded through the kubectl process to the service in the cluster, and then to one of the backend pods. The service's load balancing still applies. Each request may hit a different pod.

Stop the port-forward by pressing Ctrl+C in the terminal where it is running.

### Port Forwarding to a Pod

You can also forward directly to a pod, bypassing the service. This is useful when you need to test a specific pod or when a service does not exist yet.

```bash
POD=$(kubectl get pods -n tutorial-services -l app=port-forward-demo -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward pod/$POD 8081:80 -n tutorial-services
```

This forwards your local port 8081 to port 80 on the specific pod. In another terminal, test it.

```bash
curl http://localhost:8081
```

The response comes from the specific pod you targeted, not from the service's load-balanced pool. Stop the port-forward with Ctrl+C.

### Choosing the Local Port

If you omit the local port, kubectl chooses the same port as the remote port.

```bash
kubectl port-forward service/port-forward-demo :80 -n tutorial-services
```

The output shows which local port was chosen, typically 80. If port 80 is already in use on your local machine, the command fails. You can also let kubectl choose a random available local port by using `:0` as the local port.

```bash
kubectl port-forward service/port-forward-demo 0:80 -n tutorial-services
```

The output shows `Forwarding from 127.0.0.1:<random-port> -> 80`. Check the output to see which port was assigned, then use that port in your curl command.

### Port Forwarding and Namespaces

Port forwarding respects namespace boundaries. If you forward to a service or pod in one namespace, you can only reach resources in that namespace. If you need to access services in multiple namespaces, you must run separate port-forward commands, each forwarding a different local port to a different namespace.

### Port Forward Limitations

Port forwarding is a client-side operation. If the kubectl process is killed, the connection drops. It is not suitable for long-running access or for sharing access with other users. For those use cases, create a NodePort or LoadBalancer service, or use an Ingress. Port forwarding also does not support UDP traffic, only TCP. If you need to test a UDP service, you must create a NodePort or use a different access method.

### Running Port Forward in the Background

You can run port-forward in the background using `&` in bash, but if you close the terminal, the process terminates. For persistent forwarding during a debugging session, run it in a dedicated terminal or use a terminal multiplexer like tmux or screen.

```bash
kubectl port-forward service/port-forward-demo 8080:80 -n tutorial-services > /dev/null 2>&1 &
```

This runs the port-forward in the background and suppresses output. To stop it, find the process ID and kill it.

```bash
ps aux | grep "port-forward"
kill <pid>
```

For most debugging tasks, running port-forward in a dedicated terminal with visible output is simpler and safer.

### Cleanup

```bash
kubectl delete service port-forward-demo -n tutorial-services
kubectl delete deployment port-forward-demo -n tutorial-services
```

## Tutorial Cleanup

Delete the tutorial namespace and all resources:

```bash
kubectl delete namespace tutorial-services
```

## Reference Commands

### Service Creation

| Task | Imperative | Declarative |
|------|------------|-------------|
| ClusterIP | `kubectl expose deployment <name> --port=80` | spec.type: ClusterIP |
| NodePort | `kubectl expose deployment <name> --type=NodePort --port=80` | spec.type: NodePort |
| LoadBalancer | `kubectl expose deployment <name> --type=LoadBalancer --port=80` | spec.type: LoadBalancer |
| ExternalName | Not available | spec.type: ExternalName, spec.externalName |
| Headless | Not available | spec.clusterIP: None |

### Service Verification

| Task | Command |
|------|---------|
| List services | `kubectl get svc -n <namespace>` |
| Show service details | `kubectl describe svc <name> -n <namespace>` |
| Show endpoints | `kubectl get endpoints <name> -n <namespace>` |
| Test connectivity | `kubectl run curl-test --image=curlimages/curl:8.5.0 --rm -it -- curl http://<service>` |
| DNS lookup | `kubectl run dns-test --image=busybox:1.36 --rm -it -- nslookup <service>` |
| Port-forward to service | `kubectl port-forward service/<name> <local-port>:<service-port> -n <namespace>` |
| Port-forward to pod | `kubectl port-forward pod/<name> <local-port>:<pod-port> -n <namespace>` |

### Debugging

| Symptom | Command |
|---------|---------|
| Empty endpoints | `kubectl get endpoints <name>` then check selector match |
| Connection refused | Check targetPort matches container port |
| DNS not resolving | Check CoreDNS pods in kube-system |
| Service pending | Check metallb or cloud LB config for LoadBalancer type |
