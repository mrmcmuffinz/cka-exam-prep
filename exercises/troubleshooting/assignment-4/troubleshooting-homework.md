# Network Troubleshooting Homework

This homework contains 15 debugging exercises for network issues. All exercises present broken configurations to diagnose and fix.

## Setup

```bash
kubectl get nodes
```

Clean up previous exercises.

```bash
for i in 1 2 3 4 5; do
  for j in 1 2 3; do
    kubectl delete namespace ex-${i}-${j} --ignore-not-found --wait=false
  done
done
```

-----

## Level 1: Service Issues

### Exercise 1.1

**Setup:**

```bash
kubectl create namespace ex-1-1

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: ex-1-1
  labels:
    app: backend
spec:
  containers:
  - name: backend
    image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: ex-1-1
spec:
  selector:
    app: api
  ports:
  - port: 80
EOF
```

**Objective:**

The service has no endpoints. Diagnose and fix.

**Verification:**

```bash
kubectl get endpoints backend-svc -n ex-1-1 | grep -v "none"
```

-----

### Exercise 1.2

**Setup:**

```bash
kubectl create namespace ex-1-2

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: ex-1-2
  labels:
    app: web
spec:
  containers:
  - name: web
    image: nginx:1.25
    ports:
    - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: ex-1-2
spec:
  selector:
    app: web
  ports:
  - port: 8080
    targetPort: 8080
EOF
```

**Objective:**

Service does not work. Diagnose and fix.

**Verification:**

```bash
kubectl run test -n ex-1-2 --image=busybox:1.36 --restart=Never --rm -it -- wget -T5 -O- http://web-svc
```

-----

### Exercise 1.3

**Setup:**

```bash
kubectl create namespace ex-1-3

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: app
  namespace: ex-1-3
  labels:
    tier: frontend
spec:
  containers:
  - name: app
    image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: app-svc
  namespace: ex-1-3
spec:
  selector:
    app: frontend
  ports:
  - port: 80
EOF
```

**Objective:**

Service has no endpoints. Diagnose and fix.

**Verification:**

```bash
kubectl get endpoints app-svc -n ex-1-3 | grep -v "none"
```

-----

## Level 2: DNS Issues

### Exercise 2.1

**Setup:**

```bash
kubectl create namespace ex-2-1

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: ex-2-1
spec:
  dnsPolicy: None
  containers:
  - name: client
    image: busybox:1.36
    command: ["sleep", "3600"]
EOF
```

**Objective:**

DNS resolution does not work in the pod. Diagnose and fix.

**Verification:**

```bash
kubectl exec client -n ex-2-1 -- nslookup kubernetes.default
```

-----

### Exercise 2.2

**Setup:**

```bash
kubectl create namespace ex-2-2

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: ex-2-2
  labels:
    app: backend
spec:
  containers:
  - name: backend
    image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: ex-2-2
spec:
  selector:
    app: backend
  ports:
  - port: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: ex-2-2
spec:
  containers:
  - name: client
    image: busybox:1.36
    command: ["sh", "-c", "wget -T5 -O- http://backend-svc && sleep 3600"]
EOF
```

**Objective:**

Client pod fails to connect. Diagnose and fix.

**Verification:**

```bash
kubectl exec client -n ex-2-2 -- wget -T5 -O- http://backend
```

-----

### Exercise 2.3

**Setup:**

```bash
kubectl create namespace ex-2-3

kubectl scale deployment coredns -n kube-system --replicas=0
sleep 10
```

**Objective:**

DNS is not working cluster-wide. Diagnose and fix.

**Verification:**

```bash
kubectl run test -n ex-2-3 --image=busybox:1.36 --restart=Never --rm -it -- nslookup kubernetes.default
```

-----

## Level 3: NetworkPolicy Issues

### Exercise 3.1

**Setup:**

```bash
kubectl create namespace ex-3-1

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: ex-3-1
  labels:
    app: web
spec:
  containers:
  - name: web
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
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: ex-3-1
spec:
  podSelector: {}
  policyTypes:
  - Ingress
EOF
```

**Objective:**

Traffic to the service is blocked. Diagnose and fix to allow access from any pod.

**Verification:**

```bash
kubectl run test -n ex-3-1 --image=busybox:1.36 --restart=Never --rm -it -- wget -T5 -O- http://web-svc
```

-----

### Exercise 3.2

**Setup:**

```bash
kubectl create namespace ex-3-2

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: ex-3-2
  labels:
    app: client
spec:
  containers:
  - name: client
    image: busybox:1.36
    command: ["sleep", "3600"]
---
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
EOF
```

**Objective:**

The client cannot resolve DNS. Diagnose and fix while keeping the egress restriction.

**Verification:**

```bash
kubectl exec client -n ex-3-2 -- nslookup kubernetes.default
```

-----

### Exercise 3.3

**Setup:**

```bash
kubectl create namespace ex-3-3
kubectl create namespace ex-3-3-client

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: server
  namespace: ex-3-3
  labels:
    app: server
spec:
  containers:
  - name: server
    image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: server-svc
  namespace: ex-3-3
spec:
  selector:
    app: server
  ports:
  - port: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-ns
  namespace: ex-3-3
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: client
EOF
```

**Objective:**

Cross-namespace access is blocked. Fix to allow access from ex-3-3-client namespace.

**Verification:**

```bash
kubectl run test -n ex-3-3-client --image=busybox:1.36 --restart=Never --rm -it -- wget -T5 -O- http://server-svc.ex-3-3
```

-----

## Level 4: External Access

### Exercise 4.1

**Setup:**

```bash
kubectl create namespace ex-4-1

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: ex-4-1
  labels:
    app: web
spec:
  containers:
  - name: web
    image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: web-np
  namespace: ex-4-1
spec:
  type: NodePort
  selector:
    app: webapp
  ports:
  - port: 80
    nodePort: 30080
EOF
```

**Objective:**

NodePort service does not work. Diagnose and fix.

**Verification:**

```bash
kubectl get endpoints web-np -n ex-4-1 | grep -v "none"
```

-----

### Exercise 4.2

**Objective:**

Describe the diagnostic steps for an Ingress that is not routing traffic.

**Verification:**

Document the commands to check Ingress controller, Ingress rules, backend services, and certificates.

-----

### Exercise 4.3

**Objective:**

Describe how to troubleshoot LoadBalancer services stuck in Pending state.

**Verification:**

Document the diagnostic workflow.

-----

## Level 5: Complex Network Failures

### Exercise 5.1

**Setup:**

```bash
kubectl create namespace ex-5-1

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: ex-5-1
  labels:
    tier: frontend
spec:
  containers:
  - name: frontend
    image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
  namespace: ex-5-1
spec:
  selector:
    app: frontend
  ports:
  - port: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: ex-5-1
  labels:
    tier: backend
spec:
  containers:
  - name: backend
    image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: ex-5-1
spec:
  selector:
    tier: api
  ports:
  - port: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: ex-5-1
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
```

**Objective:**

Multiple networking issues. Fix all problems so frontend can reach backend.

**Verification:**

```bash
kubectl exec frontend -n ex-5-1 -- wget -T5 -O- http://backend-svc
```

-----

### Exercise 5.2

**Objective:**

Design a complete network troubleshooting workflow for a multi-tier application.

**Verification:**

Create a checklist covering services, DNS, NetworkPolicy, and connectivity testing.

-----

### Exercise 5.3

**Objective:**

Simulate and diagnose a production network incident involving DNS and NetworkPolicy.

**Verification:**

Document the incident response steps.

-----

## Cleanup

```bash
for i in 1 2 3 4 5; do
  for j in 1 2 3; do
    kubectl delete namespace ex-${i}-${j} --ignore-not-found --wait=false
  done
done
kubectl delete namespace ex-3-3-client --ignore-not-found --wait=false
kubectl scale deployment coredns -n kube-system --replicas=2
```
