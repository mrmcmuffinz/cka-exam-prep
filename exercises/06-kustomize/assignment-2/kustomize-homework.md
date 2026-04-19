# Patches and Transformers Homework

This homework file contains 15 progressive exercises organized into five difficulty levels. The exercises assume you have worked through `kustomize-tutorial.md` and completed kustomize/assignment-1. Each exercise uses its own namespace and working directory. Complete the exercises in order.

## Setup

Verify that your cluster is running.

```bash
kubectl get nodes
```

Create a base working directory for all exercises.

```bash
mkdir -p ~/kustomize-patches
cd ~/kustomize-patches
```

If you want to clean up any leftover exercise namespaces from a previous attempt, run the following.

```bash
for i in 1 2 3 4 5; do
  for j in 1 2 3; do
    kubectl delete namespace ex-${i}-${j} --ignore-not-found --wait=false
  done
done
rm -rf ~/kustomize-patches/*
```

-----

## Level 1: Strategic Merge Patches

### Exercise 1.1

**Objective:** Create a strategic merge patch to modify replicas.

**Setup:**

```bash
mkdir -p ~/kustomize-patches/ex-1-1
cd ~/kustomize-patches/ex-1-1
kubectl create namespace ex-1-1
```

Create the base deployment.

```bash
cat > deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
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
```

**Task:**

Create a strategic merge patch file named `replica-patch.yaml` that changes replicas to 3. Create a kustomization.yaml that applies this patch, sets namespace to ex-1-1, and apply to the cluster.

**Verification:**

```bash
# deployment should have 3 replicas
kubectl get deployment webapp -n ex-1-1 -o jsonpath='{.spec.replicas}'; echo
```

Expected: 3 replicas.

-----

### Exercise 1.2

**Objective:** Create a patch to add environment variables.

**Setup:**

```bash
mkdir -p ~/kustomize-patches/ex-1-2
cd ~/kustomize-patches/ex-1-2
kubectl create namespace ex-1-2
```

Create the base deployment.

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

Create a strategic merge patch that adds environment variables: LOG_LEVEL=debug and ENVIRONMENT=development. Apply with namespace ex-1-2.

**Verification:**

```bash
# check env vars
kubectl get deployment api -n ex-1-2 -o jsonpath='{.spec.template.spec.containers[0].env}'; echo
```

Expected: Environment variables LOG_LEVEL and ENVIRONMENT present.

-----

### Exercise 1.3

**Objective:** Create a patch to add resource requests and limits.

**Setup:**

```bash
mkdir -p ~/kustomize-patches/ex-1-3
cd ~/kustomize-patches/ex-1-3
kubectl create namespace ex-1-3
```

Create the base deployment.

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

Create a strategic merge patch that adds resource requests (memory: 64Mi, cpu: 50m) and limits (memory: 128Mi, cpu: 100m). Apply with namespace ex-1-3.

**Verification:**

```bash
# check resources
kubectl get deployment backend -n ex-1-3 -o jsonpath='{.spec.template.spec.containers[0].resources}'; echo
```

Expected: Both requests and limits configured.

-----

## Level 2: JSON 6902 and Images

### Exercise 2.1

**Objective:** Create a JSON 6902 patch.

**Setup:**

```bash
mkdir -p ~/kustomize-patches/ex-2-1
cd ~/kustomize-patches/ex-2-1
kubectl create namespace ex-2-1
```

Create the base deployment.

```bash
cat > deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service
spec:
  replicas: 1
  selector:
    matchLabels:
      app: service
  template:
    metadata:
      labels:
        app: service
    spec:
      containers:
      - name: service
        image: nginx:1.25
EOF
```

**Task:**

Create a JSON 6902 patch that replaces the replicas value with 4. Apply with namespace ex-2-1.

**Verification:**

```bash
# should have 4 replicas
kubectl get deployment service -n ex-2-1 -o jsonpath='{.spec.replicas}'; echo
```

Expected: 4 replicas.

-----

### Exercise 2.2

**Objective:** Change container image using the images transformer.

**Setup:**

```bash
mkdir -p ~/kustomize-patches/ex-2-2
cd ~/kustomize-patches/ex-2-2
kubectl create namespace ex-2-2
```

Create the base deployment.

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

Use the images transformer to change the nginx image tag from 1.25 to 1.26. Apply with namespace ex-2-2.

**Verification:**

```bash
# should use nginx:1.26
kubectl get deployment web -n ex-2-2 -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
```

Expected: nginx:1.26.

-----

### Exercise 2.3

**Objective:** Change image tag only using images transformer.

**Setup:**

```bash
mkdir -p ~/kustomize-patches/ex-2-3
cd ~/kustomize-patches/ex-2-3
kubectl create namespace ex-2-3
```

Create the base deployment with httpd.

```bash
cat > deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: apache
  template:
    metadata:
      labels:
        app: apache
    spec:
      containers:
      - name: apache
        image: httpd:2.4
EOF
```

**Task:**

Use the images transformer to change the httpd image tag to 2.4.58. Apply with namespace ex-2-3.

**Verification:**

```bash
# should use httpd:2.4.58
kubectl get deployment apache -n ex-2-3 -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
```

Expected: httpd:2.4.58.

-----

## Level 3: Debugging Patch Issues

### Exercise 3.1

**Objective:** Debug a strategic merge patch that is not being applied.

**Setup:**

```bash
mkdir -p ~/kustomize-patches/ex-3-1
cd ~/kustomize-patches/ex-3-1
kubectl create namespace ex-3-1
```

Create the base and broken patch.

```bash
cat > deployment.yaml <<'EOF'
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

cat > patch.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wrongname
spec:
  replicas: 5
EOF

cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-3-1

patches:
- path: patch.yaml
EOF
```

**Task:**

The patch is not being applied correctly. Debug and fix the issue so the deployment has 5 replicas.

**Verification:**

```bash
# should have 5 replicas
kubectl apply -k ~/kustomize-patches/ex-3-1
kubectl get deployment myapp -n ex-3-1 -o jsonpath='{.spec.replicas}'; echo
```

Expected: 5 replicas.

-----

### Exercise 3.2

**Objective:** Debug a JSON 6902 patch with wrong path.

**Setup:**

```bash
mkdir -p ~/kustomize-patches/ex-3-2
cd ~/kustomize-patches/ex-3-2
kubectl create namespace ex-3-2
```

Create the base and broken patch.

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

cat > json-patch.yaml <<'EOF'
- op: replace
  path: /spec/replica
  value: 3
EOF

cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-3-2

patches:
- target:
    kind: Deployment
    name: broken
  path: json-patch.yaml
EOF
```

**Task:**

The JSON patch fails because of an incorrect path. Fix the patch so the deployment has 3 replicas.

**Verification:**

```bash
# build should succeed
kubectl kustomize ~/kustomize-patches/ex-3-2

# should have 3 replicas
kubectl apply -k ~/kustomize-patches/ex-3-2
kubectl get deployment broken -n ex-3-2 -o jsonpath='{.spec.replicas}'; echo
```

Expected: 3 replicas.

-----

### Exercise 3.3

**Objective:** Debug a patch targeting the wrong resource.

**Setup:**

```bash
mkdir -p ~/kustomize-patches/ex-3-3
cd ~/kustomize-patches/ex-3-3
kubectl create namespace ex-3-3
```

Create the base and patch.

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

cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-3-3

patches:
- target:
    kind: Deployment
    name: backend
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 3
EOF
```

**Task:**

The patch targets a non-existent resource. Fix the kustomization so the patch applies to the frontend deployment.

**Verification:**

```bash
# should have 3 replicas
kubectl apply -k ~/kustomize-patches/ex-3-3
kubectl get deployment frontend -n ex-3-3 -o jsonpath='{.spec.replicas}'; echo
```

Expected: 3 replicas.

-----

## Level 4: Generators

### Exercise 4.1

**Objective:** Create a ConfigMap from literals.

**Setup:**

```bash
mkdir -p ~/kustomize-patches/ex-4-1
cd ~/kustomize-patches/ex-4-1
kubectl create namespace ex-4-1
```

**Task:**

Create a kustomization.yaml that generates a ConfigMap named `app-config` with literals: DATABASE_URL=localhost:5432 and LOG_LEVEL=info. Apply with namespace ex-4-1.

**Verification:**

```bash
# configmap should exist (with hash suffix)
kubectl get configmap -n ex-4-1 | grep app-config

# should have the data
kubectl get configmap -n ex-4-1 -o jsonpath='{.items[0].data}'; echo
```

Expected: ConfigMap with DATABASE_URL and LOG_LEVEL.

-----

### Exercise 4.2

**Objective:** Create a Secret from file.

**Setup:**

```bash
mkdir -p ~/kustomize-patches/ex-4-2
cd ~/kustomize-patches/ex-4-2
kubectl create namespace ex-4-2
```

Create a credentials file.

```bash
cat > credentials.txt <<'EOF'
username=admin
password=secretpassword
EOF
```

**Task:**

Create a kustomization.yaml that generates a Secret named `app-credentials` from the credentials.txt file. Apply with namespace ex-4-2.

**Verification:**

```bash
# secret should exist
kubectl get secret -n ex-4-2 | grep app-credentials

# should have file content (base64 encoded)
kubectl get secret -n ex-4-2 -o jsonpath='{.items[0].data}'; echo
```

Expected: Secret with credentials.txt data.

-----

### Exercise 4.3

**Objective:** Use generator behavior options.

**Setup:**

```bash
mkdir -p ~/kustomize-patches/ex-4-3
cd ~/kustomize-patches/ex-4-3
kubectl create namespace ex-4-3
```

**Task:**

Create a kustomization.yaml that generates a ConfigMap named `stable-config` with literal SETTING=value, but disable the name suffix hash so the ConfigMap is named exactly `stable-config`. Apply with namespace ex-4-3.

**Verification:**

```bash
# configmap should have exact name (no hash)
kubectl get configmap stable-config -n ex-4-3

# should not have hash suffix
kubectl get configmap -n ex-4-3 --no-headers | grep -c stable-config-
```

Expected: ConfigMap named exactly `stable-config`.

-----

## Level 5: Complex Patching

### Exercise 5.1

**Objective:** Apply multiple patches to the same resource.

**Setup:**

```bash
mkdir -p ~/kustomize-patches/ex-5-1
cd ~/kustomize-patches/ex-5-1
kubectl create namespace ex-5-1
```

Create the base deployment.

```bash
cat > deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multipatched
spec:
  replicas: 1
  selector:
    matchLabels:
      app: multipatched
  template:
    metadata:
      labels:
        app: multipatched
    spec:
      containers:
      - name: multipatched
        image: nginx:1.25
EOF
```

**Task:**

Create three separate patches: 1) Change replicas to 3, 2) Add environment variable ENV=production, 3) Add resource limits (memory: 256Mi). Apply all three patches to the same deployment.

**Verification:**

```bash
# 3 replicas
kubectl get deployment multipatched -n ex-5-1 -o jsonpath='{.spec.replicas}'; echo

# ENV variable
kubectl get deployment multipatched -n ex-5-1 -o jsonpath='{.spec.template.spec.containers[0].env}'; echo

# resource limits
kubectl get deployment multipatched -n ex-5-1 -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'; echo
```

Expected: 3 replicas, ENV=production, memory limit 256Mi.

-----

### Exercise 5.2

**Objective:** Debug a complex patch chain.

**Setup:**

```bash
mkdir -p ~/kustomize-patches/ex-5-2
cd ~/kustomize-patches/ex-5-2
kubectl create namespace ex-5-2
```

Create the base and patches.

```bash
cat > deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: complex
spec:
  replicas: 1
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

cat > patch1.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: complex
spec:
  replicas: 2
EOF

cat > patch2.yaml <<'EOF'
- op: add
  path: /spec/template/spec/containers/0/env
  value:
  - name: DEBUG
    value: "true"
EOF

cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-5-2

patches:
- path: patch1.yaml
- target:
    kind: Deployment
    name: wrongname
  path: patch2.yaml
EOF
```

**Task:**

The second patch is not being applied. Debug and fix the kustomization.

**Verification:**

```bash
# 2 replicas
kubectl apply -k ~/kustomize-patches/ex-5-2
kubectl get deployment complex -n ex-5-2 -o jsonpath='{.spec.replicas}'; echo

# DEBUG env var
kubectl get deployment complex -n ex-5-2 -o jsonpath='{.spec.template.spec.containers[0].env}'; echo
```

Expected: 2 replicas and DEBUG environment variable.

-----

### Exercise 5.3

**Objective:** Design a complete patch strategy for an application.

**Setup:**

```bash
mkdir -p ~/kustomize-patches/ex-5-3
cd ~/kustomize-patches/ex-5-3
kubectl create namespace ex-5-3
```

**Task:**

Create a deployment for a web application with nginx:1.25. Then create a complete kustomization that: 1) Changes replicas to 3, 2) Adds environment variables APP_NAME=myapp and VERSION=1.0, 3) Adds resource requests and limits, 4) Uses the images transformer to update to nginx:1.26, 5) Generates a ConfigMap with application settings. Apply with namespace ex-5-3.

**Verification:**

```bash
# 3 replicas
kubectl get deployment -n ex-5-3 -o jsonpath='{.items[0].spec.replicas}'; echo

# nginx:1.26
kubectl get deployment -n ex-5-3 -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'; echo

# env vars
kubectl get deployment -n ex-5-3 -o jsonpath='{.items[0].spec.template.spec.containers[0].env}'; echo

# configmap exists
kubectl get configmap -n ex-5-3
```

Expected: Complete application with all modifications applied.

-----

## Cleanup

Remove all exercise namespaces and files.

```bash
for i in 1 2 3 4 5; do
  for j in 1 2 3; do
    kubectl delete namespace ex-${i}-${j} --ignore-not-found --wait=false
  done
done
rm -rf ~/kustomize-patches
```

## Key Takeaways

After completing these exercises, you should be comfortable with creating strategic merge patches, creating JSON 6902 patches, using inline patches, using the images transformer, generating ConfigMaps from literals and files, generating Secrets, debugging patch errors, and combining multiple patches and generators.
