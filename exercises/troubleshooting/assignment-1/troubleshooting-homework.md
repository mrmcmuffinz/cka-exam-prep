# Application Troubleshooting Homework

This homework file contains 15 debugging exercises organized into five difficulty levels. All exercises present broken configurations that you must diagnose and fix. Exercise headings are intentionally bare to avoid spoiling the problem.

## Setup

Verify that your cluster is running with multiple nodes.

```bash
kubectl get nodes
```

Verify metrics-server is installed.

```bash
kubectl top nodes
```

If metrics-server is not installed, install it.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.8.1/components.yaml
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
```

Clean up any leftover exercise namespaces.

```bash
for i in 1 2 3 4 5; do
  for j in 1 2 3; do
    kubectl delete namespace ex-${i}-${j} --ignore-not-found --wait=false
  done
done
```

-----

## Level 1: Single Failure Diagnosis

### Exercise 1.1

**Setup:**

```bash
kubectl create namespace ex-1-1

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: webapp
  namespace: ex-1-1
spec:
  containers:
  - name: webapp
    image: nginx:1.25
    command: ["nginx", "-g", "daemon off"]
EOF
```

**Objective:**

The pod is crashing. Diagnose and fix the issue so the pod runs successfully.

**Verification:**

```bash
kubectl get pod webapp -n ex-1-1 | grep Running
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
  name: data-processor
  namespace: ex-1-2
spec:
  containers:
  - name: processor
    image: busybox:1.36
    command: ["sh", "-c", "cat /data/input.txt"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: data-pvc
EOF
```

**Objective:**

The pod is stuck in Pending. Diagnose and fix the issue so the pod can start.

**Verification:**

```bash
kubectl get pod data-processor -n ex-1-2 | grep -E "Running|Completed"
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
  name: backend
  namespace: ex-1-3
  labels:
    app: backend
    tier: api
spec:
  containers:
  - name: backend
    image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: ex-1-3
spec:
  selector:
    app: backend
    tier: database
  ports:
  - port: 80
    targetPort: 80
EOF
```

**Objective:**

The service has no endpoints. Diagnose and fix the issue so the service correctly routes to the pod.

**Verification:**

```bash
kubectl get endpoints backend-svc -n ex-1-3 -o jsonpath='{.subsets[0].addresses[0].ip}' && echo " OK"
```

-----

## Level 2: Configuration Issues

### Exercise 2.1

**Setup:**

```bash
kubectl create namespace ex-2-1

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: config-app
  namespace: ex-2-1
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo \$APP_CONFIG; sleep 3600"]
    envFrom:
    - configMapRef:
        name: app-settings
EOF
```

**Objective:**

The pod cannot start due to a missing resource. Diagnose and fix the issue.

**Verification:**

```bash
kubectl get pod config-app -n ex-2-1 | grep Running
kubectl exec config-app -n ex-2-1 -- env | grep APP
```

-----

### Exercise 2.2

**Setup:**

```bash
kubectl create namespace ex-2-2

kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=secret123 \
  -n ex-2-2

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: db-client
  namespace: ex-2-2
spec:
  containers:
  - name: client
    image: busybox:1.36
    command: ["sh", "-c", "echo User: \$DB_USER Pass: \$DB_PASS; sleep 3600"]
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: user
    - name: DB_PASS
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: pass
EOF
```

**Objective:**

The pod cannot start due to configuration issues. Diagnose and fix the issue.

**Verification:**

```bash
kubectl get pod db-client -n ex-2-2 | grep Running
kubectl exec db-client -n ex-2-2 -- env | grep -E "DB_USER|DB_PASS"
```

-----

### Exercise 2.3

**Setup:**

```bash
kubectl create namespace ex-2-3

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: ex-2-3
data:
  LOG_LEVEL: info
  DATABASE_HOST: localhost
---
apiVersion: v1
kind: Pod
metadata:
  name: env-app
  namespace: ex-2-3
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo Log: \$LOGLEVEL DB: \$DATABASE_HOST; sleep 3600"]
    env:
    - name: LOGLEVEL
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: LOGLEVEL
    - name: DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: DATABASE_HOST
EOF
```

**Objective:**

The pod cannot start. Diagnose and fix the configuration issue.

**Verification:**

```bash
kubectl get pod env-app -n ex-2-3 | grep Running
kubectl exec env-app -n ex-2-3 -- env | grep -E "LOGLEVEL|DATABASE"
```

-----

## Level 3: Resource and Image Issues

### Exercise 3.1

**Setup:**

```bash
kubectl create namespace ex-3-1

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: memory-app
  namespace: ex-3-1
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "while true; do head -c 50m /dev/zero | tail; sleep 1; done"]
    resources:
      requests:
        memory: 10Mi
      limits:
        memory: 20Mi
EOF
```

**Objective:**

The pod keeps getting killed. Diagnose the issue and fix the configuration so the pod runs stably.

**Verification:**

```bash
kubectl get pod memory-app -n ex-3-1 | grep Running
# Wait 30 seconds and check again
sleep 30
kubectl get pod memory-app -n ex-3-1 | grep Running
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
  name: custom-app
  namespace: ex-3-2
spec:
  containers:
  - name: app
    image: mycompany/custom-app:v1.2.3
EOF
```

**Objective:**

The pod cannot start due to an image issue. Diagnose and fix the issue by using a valid public image.

**Verification:**

```bash
kubectl get pod custom-app -n ex-3-2 | grep Running
```

-----

### Exercise 3.3

**Setup:**

```bash
kubectl create namespace ex-3-3

kubectl create resourcequota pod-quota \
  --hard=pods=1 \
  -n ex-3-3

kubectl run existing-pod --image=nginx:1.25 -n ex-3-3

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: blocked-pod
  namespace: ex-3-3
spec:
  containers:
  - name: app
    image: nginx:1.25
EOF
```

**Objective:**

The second pod cannot be created. Diagnose the issue and modify the namespace configuration to allow the pod to be created.

**Verification:**

```bash
kubectl get pod blocked-pod -n ex-3-3 | grep -E "Running|Pending"
```

-----

## Level 4: Multi-Factor Failures

### Exercise 4.1

**Setup:**

```bash
kubectl create namespace ex-4-1

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: dual-issue
  namespace: ex-4-1
spec:
  containers:
  - name: app
    image: nginx:1.25
    command: ["nginx", "-g", "daemon off"]
    env:
    - name: CONFIG
      valueFrom:
        configMapKeyRef:
          name: missing-config
          key: setting
EOF
```

**Objective:**

The pod has multiple issues preventing it from running. Find and fix all issues.

**Verification:**

```bash
kubectl get pod dual-issue -n ex-4-1 | grep Running
```

-----

### Exercise 4.2

**Setup:**

```bash
kubectl create namespace ex-4-2

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  namespace: ex-4-2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: web
        image: nginx:nonexistent
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-svc
  namespace: ex-4-2
spec:
  selector:
    app: web
  ports:
  - port: 80
EOF
```

**Objective:**

The deployment has pods that are not running and the service has no endpoints. Find and fix all issues.

**Verification:**

```bash
kubectl get deployment webapp -n ex-4-2 -o jsonpath='{.status.readyReplicas}' && echo " ready"
kubectl get endpoints webapp-svc -n ex-4-2 -o jsonpath='{.subsets[0].addresses[0].ip}' && echo " has endpoints"
```

-----

### Exercise 4.3

**Setup:**

```bash
kubectl create namespace ex-4-3

kubectl create configmap app-config \
  --from-literal=DB_HOST=localhost \
  -n ex-4-3

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: configured-app
  namespace: ex-4-3
  labels:
    app: configured
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo DB: \$DB_HOST PORT: \$DB_PORT; sleep 3600"]
    env:
    - name: DB_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: DB_HOST
    - name: DB_PORT
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: DB_PORT
---
apiVersion: v1
kind: Service
metadata:
  name: configured-svc
  namespace: ex-4-3
spec:
  selector:
    app: config-app
  ports:
  - port: 80
EOF
```

**Objective:**

The pod cannot start and the service is not routing correctly. Find and fix all issues.

**Verification:**

```bash
kubectl get pod configured-app -n ex-4-3 | grep Running
kubectl exec configured-app -n ex-4-3 -- env | grep DB
kubectl get endpoints configured-svc -n ex-4-3 -o jsonpath='{.subsets[0].addresses[0].ip}' && echo " OK"
```

-----

## Level 5: Complex Scenarios

### Exercise 5.1

**Setup:**

```bash
kubectl create namespace ex-5-1

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
  namespace: ex-5-1
data:
  API_URL: http://api-svc:8080
---
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
    envFrom:
    - configMapRef:
        name: frontend-settings
---
apiVersion: v1
kind: Pod
metadata:
  name: api
  namespace: ex-5-1
  labels:
    tier: api
spec:
  containers:
  - name: api
    image: busybox:1.36
    command: ["sh", "-c", "while true; do echo 'API running'; sleep 10; done"]
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
kind: Service
metadata:
  name: api-svc
  namespace: ex-5-1
spec:
  selector:
    tier: backend
  ports:
  - port: 8080
EOF
```

**Objective:**

This multi-tier application has several issues. Find and fix all problems so both pods run and both services have endpoints.

**Verification:**

```bash
kubectl get pods -n ex-5-1 | grep -c Running | grep 2
kubectl get endpoints frontend-svc -n ex-5-1 -o jsonpath='{.subsets[0].addresses[0].ip}' && echo " frontend OK"
kubectl get endpoints api-svc -n ex-5-1 -o jsonpath='{.subsets[0].addresses[0].ip}' && echo " api OK"
```

-----

### Exercise 5.2

**Setup:**

```bash
kubectl create namespace ex-5-2

kubectl create secret generic app-secrets \
  --from-literal=api-key=abc123 \
  --from-literal=db-password=secret \
  -n ex-5-2

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: ex-5-2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        version: v1
    spec:
      containers:
      - name: backend
        image: nginx:1.25
        command: ["nginx", "-g", "daemon of;"]
        env:
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: apikey
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: db-password
        resources:
          limits:
            memory: 50Mi
---
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: ex-5-2
spec:
  selector:
    app: backend
    version: v2
  ports:
  - port: 80
EOF
```

**Objective:**

The deployment pods are failing and the service has no endpoints. This is a complex scenario with multiple issues. Find and fix all problems.

**Verification:**

```bash
kubectl get deployment backend -n ex-5-2 -o jsonpath='{.status.readyReplicas}' && echo " replicas ready"
kubectl get endpoints backend-svc -n ex-5-2 -o jsonpath='{.subsets[0].addresses[0].ip}' && echo " has endpoints"
```

-----

### Exercise 5.3

**Setup:**

```bash
kubectl create namespace ex-5-3

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
  namespace: ex-5-3
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: nonexistent-class
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: db-config
  namespace: ex-5-3
data:
  MYSQL_DATABASE: myapp
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: ex-5-3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: db
        image: busybox:1.36
        command: ["sh", "-c", "echo DB: \$MYSQL_DATABASE; sleep 3600"]
        env:
        - name: MYSQL_DATABASE
          valueFrom:
            configMapKeyRef:
              name: db-config
              key: MYSQL_DATABASE
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secrets
              key: password
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: data-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: database-svc
  namespace: ex-5-3
spec:
  selector:
    app: db
  ports:
  - port: 3306
EOF
```

**Objective:**

This database deployment has multiple issues preventing it from running. Find and fix all problems.

**Verification:**

```bash
kubectl get deployment database -n ex-5-3 -o jsonpath='{.status.readyReplicas}' && echo " replicas ready"
kubectl get endpoints database-svc -n ex-5-3 -o jsonpath='{.subsets[0].addresses[0].ip}' && echo " has endpoints"
```

-----

## Cleanup

Remove all exercise namespaces.

```bash
for i in 1 2 3 4 5; do
  for j in 1 2 3; do
    kubectl delete namespace ex-${i}-${j} --ignore-not-found --wait=false
  done
done
```

## Key Takeaways

After completing these exercises, you should be proficient at diagnosing CrashLoopBackOff from logs and exit codes, identifying ImagePullBackOff and Pending causes, finding missing ConfigMaps and Secrets, recognizing OOMKilled and resource issues, debugging service selector mismatches, and systematically troubleshooting multi-issue scenarios.
