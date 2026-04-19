# Helm Templates and Debugging Homework

This homework file contains 15 progressive exercises organized into five difficulty levels. The exercises assume you have worked through `helm-tutorial.md` and completed 05-helm/assignment-1 and assignment-2. Each exercise uses its own namespace where applicable. Complete the exercises in order.

## Setup

Verify that your cluster is running and Helm is installed.

```bash
kubectl get nodes
helm version
```

Ensure you have the bitnami repository configured.

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

If you want to clean up any leftover exercise namespaces from a previous attempt, run the following.

```bash
for i in 1 2 3 4 5; do
  for j in 1 2 3; do
    kubectl delete namespace ex-${i}-${j} --ignore-not-found --wait=false
  done
done
```

-----

## Level 1: Template Rendering

### Exercise 1.1

**Objective:** Render chart templates locally and understand the output.

**Setup:**

No cluster resources needed for this exercise.

**Task:**

Render the bitnami/nginx chart templates with release name `template-demo` and default values. Save the output to a file called `default-render.yaml`. Then render again with replicaCount=3 and save to `scaled-render.yaml`.

**Verification:**

```bash
# both files should exist
ls -la default-render.yaml scaled-render.yaml

# default should have replicas: 1
grep "replicas:" default-render.yaml

# scaled should have replicas: 3
grep "replicas:" scaled-render.yaml
```

Expected: Both files exist with different replica counts.

-----

### Exercise 1.2

**Objective:** Compare rendered output with different values.

**Setup:**

No cluster resources needed.

**Task:**

Render bitnami/nginx twice: once with service.type=LoadBalancer (default) and once with service.type=ClusterIP. Save to `lb-service.yaml` and `clusterip-service.yaml`. Identify the difference in the Service resource.

**Verification:**

```bash
# LoadBalancer type
grep "type: LoadBalancer" lb-service.yaml

# ClusterIP type
grep "type: ClusterIP" clusterip-service.yaml
```

Expected: Different service types in each file.

-----

### Exercise 1.3

**Objective:** Validate rendered manifests before deployment.

**Setup:**

```bash
kubectl create namespace ex-1-3
```

**Task:**

Render bitnami/nginx with release name `validated-app`, namespace ex-1-3, and ClusterIP service type. Pipe the output to kubectl apply with --dry-run=client to validate the manifests are correct.

**Verification:**

```bash
# validation should pass
helm template validated-app bitnami/nginx \
  --namespace ex-1-3 \
  --set service.type=ClusterIP | \
  kubectl apply --dry-run=client -f - 2>&1 | grep -c "created\|configured"
```

Expected: Validation passes, showing resources would be created.

-----

## Level 2: Debugging

### Exercise 2.1

**Objective:** Use --debug to get verbose output during installation.

**Setup:**

```bash
kubectl create namespace ex-2-1
```

**Task:**

Install bitnami/nginx with release name `debug-app` in namespace ex-2-1 using the --debug flag. Observe the additional output including rendered templates and deployment details.

**Verification:**

```bash
# release should be installed
helm list -n ex-2-1 | grep debug-app

# can see debug output by running again with --dry-run
helm upgrade debug-app bitnami/nginx -n ex-2-1 --debug --dry-run 2>&1 | head -50
```

Expected: Release installed, debug output shows rendered templates.

-----

### Exercise 2.2

**Objective:** Use --dry-run to test an installation without applying it.

**Setup:**

```bash
kubectl create namespace ex-2-2
```

**Task:**

Test installing bitnami/nginx with release name `dryrun-app` in namespace ex-2-2 using --dry-run. The release should NOT actually be created.

**Verification:**

```bash
# release should NOT exist
helm list -n ex-2-2 | grep -c dryrun-app || echo "0"

# namespace should have no pods
kubectl get pods -n ex-2-2 2>&1 | grep -c "No resources"
```

Expected: Release does not exist, no pods created.

-----

### Exercise 2.3

**Objective:** Diagnose a values error using debug output.

**Setup:**

```bash
kubectl create namespace ex-2-3
```

**Task:**

Try to install bitnami/redis with an invalid architecture value. Use --dry-run and --debug to see the error. Then install correctly with architecture=standalone.

```bash
helm install bad-redis bitnami/redis \
  --namespace ex-2-3 \
  --set architecture=invalid \
  --dry-run --debug 2>&1 | tail -20
```

**Verification:**

```bash
# correct installation
helm list -n ex-2-3 | grep good-redis

# pods running
kubectl get pods -n ex-2-3
```

Expected: Error visible in debug output, correct installation with valid architecture.

-----

## Level 3: Debugging Complex Issues

### Exercise 3.1

**Objective:** Debug an installation that fails due to missing required values.

**Setup:**

```bash
kubectl create namespace ex-3-1
```

An installation attempt failed silently.

```bash
helm install db-app bitnami/postgresql \
  --namespace ex-3-1 \
  --set primary.service.type=ClusterIP \
  --dry-run 2>&1 || true
```

**Task:**

The postgresql chart requires an auth.password or auth.postgresPassword value. Debug the issue by examining the error output, then install correctly with release name `working-db` and a password set.

**Verification:**

```bash
# release should be installed
helm list -n ex-3-1 | grep working-db

# should have set a password
helm get values working-db -n ex-3-1 | grep -i password
```

Expected: Release installed with password configured.

-----

### Exercise 3.2

**Objective:** Debug a release that installed but pods are not running.

**Setup:**

```bash
kubectl create namespace ex-3-2
helm install mystery-app bitnami/nginx \
  --namespace ex-3-2 \
  --set image.tag=nonexistent-tag-12345 \
  --set service.type=ClusterIP
```

**Task:**

The release shows as deployed but pods are not running. Diagnose the issue using kubectl commands, then upgrade the release with a valid image tag to fix it.

**Verification:**

```bash
# pods should be running after fix
kubectl get pods -n ex-3-2 | grep Running

# should be using valid image
kubectl get deployment -n ex-3-2 -o jsonpath='{.items[0].spec.template.spec.containers[0].image}'; echo
```

Expected: Pods running with valid nginx image.

-----

### Exercise 3.3

**Objective:** Debug dependency-related issues.

**Setup:**

```bash
kubectl create namespace ex-3-3
```

**Task:**

Examine the dependencies of the bitnami/wordpress chart. Then install wordpress with release name `blog-app`, disabling the memcached dependency (set memcached.enabled=false) and configuring mariadb with a root password.

**Verification:**

```bash
# release should be installed
helm list -n ex-3-3 | grep blog-app

# should have mariadb pods but not memcached
kubectl get pods -n ex-3-3 | grep mariadb
kubectl get pods -n ex-3-3 | grep memcached | wc -l
```

Expected: WordPress and MariaDB running, no Memcached.

-----

## Level 4: Advanced Features

### Exercise 4.1

**Objective:** Understand chart dependencies by examining a complex chart.

**Setup:**

No cluster resources needed.

**Task:**

Examine the bitnami/wordpress chart to understand its dependencies. List all dependencies and their conditions. Then render the chart with and without memcached enabled to see the difference.

**Verification:**

```bash
# show dependencies
helm show chart bitnami/wordpress | grep -A30 dependencies

# render with memcached
helm template wp bitnami/wordpress --set memcached.enabled=true 2>/dev/null | grep -c memcached

# render without memcached
helm template wp bitnami/wordpress --set memcached.enabled=false 2>/dev/null | grep -c memcached
```

Expected: Dependencies listed, different resource counts with/without memcached.

-----

### Exercise 4.2

**Objective:** Manage chart dependencies for a downloaded chart.

**Setup:**

Create a working directory.

```bash
mkdir -p /tmp/ex-4-2
cd /tmp/ex-4-2
```

**Task:**

Download the bitnami/wordpress chart and extract it. Examine the Chart.yaml to see the dependencies. Update the dependencies to download the subchart files.

**Verification:**

```bash
# chart should be downloaded
ls /tmp/ex-4-2/wordpress/Chart.yaml

# dependencies should be in charts/ directory
ls /tmp/ex-4-2/wordpress/charts/
```

Expected: Chart downloaded, dependency charts present in charts/ directory.

-----

### Exercise 4.3

**Objective:** Handle secrets appropriately during installation.

**Setup:**

```bash
kubectl create namespace ex-4-3
```

**Task:**

Install bitnami/redis with release name `secure-cache` in namespace ex-4-3. Set a password using the --set flag (do not create a values file with the password). After installation, verify the password is not visible in plain text in the rendered secrets.

**Verification:**

```bash
# release installed
helm list -n ex-4-3 | grep secure-cache

# password should be base64 encoded in secret, not plain text
kubectl get secret -n ex-4-3 -o yaml | grep -v "password:" | head -20

# values show password was set
helm get values secure-cache -n ex-4-3 | grep password
```

Expected: Release installed, password in values but base64 encoded in secrets.

-----

## Level 5: Production Scenarios

### Exercise 5.1

**Objective:** Debug a complex chart installation with multiple issues.

**Setup:**

```bash
kubectl create namespace ex-5-1
```

**Task:**

Install bitnami/nginx with release name `production-web` with the following requirements: 3 replicas, ClusterIP service, resource requests (memory: 128Mi, cpu: 100m), and resource limits (memory: 256Mi, cpu: 200m). Before installing, use --dry-run --debug to verify the configuration is correct. Then install for real.

**Verification:**

```bash
# release deployed
helm list -n ex-5-1 | grep production-web

# 3 replicas
kubectl get deployment -n ex-5-1 -o jsonpath='{.items[0].spec.replicas}'; echo

# resources configured
kubectl get deployment -n ex-5-1 -o jsonpath='{.items[0].spec.template.spec.containers[0].resources}'; echo
```

Expected: 3 replicas with proper resource configuration.

-----

### Exercise 5.2

**Objective:** Audit a chart for best practices before deployment.

**Setup:**

```bash
kubectl create namespace ex-5-2
```

**Task:**

Before deploying bitnami/redis for production use, audit it by: 1) Rendering the templates to examine resource labels, 2) Checking if probes are configured, 3) Verifying resource requests/limits can be set. Then install with release name `audited-cache` using standalone architecture, auth disabled, and resource requests.

**Verification:**

```bash
# release deployed
helm list -n ex-5-2 | grep audited-cache

# has standard labels
kubectl get deployment -n ex-5-2 -o jsonpath='{.items[0].metadata.labels}' | grep app.kubernetes.io

# has resource requests
kubectl get deployment -n ex-5-2 -o jsonpath='{.items[0].spec.template.spec.containers[0].resources.requests}'; echo
```

Expected: Release deployed with proper labels and resources.

-----

### Exercise 5.3

**Objective:** Create comprehensive deployment documentation.

**Setup:**

```bash
kubectl create namespace ex-5-3
```

**Task:**

Create a deployment for nginx that follows all best practices. Create a values file named `production-nginx.yaml` with documentation comments explaining each setting. Include: 3 replicas, ClusterIP service, resource requests and limits, and any other settings you consider important. Install with release name `documented-web` using --atomic.

**Verification:**

```bash
# values file exists with comments
cat production-nginx.yaml | grep "#"

# release deployed
helm list -n ex-5-3 | grep documented-web

# configuration applied
kubectl get deployment -n ex-5-3 -o jsonpath='{.items[0].spec.replicas}'; echo
```

Expected: Documented values file, release deployed with atomic flag.

-----

## Cleanup

Remove all exercise namespaces and temporary files.

```bash
for i in 1 2 3 4 5; do
  for j in 1 2 3; do
    helm uninstall $(helm list -n ex-${i}-${j} -q) -n ex-${i}-${j} 2>/dev/null || true
    kubectl delete namespace ex-${i}-${j} --ignore-not-found --wait=false
  done
done

rm -f default-render.yaml scaled-render.yaml lb-service.yaml clusterip-service.yaml production-nginx.yaml
rm -rf /tmp/ex-4-2
```

## Key Takeaways

After completing these exercises, you should be comfortable with rendering chart templates locally, comparing template output with different values, validating manifests before deployment, using --debug and --dry-run for troubleshooting, diagnosing template and values errors, understanding and managing chart dependencies, handling secrets appropriately, and applying best practices for production deployments.
