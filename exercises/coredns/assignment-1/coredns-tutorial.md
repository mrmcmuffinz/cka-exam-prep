# CoreDNS Tutorial: DNS Fundamentals

## Introduction

DNS is the backbone of service discovery in Kubernetes. When a pod needs to communicate with a service, it does not need to know the service's IP address. Instead, it can use the service name, and the cluster's DNS system resolves that name to the correct IP address. This abstraction makes applications portable and resilient to changes in service locations.

Every Kubernetes cluster runs a DNS service, typically CoreDNS, that provides name resolution for services and pods. When you create a Service, Kubernetes automatically creates a DNS record for it. Pods are configured at startup to use the cluster DNS service as their nameserver, which is why service names "just work" from within pods.

This tutorial covers the DNS record formats for services and pods, the different DNS policies available for pods, how to examine DNS configuration within pods, and how to use tools like nslookup and dig to query and debug DNS. These fundamentals are essential for understanding how service discovery works and for troubleshooting connectivity issues.

## Prerequisites

You need a running kind cluster. Create a multi-node cluster if you do not already have one:

```bash
cat <<EOF | KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
EOF
```

Verify the cluster is running:

```bash
kubectl cluster-info
kubectl get nodes
```

## Setup

Create the tutorial namespace and some services and pods to work with:

```bash
kubectl create namespace tutorial-coredns
```

Create a web service deployment:

```yaml
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: tutorial-coredns
spec:
  replicas: 2
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
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: tutorial-coredns
spec:
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 80
EOF
```

Create a second namespace with another service for cross-namespace testing:

```bash
kubectl create namespace tutorial-coredns-backend

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: tutorial-coredns-backend
spec:
  replicas: 1
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
  name: api-service
  namespace: tutorial-coredns-backend
spec:
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 80
EOF
```

Create a debug pod with DNS tools:

```yaml
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: dnstools
  namespace: tutorial-coredns
spec:
  containers:
  - name: dnstools
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
```

Wait for all pods to be ready:

```bash
kubectl get pods -n tutorial-coredns -w
kubectl get pods -n tutorial-coredns-backend -w
```

## Service DNS Format

Kubernetes creates DNS records for every Service. The full DNS name for a service follows this format:

```
<service-name>.<namespace>.svc.cluster.local
```

The components are:

- **service-name**: The name you gave the service in its metadata
- **namespace**: The namespace where the service lives
- **svc**: A literal string indicating this is a service record
- **cluster.local**: The default cluster domain (configurable but rarely changed)

For the web-service in tutorial-coredns namespace, the full DNS name is:

```
web-service.tutorial-coredns.svc.cluster.local
```

### Short Names Within Namespace

Pods do not need to use the full DNS name when accessing services in the same namespace. Kubernetes configures pods with search domains that allow shorter names to work. From a pod in tutorial-coredns, all of these will resolve to the same service:

```
web-service
web-service.tutorial-coredns
web-service.tutorial-coredns.svc
web-service.tutorial-coredns.svc.cluster.local
```

Test this from the dnstools pod:

```bash
kubectl exec -n tutorial-coredns dnstools -- nslookup web-service
```

The output shows the IP address of the web-service:

```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      web-service
Address 1: 10.96.X.X web-service.tutorial-coredns.svc.cluster.local
```

### Cross-Namespace DNS

To access a service in a different namespace, you must include at least the namespace in the DNS name. From a pod in tutorial-coredns, access the api-service in tutorial-coredns-backend:

```bash
kubectl exec -n tutorial-coredns dnstools -- nslookup api-service.tutorial-coredns-backend
```

The short name `api-service` alone will not work because search domains only include the pod's own namespace.

### FQDN for External Domains

When accessing external domains (outside the cluster), always use the fully qualified domain name with a trailing dot, or ensure the query is specific enough to avoid search domain expansion. For example, `google.com` will first try `google.com.tutorial-coredns.svc.cluster.local` before trying the actual `google.com`. Adding a trailing dot or using the full name prevents this expansion.

## Pod DNS Records

Kubernetes also creates DNS records for pods, though they are less commonly used than service DNS. The format is:

```
<pod-ip-with-dashes>.<namespace>.pod.cluster.local
```

For a pod with IP 10.244.0.5 in the default namespace:

```
10-244-0-5.default.pod.cluster.local
```

Notice that dots in the IP address are replaced with dashes.

Find a pod's IP and construct its DNS name:

```bash
kubectl get pods -n tutorial-coredns -o wide
```

If the web pod has IP 10.244.1.5, its DNS name is `10-244-1-5.tutorial-coredns.pod.cluster.local`.

### Headless Service Pod DNS

When you create a headless service (clusterIP: None), pods backing that service get additional DNS records. Each pod gets a DNS name in the format:

```
<pod-name>.<service-name>.<namespace>.svc.cluster.local
```

This is useful for StatefulSets where each pod needs a stable, unique DNS name.

## DNS Policies

The `spec.dnsPolicy` field in a pod spec controls how the pod resolves DNS names. There are four options:

### ClusterFirst (Default)

```yaml
spec:
  dnsPolicy: ClusterFirst
```

This is the default policy. DNS queries are sent to the cluster DNS service (CoreDNS). If the query is for a name that does not match a cluster domain suffix (like `.cluster.local`), CoreDNS forwards the query to upstream DNS servers (typically inherited from the node).

### Default

```yaml
spec:
  dnsPolicy: Default
```

The pod inherits DNS configuration from the node it runs on. The cluster DNS is not used at all. This means service names will not resolve within the pod. Use this only when you specifically need node-level DNS resolution.

### None

```yaml
spec:
  dnsPolicy: None
```

No DNS configuration is set automatically. You must provide all DNS settings via `spec.dnsConfig`. This is useful when you need complete control over DNS resolution.

### ClusterFirstWithHostNet

```yaml
spec:
  dnsPolicy: ClusterFirstWithHostNet
  hostNetwork: true
```

This policy is required for pods using host networking that still need cluster DNS. When a pod uses `hostNetwork: true`, the default behavior would use the node's DNS, but ClusterFirstWithHostNet ensures cluster DNS is still used.

### Demonstrating DNS Policies

Create pods with different DNS policies:

```yaml
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: dns-clusterfirst
  namespace: tutorial-coredns
spec:
  dnsPolicy: ClusterFirst
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: dns-default
  namespace: tutorial-coredns
spec:
  dnsPolicy: Default
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
```

Compare their /etc/resolv.conf:

```bash
kubectl exec -n tutorial-coredns dns-clusterfirst -- cat /etc/resolv.conf
kubectl exec -n tutorial-coredns dns-default -- cat /etc/resolv.conf
```

The ClusterFirst pod points to the cluster DNS (typically 10.96.0.10), while the Default pod shows the node's DNS configuration.

## DNS Configuration in Pods

Every pod has a `/etc/resolv.conf` file that controls DNS resolution. For pods using ClusterFirst (the default), this file contains:

```
nameserver 10.96.0.10
search tutorial-coredns.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

### nameserver

Points to the CoreDNS service IP (kube-dns service in kube-system). All DNS queries go to this address.

```bash
kubectl get svc -n kube-system kube-dns
```

### search

Lists domains that are appended to short names. When you query `web-service`, the resolver tries:

1. web-service.tutorial-coredns.svc.cluster.local
2. web-service.svc.cluster.local
3. web-service.cluster.local
4. web-service (as-is if no match)

The first domain to resolve wins.

### ndots:5

This option controls when search domains are used. If a name has fewer than 5 dots, it is considered "short" and search domains are appended. If it has 5 or more dots, it is treated as a fully qualified name and queried as-is first.

This means `web-service` (0 dots) triggers search domain expansion, but `web-service.tutorial-coredns.svc.cluster.local` (4 dots) also triggers expansion because 4 < 5. Only names with 5+ dots skip the search domain lookup.

In practice, ndots:5 ensures that cluster names (which have at most 4 dots) always use search domains, while external FQDNs can be optimized by adding a trailing dot.

## DNS Queries from Pods

Two tools are commonly used for DNS debugging: nslookup and dig.

### nslookup

Basic service lookup:

```bash
kubectl exec -n tutorial-coredns dnstools -- nslookup web-service
```

Lookup with explicit server:

```bash
kubectl exec -n tutorial-coredns dnstools -- nslookup web-service 10.96.0.10
```

### dig

For more detailed output, use dig. First, create a pod with dig installed:

```yaml
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: digtools
  namespace: tutorial-coredns
spec:
  containers:
  - name: dig
    image: alpine:3.20
    command: ["sleep", "3600"]
EOF
```

Install dig in the pod:

```bash
kubectl exec -n tutorial-coredns digtools -- apk add --no-cache bind-tools
```

Now use dig for detailed queries:

```bash
kubectl exec -n tutorial-coredns digtools -- dig web-service.tutorial-coredns.svc.cluster.local
```

The output includes query time, response flags, and TTL values that are useful for debugging.

### Interpreting DNS Responses

A successful DNS response shows:

- **ANSWER SECTION**: The IP address(es) for the queried name
- **SERVER**: Which DNS server answered
- **Query time**: How long the query took

A failed response shows `NXDOMAIN` (name does not exist) or `SERVFAIL` (server error).

## Custom DNS Configuration

The `spec.dnsConfig` field lets you customize DNS settings. This is most useful with `dnsPolicy: None` but can also supplement other policies.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: custom-dns
  namespace: tutorial-coredns
spec:
  dnsPolicy: None
  dnsConfig:
    nameservers:
      - 10.96.0.10
    searches:
      - tutorial-coredns.svc.cluster.local
      - svc.cluster.local
    options:
      - name: ndots
        value: "2"
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
```

Apply and verify:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: custom-dns
  namespace: tutorial-coredns
spec:
  dnsPolicy: None
  dnsConfig:
    nameservers:
      - 10.96.0.10
    searches:
      - tutorial-coredns.svc.cluster.local
      - svc.cluster.local
    options:
      - name: ndots
        value: "2"
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl exec -n tutorial-coredns custom-dns -- cat /etc/resolv.conf
```

## Verification

Verify the tutorial setup is working:

```bash
# Service DNS resolves
kubectl exec -n tutorial-coredns dnstools -- nslookup web-service

# Cross-namespace DNS resolves
kubectl exec -n tutorial-coredns dnstools -- nslookup api-service.tutorial-coredns-backend

# CoreDNS is running
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

## Cleanup

Delete the tutorial namespaces and all resources:

```bash
kubectl delete namespace tutorial-coredns
kubectl delete namespace tutorial-coredns-backend
```

## Reference Commands

| Task | Command |
|------|---------|
| List CoreDNS pods | `kubectl get pods -n kube-system -l k8s-app=kube-dns` |
| Get CoreDNS service IP | `kubectl get svc -n kube-system kube-dns` |
| View pod resolv.conf | `kubectl exec -n <ns> <pod> -- cat /etc/resolv.conf` |
| nslookup service | `kubectl exec -n <ns> <pod> -- nslookup <service>` |
| nslookup cross-namespace | `kubectl exec -n <ns> <pod> -- nslookup <service>.<target-ns>` |
| nslookup FQDN | `kubectl exec -n <ns> <pod> -- nslookup <service>.<ns>.svc.cluster.local` |
| dig query | `kubectl exec -n <ns> <pod> -- dig <name>` |
| dig with server | `kubectl exec -n <ns> <pod> -- dig @10.96.0.10 <name>` |
| Create namespace | `kubectl create namespace <name>` |
| Delete namespace | `kubectl delete namespace <name>` |
