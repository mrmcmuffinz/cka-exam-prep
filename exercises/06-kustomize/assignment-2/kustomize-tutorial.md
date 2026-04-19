# Patches and Transformers Tutorial

This tutorial covers advanced Kustomize features for modifying resources. You will learn strategic merge patches for merging changes into resources, JSON 6902 patches for precise path-based modifications, inline patches for simple changes, image transformers for updating container images, and ConfigMap/Secret generators for creating configuration resources.

All tutorial resources use a dedicated namespace called `tutorial-kustomize` so they will not collide with anything the exercises create.

## Prerequisites

Verify your cluster is up and kubectl is working.

```bash
kubectl get nodes
kubectl cluster-info
```

Create the tutorial namespace and working directory.

```bash
kubectl create namespace tutorial-kustomize
mkdir -p ~/kustomize-patches-tutorial
cd ~/kustomize-patches-tutorial
```

## Part 1: Strategic Merge Patches

Strategic merge patches work by merging a partial resource definition into the original resource. They are the most common and intuitive patch type.

### Creating a Base Deployment

First, create a base deployment.

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
        ports:
        - containerPort: 80
EOF
```

### Simple Patch: Changing Replicas

Create a patch that changes the replica count.

```bash
cat > replica-patch.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 3
EOF
```

The patch only includes the fields you want to change. You must include enough identifying information (apiVersion, kind, metadata.name) for Kustomize to find the target resource.

Create the kustomization.

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

patches:
- path: replica-patch.yaml
EOF
```

Build to see the result.

```bash
kubectl kustomize .
```

The deployment now has 3 replicas. The patch was merged into the original.

### Patch: Adding Environment Variables

Create a patch that adds environment variables to the container.

```bash
cat > env-patch.yaml <<'EOF'
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
        - name: LOG_LEVEL
          value: debug
        - name: ENVIRONMENT
          value: development
EOF
```

Update the kustomization to include both patches.

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

patches:
- path: replica-patch.yaml
- path: env-patch.yaml
EOF
```

Build to see both patches applied.

```bash
kubectl kustomize .
```

The deployment now has 3 replicas and two environment variables.

### Patch: Adding Resources

Create a patch that adds resource requests and limits.

```bash
cat > resources-patch.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  template:
    spec:
      containers:
      - name: webapp
        resources:
          requests:
            memory: 128Mi
            cpu: 100m
          limits:
            memory: 256Mi
            cpu: 200m
EOF
```

Add to kustomization.

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

patches:
- path: replica-patch.yaml
- path: env-patch.yaml
- path: resources-patch.yaml
EOF
```

Build and verify all three patches are applied.

```bash
kubectl kustomize .
```

## Part 2: JSON 6902 Patches

JSON 6902 patches (also called JSON patches) provide precise control over modifications using operations like add, remove, replace, move, copy, and test.

### Basic JSON Patch

Create a JSON patch to change replicas.

```bash
cat > json-patch.yaml <<'EOF'
- op: replace
  path: /spec/replicas
  value: 5
EOF
```

Update kustomization to use JSON patch.

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

patches:
- target:
    kind: Deployment
    name: webapp
  path: json-patch.yaml
EOF
```

The target field specifies which resource to patch. The path field points to the JSON patch file.

Build to see the result.

```bash
kubectl kustomize .
```

### JSON Patch Operations

JSON patches support these operations.

Add a new field.

```bash
cat > add-patch.yaml <<'EOF'
- op: add
  path: /metadata/labels/version
  value: v1
EOF
```

Remove a field.

```bash
cat > remove-patch.yaml <<'EOF'
- op: remove
  path: /spec/template/spec/containers/0/ports
EOF
```

Replace a value.

```bash
cat > replace-patch.yaml <<'EOF'
- op: replace
  path: /spec/template/spec/containers/0/image
  value: nginx:1.26
EOF
```

### Path Syntax

JSON patch paths use JSON Pointer syntax. Array indices are zero-based.

/spec/replicas - the replicas field
/spec/template/spec/containers/0 - first container
/spec/template/spec/containers/0/image - first container's image
/metadata/labels/app - the app label

### When to Use JSON Patches

Use JSON patches when you need to remove a field (strategic merge cannot delete), make very precise modifications, or work with resources that have unusual structures.

## Part 3: Inline Patches

Inline patches allow you to write the patch content directly in kustomization.yaml. This is convenient for small patches.

### Strategic Merge Inline

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: webapp
    spec:
      replicas: 4
EOF
```

The patch content is embedded directly in the kustomization.yaml using the patch field with a multi-line string.

### JSON Patch Inline

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

patches:
- target:
    kind: Deployment
    name: webapp
  patch: |-
    - op: replace
      path: /spec/replicas
      value: 6
EOF
```

Build to see the result.

```bash
kubectl kustomize .
```

Inline patches are best for simple, one-off changes where creating a separate file would be overkill.

## Part 4: Image Transformers

The images transformer changes container images without writing patches. This is cleaner than patching for image updates.

### Changing Image Tag

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

images:
- name: nginx
  newTag: "1.26"
EOF
```

Build to see the image change.

```bash
kubectl kustomize .
```

The image is now nginx:1.26 instead of nginx:1.25.

### Changing Image Name

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

images:
- name: nginx
  newName: my-registry/nginx
  newTag: "1.25"
EOF
```

This changes the image to my-registry/nginx:1.25. The name field matches the original image name (without tag).

### Using Digest

For immutable deployments, use a digest instead of a tag.

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

images:
- name: nginx
  digest: sha256:abc123...
EOF
```

## Part 5: ConfigMap and Secret Generators

Generators create ConfigMaps and Secrets from various sources. They automatically add hash suffixes to names and update references.

### ConfigMap from Literals

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

configMapGenerator:
- name: app-config
  literals:
  - LOG_LEVEL=info
  - DB_HOST=localhost
EOF
```

Build to see the generated ConfigMap.

```bash
kubectl kustomize .
```

Notice the ConfigMap name has a hash suffix (like app-config-abc123). This ensures that changes to the ConfigMap trigger pod rollouts.

### ConfigMap from Files

Create a config file.

```bash
cat > app.properties <<'EOF'
setting1=value1
setting2=value2
database.host=localhost
database.port=5432
EOF
```

Generate ConfigMap from file.

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

configMapGenerator:
- name: app-config
  files:
  - app.properties
EOF
```

Build to see the ConfigMap with file content.

```bash
kubectl kustomize .
```

### Secret Generator

Secrets work similarly to ConfigMaps.

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

secretGenerator:
- name: app-secrets
  literals:
  - DB_PASSWORD=secretpassword
  - API_KEY=myapikey
EOF
```

Build to see the generated Secret.

```bash
kubectl kustomize .
```

The values are base64 encoded automatically.

### Generator Options

Control generator behavior.

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

configMapGenerator:
- name: app-config
  literals:
  - LOG_LEVEL=info
  options:
    disableNameSuffixHash: true

generatorOptions:
  labels:
    generated: "true"
EOF
```

The disableNameSuffixHash option removes the hash suffix. The generatorOptions apply to all generators.

## Part 6: Combining Patches with Other Features

You can use patches, images, and generators together.

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: tutorial-kustomize

patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: webapp
    spec:
      replicas: 3

images:
- name: nginx
  newTag: "1.26"

configMapGenerator:
- name: app-config
  literals:
  - ENVIRONMENT=production
EOF
```

Build and apply.

```bash
kubectl kustomize .
kubectl apply -k . -n tutorial-kustomize
```

Verify the deployment.

```bash
kubectl get deployment,configmap -n tutorial-kustomize
```

## Cleanup

Remove tutorial resources.

```bash
kubectl delete -k . -n tutorial-kustomize --ignore-not-found
kubectl delete namespace tutorial-kustomize
cd ~
rm -rf ~/kustomize-patches-tutorial
```

## Reference Commands

| Task | Command |
|------|---------|
| Build kustomization | `kubectl kustomize <directory>` |
| Apply kustomization | `kubectl apply -k <directory>` |

## Patch Types Comparison

| Type | Use Case | Syntax |
|------|----------|--------|
| Strategic Merge | Add/modify fields, intuitive YAML | Partial resource YAML |
| JSON 6902 | Remove fields, precise paths | Operations (add, remove, replace) |
| Inline | Small, one-off changes | Embedded in kustomization.yaml |
| Images | Change container images | images transformer |

## kustomization.yaml Quick Reference

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

# Strategic merge patch from file
patches:
- path: patch.yaml

# JSON 6902 patch
patches:
- target:
    kind: Deployment
    name: webapp
  path: json-patch.yaml

# Inline strategic merge
patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: webapp
    spec:
      replicas: 3

# Image transformer
images:
- name: nginx
  newTag: "1.26"

# ConfigMap generator
configMapGenerator:
- name: config
  literals:
  - KEY=value

# Secret generator
secretGenerator:
- name: secret
  literals:
  - PASSWORD=secret
```
