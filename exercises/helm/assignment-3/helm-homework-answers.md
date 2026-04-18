# Helm Templates and Debugging Homework Answers

This file contains complete solutions for all 15 exercises in `helm-homework.md`, along with explanations and a common mistakes section.

-----

## Exercise 1.1 Solution

Render with default values.

```bash
helm template template-demo bitnami/nginx > default-render.yaml
```

Render with scaled replicas.

```bash
helm template template-demo bitnami/nginx \
  --set replicaCount=3 > scaled-render.yaml
```

The `helm template` command renders all chart templates with the given values but does not install anything to the cluster. This is useful for reviewing what will be created, for GitOps workflows, and for debugging.

-----

## Exercise 1.2 Solution

Render with LoadBalancer.

```bash
helm template lb-demo bitnami/nginx > lb-service.yaml
```

Render with ClusterIP.

```bash
helm template clusterip-demo bitnami/nginx \
  --set service.type=ClusterIP > clusterip-service.yaml
```

Comparing the files shows the Service resource has different type fields. LoadBalancer creates a cloud load balancer, while ClusterIP creates an internal-only service.

-----

## Exercise 1.3 Solution

```bash
helm template validated-app bitnami/nginx \
  --namespace ex-1-3 \
  --set service.type=ClusterIP | \
  kubectl apply --dry-run=client -f -
```

Piping to kubectl with --dry-run=client validates the rendered YAML against the Kubernetes API schema without creating resources. This catches issues like invalid field names or incorrect types that Helm itself might not catch.

-----

## Exercise 2.1 Solution

```bash
helm install debug-app bitnami/nginx \
  --namespace ex-2-1 \
  --set service.type=ClusterIP \
  --debug
```

The --debug flag outputs verbose information including the rendered manifests, hooks, and detailed status. This is helpful when debugging why an installation behaves unexpectedly.

-----

## Exercise 2.2 Solution

```bash
helm install dryrun-app bitnami/nginx \
  --namespace ex-2-2 \
  --set service.type=ClusterIP \
  --dry-run
```

The --dry-run flag simulates the installation without creating any resources. The release is not recorded and no Kubernetes objects are created. This is essential for testing changes before applying them.

-----

## Exercise 2.3 Solution

First, observe the error.

```bash
helm install bad-redis bitnami/redis \
  --namespace ex-2-3 \
  --set architecture=invalid \
  --dry-run --debug 2>&1 | tail -20
```

The error message indicates that architecture must be "standalone" or "replication".

Install correctly.

```bash
helm install good-redis bitnami/redis \
  --namespace ex-2-3 \
  --set architecture=standalone \
  --set auth.enabled=false \
  --set master.service.type=ClusterIP
```

The --debug output shows exactly what values are being used and what validation errors occur.

-----

## Exercise 3.1 Solution

The postgresql chart requires a password. Install with password set.

```bash
helm install working-db bitnami/postgresql \
  --namespace ex-3-1 \
  --set auth.postgresPassword=mysecretpassword \
  --set primary.service.type=ClusterIP
```

The error message from the dry-run indicated that auth.postgresPassword was required. Always check chart documentation or error messages for required values.

-----

## Exercise 3.2 Solution

First, diagnose the issue.

```bash
kubectl get pods -n ex-3-2
kubectl describe pod -n ex-3-2 -l app.kubernetes.io/instance=mystery-app
kubectl get events -n ex-3-2 --sort-by='.lastTimestamp'
```

The events show ImagePullBackOff because the image tag does not exist.

Fix by upgrading with a valid tag.

```bash
helm upgrade mystery-app bitnami/nginx \
  --namespace ex-3-2 \
  --set service.type=ClusterIP \
  --set image.tag=1.25
```

When a release is deployed but pods are not running, always check kubectl describe and events for the actual error.

-----

## Exercise 3.3 Solution

First, examine dependencies.

```bash
helm show chart bitnami/wordpress | grep -A30 dependencies
```

Install with memcached disabled.

```bash
helm install blog-app bitnami/wordpress \
  --namespace ex-3-3 \
  --set memcached.enabled=false \
  --set mariadb.auth.rootPassword=rootpassword \
  --set mariadb.auth.password=wppassword \
  --set service.type=ClusterIP \
  --set wordpressPassword=adminpassword
```

Setting a subchart condition to false (memcached.enabled=false) excludes that dependency from the installation.

-----

## Exercise 4.1 Solution

Show dependencies.

```bash
helm show chart bitnami/wordpress | grep -A30 dependencies
```

Render with memcached enabled.

```bash
helm template wp bitnami/wordpress \
  --set memcached.enabled=true \
  --set mariadb.auth.rootPassword=test \
  --set wordpressPassword=test 2>/dev/null | grep -c "kind: Deployment"
```

Render without memcached.

```bash
helm template wp bitnami/wordpress \
  --set memcached.enabled=false \
  --set mariadb.auth.rootPassword=test \
  --set wordpressPassword=test 2>/dev/null | grep -c "kind: Deployment"
```

The count of resources differs based on whether dependencies are enabled.

-----

## Exercise 4.2 Solution

Download and extract the chart.

```bash
cd /tmp/ex-4-2
helm pull bitnami/wordpress --untar
```

Examine dependencies.

```bash
cat /tmp/ex-4-2/wordpress/Chart.yaml
```

Update dependencies.

```bash
cd /tmp/ex-4-2/wordpress
helm dependency update .
ls charts/
```

The `helm dependency update` command downloads the dependency charts specified in Chart.yaml into the charts/ directory.

-----

## Exercise 4.3 Solution

```bash
helm install secure-cache bitnami/redis \
  --namespace ex-4-3 \
  --set architecture=standalone \
  --set auth.password=mysecretpassword \
  --set master.service.type=ClusterIP
```

The password is set via --set flag, not stored in a values file. In the cluster, the password is stored in a Kubernetes Secret with base64 encoding.

Check the secret.

```bash
kubectl get secret secure-cache-redis -n ex-4-3 -o jsonpath='{.data.redis-password}' | base64 -d; echo
```

The password is stored encoded, not as plain text in the manifest.

-----

## Exercise 5.1 Solution

First, validate with dry-run.

```bash
helm install production-web bitnami/nginx \
  --namespace ex-5-1 \
  --set replicaCount=3 \
  --set service.type=ClusterIP \
  --set resources.requests.memory=128Mi \
  --set resources.requests.cpu=100m \
  --set resources.limits.memory=256Mi \
  --set resources.limits.cpu=200m \
  --dry-run --debug
```

Review the output to verify configuration, then install.

```bash
helm install production-web bitnami/nginx \
  --namespace ex-5-1 \
  --set replicaCount=3 \
  --set service.type=ClusterIP \
  --set resources.requests.memory=128Mi \
  --set resources.requests.cpu=100m \
  --set resources.limits.memory=256Mi \
  --set resources.limits.cpu=200m
```

-----

## Exercise 5.2 Solution

Audit the chart.

```bash
# Check labels
helm template audit-check bitnami/redis \
  --set architecture=standalone | grep -A5 "labels:"

# Check for probes
helm template audit-check bitnami/redis \
  --set architecture=standalone | grep -E "(livenessProbe|readinessProbe)"

# Check resource setting capability
helm show values bitnami/redis | grep -A10 resources
```

Install with audit findings applied.

```bash
helm install audited-cache bitnami/redis \
  --namespace ex-5-2 \
  --set architecture=standalone \
  --set auth.enabled=false \
  --set master.service.type=ClusterIP \
  --set master.resources.requests.memory=64Mi \
  --set master.resources.requests.cpu=50m
```

-----

## Exercise 5.3 Solution

Create the documented values file.

```bash
cat > production-nginx.yaml <<'EOF'
# Production nginx configuration
# Last updated: 2024

# High availability: 3 replicas for redundancy
replicaCount: 3

# Internal service only, ingress handles external traffic
service:
  type: ClusterIP

# Resource management for predictable performance
resources:
  # Requests: minimum guaranteed resources
  requests:
    memory: 128Mi
    cpu: 100m
  # Limits: maximum allowed resources
  limits:
    memory: 256Mi
    cpu: 200m

# Pull policy ensures we get updates
image:
  pullPolicy: IfNotPresent
EOF
```

Install with atomic flag.

```bash
helm install documented-web bitnami/nginx \
  --namespace ex-5-3 \
  -f production-nginx.yaml \
  --atomic \
  --timeout 5m
```

Using --atomic ensures automatic rollback if the installation fails.

-----

## Common Mistakes

**Template syntax errors in values.** When values contain special characters, they may cause template errors. Use --debug to see the exact error.

**Hook not running due to wrong annotation.** The annotation must be exactly "helm.sh/hook" with the correct value. Typos cause hooks to be treated as regular resources.

**Dependencies not updated.** When using a chart with dependencies, always run `helm dependency update` before installing from a local directory.

**Secrets visible in history.** Helm stores values in release history. For sensitive data, use external secret management rather than values files.

**Not using --dry-run before production.** Always validate changes with --dry-run before applying to production clusters.

**Assuming dry-run catches all issues.** The --dry-run flag validates templates and basic API compatibility, but does not catch runtime issues like resource quotas or image pull failures.

**Ignoring chart test results.** Some charts include tests. Run `helm test` after deployment to verify the application is working correctly.

**Not setting resource limits.** Production deployments should always have resource requests and limits to prevent resource contention.

-----

## Debugging Commands Cheat Sheet

| Task | Command |
|------|---------|
| Render templates | `helm template <release> <chart>` |
| Render with values | `helm template <release> <chart> -f values.yaml` |
| Render to file | `helm template <release> <chart> > output.yaml` |
| Render one template | `helm template <release> <chart> --show-only templates/x.yaml` |
| Validate rendered YAML | `helm template ... \| kubectl apply --dry-run=client -f -` |
| Install with debug | `helm install <release> <chart> --debug` |
| Dry run install | `helm install <release> <chart> --dry-run` |
| Debug + dry run | `helm install <release> <chart> --debug --dry-run` |
| Show chart info | `helm show chart <chart>` |
| Show chart values | `helm show values <chart>` |
| Show dependencies | `helm show chart <chart> \| grep -A20 dependencies` |
| Update dependencies | `helm dependency update ./chart` |
| Get release manifest | `helm get manifest <release> -n <ns>` |
| Get release values | `helm get values <release> -n <ns>` |
| Get all release info | `helm get all <release> -n <ns>` |
| Run chart tests | `helm test <release> -n <ns>` |
| Check pod events | `kubectl describe pod -n <ns> -l app.kubernetes.io/instance=<release>` |
| Check namespace events | `kubectl get events -n <ns> --sort-by='.lastTimestamp'` |
