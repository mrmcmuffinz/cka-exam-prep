# Overlays and Components Homework

This homework file contains 15 progressive exercises organized into five difficulty levels. The exercises assume you have worked through `kustomize-tutorial.md` and completed assignments 1 and 2. Each exercise uses its own directory structure. Complete the exercises in order.

## Setup

Verify that your cluster is running.

```bash
kubectl get nodes
```

Create a base working directory for all exercises.

```bash
mkdir -p ~/kustomize-overlays
cd ~/kustomize-overlays
```

If you want to clean up from a previous attempt, run the following.

```bash
for i in 1 2 3 4 5; do
  for j in 1 2 3; do
    kubectl delete namespace ex-${i}-${j}-dev --ignore-not-found --wait=false
    kubectl delete namespace ex-${i}-${j}-prod --ignore-not-found --wait=false
    kubectl delete namespace ex-${i}-${j} --ignore-not-found --wait=false
  done
done
rm -rf ~/kustomize-overlays/*
```

-----

## Level 1: Base and Overlays

### Exercise 1.1

**Objective:** Create a base kustomization.

**Setup:**

```bash
mkdir -p ~/kustomize-overlays/ex-1-1/base
cd ~/kustomize-overlays/ex-1-1
```

**Task:**

Create a base directory with a deployment (nginx:1.25, 1 replica) and service (ClusterIP). Create the kustomization.yaml that includes both resources. Verify the base builds correctly.

**Verification:**

```bash
# base should build
kubectl kustomize ~/kustomize-overlays/ex-1-1/base | grep "kind: Deployment"
kubectl kustomize ~/kustomize-overlays/ex-1-1/base | grep "kind: Service"
```

Expected: Both Deployment and Service in output.

-----

### Exercise 1.2

**Objective:** Create a dev overlay.

**Setup:**

Use the base from exercise 1.1.

```bash
mkdir -p ~/kustomize-overlays/ex-1-1/overlays/dev
kubectl create namespace ex-1-2-dev
```

**Task:**

Create a dev overlay that references the base, sets namespace to ex-1-2-dev, and adds namePrefix "dev-". Apply the overlay.

**Verification:**

```bash
# deployment should exist with prefix
kubectl get deployment -n ex-1-2-dev | grep dev-
```

Expected: Deployment with dev- prefix in ex-1-2-dev namespace.

-----

### Exercise 1.3

**Objective:** Create base and overlay in one exercise.

**Setup:**

```bash
mkdir -p ~/kustomize-overlays/ex-1-3/{base,overlays/dev}
cd ~/kustomize-overlays/ex-1-3
kubectl create namespace ex-1-3
```

**Task:**

Create a complete structure: base with deployment and service, and a dev overlay that references the base, sets namespace to ex-1-3, and adds commonLabels "tier: frontend". Build and apply.

**Verification:**

```bash
# deployment should have label
kubectl get deployment -n ex-1-3 -o jsonpath='{.items[0].metadata.labels.tier}'; echo
```

Expected: Label "tier: frontend" on deployment.

-----

## Level 2: Environment Configurations

### Exercise 2.1

**Objective:** Create dev and prod overlays with different settings.

**Setup:**

```bash
mkdir -p ~/kustomize-overlays/ex-2-1/{base,overlays/dev,overlays/prod}
cd ~/kustomize-overlays/ex-2-1
kubectl create namespace ex-2-1-dev
kubectl create namespace ex-2-1-prod
```

**Task:**

Create a base with a deployment (nginx:1.25, 1 replica). Create dev overlay (namespace ex-2-1-dev, 1 replica, label env=dev) and prod overlay (namespace ex-2-1-prod, 3 replicas, label env=prod). Apply both overlays.

**Verification:**

```bash
# dev has 1 replica
kubectl get deployment -n ex-2-1-dev -o jsonpath='{.items[0].spec.replicas}'; echo

# prod has 3 replicas
kubectl get deployment -n ex-2-1-prod -o jsonpath='{.items[0].spec.replicas}'; echo
```

Expected: Dev with 1 replica, prod with 3 replicas.

-----

### Exercise 2.2

**Objective:** Configure environment-specific namespaces.

**Setup:**

```bash
mkdir -p ~/kustomize-overlays/ex-2-2/{base,overlays/dev,overlays/prod}
cd ~/kustomize-overlays/ex-2-2
kubectl create namespace webapp-dev
kubectl create namespace webapp-prod
```

**Task:**

Create a base with a deployment named "webapp". Create overlays that deploy to webapp-dev and webapp-prod namespaces respectively. Each overlay should add an appropriate environment label.

**Verification:**

```bash
# deployment in webapp-dev
kubectl get deployment webapp -n webapp-dev

# deployment in webapp-prod
kubectl get deployment webapp -n webapp-prod
```

Expected: Same deployment name in different namespaces.

-----

### Exercise 2.3

**Objective:** Layer patches in overlay.

**Setup:**

```bash
mkdir -p ~/kustomize-overlays/ex-2-3/{base,overlays/prod}
cd ~/kustomize-overlays/ex-2-3
kubectl create namespace ex-2-3
```

**Task:**

Create a base deployment. Create a prod overlay that: 1) Sets namespace to ex-2-3, 2) Changes replicas to 3, 3) Adds environment variable ENVIRONMENT=production, 4) Adds resource limits. Use a separate patch file for the patches.

**Verification:**

```bash
# 3 replicas
kubectl get deployment -n ex-2-3 -o jsonpath='{.items[0].spec.replicas}'; echo

# environment variable
kubectl get deployment -n ex-2-3 -o jsonpath='{.items[0].spec.template.spec.containers[0].env}'; echo

# resource limits
kubectl get deployment -n ex-2-3 -o jsonpath='{.items[0].spec.template.spec.containers[0].resources.limits}'; echo
```

Expected: All three modifications applied.

-----

## Level 3: Debugging Overlay Issues

### Exercise 3.1

**Objective:** Debug a base path issue.

**Setup:**

```bash
mkdir -p ~/kustomize-overlays/ex-3-1/{base,overlays/dev}
cd ~/kustomize-overlays/ex-3-1
kubectl create namespace ex-3-1
```

Create the base.

```bash
cat > base/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
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
      - name: app
        image: nginx:1.25
EOF

cat > base/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
EOF
```

Create a broken overlay.

```bash
cat > overlays/dev/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../base

namespace: ex-3-1
EOF
```

**Task:**

The overlay fails to build because the path to base is wrong. Fix the kustomization.yaml and apply.

**Verification:**

```bash
# should build
kubectl kustomize ~/kustomize-overlays/ex-3-1/overlays/dev

# should apply
kubectl apply -k ~/kustomize-overlays/ex-3-1/overlays/dev
kubectl get deployment app -n ex-3-1
```

Expected: Overlay builds and deployment is created.

-----

### Exercise 3.2

**Objective:** Debug a patch not applying in overlay.

**Setup:**

```bash
mkdir -p ~/kustomize-overlays/ex-3-2/{base,overlays/dev}
cd ~/kustomize-overlays/ex-3-2
kubectl create namespace ex-3-2
```

Create the base.

```bash
cat > base/deployment.yaml <<'EOF'
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

cat > base/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
EOF
```

Create a broken overlay with patch.

```bash
cat > overlays/dev/patch.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wrongname
spec:
  replicas: 5
EOF

cat > overlays/dev/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namespace: ex-3-2

patches:
- path: patch.yaml
EOF
```

**Task:**

The patch is not being applied because it targets the wrong name. Fix the patch file and apply.

**Verification:**

```bash
# should have 5 replicas
kubectl apply -k ~/kustomize-overlays/ex-3-2/overlays/dev
kubectl get deployment webapp -n ex-3-2 -o jsonpath='{.spec.replicas}'; echo
```

Expected: 5 replicas.

-----

### Exercise 3.3

**Objective:** Debug a namespace conflict.

**Setup:**

```bash
mkdir -p ~/kustomize-overlays/ex-3-3/{base,overlays/dev}
cd ~/kustomize-overlays/ex-3-3
kubectl create namespace correct-ns
```

Create a base with a hardcoded namespace.

```bash
cat > base/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: namespaced
  namespace: wrong-ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: namespaced
  template:
    metadata:
      labels:
        app: namespaced
    spec:
      containers:
      - name: namespaced
        image: nginx:1.25
EOF

cat > base/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
EOF

cat > overlays/dev/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namespace: correct-ns
EOF
```

**Task:**

The overlay sets namespace to correct-ns, but the base has a hardcoded namespace. The namespace transformer should override it, but verify by building. If needed, modify the base to not hardcode the namespace.

**Verification:**

```bash
# check what namespace is in output
kubectl kustomize ~/kustomize-overlays/ex-3-3/overlays/dev | grep "namespace:"

# apply and verify
kubectl apply -k ~/kustomize-overlays/ex-3-3/overlays/dev
kubectl get deployment namespaced -n correct-ns
```

Expected: Deployment in correct-ns namespace.

-----

## Level 4: Components

### Exercise 4.1

**Objective:** Create a reusable component.

**Setup:**

```bash
mkdir -p ~/kustomize-overlays/ex-4-1/{base,overlays/prod,components/logging}
cd ~/kustomize-overlays/ex-4-1
kubectl create namespace ex-4-1
```

Create a base deployment.

```bash
cat > base/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
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
      - name: app
        image: nginx:1.25
EOF

cat > base/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
EOF
```

**Task:**

Create a logging component that adds annotation "logging.enabled: true" to the deployment. Create a prod overlay that uses the base and includes the logging component. Apply with namespace ex-4-1.

**Verification:**

```bash
# should have annotation
kubectl get deployment app -n ex-4-1 -o jsonpath='{.metadata.annotations}'; echo
```

Expected: logging.enabled annotation present.

-----

### Exercise 4.2

**Objective:** Include multiple components in overlay.

**Setup:**

```bash
mkdir -p ~/kustomize-overlays/ex-4-2/{base,overlays/prod,components/metrics,components/security}
cd ~/kustomize-overlays/ex-4-2
kubectl create namespace ex-4-2
```

Create a base deployment.

```bash
cat > base/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      containers:
      - name: secure-app
        image: nginx:1.25
EOF

cat > base/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
EOF
```

**Task:**

Create a metrics component (adds annotation metrics.enabled: true) and a security component (adds annotation security.hardened: true). Create a prod overlay that includes both components. Apply with namespace ex-4-2.

**Verification:**

```bash
# should have both annotations
kubectl get deployment secure-app -n ex-4-2 -o jsonpath='{.metadata.annotations}'; echo
```

Expected: Both metrics.enabled and security.hardened annotations.

-----

### Exercise 4.3

**Objective:** Combine component with patches.

**Setup:**

```bash
mkdir -p ~/kustomize-overlays/ex-4-3/{base,overlays/prod,components/ha}
cd ~/kustomize-overlays/ex-4-3
kubectl create namespace ex-4-3
```

Create a base deployment.

```bash
cat > base/deployment.yaml <<'EOF'
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

cat > base/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
EOF
```

**Task:**

Create an HA (high availability) component that sets replicas to 3 and adds annotation ha.enabled: true. Create a prod overlay that uses both the base, the HA component, and also adds its own patch for environment variable ENVIRONMENT=production. Apply with namespace ex-4-3.

**Verification:**

```bash
# 3 replicas from component
kubectl get deployment webapp -n ex-4-3 -o jsonpath='{.spec.replicas}'; echo

# ha annotation from component
kubectl get deployment webapp -n ex-4-3 -o jsonpath='{.metadata.annotations}'; echo

# env var from overlay patch
kubectl get deployment webapp -n ex-4-3 -o jsonpath='{.spec.template.spec.containers[0].env}'; echo
```

Expected: 3 replicas, HA annotation, and ENVIRONMENT env var.

-----

## Level 5: Complete Application Structure

### Exercise 5.1

**Objective:** Design a multi-environment structure.

**Setup:**

```bash
mkdir -p ~/kustomize-overlays/ex-5-1
cd ~/kustomize-overlays/ex-5-1
kubectl create namespace myapp-dev
kubectl create namespace myapp-prod
```

**Task:**

Create a complete structure for a web application: base with deployment (nginx, 1 replica) and service, dev overlay (namespace myapp-dev, 1 replica, env DEV=true), and prod overlay (namespace myapp-prod, 3 replicas, env PROD=true). Apply both overlays.

**Verification:**

```bash
# dev deployed
kubectl get deployment -n myapp-dev

# prod deployed with 3 replicas
kubectl get deployment -n myapp-prod -o jsonpath='{.items[0].spec.replicas}'; echo
```

Expected: Both environments deployed with correct configurations.

-----

### Exercise 5.2

**Objective:** Debug a complex overlay chain.

**Setup:**

```bash
mkdir -p ~/kustomize-overlays/ex-5-2/{base,overlays/prod,components/feature}
cd ~/kustomize-overlays/ex-5-2
kubectl create namespace ex-5-2
```

Create a complex setup with issues.

```bash
cat > base/deployment.yaml <<'EOF'
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

cat > base/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
EOF

cat > components/feature/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: wrong
    spec:
      replicas: 5
EOF

cat > overlays/prod/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../base

components:
- ../../components/feature

namespace: ex-5-2
EOF
```

**Task:**

The overlay has issues: base path is wrong and component patch targets wrong name. Fix all issues and apply.

**Verification:**

```bash
# should build
kubectl kustomize ~/kustomize-overlays/ex-5-2/overlays/prod

# should have 5 replicas
kubectl apply -k ~/kustomize-overlays/ex-5-2/overlays/prod
kubectl get deployment complex -n ex-5-2 -o jsonpath='{.spec.replicas}'; echo
```

Expected: 5 replicas after all fixes.

-----

### Exercise 5.3

**Objective:** Create a production-ready kustomization structure.

**Setup:**

```bash
mkdir -p ~/kustomize-overlays/ex-5-3
cd ~/kustomize-overlays/ex-5-3
kubectl create namespace production
```

**Task:**

Create a complete production-ready structure for a web application: base with deployment and service, components for monitoring (adds prometheus annotations) and security (adds security context), prod overlay that combines base with both components, sets namespace to production, sets 3 replicas, and adds resource limits. Apply and verify.

**Verification:**

```bash
# 3 replicas
kubectl get deployment -n production -o jsonpath='{.items[0].spec.replicas}'; echo

# prometheus annotations
kubectl get deployment -n production -o jsonpath='{.items[0].spec.template.metadata.annotations}'; echo

# security context
kubectl get deployment -n production -o jsonpath='{.items[0].spec.template.spec.securityContext}'; echo

# resource limits
kubectl get deployment -n production -o jsonpath='{.items[0].spec.template.spec.containers[0].resources.limits}'; echo
```

Expected: All production configurations applied.

-----

## Cleanup

Remove all exercise resources.

```bash
for ns in ex-1-2-dev ex-1-3 ex-2-1-dev ex-2-1-prod webapp-dev webapp-prod ex-2-3 ex-3-1 ex-3-2 correct-ns ex-4-1 ex-4-2 ex-4-3 myapp-dev myapp-prod ex-5-2 production; do
  kubectl delete namespace $ns --ignore-not-found --wait=false
done
rm -rf ~/kustomize-overlays
```

## Key Takeaways

After completing these exercises, you should be comfortable with creating base kustomizations, creating overlays that reference bases, using namespace transformers per environment, creating reusable components, combining components with overlays, debugging overlay path issues, debugging patch targeting issues, and designing production-ready kustomization structures.
