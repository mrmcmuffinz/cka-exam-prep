# Kustomize Fundamentals Tutorial

This tutorial introduces Kustomize, a template-free configuration management tool for Kubernetes. Unlike Helm, which uses templates with placeholders, Kustomize works by applying transformations to plain Kubernetes YAML files. You will learn the kustomization.yaml structure, how to reference resources, and how to use common transformers to customize your deployments.

All tutorial resources use a dedicated namespace called `tutorial-kustomize` so they will not collide with anything the exercises create.

## Prerequisites

Verify your cluster is up and kubectl is working.

```bash
kubectl get nodes
kubectl cluster-info
```

Create the tutorial namespace.

```bash
kubectl create namespace tutorial-kustomize
```

Create a working directory for this tutorial.

```bash
mkdir -p ~/kustomize-tutorial
cd ~/kustomize-tutorial
```

## Part 1: What is Kustomize?

Kustomize is a configuration management tool that is built into kubectl. It allows you to customize Kubernetes configurations without modifying the original YAML files. Instead, you create a kustomization.yaml file that describes what transformations to apply.

The key philosophy of Kustomize is template-free customization. Your base Kubernetes manifests remain valid YAML that you can apply directly with kubectl. Kustomize layers transformations on top without introducing template syntax like {{ .Values.replicas }}.

Kustomize is particularly useful for managing configurations across multiple environments (dev, staging, production) where you want to share base configurations but apply environment-specific changes.

## Part 2: kustomization.yaml Structure

The kustomization.yaml file is the heart of every Kustomize configuration. Let us create a simple example.

First, create a deployment manifest.

```bash
cat > deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
EOF
```

Now create a kustomization.yaml that references this deployment.

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
EOF
```

The structure is straightforward. The apiVersion and kind identify this as a Kustomization file. The resources field lists the Kubernetes manifests to include.

### Building the Kustomization

Use kubectl kustomize to see what the output would be.

```bash
kubectl kustomize .
```

The output is the deployment.yaml content, unchanged because we have not applied any transformers yet. The dot (.) refers to the current directory containing kustomization.yaml.

### Applying the Kustomization

Apply the kustomization to your cluster.

```bash
kubectl apply -k . -n tutorial-kustomize
```

The -k flag tells kubectl to build and apply the kustomization in the specified directory.

Verify the deployment was created.

```bash
kubectl get deployment -n tutorial-kustomize
```

## Part 3: Common Transformers

Transformers modify resources during the build process. Kustomize includes several built-in transformers.

### namePrefix and nameSuffix

Add a prefix or suffix to all resource names.

Update kustomization.yaml.

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namePrefix: dev-
nameSuffix: -v1
EOF
```

Build to see the result.

```bash
kubectl kustomize .
```

The deployment name is now `dev-nginx-v1`. This is useful for creating multiple instances of the same resources with different names.

### commonLabels

Add labels to all resources and their selectors.

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

commonLabels:
  environment: development
  team: platform
EOF
```

Build to see the labels.

```bash
kubectl kustomize .
```

The labels are added to metadata.labels and to spec.selector.matchLabels and spec.template.metadata.labels. Kustomize knows how to handle Kubernetes resources properly.

### commonAnnotations

Add annotations to all resources.

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

commonAnnotations:
  owner: platform-team
  documentation: https://wiki.example.com/nginx
EOF
```

Build to see the annotations.

```bash
kubectl kustomize .
```

Annotations are added to metadata.annotations on all resources.

### namespace

Set the namespace for all resources.

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: tutorial-kustomize
EOF
```

Build to see the namespace.

```bash
kubectl kustomize .
```

Every resource now has metadata.namespace: tutorial-kustomize. This is useful for deploying the same manifests to different namespaces.

## Part 4: Combining Multiple Resources

Kustomize can manage multiple resources at once. Create a service to go with our deployment.

```bash
cat > service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
EOF
```

Update kustomization.yaml to include both resources.

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml

namespace: tutorial-kustomize

commonLabels:
  app: nginx
  environment: tutorial

namePrefix: demo-
EOF
```

Build to see both resources.

```bash
kubectl kustomize .
```

Both the deployment and service are output with the prefix, labels, and namespace applied. Notice that the service selector now also includes the common labels.

Apply to the cluster.

```bash
kubectl apply -k .
```

Verify both resources exist.

```bash
kubectl get deployment,service -n tutorial-kustomize
```

## Part 5: Resource Ordering

Kustomize outputs resources in a specific order that respects Kubernetes dependencies. Namespaces come before resources that go in them, ConfigMaps and Secrets come before Deployments that reference them, and so on.

You can see this by adding a ConfigMap.

```bash
cat > configmap.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-config
data:
  index.html: |
    <html><body>Hello from Kustomize</body></html>
EOF
```

Update kustomization.yaml.

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- configmap.yaml
- deployment.yaml
- service.yaml

namespace: tutorial-kustomize

commonLabels:
  app: nginx
  environment: tutorial

namePrefix: demo-
EOF
```

Build and observe the order.

```bash
kubectl kustomize .
```

The ConfigMap appears before the Deployment in the output, even though we listed them in a different order. Kustomize reorders resources to ensure dependencies are created first.

## Part 6: Referencing Directories

Instead of listing individual files, you can reference entire directories.

Create a subdirectory with resources.

```bash
mkdir -p base
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
  type: ClusterIP
EOF

cat > base/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
EOF
```

Now reference the directory from another kustomization.

```bash
cat > kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ./base

namespace: tutorial-kustomize
namePrefix: referenced-
EOF
```

Build to see the result.

```bash
kubectl kustomize .
```

Both resources from the base directory are included with the prefix applied. This pattern is the foundation for base/overlay structures covered in assignment-3.

## Part 7: Building vs Applying

There are two ways to use Kustomize.

Build only (preview).

```bash
kubectl kustomize .
```

This renders the final YAML to stdout without applying anything. Use this to review changes before applying.

Build and apply.

```bash
kubectl apply -k .
```

This builds and applies in one step. You can also save the output and apply separately.

```bash
kubectl kustomize . > output.yaml
kubectl apply -f output.yaml -n tutorial-kustomize
```

This two-step approach is useful when you want to review or version-control the rendered output.

## Part 8: Standalone Kustomize Command

While kubectl has Kustomize built in, you can also install the standalone kustomize command, which may have newer features.

```bash
# Check if kustomize is installed
kustomize version

# Build with standalone kustomize
kustomize build .
```

For CKA exam purposes, kubectl kustomize is sufficient. The standalone command is useful for accessing newer features or in environments where you cannot modify kubectl.

## Cleanup

Remove all tutorial resources.

```bash
kubectl delete -k . --ignore-not-found
kubectl delete namespace tutorial-kustomize
cd ~
rm -rf ~/kustomize-tutorial
```

## Reference Commands

| Task | Command |
|------|---------|
| Build kustomization | `kubectl kustomize <directory>` |
| Apply kustomization | `kubectl apply -k <directory>` |
| Delete kustomization resources | `kubectl delete -k <directory>` |
| Build with standalone | `kustomize build <directory>` |
| Save output to file | `kubectl kustomize . > output.yaml` |

## kustomization.yaml Quick Reference

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Resource files to include
resources:
- deployment.yaml
- service.yaml
- ./subdirectory

# Set namespace for all resources
namespace: my-namespace

# Add prefix to all resource names
namePrefix: prefix-

# Add suffix to all resource names
nameSuffix: -suffix

# Add labels to all resources
commonLabels:
  key: value

# Add annotations to all resources
commonAnnotations:
  key: value
```
