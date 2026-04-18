# Application Troubleshooting Homework Answers

This file contains complete diagnostic workflows and solutions for all 15 exercises.

-----

## Exercise 1.1 Solution

**Diagnosis:**

```bash
kubectl get pod webapp -n ex-1-1
kubectl describe pod webapp -n ex-1-1
kubectl logs webapp -n ex-1-1 --previous
```

The pod is in CrashLoopBackOff. The command has a syntax error: `daemon off` should be `daemon off;` (missing semicolon) and the entire argument should be quoted.

**Fix:**

```bash
kubectl delete pod webapp -n ex-1-1

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
    command: ["nginx", "-g", "daemon off;"]
EOF
```

The nginx command requires the semicolon at the end of the directive.

-----

## Exercise 1.2 Solution

**Diagnosis:**

```bash
kubectl get pod data-processor -n ex-1-2
kubectl describe pod data-processor -n ex-1-2
kubectl get pvc -n ex-1-2
```

The pod is Pending because the PVC "data-pvc" does not exist.

**Fix:**

Create the PVC (using the default StorageClass).

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
  namespace: ex-1-2
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Mi
EOF
```

Also, the command tries to read a file that does not exist. Update the pod to do something that works.

```bash
kubectl delete pod data-processor -n ex-1-2

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
    command: ["sh", "-c", "ls /data; sleep 3600"]
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: data-pvc
EOF
```

-----

## Exercise 1.3 Solution

**Diagnosis:**

```bash
kubectl get endpoints backend-svc -n ex-1-3
kubectl get pod backend -n ex-1-3 --show-labels
kubectl get svc backend-svc -n ex-1-3 -o jsonpath='{.spec.selector}'
```

The service selector is `app: backend, tier: database` but the pod has `app: backend, tier: api`. The tier label does not match.

**Fix:**

```bash
kubectl patch svc backend-svc -n ex-1-3 --type='json' -p='[{"op": "replace", "path": "/spec/selector/tier", "value": "api"}]'
```

Or recreate the service with correct selector.

```bash
kubectl delete svc backend-svc -n ex-1-3

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: ex-1-3
spec:
  selector:
    app: backend
    tier: api
  ports:
  - port: 80
    targetPort: 80
EOF
```

-----

## Exercise 2.1 Solution

**Diagnosis:**

```bash
kubectl describe pod config-app -n ex-2-1
kubectl get configmap -n ex-2-1
```

The ConfigMap "app-settings" does not exist.

**Fix:**

```bash
kubectl create configmap app-settings --from-literal=APP_CONFIG=myvalue -n ex-2-1
kubectl delete pod config-app -n ex-2-1

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

-----

## Exercise 2.2 Solution

**Diagnosis:**

```bash
kubectl describe pod db-client -n ex-2-2
kubectl get secret db-credentials -n ex-2-2 -o jsonpath='{.data}' | base64 -d
```

The secret has keys "username" and "password", but the pod references keys "user" and "pass".

**Fix:**

```bash
kubectl delete pod db-client -n ex-2-2

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
          key: username
    - name: DB_PASS
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
EOF
```

-----

## Exercise 2.3 Solution

**Diagnosis:**

```bash
kubectl describe pod env-app -n ex-2-3
kubectl get configmap app-config -n ex-2-3 -o yaml
```

The ConfigMap has key "LOG_LEVEL" but the pod references "LOGLEVEL" (no underscore).

**Fix:**

```bash
kubectl delete pod env-app -n ex-2-3

cat <<EOF | kubectl apply -f -
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
          key: LOG_LEVEL
    - name: DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: DATABASE_HOST
EOF
```

-----

## Exercise 3.1 Solution

**Diagnosis:**

```bash
kubectl describe pod memory-app -n ex-3-1
```

The pod is being OOMKilled because the memory limit (20Mi) is too low for the workload.

**Fix:**

```bash
kubectl delete pod memory-app -n ex-3-1

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
    command: ["sh", "-c", "sleep 3600"]
    resources:
      requests:
        memory: 64Mi
      limits:
        memory: 128Mi
EOF
```

Either increase the memory limit or change the workload to use less memory.

-----

## Exercise 3.2 Solution

**Diagnosis:**

```bash
kubectl describe pod custom-app -n ex-3-2
```

ImagePullBackOff because the image "mycompany/custom-app:v1.2.3" does not exist in any accessible registry.

**Fix:**

```bash
kubectl delete pod custom-app -n ex-3-2

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: custom-app
  namespace: ex-3-2
spec:
  containers:
  - name: app
    image: nginx:1.25
EOF
```

-----

## Exercise 3.3 Solution

**Diagnosis:**

```bash
kubectl describe pod blocked-pod -n ex-3-3
kubectl get resourcequota -n ex-3-3
```

The ResourceQuota limits pods to 1, and there is already one pod running.

**Fix:**

Increase the quota or delete the existing pod.

```bash
kubectl patch resourcequota pod-quota -n ex-3-3 --type='json' -p='[{"op": "replace", "path": "/spec/hard/pods", "value": "2"}]'
```

Then recreate the blocked pod if needed.

-----

## Exercise 4.1 Solution

**Diagnosis:**

```bash
kubectl describe pod dual-issue -n ex-4-1
```

Two issues: 1) Missing ConfigMap "missing-config", 2) nginx command syntax error (should be `daemon off;`).

**Fix:**

```bash
kubectl create configmap missing-config --from-literal=setting=value -n ex-4-1
kubectl delete pod dual-issue -n ex-4-1

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
    command: ["nginx", "-g", "daemon off;"]
    env:
    - name: CONFIG
      valueFrom:
        configMapKeyRef:
          name: missing-config
          key: setting
EOF
```

-----

## Exercise 4.2 Solution

**Diagnosis:**

```bash
kubectl get pods -n ex-4-2
kubectl describe pod -n ex-4-2
kubectl get endpoints webapp-svc -n ex-4-2
kubectl get svc webapp-svc -n ex-4-2 -o yaml
```

Issues: 1) Image "nginx:nonexistent" does not exist, 2) Service selector is `app: web` but pod label is `app: webapp`, 3) Readiness probe path /health does not exist on nginx.

**Fix:**

```bash
kubectl delete deployment webapp -n ex-4-2
kubectl delete svc webapp-svc -n ex-4-2

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
        image: nginx:1.25
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
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
    app: webapp
  ports:
  - port: 80
EOF
```

-----

## Exercise 4.3 Solution

**Diagnosis:**

```bash
kubectl describe pod configured-app -n ex-4-3
kubectl get configmap app-config -n ex-4-3 -o yaml
kubectl get endpoints configured-svc -n ex-4-3
```

Issues: 1) ConfigMap key "DB_PORT" does not exist, 2) Service selector `app: config-app` does not match pod label `app: configured`.

**Fix:**

```bash
kubectl patch configmap app-config -n ex-4-3 --type='json' -p='[{"op": "add", "path": "/data/DB_PORT", "value": "5432"}]'
kubectl delete pod configured-app -n ex-4-3

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
EOF

kubectl patch svc configured-svc -n ex-4-3 --type='json' -p='[{"op": "replace", "path": "/spec/selector/app", "value": "configured"}]'
```

-----

## Exercise 5.1 Solution

**Diagnosis:**

Multiple issues across frontend, api, and services.

**Issues:**

1. Frontend pod references ConfigMap "frontend-settings" but it is named "frontend-config"
2. frontend-svc selector `app: frontend` does not match pod label `tier: frontend`
3. api-svc selector `tier: backend` does not match pod label `tier: api`

**Fix:**

```bash
kubectl delete pod frontend -n ex-5-1
kubectl delete svc frontend-svc api-svc -n ex-5-1

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
    envFrom:
    - configMapRef:
        name: frontend-config
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
  namespace: ex-5-1
spec:
  selector:
    tier: frontend
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
    tier: api
  ports:
  - port: 8080
EOF
```

-----

## Exercise 5.2 Solution

**Diagnosis:**

Multiple issues in the deployment and service.

**Issues:**

1. nginx command has syntax error: `daemon of;` should be `daemon off;`
2. Secret key "apikey" does not exist (it is "api-key")
3. Service selector has `version: v2` but pods have `version: v1`
4. Memory limit 50Mi is low for nginx but should work

**Fix:**

```bash
kubectl delete deployment backend -n ex-5-2
kubectl delete svc backend-svc -n ex-5-2

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
        command: ["nginx", "-g", "daemon off;"]
        env:
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: api-key
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: db-password
        resources:
          limits:
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: ex-5-2
spec:
  selector:
    app: backend
    version: v1
  ports:
  - port: 80
EOF
```

-----

## Exercise 5.3 Solution

**Diagnosis:**

Multiple issues with PVC, Secret, and Service.

**Issues:**

1. PVC uses StorageClass "nonexistent-class" which does not exist
2. Secret "db-secrets" does not exist
3. Service selector `app: db` does not match pod label `app: database`

**Fix:**

```bash
kubectl delete pvc data-pvc -n ex-5-3
kubectl delete deployment database -n ex-5-3
kubectl delete svc database-svc -n ex-5-3

kubectl create secret generic db-secrets --from-literal=password=rootpassword -n ex-5-3

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
    app: database
  ports:
  - port: 3306
EOF
```

-----

## Common Mistakes in Diagnosis

1. Not checking --previous logs for crashed containers
2. Not comparing service selector with pod labels
3. Not checking if referenced ConfigMaps/Secrets exist
4. Not checking key names in ConfigMap/Secret references
5. Not checking PVC binding status
6. Assuming resource limits are sufficient without checking OOMKilled

-----

## Troubleshooting Flowchart

```
Pod not Running?
├── Pending?
│   └── Check: Resources, PVC, NodeSelector, Taints
├── ImagePullBackOff?
│   └── Check: Image name, tag, registry access
├── CrashLoopBackOff?
│   └── Check: logs --previous, command syntax, dependencies
├── CreateContainerError?
│   └── Check: ConfigMap/Secret references, volume mounts
└── Running but not Ready?
    └── Check: Readiness probe, endpoint registration

Service has no endpoints?
├── Check pod labels vs service selector
├── Check pod readiness
└── Check namespace match
```
