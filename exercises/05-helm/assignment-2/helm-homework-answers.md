# Helm Lifecycle Management Homework Answers

This file contains complete solutions for all 15 exercises in `helm-homework.md`, along with explanations and a common mistakes section.

-----

## Exercise 1.1 Solution

```bash
helm upgrade web-app bitnami/nginx \
  --namespace ex-1-1 \
  --set replicaCount=3 \
  --set service.type=ClusterIP
```

The upgrade command has the same structure as install. You must specify all the values you want, or use --reuse-values to keep existing ones. In this case, we explicitly set both replicaCount and service.type.

-----

## Exercise 1.2 Solution

```bash
helm upgrade web-app bitnami/nginx \
  --namespace ex-1-1 \
  --set replicaCount=5 \
  --set service.type=ClusterIP \
  --set resources.requests.memory=128Mi \
  --set resources.requests.cpu=100m \
  --dry-run
```

The `--dry-run` flag renders the templates and shows what would be applied, but does not actually make any changes to the cluster. This is essential for previewing changes in production environments.

-----

## Exercise 1.3 Solution

```bash
helm history web-app -n ex-1-1
```

The output shows all revisions with their revision number, timestamp, status, chart version, and description. Revision 1 is the original install, and each upgrade creates a new revision. The status column shows "deployed" for the current revision and "superseded" for previous ones.

-----

## Exercise 2.1 Solution

Create the values file.

```bash
cat > ex-2-1-values.yaml <<'EOF'
replicaCount: 2
service:
  type: ClusterIP
EOF
```

Install using the values file.

```bash
helm install values-demo bitnami/nginx \
  --namespace ex-2-1 \
  -f ex-2-1-values.yaml
```

Values files use the same YAML structure as the chart's values.yaml. They are cleaner than multiple --set flags and can be version-controlled.

-----

## Exercise 2.2 Solution

```bash
helm upgrade values-demo bitnami/nginx \
  --namespace ex-2-1 \
  -f ex-2-1-values.yaml \
  --set replicaCount=4
```

The --set flag takes precedence over values files. This is useful for environment-specific overrides in CI/CD pipelines where you have a base values file and need to modify specific settings per environment.

-----

## Exercise 2.3 Solution

Create both values files.

```bash
cat > base.yaml <<'EOF'
replicaCount: 1
service:
  type: ClusterIP
EOF

cat > overlay.yaml <<'EOF'
replicaCount: 3
EOF
```

Install with both files, overlay last.

```bash
helm install layered-config bitnami/nginx \
  --namespace ex-2-3 \
  -f base.yaml \
  -f overlay.yaml
```

When using multiple -f flags, later files override earlier ones. This pattern is useful for base/overlay configuration where base.yaml contains common settings and overlay.yaml contains environment-specific overrides.

-----

## Exercise 3.1 Solution

The problem is that the colleague's upgrade did not include the resources setting. When you upgrade without --reuse-values, you must specify all desired values.

Fix by including all required values.

```bash
helm upgrade config-app bitnami/nginx \
  --namespace ex-3-1 \
  --set replicaCount=3 \
  --set service.type=ClusterIP \
  --set resources.requests.memory=128Mi
```

Alternative using --reuse-values (if the original values still exist).

```bash
helm rollback config-app 1 -n ex-3-1
helm upgrade config-app bitnami/nginx \
  --namespace ex-3-1 \
  --reuse-values \
  --set replicaCount=3
```

-----

## Exercise 3.2 Solution

First, check the history to find which revision had 3 replicas.

```bash
helm history rollback-demo -n ex-3-2
```

Revision 3 had replicaCount=3. Roll back to it.

```bash
helm rollback rollback-demo 3 -n ex-3-2
```

When rolling back, you need to know which revision contains the desired state. Use `helm history` to review what each revision contained.

-----

## Exercise 3.3 Solution

The issue is that --reuse-values with a values file behaves unexpectedly. The --reuse-values flag keeps the existing values, and the values file is merged on top. But if the values file only has replicaCount, other chart defaults might also be applied.

The safer approach is to create a complete values file with all desired settings.

```bash
cat > complete-values.yaml <<'EOF'
replicaCount: 4
service:
  type: ClusterIP
image:
  pullPolicy: IfNotPresent
resources:
  requests:
    memory: 64Mi
    cpu: 50m
  limits:
    memory: 128Mi
    cpu: 100m
EOF

helm upgrade complex-app bitnami/nginx \
  --namespace ex-3-3 \
  -f complete-values.yaml
```

This gives explicit control over all values without relying on --reuse-values behavior.

-----

## Exercise 4.1 Solution

```bash
helm rollback stable-app -n ex-4-1
```

Without a revision number, Helm rolls back to the previous revision. This is the quickest way to undo the most recent change.

-----

## Exercise 4.2 Solution

```bash
helm rollback versioned-app 2 -n ex-4-2
```

Specifying the revision number rolls back to that exact revision. This creates a new revision (5) that has the same values as revision 2.

-----

## Exercise 4.3 Solution

```bash
helm rollback versioned-app 4 -n ex-4-2
helm history versioned-app -n ex-4-2
```

Each rollback creates a new revision. The history now shows 6 revisions, with the latest saying "Rollback to 4". This means you can always trace what happened and can even undo a rollback by rolling back to a revision before it.

-----

## Exercise 5.1 Solution

Step 1: Install with 1 replica.

```bash
helm install full-lifecycle bitnami/nginx \
  --namespace ex-5-1 \
  --set replicaCount=1 \
  --set service.type=ClusterIP
```

Step 2: Upgrade to 2 replicas.

```bash
helm upgrade full-lifecycle bitnami/nginx \
  --namespace ex-5-1 \
  --set replicaCount=2 \
  --set service.type=ClusterIP
```

Step 3: Upgrade to 3 replicas with memory request.

```bash
helm upgrade full-lifecycle bitnami/nginx \
  --namespace ex-5-1 \
  --set replicaCount=3 \
  --set service.type=ClusterIP \
  --set resources.requests.memory=128Mi
```

Step 4: Roll back to 2-replica state (revision 2).

```bash
helm rollback full-lifecycle 2 -n ex-5-1
```

The rollback to revision 2 removes the memory request because revision 2 did not have it.

-----

## Exercise 5.2 Solution

Roll back to the stable state.

```bash
helm rollback production-app 1 -n ex-5-2
```

Verify the state.

```bash
kubectl get deployment -n ex-5-2 -o jsonpath='{.items[0].spec.replicas}'; echo
kubectl get deployment -n ex-5-2 -o jsonpath='{.items[0].spec.template.spec.containers[0].resources.requests.memory}'; echo
kubectl get pods -n ex-5-2
```

Rolling back to revision 1 restores the original values file configuration with 2 replicas and proper resource settings.

-----

## Exercise 5.3 Solution

Create the production values file.

```bash
cat > production.yaml <<'EOF'
replicaCount: 3
service:
  type: ClusterIP
resources:
  requests:
    memory: 256Mi
    cpu: 200m
EOF
```

Install the initial release.

```bash
helm install strategic-app bitnami/nginx \
  --namespace ex-5-3 \
  -f production.yaml
```

Create the update values file.

```bash
cat > update.yaml <<'EOF'
replicaCount: 4
service:
  type: ClusterIP
resources:
  requests:
    memory: 256Mi
    cpu: 200m
EOF
```

Upgrade with atomic flag.

```bash
helm upgrade strategic-app bitnami/nginx \
  --namespace ex-5-3 \
  -f update.yaml \
  --atomic \
  --timeout 2m
```

The --atomic flag ensures that if the upgrade fails for any reason (pods not becoming ready, timeout exceeded), Helm automatically rolls back to the previous revision. This is essential for production deployments.

-----

## Common Mistakes

**Using --reuse-values with new chart version.** When upgrading to a new chart version, --reuse-values keeps your old values but may miss new required values or defaults that changed. Prefer explicit values files for chart version upgrades.

**Rollback to non-existent revision.** Always check `helm history` before rolling back to confirm the revision exists and contains the desired configuration.

**Values file syntax errors.** YAML is sensitive to indentation. Use a YAML linter or `helm lint` to catch syntax errors before deployment.

**Upgrade changing unexpected values.** Without --reuse-values, you must specify all desired values. If you only specify some values, others revert to chart defaults.

**Uninstall not cleaning up PVCs.** Helm uninstall removes Helm-managed resources, but PersistentVolumeClaims with Retain policy may remain. Check for leftover PVCs manually.

**Forgetting that rollback creates new revision.** Rollback does not erase history; it creates a new revision with the old configuration. This means revision numbers always increase.

**Not using --dry-run in production.** Always preview changes with --dry-run before applying to production clusters.

**Mixing values files and --set without understanding precedence.** Remember: chart defaults < first -f file < subsequent -f files < --set flags.

-----

## Lifecycle Commands Cheat Sheet

| Task | Command |
|------|---------|
| Upgrade release | `helm upgrade <release> <chart> -n <ns>` |
| Upgrade with values file | `helm upgrade <release> <chart> -f values.yaml` |
| Upgrade with --set override | `helm upgrade <release> <chart> -f values.yaml --set key=value` |
| Preview upgrade | `helm upgrade <release> <chart> --dry-run` |
| Keep existing values | `helm upgrade <release> <chart> --reuse-values` |
| Reset to defaults | `helm upgrade <release> <chart> --reset-values` |
| Atomic upgrade | `helm upgrade <release> <chart> --atomic --timeout 5m` |
| Install or upgrade | `helm upgrade <release> <chart> --install` |
| View history | `helm history <release> -n <ns>` |
| Rollback to previous | `helm rollback <release> -n <ns>` |
| Rollback to revision | `helm rollback <release> <revision> -n <ns>` |
| Get current values | `helm get values <release> -n <ns>` |
| Get all values | `helm get values <release> -n <ns> --all` |
| Uninstall release | `helm uninstall <release> -n <ns>` |
| Uninstall keep history | `helm uninstall <release> --keep-history` |
