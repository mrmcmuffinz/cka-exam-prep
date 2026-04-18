# Network Troubleshooting Homework: 15 Progressive Exercises

These exercises build on the concepts covered in `troubleshooting-tutorial.md`. Every exercise is a debugging scenario; the setup breaks something on the network path, and you must diagnose and fix it.

All exercises assume the multi-node kind cluster described in `docs/cluster-setup.md#multi-node-with-calico-networkpolicy-support` with MetalLB and Traefik installed per the tutorial's prerequisites:

```bash
kubectl config current-context   # expect: kind-kind
kubectl get nodes                # expect: 4 nodes, all Ready
kubectl get pods -n kube-system -l k8s-app=kube-dns   # CoreDNS Running
kubectl get pods -n metallb-system                    # MetalLB Running
kubectl get ingressclass                              # traefik listed
```

Every exercise uses its own namespace. Cluster-scoped objects stay within their namespaces as much as possible; NetworkPolicies are namespace-scoped, Ingress resources are namespace-scoped.

## Global Setup

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 \
          ex-2-1 ex-2-2 ex-2-2-target ex-2-3 \
          ex-3-1 ex-3-2 ex-3-3 ex-3-3-src \
          ex-4-1 ex-4-2 ex-4-3 \
          ex-5-1 ex-5-2 ex-5-3; do
  kubectl create namespace $ns
done
```

---

## Level 1: Service Issues

### Exercise 1.1

**Objective:** Make the `web` Service reach its backend pods.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: ex-1-1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: ex-1-1
spec:
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: webapp
EOF

kubectl rollout status deployment/web -n ex-1-1 --timeout=60s
```

**Task:**

The `web` Service exists but a curl from another pod in the namespace hangs (or returns connection-refused). Diagnose and fix.

**Verification:**

```bash
kubectl get endpoints web -n ex-1-1
# Expected: ENDPOINTS column lists two pod IPs (not <none>).

kubectl run probe -n ex-1-1 --rm -it --restart=Never --image=busybox:1.36 \
  -- wget -q -O- http://web/
# Expected: the nginx default index page is printed.
```

---

### Exercise 1.2

**Objective:** Make the `api` Service actually serve requests.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: ex-1-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
              name: http
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: ex-1-2
spec:
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: api
EOF

kubectl rollout status deployment/api -n ex-1-2 --timeout=60s
```

**Task:**

The Service has endpoints, but curl from another pod hangs forever. Diagnose and fix.

**Verification:**

```bash
kubectl get endpoints api -n ex-1-2
# Expected: ENDPOINTS populated (the problem is not the selector).

kubectl run probe -n ex-1-2 --rm -it --restart=Never --image=busybox:1.36 \
  -- sh -c 'timeout 5 wget -q -O- http://api/ && echo ok'
# Expected: the page content followed by "ok".
```

---

### Exercise 1.3

**Objective:** Make the `cache` Service's TCP connections succeed.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cache
  namespace: ex-1-3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cache
  template:
    metadata:
      labels:
        app: cache
    spec:
      containers:
        - name: redis
          image: redis:7.2
          ports:
            - containerPort: 6379
              name: redis
---
apiVersion: v1
kind: Service
metadata:
  name: cache
  namespace: ex-1-3
spec:
  ports:
    - port: 6379
      targetPort: 6379
      protocol: UDP
  selector:
    app: cache
EOF

kubectl rollout status deployment/cache -n ex-1-3 --timeout=60s
```

**Task:**

The `cache` Service is supposed to forward TCP traffic to Redis, but a connection attempt from another pod returns connection-refused or closes immediately. Diagnose and fix.

**Verification:**

```bash
kubectl get svc cache -n ex-1-3 \
  -o jsonpath='{.spec.ports[0].protocol}{"\n"}'
# Expected: TCP

kubectl run probe -n ex-1-3 --rm -it --restart=Never --image=busybox:1.36 \
  -- sh -c 'echo PING | nc -w 3 cache 6379'
# Expected: a +PONG response from Redis.
```

---

## Level 2: DNS Issues

### Exercise 2.1

**Objective:** Restore cluster DNS.

**Setup:**

```bash
kubectl scale deployment coredns -n kube-system --replicas=0
sleep 15
```

**Task:**

After the setup, no pod in the cluster can resolve DNS names. Diagnose what happened and restore DNS functionality.

**Verification:**

```bash
kubectl get deployment coredns -n kube-system \
  -o jsonpath='{.status.readyReplicas}{"\n"}'
# Expected: a number >= 1 (CoreDNS is running again).

kubectl run probe -n ex-2-1 --rm -it --restart=Never --image=busybox:1.36 \
  -- nslookup kubernetes.default
# Expected: an Address line for the kubernetes Service (usually 10.96.0.1).
```

---

### Exercise 2.2

**Objective:** Make the curl from the `client` pod succeed.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: target
  namespace: ex-2-2-target
spec:
  replicas: 1
  selector:
    matchLabels:
      app: target
  template:
    metadata:
      labels:
        app: target
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: target
  namespace: ex-2-2-target
spec:
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: target
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client
  namespace: ex-2-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client
  template:
    metadata:
      labels:
        app: client
    spec:
      containers:
        - name: probe
          image: busybox:1.36
          command: ["sh", "-c", "while true; do wget -q -O- http://target/ > /dev/null && echo OK || echo FAIL; sleep 3; done"]
EOF

kubectl rollout status deployment/target -n ex-2-2-target --timeout=60s
kubectl rollout status deployment/client -n ex-2-2 --timeout=60s
```

**Task:**

The `client` Deployment (in namespace `ex-2-2`) keeps logging `FAIL` because its curl to `http://target/` does not resolve. The target Service exists in a different namespace. Diagnose the DNS failure and modify the client's command so it reaches the target by its correct DNS name.

**Verification:**

```bash
CLIENT=$(kubectl get pod -n ex-2-2 -l app=client -o jsonpath='{.items[0].metadata.name}')
sleep 10
kubectl logs -n ex-2-2 $CLIENT --tail=5 | grep -c OK
# Expected: a number >= 1 (OK lines appearing in the log).
```

---

### Exercise 2.3

**Objective:** Make DNS work again in the `ex-2-3` namespace.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
  namespace: ex-2-3
spec:
  podSelector: {}
  policyTypes:
    - Egress
EOF
sleep 5
```

**Task:**

A client pod in `ex-2-3` cannot resolve any DNS name. A NetworkPolicy is in effect. Modify or add policies so that DNS queries from any pod in `ex-2-3` to the cluster DNS service (CoreDNS in `kube-system`, label `k8s-app: kube-dns`) on UDP port 53 and TCP port 53 are allowed, while other egress remains denied.

**Verification:**

```bash
kubectl run dns-probe -n ex-2-3 --rm -it --restart=Never --image=busybox:1.36 \
  -- nslookup kubernetes.default
# Expected: an Address line for kubernetes.default.
```

---

## Level 3: NetworkPolicy Issues

### Exercise 3.1

**Objective:** Make the frontend reach the backend.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: ex-3-1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: ex-3-1
spec:
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: backend
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: ex-3-1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: probe
          image: busybox:1.36
          command: ["sh", "-c", "while true; do wget -q -O- http://backend/ > /dev/null && echo OK || echo FAIL; sleep 3; done"]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: ex-3-1
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
EOF

kubectl rollout status deployment/backend -n ex-3-1 --timeout=60s
kubectl rollout status deployment/frontend -n ex-3-1 --timeout=60s
```

**Task:**

After the setup, the frontend's logs show only `FAIL`. Add a NetworkPolicy that allows ingress traffic from pods labeled `app=frontend` to pods labeled `app=backend` on port 80. Leave the existing deny-all-ingress in place.

**Verification:**

```bash
CLIENT=$(kubectl get pod -n ex-3-1 -l app=frontend -o jsonpath='{.items[0].metadata.name}')
sleep 10
kubectl logs -n ex-3-1 $CLIENT --tail=5 | grep -c OK
# Expected: a number >= 1.
```

---

### Exercise 3.2

**Objective:** Restore outbound traffic from the `client` pod while keeping a default-deny egress in place.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client
  namespace: ex-3-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client
  template:
    metadata:
      labels:
        app: client
    spec:
      containers:
        - name: probe
          image: busybox:1.36
          command: ["sh", "-c", "while true; do wget -q -O- --timeout=2 http://kubernetes.default.svc:443/ > /dev/null 2>&1 && echo OK || echo FAIL; sleep 3; done"]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
  namespace: ex-3-2
spec:
  podSelector:
    matchLabels:
      app: client
  policyTypes:
    - Egress
EOF

kubectl rollout status deployment/client -n ex-3-2 --timeout=60s
sleep 10
```

**Task:**

The client's egress is fully blocked. Add NetworkPolicies that allow the client pod to perform DNS lookups (to CoreDNS at `k8s-app=kube-dns` in `kube-system`, UDP port 53) and to reach the cluster API server via `kubernetes.default.svc` (which typically listens on port 443 in the `default` namespace). Do not remove the `deny-all-egress` policy.

**Verification:**

```bash
kubectl run dns-probe -n ex-3-2 --rm -it --restart=Never --image=busybox:1.36 \
  -- nslookup kubernetes.default
# Expected: an Address line (DNS works).

# A pod in the default-deny still cannot reach arbitrary external services;
# the additional allow rules only expose DNS and the cluster API server.
kubectl get networkpolicy -n ex-3-2 -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | sort
# Expected: deny-all-egress plus the additional allow policies you created.
```

---

### Exercise 3.3

**Objective:** Make the cross-namespace curl from `ex-3-3-src` reach `ex-3-3`.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: target
  namespace: ex-3-3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: target
  template:
    metadata:
      labels:
        app: target
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
---
apiVersion: v1
kind: Service
metadata:
  name: target
  namespace: ex-3-3
spec:
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: target
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-caller
  namespace: ex-3-3
spec:
  podSelector:
    matchLabels:
      app: target
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: caller-ns
      ports:
        - port: 80
          protocol: TCP
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: caller
  namespace: ex-3-3-src
spec:
  replicas: 1
  selector:
    matchLabels:
      app: caller
  template:
    metadata:
      labels:
        app: caller
    spec:
      containers:
        - name: probe
          image: busybox:1.36
          command: ["sh", "-c", "while true; do wget -q -O- http://target.ex-3-3/ > /dev/null && echo OK || echo FAIL; sleep 3; done"]
EOF

kubectl rollout status deployment/target -n ex-3-3 --timeout=60s
kubectl rollout status deployment/caller -n ex-3-3-src --timeout=60s
sleep 10
```

**Task:**

The `caller` Deployment in `ex-3-3-src` tries to reach `target` in `ex-3-3` but always logs `FAIL`. The NetworkPolicy in `ex-3-3` selects by namespace label. Diagnose the mismatch between the policy's `namespaceSelector` and the source namespace, and fix the policy so cross-namespace traffic is allowed.

**Verification:**

```bash
CLIENT=$(kubectl get pod -n ex-3-3-src -l app=caller -o jsonpath='{.items[0].metadata.name}')
sleep 10
kubectl logs -n ex-3-3-src $CLIENT --tail=5 | grep -c OK
# Expected: a number > 0.

kubectl get networkpolicy allow-from-caller -n ex-3-3 \
  -o jsonpath='{.spec.ingress[0].from[0].namespaceSelector.matchLabels}{"\n"}'
# Expected: a selector containing kubernetes.io/metadata.name: ex-3-3-src
```

---

## Level 4: External Access

### Exercise 4.1

**Objective:** Make the Ingress route traffic to the backend.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: ex-4-1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: app
  namespace: ex-4-1
spec:
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: app
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app
  namespace: ex-4-1
spec:
  rules:
    - host: app.ex-4-1.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app
                port:
                  number: 80
EOF

kubectl rollout status deployment/app -n ex-4-1 --timeout=60s
sleep 15
```

**Task:**

The Ingress exists but has no ADDRESS and no controller is routing for it. Diagnose why and fix the Ingress so Traefik picks it up.

**Verification:**

```bash
kubectl get ingress app -n ex-4-1 \
  -o jsonpath='{.spec.ingressClassName}{"\n"}'
# Expected: traefik
```

---

### Exercise 4.2

**Objective:** Make a curl to the Ingress succeed.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: site
  namespace: ex-4-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: site
  template:
    metadata:
      labels:
        app: site
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: site
  namespace: ex-4-2
spec:
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: site
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: site
  namespace: ex-4-2
spec:
  ingressClassName: traefik
  rules:
    - host: wrong-host.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: site
                port:
                  number: 80
EOF

kubectl rollout status deployment/site -n ex-4-2 --timeout=60s
```

**Task:**

The Ingress is claimed by Traefik, but a curl with `Host: site.ex-4-2.local` returns a 404 from Traefik. Diagnose the Host header mismatch and fix the Ingress so the expected Host routes to the `site` Service.

**Verification:**

```bash
kubectl get ingress site -n ex-4-2 \
  -o jsonpath='{.spec.rules[0].host}{"\n"}'
# Expected: site.ex-4-2.local
```

---

### Exercise 4.3

**Objective:** Make a LoadBalancer Service get an external IP.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: ex-4-3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
---
apiVersion: v1
kind: Service
metadata:
  name: app
  namespace: ex-4-3
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: app
EOF

kubectl rollout status deployment/app -n ex-4-3 --timeout=60s
sleep 15

kubectl delete ipaddresspool --all -n metallb-system --ignore-not-found
sleep 10
```

**Task:**

The LoadBalancer Service stays in `<pending>` because MetalLB has no IP address pool. Recreate the pool (use the kind subnet range; the default setup uses `172.18.255.200-172.18.255.250`) so MetalLB assigns an external IP. The authoritative setup is in `docs/cluster-setup.md#metallb-for-loadbalancer-services`.

**Verification:**

```bash
kubectl get ipaddresspools -n metallb-system \
  -o jsonpath='{.items[*].metadata.name}{"\n"}'
# Expected: a pool name (non-empty).

sleep 10
kubectl get service app -n ex-4-3 \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}'
# Expected: an IP address from the restored pool.
```

---

## Level 5: Complex Network Failures

### Exercise 5.1

**Objective:** Fully restore connectivity from the `client` pod in `ex-5-1` to the `backend` Service.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: ex-5-1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: ex-5-1
spec:
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: backend-v2
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client
  namespace: ex-5-1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client
  template:
    metadata:
      labels:
        app: client
    spec:
      containers:
        - name: probe
          image: busybox:1.36
          command: ["sh", "-c", "while true; do wget -q -O- http://backend/ > /dev/null && echo OK || echo FAIL; sleep 3; done"]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-ingress
  namespace: ex-5-1
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
EOF

kubectl rollout status deployment/backend -n ex-5-1 --timeout=60s
kubectl rollout status deployment/client -n ex-5-1 --timeout=60s
sleep 10
```

**Task:**

The client's logs show only `FAIL`. There are two independent issues: the Service has empty endpoints because of a selector mismatch, and a NetworkPolicy blocks ingress to backend pods. Fix both so the client reports `OK`.

**Verification:**

```bash
kubectl get endpoints backend -n ex-5-1 \
  -o jsonpath='{.subsets[0].addresses[*].ip}{"\n"}'
# Expected: two IPs (the backend pod IPs).

CLIENT=$(kubectl get pod -n ex-5-1 -l app=client -o jsonpath='{.items[0].metadata.name}')
sleep 10
kubectl logs -n ex-5-1 $CLIENT --tail=5 | grep -c OK
# Expected: a number > 0.
```

---

### Exercise 5.2

**Objective:** Trace and fix a cascading network failure across three layers.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: ex-5-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: ex-5-2
spec:
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: web
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client
  namespace: ex-5-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client
  template:
    metadata:
      labels:
        app: client
    spec:
      containers:
        - name: probe
          image: busybox:1.36
          command: ["sh", "-c", "while true; do wget -q -O- http://web.wrong-ns/ > /dev/null && echo OK || echo FAIL; sleep 3; done"]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-web
  namespace: ex-5-2
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: admin-client
      ports:
        - port: 80
EOF

kubectl rollout status deployment/web -n ex-5-2 --timeout=60s
kubectl rollout status deployment/client -n ex-5-2 --timeout=60s
sleep 10
```

**Task:**

Three things are broken simultaneously: the client curls a DNS name that does not exist, the Service has a wrong `targetPort`, and the NetworkPolicy's `from.podSelector` does not match the client's labels. Fix all three so the client reports `OK` regularly.

**Verification:**

```bash
kubectl get svc web -n ex-5-2 \
  -o jsonpath='{.spec.ports[0].targetPort}{"\n"}'
# Expected: 80 (matching the container's listening port).

kubectl get networkpolicy restrict-web -n ex-5-2 \
  -o jsonpath='{.spec.ingress[0].from[0].podSelector.matchLabels}{"\n"}'
# Expected: a selector that matches the client pod's labels (app=client).

CLIENT=$(kubectl get pod -n ex-5-2 -l app=client -o jsonpath='{.items[0].metadata.name}')
sleep 10
kubectl logs -n ex-5-2 $CLIENT --tail=5 | grep -c OK
# Expected: a number > 0.
```

---

### Exercise 5.3

**Objective:** Author a production-runbook for the incident described below.

**Setup:**

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prod-web
  namespace: ex-5-3
spec:
  replicas: 3
  selector:
    matchLabels:
      app: prod-web
  template:
    metadata:
      labels:
        app: prod-web
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: prod-web
  namespace: ex-5-3
spec:
  ports:
    - port: 80
      targetPort: 80
  selector:
    app: prod-web
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prod-web
  namespace: ex-5-3
spec:
  ingressClassName: traefik
  rules:
    - host: prod-web.ex-5-3.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: prod-web
                port:
                  number: 80
EOF

kubectl rollout status deployment/prod-web -n ex-5-3 --timeout=60s
```

**Task:**

Imagine an on-call engineer has just been paged with the alert "external user reports `prod-web.ex-5-3.local` returns 503". Write a runbook at `/tmp/ex-5-3-runbook.md` that lists, in order, the diagnostic commands you would run to narrow the root cause from outermost layer (Ingress) to innermost layer (pod), with the expected-vs-actual signals at each step and the corresponding fix category. The runbook should cover at least six steps and should explicitly call out which kubectl commands to run at each step.

**Verification:**

```bash
test -f /tmp/ex-5-3-runbook.md && wc -l /tmp/ex-5-3-runbook.md
# Expected: the file exists and has at least 30 lines.

grep -c '^#\|^##\|^###' /tmp/ex-5-3-runbook.md
# Expected: a count > 5 (the runbook is structured with at least 6 step headers).

# The file mentions the expected command surface:
for keyword in 'kubectl describe ingress' 'kubectl get endpoints' 'kubectl logs' 'kubectl get networkpolicies'; do
  grep -c "$keyword" /tmp/ex-5-3-runbook.md
done
# Expected: each grep returns a count >= 1.
```

---

## Cleanup

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 \
          ex-2-1 ex-2-2 ex-2-2-target ex-2-3 \
          ex-3-1 ex-3-2 ex-3-3 ex-3-3-src \
          ex-4-1 ex-4-2 ex-4-3 \
          ex-5-1 ex-5-2 ex-5-3; do
  kubectl delete namespace $ns --ignore-not-found
done

# Re-scale CoreDNS if Exercise 2.1 left it down:
kubectl scale deployment coredns -n kube-system --replicas=2

rm -f /tmp/ex-5-3-runbook.md
```

---

## Key Takeaways

Network failures at the cluster layer follow a predictable six-layer path from "user cannot reach the app" back to the root cause, and the root cause almost always lives at an earlier layer than the symptom. Practice the playbook on healthy systems so it is reflex under pressure: pod Ready, Service endpoints populated, DNS resolves, client can curl the ClusterIP, NetworkPolicy permits the flow, external path intact. A failure at step N means the problem is at that layer; earlier layers' checks all passed and do not need re-examination.

Empty Service endpoints are always a selector problem. Populated endpoints with timeout or connection-refused are always a port or protocol problem; check `spec.ports[0].targetPort` against the pod's `containerPort`, and confirm `spec.ports[0].protocol` matches what the container actually serves. DNS failures split into two observable buckets: NXDOMAIN (wrong name, wrong namespace) and hang (CoreDNS down or DNS egress blocked by NetworkPolicy). Any NetworkPolicy rollout that does not include the DNS egress rule breaks every Service lookup in the affected pods.

Cross-namespace traffic always has two sides: the destination NetworkPolicy's `namespaceSelector` must match the source namespace, and the source NetworkPolicy (if any) must allow egress to the destination. The common mistake is to write the `namespaceSelector` against a label the source namespace does not have; the built-in `kubernetes.io/metadata.name` label (which every namespace carries with its own name as the value) is the most reliable selector value for this case.

External access is often a three-part failure: wrong Service type, wrong port, or wrong controller claim. NodePort uses the node IP at the NodePort (not the Service port). LoadBalancer in kind needs MetalLB with a configured IPAddressPool, or it stays `Pending` forever. Ingress needs a matching `ingressClassName` or no controller routes for it, and the Host header the client sends must match `spec.rules[0].host` or the controller returns 404.

The diagnostic playbook runs in under a minute once it is reflex: pod status, `kubectl get endpoints`, `nslookup` from a debug pod, curl by ClusterIP, curl by pod IP, `kubectl get networkpolicies`. Six commands, six layers, each with a specific expected output. Every production network outage described in post-mortems usually ends with "the root cause was at step N and we spent two hours looking at steps M > N." The playbook exists to keep the search ordered.
