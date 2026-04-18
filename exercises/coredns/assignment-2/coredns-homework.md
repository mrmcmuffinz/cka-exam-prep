# CoreDNS Homework: CoreDNS Configuration

Work through these 15 exercises to build practical skills with CoreDNS configuration. Complete the tutorial (coredns-tutorial.md) before starting these exercises. Each level increases in complexity, building on concepts from previous levels.

**Important:** Before editing the CoreDNS ConfigMap, always create a backup. Incorrect changes can break DNS for the entire cluster.

---

## Level 1: CoreDNS Exploration

These exercises focus on examining the CoreDNS components without making changes.

### Exercise 1.1

**Objective:** List CoreDNS pods and the kube-dns service, and identify how pods find the DNS server.

**Setup:**

```bash
kubectl create namespace ex-1-1

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: explorer
  namespace: ex-1-1
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/explorer -n ex-1-1 --timeout=60s
```

**Task:** List the CoreDNS pods in kube-system namespace. Get the kube-dns service details. Then verify that the explorer pod uses the kube-dns ClusterIP as its nameserver.

**Verification:**

```bash
# CoreDNS pods should be running
kubectl get pods -n kube-system -l k8s-app=kube-dns | grep -q "Running" && echo "CoreDNS pods running" || echo "CoreDNS pods not running"

# kube-dns service should exist
kubectl get svc kube-dns -n kube-system -o jsonpath='{.spec.clusterIP}' && echo ""

# Pod should use kube-dns IP
KUBE_DNS_IP=$(kubectl get svc kube-dns -n kube-system -o jsonpath='{.spec.clusterIP}')
kubectl exec -n ex-1-1 explorer -- cat /etc/resolv.conf | grep -q "$KUBE_DNS_IP" && echo "Pod uses kube-dns" || echo "Pod does not use kube-dns"
```

---

### Exercise 1.2

**Objective:** View and examine the CoreDNS ConfigMap.

**Setup:**

```bash
kubectl create namespace ex-1-2
```

**Task:** Retrieve the CoreDNS ConfigMap from kube-system namespace and examine its contents. Identify the name of the configuration file stored in the ConfigMap.

**Verification:**

```bash
# ConfigMap should exist and contain Corefile
kubectl get configmap coredns -n kube-system -o jsonpath='{.data}' | grep -q "Corefile" && echo "Corefile found in ConfigMap" || echo "Corefile not found"
```

---

### Exercise 1.3

**Objective:** Identify all plugins configured in the default Corefile.

**Setup:**

```bash
kubectl create namespace ex-1-3
```

**Task:** View the Corefile from the coredns ConfigMap. List all the plugins that are configured in the default server block. Count how many plugins are present.

**Verification:**

```bash
# The Corefile should contain the kubernetes plugin
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' | grep -q "kubernetes" && echo "kubernetes plugin present" || echo "kubernetes plugin missing"

# The Corefile should contain the forward plugin
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' | grep -q "forward" && echo "forward plugin present" || echo "forward plugin missing"

# The Corefile should contain the cache plugin
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' | grep -q "cache" && echo "cache plugin present" || echo "cache plugin missing"
```

---

## Level 2: Configuration Basics

These exercises focus on understanding how specific plugins work.

### Exercise 2.1

**Objective:** Examine the kubernetes plugin configuration and understand its options.

**Setup:**

```bash
kubectl create namespace ex-2-1

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: webserver
  namespace: ex-2-1
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
  namespace: ex-2-1
spec:
  selector:
    app: web
  ports:
  - port: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: ex-2-1
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/client -n ex-2-1 --timeout=60s
```

**Task:** View the kubernetes plugin section in the Corefile. Identify the cluster domain, the TTL value, and whether pod DNS records are enabled. Then verify that the client pod can resolve the web-svc service.

**Verification:**

```bash
# Kubernetes plugin should have cluster.local domain
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' | grep -q "cluster.local" && echo "cluster.local domain configured" || echo "cluster.local not found"

# Service resolution should work
kubectl exec -n ex-2-1 client -- nslookup web-svc 2>/dev/null | grep -q "Address" && echo "Service resolution works" || echo "Service resolution failed"
```

---

### Exercise 2.2

**Objective:** Examine the forward plugin configuration and understand upstream DNS.

**Setup:**

```bash
kubectl create namespace ex-2-2

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: external-test
  namespace: ex-2-2
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/external-test -n ex-2-2 --timeout=60s
```

**Task:** View the forward plugin section in the Corefile. Identify where external DNS queries are forwarded. Then test resolving an external domain from the pod.

**Verification:**

```bash
# Forward plugin should be present
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' | grep -q "forward" && echo "forward plugin present" || echo "forward plugin missing"

# External DNS should resolve
kubectl exec -n ex-2-2 external-test -- nslookup example.com 2>/dev/null | grep -q "Address" && echo "External DNS works" || echo "External DNS failed"
```

---

### Exercise 2.3

**Objective:** View CoreDNS logs to see DNS activity.

**Setup:**

```bash
kubectl create namespace ex-2-3

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: query-maker
  namespace: ex-2-3
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/query-maker -n ex-2-3 --timeout=60s
```

**Task:** Generate some DNS queries from the pod. Then view CoreDNS logs to see if any activity is logged. Note whether successful queries are logged by default.

**Verification:**

```bash
# Generate queries
kubectl exec -n ex-2-3 query-maker -- nslookup kubernetes.default
kubectl exec -n ex-2-3 query-maker -- nslookup nonexistent.invalid 2>/dev/null || true

# View logs (may show errors for failed queries)
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=20
```

---

## Level 3: Debugging Configuration Issues

These exercises present broken CoreDNS configurations to diagnose.

### Exercise 3.1

**Objective:** DNS queries are failing for all pods in the cluster. Diagnose the issue.

**Setup:**

```bash
kubectl create namespace ex-3-1

# Backup current config
kubectl get configmap coredns -n kube-system -o yaml > /tmp/coredns-backup-3-1.yaml

# Apply broken config (syntax error)
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
        health {
           lameduck 5s
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
EOF

# Wait for pods to potentially restart
sleep 5
```

**Task:** Diagnose why DNS is broken. Check CoreDNS pod status and logs to find the issue.

**Verification:**

```bash
# Check CoreDNS pod status
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check logs for errors
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=30 2>&1 | head -20
```

**Cleanup (restore working config):**

```bash
kubectl apply -f /tmp/coredns-backup-3-1.yaml
sleep 10
```

---

### Exercise 3.2

**Objective:** External domain resolution is failing, but cluster DNS works. Diagnose the issue.

**Setup:**

```bash
kubectl create namespace ex-3-2

# Backup current config
kubectl get configmap coredns -n kube-system -o yaml > /tmp/coredns-backup-3-2.yaml

# Apply config with broken forward
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
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        forward . 192.0.2.1 {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
EOF

sleep 15

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: dns-tester
  namespace: ex-3-2
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/dns-tester -n ex-3-2 --timeout=60s
```

**Task:** Cluster DNS (kubernetes.default) works, but external DNS (example.com) times out. Diagnose why by examining the Corefile.

**Verification:**

```bash
# Cluster DNS should work
kubectl exec -n ex-3-2 dns-tester -- nslookup kubernetes.default 2>/dev/null | grep -q "Address" && echo "Cluster DNS: OK" || echo "Cluster DNS: FAILED"

# External DNS should fail (192.0.2.1 is not a real DNS server)
timeout 5 kubectl exec -n ex-3-2 dns-tester -- nslookup example.com 2>&1 || echo "External DNS: TIMEOUT (expected)"
```

**Cleanup:**

```bash
kubectl apply -f /tmp/coredns-backup-3-2.yaml
sleep 10
```

---

### Exercise 3.3

**Objective:** Custom DNS entries are not working as expected. Diagnose the configuration.

**Setup:**

```bash
kubectl create namespace ex-3-3

# Backup current config
kubectl get configmap coredns -n kube-system -o yaml > /tmp/coredns-backup-3-3.yaml

# Apply config with hosts but missing fallthrough
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
        health {
           lameduck 5s
        }
        ready
        hosts {
           10.10.10.10 custom.internal
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
EOF

sleep 15

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: hosts-tester
  namespace: ex-3-3
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/hosts-tester -n ex-3-3 --timeout=60s
```

**Task:** The custom.internal hostname resolves, but service names no longer resolve. Diagnose what is wrong with the hosts plugin configuration.

**Verification:**

```bash
# Custom hostname works
kubectl exec -n ex-3-3 hosts-tester -- nslookup custom.internal 2>/dev/null | grep -q "10.10.10.10" && echo "Custom hostname: OK" || echo "Custom hostname: FAILED"

# Service DNS fails (because hosts plugin without fallthrough stops processing)
kubectl exec -n ex-3-3 hosts-tester -- nslookup kubernetes.default 2>&1 | head -5
```

**Cleanup:**

```bash
kubectl apply -f /tmp/coredns-backup-3-3.yaml
sleep 10
```

---

## Level 4: Customization

These exercises involve making intentional changes to CoreDNS configuration.

### Exercise 4.1

**Objective:** Add a custom DNS entry that resolves alongside normal cluster DNS.

**Setup:**

```bash
kubectl create namespace ex-4-1

# Backup current config
kubectl get configmap coredns -n kube-system -o yaml > /tmp/coredns-backup-4-1.yaml

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: app-server
  namespace: ex-4-1
  labels:
    app: app
spec:
  containers:
  - name: nginx
    image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: app-svc
  namespace: ex-4-1
spec:
  selector:
    app: app
  ports:
  - port: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: lookup-pod
  namespace: ex-4-1
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/lookup-pod -n ex-4-1 --timeout=60s
```

**Task:** Modify the CoreDNS ConfigMap to add a custom DNS entry: `legacy-db.internal` should resolve to `172.16.0.100`. Ensure that normal cluster DNS still works after the change.

**Verification:**

```bash
# Wait for reload
sleep 15

# Custom entry should resolve
kubectl exec -n ex-4-1 lookup-pod -- nslookup legacy-db.internal 2>/dev/null | grep -q "172.16.0.100" && echo "Custom entry: OK" || echo "Custom entry: FAILED"

# Cluster DNS should still work
kubectl exec -n ex-4-1 lookup-pod -- nslookup app-svc 2>/dev/null | grep -q "Address" && echo "Cluster DNS: OK" || echo "Cluster DNS: FAILED"
```

**Cleanup:**

```bash
kubectl apply -f /tmp/coredns-backup-4-1.yaml
sleep 10
```

---

### Exercise 4.2

**Objective:** Enable query logging in CoreDNS.

**Setup:**

```bash
kubectl create namespace ex-4-2

# Backup current config
kubectl get configmap coredns -n kube-system -o yaml > /tmp/coredns-backup-4-2.yaml

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: log-tester
  namespace: ex-4-2
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/log-tester -n ex-4-2 --timeout=60s
```

**Task:** Add the `log` plugin to the CoreDNS Corefile to enable query logging. Generate some DNS queries and verify they appear in the CoreDNS logs.

**Verification:**

```bash
# Wait for reload
sleep 15

# Generate queries
kubectl exec -n ex-4-2 log-tester -- nslookup kubernetes.default
kubectl exec -n ex-4-2 log-tester -- nslookup example.com

# Check logs for query entries
sleep 5
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=50 | grep -E "(kubernetes|example)" && echo "Queries logged" || echo "No query logs found"
```

**Cleanup:**

```bash
kubectl apply -f /tmp/coredns-backup-4-2.yaml
sleep 10
```

---

### Exercise 4.3

**Objective:** Modify the cache TTL settings.

**Setup:**

```bash
kubectl create namespace ex-4-3

# Backup current config
kubectl get configmap coredns -n kube-system -o yaml > /tmp/coredns-backup-4-3.yaml
```

**Task:** Modify the CoreDNS cache settings to use a maximum TTL of 60 seconds and configure negative caching (NXDOMAIN responses) to be cached for only 5 seconds. This helps when services are being created and you want failed lookups to be retried quickly.

**Verification:**

```bash
# Wait for reload
sleep 15

# Verify cache settings in config
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' | grep -A2 "cache" | head -5
```

**Cleanup:**

```bash
kubectl apply -f /tmp/coredns-backup-4-3.yaml
sleep 10
```

---

## Level 5: Complex Scenarios

These exercises present more challenging real-world scenarios.

### Exercise 5.1

**Objective:** Configure a stub domain for enterprise DNS integration.

**Setup:**

```bash
kubectl create namespace ex-5-1

# Backup current config
kubectl get configmap coredns -n kube-system -o yaml > /tmp/coredns-backup-5-1.yaml

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: enterprise-app
  namespace: ex-5-1
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/enterprise-app -n ex-5-1 --timeout=60s
```

**Task:** Configure CoreDNS with a stub domain so that all queries for `corp.example.com` are forwarded to DNS servers at 10.0.0.53 and 10.0.0.54 (these are example IPs for illustration). Other queries should continue to use the default upstream DNS. Verify the configuration is syntactically correct (the actual resolution will fail since these servers do not exist).

**Verification:**

```bash
# Wait for reload
sleep 15

# Verify config has stub domain
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' | grep -q "corp.example.com" && echo "Stub domain configured" || echo "Stub domain not found"

# CoreDNS should still be running
kubectl get pods -n kube-system -l k8s-app=kube-dns | grep -q "Running" && echo "CoreDNS running" || echo "CoreDNS not running"

# Normal DNS should work
kubectl exec -n ex-5-1 enterprise-app -- nslookup kubernetes.default 2>/dev/null | grep -q "Address" && echo "Normal DNS: OK" || echo "Normal DNS: FAILED"
```

**Cleanup:**

```bash
kubectl apply -f /tmp/coredns-backup-5-1.yaml
sleep 10
```

---

### Exercise 5.2

**Objective:** Troubleshoot a complex custom configuration that is not working correctly.

**Setup:**

```bash
kubectl create namespace ex-5-2

# Backup current config
kubectl get configmap coredns -n kube-system -o yaml > /tmp/coredns-backup-5-2.yaml

# Apply problematic config
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
    
    internal.company:53 {
        errors
        hosts {
           10.1.1.1 db.internal.company
           10.1.1.2 api.internal.company
        }
        forward . 10.1.0.53
    }
EOF

sleep 15

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: config-tester
  namespace: ex-5-2
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/config-tester -n ex-5-2 --timeout=60s
```

**Task:** The configuration has a custom server block for `internal.company` domain. Test whether `db.internal.company` resolves correctly. If not, diagnose why and identify the fix (do not apply the fix, just identify it).

**Verification:**

```bash
# Test the custom domain resolution
kubectl exec -n ex-5-2 config-tester -- nslookup db.internal.company 2>&1 | head -5

# Check if CoreDNS is healthy
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

**Cleanup:**

```bash
kubectl apply -f /tmp/coredns-backup-5-2.yaml
sleep 10
```

---

### Exercise 5.3

**Objective:** Design a CoreDNS configuration to meet specific requirements.

**Setup:**

```bash
kubectl create namespace ex-5-3

# Backup current config
kubectl get configmap coredns -n kube-system -o yaml > /tmp/coredns-backup-5-3.yaml
```

**Task:** Design and implement a CoreDNS configuration that meets these requirements:

1. Normal cluster DNS for services and pods
2. Query logging enabled
3. Custom entry: `monitoring.internal` resolves to `10.20.30.40`
4. Cache TTL of 45 seconds
5. All the standard health, ready, and reload plugins

Create the complete Corefile and apply it. Verify all requirements are met.

**Verification:**

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: requirements-test
  namespace: ex-5-3
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/requirements-test -n ex-5-3 --timeout=60s

# Wait for config reload
sleep 15

# Test cluster DNS
kubectl exec -n ex-5-3 requirements-test -- nslookup kubernetes.default 2>/dev/null | grep -q "Address" && echo "Cluster DNS: OK" || echo "Cluster DNS: FAILED"

# Test custom entry
kubectl exec -n ex-5-3 requirements-test -- nslookup monitoring.internal 2>/dev/null | grep -q "10.20.30.40" && echo "Custom entry: OK" || echo "Custom entry: FAILED"

# Verify logging is enabled
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' | grep -q "log" && echo "Logging: Enabled" || echo "Logging: Disabled"

# Verify cache setting
kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' | grep -q "cache 45" && echo "Cache 45s: OK" || echo "Cache 45s: FAILED"
```

**Cleanup:**

```bash
kubectl apply -f /tmp/coredns-backup-5-3.yaml
sleep 10
```

---

## Cleanup

Remove all exercise namespaces:

```bash
kubectl delete namespace ex-1-1 ex-1-2 ex-1-3
kubectl delete namespace ex-2-1 ex-2-2 ex-2-3
kubectl delete namespace ex-3-1 ex-3-2 ex-3-3
kubectl delete namespace ex-4-1 ex-4-2 ex-4-3
kubectl delete namespace ex-5-1 ex-5-2 ex-5-3
```

Remove any backup files:

```bash
rm -f /tmp/coredns-backup-*.yaml
```

---

## Key Takeaways

1. **CoreDNS runs as a Deployment** in kube-system with the kube-dns Service providing a stable IP that pods use as their nameserver.

2. **The Corefile is stored in a ConfigMap** named coredns in kube-system. Changes to this ConfigMap are automatically detected and loaded.

3. **Plugins process in order** within a server block. Understanding plugin order is important for troubleshooting.

4. **The kubernetes plugin** enables cluster DNS for services and pods. The cluster.local domain is the default.

5. **The forward plugin** sends external queries to upstream DNS servers. Misconfigured upstream servers break external resolution.

6. **The hosts plugin needs fallthrough** if you want other plugins (like kubernetes) to also process queries.

7. **Always backup before editing** the CoreDNS ConfigMap. A bad config can break DNS for the entire cluster.
