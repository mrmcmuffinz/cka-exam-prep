# CoreDNS Tutorial: DNS Troubleshooting

## Introduction

When applications in Kubernetes cannot communicate, DNS is often the first suspect. Service discovery depends entirely on DNS working correctly, and failures can manifest in many ways: timeouts, "unknown host" errors, intermittent connectivity, or seemingly random failures. Effective DNS troubleshooting requires a systematic approach that examines each component in the resolution chain.

This tutorial builds on the DNS fundamentals and CoreDNS configuration knowledge from the previous assignments. It presents a structured methodology for diagnosing DNS issues, covers common failure scenarios, and demonstrates the diagnostic commands you will use repeatedly in production environments.

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

Create the tutorial namespace and test resources:

```bash
kubectl create namespace tutorial-coredns

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: webserver
  namespace: tutorial-coredns
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
  namespace: tutorial-coredns
spec:
  selector:
    app: web
  ports:
  - port: 80
---
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

kubectl wait --for=condition=Ready pod/dnstools -n tutorial-coredns --timeout=60s
kubectl wait --for=condition=Ready pod/webserver -n tutorial-coredns --timeout=60s
```

## DNS Troubleshooting Methodology

When DNS fails, follow this systematic approach:

1. **Verify CoreDNS is running** - The most common cause of cluster-wide DNS failure
2. **Test DNS from the affected pod** - Confirm the symptom
3. **Check the pod's DNS configuration** - Verify resolv.conf and dnsPolicy
4. **Test from a known-good pod** - Isolate whether the issue is pod-specific
5. **Examine CoreDNS logs** - Look for errors or hints
6. **Check Network Policies** - DNS requires egress to kube-system on port 53

Let us walk through each step.

## Step 1: Verify CoreDNS is Running

Always start here. If CoreDNS is not running, nothing else matters.

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

Healthy output:

```
NAME                       READY   STATUS    RESTARTS   AGE
coredns-5d78c9869d-abc12   1/1     Running   0          1h
coredns-5d78c9869d-def34   1/1     Running   0          1h
```

Warning signs:

- **STATUS not Running**: CoreDNS crashed or failed to start
- **READY 0/1**: CoreDNS container not ready (check readiness probe)
- **RESTARTS > 0**: CoreDNS is crashlooping (check logs)
- **No pods**: CoreDNS Deployment is missing or scaled to zero

Check the kube-dns Service:

```bash
kubectl get svc kube-dns -n kube-system
kubectl get endpoints kube-dns -n kube-system
```

The endpoints should list the CoreDNS pod IPs. If endpoints are empty, either no pods are running or the pods are not ready.

## Step 2: Test DNS from the Affected Pod

Confirm the symptom from the pod experiencing the issue:

```bash
kubectl exec -n tutorial-coredns dnstools -- nslookup web-svc
```

Possible outcomes:

**Success:**
```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      web-svc
Address 1: 10.96.X.X web-svc.tutorial-coredns.svc.cluster.local
```

**Failure - timeout:**
```
;; connection timed out; no servers could be reached
```
This usually means CoreDNS is unreachable (not running, Network Policy blocking, or networking issue).

**Failure - NXDOMAIN:**
```
** server can't find web-svc: NXDOMAIN
```
The DNS server responded but the name does not exist. Check service name spelling and namespace.

**Failure - SERVFAIL:**
```
** server can't find web-svc: SERVFAIL
```
The DNS server encountered an error. Check CoreDNS logs.

## Step 3: Check the Pod's DNS Configuration

Examine the pod's /etc/resolv.conf:

```bash
kubectl exec -n tutorial-coredns dnstools -- cat /etc/resolv.conf
```

Expected output for ClusterFirst DNS policy:

```
nameserver 10.96.0.10
search tutorial-coredns.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

Check the pod's dnsPolicy:

```bash
kubectl get pod dnstools -n tutorial-coredns -o jsonpath='{.spec.dnsPolicy}'
```

Common misconfigurations:

- **dnsPolicy: Default**: Pod uses node DNS, cannot resolve cluster services
- **dnsPolicy: None without dnsConfig**: Pod has no DNS configuration at all
- **Wrong nameserver IP**: Should be the kube-dns ClusterIP
- **Missing search domains**: Short names will not resolve

## Step 4: Test from a Known-Good Pod

Create a test pod to isolate whether the issue is pod-specific:

```bash
kubectl run dns-test --image=busybox:1.36 --restart=Never --rm -it -- nslookup web-svc.tutorial-coredns
```

If this works but the original pod fails, the issue is specific to that pod (DNS policy, Network Policy, or namespace).

## Step 5: Examine CoreDNS Logs

View recent logs:

```bash
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
```

Look for:

- **Error messages**: Parse errors, plugin failures
- **SERVFAIL responses**: Internal errors
- **Timeout errors**: Upstream DNS unreachable
- **Loop detection**: Forwarding loops

Follow logs in real-time while testing:

```bash
kubectl logs -n kube-system -l k8s-app=kube-dns -f &
kubectl exec -n tutorial-coredns dnstools -- nslookup web-svc
```

## Step 6: Check Network Policies

Network Policies can block DNS traffic. DNS uses UDP port 53 to the kube-dns service in kube-system.

List Network Policies affecting the namespace:

```bash
kubectl get networkpolicy -n tutorial-coredns
```

If a default deny policy exists, you need an egress rule allowing DNS:

```yaml
egress:
- to:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: kube-system
  ports:
  - protocol: UDP
    port: 53
```

## Common DNS Failure Scenarios

### Scenario 1: CoreDNS Pods Not Running

**Symptoms:** All DNS queries timeout. No pods can resolve any names.

**Diagnosis:**

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
# No pods or pods in CrashLoopBackOff

kubectl describe deployment coredns -n kube-system
# Check for events indicating why pods are not running
```

**Common causes:**

- ConfigMap syntax error crashed CoreDNS
- Resource exhaustion (OOMKilled)
- Node scheduling issues

**Resolution:**

```bash
# Check ConfigMap for errors
kubectl get configmap coredns -n kube-system -o yaml

# View pod events
kubectl describe pod -n kube-system -l k8s-app=kube-dns
```

### Scenario 2: Wrong DNS Policy

**Symptoms:** One pod cannot resolve cluster services, but other pods work fine.

**Diagnosis:**

```bash
kubectl get pod <problem-pod> -o jsonpath='{.spec.dnsPolicy}'
# Shows "Default" instead of "ClusterFirst"

kubectl exec <problem-pod> -- cat /etc/resolv.conf
# Shows node DNS servers, not kube-dns
```

**Resolution:** The pod spec needs `dnsPolicy: ClusterFirst` (or remove dnsPolicy to use the default).

### Scenario 3: Host Network Pod Without ClusterFirstWithHostNet

**Symptoms:** A pod with `hostNetwork: true` cannot resolve cluster services.

**Diagnosis:**

```bash
kubectl get pod <problem-pod> -o jsonpath='{.spec.hostNetwork}'
# Shows "true"

kubectl get pod <problem-pod> -o jsonpath='{.spec.dnsPolicy}'
# Shows "ClusterFirst" but should be "ClusterFirstWithHostNet"
```

**Resolution:** Use `dnsPolicy: ClusterFirstWithHostNet` for pods with host networking.

### Scenario 4: Network Policy Blocking DNS

**Symptoms:** Pod DNS times out. CoreDNS is running. Other pods work.

**Diagnosis:**

```bash
kubectl get networkpolicy -n <pod-namespace>
# Shows a default deny policy

kubectl describe networkpolicy <policy-name> -n <pod-namespace>
# No egress rule for UDP 53 to kube-system
```

**Resolution:** Add an egress rule allowing DNS traffic to kube-system.

### Scenario 5: Service Does Not Exist

**Symptoms:** NXDOMAIN for a specific service name. Other services resolve.

**Diagnosis:**

```bash
kubectl get svc <service-name> -n <namespace>
# No resources found

kubectl get svc -n <namespace>
# Service has different name or is in different namespace
```

**Resolution:** Create the service or correct the service name.

### Scenario 6: Cross-Namespace DNS Without Namespace Qualifier

**Symptoms:** Short service name fails, but FQDN works.

**Diagnosis:**

```bash
kubectl exec <pod> -- nslookup myservice
# Fails

kubectl exec <pod> -- nslookup myservice.other-namespace
# Works
```

**Resolution:** Use namespace-qualified name or FQDN for cross-namespace services.

## DNS Caching Issues

Kubernetes DNS includes caching at multiple levels:

1. **CoreDNS cache**: Configured in Corefile (default 30 seconds)
2. **Application-level caching**: Some apps cache DNS (Java, glibc)
3. **Negative caching**: NXDOMAIN responses are also cached

### Diagnosing Cache Issues

If a service was recently created but DNS fails:

```bash
# Check if service exists and has endpoints
kubectl get svc,endpoints <service-name> -n <namespace>

# Service exists but DNS fails - might be negative cache
# Wait for cache TTL (default 30 seconds) or...

# Force cache refresh by querying FQDN with trailing dot
kubectl exec <pod> -- nslookup <service>.<namespace>.svc.cluster.local.
```

### Cache TTL in CoreDNS

View the current cache setting:

```bash
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' | grep cache
```

Reduce negative cache TTL for faster recovery when creating services:

```
cache 30 {
    denial 9984 5
}
```

## Verification

Test that the tutorial setup works:

```bash
# CoreDNS running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Service resolution works
kubectl exec -n tutorial-coredns dnstools -- nslookup web-svc

# Cross-namespace resolution
kubectl exec -n tutorial-coredns dnstools -- nslookup kubernetes.default
```

## Cleanup

Delete the tutorial namespace:

```bash
kubectl delete namespace tutorial-coredns
```

## DNS Troubleshooting Flowchart

```
DNS Query Fails
       |
       v
Is CoreDNS Running?
       |
  +----+----+
  |         |
 No        Yes
  |         |
  v         v
Fix CoreDNS  Check pod's resolv.conf
  pods       |
             v
        Is nameserver kube-dns IP?
             |
        +----+----+
        |         |
       No        Yes
        |         |
        v         v
    Fix dnsPolicy  Does query work from
                   another pod?
                        |
                   +----+----+
                   |         |
                  No        Yes
                   |         |
                   v         v
             Check CoreDNS  Issue is specific
             logs/config    to this pod
                            |
                            v
                      Check Network
                      Policies, dnsPolicy
```

## Reference Commands

| Task | Command |
|------|---------|
| Check CoreDNS pods | `kubectl get pods -n kube-system -l k8s-app=kube-dns` |
| View CoreDNS logs | `kubectl logs -n kube-system -l k8s-app=kube-dns` |
| Check kube-dns endpoints | `kubectl get endpoints kube-dns -n kube-system` |
| Test DNS from pod | `kubectl exec -n <ns> <pod> -- nslookup <name>` |
| View pod resolv.conf | `kubectl exec -n <ns> <pod> -- cat /etc/resolv.conf` |
| Check pod dnsPolicy | `kubectl get pod <name> -o jsonpath='{.spec.dnsPolicy}'` |
| Check pod hostNetwork | `kubectl get pod <name> -o jsonpath='{.spec.hostNetwork}'` |
| List Network Policies | `kubectl get networkpolicy -n <namespace>` |
| Quick DNS test | `kubectl run test --rm -it --image=busybox:1.36 -- nslookup <name>` |
| Check service exists | `kubectl get svc <name> -n <namespace>` |
| Check service endpoints | `kubectl get endpoints <name> -n <namespace>` |
