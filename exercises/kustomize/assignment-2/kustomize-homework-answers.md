# Patches and Transformers Homework Answers

This file contains complete solutions for all 15 exercises in `kustomize-homework.md`, along with explanations and a common mistakes section.

-----

## Exercise 1.1 Solution

Create the patch.

```bash
cat > ~/kustomize-patches/ex-1-1/replica-patch.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 3
EOF
```

Create the kustomization.

```bash
cat > ~/kustomize-patches/ex-1-1/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-1-1

patches:
- path: replica-patch.yaml
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-patches/ex-1-1
```

Strategic merge patches must include metadata.name to match the target resource.

-----

## Exercise 1.2 Solution

Create the patch.

```bash
cat > ~/kustomize-patches/ex-1-2/env-patch.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  template:
    spec:
      containers:
      - name: api
        env:
        - name: LOG_LEVEL
          value: debug
        - name: ENVIRONMENT
          value: development
EOF
```

Create the kustomization.

```bash
cat > ~/kustomize-patches/ex-1-2/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-1-2

patches:
- path: env-patch.yaml
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-patches/ex-1-2
```

-----

## Exercise 1.3 Solution

Create the patch.

```bash
cat > ~/kustomize-patches/ex-1-3/resources-patch.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  template:
    spec:
      containers:
      - name: backend
        resources:
          requests:
            memory: 64Mi
            cpu: 50m
          limits:
            memory: 128Mi
            cpu: 100m
EOF
```

Create the kustomization.

```bash
cat > ~/kustomize-patches/ex-1-3/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-1-3

patches:
- path: resources-patch.yaml
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-patches/ex-1-3
```

-----

## Exercise 2.1 Solution

Create the JSON patch.

```bash
cat > ~/kustomize-patches/ex-2-1/json-patch.yaml <<'EOF'
- op: replace
  path: /spec/replicas
  value: 4
EOF
```

Create the kustomization.

```bash
cat > ~/kustomize-patches/ex-2-1/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-2-1

patches:
- target:
    kind: Deployment
    name: service
  path: json-patch.yaml
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-patches/ex-2-1
```

JSON 6902 patches require a target specification separate from the patch content.

-----

## Exercise 2.2 Solution

Create the kustomization.

```bash
cat > ~/kustomize-patches/ex-2-2/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-2-2

images:
- name: nginx
  newTag: "1.26"
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-patches/ex-2-2
```

The images transformer is cleaner than patches for image changes.

-----

## Exercise 2.3 Solution

Create the kustomization.

```bash
cat > ~/kustomize-patches/ex-2-3/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-2-3

images:
- name: httpd
  newTag: "2.4.58"
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-patches/ex-2-3
```

The name field in images matches the image name without the tag.

-----

## Exercise 3.1 Solution

The patch has metadata.name: wrongname but the deployment is named myapp. Fix by changing the patch name.

```bash
cat > ~/kustomize-patches/ex-3-1/patch.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 5
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-patches/ex-3-1
```

Strategic merge patches must have the correct metadata.name to match the target.

-----

## Exercise 3.2 Solution

The JSON path is /spec/replica but should be /spec/replicas (plural). Fix the path.

```bash
cat > ~/kustomize-patches/ex-3-2/json-patch.yaml <<'EOF'
- op: replace
  path: /spec/replicas
  value: 3
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-patches/ex-3-2
```

JSON paths must exactly match the field names in the resource.

-----

## Exercise 3.3 Solution

The patch targets name: backend but the deployment is named frontend. Fix the target.

```bash
cat > ~/kustomize-patches/ex-3-3/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-3-3

patches:
- target:
    kind: Deployment
    name: frontend
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 3
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-patches/ex-3-3
```

-----

## Exercise 4.1 Solution

Create the kustomization.

```bash
cat > ~/kustomize-patches/ex-4-1/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ex-4-1

configMapGenerator:
- name: app-config
  literals:
  - DATABASE_URL=localhost:5432
  - LOG_LEVEL=info
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-patches/ex-4-1
```

ConfigMapGenerator creates ConfigMaps with hash suffixes by default.

-----

## Exercise 4.2 Solution

Create the kustomization.

```bash
cat > ~/kustomize-patches/ex-4-2/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ex-4-2

secretGenerator:
- name: app-credentials
  files:
  - credentials.txt
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-patches/ex-4-2
```

SecretGenerator creates Secrets with base64-encoded data.

-----

## Exercise 4.3 Solution

Create the kustomization with options.

```bash
cat > ~/kustomize-patches/ex-4-3/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ex-4-3

configMapGenerator:
- name: stable-config
  literals:
  - SETTING=value
  options:
    disableNameSuffixHash: true
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-patches/ex-4-3
```

The options.disableNameSuffixHash prevents the hash suffix.

-----

## Exercise 5.1 Solution

Create the patches.

```bash
cat > ~/kustomize-patches/ex-5-1/replica-patch.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multipatched
spec:
  replicas: 3
EOF

cat > ~/kustomize-patches/ex-5-1/env-patch.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multipatched
spec:
  template:
    spec:
      containers:
      - name: multipatched
        env:
        - name: ENV
          value: production
EOF

cat > ~/kustomize-patches/ex-5-1/resources-patch.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multipatched
spec:
  template:
    spec:
      containers:
      - name: multipatched
        resources:
          limits:
            memory: 256Mi
EOF
```

Create the kustomization.

```bash
cat > ~/kustomize-patches/ex-5-1/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-5-1

patches:
- path: replica-patch.yaml
- path: env-patch.yaml
- path: resources-patch.yaml
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-patches/ex-5-1
```

Multiple patches are applied in order.

-----

## Exercise 5.2 Solution

The JSON patch targets name: wrongname but the deployment is named complex. Fix the target.

```bash
cat > ~/kustomize-patches/ex-5-2/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-5-2

patches:
- path: patch1.yaml
- target:
    kind: Deployment
    name: complex
  path: patch2.yaml
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-patches/ex-5-2
```

-----

## Exercise 5.3 Solution

Create the base deployment.

```bash
cat > ~/kustomize-patches/ex-5-3/deployment.yaml <<'EOF'
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

Create the patch.

```bash
cat > ~/kustomize-patches/ex-5-3/patch.yaml <<'EOF'
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
        - name: APP_NAME
          value: myapp
        - name: VERSION
          value: "1.0"
        resources:
          requests:
            memory: 64Mi
            cpu: 50m
          limits:
            memory: 128Mi
            cpu: 100m
EOF
```

Create the kustomization.

```bash
cat > ~/kustomize-patches/ex-5-3/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-5-3

patches:
- path: patch.yaml

images:
- name: nginx
  newTag: "1.26"

configMapGenerator:
- name: app-settings
  literals:
  - SETTING1=value1
  - SETTING2=value2
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-patches/ex-5-3
```

-----

## Common Mistakes

**Strategic merge not merging lists as expected.** When patching containers, you must specify the container name so Kustomize knows which container to patch. Without the name, a new container might be added instead.

**JSON 6902 path wrong.** JSON paths must exactly match the YAML structure. Use /spec/replicas not /spec/replica. Array indices are zero-based (/spec/template/spec/containers/0).

**Target not matching resource.** For JSON 6902 patches, the target kind and name must exactly match the resource. Typos cause patches to be silently ignored.

**Generator hash suffix unexpected.** By default, ConfigMap and Secret generators add a hash suffix to names. Use disableNameSuffixHash in options if you need a stable name.

**Patch file syntax errors.** Patches must be valid YAML. Strategic merge patches must include apiVersion, kind, and metadata.name to match the target.

**Forgetting to include container name.** When patching container-level fields (env, resources, etc.), include the container name in the patch so Kustomize matches the correct container.

-----

## Patch Types Comparison Cheat Sheet

| Feature | Strategic Merge | JSON 6902 |
|---------|-----------------|-----------|
| Syntax | Partial YAML | Operations list |
| Add field | Include field in patch | op: add |
| Modify field | Include field with new value | op: replace |
| Remove field | Cannot remove | op: remove |
| Array handling | Merge by name key | Index-based |
| Target specification | metadata.name in patch | Separate target block |
| Best for | Adding/modifying | Removing, precise control |
