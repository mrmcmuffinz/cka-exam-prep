# Kustomize Fundamentals Homework Answers

This file contains complete solutions for all 15 exercises in `kustomize-homework.md`, along with explanations and a common mistakes section.

-----

## Exercise 1.1 Solution

Create the deployment.

```bash
cat > ~/kustomize-exercises/ex-1-1/deployment.yaml <<'EOF'
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
EOF
```

Create the kustomization.

```bash
cat > ~/kustomize-exercises/ex-1-1/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
EOF
```

The minimum kustomization.yaml needs apiVersion, kind, and at least one resource.

-----

## Exercise 1.2 Solution

Create the kustomization.

```bash
cat > ~/kustomize-exercises/ex-1-2/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
EOF
```

Save the rendered output.

```bash
kubectl kustomize ~/kustomize-exercises/ex-1-2 > ~/kustomize-exercises/ex-1-2/rendered.yaml
```

The rendered.yaml file contains the deployment YAML exactly as it would be applied to the cluster.

-----

## Exercise 1.3 Solution

Create the kustomization with namespace.

```bash
cat > ~/kustomize-exercises/ex-1-3/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-1-3
EOF
```

Apply the kustomization.

```bash
kubectl apply -k ~/kustomize-exercises/ex-1-3
```

The -k flag tells kubectl to process the directory as a kustomization.

-----

## Exercise 2.1 Solution

```bash
cat > ~/kustomize-exercises/ex-2-1/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-2-1
namePrefix: dev-
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-exercises/ex-2-1
```

The namePrefix is prepended to all resource names. The deployment named "api" becomes "dev-api".

-----

## Exercise 2.2 Solution

```bash
cat > ~/kustomize-exercises/ex-2-2/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-2-2

commonLabels:
  environment: development
  team: platform
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-exercises/ex-2-2
```

commonLabels are added to all resources' metadata.labels and also to selector.matchLabels and template.metadata.labels for Deployments.

-----

## Exercise 2.3 Solution

```bash
cat > ~/kustomize-exercises/ex-2-3/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml

namespace: ex-2-3
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-exercises/ex-2-3
```

The namespace transformer sets metadata.namespace on all resources.

-----

## Exercise 3.1 Solution

The error is that kustomization.yaml references "deployment.yaml" but the file is named "app-deployment.yaml".

Fix the kustomization.

```bash
cat > ~/kustomize-exercises/ex-3-1/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- app-deployment.yaml

namespace: ex-3-1
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-exercises/ex-3-1
```

Resource paths in kustomization.yaml must exactly match the actual file names.

-----

## Exercise 3.2 Solution

The issue is that commonLabels changes the app label on the deployment pods but the service selector was also updated. However, the original issue description was misleading. Kustomize actually handles this correctly by updating both the service selector and the pod labels.

The real fix is to verify that the selector labels match. If they do not match after applying, remove the commonLabels for app and use the original app label.

Actually, in this case, Kustomize will work correctly because it updates both the deployment pod template labels and the service selector. Let us verify.

```bash
kubectl apply -k ~/kustomize-exercises/ex-3-2
kubectl get endpoints webapp -n ex-3-2
```

If the service has no endpoints, the issue is that the deployment's selector.matchLabels still has "app: webapp" but the pods have "app: my-webapp". Fix by keeping the same app label.

```bash
cat > ~/kustomize-exercises/ex-3-2/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml

namespace: ex-3-2

commonLabels:
  environment: production
EOF
```

By removing the app label from commonLabels, the original app: webapp label is preserved and selectors work correctly.

-----

## Exercise 3.3 Solution

The kustomization.yaml is missing the apiVersion field.

Fix.

```bash
cat > ~/kustomize-exercises/ex-3-3/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-3-3
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-exercises/ex-3-3
```

Both apiVersion and kind are required fields in kustomization.yaml.

-----

## Exercise 4.1 Solution

Create the resources.

```bash
cat > ~/kustomize-exercises/ex-4-1/deployment.yaml <<'EOF'
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
EOF

cat > ~/kustomize-exercises/ex-4-1/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  selector:
    app: nginx
  ports:
  - port: 80
  type: ClusterIP
EOF
```

Create the kustomization.

```bash
cat > ~/kustomize-exercises/ex-4-1/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml

namespace: ex-4-1
namePrefix: prod-

commonLabels:
  tier: frontend
  env: production
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-exercises/ex-4-1
```

Multiple transformers are applied in a consistent order by Kustomize.

-----

## Exercise 4.2 Solution

Create the deployment.

```bash
cat > ~/kustomize-exercises/ex-4-2/deployment.yaml <<'EOF'
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

Create the kustomization.

```bash
cat > ~/kustomize-exercises/ex-4-2/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-4-2

commonLabels:
  app: web
  team: platform

commonAnnotations:
  owner: platform-team
  cost-center: engineering
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-exercises/ex-4-2
```

commonLabels and commonAnnotations can be used together.

-----

## Exercise 4.3 Solution

Create the deployment.

```bash
cat > ~/kustomize-exercises/ex-4-3/deployment.yaml <<'EOF'
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

Create the kustomization.

```bash
cat > ~/kustomize-exercises/ex-4-3/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml

namespace: ex-4-3
namePrefix: team1-
nameSuffix: -v2
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-exercises/ex-4-3
```

Prefix and suffix are applied to create "team1-api-v2".

-----

## Exercise 5.1 Solution

Create all resources.

```bash
cat > ~/kustomize-exercises/ex-5-1/frontend-deployment.yaml <<'EOF'
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

cat > ~/kustomize-exercises/ex-5-1/frontend-service.yaml <<'EOF'
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

cat > ~/kustomize-exercises/ex-5-1/backend-deployment.yaml <<'EOF'
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

cat > ~/kustomize-exercises/ex-5-1/backend-service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend
  ports:
  - port: 80
  type: ClusterIP
EOF
```

Create the kustomization.

```bash
cat > ~/kustomize-exercises/ex-5-1/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- frontend-deployment.yaml
- frontend-service.yaml
- backend-deployment.yaml
- backend-service.yaml

namespace: ex-5-1
namePrefix: myapp-

commonLabels:
  project: myapp
  version: v1
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-exercises/ex-5-1
```

-----

## Exercise 5.2 Solution

The kustomization has two issues: missing apiVersion and typo in resource name (deplyoment.yaml instead of deployment.yaml).

Fix.

```bash
cat > ~/kustomize-exercises/ex-5-2/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
- configmap.yaml

namespace: ex-5-2
namePrefix: debug-
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-exercises/ex-5-2
```

-----

## Exercise 5.3 Solution

Create all resources.

```bash
cat > ~/kustomize-exercises/ex-5-3/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
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

cat > ~/kustomize-exercises/ex-5-3/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web
  ports:
  - port: 80
  type: ClusterIP
EOF

cat > ~/kustomize-exercises/ex-5-3/configmap.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
data:
  app.properties: |
    setting1=value1
    setting2=value2
EOF
```

Create the kustomization.

```bash
cat > ~/kustomize-exercises/ex-5-3/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
- configmap.yaml

namespace: ex-5-3
namePrefix: webapp-

commonLabels:
  app: webapp
  version: v1

commonAnnotations:
  owner: platform-team
  description: Production web application
EOF
```

Apply.

```bash
kubectl apply -k ~/kustomize-exercises/ex-5-3
```

-----

## Common Mistakes

**Wrong path in resources.** Resource paths must exactly match the file names. Check for typos and ensure the files exist in the correct location relative to kustomization.yaml.

**YAML syntax errors.** Kustomize requires valid YAML. Indentation matters. Use a YAML linter to catch syntax errors.

**Label key conflicts.** When using commonLabels, be aware that it changes selectors. If your deployment selector already uses a label, commonLabels will add to it or override it, potentially breaking pod selection.

**Namespace not applying to cluster-scoped resources.** The namespace transformer only affects namespaced resources. Cluster-scoped resources (like ClusterRole) are not modified.

**Missing apiVersion or kind.** Both fields are required in kustomization.yaml. The apiVersion is typically kustomize.config.k8s.io/v1beta1.

**Resource ordering expectations.** Kustomize orders resources automatically based on Kubernetes dependencies. Do not expect them to appear in the order you listed them.

**Forgetting to apply.** kubectl kustomize only builds the output. Use kubectl apply -k to actually deploy the resources.

-----

## Kustomize Commands Cheat Sheet

| Task | Command |
|------|---------|
| Build kustomization | `kubectl kustomize <directory>` |
| Apply kustomization | `kubectl apply -k <directory>` |
| Delete kustomization resources | `kubectl delete -k <directory>` |
| Save output to file | `kubectl kustomize . > output.yaml` |
| Apply saved output | `kubectl apply -f output.yaml` |

## kustomization.yaml Quick Reference

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml

namespace: my-namespace
namePrefix: prefix-
nameSuffix: -suffix

commonLabels:
  key: value

commonAnnotations:
  key: value
```
