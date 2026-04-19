# Network Policies Homework Answers: Network Policy Debugging

Complete solutions for all 15 exercises with explanations.

---

## Exercise 1.1 Solution

**Task:** Test connectivity before and after applying a deny policy.

**Result:** Before policy, traffic is allowed (no policies = allow all). After applying deny policy with no ingress rules, traffic is blocked.

**Explanation:** When no NetworkPolicy selects a pod, all traffic is allowed. Once a policy selects the pod, only explicitly allowed traffic is permitted.

---

## Exercise 1.2 Solution

**Task:** Identify why traffic is blocked.

**Diagnosis:**
```bash
kubectl describe networkpolicy api-policy -n ex-1-2
# Allows from: role=frontend

kubectl get pod web -n ex-1-2 --show-labels
# Labels: app=web (NOT role=frontend)
```

**Root Cause:** Policy allows from `role=frontend`, but the web pod has `app=web`. The labels do not match.

**Fix:** Either add `role=frontend` label to web pod or change policy to allow `app=web`.

---

## Exercise 1.3 Solution

**Task:** Diagnose why policy does not protect the database.

**Diagnosis:**
```bash
kubectl get pod database -n ex-1-3 --show-labels
# Labels: app=postgresql

kubectl describe networkpolicy protect-database -n ex-1-3
# PodSelector: app=database
```

**Root Cause:** Policy selects `app=database`, but pod has `app=postgresql`. The policy does not match the pod.

**Fix:** Change policy podSelector to `app: postgresql`.

---

## Exercise 2.1 Solution

**Task:** Verify DNS works but other egress is blocked.

**Result:** DNS queries succeed because the policy allows egress to kube-system on UDP 53. Other egress (like HTTP to example.com) is blocked because there is no matching egress rule.

---

## Exercise 2.2 Solution

**Task:** Verify service access through policy.

**Result:** Frontend can access backend via service name. The policy allows ingress from `app=frontend` on port 80, and DNS is not restricted (no egress policy on frontend).

---

## Exercise 2.3 Solution

**Task:** Verify cross-namespace access.

**Result:** Traffic is allowed because:
1. The ex-4-3-frontend namespace has `tier=frontend` label
2. The policy allows from namespaces with `tier: frontend`

---

## Exercise 3.1 Solution

**Task:** Diagnose selector mismatch.

**Diagnosis:**
```bash
kubectl get pod client -n ex-3-1 --show-labels
# Labels: role=client

kubectl describe networkpolicy server-policy -n ex-3-1
# Allows from: role=frontend
```

**Root Cause:** Policy allows `role=frontend`, but client has `role=client`.

**Fix:** Change policy to allow `role=client` or add `role=frontend` label to client.

---

## Exercise 3.2 Solution

**Task:** Diagnose DNS blocked.

**Root Cause:** The egress policy only allows traffic to pods with `app=server`. DNS queries need to reach kube-system namespace (kube-dns), which is not allowed.

**Fix:** Add DNS egress rule:
```yaml
egress:
- to:
  - podSelector:
      matchLabels:
        app: server
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

**Task:** Diagnose cross-namespace failure.

**Diagnosis:**
```bash
kubectl get namespace ex-3-3-monitoring --show-labels
# Missing: purpose=monitoring
```

**Root Cause:** The ex-3-3-monitoring namespace does not have the `purpose=monitoring` label that the policy requires.

**Fix:**
```bash
kubectl label namespace ex-3-3-monitoring purpose=monitoring
```

---

## Exercise 4.1 Solution

**Task:** Determine if traffic is allowed with multiple policies.

**Result:** Traffic IS allowed.

**Analysis:**
- secure-app has labels: `app=secure`, `env=prod`
- deny-by-app selects `app=secure`: no ingress rules
- allow-testers selects `env=prod`: allows from `role=tester`
- test-client has `role=tester`
- Policies are ADDITIVE, so allow-testers permits the traffic

---

## Exercise 4.2 Solution

**Task:** Find the permissive policy.

**Root Cause:** The policy uses `podSelector: {}` in the from clause, which matches ALL pods in the namespace:

```yaml
ingress:
- from:
  - podSelector: {}  # Matches all pods!
```

**Fix:** Specify the actual label selector:
```yaml
ingress:
- from:
  - podSelector:
      matchLabels:
        app: webapp
```

---

## Exercise 4.3 Solution

**Task:** Verify policy chain.

**Result:** Both connections work.

**Analysis:**
- web->api: ex-4-3-web has `tier=web`, api-policy allows from `tier: web`
- api->db: ex-4-3-api has `tier=api`, db-policy allows from `tier: api`

---

## Exercise 5.1 Solution

**Task:** Debug multiple policy issues.

**Issues Found:**

1. **Selector mismatch:** web-to-api policy selects `app=api`, but pod has `app=api-server`
2. **DNS blocked:** default-deny blocks all egress, including DNS
3. **Web egress blocked:** No egress rule for web pod

**Fixes:**

1. Change selector to `app: api-server`
2. Add DNS egress to default-deny policy
3. Add egress rule for web to reach api

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: ex-5-1
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-egress
  namespace: ex-5-1
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: api-server
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-ingress
  namespace: ex-5-1
spec:
  podSelector:
    matchLabels:
      app: api-server
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: web
```

---

## Exercise 5.2 Solution

**Task:** Fix service discovery failure.

**Root Cause:** Frontend egress policy does not allow DNS.

**Fix:** Add DNS egress rule:

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-egress
  namespace: ex-5-2
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - port: 80
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
EOF
```

---

## Exercise 5.3 Solution

**Task:** Document troubleshooting runbook.

**Complete Runbook:**

```bash
# Step 1: List all policies in namespace
kubectl get networkpolicy -n <namespace>

# Step 2: Get pod labels
kubectl get pods -n <namespace> --show-labels

# Step 3: Get namespace labels
kubectl get namespace <namespace> --show-labels

# Step 4: For each policy, check podSelector match
kubectl describe networkpolicy <policy> -n <namespace>

# Step 5: Test connectivity by IP
kubectl exec -n <ns> <client> -- wget -qO- --timeout=2 http://<server-ip>

# Step 6: Test DNS
kubectl exec -n <ns> <client> -- nslookup <service-name>

# Step 7: For cross-namespace, check both namespaces
kubectl get namespace <source-ns> --show-labels
kubectl get networkpolicy -n <dest-ns>

# Step 8: Compare working and broken scenarios
# What is different between a working pod and broken pod?
```

---

## Common Mistakes

### Forgetting to Test from Correct Source Pod

**Mistake:** Testing from a different pod than the one experiencing issues.

**Fix:** Always test from the actual affected pod.

### Missing DNS Egress in Default Deny

**Mistake:** Creating egress deny without DNS exception.

**Fix:** Always add UDP 53 egress to kube-system.

### Not Understanding Additive Behavior

**Mistake:** Expecting deny policy to override allow policy.

**Fix:** Policies are additive. If ANY policy allows, traffic is allowed.

### Checking Wrong Policy for Namespace

**Mistake:** Looking at policies in wrong namespace.

**Fix:** Ingress policies are in the destination namespace. Egress policies are in the source namespace.

### CNI Not Supporting NetworkPolicy

**Mistake:** Testing on cluster without Calico/Cilium.

**Fix:** Verify CNI supports NetworkPolicy: `kubectl get pods -n kube-system -l k8s-app=calico-node`

---

## Policy Debugging Flowchart

```
Traffic Blocked?
       |
       v
List policies: kubectl get networkpolicy -n <ns>
       |
       v
Any policies select target pod?
       |
  +----+----+
  |         |
 No        Yes
  |         |
  v         v
No policy  Check from/to selector
= allow    matches source
all        |
           v
       Match?
           |
      +----+----+
      |         |
     No        Yes
      |         |
      v         v
  Blocked   Check port match
  (wrong    |
  selector)  v
          Port match?
             |
        +----+----+
        |         |
       No        Yes
        |         |
        v         v
    Blocked   Should be allowed!
    (wrong    Check for other
    port)     blocking policies
```

---

## Verification Commands Cheat Sheet

| Task | Command |
|------|---------|
| List policies | `kubectl get networkpolicy -n <ns>` |
| Describe policy | `kubectl describe networkpolicy <name> -n <ns>` |
| Get pod labels | `kubectl get pod <name> --show-labels` |
| Get ns labels | `kubectl get namespace <name> --show-labels` |
| Add ns label | `kubectl label namespace <name> <key>=<value>` |
| Test HTTP | `kubectl exec -n <ns> <pod> -- wget -qO- --timeout=2 http://<ip>` |
| Test DNS | `kubectl exec -n <ns> <pod> -- nslookup <name>` |
| Test with timeout | `timeout 3 kubectl exec ...` |
