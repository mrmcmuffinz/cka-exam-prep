# CoreDNS Tutorial: CoreDNS Configuration

## Introduction

CoreDNS is the DNS server that powers service discovery in Kubernetes clusters. While the previous assignment covered how to use DNS from pods, this tutorial focuses on how CoreDNS itself is deployed and configured. Understanding CoreDNS internals is essential for cluster administrators who need to customize DNS behavior, troubleshoot resolution issues, or integrate cluster DNS with enterprise DNS infrastructure.

CoreDNS runs as a Deployment in the kube-system namespace and is configured through a ConfigMap. The configuration file, called the Corefile, uses a plugin-based architecture where each plugin handles a specific DNS function. By modifying the Corefile, you can add custom DNS records, configure upstream DNS servers, enable logging, and implement stub domains for enterprise integration.

This tutorial walks through the CoreDNS Deployment, examines the ConfigMap and Corefile structure, explains the key plugins, and demonstrates common configuration customizations.

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

Create the tutorial namespace and a test pod:

```bash
kubectl create namespace tutorial-coredns

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: dnstest
  namespace: tutorial-coredns
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/dnstest -n tutorial-coredns --timeout=60s
```

## CoreDNS Deployment in kube-system

CoreDNS runs as a Deployment in the kube-system namespace. List the CoreDNS pods:

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

Output shows two CoreDNS pods (for high availability):

```
NAME                       READY   STATUS    RESTARTS   AGE
coredns-5d78c9869d-abc12   1/1     Running   0          10m
coredns-5d78c9869d-def34   1/1     Running   0          10m
```

View the Deployment:

```bash
kubectl get deployment coredns -n kube-system
kubectl describe deployment coredns -n kube-system
```

Key characteristics of the CoreDNS Deployment:

- **Replicas:** Typically 2 for high availability
- **Pod anti-affinity:** Ensures pods run on different nodes
- **Resource requests/limits:** Configured for DNS workload
- **Liveness and readiness probes:** Health monitoring via /health and /ready endpoints

The CoreDNS Service provides a stable ClusterIP for DNS queries:

```bash
kubectl get svc kube-dns -n kube-system
```

```
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE
kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP   10m
```

This IP (typically 10.96.0.10) is what pods use as their nameserver.

## CoreDNS ConfigMap and Corefile

CoreDNS configuration is stored in a ConfigMap named `coredns` in the kube-system namespace:

```bash
kubectl get configmap coredns -n kube-system -o yaml
```

The ConfigMap contains the Corefile:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
```

### Corefile Structure

The Corefile consists of server blocks. Each block starts with a zone declaration and port, followed by plugins in curly braces:

```
<zone>:<port> {
    <plugin1>
    <plugin2> <options>
    ...
}
```

The `.` zone matches all domains (the root zone). Port 53 is the standard DNS port. Plugins inside the block are processed in order for each query.

## CoreDNS Plugins

Each plugin handles a specific aspect of DNS processing. Here are the key plugins in the default Corefile:

### errors

```
errors
```

Logs errors to standard output. Essential for troubleshooting. No configuration needed.

### health

```
health {
   lameduck 5s
}
```

Provides a health check endpoint at :8080/health. The lameduck period allows graceful shutdown by continuing to serve requests briefly before stopping.

### ready

```
ready
```

Provides a readiness check endpoint at :8181/ready. Used by Kubernetes readiness probes to determine when CoreDNS is ready to serve queries.

### kubernetes

```
kubernetes cluster.local in-addr.arpa ip6.arpa {
   pods insecure
   fallthrough in-addr.arpa ip6.arpa
   ttl 30
}
```

This is the most important plugin for Kubernetes DNS. It enables CoreDNS to resolve service and pod names within the cluster.

- **cluster.local:** The cluster domain
- **in-addr.arpa, ip6.arpa:** Reverse DNS zones
- **pods insecure:** Allows pod A records (insecure means no pod verification)
- **fallthrough:** Pass unresolved queries to next plugin for these zones
- **ttl:** Time-to-live for responses (30 seconds)

### prometheus

```
prometheus :9153
```

Exposes Prometheus metrics on port 9153. Useful for monitoring CoreDNS performance.

### forward

```
forward . /etc/resolv.conf {
   max_concurrent 1000
}
```

Forwards queries for external domains to upstream DNS servers. The `/etc/resolv.conf` file inside the CoreDNS pod contains the node's DNS servers. You can also specify explicit IPs:

```
forward . 8.8.8.8 8.8.4.4
```

### cache

```
cache 30
```

Caches responses for 30 seconds. Reduces load on upstream servers and improves response time for repeated queries.

### loop

```
loop
```

Detects simple forwarding loops and halts CoreDNS if detected. This prevents infinite loops that could occur with misconfigured forwarding.

### reload

```
reload
```

Enables automatic reload of the Corefile when the ConfigMap changes. CoreDNS checks for changes every 30 seconds by default. No restart required.

### loadbalance

```
loadbalance
```

Randomizes the order of A records in responses. Provides simple round-robin load balancing for services with multiple endpoints.

## Viewing CoreDNS Logs

View CoreDNS logs to see errors and, if logging is enabled, DNS queries:

```bash
kubectl logs -n kube-system -l k8s-app=kube-dns
```

By default, only errors are logged. To see all queries, add the `log` plugin (demonstrated later).

## Configuration Customization

### Adding Query Logging

To log all DNS queries, add the `log` plugin:

```bash
kubectl edit configmap coredns -n kube-system
```

Add `log` after `errors`:

```
.:53 {
    errors
    log
    health {
       lameduck 5s
    }
    ...
}
```

After saving, CoreDNS automatically reloads (may take up to 30 seconds). Test and view logs:

```bash
kubectl exec -n tutorial-coredns dnstest -- nslookup kubernetes
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=20
```

You should see log entries for the DNS query.

### Adding Custom DNS Records

You can add custom DNS records using the `hosts` plugin. This is useful for internal services, legacy systems, or testing.

First, back up the current ConfigMap:

```bash
kubectl get configmap coredns -n kube-system -o yaml > coredns-backup.yaml
```

Edit the ConfigMap to add custom records:

```bash
kubectl edit configmap coredns -n kube-system
```

Add a hosts block before the forward plugin:

```
.:53 {
    errors
    health {
       lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    hosts {
       192.168.1.100 legacy-server.internal
       192.168.1.101 old-database.internal
       fallthrough
    }
    prometheus :9153
    forward . /etc/resolv.conf {
       max_concurrent 1000
    }
    cache 30
    loop
    reload
    loadbalance
}
```

The `fallthrough` directive passes unmatched queries to the next plugin. Wait for reload and test:

```bash
kubectl exec -n tutorial-coredns dnstest -- nslookup legacy-server.internal
```

### Configuring Stub Domains

Stub domains route queries for specific domains to designated DNS servers. This is common in enterprise environments where certain domains (like `corp.example.com`) should resolve through internal DNS servers.

Add a separate server block for the stub domain:

```
corp.example.com:53 {
    errors
    cache 30
    forward . 10.0.0.53 10.0.0.54
}

.:53 {
    errors
    health {
       lameduck 5s
    }
    ...
}
```

Queries for `*.corp.example.com` go to the internal DNS servers (10.0.0.53, 10.0.0.54), while other queries use the default upstream servers.

### Modifying Cache Settings

The cache plugin supports additional options:

```
cache 60 {
    success 9984 30
    denial 9984 5
}
```

- **60:** Maximum TTL in seconds
- **success 9984 30:** Cache up to 9984 successful responses for 30 seconds
- **denial 9984 5:** Cache up to 9984 NXDOMAIN responses for 5 seconds

Shorter denial cache helps when services are being created. Longer success cache improves performance for stable services.

### Changing Upstream DNS Servers

To use specific upstream DNS servers instead of the node's resolv.conf:

```
forward . 8.8.8.8 8.8.4.4 {
   max_concurrent 1000
}
```

Or use DNS over TLS for privacy:

```
forward . tls://9.9.9.9 tls://149.112.112.112 {
   tls_servername dns.quad9.net
   health_check 5s
}
```

## Changes Take Effect Automatically

The `reload` plugin monitors the ConfigMap for changes and reloads the configuration automatically. This typically happens within 30 seconds of saving the ConfigMap.

Watch CoreDNS logs to see the reload:

```bash
kubectl logs -n kube-system -l k8s-app=kube-dns -f
```

When the ConfigMap changes, you will see:

```
[INFO] Reloading
[INFO] plugin/reload: Running configuration SHA512 = <hash>
[INFO] Reloading complete
```

## Verification

Verify the tutorial setup is working:

```bash
# CoreDNS pods are running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# ConfigMap exists
kubectl get configmap coredns -n kube-system

# DNS queries work
kubectl exec -n tutorial-coredns dnstest -- nslookup kubernetes.default
```

## Cleanup

Restore the original CoreDNS ConfigMap if you made changes:

```bash
kubectl apply -f coredns-backup.yaml
```

Delete the tutorial namespace:

```bash
kubectl delete namespace tutorial-coredns
```

## Reference Commands

| Task | Command |
|------|---------|
| List CoreDNS pods | `kubectl get pods -n kube-system -l k8s-app=kube-dns` |
| View CoreDNS Deployment | `kubectl describe deployment coredns -n kube-system` |
| Get CoreDNS ConfigMap | `kubectl get configmap coredns -n kube-system -o yaml` |
| Edit CoreDNS ConfigMap | `kubectl edit configmap coredns -n kube-system` |
| View CoreDNS logs | `kubectl logs -n kube-system -l k8s-app=kube-dns` |
| Follow CoreDNS logs | `kubectl logs -n kube-system -l k8s-app=kube-dns -f` |
| Backup ConfigMap | `kubectl get configmap coredns -n kube-system -o yaml > backup.yaml` |
| Restore ConfigMap | `kubectl apply -f backup.yaml` |
| Check CoreDNS endpoints | `kubectl get endpoints kube-dns -n kube-system` |
| Describe CoreDNS service | `kubectl describe svc kube-dns -n kube-system` |
