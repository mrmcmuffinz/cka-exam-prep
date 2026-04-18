# CoreDNS Homework Answers: CoreDNS Configuration

Complete solutions for all 15 exercises with explanations.

---

## Exercise 1.1 Solution

**Task:** List CoreDNS pods and the kube-dns service, and identify how pods find the DNS server.

**Solution:**

```bash
# List CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Get kube-dns service details
kubectl get svc kube-dns -n kube-system

# Get the ClusterIP
kubectl get svc kube-dns -n kube-system -o jsonpath='{.spec.clusterIP}'

# Check pod's nameserver
kubectl exec -n ex-1-1 explorer -- cat /etc/resolv.conf
```

**Explanation:** CoreDNS pods run in kube-system with the label `k8s-app=kube-dns`. The kube-dns Service provides a stable ClusterIP (typically 10.96.0.10) that is configured as the nameserver in every pod's /etc/resolv.conf. This is how pods discover the DNS server without needing to know which nodes CoreDNS pods run on.

---

## Exercise 1.2 Solution

**Task:** Retrieve and examine the CoreDNS ConfigMap.

**Solution:**

```bash
kubectl get configmap coredns -n kube-system -o yaml
```

**Output (key sections):**

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
        health { ... }
        ...
    }
```

**Explanation:** The ConfigMap is named `coredns` and contains a single key `Corefile` which holds the CoreDNS configuration. The Corefile defines how CoreDNS handles DNS queries, including which plugins to use and in what order.

---

## Exercise 1.3 Solution

**Task:** Identify all plugins in the default Corefile.

**Solution:**

```bash
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}'
```

**Default plugins (typically 10 or more):**

1. errors - logs errors
2. health - provides health endpoint
3. ready - provides readiness endpoint
4. kubernetes - resolves cluster DNS
5. prometheus - exposes metrics
6. forward - forwards external queries
7. cache - caches responses
8. loop - detects forwarding loops
9. reload - auto-reloads config
10. loadbalance - randomizes response order

**Explanation:** Each plugin handles a specific function. The plugins are processed in order for each DNS query. Some plugins (like kubernetes) answer queries directly, while others (like cache) modify behavior without directly answering.

---

## Exercise 2.1 Solution

**Task:** Examine the kubernetes plugin configuration.

**Solution:**

```bash
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' | grep -A5 "kubernetes"
```

**Output:**

```
kubernetes cluster.local in-addr.arpa ip6.arpa {
   pods insecure
   fallthrough in-addr.arpa ip6.arpa
   ttl 30
}
```

**Key settings:**

- **cluster.local**: The cluster domain for services and pods
- **pods insecure**: Enables pod A records (insecure means no verification)
- **ttl 30**: DNS responses have a 30-second TTL
- **fallthrough**: For reverse DNS zones, pass to next plugin if no match

**Explanation:** The kubernetes plugin is what makes cluster DNS work. It watches the Kubernetes API for Services and Endpoints and creates DNS records accordingly. The ttl value controls how long clients cache responses.

---

## Exercise 2.2 Solution

**Task:** Examine the forward plugin and test external DNS.

**Solution:**

```bash
# View forward config
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' | grep -A3 "forward"

# Test external resolution
kubectl exec -n ex-2-2 external-test -- nslookup example.com
```

**Forward configuration:**

```
forward . /etc/resolv.conf {
   max_concurrent 1000
}
```

**Explanation:** The `.` means forward all unmatched queries. `/etc/resolv.conf` refers to the CoreDNS pod's resolv.conf, which contains the node's upstream DNS servers. This is how external domains like example.com get resolved. The `max_concurrent` limits parallel queries to prevent overload.

---

## Exercise 2.3 Solution

**Task:** View CoreDNS logs and note default logging behavior.

**Solution:**

```bash
# Generate queries
kubectl exec -n ex-2-3 query-maker -- nslookup kubernetes.default
kubectl exec -n ex-2-3 query-maker -- nslookup nonexistent.invalid

# View logs
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=20
```

**Observation:** By default, only errors are logged (via the `errors` plugin). Successful queries are NOT logged unless you add the `log` plugin. You may see NXDOMAIN errors for nonexistent.invalid.

**Explanation:** The default configuration only logs errors to minimize log volume. In production clusters with thousands of pods, logging every query would generate massive amounts of data. Enable the `log` plugin only when debugging.

---

## Exercise 3.1 Solution

**Task:** Diagnose why DNS is completely broken.

**Diagnosis:**

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=30
```

**Root Cause:** The Corefile has a syntax error. The `health` block is missing a closing brace `}` before `ready`:

```
health {
   lameduck 5s
ready          <- Should be after closing brace
```

**Correct syntax:**

```
health {
   lameduck 5s
}
ready
```

**Explanation:** CoreDNS fails to parse the Corefile and either crashes or refuses to reload. The logs will show a parse error. Syntax errors in the Corefile can completely break cluster DNS.

---

## Exercise 3.2 Solution

**Task:** Diagnose why external DNS fails but cluster DNS works.

**Diagnosis:**

```bash
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' | grep forward
```

**Output:**

```
forward . 192.0.2.1 {
```

**Root Cause:** The forward plugin is configured to use `192.0.2.1` as the upstream DNS server. This IP is in the TEST-NET-1 range (192.0.2.0/24), which is reserved for documentation and will not respond to DNS queries.

**Fix:** Change the forward plugin to use valid DNS servers:

```
forward . /etc/resolv.conf {
```

or

```
forward . 8.8.8.8 8.8.4.4 {
```

**Explanation:** Cluster DNS (kubernetes plugin) works independently of the forward plugin. External queries fail because the configured upstream server does not exist or respond.

---

## Exercise 3.3 Solution

**Task:** Diagnose why service DNS stopped working after adding custom hosts.

**Diagnosis:**

```bash
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' | grep -A4 "hosts"
```

**Output:**

```
hosts {
   10.10.10.10 custom.internal
}
```

**Root Cause:** The hosts plugin is missing the `fallthrough` directive. Without fallthrough, the hosts plugin claims authority for all queries and returns NXDOMAIN for anything not in its list.

**Fix:** Add fallthrough to the hosts block:

```
hosts {
   10.10.10.10 custom.internal
   fallthrough
}
```

**Explanation:** In CoreDNS, plugins process queries in order. When a plugin handles a query (even to say "not found"), subsequent plugins do not run unless `fallthrough` is specified. The hosts plugin needs fallthrough to allow the kubernetes plugin to handle cluster DNS queries.

---

## Exercise 4.1 Solution

**Task:** Add a custom DNS entry that works alongside cluster DNS.

**Solution:**

```bash
kubectl edit configmap coredns -n kube-system
```

Add hosts block with fallthrough:

```
.:53 {
    errors
    health {
       lameduck 5s
    }
    ready
    hosts {
       172.16.0.100 legacy-db.internal
       fallthrough
    }
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    forward . /etc/resolv.conf
    cache 30
    loop
    reload
    loadbalance
}
```

**Key points:**

- Add hosts block BEFORE kubernetes plugin
- Include `fallthrough` so kubernetes plugin still processes
- Wait for automatic reload (up to 30 seconds)

**Explanation:** The hosts plugin provides simple static DNS entries. With fallthrough, queries not matching any host entry pass to the next plugin (kubernetes), preserving normal cluster DNS functionality.

---

## Exercise 4.2 Solution

**Task:** Enable query logging in CoreDNS.

**Solution:**

```bash
kubectl edit configmap coredns -n kube-system
```

Add the `log` plugin after `errors`:

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

**Verification:**

```bash
# Generate queries
kubectl exec -n ex-4-2 log-tester -- nslookup kubernetes.default

# View logs
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=20
```

**Log format:**

```
[INFO] 10.244.0.5:12345 - 12345 "A IN kubernetes.default.svc.cluster.local. udp 53 false 512" NOERROR qr,aa,rd 106 0.000123s
```

**Explanation:** The `log` plugin logs every query with source IP, query type, name, response code, and latency. This is invaluable for debugging but generates significant log volume in busy clusters.

---

## Exercise 4.3 Solution

**Task:** Modify cache TTL settings with negative caching.

**Solution:**

```bash
kubectl edit configmap coredns -n kube-system
```

Replace the cache line:

```
cache 60 {
    denial 9984 5
}
```

**Settings:**

- **60**: Maximum TTL for successful responses
- **denial 9984 5**: Cache up to 9984 negative responses for 5 seconds

**Explanation:** The denial setting controls negative caching (NXDOMAIN responses). A short denial TTL (5 seconds) means that when a service is first created, pods will retry failed lookups quickly rather than waiting for a longer cache expiry. The number 9984 is the maximum cache size.

---

## Exercise 5.1 Solution

**Task:** Configure a stub domain for enterprise DNS.

**Solution:**

```bash
kubectl edit configmap coredns -n kube-system
```

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
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
    forward . /etc/resolv.conf
    cache 30
    loop
    reload
    loadbalance
}
```

**Key points:**

- Separate server block for the stub domain
- Comes BEFORE the main server block
- Forwards only to enterprise DNS servers
- Main block still handles everything else

**Explanation:** CoreDNS processes server blocks from most specific to least specific. Queries for `*.corp.example.com` match the first block and go to enterprise DNS. All other queries match the `.` (root) block and use normal resolution.

---

## Exercise 5.2 Solution

**Task:** Troubleshoot the custom internal.company configuration.

**Diagnosis:**

Test the resolution:

```bash
kubectl exec -n ex-5-2 config-tester -- nslookup db.internal.company
```

**Finding:** The resolution likely fails because of how CoreDNS matches server blocks.

**Root Cause:** The server block is defined for `internal.company:53`, but queries from pods go to the main server block (.:53) first. The pods are not querying for `internal.company` directly; the search domains append cluster domains.

**Additional Issue:** The hosts plugin in the stub domain block does not have `fallthrough`, so the forward to 10.1.0.53 never runs for hosts entries.

**Fix (not applied):**

1. Either add the hosts entries to the main server block with proper fallthrough
2. Or configure pods to use FQDNs like `db.internal.company.`

**Explanation:** Server block matching depends on how the query arrives. Since pods use search domains, `db.internal.company` becomes `db.internal.company.ex-5-2.svc.cluster.local` first, which matches the main block, not the stub.

---

## Exercise 5.3 Solution

**Task:** Design a complete CoreDNS configuration meeting all requirements.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        log
        health {
           lameduck 5s
        }
        ready
        hosts {
           10.20.30.40 monitoring.internal
           fallthrough
        }
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 45
        loop
        reload
        loadbalance
    }
EOF
```

**Requirements met:**

1. **Normal cluster DNS**: kubernetes plugin with cluster.local
2. **Query logging**: log plugin added after errors
3. **Custom entry**: hosts plugin with monitoring.internal -> 10.20.30.40 and fallthrough
4. **Cache TTL of 45 seconds**: cache 45
5. **Standard plugins**: health, ready, reload all present

**Explanation:** This configuration combines all requirements. The key is placing hosts before kubernetes (so custom entries are checked first) and including fallthrough (so kubernetes plugin still works).

---

## Common Mistakes

### Syntax Errors in Corefile

**Mistake:** Missing braces, typos in plugin names, or incorrect indentation.

**Problem:** CoreDNS fails to start or reload, breaking cluster DNS completely.

**Fix:** Always validate syntax by checking CoreDNS pod status after changes. Keep a backup before editing.

### Plugin Order Matters

**Mistake:** Placing plugins in wrong order or forgetting fallthrough.

**Problem:** Queries may not reach the correct plugin, causing resolution failures.

**Fix:** Understand that plugins process in order. Use fallthrough when a plugin should not be authoritative for all queries.

### Not Waiting for Reload

**Mistake:** Testing immediately after ConfigMap change.

**Problem:** CoreDNS checks for changes every 30 seconds. Tests may show old behavior.

**Fix:** Wait at least 30 seconds after ConfigMap changes, or watch logs for "Reloading complete" message.

### Wrong ConfigMap Name or Namespace

**Mistake:** Editing a ConfigMap with wrong name or in wrong namespace.

**Problem:** Changes have no effect because CoreDNS uses the coredns ConfigMap in kube-system.

**Fix:** Always verify: `kubectl get configmap coredns -n kube-system`

### Breaking Cluster DNS with Bad Config

**Mistake:** Making changes without a backup or without testing.

**Problem:** Cluster DNS breaks, affecting all workloads.

**Fix:** Always backup before editing. Test immediately after changes. Have a recovery plan.

---

## CoreDNS Configuration Cheat Sheet

| Task | Configuration |
|------|---------------|
| Enable logging | Add `log` after `errors` |
| Add custom entry | `hosts { IP hostname fallthrough }` |
| Change cache TTL | `cache <seconds>` |
| Negative cache | `cache <ttl> { denial <size> <seconds> }` |
| Stub domain | New server block: `domain:53 { forward . <dns-servers> }` |
| Custom upstream DNS | `forward . 8.8.8.8 8.8.4.4` |
| DNS over TLS | `forward . tls://9.9.9.9 { tls_servername dns.quad9.net }` |
| View current config | `kubectl get cm coredns -n kube-system -o jsonpath='{.data.Corefile}'` |
| Edit config | `kubectl edit cm coredns -n kube-system` |
| Backup config | `kubectl get cm coredns -n kube-system -o yaml > backup.yaml` |
| View logs | `kubectl logs -n kube-system -l k8s-app=kube-dns` |
| Check pods | `kubectl get pods -n kube-system -l k8s-app=kube-dns` |
