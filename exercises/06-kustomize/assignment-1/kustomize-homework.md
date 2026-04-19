# Kustomize Fundamentals Homework

This homework file contains 15 progressive exercises organized into five difficulty levels. The exercises assume you have worked through `kustomize-tutorial.md`. Each exercise uses its own namespace and working directory. Complete the exercises in order.

## Setup

Verify that your cluster is running.

```bash
kubectl get nodes
```

Create a base working directory for all exercises.

```bash
mkdir -p ~/kustomize-exercises
cd ~/kustomize-exercises
```

If you want to clean up any leftover exercise namespaces from a previous attempt, run the following.

```bash
for i in 1 2 3 4 5; do
  for j in 1 2 3; do
    kubectl delete namespace ex-${i}-${j} --ignore-not-found --wait=false
  done
done
rm -rf ~/kustomize-exercises/*
```

-----

## Level 1: Basic Kustomization

### Exercise 1.1

**Objective:** Create a basic kustomization with a single resource.

**Setup:**

```bash
mkdir -p ~/kustomize-exercises/ex-1-1
cd ~/kustomize-exercises/ex-1-1
kubectl create namespace ex-1-1
```

**Task:**

Create a deployment.yaml file for an nginx deployment with 1 replica. Then create a kustomization.yaml that references this deployment. Build the kustomization and verify the output.

**Verification:**

```bash
# kustomization.yaml should exist
cat ~/kustomize-exercises/ex-1-1/kustomization.yaml

# build should produce valid output
kubectl kustomize ~/kustomize-exercises/ex-1-1 | grep "kind: Deployment"

# output should include nginx image
kubectl kustomize ~/kustomize-exercises/ex-1-1 | grep "image: nginx"
```

Expected: kustomization.yaml exists, output contains a Deployment with nginx image.

-----

### Exercise 1.2

**Objective:** Build and view kustomization output.

**Setup:**

```bash
mkdir -p ~/kustomize-exercises/ex-1-2
cd ~/kustomize-exercises/ex-1-2
kubectl create namespace ex-1-2
```

Create base resources.

```bash
cat > deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
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
      - name: webapp
        image: nginx:1.25
EOF
```

**Task:**

Create a kustomization.yaml that references the deployment. Use kubectl kustomize to build the output and save it to a file called rendered.yaml.

**Verification:**

```bash
# rendered.yaml should exist
ls ~/kustomize-exercises/ex-1-2/rendered.yaml

# should contain the deployment
grep "kind: Deployment" ~/kustomize-exercises/ex-1-2/rendered.yaml

# should have 2 replicas
grep "replicas: 2" ~/kustomize-exercises/ex-1-2/rendered.yaml
```

Expected: rendered.yaml exists with deployment content.

-----

### Exercise 1.3

**Objective:** Apply a kustomization to the cluster.

**Setup:**

```bash
mkdir -p ~/kustomize-exercises/ex-1-3
cd ~/kustomize-exercises/ex-1-3
kubectl create namespace ex-1-3
```

Create base resources.

```bash
cat > deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
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
      - name: web
        image: nginx:1.25
EOF
```

**Task:**

Create a kustomization.yaml that sets the namespace to ex-1-3. Apply the kustomization using kubectl apply -k.

**Verification:**

```bash
# deployment should exist in namespace
kubectl get deployment web -n ex-1-3

# should be running
kubectl get pods -n ex-1-3 | grep Running
```

Expected: Deployment created in ex-1-3 namespace, pod running.

-----

## Level 2: Common Transformers

### Exercise 2.1

**Objective:** Add a namePrefix to all resources.

**Setup:**

```bash
mkdir -p ~/kustomize-exercises/ex-2-1
cd ~/kustomize-exercises/ex-2-1
kubectl create namespace ex-2-1
```

Create base resources.

```bash
cat > deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
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
      - name: api
        image: nginx:1.25
EOF
```

**Task:**

Create a kustomization.yaml that adds the prefix "dev-" to all resource names and sets namespace to ex-2-1. Apply and verify the deployment name is "dev-api".

**Verification:**

```bash
# deployment should have prefix
kubectl get deployment -n ex-2-1 | grep dev-api

# original name should not exist
kubectl get deployment api -n ex-2-1 2>&1 | grep -c "not found"
```

Expected: Deployment named "dev-api" exists, "api" does not.

-----

### Exercise 2.2

**Objective:** Add commonLabels to all resources.

**Setup:**

```bash
mkdir -p ~/kustomize-exercises/ex-2-2
cd ~/kustomize-exercises/ex-2-2
kubectl create namespace ex-2-2
```

Create base resources.

```bash
cat > deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
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
      - name: backend
        image: nginx:1.25
EOF
```

**Task:**

Create a kustomization.yaml that adds labels "environment: development" and "team: platform" to all resources. Set namespace to ex-2-2 and apply.

**Verification:**

```bash
# deployment should have environment label
kubectl get deployment backend -n ex-2-2 -o jsonpath='{.metadata.labels.environment}'; echo

# deployment should have team label
kubectl get deployment backend -n ex-2-2 -o jsonpath='{.metadata.labels.team}'; echo

# pod should also have labels
kubectl get pods -n ex-2-2 -o jsonpath='{.items[0].metadata.labels.environment}'; echo
```

Expected: Labels "development" and "platform" on deployment and pods.

-----

### Exercise 2.3

**Objective:** Set namespace for all resources.

**Setup:**

```bash
mkdir -p ~/kustomize-exercises/ex-2-3
cd ~/kustomize-exercises/ex-2-3
kubectl create namespace ex-2-3
```

Create resources without namespace.

```bash
cat > deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
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
      - name: frontend
        image: nginx:1.25
EOF

cat > service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  selector:
    app: frontend
  ports:
  - port: 80
  type: ClusterIP
EOF
```

**Task:**

Create a kustomization.yaml that references both resources and sets namespace to ex-2-3 for all of them. Apply and verify both are in the correct namespace.

**Verification:**

```bash
# deployment in correct namespace
kubectl get deployment frontend -n ex-2-3

# service in correct namespace
kubectl get service frontend -n ex-2-3

# not in default namespace
kubectl get deployment frontend -n default 2>&1 | grep -c "not found"
```

Expected: Both resources in ex-2-3 namespace.

-----

## Level 3: Debugging Kustomization Issues

### Exercise 3.1

**Objective:** Debug a kustomization with incorrect resource path.

**Setup:**

```bash
mkdir -p ~/kustomize-exercises/ex-3-1
cd ~/kustomize-exercises/ex-3-1
kubectl create namespace ex-3-1
```

Create resources.

```bash
cat > app-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: nginx:1.25
EOF

cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-3-1
EOF
```

**Task:**

The kustomization fails to build. Find the error and fix the kustomization.yaml so it correctly references the deployment file.

**Verification:**

```bash
# build should succeed
kubectl kustomize ~/kustomize-exercises/ex-3-1

# apply should work
kubectl apply -k ~/kustomize-exercises/ex-3-1
kubectl get deployment myapp -n ex-3-1
```

Expected: Kustomization builds and applies successfully.

-----

### Exercise 3.2

**Objective:** Debug a kustomization with label conflict.

**Setup:**

```bash
mkdir -p ~/kustomize-exercises/ex-3-2
cd ~/kustomize-exercises/ex-3-2
kubectl create namespace ex-3-2
```

Create resources.

```bash
cat > deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  labels:
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: nginx:1.25
EOF

cat > service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: webapp
spec:
  selector:
    app: webapp
  ports:
  - port: 80
  type: ClusterIP
EOF

cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml

namespace: ex-3-2

commonLabels:
  app: my-webapp
EOF
```

**Task:**

This kustomization will cause the service selector to not match the deployment pods because commonLabels changes the app label. Fix the kustomization so that the service correctly selects the deployment pods.

**Verification:**

```bash
# apply
kubectl apply -k ~/kustomize-exercises/ex-3-2

# service should have endpoints
kubectl get endpoints webapp -n ex-3-2 -o jsonpath='{.subsets[0].addresses[0].ip}'; echo
```

Expected: Service has endpoints pointing to the pod.

-----

### Exercise 3.3

**Objective:** Debug a kustomization with missing apiVersion.

**Setup:**

```bash
mkdir -p ~/kustomize-exercises/ex-3-3
cd ~/kustomize-exercises/ex-3-3
kubectl create namespace ex-3-3
```

Create resources.

```bash
cat > deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken
spec:
  replicas: 1
  selector:
    matchLabels:
      app: broken
  template:
    metadata:
      labels:
        app: broken
    spec:
      containers:
      - name: broken
        image: nginx:1.25
EOF

cat > kustomization.yaml <<'EOF'
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-3-3
EOF
```

**Task:**

The kustomization fails to build because it is missing required fields. Fix the kustomization.yaml so it builds correctly.

**Verification:**

```bash
# build should succeed
kubectl kustomize ~/kustomize-exercises/ex-3-3

# apply should work
kubectl apply -k ~/kustomize-exercises/ex-3-3
kubectl get deployment broken -n ex-3-3
```

Expected: Kustomization builds and applies successfully.

-----

## Level 4: Multi-Resource Kustomizations

### Exercise 4.1

**Objective:** Combine multiple resources with multiple transformers.

**Setup:**

```bash
mkdir -p ~/kustomize-exercises/ex-4-1
cd ~/kustomize-exercises/ex-4-1
kubectl create namespace ex-4-1
```

**Task:**

Create a deployment for nginx and a service for it. Create a kustomization.yaml that references both resources, sets namespace to ex-4-1, adds namePrefix "prod-", and adds commonLabels "tier: frontend" and "env: production". Apply and verify.

**Verification:**

```bash
# deployment name should have prefix
kubectl get deployment -n ex-4-1 | grep prod-

# labels should exist
kubectl get deployment -n ex-4-1 -o jsonpath='{.items[0].metadata.labels.tier}'; echo
kubectl get deployment -n ex-4-1 -o jsonpath='{.items[0].metadata.labels.env}'; echo

# service should exist with prefix
kubectl get service -n ex-4-1 | grep prod-
```

Expected: Resources with prefix and labels.

-----

### Exercise 4.2

**Objective:** Add both labels and annotations.

**Setup:**

```bash
mkdir -p ~/kustomize-exercises/ex-4-2
cd ~/kustomize-exercises/ex-4-2
kubectl create namespace ex-4-2
```

**Task:**

Create a deployment for nginx. Create a kustomization.yaml that sets namespace to ex-4-2, adds commonLabels "app: web" and "team: platform", and adds commonAnnotations "owner: platform-team" and "cost-center: engineering". Apply and verify.

**Verification:**

```bash
# labels should exist
kubectl get deployment -n ex-4-2 -o jsonpath='{.items[0].metadata.labels.team}'; echo

# annotations should exist
kubectl get deployment -n ex-4-2 -o jsonpath='{.items[0].metadata.annotations.owner}'; echo
kubectl get deployment -n ex-4-2 -o jsonpath='{.items[0].metadata.annotations.cost-center}'; echo
```

Expected: Both labels and annotations present.

-----

### Exercise 4.3

**Objective:** Use prefix and suffix together.

**Setup:**

```bash
mkdir -p ~/kustomize-exercises/ex-4-3
cd ~/kustomize-exercises/ex-4-3
kubectl create namespace ex-4-3
```

**Task:**

Create a deployment named "api". Create a kustomization.yaml that sets namespace to ex-4-3, adds namePrefix "team1-", and adds nameSuffix "-v2". The final deployment name should be "team1-api-v2".

**Verification:**

```bash
# deployment should have full transformed name
kubectl get deployment team1-api-v2 -n ex-4-3

# original name should not exist
kubectl get deployment api -n ex-4-3 2>&1 | grep -c "not found"
```

Expected: Deployment named "team1-api-v2".

-----

## Level 5: Application Scenarios

### Exercise 5.1

**Objective:** Kustomize a multi-service application.

**Setup:**

```bash
mkdir -p ~/kustomize-exercises/ex-5-1
cd ~/kustomize-exercises/ex-5-1
kubectl create namespace ex-5-1
```

**Task:**

Create a two-tier application with: 1) A frontend deployment and service (nginx), 2) A backend deployment and service (nginx acting as API). Create a kustomization.yaml that includes all four resources, sets namespace to ex-5-1, adds namePrefix "myapp-", and adds commonLabels "project: myapp" and "version: v1".

**Verification:**

```bash
# all deployments should exist with prefix
kubectl get deployment -n ex-5-1 | grep myapp-

# all services should exist with prefix
kubectl get service -n ex-5-1 | grep myapp-

# count should be 2 deployments, 2 services
kubectl get deployment -n ex-5-1 --no-headers | wc -l
kubectl get service -n ex-5-1 --no-headers | wc -l
```

Expected: 2 deployments and 2 services with prefix and labels.

-----

### Exercise 5.2

**Objective:** Debug a complex kustomization.

**Setup:**

```bash
mkdir -p ~/kustomize-exercises/ex-5-2
cd ~/kustomize-exercises/ex-5-2
kubectl create namespace ex-5-2
```

Create resources with issues.

```bash
cat > deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: complex
spec:
  replicas: 2
  selector:
    matchLabels:
      app: complex
  template:
    metadata:
      labels:
        app: complex
    spec:
      containers:
      - name: complex
        image: nginx:1.25
EOF

cat > service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: complex-svc
spec:
  selector:
    app: complex
  ports:
  - port: 80
EOF

cat > configmap.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: complex-config
data:
  setting: value
EOF

cat > kustomization.yaml <<'EOF'
kind: Kustomization

resources:
- deplyoment.yaml
- service.yaml
- configmap.yaml

namespace: ex-5-2
namePrefix: debug-
EOF
```

**Task:**

The kustomization has multiple issues. Debug and fix all issues so it builds and applies successfully.

**Verification:**

```bash
# build should succeed
kubectl kustomize ~/kustomize-exercises/ex-5-2

# apply should work
kubectl apply -k ~/kustomize-exercises/ex-5-2

# all resources should exist
kubectl get deployment,service,configmap -n ex-5-2 | grep debug-
```

Expected: All three resources created with prefix.

-----

### Exercise 5.3

**Objective:** Design a kustomization structure for a project.

**Setup:**

```bash
mkdir -p ~/kustomize-exercises/ex-5-3
cd ~/kustomize-exercises/ex-5-3
kubectl create namespace ex-5-3
```

**Task:**

Design a complete kustomization for a web application with: deployment (3 replicas, nginx:1.25), service (ClusterIP), and configmap with application settings. The kustomization should set namespace to ex-5-3, add namePrefix "webapp-", add commonLabels for app and version, and add commonAnnotations for owner and description.

**Verification:**

```bash
# build should succeed
kubectl kustomize ~/kustomize-exercises/ex-5-3

# apply should work
kubectl apply -k ~/kustomize-exercises/ex-5-3

# deployment should have 3 replicas
kubectl get deployment -n ex-5-3 -o jsonpath='{.items[0].spec.replicas}'; echo

# labels should exist
kubectl get deployment -n ex-5-3 -o jsonpath='{.items[0].metadata.labels}'; echo

# annotations should exist
kubectl get deployment -n ex-5-3 -o jsonpath='{.items[0].metadata.annotations}'; echo
```

Expected: Complete application deployed with all transformations applied.

-----

## Cleanup

Remove all exercise namespaces and files.

```bash
for i in 1 2 3 4 5; do
  for j in 1 2 3; do
    kubectl delete namespace ex-${i}-${j} --ignore-not-found --wait=false
  done
done
rm -rf ~/kustomize-exercises
```

## Key Takeaways

After completing these exercises, you should be comfortable with creating kustomization.yaml files, referencing multiple resources, using kubectl kustomize to preview output, using kubectl apply -k to deploy, adding namePrefix and nameSuffix, adding commonLabels and commonAnnotations, setting namespace for all resources, combining multiple transformers, and debugging common kustomization errors.
