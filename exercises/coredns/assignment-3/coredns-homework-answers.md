# CoreDNS Homework Answers: DNS Troubleshooting

Complete solutions for all 15 exercises with explanations.

---

## Exercise 1.1 Solution

**Task:** Test DNS resolution from a pod for both short name and FQDN.

**Solution:**

```bash
# Short name lookup
kubectl exec -n ex-1-1 tester -- nslookup backend-svc

# FQDN lookup
kubectl exec -n ex-1-1 tester -- nslookup backend-svc.ex-1-1.svc.cluster.local
```

**Expected Output:**

```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      backend-svc
Address 1: 10.96.X.X backend-svc.ex-1-1.svc.cluster.local
```

**Explanation:** Both lookups should succeed. The short name works because the pod's search domains include `ex-1-1.svc.cluster.local`. The FQDN works because it explicitly specifies the complete DNS name. Verifying both confirms that DNS resolution and search domain configuration are correct.

---

## Exercise 1.2 Solution

**Task:** Compare resolv.conf between pods with different DNS policies.

**Solution:**

```bash
kubectl exec -n ex-1-2 pod-clusterfirst -- cat /etc/resolv.conf
kubectl exec -n ex-1-2 pod-default -- cat /etc/resolv.conf
```

**ClusterFirst output:**

```
nameserver 10.96.0.10
search ex-1-2.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

**Default output:**

```
nameserver 192.168.X.X
search localdomain
```

**Key differences:**

| Setting | ClusterFirst | Default |
|---------|-------------|---------|
| nameserver | kube-dns IP (10.96.0.10) | Node's DNS |
| search | Cluster domains | Node's domains |
| Can resolve services | Yes | No |

**Explanation:** ClusterFirst uses the cluster DNS server and includes search domains for the cluster. Default inherits the node's DNS configuration, which knows nothing about Kubernetes services. Only pods with ClusterFirst (or ClusterFirstWithHostNet) can resolve service names.

---

## Exercise 1.3 Solution

**Task:** Verify CoreDNS service availability.

**Solution:**

```bash
# Check service
kubectl get svc kube-dns -n kube-system -o wide

# Check endpoints
kubectl get endpoints kube-dns -n kube-system

# Check pods
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
```

**Expected Output:**

Service has ClusterIP (usually 10.96.0.10), endpoints list CoreDNS pod IPs, and pods are Running with 1/1 Ready.

**Explanation:** The kube-dns service provides a stable IP for DNS queries. The endpoints point to actual CoreDNS pods. If endpoints are empty, either pods are not running or they are not ready. This verification confirms the entire DNS infrastructure is functioning.

---

## Exercise 2.1 Solution

**Task:** Check CoreDNS pod status and readiness probe configuration.

**Solution:**

```bash
# Check pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check readiness probe
kubectl get deployment coredns -n kube-system -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}'
```

**Readiness Probe Configuration:**

```json
{
  "failureThreshold": 3,
  "httpGet": {
    "path": "/ready",
    "port": 8181,
    "scheme": "HTTP"
  },
  "periodSeconds": 10,
  "successThreshold": 1,
  "timeoutSeconds": 1
}
```

**Explanation:** CoreDNS exposes a /ready endpoint on port 8181. Kubernetes checks this endpoint every 10 seconds. If the endpoint fails 3 times, the pod is marked not ready and removed from the kube-dns endpoints. This prevents traffic from being sent to unhealthy CoreDNS pods.

---

## Exercise 2.2 Solution

**Task:** Generate DNS queries and view CoreDNS logs.

**Solution:**

```bash
# Generate queries
kubectl exec -n ex-2-2 query-generator -- nslookup kubernetes.default
kubectl exec -n ex-2-2 query-generator -- nslookup nonexistent.invalid

# View logs
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=30
```

**Observation:** By default, CoreDNS only logs errors. You will see the NXDOMAIN response for nonexistent.invalid but not the successful kubernetes.default query.

**Explanation:** The default Corefile includes the `errors` plugin but not the `log` plugin. This minimizes log volume in production clusters. To see all queries, add the `log` plugin to the Corefile.

---

## Exercise 2.3 Solution

**Task:** Verify CoreDNS endpoints match pod IPs.

**Solution:**

```bash
# Get endpoint IPs
kubectl get endpoints kube-dns -n kube-system -o jsonpath='{.subsets[0].addresses[*].ip}'

# Get pod IPs
kubectl get pods -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[*].status.podIP}'
```

**Expected:** Both commands return the same set of IP addresses.

**Explanation:** The kube-dns service endpoints should exactly match the IPs of running, ready CoreDNS pods. If endpoints are missing or different from pod IPs, there may be a labeling issue or the pods may not be ready.

---

## Exercise 3.1 Solution

**Task:** Diagnose why a pod cannot resolve any DNS names.

**Diagnosis:**

```bash
kubectl get pod broken-client -n ex-3-1 -o jsonpath='{.spec.dnsPolicy}'
# Output: None

kubectl exec -n ex-3-1 broken-client -- cat /etc/resolv.conf
# Output: empty or minimal
```

**Root Cause:** The pod has `dnsPolicy: None` but no `dnsConfig` is provided. With dnsPolicy: None, the pod's /etc/resolv.conf is empty or contains only what dnsConfig specifies.

**Fix:** Either change dnsPolicy to ClusterFirst, or provide a complete dnsConfig:

```yaml
spec:
  dnsPolicy: None
  dnsConfig:
    nameservers:
      - "10.96.0.10"
    searches:
      - ex-3-1.svc.cluster.local
      - svc.cluster.local
      - cluster.local
```

---

## Exercise 3.2 Solution

**Task:** Diagnose why a pod's DNS lookups timeout.

**Diagnosis:**

```bash
kubectl get networkpolicy -n ex-3-2
kubectl describe networkpolicy deny-all-egress -n ex-3-2
```

**Output:**

```
Name:         deny-all-egress
PodSelector:  <none> (Applies to all pods in namespace)
PolicyTypes:  Egress
Egress Rules:
  (none)
```

**Root Cause:** The NetworkPolicy applies default deny for all egress traffic. Since there are no egress rules, pods cannot send any outbound traffic, including DNS queries to kube-dns in kube-system.

**Fix:** Add an egress rule allowing DNS:

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

---

## Exercise 3.3 Solution

**Task:** Diagnose why a service lookup returns NXDOMAIN when the service exists.

**Diagnosis:**

```bash
# The frontend pod is in ex-3-3-frontend namespace
# The service is in ex-3-3-backend namespace

kubectl exec -n ex-3-3-frontend frontend -- nslookup api-service
# Fails - tries api-service.ex-3-3-frontend.svc.cluster.local

kubectl exec -n ex-3-3-frontend frontend -- nslookup api-service.ex-3-3-backend
# Works
```

**Root Cause:** The pod's search domains only include its own namespace. When looking up `api-service` (short name), it tries `api-service.ex-3-3-frontend.svc.cluster.local`, which does not exist.

**Fix:** Use the namespace-qualified name `api-service.ex-3-3-backend` or the FQDN.

---

## Exercise 4.1 Solution

**Task:** Identify what is missing from the Network Policy that blocks DNS.

**Diagnosis:**

```bash
kubectl describe networkpolicy client-egress -n ex-4-1
```

**Output:**

```
Egress Rules:
  To Port: 80/TCP
  To:
    PodSelector: app=server
```

**Root Cause:** The egress rule only allows traffic to pods with `app=server` on port 80. DNS queries go to kube-dns in kube-system namespace on UDP port 53, which is not allowed.

**Fix:** Add a rule allowing DNS egress:

```yaml
egress:
- to:
  - podSelector:
      matchLabels:
        app: server
  ports:
  - port: 80
- to:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: kube-system
    podSelector:
      matchLabels:
        k8s-app: kube-dns
  ports:
  - protocol: UDP
    port: 53
```

---

## Exercise 4.2 Solution

**Task:** Understand DNS caching behavior when creating new services.

**Observation:**

1. First lookup of `new-service` fails with NXDOMAIN
2. Service is created
3. Immediate second lookup may still fail
4. After waiting 30+ seconds, lookup succeeds

**Explanation:** CoreDNS caches NXDOMAIN responses (negative caching). The default cache TTL is 30 seconds. When you first query a non-existent service, the NXDOMAIN is cached. Even after creating the service, the cache may still return the old NXDOMAIN response until the cache expires.

**Workarounds:**

1. Wait for cache TTL (default 30 seconds)
2. Query with FQDN and trailing dot to bypass some caching
3. Reduce negative cache TTL in CoreDNS config:
   ```
   cache 30 {
       denial 9984 5
   }
   ```

---

## Exercise 4.3 Solution

**Task:** Test different DNS name formats for cross-namespace resolution.

**Results:**

| Name Format | Works | Why |
|-------------|-------|-----|
| `mysql-service` | No | Searches in ex-4-3-app namespace only |
| `mysql-service.ex-4-3-db` | Yes | Namespace qualifier specifies correct namespace |
| `mysql-service.ex-4-3-db.svc.cluster.local` | Yes | Full FQDN is explicit |

**Explanation:** Short names rely on search domains, which only include the pod's own namespace. For cross-namespace access, you must include the target namespace in the DNS name.

---

## Exercise 5.1 Solution

**Task:** Diagnose why one pod fails while another succeeds.

**Diagnosis:**

```bash
# Compare DNS policies
kubectl get pod problem-pod -n ex-5-1 -o jsonpath='{.spec.dnsPolicy}'
# Output: Default

kubectl get pod normal-pod -n ex-5-1 -o jsonpath='{.spec.dnsPolicy}'
# Output: (empty, meaning ClusterFirst is used)

# Compare resolv.conf
kubectl exec -n ex-5-1 problem-pod -- cat /etc/resolv.conf
# Shows node DNS

kubectl exec -n ex-5-1 normal-pod -- cat /etc/resolv.conf
# Shows cluster DNS (10.96.0.10)
```

**Root Cause:** problem-pod has `dnsPolicy: Default`, which uses the node's DNS configuration instead of cluster DNS. Node DNS does not know about Kubernetes services.

**Fix:** Remove the dnsPolicy from problem-pod (to use ClusterFirst default) or explicitly set `dnsPolicy: ClusterFirst`.

---

## Exercise 5.2 Solution

**Task:** Investigate intermittent DNS failures and verify high availability.

**Solution:**

```bash
# Run multiple queries
for i in 1 2 3 4 5; do
  kubectl exec -n ex-5-2 tester -- nslookup target-svc 2>/dev/null | grep -q "Address" && echo "Query $i: OK" || echo "Query $i: FAILED"
done

# Check CoreDNS replicas
kubectl get deployment coredns -n kube-system

# Check pod distribution
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
```

**Expected:** All queries succeed. CoreDNS should have 2 replicas on different nodes.

**Explanation:** Intermittent DNS failures can indicate:

1. **Single CoreDNS pod:** If only one pod exists and it restarts, DNS fails briefly
2. **Both pods on same node:** If that node fails, DNS fails
3. **Resource exhaustion:** CoreDNS pods OOMKilled under load
4. **Network issues:** Intermittent network problems between pods and CoreDNS

For high availability, CoreDNS should have 2+ replicas distributed across nodes via pod anti-affinity.

---

## Exercise 5.3 Solution

**Task:** Document a complete DNS troubleshooting runbook.

**Runbook:**

```bash
# Step 1: Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns
# Expected: 2 pods, Running, 1/1 Ready

# Step 2: Check kube-dns service and endpoints
kubectl get svc kube-dns -n kube-system
# Expected: ClusterIP exists (usually 10.96.0.10)

kubectl get endpoints kube-dns -n kube-system
# Expected: Endpoints list CoreDNS pod IPs

# Step 3: Check pod's DNS configuration
kubectl exec -n <namespace> <pod> -- cat /etc/resolv.conf
# Expected: nameserver 10.96.0.10, cluster search domains

# Step 4: Test DNS from the pod
kubectl exec -n <namespace> <pod> -- nslookup kubernetes.default
# Expected: Resolves to kubernetes service IP

# Step 5: Check for Network Policies
kubectl get networkpolicy -n <namespace>
# If present, verify egress to kube-system on UDP 53 is allowed

# Step 6: View CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50
# Look for errors or SERVFAIL responses
```

**Decision Tree:**

1. If Step 1 fails: Fix CoreDNS pods (check ConfigMap, resources, node scheduling)
2. If Step 2 fails: CoreDNS pods not ready, check readiness probes
3. If Step 3 shows wrong nameserver: Check pod dnsPolicy
4. If Step 4 fails but Step 1-3 OK: Check Network Policies (Step 5)
5. If Step 5 shows deny policy: Add DNS egress exception
6. If all steps pass: Check for application-level caching or service name typos

---

## Common Mistakes

### Not Checking if CoreDNS is Running First

**Mistake:** Spending time debugging pod DNS config when CoreDNS is down.

**Fix:** Always start with `kubectl get pods -n kube-system -l k8s-app=kube-dns`. If CoreDNS is not running, fix that first.

### Forgetting Network Policy Affects DNS

**Mistake:** Creating a default deny egress policy without DNS exception.

**Fix:** Every default deny egress policy needs:

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

### Testing from Wrong Namespace

**Mistake:** Testing DNS from a pod in a different namespace than the affected application.

**Fix:** Test from a pod in the same namespace as the affected workload to ensure you are testing the same search domains and Network Policies.

### Cache Masking the Real Issue

**Mistake:** Assuming DNS is fixed after creating a service, but cached NXDOMAIN still causes failures.

**Fix:** Wait for cache TTL (default 30 seconds) or test with FQDN with trailing dot.

### Not Checking CoreDNS Logs

**Mistake:** Ignoring CoreDNS logs when DNS fails.

**Fix:** Always check `kubectl logs -n kube-system -l k8s-app=kube-dns` for errors, SERVFAIL, or timeout messages.

---

## DNS Troubleshooting Flowchart

```
DNS Query Fails
       |
       v
[1] kubectl get pods -n kube-system -l k8s-app=kube-dns
       |
   Pods Running?
       |
  +----+----+
  |         |
 No        Yes
  |         |
  v         v
Fix CoreDNS [2] Check pod resolv.conf
 pods            |
                 v
            nameserver = kube-dns IP?
                 |
            +----+----+
            |         |
           No        Yes
            |         |
            v         v
       Fix dnsPolicy  [3] Test from another pod
                           |
                      Works in other pod?
                           |
                      +----+----+
                      |         |
                     No        Yes
                      |         |
                      v         v
                 Check CoreDNS  Issue is pod-specific
                 config/logs    |
                                v
                           Check NetworkPolicy,
                           dnsPolicy, namespace
```

---

## Verification Commands Cheat Sheet

| Check | Command |
|-------|---------|
| CoreDNS pods | `kubectl get pods -n kube-system -l k8s-app=kube-dns` |
| CoreDNS logs | `kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50` |
| kube-dns service | `kubectl get svc kube-dns -n kube-system` |
| kube-dns endpoints | `kubectl get endpoints kube-dns -n kube-system` |
| Pod resolv.conf | `kubectl exec -n <ns> <pod> -- cat /etc/resolv.conf` |
| Pod dnsPolicy | `kubectl get pod <name> -n <ns> -o jsonpath='{.spec.dnsPolicy}'` |
| Test DNS | `kubectl exec -n <ns> <pod> -- nslookup <service>` |
| Network Policies | `kubectl get networkpolicy -n <namespace>` |
| Quick test pod | `kubectl run test --rm -it --image=busybox:1.36 -- nslookup <name>` |
| CoreDNS ConfigMap | `kubectl get cm coredns -n kube-system -o yaml` |
