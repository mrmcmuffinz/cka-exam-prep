# Overlays and Components Homework Answers

This file contains complete solutions for all 15 exercises in `kustomize-homework.md`, along with explanations and a common mistakes section.

-----

## Exercise 1.1 Solution

Create the base deployment.

```bash
cat > ~/kustomize-overlays/ex-1-1/base/deployment.yaml <<'EOF'
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

Create the base service.

```bash
cat > ~/kustomize-overlays/ex-1-1/base/service.yaml <<'EOF'
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
```

Create the kustomization.

```bash
cat > ~/kustomize-overlays/ex-1-1/base/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
EOF
```

-----

## Exercise 1.2 Solution

Create the dev overlay.

```bash
cat > ~/kustomize-overlays/ex-1-1/overlays/dev/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namespace: ex-1-2-dev

namePrefix: dev-
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-overlays/ex-1-1/overlays/dev
```

The path ../../base goes up two directories from overlays/dev to reach the base.

-----

## Exercise 1.3 Solution

Create base deployment.

```bash
cat > ~/kustomize-overlays/ex-1-3/base/deployment.yaml <<'EOF'
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

cat > ~/kustomize-overlays/ex-1-3/base/service.yaml <<'EOF'
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

cat > ~/kustomize-overlays/ex-1-3/base/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
EOF
```

Create overlay.

```bash
cat > ~/kustomize-overlays/ex-1-3/overlays/dev/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namespace: ex-1-3

commonLabels:
  tier: frontend
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-overlays/ex-1-3/overlays/dev
```

-----

## Exercise 2.1 Solution

Create base.

```bash
cat > ~/kustomize-overlays/ex-2-1/base/deployment.yaml <<'EOF'
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

cat > ~/kustomize-overlays/ex-2-1/base/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
EOF
```

Create dev overlay.

```bash
cat > ~/kustomize-overlays/ex-2-1/overlays/dev/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namespace: ex-2-1-dev

commonLabels:
  env: dev
EOF
```

Create prod overlay.

```bash
cat > ~/kustomize-overlays/ex-2-1/overlays/prod/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namespace: ex-2-1-prod

commonLabels:
  env: prod

patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: app
    spec:
      replicas: 3
EOF
```

Apply both.

```bash
kubectl apply -k ~/kustomize-overlays/ex-2-1/overlays/dev
kubectl apply -k ~/kustomize-overlays/ex-2-1/overlays/prod
```

-----

## Exercise 2.2 Solution

Create base.

```bash
cat > ~/kustomize-overlays/ex-2-2/base/deployment.yaml <<'EOF'
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

cat > ~/kustomize-overlays/ex-2-2/base/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
EOF
```

Create overlays.

```bash
cat > ~/kustomize-overlays/ex-2-2/overlays/dev/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namespace: webapp-dev

commonLabels:
  environment: development
EOF

cat > ~/kustomize-overlays/ex-2-2/overlays/prod/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namespace: webapp-prod

commonLabels:
  environment: production
EOF
```

Apply both.

```bash
kubectl apply -k ~/kustomize-overlays/ex-2-2/overlays/dev
kubectl apply -k ~/kustomize-overlays/ex-2-2/overlays/prod
```

-----

## Exercise 2.3 Solution

Create base.

```bash
cat > ~/kustomize-overlays/ex-2-3/base/deployment.yaml <<'EOF'
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

cat > ~/kustomize-overlays/ex-2-3/base/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
EOF
```

Create patch file.

```bash
cat > ~/kustomize-overlays/ex-2-3/overlays/prod/prod-patch.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: app
        env:
        - name: ENVIRONMENT
          value: production
        resources:
          limits:
            memory: 256Mi
            cpu: 200m
EOF
```

Create overlay.

```bash
cat > ~/kustomize-overlays/ex-2-3/overlays/prod/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namespace: ex-2-3

patches:
- path: prod-patch.yaml
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-overlays/ex-2-3/overlays/prod
```

-----

## Exercise 3.1 Solution

The path ../base is wrong because the overlay is in overlays/dev, so it needs to go up two levels. Fix to ../../base.

```bash
cat > ~/kustomize-overlays/ex-3-1/overlays/dev/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namespace: ex-3-1
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-overlays/ex-3-1/overlays/dev
```

-----

## Exercise 3.2 Solution

The patch targets name: wrongname but the deployment is named webapp. Fix the patch.

```bash
cat > ~/kustomize-overlays/ex-3-2/overlays/dev/patch.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 5
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-overlays/ex-3-2/overlays/dev
```

-----

## Exercise 3.3 Solution

The namespace transformer should override the hardcoded namespace. If it does not work as expected, remove the namespace from the base deployment.

```bash
cat > ~/kustomize-overlays/ex-3-3/base/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: namespaced
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
```

Apply.

```bash
kubectl apply -k ~/kustomize-overlays/ex-3-3/overlays/dev
```

Actually, the namespace transformer does override hardcoded namespaces in namespaced resources. The original setup should work.

-----

## Exercise 4.1 Solution

Create the component.

```bash
cat > ~/kustomize-overlays/ex-4-1/components/logging/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: app
      annotations:
        logging.enabled: "true"
EOF
```

Create the overlay.

```bash
cat > ~/kustomize-overlays/ex-4-1/overlays/prod/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

components:
- ../../components/logging

namespace: ex-4-1
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-overlays/ex-4-1/overlays/prod
```

-----

## Exercise 4.2 Solution

Create metrics component.

```bash
cat > ~/kustomize-overlays/ex-4-2/components/metrics/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: secure-app
      annotations:
        metrics.enabled: "true"
EOF
```

Create security component.

```bash
cat > ~/kustomize-overlays/ex-4-2/components/security/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: secure-app
      annotations:
        security.hardened: "true"
EOF
```

Create overlay with both.

```bash
cat > ~/kustomize-overlays/ex-4-2/overlays/prod/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

components:
- ../../components/metrics
- ../../components/security

namespace: ex-4-2
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-overlays/ex-4-2/overlays/prod
```

-----

## Exercise 4.3 Solution

Create HA component.

```bash
cat > ~/kustomize-overlays/ex-4-3/components/ha/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: webapp
      annotations:
        ha.enabled: "true"
    spec:
      replicas: 3
EOF
```

Create overlay with component and additional patch.

```bash
cat > ~/kustomize-overlays/ex-4-3/overlays/prod/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

components:
- ../../components/ha

namespace: ex-4-3

patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: webapp
    spec:
      template:
        spec:
          containers:
          - name: webapp
            env:
            - name: ENVIRONMENT
              value: production
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-overlays/ex-4-3/overlays/prod
```

-----

## Exercise 5.1 Solution

Create full structure.

```bash
mkdir -p ~/kustomize-overlays/ex-5-1/{base,overlays/dev,overlays/prod}

cat > ~/kustomize-overlays/ex-5-1/base/deployment.yaml <<'EOF'
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

cat > ~/kustomize-overlays/ex-5-1/base/service.yaml <<'EOF'
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

cat > ~/kustomize-overlays/ex-5-1/base/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
EOF

cat > ~/kustomize-overlays/ex-5-1/overlays/dev/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namespace: myapp-dev

patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: webapp
    spec:
      template:
        spec:
          containers:
          - name: webapp
            env:
            - name: DEV
              value: "true"
EOF

cat > ~/kustomize-overlays/ex-5-1/overlays/prod/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namespace: myapp-prod

patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: webapp
    spec:
      replicas: 3
      template:
        spec:
          containers:
          - name: webapp
            env:
            - name: PROD
              value: "true"
EOF
```

Apply both.

```bash
kubectl apply -k ~/kustomize-overlays/ex-5-1/overlays/dev
kubectl apply -k ~/kustomize-overlays/ex-5-1/overlays/prod
```

-----

## Exercise 5.2 Solution

Two issues: base path is ../base (should be ../../base) and component patch targets name: wrong (should be complex).

Fix component.

```bash
cat > ~/kustomize-overlays/ex-5-2/components/feature/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: complex
    spec:
      replicas: 5
EOF
```

Fix overlay.

```bash
cat > ~/kustomize-overlays/ex-5-2/overlays/prod/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

components:
- ../../components/feature

namespace: ex-5-2
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-overlays/ex-5-2/overlays/prod
```

-----

## Exercise 5.3 Solution

Create complete structure.

```bash
mkdir -p ~/kustomize-overlays/ex-5-3/{base,overlays/prod,components/monitoring,components/security}

cat > ~/kustomize-overlays/ex-5-3/base/deployment.yaml <<'EOF'
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

cat > ~/kustomize-overlays/ex-5-3/base/service.yaml <<'EOF'
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

cat > ~/kustomize-overlays/ex-5-3/base/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
EOF

cat > ~/kustomize-overlays/ex-5-3/components/monitoring/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: webapp
    spec:
      template:
        metadata:
          annotations:
            prometheus.io/scrape: "true"
            prometheus.io/port: "80"
EOF

cat > ~/kustomize-overlays/ex-5-3/components/security/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: webapp
    spec:
      template:
        spec:
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
EOF

cat > ~/kustomize-overlays/ex-5-3/overlays/prod/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

components:
- ../../components/monitoring
- ../../components/security

namespace: production

patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: webapp
    spec:
      replicas: 3
      template:
        spec:
          containers:
          - name: webapp
            resources:
              limits:
                memory: 256Mi
                cpu: 200m
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-overlays/ex-5-3/overlays/prod
```

-----

## Common Mistakes

**Relative path from overlay wrong.** Paths are relative to the kustomization.yaml file. From overlays/dev/, you need ../../base to reach the base directory.

**Patch in overlay not finding resource.** The patch must have the correct metadata.name to match resources from the base.

**Component not being included.** Verify the components path is correct and the component has kind: Component with the right apiVersion.

**Namespace transformer conflicts.** The namespace transformer overrides namespaces, but watch for cluster-scoped resources that should not have namespaces.

**Resource duplication.** Do not include the same resource in both base and overlay, or it will be duplicated.

-----

## Overlay Structure Cheat Sheet

```
myapp/
  base/
    deployment.yaml
    service.yaml
    kustomization.yaml      # lists resources only
  overlays/
    dev/
      kustomization.yaml    # resources: [../../base], namespace: dev, patches
    prod/
      kustomization.yaml    # resources: [../../base], namespace: prod, patches
  components/
    monitoring/
      kustomization.yaml    # kind: Component, patches for monitoring
    security/
      kustomization.yaml    # kind: Component, patches for security
```
