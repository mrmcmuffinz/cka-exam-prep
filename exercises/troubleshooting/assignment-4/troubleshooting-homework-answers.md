# Network Troubleshooting Homework Answers

Solutions for all 15 exercises.

-----

## Exercise 1.1 Solution

Service selector `app: api` does not match pod label `app: backend`.

```bash
kubectl patch svc backend-svc -n ex-1-1 --type='json' -p='[{"op": "replace", "path": "/spec/selector/app", "value": "backend"}]'
```

-----

## Exercise 1.2 Solution

Service targetPort is 8080 but container listens on 80.

```bash
kubectl patch svc web-svc -n ex-1-2 --type='json' -p='[{"op": "replace", "path": "/spec/ports/0/targetPort", "value": 80}]'
```

-----

## Exercise 1.3 Solution

Service selector `app: frontend` does not match pod label `tier: frontend`.

Either patch service or pod. Patching service.

```bash
kubectl delete svc app-svc -n ex-1-3
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: app-svc
  namespace: ex-1-3
spec:
  selector:
    tier: frontend
  ports:
  - port: 80
EOF
```

-----

## Exercise 2.1 Solution

Pod has dnsPolicy: None with no dnsConfig. Fix by using ClusterFirst.

```bash
kubectl delete pod client -n ex-2-1
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: ex-2-1
spec:
  dnsPolicy: ClusterFirst
  containers:
  - name: client
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
```

-----

## Exercise 2.2 Solution

Client tries to connect to "backend-svc" but service is named "backend".

Fix the client command or create an alias service. The service is correctly named "backend".

```bash
kubectl exec client -n ex-2-2 -- wget -T5 -O- http://backend
```

-----

## Exercise 2.3 Solution

CoreDNS was scaled to 0 replicas.

```bash
kubectl scale deployment coredns -n kube-system --replicas=2
```

-----

## Exercise 3.1 Solution

NetworkPolicy denies all ingress. Add a policy to allow access.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all-ingress
  namespace: ex-3-1
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
  - Ingress
  ingress:
  - {}
EOF
```

-----

## Exercise 3.2 Solution

Egress policy does not allow DNS (port 53 UDP). Add DNS egress rule.

```bash
kubectl delete networkpolicy restrict-egress -n ex-3-2
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
  namespace: ex-3-2
spec:
  podSelector:
    matchLabels:
      app: client
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: backend
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
EOF
```

-----

## Exercise 3.3 Solution

Policy only allows from same namespace with podSelector. Need namespaceSelector for cross-namespace.

```bash
kubectl delete networkpolicy allow-same-ns -n ex-3-3
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-cross-ns
  namespace: ex-3-3
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ex-3-3-client
EOF
```

-----

## Exercise 4.1 Solution

Service selector `app: webapp` does not match pod label `app: web`.

```bash
kubectl patch svc web-np -n ex-4-1 --type='json' -p='[{"op": "replace", "path": "/spec/selector/app", "value": "web"}]'
```

-----

## Exercise 4.2 Solution

Ingress troubleshooting workflow.

1. Check Ingress controller is running.
```bash
kubectl get pods -n ingress-nginx
```

2. Check Ingress resource.
```bash
kubectl describe ingress <name> -n <namespace>
```

3. Check backend services have endpoints.
```bash
kubectl get endpoints <backend-service> -n <namespace>
```

4. Check Ingress controller logs.
```bash
kubectl logs -n ingress-nginx <controller-pod>
```

5. Test direct service access.
```bash
kubectl run test --image=busybox:1.36 --rm -it -- wget -T5 -O- http://<service>
```

-----

## Exercise 4.3 Solution

LoadBalancer Pending troubleshooting.

1. Check if cloud provider integration exists.
```bash
kubectl get nodes -o jsonpath='{.items[0].spec.providerID}'
```

2. Kind/local clusters have no LoadBalancer provider.

3. Options: Use NodePort, install MetalLB, or use Ingress.

4. Check events.
```bash
kubectl describe svc <service>
```

-----

## Exercise 5.1 Solution

Multiple issues.

1. frontend-svc selector wrong (app vs tier).
2. backend-svc selector wrong.
3. NetworkPolicy denies all traffic.

Fix.

```bash
# Fix frontend service
kubectl patch svc frontend-svc -n ex-5-1 --type='json' -p='[{"op": "replace", "path": "/spec/selector/tier", "value": "frontend"}, {"op": "remove", "path": "/spec/selector/app"}]'

# Fix backend service
kubectl delete svc backend-svc -n ex-5-1
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: ex-5-1
spec:
  selector:
    tier: backend
  ports:
  - port: 80
EOF

# Add NetworkPolicy to allow traffic
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: ex-5-1
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
  name: allow-frontend-egress
  namespace: ex-5-1
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
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
EOF
```

-----

## Exercise 5.2 Solution

Network troubleshooting checklist.

1. Service layer: endpoints exist, selector matches, ports correct.
2. DNS: CoreDNS running, resolution works, correct service name.
3. NetworkPolicy: policies allow required traffic, DNS egress included.
4. Connectivity: test from client pod, check kube-proxy, verify CNI.

-----

## Exercise 5.3 Solution

Incident response steps.

1. Identify scope (which pods/namespaces affected).
2. Check recent changes (NetworkPolicy, DNS config).
3. Verify CoreDNS health.
4. Check NetworkPolicy egress for DNS.
5. Test connectivity step by step.
6. Roll back problematic changes.
7. Verify resolution.
8. Document root cause and fix.
