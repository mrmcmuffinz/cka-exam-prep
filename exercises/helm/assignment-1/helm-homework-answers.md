# Helm Basics Homework Answers

This file contains complete solutions for all 15 exercises in `helm-homework.md`, along with explanations and a common mistakes section.

-----

## Exercise 1.1 Solution

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo list
```

The `helm repo add` command registers a repository with a local name. The name (jetstack) is how you reference it in subsequent commands. The URL is where Helm fetches the chart index and charts from.

-----

## Exercise 1.2 Solution

Search for redis chart.

```bash
helm search repo bitnami/redis
```

Find all versions.

```bash
helm search repo bitnami/redis --versions
```

The `--versions` flag shows all available versions instead of just the latest. This is useful when you need to install a specific version or understand what versions are available for upgrade.

-----

## Exercise 1.3 Solution

```bash
helm repo update
```

This command fetches the latest index.yaml from each configured repository. The index contains metadata about all available charts and their versions. Without updating, you might not see newly published charts or versions.

When you run `helm repo update`, you will see output like "Successfully got an update from the 'bitnami' chart repository" for each repository.

-----

## Exercise 2.1 Solution

```bash
helm install web-server bitnami/nginx --namespace ex-2-1
```

This installs the nginx chart with the release name `web-server`. The release name must be unique within the namespace. Helm creates all resources defined in the chart (Deployment, Service, ConfigMap, etc.) in the specified namespace.

-----

## Exercise 2.2 Solution

```bash
helm install cache-server bitnami/redis --namespace ex-2-2 --create-namespace
```

The `--create-namespace` flag tells Helm to create the namespace if it does not exist. Without this flag, the installation would fail with a "namespace not found" error.

-----

## Exercise 2.3 Solution

List all releases across namespaces.

```bash
helm list --all-namespaces
```

Get detailed status for web-server.

```bash
helm status web-server -n ex-2-1
```

The `--all-namespaces` flag (or `-A` for short) shows releases from every namespace. The `helm status` command shows the current state of a release, including deployment time, namespace, status, and any notes the chart provides (such as how to access the service).

-----

## Exercise 3.1 Solution

The error was a typo in the repository name: `bitnaim/nginx` instead of `bitnami/nginx`.

```bash
helm install web-app bitnami/nginx --namespace ex-3-1
```

Helm reports "Error: repo bitnaim not found" when the repository name is misspelled. Always double-check repository and chart names. You can use `helm search repo nginx` to find the correct chart name.

-----

## Exercise 3.2 Solution

The error was that a release named `my-release` already exists in the namespace. Release names must be unique within a namespace.

```bash
helm install my-second-release bitnami/nginx --namespace ex-3-2
```

Helm reports "Error: INSTALLATION FAILED: cannot re-use a name that is still in use" when you try to reuse a release name. Choose a different name, or uninstall the existing release first if you want to reuse the name.

-----

## Exercise 3.3 Solution

The error was using a colon (`:`) instead of an equals sign (`=`) in the --set syntax. The correct syntax is `--set key=value`.

```bash
helm install fixed-nginx bitnami/nginx --namespace ex-3-3 --set replicaCount=3
```

Helm uses `=` for key-value pairs. The colon syntax is not recognized and causes a parsing error.

-----

## Exercise 4.1 Solution

```bash
helm install custom-web bitnami/nginx \
  --namespace ex-4-1 \
  --set replicaCount=2 \
  --set service.type=ClusterIP
```

Multiple `--set` flags can be used to override multiple values. Each flag is processed in order. The values are applied on top of the chart's defaults.

-----

## Exercise 4.2 Solution

```bash
helm install resource-web bitnami/nginx \
  --namespace ex-4-2 \
  --set resources.requests.memory=128Mi \
  --set resources.requests.cpu=100m \
  --set service.type=ClusterIP
```

Nested values use dot notation. The path `resources.requests.memory` corresponds to the YAML structure.

```yaml
resources:
  requests:
    memory: 128Mi
```

-----

## Exercise 4.3 Solution

First, inspect the values.

```bash
helm show values bitnami/redis | head -100
```

Look for the `architecture` and `auth` sections. Then install with the correct values.

```bash
helm install custom-cache bitnami/redis \
  --namespace ex-4-3 \
  --set architecture=standalone \
  --set auth.enabled=false
```

The `helm show values` command is essential for understanding what configuration options a chart provides. Always inspect values before installing to make informed decisions about customization.

-----

## Exercise 5.1 Solution

Install nginx frontend.

```bash
helm install frontend bitnami/nginx \
  --namespace ex-5-1 \
  --set service.type=ClusterIP
```

Install redis backend.

```bash
helm install backend bitnami/redis \
  --namespace ex-5-1 \
  --set architecture=standalone \
  --set auth.enabled=false \
  --set master.service.type=ClusterIP
```

For redis, when using standalone architecture, the service name includes "master" (e.g., `backend-redis-master`). The `master.service.type` sets the service type for the master node.

When deploying multiple charts to the same namespace, ensure release names are unique and understand how each chart names its resources to avoid conflicts.

-----

## Exercise 5.2 Solution

The installation failed because the repository name was misspelled (`bitnaim` instead of `bitnami`). Clean up and install correctly.

First, check if anything was created.

```bash
helm list -n ex-5-2
```

If any failed release exists, uninstall it.

```bash
helm uninstall broken-cache -n ex-5-2 2>/dev/null || true
```

Install correctly.

```bash
helm install working-cache bitnami/redis \
  --namespace ex-5-2 \
  --set architecture=standalone \
  --set auth.enabled=false \
  --set master.service.type=ClusterIP
```

When debugging failed installations, start by checking what Helm recorded (helm list), then check Kubernetes resources (kubectl get all), and finally clean up any partial state before retrying.

-----

## Exercise 5.3 Solution

Install with comprehensive configuration.

```bash
helm install production-web bitnami/nginx \
  --namespace ex-5-3 \
  --set replicaCount=3 \
  --set service.type=ClusterIP \
  --set resources.requests.memory=256Mi \
  --set resources.requests.cpu=200m \
  --set resources.limits.memory=512Mi \
  --set resources.limits.cpu=500m
```

Retrieve information for team documentation.

```bash
# Status shows current state and notes
helm status production-web -n ex-5-3

# Manifest shows exactly what was created
helm get manifest production-web -n ex-5-3

# Values shows what configuration was applied
helm get values production-web -n ex-5-3

# All values including defaults
helm get values production-web -n ex-5-3 --all
```

For production deployments, always document the exact values used. The `helm get values` command captures this, and `helm get manifest` shows the resulting Kubernetes resources.

-----

## Common Mistakes

**Repository not updated before search.** If you add a new repository or need the latest charts, always run `helm repo update`. Otherwise, you might not see new charts or versions.

**Release name conflicts.** Release names must be unique within a namespace. If you get "cannot re-use a name" errors, either choose a different name or uninstall the existing release first.

**Wrong --set syntax.** Use `--set key=value` with an equals sign, not a colon. For nested values, use dots: `--set parent.child=value`.

**Namespace not existing.** By default, Helm does not create namespaces. Either create the namespace first with `kubectl create namespace` or use `--create-namespace` during installation.

**Chart not found in repository.** Verify the repository name and chart name are correct. Use `helm search repo` to find available charts. Remember that chart references include the repository prefix (e.g., `bitnami/nginx`, not just `nginx`).

**Confusing chart name with release name.** The chart name (e.g., `bitnami/nginx`) specifies what to install. The release name (e.g., `my-nginx`) is how you identify this installation. They are different things.

**Not inspecting values before installing.** Always run `helm show values <chart>` before installing to understand what configuration options are available and what the defaults are.

**Forgetting namespace on commands.** Most Helm commands require `-n <namespace>` or `--namespace <namespace>`. If you omit it, Helm uses the default namespace from your kubeconfig context.

-----

## Helm Commands Cheat Sheet

| Task | Command |
|------|---------|
| Add repository | `helm repo add <name> <url>` |
| List repositories | `helm repo list` |
| Update repositories | `helm repo update` |
| Search for charts | `helm search repo <keyword>` |
| Search all versions | `helm search repo <chart> --versions` |
| Remove repository | `helm repo remove <name>` |
| Show chart metadata | `helm show chart <chart>` |
| Show chart values | `helm show values <chart>` |
| Show chart readme | `helm show readme <chart>` |
| Install chart | `helm install <release> <chart> -n <ns>` |
| Install with namespace creation | `helm install <release> <chart> -n <ns> --create-namespace` |
| Install with values | `helm install <release> <chart> --set key=value` |
| List releases | `helm list -n <namespace>` |
| List all releases | `helm list -A` |
| Release status | `helm status <release> -n <ns>` |
| Release manifest | `helm get manifest <release> -n <ns>` |
| Release values | `helm get values <release> -n <ns>` |
| All release info | `helm get all <release> -n <ns>` |
| Uninstall release | `helm uninstall <release> -n <ns>` |
