# Overlays and Components Tutorial

This tutorial covers advanced Kustomize composition patterns. You will learn how to structure base and overlay directories for environment management, create reusable components for partial configurations, and apply Kustomize best practices for maintainable deployments.

All tutorial resources use dedicated namespaces that will not collide with anything the exercises create.

## Prerequisites

Verify your cluster is up and kubectl is working.

```bash
kubectl get nodes
kubectl cluster-info
```

Create a working directory for this tutorial.

```bash
mkdir -p ~/kustomize-overlays-tutorial
cd ~/kustomize-overlays-tutorial
```

## Part 1: Base and Overlay Concept

The base/overlay pattern is Kustomize's approach to environment management. A base contains shared resources that are the same across all environments. Overlays customize the base for specific environments (dev, staging, production).

### Directory Structure

The standard structure looks like this.

```
myapp/
  base/
    deployment.yaml
    service.yaml
    kustomization.yaml
  overlays/
    dev/
      kustomization.yaml
    staging/
      kustomization.yaml
    prod/
      kustomization.yaml
```

### Creating the Base

Create the base directory with shared resources.

```bash
mkdir -p base
```

Create a deployment.

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
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: 64Mi
            cpu: 50m
EOF
```

Create a service.

```bash
cat > base/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: webapp
spec:
  selector:
    app: webapp
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF
```

Create the base kustomization.

```bash
cat > base/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
EOF
```

Verify the base builds correctly.

```bash
kubectl kustomize base
```

## Part 2: Creating Overlays

Overlays reference a base and add environment-specific customizations.

### Dev Overlay

Create the dev overlay directory.

```bash
mkdir -p overlays/dev
```

Create the dev kustomization that references the base and adds dev-specific settings.

```bash
cat > overlays/dev/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namespace: dev

namePrefix: dev-

commonLabels:
  environment: development

patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: webapp
    spec:
      replicas: 1
      template:
        spec:
          containers:
          - name: webapp
            env:
            - name: LOG_LEVEL
              value: debug
EOF
```

The key elements are: resources references the base using a relative path, namespace sets all resources to the dev namespace, namePrefix distinguishes dev resources, commonLabels tags everything as development, and the inline patch adds dev-specific settings.

Build and verify.

```bash
kubectl kustomize overlays/dev
```

### Prod Overlay

Create the production overlay with different settings.

```bash
mkdir -p overlays/prod

cat > overlays/prod/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namespace: prod

namePrefix: prod-

commonLabels:
  environment: production

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
            - name: LOG_LEVEL
              value: warn
            resources:
              requests:
                memory: 256Mi
                cpu: 200m
              limits:
                memory: 512Mi
                cpu: 500m
EOF
```

Production has 3 replicas, less verbose logging, and higher resource allocations.

Build and compare.

```bash
kubectl kustomize overlays/prod
```

### Applying Overlays

Create the namespaces and apply.

```bash
kubectl create namespace dev
kubectl create namespace prod

kubectl apply -k overlays/dev
kubectl apply -k overlays/prod
```

Verify both deployments.

```bash
kubectl get deployment -n dev
kubectl get deployment -n prod
```

## Part 3: Overlay Patches

Overlays can include patch files in addition to inline patches.

Create a separate patch file for the dev overlay.

```bash
cat > overlays/dev/debug-config.yaml <<'EOF'
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
        - name: DEBUG
          value: "true"
        - name: TRACE
          value: "true"
EOF
```

Update the dev kustomization to use the file.

```bash
cat > overlays/dev/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namespace: dev

namePrefix: dev-

commonLabels:
  environment: development

patches:
- path: debug-config.yaml
EOF
```

Build and verify the new patch is applied.

```bash
kubectl kustomize overlays/dev
```

## Part 4: Components

Components are reusable partial configurations that can be included in multiple overlays. They are useful for features that some environments need but others do not.

### Creating a Component

Create a components directory.

```bash
mkdir -p components/metrics
```

Create a metrics component that adds a metrics sidecar.

```bash
cat > components/metrics/kustomization.yaml <<'EOF'
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
            prometheus.io/port: "9090"
        spec:
          containers:
          - name: metrics-exporter
            image: prom/node-exporter:v1.7.0
            ports:
            - containerPort: 9090
EOF
```

Note that components use kind: Component and apiVersion: kustomize.config.k8s.io/v1alpha1.

### Using Components in Overlays

Update the prod overlay to include the metrics component.

```bash
cat > overlays/prod/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

components:
- ../../components/metrics

namespace: prod

namePrefix: prod-

commonLabels:
  environment: production

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
            - name: LOG_LEVEL
              value: warn
            resources:
              requests:
                memory: 256Mi
                cpu: 200m
              limits:
                memory: 512Mi
                cpu: 500m
EOF
```

Build and verify the metrics container is added.

```bash
kubectl kustomize overlays/prod
```

The output shows two containers: webapp and metrics-exporter.

### Multiple Components

Create another component for security settings.

```bash
mkdir -p components/security

cat > components/security/kustomization.yaml <<'EOF'
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
          containers:
          - name: webapp
            securityContext:
              readOnlyRootFilesystem: true
              allowPrivilegeEscalation: false
EOF
```

Include both components in prod.

```bash
cat > overlays/prod/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

components:
- ../../components/metrics
- ../../components/security

namespace: prod

namePrefix: prod-

commonLabels:
  environment: production

patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: webapp
    spec:
      replicas: 3
EOF
```

Build to see both components applied.

```bash
kubectl kustomize overlays/prod
```

## Part 5: Namespace Per Environment

A common pattern is to use namespace transformers to deploy the same application to different namespaces.

Update overlays to use consistent namespace patterns.

```bash
cat > overlays/dev/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

namespace: webapp-dev

commonLabels:
  environment: development
  app.kubernetes.io/part-of: webapp
EOF

cat > overlays/prod/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

components:
- ../../components/metrics
- ../../components/security

namespace: webapp-prod

commonLabels:
  environment: production
  app.kubernetes.io/part-of: webapp

patches:
- patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: webapp
    spec:
      replicas: 3
EOF
```

Now both environments have descriptive namespace names.

## Part 6: Best Practices

### Directory Organization

Keep bases minimal with only shared resources. Put environment-specific settings in overlays. Use components for optional features. Name directories clearly (base, overlays/dev, overlays/prod, components/feature).

### Documentation

Add README files to explain the structure.

```bash
cat > README.md <<'EOF'
# WebApp Kustomize Configuration

## Structure

- base/: Shared resources for all environments
- overlays/dev/: Development environment configuration
- overlays/prod/: Production environment configuration
- components/metrics/: Optional metrics sidecar
- components/security/: Security hardening settings

## Usage

Deploy to dev:
kubectl apply -k overlays/dev

Deploy to prod:
kubectl apply -k overlays/prod
EOF
```

### Version Control

Keep all kustomization files in version control. Base changes affect all environments. Review overlay changes carefully for environment-specific impact.

## Cleanup

Remove tutorial resources.

```bash
kubectl delete -k overlays/dev --ignore-not-found
kubectl delete -k overlays/prod --ignore-not-found
kubectl delete namespace dev --ignore-not-found
kubectl delete namespace prod --ignore-not-found
kubectl delete namespace webapp-dev --ignore-not-found
kubectl delete namespace webapp-prod --ignore-not-found
cd ~
rm -rf ~/kustomize-overlays-tutorial
```

## Reference Commands

| Task | Command |
|------|---------|
| Build overlay | `kubectl kustomize overlays/dev` |
| Apply overlay | `kubectl apply -k overlays/dev` |
| Delete overlay resources | `kubectl delete -k overlays/dev` |
| Build base only | `kubectl kustomize base` |

## Directory Structure Reference

```
myapp/
  base/
    deployment.yaml
    service.yaml
    kustomization.yaml
  overlays/
    dev/
      kustomization.yaml
      [patches...]
    staging/
      kustomization.yaml
      [patches...]
    prod/
      kustomization.yaml
      [patches...]
  components/
    metrics/
      kustomization.yaml
    security/
      kustomization.yaml
  README.md
```
