# CoreDNS Homework: DNS Fundamentals

Work through these 15 exercises to build practical skills with Kubernetes DNS. Complete the tutorial (coredns-tutorial.md) before starting these exercises. Each level increases in complexity, building on concepts from previous levels.

---

## Level 1: Service DNS

These exercises focus on basic service DNS lookups using different name formats.

### Exercise 1.1

**Objective:** Look up a service using its short name from within the same namespace.

**Setup:**

```bash
kubectl create namespace ex-1-1

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: ex-1-1
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
  namespace: ex-1-1
spec:
  selector:
    app: backend
  ports:
  - port: 8080
    targetPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: ex-1-1
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/client -n ex-1-1 --timeout=60s
kubectl wait --for=condition=Ready pod/backend -n ex-1-1 --timeout=60s
```

**Task:** From the client pod, use nslookup to resolve the backend-svc service using only its short name (no namespace or domain suffix).

**Verification:**

```bash
# This should show the service IP
kubectl exec -n ex-1-1 client -- nslookup backend-svc 2>/dev/null | grep -q "Address" && echo "DNS resolution successful" || echo "DNS resolution failed"
```

---

### Exercise 1.2

**Objective:** Look up a service using its fully qualified domain name (FQDN).

**Setup:**

```bash
kubectl create namespace ex-1-2

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: database
  namespace: ex-1-2
  labels:
    app: database
spec:
  containers:
  - name: redis
    image: redis:7.2
---
apiVersion: v1
kind: Service
metadata:
  name: database-svc
  namespace: ex-1-2
spec:
  selector:
    app: database
  ports:
  - port: 6379
    targetPort: 6379
---
apiVersion: v1
kind: Pod
metadata:
  name: lookup
  namespace: ex-1-2
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/lookup -n ex-1-2 --timeout=60s
kubectl wait --for=condition=Ready pod/database -n ex-1-2 --timeout=60s
```

**Task:** From the lookup pod, use nslookup to resolve the database-svc service using its complete FQDN including the cluster.local domain.

**Verification:**

```bash
# The FQDN query should resolve to the service IP
kubectl exec -n ex-1-2 lookup -- nslookup database-svc.ex-1-2.svc.cluster.local 2>/dev/null | grep -q "Address" && echo "FQDN resolution successful" || echo "FQDN resolution failed"
```

---

### Exercise 1.3

**Objective:** Look up a service in a different namespace.

**Setup:**

```bash
kubectl create namespace ex-1-3-frontend
kubectl create namespace ex-1-3-backend

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: api
  namespace: ex-1-3-backend
  labels:
    app: api
spec:
  containers:
  - name: nginx
    image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: ex-1-3-backend
spec:
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: ex-1-3-frontend
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/frontend -n ex-1-3-frontend --timeout=60s
kubectl wait --for=condition=Ready pod/api -n ex-1-3-backend --timeout=60s
```

**Task:** From the frontend pod in ex-1-3-frontend namespace, use nslookup to resolve the api-service that is running in ex-1-3-backend namespace.

**Verification:**

```bash
# Cross-namespace lookup should resolve
kubectl exec -n ex-1-3-frontend frontend -- nslookup api-service.ex-1-3-backend 2>/dev/null | grep -q "Address" && echo "Cross-namespace resolution successful" || echo "Cross-namespace resolution failed"
```

---

## Level 2: Pod DNS and Policies

These exercises explore pod DNS records and how DNS policies affect name resolution.

### Exercise 2.1

**Objective:** Discover and query a pod's DNS record.

**Setup:**

```bash
kubectl create namespace ex-2-1

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: target-pod
  namespace: ex-2-1
spec:
  containers:
  - name: nginx
    image: nginx:1.25
---
apiVersion: v1
kind: Pod
metadata:
  name: lookup-pod
  namespace: ex-2-1
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/target-pod -n ex-2-1 --timeout=60s
kubectl wait --for=condition=Ready pod/lookup-pod -n ex-2-1 --timeout=60s
```

**Task:** Find the IP address of target-pod, construct its DNS name (replacing dots with dashes), and verify the DNS name resolves back to the pod IP.

**Verification:**

```bash
# Get the pod IP
POD_IP=$(kubectl get pod -n ex-2-1 target-pod -o jsonpath='{.status.podIP}')
# Convert dots to dashes
POD_DNS=$(echo $POD_IP | tr '.' '-')
# Full DNS name should resolve
kubectl exec -n ex-2-1 lookup-pod -- nslookup ${POD_DNS}.ex-2-1.pod.cluster.local 2>/dev/null | grep -q "$POD_IP" && echo "Pod DNS resolves correctly" || echo "Pod DNS resolution failed"
```

---

### Exercise 2.2

**Objective:** Compare DNS behavior between ClusterFirst and Default DNS policies.

**Setup:**

```bash
kubectl create namespace ex-2-2

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: webserver
  namespace: ex-2-2
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
  namespace: ex-2-2
spec:
  selector:
    app: web
  ports:
  - port: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-clusterfirst
  namespace: ex-2-2
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
  name: pod-default
  namespace: ex-2-2
spec:
  dnsPolicy: Default
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/pod-clusterfirst -n ex-2-2 --timeout=60s
kubectl wait --for=condition=Ready pod/pod-default -n ex-2-2 --timeout=60s
```

**Task:** Test whether each pod can resolve the web-svc service name. Determine which DNS policy allows service name resolution.

**Verification:**

```bash
# ClusterFirst should resolve service names
kubectl exec -n ex-2-2 pod-clusterfirst -- nslookup web-svc 2>/dev/null | grep -q "Address" && echo "ClusterFirst: service name resolves" || echo "ClusterFirst: service name does NOT resolve"

# Default should NOT resolve service names
kubectl exec -n ex-2-2 pod-default -- nslookup web-svc 2>/dev/null | grep -q "Address" && echo "Default: service name resolves" || echo "Default: service name does NOT resolve"
```

---

### Exercise 2.3

**Objective:** Examine the /etc/resolv.conf in pods with different DNS policies and identify the nameserver and search domains.

**Setup:**

```bash
kubectl create namespace ex-2-3

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: examine-pod
  namespace: ex-2-3
spec:
  dnsPolicy: ClusterFirst
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/examine-pod -n ex-2-3 --timeout=60s
```

**Task:** View the /etc/resolv.conf file in the examine-pod. Identify the nameserver IP, the search domains, and the ndots value.

**Verification:**

```bash
# Should show nameserver pointing to kube-dns (typically 10.96.0.10)
kubectl exec -n ex-2-3 examine-pod -- cat /etc/resolv.conf | grep -q "nameserver" && echo "nameserver line present" || echo "nameserver line missing"

# Should show search domains including the namespace
kubectl exec -n ex-2-3 examine-pod -- cat /etc/resolv.conf | grep -q "ex-2-3.svc.cluster.local" && echo "namespace search domain present" || echo "namespace search domain missing"

# Should show ndots option
kubectl exec -n ex-2-3 examine-pod -- cat /etc/resolv.conf | grep -q "ndots" && echo "ndots option present" || echo "ndots option missing"
```

---

## Level 3: Debugging DNS Queries

These exercises present scenarios where DNS is not working as expected. Diagnose and understand each issue.

### Exercise 3.1

**Objective:** A pod cannot resolve a service name. Find and explain the issue.

**Setup:**

```bash
kubectl create namespace ex-3-1

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: server
  namespace: ex-3-1
  labels:
    app: server
spec:
  containers:
  - name: nginx
    image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: server-svc
  namespace: ex-3-1
spec:
  selector:
    app: server
  ports:
  - port: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: broken-client
  namespace: ex-3-1
spec:
  dnsPolicy: Default
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/broken-client -n ex-3-1 --timeout=60s
```

**Task:** The broken-client pod cannot resolve server-svc. Diagnose why DNS resolution fails.

**Verification:**

```bash
# Demonstrate the failure
kubectl exec -n ex-3-1 broken-client -- nslookup server-svc 2>&1 | head -5

# Check the DNS policy
kubectl get pod -n ex-3-1 broken-client -o jsonpath='{.spec.dnsPolicy}' && echo ""
```

---

### Exercise 3.2

**Objective:** A pod is trying to access a service in another namespace but the lookup fails. Find and explain the issue.

**Setup:**

```bash
kubectl create namespace ex-3-2-app
kubectl create namespace ex-3-2-db

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: mysql
  namespace: ex-3-2-db
  labels:
    app: mysql
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Service
metadata:
  name: mysql-svc
  namespace: ex-3-2-db
spec:
  selector:
    app: mysql
  ports:
  - port: 3306
---
apiVersion: v1
kind: Pod
metadata:
  name: app
  namespace: ex-3-2-app
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/app -n ex-3-2-app --timeout=60s
```

**Task:** From the app pod, nslookup for `mysql-svc` fails. Diagnose why and determine what DNS name would work.

**Verification:**

```bash
# This fails (short name from different namespace)
kubectl exec -n ex-3-2-app app -- nslookup mysql-svc 2>&1 | head -3

# This should work (with namespace included)
kubectl exec -n ex-3-2-app app -- nslookup mysql-svc.ex-3-2-db 2>/dev/null | grep -q "Address" && echo "Cross-namespace lookup works" || echo "Still failing"
```

---

### Exercise 3.3

**Objective:** A pod's DNS query for an external domain is slow because of search domain expansion. Understand the behavior.

**Setup:**

```bash
kubectl create namespace ex-3-3

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: external-test
  namespace: ex-3-3
spec:
  containers:
  - name: alpine
    image: alpine:3.20
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/external-test -n ex-3-3 --timeout=60s
kubectl exec -n ex-3-3 external-test -- apk add --no-cache bind-tools >/dev/null 2>&1
```

**Task:** Use dig to query `example.com` and observe the query behavior. Then query `example.com.` (with trailing dot) and compare.

**Verification:**

```bash
# Query without trailing dot (triggers search domain expansion)
echo "Query without trailing dot:"
kubectl exec -n ex-3-3 external-test -- dig example.com +search +short

# Query with trailing dot (bypasses search domains)
echo "Query with trailing dot:"
kubectl exec -n ex-3-3 external-test -- dig example.com. +short
```

---

## Level 4: DNS Configuration

These exercises involve configuring custom DNS settings for pods.

### Exercise 4.1

**Objective:** Create a pod that uses dnsConfig to add a custom search domain.

**Setup:**

```bash
kubectl create namespace ex-4-1

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: service-a
  namespace: ex-4-1
  labels:
    app: service-a
spec:
  containers:
  - name: nginx
    image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: svc-a
  namespace: ex-4-1
spec:
  selector:
    app: service-a
  ports:
  - port: 80
EOF

kubectl wait --for=condition=Ready pod/service-a -n ex-4-1 --timeout=60s
```

**Task:** Create a pod named custom-search in the ex-4-1 namespace that uses dnsPolicy: ClusterFirst but also adds a custom search domain `internal.company.local` to its DNS configuration using dnsConfig. Verify the custom search domain appears in /etc/resolv.conf.

**Verification:**

```bash
# The pod should exist and be running
kubectl get pod -n ex-4-1 custom-search -o jsonpath='{.status.phase}' | grep -q "Running" && echo "Pod is running" || echo "Pod not running"

# Custom search domain should be present
kubectl exec -n ex-4-1 custom-search -- cat /etc/resolv.conf | grep -q "internal.company.local" && echo "Custom search domain present" || echo "Custom search domain missing"
```

---

### Exercise 4.2

**Objective:** Create a pod with a custom ndots value and understand how it changes DNS behavior.

**Setup:**

```bash
kubectl create namespace ex-4-2

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: webapi
  namespace: ex-4-2
  labels:
    app: webapi
spec:
  containers:
  - name: nginx
    image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: webapi-svc
  namespace: ex-4-2
spec:
  selector:
    app: webapi
  ports:
  - port: 80
EOF

kubectl wait --for=condition=Ready pod/webapi -n ex-4-2 --timeout=60s
```

**Task:** Create a pod named low-ndots in the ex-4-2 namespace with dnsPolicy: ClusterFirst and dnsConfig that sets ndots to 1. Verify the ndots value is 1 in the pod's /etc/resolv.conf and that service resolution still works.

**Verification:**

```bash
# ndots should be 1
kubectl exec -n ex-4-2 low-ndots -- cat /etc/resolv.conf | grep -q "ndots:1" && echo "ndots:1 is set" || echo "ndots:1 not set"

# Service resolution should still work
kubectl exec -n ex-4-2 low-ndots -- nslookup webapi-svc 2>/dev/null | grep -q "Address" && echo "Service resolution works" || echo "Service resolution failed"
```

---

### Exercise 4.3

**Objective:** Create a pod that uses dnsPolicy: None with a complete custom DNS configuration.

**Setup:**

```bash
kubectl create namespace ex-4-3

# Get the kube-dns service IP
KUBE_DNS_IP=$(kubectl get svc -n kube-system kube-dns -o jsonpath='{.spec.clusterIP}')
echo "kube-dns IP: $KUBE_DNS_IP"

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: target-service
  namespace: ex-4-3
  labels:
    app: target
spec:
  containers:
  - name: nginx
    image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: target-svc
  namespace: ex-4-3
spec:
  selector:
    app: target
  ports:
  - port: 80
EOF

kubectl wait --for=condition=Ready pod/target-service -n ex-4-3 --timeout=60s
```

**Task:** Create a pod named fully-custom in ex-4-3 namespace with dnsPolicy: None. Configure dnsConfig to use the kube-dns service IP as nameserver, set search domains for ex-4-3.svc.cluster.local and svc.cluster.local, and set ndots to 3. Verify the pod can resolve target-svc.

**Verification:**

```bash
# Pod should have dnsPolicy None
kubectl get pod -n ex-4-3 fully-custom -o jsonpath='{.spec.dnsPolicy}' | grep -q "None" && echo "dnsPolicy is None" || echo "dnsPolicy is not None"

# DNS resolution should work
kubectl exec -n ex-4-3 fully-custom -- nslookup target-svc 2>/dev/null | grep -q "Address" && echo "Service resolution works" || echo "Service resolution failed"
```

---

## Level 5: Complex Scenarios

These exercises present more challenging real-world scenarios.

### Exercise 5.1

**Objective:** Set up and verify cross-namespace service discovery for a multi-tier application.

**Setup:**

```bash
kubectl create namespace ex-5-1-web
kubectl create namespace ex-5-1-api
kubectl create namespace ex-5-1-db

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: postgres
  namespace: ex-5-1-db
  labels:
    app: postgres
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-svc
  namespace: ex-5-1-db
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
---
apiVersion: v1
kind: Pod
metadata:
  name: api-server
  namespace: ex-5-1-api
  labels:
    app: api
spec:
  containers:
  - name: nginx
    image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: api-svc
  namespace: ex-5-1-api
spec:
  selector:
    app: api
  ports:
  - port: 8080
    targetPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: web-frontend
  namespace: ex-5-1-web
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/web-frontend -n ex-5-1-web --timeout=60s
kubectl wait --for=condition=Ready pod/api-server -n ex-5-1-api --timeout=60s
kubectl wait --for=condition=Ready pod/postgres -n ex-5-1-db --timeout=60s
```

**Task:** From the web-frontend pod, verify DNS resolution works to both api-svc (in ex-5-1-api namespace) and postgres-svc (in ex-5-1-db namespace). Document the correct DNS names to use.

**Verification:**

```bash
# Web can reach API
kubectl exec -n ex-5-1-web web-frontend -- nslookup api-svc.ex-5-1-api 2>/dev/null | grep -q "Address" && echo "Web to API: OK" || echo "Web to API: FAILED"

# Web can reach DB (through API in practice, but DNS should work)
kubectl exec -n ex-5-1-web web-frontend -- nslookup postgres-svc.ex-5-1-db 2>/dev/null | grep -q "Address" && echo "Web to DB: OK" || echo "Web to DB: FAILED"

# API can reach DB
kubectl exec -n ex-5-1-api api-server -- apt-get update > /dev/null 2>&1 || true
kubectl exec -n ex-5-1-api api-server -- nslookup postgres-svc.ex-5-1-db 2>/dev/null | grep -q "Address" && echo "API to DB: OK" || echo "API to DB: FAILED"
```

---

### Exercise 5.2

**Objective:** Debug DNS behavior for a pod using host networking.

**Setup:**

```bash
kubectl create namespace ex-5-2

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: hostnet-wrong
  namespace: ex-5-2
spec:
  hostNetwork: true
  dnsPolicy: ClusterFirst
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: hostnet-correct
  namespace: ex-5-2
spec:
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: service-pod
  namespace: ex-5-2
  labels:
    app: service
spec:
  containers:
  - name: nginx
    image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: test-svc
  namespace: ex-5-2
spec:
  selector:
    app: service
  ports:
  - port: 80
EOF

kubectl wait --for=condition=Ready pod/hostnet-wrong -n ex-5-2 --timeout=60s
kubectl wait --for=condition=Ready pod/hostnet-correct -n ex-5-2 --timeout=60s
```

**Task:** Compare DNS behavior between hostnet-wrong and hostnet-correct pods. Both use host networking, but they have different DNS policies. Determine which one can resolve cluster service names and explain why.

**Verification:**

```bash
# Check which pod can resolve service names
echo "hostnet-wrong (ClusterFirst + hostNetwork):"
kubectl exec -n ex-5-2 hostnet-wrong -- nslookup test-svc.ex-5-2 2>&1 | head -5

echo ""
echo "hostnet-correct (ClusterFirstWithHostNet + hostNetwork):"
kubectl exec -n ex-5-2 hostnet-correct -- nslookup test-svc.ex-5-2 2>&1 | head -5
```

---

### Exercise 5.3

**Objective:** Design and implement a DNS strategy for an application with specific requirements.

**Setup:**

```bash
kubectl create namespace ex-5-3
```

**Task:** Create an application deployment with the following DNS requirements:

1. The application needs to resolve cluster services normally
2. The application also needs to resolve names in a custom domain `internal.corp`
3. The application should have optimized DNS settings with ndots:2 to reduce lookup time for external domains

Create a pod named optimized-app in ex-5-3 namespace that meets these requirements. Use nginx:1.25 as the container image.

**Verification:**

```bash
# Pod should be running
kubectl get pod -n ex-5-3 optimized-app -o jsonpath='{.status.phase}' | grep -q "Running" && echo "Pod is running" || echo "Pod not running"

# Custom search domain should be present
kubectl exec -n ex-5-3 optimized-app -- cat /etc/resolv.conf | grep -q "internal.corp" && echo "Custom domain present" || echo "Custom domain missing"

# ndots should be 2
kubectl exec -n ex-5-3 optimized-app -- cat /etc/resolv.conf | grep -q "ndots:2" && echo "ndots:2 is set" || echo "ndots:2 not set"

# Standard cluster resolution should still work
kubectl exec -n ex-5-3 optimized-app -- nslookup kubernetes.default 2>/dev/null | grep -q "Address" && echo "Cluster DNS works" || echo "Cluster DNS broken"
```

---

## Cleanup

Remove all exercise namespaces:

```bash
kubectl delete namespace ex-1-1 ex-1-2 ex-1-3-frontend ex-1-3-backend
kubectl delete namespace ex-2-1 ex-2-2 ex-2-3
kubectl delete namespace ex-3-1 ex-3-2-app ex-3-2-db ex-3-3
kubectl delete namespace ex-4-1 ex-4-2 ex-4-3
kubectl delete namespace ex-5-1-web ex-5-1-api ex-5-1-db ex-5-2 ex-5-3
```

---

## Key Takeaways

1. **Service DNS format** follows the pattern `<service>.<namespace>.svc.cluster.local`. Short names work within the same namespace due to search domains.

2. **Cross-namespace DNS** requires at least the namespace in the DNS name. The short service name alone only works within the same namespace.

3. **DNS policies** control how pods resolve names. ClusterFirst (default) uses cluster DNS. Default uses node DNS (no cluster names). None requires explicit dnsConfig.

4. **Host network pods** require dnsPolicy: ClusterFirstWithHostNet to use cluster DNS. Using ClusterFirst with hostNetwork results in node DNS behavior.

5. **The ndots option** determines when search domains are applied. Lower values reduce lookups for external domains but may require FQDNs for some cluster names.

6. **Pod DNS records** exist but are rarely used directly. Service DNS is the standard for pod-to-pod communication via services.
