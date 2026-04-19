# Helm Templates and Debugging Tutorial

This tutorial covers advanced Helm topics that are essential for production use and the CKA exam. You will learn how to render templates locally, debug chart installations, understand Helm hooks, manage chart dependencies, and apply best practices. These skills help you troubleshoot issues and deploy applications reliably.

All tutorial resources use a dedicated namespace called `tutorial-helm` so they will not collide with anything the exercises create.

## Prerequisites

Verify your cluster is up and Helm is installed.

```bash
kubectl get nodes
helm version
```

Ensure you have the bitnami repository configured.

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

Create the tutorial namespace.

```bash
kubectl create namespace tutorial-helm
```

## Part 1: Template Rendering

The `helm template` command renders chart templates locally without installing anything to the cluster. This is invaluable for understanding what a chart will create and for integrating with GitOps workflows.

### Basic Template Rendering

Render the nginx chart templates.

```bash
helm template my-release bitnami/nginx
```

This outputs all the Kubernetes manifests that would be created. You see Deployments, Services, ConfigMaps, and other resources, all rendered with the default values.

### Rendering with Custom Values

Render with custom values to see how they affect the output.

```bash
helm template my-release bitnami/nginx \
  --set replicaCount=3 \
  --set service.type=ClusterIP
```

Compare the output to the default rendering. You will see `replicas: 3` in the Deployment spec.

### Rendering to a File

Save the rendered output for review or version control.

```bash
helm template my-release bitnami/nginx \
  --set service.type=ClusterIP \
  > rendered-manifests.yaml
```

You can now review the file, apply it with kubectl, or commit it to a Git repository.

### Validating Rendered Output

Use kubectl to validate the rendered YAML.

```bash
helm template my-release bitnami/nginx \
  --set service.type=ClusterIP | \
  kubectl apply --dry-run=client -f -
```

This validates the YAML syntax and basic Kubernetes schema without creating resources.

### Rendering Specific Templates

If a chart has many templates and you only want to see one, use --show-only.

```bash
helm template my-release bitnami/nginx --show-only templates/deployment.yaml
```

This renders only the deployment template, making it easier to focus on specific resources.

## Part 2: Debugging Installations

When helm install or upgrade fails, debugging flags help you understand what went wrong.

### Using --debug

The --debug flag provides verbose output including rendered templates.

```bash
helm install debug-demo bitnami/nginx \
  --namespace tutorial-helm \
  --set service.type=ClusterIP \
  --debug
```

The output includes the rendered manifests, hook details, and diagnostic information. This is helpful when you need to see exactly what Helm is trying to create.

### Using --dry-run

The --dry-run flag simulates the installation without creating resources.

```bash
helm install dry-demo bitnami/nginx \
  --namespace tutorial-helm \
  --set service.type=ClusterIP \
  --dry-run
```

This is useful for validating an installation will work before committing to it.

### Combining --debug and --dry-run

For maximum visibility without making changes.

```bash
helm install test-demo bitnami/nginx \
  --namespace tutorial-helm \
  --set service.type=ClusterIP \
  --debug \
  --dry-run
```

This shows everything that would happen, including hook execution order, without making any changes.

### Diagnosing Template Errors

When a chart has template errors, you will see messages like "Error: template: chart/templates/deployment.yaml:10:12: executing ... nil pointer evaluating interface {}".

This usually means a required value is missing. Check the values.yaml of the chart to understand what values are expected.

### Diagnosing Values Errors

Some charts validate values and reject invalid configurations. For example.

```bash
helm install bad-values bitnami/nginx \
  --namespace tutorial-helm \
  --set architecture=invalid \
  --dry-run 2>&1 || true
```

The error message tells you what value was invalid and sometimes what valid options are.

### Diagnosing Resource Errors

If templates render correctly but resources fail to create, check Kubernetes events.

```bash
helm install resource-demo bitnami/nginx \
  --namespace tutorial-helm \
  --set service.type=ClusterIP

kubectl get events -n tutorial-helm --sort-by='.lastTimestamp'
```

Events show why pods failed to start, services failed to create, and so on.

Clean up.

```bash
helm uninstall debug-demo -n tutorial-helm
helm uninstall resource-demo -n tutorial-helm
```

## Part 3: Helm Hooks

Hooks allow you to execute actions at specific points in a release lifecycle. Common use cases include database migrations before upgrades and sending notifications after deployments.

### Hook Types

Helm supports these hook types.

pre-install: Executes before resources are created
post-install: Executes after resources are created
pre-upgrade: Executes before upgrade
post-upgrade: Executes after upgrade
pre-delete: Executes before deletion
post-delete: Executes after deletion
pre-rollback: Executes before rollback
post-rollback: Executes after rollback

### How Hooks Work

Hooks are Kubernetes resources (usually Jobs or Pods) with special annotations.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pre-install-job
  annotations:
    "helm.sh/hook": pre-install
    "helm.sh/hook-weight": "0"
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  template:
    spec:
      containers:
      - name: migration
        image: myapp/migration:1.0
        command: ["./run-migration.sh"]
      restartPolicy: Never
```

The helm.sh/hook annotation specifies when the hook runs. The hook-weight determines order (lower runs first). The hook-delete-policy controls cleanup.

### Viewing Hooks in a Chart

To see if a chart has hooks, render it and look for hook annotations.

```bash
helm template demo bitnami/nginx | grep -A5 "helm.sh/hook"
```

Not all charts have hooks. The nginx chart may not have any, but database charts often do.

### Hook Delete Policies

The hook-delete-policy annotation controls when hook resources are deleted.

hook-succeeded: Delete after successful execution
hook-failed: Delete after failed execution
before-hook-creation: Delete old hook before creating new one

### Debugging Hook Issues

If a release is stuck, it might be waiting for a hook to complete. Check for hook Jobs.

```bash
kubectl get jobs -n tutorial-helm
kubectl get pods -n tutorial-helm
```

If a hook Job failed, check its logs.

```bash
kubectl logs job/<job-name> -n tutorial-helm
```

## Part 4: Chart Dependencies

Charts can depend on other charts. For example, a web application chart might depend on a database chart.

### Viewing Dependencies

Check if a chart has dependencies.

```bash
helm show chart bitnami/wordpress | grep -A20 dependencies
```

WordPress depends on MariaDB and Memcached, for example.

### Dependency Commands

Before installing a chart with dependencies, update them.

```bash
helm dependency update ./my-chart
```

This downloads the dependency charts to the charts/ directory.

To build dependencies from a lock file.

```bash
helm dependency build ./my-chart
```

### Dependencies in values

When a chart has dependencies, you pass values to subcharts using the subchart name as a key.

```bash
helm install wp bitnami/wordpress \
  --namespace tutorial-helm \
  --set mariadb.auth.rootPassword=secretpassword \
  --set mariadb.auth.password=wppassword \
  --set service.type=ClusterIP
```

The mariadb.* values are passed to the mariadb subchart.

### Conditional Dependencies

Charts can make dependencies optional using condition or tags in Chart.yaml.

```yaml
dependencies:
  - name: redis
    version: "17.x.x"
    repository: https://charts.bitnami.com/bitnami
    condition: redis.enabled
```

The dependency is only included if redis.enabled is true in values.

## Part 5: Secrets and Sensitive Data

Handling secrets properly is critical for security.

### Secrets in Values

Never commit secrets to version control. Instead, use environment variables or external secret management.

```bash
helm install secure-app bitnami/nginx \
  --namespace tutorial-helm \
  --set adminPassword="${ADMIN_PASSWORD}" \
  --set service.type=ClusterIP
```

The secret is passed at runtime, not stored in values files.

### Secrets and Revision History

Helm stores release history, including values. This means secrets may be visible in history.

```bash
helm get values secure-app -n tutorial-helm
```

For highly sensitive data, consider external secret management tools like HashiCorp Vault or Kubernetes External Secrets.

### Best Practices for Secrets

Do not put secrets in values files that are committed to version control. Use CI/CD environment variables to inject secrets at deployment time. Consider the helm-secrets plugin for encrypted values files. Limit who can run `helm get values` with RBAC.

Clean up.

```bash
helm uninstall secure-app -n tutorial-helm 2>/dev/null || true
```

## Part 6: Helm Best Practices

Following best practices makes Helm deployments more reliable and maintainable.

### Naming Conventions

Use descriptive release names that indicate the environment and purpose.

```bash
# Good
helm install frontend-production bitnami/nginx ...
helm install api-staging bitnami/nginx ...

# Less clear
helm install release1 bitnami/nginx ...
```

### Resource Labels

Good charts add consistent labels. Check that deployed resources have labels like app.kubernetes.io/name, app.kubernetes.io/instance, and app.kubernetes.io/version.

```bash
kubectl get deployments -n tutorial-helm --show-labels
```

### Using --atomic for Production

Always use --atomic for production deployments to ensure automatic rollback on failure.

```bash
helm upgrade frontend bitnami/nginx \
  --namespace production \
  --atomic \
  --timeout 5m \
  -f production-values.yaml
```

### Values Documentation

When using values files, document why each value is set.

```yaml
# production-values.yaml
# 3 replicas for high availability
replicaCount: 3

# ClusterIP because we use Ingress
service:
  type: ClusterIP

# Resource limits to prevent noisy neighbor issues
resources:
  requests:
    memory: 256Mi
    cpu: 200m
  limits:
    memory: 512Mi
    cpu: 500m
```

### Pre-deployment Validation

Always validate before deploying.

```bash
# Render and validate
helm template release chart -f values.yaml | kubectl apply --dry-run=client -f -

# Or use helm with --dry-run
helm upgrade release chart -f values.yaml --dry-run
```

### Chart Testing

Some charts include tests. Run them after deployment.

```bash
helm test my-release -n tutorial-helm
```

Tests verify the deployment is working correctly.

## Cleanup

Remove any remaining resources.

```bash
helm list -n tutorial-helm -q | xargs -I {} helm uninstall {} -n tutorial-helm
kubectl delete namespace tutorial-helm
rm -f rendered-manifests.yaml
```

## Reference Commands

| Task | Command |
|------|---------|
| Render templates | `helm template <release> <chart>` |
| Render with values | `helm template <release> <chart> -f values.yaml` |
| Render to file | `helm template <release> <chart> > output.yaml` |
| Render specific template | `helm template <release> <chart> --show-only templates/deployment.yaml` |
| Install with debug | `helm install <release> <chart> --debug` |
| Install dry-run | `helm install <release> <chart> --dry-run` |
| Install debug + dry-run | `helm install <release> <chart> --debug --dry-run` |
| View dependencies | `helm show chart <chart> \| grep -A20 dependencies` |
| Update dependencies | `helm dependency update ./chart` |
| Build dependencies | `helm dependency build ./chart` |
| Run chart tests | `helm test <release> -n <ns>` |
| Atomic upgrade | `helm upgrade <release> <chart> --atomic --timeout 5m` |
