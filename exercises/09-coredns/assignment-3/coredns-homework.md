# CoreDNS Homework: DNS Troubleshooting

Work through these 15 exercises to build practical DNS troubleshooting skills. Complete the tutorial (coredns-tutorial.md) before starting these exercises. Each level increases in complexity, building on concepts from previous levels.

---

## Level 1: Basic DNS Diagnostics

These exercises focus on fundamental diagnostic techniques.

### Exercise 1.1

**Objective:** Test DNS resolution from a pod and verify it works correctly.

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
  name: tester
  namespace: ex-1-1
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/tester -n ex-1-1 --timeout=60s
kubectl wait --for=condition=Ready pod/backend -n ex-1-1 --timeout=60s
```

**Task:** From the tester pod, verify that DNS resolution works for the backend-svc service. Test both the short name and the FQDN.

**Verification:**

```bash
# Short name should resolve
kubectl exec -n ex-1-1 tester -- nslookup backend-svc 2>/dev/null | grep -q "Address" && echo "Short name: OK" || echo "Short name: FAILED"

# FQDN should resolve
kubectl exec -n ex-1-1 tester -- nslookup backend-svc.ex-1-1.svc.cluster.local 2>/dev/null | grep -q "Address" && echo "FQDN: OK" || echo "FQDN: FAILED"
```

---

### Exercise 1.2

**Objective:** Compare /etc/resolv.conf between pods with different DNS policies.

**Setup:**

```bash
kubectl create namespace ex-1-2

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: pod-clusterfirst
  namespace: ex-1-2
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
  namespace: ex-1-2
spec:
  dnsPolicy: Default
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/pod-clusterfirst -n ex-1-2 --timeout=60s
kubectl wait --for=condition=Ready pod/pod-default -n ex-1-2 --timeout=60s
```

**Task:** View the /etc/resolv.conf for each pod and identify the differences. Determine which pod can resolve cluster service names.

**Verification:**

```bash
# Compare resolv.conf
echo "ClusterFirst pod:"
kubectl exec -n ex-1-2 pod-clusterfirst -- cat /etc/resolv.conf

echo ""
echo "Default pod:"
kubectl exec -n ex-1-2 pod-default -- cat /etc/resolv.conf
```

---

### Exercise 1.3

**Objective:** Verify CoreDNS service availability.

**Setup:**

```bash
kubectl create namespace ex-1-3
```

**Task:** Check that the kube-dns service exists, has a ClusterIP, and has healthy endpoints. Verify that CoreDNS pods are running.

**Verification:**

```bash
# Service should exist with ClusterIP
kubectl get svc kube-dns -n kube-system -o wide

# Endpoints should list CoreDNS pod IPs
kubectl get endpoints kube-dns -n kube-system

# CoreDNS pods should be running
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

---

## Level 2: CoreDNS Health

These exercises focus on checking CoreDNS status and logs.

### Exercise 2.1

**Objective:** Check CoreDNS pod status and readiness.

**Setup:**

```bash
kubectl create namespace ex-2-1
```

**Task:** Examine the CoreDNS Deployment and pods. Check that pods are Running and Ready. Identify how the readiness probe is configured.

**Verification:**

```bash
# Pods should be Running and Ready
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check readiness probe config
kubectl get deployment coredns -n kube-system -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}' | python3 -m json.tool 2>/dev/null || kubectl get deployment coredns -n kube-system -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}'
```

---

### Exercise 2.2

**Objective:** View and interpret CoreDNS logs.

**Setup:**

```bash
kubectl create namespace ex-2-2

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: query-generator
  namespace: ex-2-2
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/query-generator -n ex-2-2 --timeout=60s
```

**Task:** Generate some DNS queries including one that will fail. Then view CoreDNS logs to see if any activity is recorded.

**Verification:**

```bash
# Generate successful query
kubectl exec -n ex-2-2 query-generator -- nslookup kubernetes.default

# Generate failing query
kubectl exec -n ex-2-2 query-generator -- nslookup nonexistent.invalid 2>/dev/null || true

# View CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=30
```

---

### Exercise 2.3

**Objective:** Verify CoreDNS endpoints are healthy.

**Setup:**

```bash
kubectl create namespace ex-2-3
```

**Task:** Check that the kube-dns service has endpoints pointing to running CoreDNS pods. Verify the endpoint IPs match the CoreDNS pod IPs.

**Verification:**

```bash
# Get endpoints
ENDPOINTS=$(kubectl get endpoints kube-dns -n kube-system -o jsonpath='{.subsets[0].addresses[*].ip}')
echo "Endpoints: $ENDPOINTS"

# Get pod IPs
POD_IPS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[*].status.podIP}')
echo "Pod IPs: $POD_IPS"

# They should match
echo ""
echo "Endpoints and Pod IPs should match"
```

---

## Level 3: Debugging DNS Failures

These exercises present broken configurations to diagnose.

### Exercise 3.1

**Objective:** A pod cannot resolve any DNS names. Diagnose and fix the issue.

**Setup:**

```bash
kubectl create namespace ex-3-1

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: webserver
  namespace: ex-3-1
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
  namespace: ex-3-1
spec:
  selector:
    app: web
  ports:
  - port: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: broken-client
  namespace: ex-3-1
spec:
  dnsPolicy: None
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/broken-client -n ex-3-1 --timeout=60s
```

**Task:** The broken-client pod cannot resolve DNS names. Diagnose the issue.

**Verification:**

```bash
# Demonstrate the failure
kubectl exec -n ex-3-1 broken-client -- nslookup web-svc 2>&1 | head -5

# Check DNS policy
kubectl get pod broken-client -n ex-3-1 -o jsonpath='{.spec.dnsPolicy}' && echo ""

# Check resolv.conf
kubectl exec -n ex-3-1 broken-client -- cat /etc/resolv.conf 2>&1
```

---

### Exercise 3.2

**Objective:** A pod's DNS lookups time out, but other pods work fine. Diagnose the issue.

**Setup:**

```bash
kubectl create namespace ex-3-2

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: app
  namespace: ex-3-2
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
  name: app-svc
  namespace: ex-3-2
spec:
  selector:
    app: target
  ports:
  - port: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: isolated-pod
  namespace: ex-3-2
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
  namespace: ex-3-2
spec:
  podSelector:
    matchLabels: {}
  policyTypes:
  - Egress
EOF

kubectl wait --for=condition=Ready pod/isolated-pod -n ex-3-2 --timeout=60s
```

**Task:** The isolated-pod cannot resolve DNS (timeout). Diagnose why.

**Verification:**

```bash
# DNS lookup times out
timeout 5 kubectl exec -n ex-3-2 isolated-pod -- nslookup app-svc 2>&1 || echo "DNS lookup timed out"

# Check Network Policies
kubectl get networkpolicy -n ex-3-2
kubectl describe networkpolicy deny-all-egress -n ex-3-2
```

---

### Exercise 3.3

**Objective:** A service name lookup returns NXDOMAIN even though the service exists. Diagnose the issue.

**Setup:**

```bash
kubectl create namespace ex-3-3-frontend
kubectl create namespace ex-3-3-backend

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: api
  namespace: ex-3-3-backend
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
  namespace: ex-3-3-backend
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
  name: frontend
  namespace: ex-3-3-frontend
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/frontend -n ex-3-3-frontend --timeout=60s
```

**Task:** From the frontend pod, looking up `api-service` returns NXDOMAIN, but the service exists. Diagnose why.

**Verification:**

```bash
# This fails
kubectl exec -n ex-3-3-frontend frontend -- nslookup api-service 2>&1 | head -5

# Service exists in backend namespace
kubectl get svc api-service -n ex-3-3-backend
```

---

## Level 4: Complex DNS Issues

These exercises involve more complex scenarios.

### Exercise 4.1

**Objective:** Debug a Network Policy that is blocking DNS.

**Setup:**

```bash
kubectl create namespace ex-4-1

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: server
  namespace: ex-4-1
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
  namespace: ex-4-1
spec:
  selector:
    app: server
  ports:
  - port: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: ex-4-1
  labels:
    role: client
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: client-egress
  namespace: ex-4-1
spec:
  podSelector:
    matchLabels:
      role: client
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: server
    ports:
    - port: 80
EOF

kubectl wait --for=condition=Ready pod/client -n ex-4-1 --timeout=60s
```

**Task:** The client pod should be able to reach the server, but DNS lookups fail. Identify what is missing from the Network Policy and describe the fix.

**Verification:**

```bash
# DNS fails
timeout 5 kubectl exec -n ex-4-1 client -- nslookup server-svc 2>&1 || echo "DNS lookup timed out"

# Examine the policy
kubectl describe networkpolicy client-egress -n ex-4-1
```

---

### Exercise 4.2

**Objective:** Diagnose a caching-related DNS issue.

**Setup:**

```bash
kubectl create namespace ex-4-2

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: cache-tester
  namespace: ex-4-2
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/cache-tester -n ex-4-2 --timeout=60s
```

**Task:** You need to create a new service and have it resolve immediately. Understand how DNS caching might affect this and how to work around it.

1. First, attempt to look up `new-service` (which does not exist yet)
2. Create the service
3. Try to look it up again immediately
4. Understand the caching behavior

**Verification:**

```bash
# Try to look up non-existent service
kubectl exec -n ex-4-2 cache-tester -- nslookup new-service 2>&1 || true

# Create the service
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: new-pod
  namespace: ex-4-2
  labels:
    app: new
spec:
  containers:
  - name: nginx
    image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: new-service
  namespace: ex-4-2
spec:
  selector:
    app: new
  ports:
  - port: 80
EOF

kubectl wait --for=condition=Ready pod/new-pod -n ex-4-2 --timeout=60s

# Try immediately
kubectl exec -n ex-4-2 cache-tester -- nslookup new-service 2>&1 | head -5

# If it fails, wait and try again
sleep 35
kubectl exec -n ex-4-2 cache-tester -- nslookup new-service 2>&1 | head -5
```

---

### Exercise 4.3

**Objective:** Troubleshoot cross-namespace DNS with multiple potential issues.

**Setup:**

```bash
kubectl create namespace ex-4-3-app
kubectl create namespace ex-4-3-db

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: mysql
  namespace: ex-4-3-db
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
  name: mysql-service
  namespace: ex-4-3-db
spec:
  selector:
    app: mysql
  ports:
  - port: 3306
---
apiVersion: v1
kind: Pod
metadata:
  name: webapp
  namespace: ex-4-3-app
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/webapp -n ex-4-3-app --timeout=60s
```

**Task:** From the webapp pod, verify that you can resolve the mysql-service in the ex-4-3-db namespace. Test different DNS name formats and determine which ones work.

**Verification:**

```bash
# Short name (will fail - wrong namespace)
kubectl exec -n ex-4-3-app webapp -- nslookup mysql-service 2>&1 | head -3

# With namespace (should work)
kubectl exec -n ex-4-3-app webapp -- nslookup mysql-service.ex-4-3-db 2>&1 | head -5

# FQDN (should work)
kubectl exec -n ex-4-3-app webapp -- nslookup mysql-service.ex-4-3-db.svc.cluster.local 2>&1 | head -5
```

---

## Level 5: Multi-Factor Failures

These exercises present complex scenarios with multiple issues.

### Exercise 5.1

**Objective:** Debug a cluster with multiple DNS problems.

**Setup:**

```bash
kubectl create namespace ex-5-1

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: service-a
  namespace: ex-5-1
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
  name: service-a
  namespace: ex-5-1
spec:
  selector:
    app: service-a
  ports:
  - port: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: problem-pod
  namespace: ex-5-1
spec:
  dnsPolicy: Default
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: normal-pod
  namespace: ex-5-1
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/problem-pod -n ex-5-1 --timeout=60s
kubectl wait --for=condition=Ready pod/normal-pod -n ex-5-1 --timeout=60s
```

**Task:** The problem-pod cannot resolve service-a, but normal-pod can. Diagnose the issue by comparing the two pods.

**Verification:**

```bash
# problem-pod fails
kubectl exec -n ex-5-1 problem-pod -- nslookup service-a 2>&1 | head -5

# normal-pod works
kubectl exec -n ex-5-1 normal-pod -- nslookup service-a 2>&1 | head -5

# Compare resolv.conf
echo "problem-pod resolv.conf:"
kubectl exec -n ex-5-1 problem-pod -- cat /etc/resolv.conf

echo ""
echo "normal-pod resolv.conf:"
kubectl exec -n ex-5-1 normal-pod -- cat /etc/resolv.conf
```

---

### Exercise 5.2

**Objective:** Diagnose intermittent DNS failures.

**Setup:**

```bash
kubectl create namespace ex-5-2

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: target
  namespace: ex-5-2
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
  namespace: ex-5-2
spec:
  selector:
    app: target
  ports:
  - port: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: tester
  namespace: ex-5-2
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/tester -n ex-5-2 --timeout=60s
```

**Task:** Simulate investigating intermittent DNS issues. Run multiple DNS queries and check if any fail. Also verify CoreDNS has multiple healthy replicas for high availability.

**Verification:**

```bash
# Run multiple queries
for i in 1 2 3 4 5; do
  kubectl exec -n ex-5-2 tester -- nslookup target-svc 2>/dev/null | grep -q "Address" && echo "Query $i: OK" || echo "Query $i: FAILED"
done

# Check CoreDNS replicas
kubectl get deployment coredns -n kube-system -o jsonpath='{.status.readyReplicas}' && echo " ready replicas"

# Check pods are on different nodes (for HA)
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
```

---

### Exercise 5.3

**Objective:** Create a DNS troubleshooting runbook by demonstrating the diagnostic steps.

**Setup:**

```bash
kubectl create namespace ex-5-3

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: ex-5-3
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/test-pod -n ex-5-3 --timeout=60s
```

**Task:** Document a DNS troubleshooting runbook by running through all the diagnostic steps in order:

1. Check CoreDNS pods are running
2. Check kube-dns service and endpoints
3. Check pod's DNS configuration
4. Test DNS from the pod
5. Check for Network Policies
6. View CoreDNS logs

**Verification:**

```bash
echo "=== Step 1: Check CoreDNS pods ==="
kubectl get pods -n kube-system -l k8s-app=kube-dns

echo ""
echo "=== Step 2: Check kube-dns service and endpoints ==="
kubectl get svc kube-dns -n kube-system
kubectl get endpoints kube-dns -n kube-system

echo ""
echo "=== Step 3: Check pod's DNS configuration ==="
kubectl exec -n ex-5-3 test-pod -- cat /etc/resolv.conf

echo ""
echo "=== Step 4: Test DNS from the pod ==="
kubectl exec -n ex-5-3 test-pod -- nslookup kubernetes.default

echo ""
echo "=== Step 5: Check for Network Policies ==="
kubectl get networkpolicy -n ex-5-3

echo ""
echo "=== Step 6: View CoreDNS logs ==="
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=10
```

---

## Cleanup

Remove all exercise namespaces:

```bash
kubectl delete namespace ex-1-1 ex-1-2 ex-1-3
kubectl delete namespace ex-2-1 ex-2-2 ex-2-3
kubectl delete namespace ex-3-1 ex-3-2 ex-3-3-frontend ex-3-3-backend
kubectl delete namespace ex-4-1 ex-4-2 ex-4-3-app ex-4-3-db
kubectl delete namespace ex-5-1 ex-5-2 ex-5-3
```

---

## Key Takeaways

1. **Always start by checking CoreDNS** is running. If CoreDNS pods are not healthy, nothing else matters.

2. **Check the pod's resolv.conf** to verify it uses the kube-dns ClusterIP. Wrong dnsPolicy causes many issues.

3. **Network Policies can block DNS.** A default deny egress policy without a DNS exception breaks service discovery.

4. **Cross-namespace lookups need namespace qualifiers.** Short names only work within the same namespace.

5. **DNS caching can mask changes.** Negative cache (NXDOMAIN) responses are cached too. Wait for cache TTL or use FQDN with trailing dot.

6. **Compare working and broken pods** to isolate pod-specific issues like wrong dnsPolicy or Network Policies.

7. **CoreDNS logs show errors** but not successful queries by default. Enable the log plugin for detailed debugging.
