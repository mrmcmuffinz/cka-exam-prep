# CoreDNS Homework Answers: DNS Fundamentals

Complete solutions for all 15 exercises with explanations.

---

## Exercise 1.1 Solution

**Task:** Look up a service using its short name from within the same namespace.

**Solution:**

```bash
kubectl exec -n ex-1-1 client -- nslookup backend-svc
```

**Expected Output:**

```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      backend-svc
Address 1: 10.96.X.X backend-svc.ex-1-1.svc.cluster.local
```

**Explanation:** The short name `backend-svc` works because the pod's /etc/resolv.conf contains search domains that include the pod's namespace. When you query `backend-svc`, the resolver appends search domains and tries `backend-svc.ex-1-1.svc.cluster.local` first, which resolves to the service IP.

---

## Exercise 1.2 Solution

**Task:** Look up a service using its fully qualified domain name.

**Solution:**

```bash
kubectl exec -n ex-1-2 lookup -- nslookup database-svc.ex-1-2.svc.cluster.local
```

**Expected Output:**

```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      database-svc.ex-1-2.svc.cluster.local
Address 1: 10.96.X.X database-svc.ex-1-2.svc.cluster.local
```

**Explanation:** The FQDN includes all components: service name, namespace, svc literal, and cluster domain. Using the FQDN is explicit and works regardless of search domain configuration. It is especially important when automating or scripting to avoid ambiguity.

---

## Exercise 1.3 Solution

**Task:** Look up a service in a different namespace.

**Solution:**

```bash
kubectl exec -n ex-1-3-frontend frontend -- nslookup api-service.ex-1-3-backend
```

**Expected Output:**

```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      api-service.ex-1-3-backend
Address 1: 10.96.X.X api-service.ex-1-3-backend.svc.cluster.local
```

**Explanation:** When accessing services in other namespaces, you must include the namespace in the DNS name. The short name `api-service` alone would try `api-service.ex-1-3-frontend.svc.cluster.local` first (the pod's own namespace), which does not exist. Including the namespace (`api-service.ex-1-3-backend`) allows the search domain mechanism to find the correct service.

---

## Exercise 2.1 Solution

**Task:** Discover and query a pod's DNS record.

**Solution:**

```bash
# Get the pod IP
kubectl get pod -n ex-2-1 target-pod -o jsonpath='{.status.podIP}'

# Example output: 10.244.1.5
# Convert dots to dashes: 10-244-1-5
# Full DNS name: 10-244-1-5.ex-2-1.pod.cluster.local

# Query the pod DNS name
POD_IP=$(kubectl get pod -n ex-2-1 target-pod -o jsonpath='{.status.podIP}')
POD_DNS=$(echo $POD_IP | tr '.' '-')
kubectl exec -n ex-2-1 lookup-pod -- nslookup ${POD_DNS}.ex-2-1.pod.cluster.local
```

**Explanation:** Pod DNS records use the pod's IP address with dots replaced by dashes, followed by the namespace, `pod`, and `cluster.local`. This format is rarely used directly in applications because pod IPs change when pods restart. Services provide stable DNS names, while pod DNS is mainly useful for debugging or when direct pod addressing is required.

---

## Exercise 2.2 Solution

**Task:** Compare DNS behavior between ClusterFirst and Default DNS policies.

**Solution:**

Test service resolution from both pods:

```bash
# ClusterFirst can resolve service names
kubectl exec -n ex-2-2 pod-clusterfirst -- nslookup web-svc

# Default cannot resolve service names
kubectl exec -n ex-2-2 pod-default -- nslookup web-svc
```

**Expected Behavior:**

- **pod-clusterfirst**: Successfully resolves `web-svc` to the service IP
- **pod-default**: Fails with "server can't find web-svc" or similar error

**Explanation:** The `ClusterFirst` policy configures the pod to use the cluster DNS service (CoreDNS) as its nameserver. The `Default` policy uses the node's DNS configuration, which knows nothing about Kubernetes services. This is why Default policy pods cannot resolve service names. Use Default only when you specifically need node-level DNS and do not need cluster service discovery.

---

## Exercise 2.3 Solution

**Task:** Examine /etc/resolv.conf and identify nameserver, search domains, and ndots.

**Solution:**

```bash
kubectl exec -n ex-2-3 examine-pod -- cat /etc/resolv.conf
```

**Expected Output:**

```
nameserver 10.96.0.10
search ex-2-3.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

**Explanation:**

- **nameserver 10.96.0.10**: The IP of the kube-dns service in kube-system namespace. All DNS queries go here.
- **search domains**: Three domains that get appended to short names in order:
  1. `ex-2-3.svc.cluster.local` - finds services in the pod's namespace
  2. `svc.cluster.local` - fallback for services
  3. `cluster.local` - general cluster domain
- **ndots:5**: If a name has fewer than 5 dots, try search domains first. Since most cluster names have 0-4 dots, they all use search domain expansion.

---

## Exercise 3.1 Solution

**Task:** Diagnose why a pod cannot resolve a service name.

**Diagnosis:**

```bash
# Check the pod's DNS policy
kubectl get pod -n ex-3-1 broken-client -o jsonpath='{.spec.dnsPolicy}'
# Output: Default

# Check the pod's resolv.conf
kubectl exec -n ex-3-1 broken-client -- cat /etc/resolv.conf
# Shows node DNS, not cluster DNS
```

**Root Cause:** The pod uses `dnsPolicy: Default`, which means it inherits DNS configuration from the node rather than using cluster DNS. The node's DNS server does not know about Kubernetes services, so `server-svc` cannot be resolved.

**Fix:** Change the pod's dnsPolicy to ClusterFirst (or remove it, since ClusterFirst is the default).

---

## Exercise 3.2 Solution

**Task:** Diagnose why a cross-namespace DNS lookup fails.

**Diagnosis:**

```bash
# This fails
kubectl exec -n ex-3-2-app app -- nslookup mysql-svc
# Tries mysql-svc.ex-3-2-app.svc.cluster.local - wrong namespace

# This works
kubectl exec -n ex-3-2-app app -- nslookup mysql-svc.ex-3-2-db
```

**Root Cause:** The short name `mysql-svc` only searches within the pod's own namespace (ex-3-2-app) via search domains. The service exists in ex-3-2-db, a different namespace.

**Fix:** Use the namespace-qualified name: `mysql-svc.ex-3-2-db` or the full FQDN `mysql-svc.ex-3-2-db.svc.cluster.local`.

---

## Exercise 3.3 Solution

**Task:** Understand search domain expansion for external domains.

**Observation:**

```bash
# Without trailing dot - triggers search domain expansion
kubectl exec -n ex-3-3 external-test -- dig example.com +search +trace

# With trailing dot - queries directly
kubectl exec -n ex-3-3 external-test -- dig example.com. +short
```

**Explanation:** When you query `example.com` (without trailing dot), and the name has fewer than 5 dots (ndots:5), the resolver first tries appending search domains:

1. example.com.ex-3-3.svc.cluster.local (fails)
2. example.com.svc.cluster.local (fails)
3. example.com.cluster.local (fails)
4. example.com (finally succeeds)

This adds latency to external domain queries. Adding a trailing dot (`example.com.`) marks the name as fully qualified, skipping search domain expansion.

**Optimization:** For frequently accessed external domains, use trailing dots or lower the ndots value to reduce unnecessary lookups.

---

## Exercise 4.1 Solution

**Task:** Create a pod with a custom search domain using dnsConfig.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: custom-search
  namespace: ex-4-1
spec:
  dnsPolicy: ClusterFirst
  dnsConfig:
    searches:
      - internal.company.local
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
```

**Verification:**

```bash
kubectl exec -n ex-4-1 custom-search -- cat /etc/resolv.conf
```

**Expected Output:**

```
nameserver 10.96.0.10
search ex-4-1.svc.cluster.local svc.cluster.local cluster.local internal.company.local
options ndots:5
```

**Explanation:** When using dnsPolicy: ClusterFirst with dnsConfig, the dnsConfig settings are merged with the cluster DNS settings. The custom search domain is appended to the existing search domains. This is useful when you need to resolve both cluster names and names in a custom domain.

---

## Exercise 4.2 Solution

**Task:** Create a pod with ndots:1 and verify service resolution.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: low-ndots
  namespace: ex-4-2
spec:
  dnsPolicy: ClusterFirst
  dnsConfig:
    options:
      - name: ndots
        value: "1"
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
```

**Verification:**

```bash
kubectl exec -n ex-4-2 low-ndots -- cat /etc/resolv.conf | grep ndots
# Output: options ndots:1

kubectl exec -n ex-4-2 low-ndots -- nslookup webapi-svc
# Still resolves successfully
```

**Explanation:** With ndots:1, only names with zero dots get search domain expansion. The short name `webapi-svc` has zero dots, so search domains are still applied and it resolves correctly. External domains like `example.com` (one dot) would now be queried directly first, reducing lookup latency. The tradeoff is that names with one or more dots skip search domains, which could break some cluster name lookups if not using FQDNs.

---

## Exercise 4.3 Solution

**Task:** Create a pod with dnsPolicy: None and complete custom DNS configuration.

**Solution:**

First, get the kube-dns IP:

```bash
KUBE_DNS_IP=$(kubectl get svc -n kube-system kube-dns -o jsonpath='{.spec.clusterIP}')
```

Then create the pod (using 10.96.0.10 as a typical kube-dns IP):

```yaml
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: fully-custom
  namespace: ex-4-3
spec:
  dnsPolicy: None
  dnsConfig:
    nameservers:
      - "10.96.0.10"
    searches:
      - ex-4-3.svc.cluster.local
      - svc.cluster.local
    options:
      - name: ndots
        value: "3"
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
```

**Verification:**

```bash
kubectl exec -n ex-4-3 fully-custom -- cat /etc/resolv.conf
kubectl exec -n ex-4-3 fully-custom -- nslookup target-svc
```

**Explanation:** With dnsPolicy: None, you must provide all DNS settings via dnsConfig. This gives complete control over DNS resolution. The pod uses the cluster DNS but with custom search domains and ndots value. This is useful when you need precise control over DNS behavior or when running pods that require specific DNS configurations.

---

## Exercise 5.1 Solution

**Task:** Set up cross-namespace service discovery for a multi-tier application.

**Solution:**

The correct DNS names to use for cross-namespace access:

- From web-frontend to api-svc: `api-svc.ex-5-1-api`
- From web-frontend to postgres-svc: `postgres-svc.ex-5-1-db`
- From api-server to postgres-svc: `postgres-svc.ex-5-1-db`

**Verification:**

```bash
# All cross-namespace lookups
kubectl exec -n ex-5-1-web web-frontend -- nslookup api-svc.ex-5-1-api
kubectl exec -n ex-5-1-web web-frontend -- nslookup postgres-svc.ex-5-1-db
kubectl exec -n ex-5-1-api api-server -- nslookup postgres-svc.ex-5-1-db
```

**Explanation:** In a multi-tier application spanning namespaces, each component must use namespace-qualified DNS names to reach services in other namespaces. The pattern is `<service>.<namespace>`. Applications should be configured with these DNS names (not hardcoded IPs) so they continue working if services are recreated with new IPs.

---

## Exercise 5.2 Solution

**Task:** Debug DNS behavior for pods using host networking.

**Diagnosis:**

```bash
# Check DNS policies
kubectl get pod -n ex-5-2 hostnet-wrong -o jsonpath='{.spec.dnsPolicy}'
# Output: ClusterFirst

kubectl get pod -n ex-5-2 hostnet-correct -o jsonpath='{.spec.dnsPolicy}'
# Output: ClusterFirstWithHostNet

# Check resolv.conf
kubectl exec -n ex-5-2 hostnet-wrong -- cat /etc/resolv.conf
# Shows node DNS

kubectl exec -n ex-5-2 hostnet-correct -- cat /etc/resolv.conf
# Shows cluster DNS (10.96.0.10)
```

**Finding:** hostnet-correct can resolve cluster service names, hostnet-wrong cannot.

**Explanation:** When a pod uses `hostNetwork: true`, it shares the node's network namespace. With `dnsPolicy: ClusterFirst`, Kubernetes would normally configure cluster DNS, but because the pod is in the host network namespace, it actually inherits the node's DNS configuration. The `ClusterFirstWithHostNet` policy specifically handles this case, ensuring cluster DNS is used even with host networking. Always use ClusterFirstWithHostNet for host network pods that need to resolve cluster services.

---

## Exercise 5.3 Solution

**Task:** Create a pod with optimized DNS settings including custom domain and reduced ndots.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: optimized-app
  namespace: ex-5-3
spec:
  dnsPolicy: ClusterFirst
  dnsConfig:
    searches:
      - internal.corp
    options:
      - name: ndots
        value: "2"
  containers:
  - name: nginx
    image: nginx:1.25
EOF
```

**Verification:**

```bash
kubectl exec -n ex-5-3 optimized-app -- cat /etc/resolv.conf
```

**Expected Output:**

```
nameserver 10.96.0.10
search ex-5-3.svc.cluster.local svc.cluster.local cluster.local internal.corp
options ndots:2
```

**Explanation:** This configuration provides:

1. **Cluster DNS access** through ClusterFirst policy and default search domains
2. **Custom domain resolution** through the added `internal.corp` search domain
3. **Optimized external lookups** through ndots:2, which reduces search domain expansion for external domains with 2+ dots

The tradeoff with ndots:2 is that names like `web.namespace` (1 dot) would still trigger search domains, but `api.example.com` (2 dots) would be queried directly first, improving performance for external API calls.

---

## Common Mistakes

### Using IP Instead of DNS Name

**Mistake:** Hardcoding service IPs instead of using DNS names.

**Problem:** Service IPs change when services are recreated. Applications break when IPs change.

**Fix:** Always use DNS names for service discovery. Use short names within namespace, namespace-qualified names across namespaces.

### Wrong DNS Policy for Host Network Pods

**Mistake:** Using `dnsPolicy: ClusterFirst` with `hostNetwork: true`.

**Problem:** The pod inherits node DNS instead of cluster DNS, and cannot resolve service names.

**Fix:** Use `dnsPolicy: ClusterFirstWithHostNet` for pods with host networking.

### Not Understanding Search Domains

**Mistake:** Using full FQDNs everywhere or short names for cross-namespace access.

**Problem:** FQDNs are verbose and error-prone. Short names only work within the same namespace.

**Fix:** Use short names within namespace, namespace-qualified names across namespaces. Understand how search domains work to use the shortest appropriate name.

### External Domains Without Trailing Dot

**Mistake:** Querying external domains without trailing dot and wondering about slow performance.

**Problem:** Search domain expansion tries cluster domains first, adding latency.

**Fix:** Use trailing dot for external FQDNs (`example.com.`) or lower ndots value if your application makes many external calls.

### ndots Affecting Query Behavior

**Mistake:** Changing ndots without understanding the impact.

**Problem:** Too low ndots breaks some cluster name resolution. Too high ndots adds latency to external queries.

**Fix:** Default ndots:5 works for most cases. Lower only if you understand the tradeoffs and your application makes many external calls.

---

## DNS Commands Cheat Sheet

| Task | Command |
|------|---------|
| Simple lookup | `nslookup <name>` |
| Lookup with server | `nslookup <name> <server-ip>` |
| Detailed lookup | `dig <name>` |
| Lookup with specific server | `dig @<server-ip> <name>` |
| Short answer only | `dig <name> +short` |
| Trace query path | `dig <name> +trace` |
| View resolv.conf | `cat /etc/resolv.conf` |
| Get kube-dns IP | `kubectl get svc -n kube-system kube-dns -o jsonpath='{.spec.clusterIP}'` |
| List CoreDNS pods | `kubectl get pods -n kube-system -l k8s-app=kube-dns` |
| Get pod IP | `kubectl get pod <name> -o jsonpath='{.status.podIP}'` |
| Check DNS policy | `kubectl get pod <name> -o jsonpath='{.spec.dnsPolicy}'` |
