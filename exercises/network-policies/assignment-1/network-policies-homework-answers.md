# Network Policies Homework Answers: NetworkPolicy Fundamentals

Complete solutions for all 15 exercises with explanations.

---

## Exercise 1.1 Solution

**Task:** Create a NetworkPolicy allowing ingress only from pods with `role=allowed`.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-allowed
  namespace: ex-1-1
spec:
  podSelector:
    matchLabels:
      app: server
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: allowed
EOF
```

**Explanation:** The policy selects the server pod and only allows ingress from pods with `role=allowed`. The allowed-client has this label and can connect. The blocked-client has `role=blocked` and is denied.

---

## Exercise 1.2 Solution

**Task:** Create a NetworkPolicy restricting egress to only target-a.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
  namespace: ex-1-2
spec:
  podSelector:
    matchLabels:
      app: restricted
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: target-a
EOF
```

**Explanation:** The policy selects the restricted-pod and only allows egress to pods with `app=target-a`. Traffic to target-b is blocked because it has `app=target-b`.

---

## Exercise 1.3 Solution

**Task:** Apply a deny-all ingress policy to webserver.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: ex-1-3
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
EOF
```

**Explanation:** Including Ingress in policyTypes without defining any ingress rules denies all ingress traffic. Before the policy, tester can reach webserver. After the policy, all ingress is blocked.

---

## Exercise 2.1 Solution

**Task:** Create a policy that matches pods with both `app=api` AND `env=prod`.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: protect-prod
  namespace: ex-2-1
spec:
  podSelector:
    matchLabels:
      app: api
      env: prod
  policyTypes:
  - Ingress
EOF
```

**Explanation:** The podSelector with multiple labels uses AND logic. Only pods with BOTH `app=api` AND `env=prod` are selected. The api-dev pod has `env=dev`, so it is not selected and allows all traffic. The api-prod pod matches and has all ingress denied.

---

## Exercise 2.2 Solution

**Task:** Create a policy with multiple from entries (OR logic).

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-access
  namespace: ex-2-2
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          tier: web
    - podSelector:
        matchLabels:
          tier: admin
EOF
```

**Explanation:** Multiple entries in the `from` array are OR-ed together. Traffic is allowed from pods matching `tier=web` OR `tier=admin`. The other-client has `tier=other`, which matches neither, so it is blocked.

---

## Exercise 2.3 Solution

**Task:** Create a policy allowing only TCP port 80.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: http-only
  namespace: ex-2-3
spec:
  podSelector:
    matchLabels:
      app: server
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 80
EOF
```

**Explanation:** The ports field restricts traffic to TCP port 80 only. Traffic to port 6379 (Redis) is denied because it is not in the allowed ports list. The empty podSelector in `from` allows any pod in the namespace.

---

## Exercise 3.1 Solution

**Task:** Diagnose why frontend cannot reach api-server.

**Diagnosis:**

```bash
kubectl get pod frontend -n ex-3-1 --show-labels
# Labels: app=frontend

kubectl describe networkpolicy api-policy -n ex-3-1
# Allows from: app=web
```

**Root Cause:** The policy allows ingress from pods with `app=web`, but the frontend pod has `app=frontend`. The labels do not match.

**Fix:** Either change the policy to allow `app=frontend`:

```yaml
ingress:
- from:
  - podSelector:
      matchLabels:
        app: frontend
```

Or add the `app=web` label to the frontend pod:

```bash
kubectl label pod frontend -n ex-3-1 app=web
```

---

## Exercise 3.2 Solution

**Task:** Diagnose why the policy is not protecting the database pod.

**Diagnosis:**

```bash
kubectl get pod database -n ex-3-2 --show-labels
# Labels: app=mysql, tier=database

kubectl describe networkpolicy db-policy -n ex-3-2
# PodSelector: app=database
```

**Root Cause:** The policy selects pods with `app=database`, but the database pod has `app=mysql`. The podSelector does not match, so the policy has no effect.

**Fix:** Change the policy podSelector to match the actual label:

```yaml
spec:
  podSelector:
    matchLabels:
      app: mysql
```

---

## Exercise 3.3 Solution

**Task:** Diagnose the port mismatch issue.

**Diagnosis:**

```bash
kubectl describe networkpolicy web-policy -n ex-3-3
# Allows port: 8080/TCP
```

**Root Cause:** The policy allows traffic on port 8080, but the webserver listens on port 80. The port in the policy does not match the actual service port.

**Fix:** Change the policy to allow port 80:

```yaml
ports:
- protocol: TCP
  port: 80
```

---

## Exercise 4.1 Solution

**Task:** Create a policy with both ingress and egress rules.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-rules
  namespace: ex-4-1
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
EOF
```

**Explanation:** The policy has both Ingress and Egress in policyTypes. Ingress is allowed only from frontend pods. Egress is allowed only to database pods.

---

## Exercise 4.2 Solution

**Task:** Create a policy allowing both TCP and UDP on port 53.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dns-access
  namespace: ex-4-2
spec:
  podSelector:
    matchLabels:
      app: dns
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
EOF
```

**Explanation:** The ports array includes two entries, one for TCP and one for UDP. DNS uses both protocols, so both must be allowed for proper DNS functionality.

---

## Exercise 4.3 Solution

**Task:** Use a named port in the Network Policy.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: http-access
  namespace: ex-4-3
spec:
  podSelector:
    matchLabels:
      app: server
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: http
EOF
```

**Explanation:** The port field references the named port `http` instead of the number 80. This matches the `name: http` in the container's ports definition. Named ports make policies more readable and resilient to port number changes.

---

## Exercise 5.1 Solution

**Task:** Implement policies for a frontend/backend web application.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-policy
  namespace: ex-5-1
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
  name: backend-policy
  namespace: ex-5-1
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
    ports:
    - port: 80
EOF
```

**Explanation:** 

- Frontend policy: Empty ingress rule `{}` allows all ingress
- Backend policy: Only allows ingress from pods with `tier=web` on port 80

External clients can reach frontend (no restrictions), frontend can reach backend (allowed by backend policy), but external clients cannot reach backend directly (not matched by backend policy's from selector).

---

## Exercise 5.2 Solution

**Task:** Fix the policy so service-b can reach service-a.

**Diagnosis:**

```bash
kubectl describe networkpolicy service-a-policy -n ex-5-2
# Allows from pods with: allowed=true

kubectl get pod service-b -n ex-5-2 --show-labels
# No allowed=true label
```

**Fix:** Add the required label to service-b:

```bash
kubectl label pod service-b -n ex-5-2 allowed=true
```

**Explanation:** The policy allows ingress from pods with `allowed=true`, but service-b does not have this label. Adding the label allows service-b to be matched by the policy's from selector.

---

## Exercise 5.3 Solution

**Task:** Design policies for a three-tier application.

**Solution:**

```yaml
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-policy
  namespace: ex-5-3
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Ingress
  ingress:
  - {}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-policy
  namespace: ex-5-3
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
    ports:
    - port: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-policy
  namespace: ex-5-3
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
    ports:
    - port: 80
EOF
```

**Explanation:**

- **Web (frontend):** Accepts all ingress with empty rule `{}`
- **API (backend):** Only accepts from frontend tier on port 80
- **DB (database):** Only accepts from backend tier on port 80

This enforces the traffic flow: external -> web -> api -> db. Direct access to api or db from external clients (tester) is blocked because they do not have the frontend tier label.

---

## Common Mistakes

### CNI Not Supporting NetworkPolicy

**Mistake:** Creating policies on a cluster without a CNI that supports NetworkPolicy.

**Problem:** The policies exist but are not enforced. All traffic is still allowed.

**Fix:** Use a CNI that supports NetworkPolicy (Calico, Cilium, Weave). For kind, disable the default CNI and install Calico.

### Empty podSelector Means All Pods

**Mistake:** Using `podSelector: {}` thinking it matches nothing.

**Problem:** Empty selector matches ALL pods in the namespace.

**Fix:** Understand that `{}` is a wildcard. To match specific pods, use labels.

### policyTypes Must Include What You Control

**Mistake:** Defining egress rules but not including Egress in policyTypes.

**Problem:** Egress rules have no effect if Egress is not in policyTypes.

**Fix:** Always include the relevant type (Ingress, Egress, or both) in policyTypes.

### Multiple from/to Entries Are OR, Not AND

**Mistake:** Thinking multiple from entries require all conditions.

**Problem:** Traffic is allowed if ANY from entry matches.

**Fix:** For AND logic, put multiple selectors in the SAME from entry.

### Forgetting DNS Egress Breaks Name Resolution

**Mistake:** Creating egress rules without allowing DNS.

**Problem:** Pods cannot resolve service names (DNS uses UDP port 53).

**Fix:** Add a rule allowing egress to kube-system on UDP port 53 (covered in assignment 2).

---

## NetworkPolicy Debugging Cheat Sheet

| Task | Command |
|------|---------|
| List policies | `kubectl get networkpolicy -n <namespace>` |
| Describe policy | `kubectl describe networkpolicy <name> -n <namespace>` |
| Check pod labels | `kubectl get pod <name> --show-labels` |
| Add label to pod | `kubectl label pod <name> <key>=<value>` |
| Test connectivity | `kubectl exec -n <ns> <pod> -- wget -qO- --timeout=2 http://<ip>` |
| Test with timeout | `timeout 3 kubectl exec ...` |
| Get pod IP | `kubectl get pod <name> -o jsonpath='{.status.podIP}'` |
| Delete policy | `kubectl delete networkpolicy <name> -n <namespace>` |
| Delete all policies | `kubectl delete networkpolicy --all -n <namespace>` |
