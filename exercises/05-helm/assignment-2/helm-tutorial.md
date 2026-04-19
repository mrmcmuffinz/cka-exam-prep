# Helm Lifecycle Management Tutorial

This tutorial covers the complete lifecycle of Helm releases. You will learn how to upgrade releases with new values or chart versions, use values files for configuration, understand the difference between --reuse-values and --reset-values, roll back to previous revisions, inspect release history, and cleanly uninstall releases. These operations are essential for managing applications in production and are frequently tested on the CKA exam.

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

## Part 1: Setting Up a Release to Manage

Before we can explore lifecycle operations, we need a release to work with. Install nginx with some initial configuration.

```bash
helm install lifecycle-demo bitnami/nginx \
  --namespace tutorial-helm \
  --set replicaCount=1 \
  --set service.type=ClusterIP
```

Verify the installation.

```bash
helm list -n tutorial-helm
kubectl get pods -n tutorial-helm
```

Check the current values.

```bash
helm get values lifecycle-demo -n tutorial-helm
```

You should see the values you set: replicaCount: 1 and service.type: ClusterIP. Let us now explore how to change these values.

## Part 2: Upgrading Releases

The `helm upgrade` command modifies an existing release. You can change values, upgrade to a new chart version, or both.

### Upgrading with New Values

Change the replica count from 1 to 3.

```bash
helm upgrade lifecycle-demo bitnami/nginx \
  --namespace tutorial-helm \
  --set replicaCount=3 \
  --set service.type=ClusterIP
```

The upgrade command takes the same format as install: `helm upgrade <release> <chart>`. Helm computes the difference between the current state and the desired state, then applies changes.

Verify the change.

```bash
kubectl get deployment -n tutorial-helm
helm get values lifecycle-demo -n tutorial-helm
```

You should now see 3 replicas.

### Previewing Changes with --dry-run

Before making changes in production, you can preview what would happen.

```bash
helm upgrade lifecycle-demo bitnami/nginx \
  --namespace tutorial-helm \
  --set replicaCount=5 \
  --set service.type=ClusterIP \
  --dry-run
```

The `--dry-run` flag renders the templates and shows what would be applied, but does not actually change anything. This is invaluable for catching errors before they affect the cluster.

### Understanding Revisions

Each upgrade creates a new revision. Check the history.

```bash
helm history lifecycle-demo -n tutorial-helm
```

You should see revision 1 (the original install) and revision 2 (the upgrade). Each revision tracks what values were used and the status of that deployment.

## Part 3: Values Files

While `--set` is convenient for a few values, production deployments often have many configuration options. Values files provide a cleaner way to manage configuration.

### Creating a Values File

Create a values file with our desired configuration.

```bash
cat > my-values.yaml <<'EOF'
replicaCount: 2

service:
  type: ClusterIP

resources:
  requests:
    memory: 128Mi
    cpu: 100m
  limits:
    memory: 256Mi
    cpu: 200m
EOF
```

### Using a Values File

Apply the values file during upgrade.

```bash
helm upgrade lifecycle-demo bitnami/nginx \
  --namespace tutorial-helm \
  -f my-values.yaml
```

The `-f` flag (or `--values`) specifies a values file. The file structure mirrors the chart's values.yaml structure.

Verify the changes.

```bash
helm get values lifecycle-demo -n tutorial-helm
kubectl get deployment -n tutorial-helm -o jsonpath='{.items[0].spec.replicas}'; echo
```

### Combining Values Files with --set

You can combine values files with --set flags. The --set values take precedence.

```bash
helm upgrade lifecycle-demo bitnami/nginx \
  --namespace tutorial-helm \
  -f my-values.yaml \
  --set replicaCount=4
```

Even though my-values.yaml says replicaCount: 2, the --set flag overrides it to 4.

```bash
kubectl get deployment -n tutorial-helm -o jsonpath='{.items[0].spec.replicas}'; echo
```

### Multiple Values Files

You can specify multiple values files. Later files override earlier ones.

```bash
cat > base-values.yaml <<'EOF'
replicaCount: 1
service:
  type: ClusterIP
EOF

cat > production-values.yaml <<'EOF'
replicaCount: 3
resources:
  requests:
    memory: 256Mi
    cpu: 200m
EOF
```

Apply both files.

```bash
helm upgrade lifecycle-demo bitnami/nginx \
  --namespace tutorial-helm \
  -f base-values.yaml \
  -f production-values.yaml
```

The order matters. production-values.yaml overrides replicaCount from base-values.yaml, resulting in 3 replicas.

## Part 4: Reusing vs Resetting Values

When upgrading, you have two options for handling existing values: keep them or reset them.

### --reuse-values

The `--reuse-values` flag keeps all values from the current release and merges in any new values you specify.

```bash
helm upgrade lifecycle-demo bitnami/nginx \
  --namespace tutorial-helm \
  --reuse-values \
  --set image.pullPolicy=Always
```

This keeps all existing values (replicaCount, service.type, resources, etc.) and adds image.pullPolicy=Always.

Check the values.

```bash
helm get values lifecycle-demo -n tutorial-helm
```

You should see all previous values plus the new one.

### --reset-values

The `--reset-values` flag discards all existing custom values and starts fresh from the chart defaults.

```bash
helm upgrade lifecycle-demo bitnami/nginx \
  --namespace tutorial-helm \
  --reset-values \
  --set replicaCount=2 \
  --set service.type=ClusterIP
```

Now check the values.

```bash
helm get values lifecycle-demo -n tutorial-helm
```

Only replicaCount and service.type are shown. All previous custom values (resources, image.pullPolicy) are gone.

### When to Use Each

Use `--reuse-values` when making incremental changes and you want to keep everything else the same. This is useful for adding a new setting without having to re-specify everything.

Use `--reset-values` (or simply omit both flags and specify all desired values) when you want explicit control over what values are applied. This is safer when upgrading to a new chart version where defaults may have changed.

The pitfall with `--reuse-values` is that when chart defaults change in a new version, your release keeps the old behavior because it reuses the old values rather than picking up new defaults.

## Part 5: Rolling Back

When an upgrade causes problems, you can roll back to a previous revision.

### Viewing History

First, check what revisions are available.

```bash
helm history lifecycle-demo -n tutorial-helm
```

Each revision shows the revision number, update time, status, chart version, and description.

### Rolling Back to Previous Revision

Roll back to the previous revision.

```bash
helm rollback lifecycle-demo -n tutorial-helm
```

Without a revision number, Helm rolls back to the previous revision.

### Rolling Back to Specific Revision

Roll back to a specific revision number.

```bash
helm rollback lifecycle-demo 1 -n tutorial-helm
```

This rolls back to revision 1 (the original installation).

### Understanding Rollback Revisions

Important: rolling back creates a new revision, it does not delete history.

```bash
helm history lifecycle-demo -n tutorial-helm
```

You will see the rollback listed as a new revision with description "Rollback to X". This means you can always see what happened and can even roll back the rollback if needed.

### Rollback Limitations

Rollback restores the Helm values and templates, but some changes may be irreversible at the cluster level. For example, if you deleted a PVC that had data, rolling back the Helm release will not recover that data. Rollback is for configuration, not data recovery.

## Part 6: Uninstalling Releases

When you no longer need a release, uninstall it.

### Basic Uninstall

```bash
helm install to-uninstall bitnami/nginx \
  --namespace tutorial-helm \
  --set service.type=ClusterIP
```

```bash
helm uninstall to-uninstall -n tutorial-helm
```

This removes all Kubernetes resources created by the release. Verify.

```bash
kubectl get all -n tutorial-helm -l app.kubernetes.io/instance=to-uninstall
```

Nothing should be returned.

### What Gets Deleted

The uninstall command removes all resources that were part of the release: Deployments, Services, ConfigMaps, Secrets, and so on. By default, it also removes the release from Helm's history.

### Keeping History

If you want to keep the release in history (for auditing or potential reinstallation), use `--keep-history`.

```bash
helm install history-demo bitnami/nginx \
  --namespace tutorial-helm \
  --set service.type=ClusterIP

helm uninstall history-demo -n tutorial-helm --keep-history
```

Now check history.

```bash
helm history history-demo -n tutorial-helm
```

The release appears with status "uninstalled". You cannot reinstall with the same name while the history exists, but you can see what was there.

### Namespace Cleanup

Helm does not delete namespaces. If you created a namespace specifically for a release, delete it separately.

```bash
kubectl delete namespace some-namespace
```

Also note that some resources like PersistentVolumeClaims may have Retain reclaim policies and will not be deleted with the release. Check for leftover PVCs if storage was involved.

## Part 7: The Atomic Flag

For production upgrades, the `--atomic` flag provides safer rollback behavior.

```bash
helm upgrade lifecycle-demo bitnami/nginx \
  --namespace tutorial-helm \
  -f my-values.yaml \
  --atomic \
  --timeout 5m
```

The `--atomic` flag tells Helm to automatically roll back to the previous revision if the upgrade fails. The `--timeout` flag sets how long to wait for the upgrade to succeed before considering it failed.

This is particularly useful in CI/CD pipelines where you want automatic recovery from failed deployments.

## Cleanup

Remove all the releases and files we created in this tutorial.

```bash
helm uninstall lifecycle-demo -n tutorial-helm
kubectl delete namespace tutorial-helm
rm -f my-values.yaml base-values.yaml production-values.yaml
```

## Reference Commands

| Task | Command |
|------|---------|
| Upgrade release | `helm upgrade <release> <chart> -n <ns>` |
| Upgrade with values | `helm upgrade <release> <chart> --set key=value` |
| Upgrade with values file | `helm upgrade <release> <chart> -f values.yaml` |
| Preview upgrade | `helm upgrade <release> <chart> --dry-run` |
| Keep existing values | `helm upgrade <release> <chart> --reuse-values` |
| Reset to defaults | `helm upgrade <release> <chart> --reset-values` |
| Atomic upgrade | `helm upgrade <release> <chart> --atomic` |
| Install or upgrade | `helm upgrade <release> <chart> --install` |
| View history | `helm history <release> -n <ns>` |
| Rollback to previous | `helm rollback <release> -n <ns>` |
| Rollback to revision | `helm rollback <release> <revision> -n <ns>` |
| Uninstall release | `helm uninstall <release> -n <ns>` |
| Uninstall keep history | `helm uninstall <release> -n <ns> --keep-history` |
