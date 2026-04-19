# Helm Basics Tutorial

This tutorial introduces Helm, the package manager for Kubernetes. You will learn what Helm is and why it exists, how to manage chart repositories, how to install charts with default and custom values, and how to inspect charts and releases. By the end, you will have hands-on experience with the Helm workflow that is essential for the CKA exam and real-world Kubernetes administration.

All tutorial resources use releases in a dedicated namespace called `tutorial-helm` so they will not collide with anything the exercises create.

## Prerequisites

Verify your cluster is up and kubectl is working before you start.

```bash
kubectl get nodes
kubectl cluster-info
```

You should see at least one node in Ready state. Next, verify Helm is installed.

```bash
helm version
```

You should see version information for Helm 3.x. If Helm is not installed, install it with the following command.

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

Create the tutorial namespace.

```bash
kubectl create namespace tutorial-helm
```

## Part 1: What is Helm?

Helm is the package manager for Kubernetes, analogous to apt for Debian or yum for RHEL. It solves the problem of deploying complex applications that consist of multiple Kubernetes resources (Deployments, Services, ConfigMaps, Secrets, and so on) by packaging them together into a single unit called a chart.

A chart is a collection of files that describe a related set of Kubernetes resources. Charts are versioned and can be shared through repositories, making it easy to distribute and deploy applications consistently across environments.

When you install a chart, Helm creates a release. A release is a specific instance of a chart running in your cluster. You can have multiple releases of the same chart (for example, multiple Redis instances), each with its own name and configuration.

Helm 3 is a client-only tool. There is no server component (Tiller was removed in Helm 3). The Helm CLI communicates directly with the Kubernetes API server using your kubeconfig credentials.

Key concepts to remember are: a chart is the package containing Kubernetes manifests and metadata, a release is an installed instance of a chart, and a revision is a version of a release (incremented on each upgrade or rollback).

## Part 2: Chart Repositories

Charts are distributed through repositories. A repository is simply an HTTP server that hosts a collection of charts along with an index file that lists what is available. Let us work with repositories.

### Adding a Repository

The most commonly used public repository is the Bitnami repository, which contains production-quality charts for many popular applications. Add it to your local Helm configuration.

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
```

The command returns a confirmation message. The repository is now available locally.

### Listing Repositories

See all repositories you have configured.

```bash
helm repo list
```

You should see the bitnami repository listed with its URL.

### Updating Repositories

Repository indexes are cached locally. To get the latest chart versions, update the cache.

```bash
helm repo update
```

This fetches the latest index from each configured repository. Always run this before searching or installing if you have not done so recently.

### Searching for Charts

Search for charts in your configured repositories.

```bash
helm search repo nginx
```

This returns all charts with "nginx" in the name or description. The output shows the chart name (with repository prefix), chart version, app version, and description.

To search for a specific chart.

```bash
helm search repo bitnami/nginx
```

To see all available versions of a chart.

```bash
helm search repo bitnami/nginx --versions
```

### Artifact Hub

For discovering charts from repositories you have not added yet, use Artifact Hub at https://artifacthub.io. It aggregates charts from many sources. You can search there, find installation instructions, and then add the relevant repository to your local configuration.

### Removing a Repository

If you no longer need a repository, remove it.

```bash
helm repo remove bitnami
```

For the rest of this tutorial, we need the bitnami repository, so add it back if you removed it.

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

## Part 3: Installing Charts

Now that you have repositories configured, let us install a chart. We will use a simple nginx deployment as an example.

### Basic Installation

Install nginx with default values.

```bash
helm install my-nginx bitnami/nginx --namespace tutorial-helm
```

The command syntax is `helm install <release-name> <chart>`. The release name (`my-nginx`) is how you will refer to this installation. The chart (`bitnami/nginx`) specifies which chart to install.

Helm outputs information about the release, including the status and any notes from the chart. Check the status.

```bash
helm status my-nginx --namespace tutorial-helm
```

This shows the release status, revision number, and notes. The notes often contain instructions for accessing the deployed application.

### Listing Releases

See all releases in the current namespace.

```bash
helm list --namespace tutorial-helm
```

To see releases in all namespaces.

```bash
helm list --all-namespaces
```

The output shows the release name, namespace, revision, status, chart, and app version.

### What Got Created?

To see exactly what Kubernetes resources the chart created, retrieve the manifest.

```bash
helm get manifest my-nginx --namespace tutorial-helm
```

This outputs the rendered YAML for all resources that were created. You will see Deployments, Services, ConfigMaps, and other resources depending on the chart.

### Installing to a New Namespace

You can create a namespace automatically during installation.

```bash
helm install another-nginx bitnami/nginx \
  --namespace nginx-demo \
  --create-namespace
```

The `--create-namespace` flag creates the namespace if it does not exist.

Let us clean up this extra release and namespace.

```bash
helm uninstall another-nginx --namespace nginx-demo
kubectl delete namespace nginx-demo
```

## Part 4: Customizing Values with --set

Charts have default values for all their configuration options. You can override these defaults at install time using the `--set` flag.

### Viewing Default Values

Before customizing, see what values a chart accepts.

```bash
helm show values bitnami/nginx
```

This outputs the default values.yaml file from the chart. It shows all configurable options with their defaults and often includes comments explaining each option.

For a specific chart, the output might show options like `replicaCount`, `image.repository`, `image.tag`, `service.type`, and many others.

### Simple Value Override

Let us install another nginx release with a custom replica count.

```bash
helm install scaled-nginx bitnami/nginx \
  --namespace tutorial-helm \
  --set replicaCount=3
```

Verify the deployment has three replicas.

```bash
kubectl get deployment -n tutorial-helm -l app.kubernetes.io/instance=scaled-nginx
```

### Nested Values

Many chart values are nested. Use dot notation to set them.

```bash
helm install custom-nginx bitnami/nginx \
  --namespace tutorial-helm \
  --set service.type=ClusterIP \
  --set resources.requests.memory=128Mi \
  --set resources.requests.cpu=100m
```

This sets the service type to ClusterIP (instead of the default LoadBalancer) and configures resource requests.

### Multiple --set Flags

You can use multiple `--set` flags in a single command. Each one is applied in order.

```bash
helm install multi-nginx bitnami/nginx \
  --namespace tutorial-helm \
  --set replicaCount=2 \
  --set service.type=ClusterIP \
  --set image.pullPolicy=Always
```

### Checking Applied Values

To see what values were used for a release (both defaults and overrides).

```bash
helm get values scaled-nginx --namespace tutorial-helm
```

This shows only the values you explicitly set. To see all values including defaults.

```bash
helm get values scaled-nginx --namespace tutorial-helm --all
```

## Part 5: Inspecting Charts

Before installing a chart, you often want to inspect it. Helm provides several commands for this.

### Chart Metadata

See basic information about a chart.

```bash
helm show chart bitnami/nginx
```

This displays the Chart.yaml contents: name, version, app version, description, maintainers, and dependencies.

### Chart README

Many charts include documentation.

```bash
helm show readme bitnami/nginx
```

This displays the README.md from the chart, which typically includes installation instructions, configuration options, and usage examples.

### All Chart Information

To see everything at once.

```bash
helm show all bitnami/nginx
```

This combines chart metadata, values, and readme into one output.

### Downloading a Chart

You can download a chart without installing it to inspect its contents.

```bash
helm pull bitnami/nginx --untar
ls nginx/
```

This downloads and extracts the chart. You will see the directory structure: Chart.yaml (metadata), values.yaml (defaults), templates/ (Kubernetes manifests), and possibly other files like README.md and NOTES.txt.

Clean up the downloaded chart.

```bash
rm -rf nginx/
```

## Part 6: Release Information

For installed releases, you can retrieve various information.

### Release Status

```bash
helm status my-nginx --namespace tutorial-helm
```

Shows the current status, last deployment time, and notes.

### Release History

```bash
helm history my-nginx --namespace tutorial-helm
```

Shows all revisions of the release. For a fresh install, there is only revision 1.

### Release Manifest

```bash
helm get manifest my-nginx --namespace tutorial-helm
```

Shows all the Kubernetes YAML that was applied for this release.

### Release Values

```bash
helm get values my-nginx --namespace tutorial-helm
```

Shows user-supplied values (what you passed via --set or -f).

### All Release Information

```bash
helm get all my-nginx --namespace tutorial-helm
```

Combines manifest, values, notes, and hooks information.

## Cleanup

Remove all the releases we created in this tutorial.

```bash
helm uninstall my-nginx --namespace tutorial-helm
helm uninstall scaled-nginx --namespace tutorial-helm
helm uninstall custom-nginx --namespace tutorial-helm
helm uninstall multi-nginx --namespace tutorial-helm
```

Delete the tutorial namespace.

```bash
kubectl delete namespace tutorial-helm
```

## Reference Commands

| Task | Command |
|------|---------|
| Add repository | `helm repo add <name> <url>` |
| List repositories | `helm repo list` |
| Update repository index | `helm repo update` |
| Search charts | `helm search repo <keyword>` |
| Remove repository | `helm repo remove <name>` |
| Install chart | `helm install <release> <chart> -n <namespace>` |
| Install with namespace creation | `helm install <release> <chart> -n <ns> --create-namespace` |
| List releases | `helm list -n <namespace>` |
| List all releases | `helm list --all-namespaces` |
| Release status | `helm status <release> -n <namespace>` |
| Release manifest | `helm get manifest <release> -n <namespace>` |
| Release values | `helm get values <release> -n <namespace>` |
| Set single value | `--set key=value` |
| Set nested value | `--set parent.child=value` |
| Show chart metadata | `helm show chart <chart>` |
| Show default values | `helm show values <chart>` |
| Show chart readme | `helm show readme <chart>` |
| Show all chart info | `helm show all <chart>` |
| Uninstall release | `helm uninstall <release> -n <namespace>` |
