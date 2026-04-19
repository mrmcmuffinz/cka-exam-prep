# Network Policies Homework Answers: Advanced Selectors and Isolation

Complete solutions for all 15 exercises with explanations.

---

## Exercise 1.1 Solution

**Task:** Allow ingress only from namespaces labeled `purpose=monitoring`.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: ex-1-1-app
spec:
  podSelector:
    matchLabels:
      app: webapp
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          purpose: monitoring
EOF
```

**Explanation:** The namespaceSelector matches namespaces with `purpose=monitoring`. Only pods in those namespaces can reach the app pod. The attacker pod is in ex-1-1-app, which does not have this label.

---

## Exercise 1.2 Solution

**Task:** Restrict egress to backend namespace with DNS access.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-egress
  namespace: ex-1-2-frontend
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          tier: backend
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
    ports:
    - protocol: UDP
      port: 53
EOF
```

**Explanation:** Two egress rules: one allows traffic to namespaces with `tier=backend`, another allows DNS to kube-system.

---

## Exercise 1.3 Solution

**Task:** Allow ingress from specific namespace using built-in name label.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-dev
  namespace: ex-1-3-prod
spec:
  podSelector:
    matchLabels:
      app: service
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ex-1-3-dev
EOF
```

**Explanation:** The `kubernetes.io/metadata.name` label is automatically added to every namespace with the namespace name as value.

---

## Exercise 2.1 Solution

**Task:** Combine pod and namespace selectors (AND).

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: combined-access
  namespace: ex-2-1-target
spec:
  podSelector:
    matchLabels:
      app: server
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          env: trusted
      podSelector:
        matchLabels:
          role: trusted
EOF
```

**Explanation:** Both selectors are in the same from entry (no dash between them), so they are AND-ed. Only pods matching `role=trusted` in namespaces matching `env=trusted` are allowed.

---

## Exercise 2.2 Solution

**Task:** Configure ipBlock for 10.0.0.0/8.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-internal
  namespace: ex-2-2
spec:
  podSelector:
    matchLabels:
      app: external
  policyTypes:
  - Ingress
  ingress:
  - from:
    - ipBlock:
        cidr: 10.0.0.0/8
EOF
```

---

## Exercise 2.3 Solution

**Task:** Configure ipBlock with except.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-with-exception
  namespace: ex-2-3
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - ipBlock:
        cidr: 192.168.0.0/16
        except:
        - 192.168.100.0/24
EOF
```

---

## Exercise 3.1 Solution

**Task:** Diagnose cross-namespace policy failure.

**Diagnosis:**

```bash
kubectl get namespace ex-3-1-client --show-labels
```

**Root Cause:** The ex-3-1-client namespace does not have the `role=client` label that the policy requires.

**Fix:**

```bash
kubectl label namespace ex-3-1-client role=client
```

---

## Exercise 3.2 Solution

**Task:** Understand AND semantics.

**Analysis:**

The policy has:
```yaml
- from:
  - namespaceSelector:
      matchLabels:
        team: alpha
    podSelector:
      matchLabels:
        role: tester
```

This is AND: namespace must have `team=alpha` AND pod must have `role=tester`.

- **client-alpha** (ns1, team=alpha, role=tester): ALLOWED (both match)
- **client-beta** (ns2, team=beta, role=tester): BLOCKED (namespace does not match)

---

## Exercise 3.3 Solution

**Task:** Diagnose ipBlock issue.

**Problem:** The except clause `10.0.0.0/8` is the same as the cidr `10.0.0.0/8`, so all IPs are excluded.

**Fix:** Remove or narrow the except clause:

```yaml
ipBlock:
  cidr: 10.0.0.0/8
  # Remove except, or use a smaller range
```

---

## Exercise 4.1 Solution

**Task:** Default deny with DNS exception.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: ex-4-1
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
EOF
```

---

## Exercise 4.2 Solution

**Task:** Namespace isolation with internal communication.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: namespace-isolation
  namespace: ex-4-2
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector: {}
  egress:
  - to:
    - podSelector: {}
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

## Exercise 4.3 Solution

**Task:** Least-privilege three-tier access.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: ex-4-3
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
  name: frontend-egress
  namespace: ex-4-3
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: backend
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-ingress
  namespace: ex-4-3
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: frontend
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-egress
  namespace: ex-4-3
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: database
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-ingress
  namespace: ex-4-3
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: backend
EOF
```

---

## Exercise 5.1 Solution

**Task:** Multi-namespace isolation.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: ex-5-1-api
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-web
  namespace: ex-5-1-api
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tier: web
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: ex-5-1-db
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-api
  namespace: ex-5-1-db
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tier: api
EOF
```

---

## Exercise 5.2 Solution

**Task:** Understand additive policy behavior.

**Analysis:**

Two policies match secure-server:
1. `policy-a` (app=server): Ingress policyType with no rules = deny all
2. `policy-b` (security=high): Allows ingress from all pods in namespace

**Result:** Client CAN reach server because policies are additive. policy-b allows ingress, so traffic is allowed even though policy-a has no rules.

---

## Exercise 5.3 Solution

**Task:** Zero-trust strategy implementation.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: ex-5-3
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
  name: web-ingress
  namespace: ex-5-3
spec:
  podSelector:
    matchLabels:
      tier: web
  policyTypes:
  - Ingress
  ingress:
  - {}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-egress
  namespace: ex-5-3
spec:
  podSelector:
    matchLabels:
      tier: web
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: api
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-ingress
  namespace: ex-5-3
spec:
  podSelector:
    matchLabels:
      tier: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: web
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-egress
  namespace: ex-5-3
spec:
  podSelector:
    matchLabels:
      tier: api
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          tier: db
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-ingress
  namespace: ex-5-3
spec:
  podSelector:
    matchLabels:
      tier: db
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: api
EOF
```

---

## Common Mistakes

### Namespace Missing Required Labels

**Mistake:** Using namespaceSelector without labeling the namespace.

**Fix:** `kubectl label namespace <name> <key>=<value>`

### Confusing AND vs OR in Selectors

**Mistake:** Putting selectors on same line expecting OR.

**Fix:** Same entry = AND. New dash = OR.

### ipBlock Not Allowing Expected CIDR

**Mistake:** except range overlaps with or equals cidr.

**Fix:** Ensure except is a proper subset of cidr.

### Default Deny Breaking Cluster DNS

**Mistake:** Egress deny without DNS exception.

**Fix:** Always add UDP 53 egress to kube-system.

### Multiple Policies Being Additive

**Mistake:** Expecting one policy to deny what another allows.

**Fix:** Policies are additive. Design with this in mind.

---

## Advanced Selector Cheat Sheet

| Task | YAML |
|------|------|
| Allow from namespace | `namespaceSelector: { matchLabels: {key: value} }` |
| Select by namespace name | `kubernetes.io/metadata.name: <name>` |
| AND selectors | Same entry, no dash between |
| OR selectors | Separate entries with dash |
| Allow from CIDR | `ipBlock: { cidr: x.x.x.x/y }` |
| Except CIDR | `ipBlock: { cidr: x.x.x.x/y, except: [a.a.a.a/b] }` |
| Default deny all | `podSelector: {}` with empty rules |
| DNS exception | `namespaceSelector: kube-system, ports: UDP 53` |
