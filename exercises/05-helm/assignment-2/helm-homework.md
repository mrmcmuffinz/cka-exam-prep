# Helm Lifecycle Management Homework

This homework file contains 15 progressive exercises organized into five difficulty levels. The exercises assume you have worked through `helm-tutorial.md` and completed 05-helm/assignment-1 (Helm Basics). Each exercise uses its own namespace where applicable. Complete the exercises in order; the progression is designed to build skills incrementally.

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

## Level 1: Upgrade Operations

### Exercise 1.1

**Objective:** Upgrade an existing release with new values.

**Setup:**

```bash
kubectl create namespace ex-1-1
helm install web-app bitnami/nginx \
  --namespace ex-1-1 \
  --set replicaCount=1 \
  --set service.type=ClusterIP
```

**Task:**

Upgrade the web-app release to use 3 replicas instead of 1. Keep the service type as ClusterIP.

**Verification:**

```bash
# should have 3 replicas
kubectl get deployment -n ex-1-1 -o jsonpath='{.items[0].spec.replicas}'; echo

# should be revision 2
helm history web-app -n ex-1-1 | grep -c "deployed\|superseded"
```

Expected: 3 replicas, revision 2 exists in history.

-----

### Exercise 1.2

**Objective:** Use dry-run to preview an upgrade before applying it.

**Setup:**

Use the web-app release from exercise 1.1.

**Task:**

Preview what would happen if you upgraded web-app to 5 replicas and added resource requests (memory: 128Mi, cpu: 100m). Do not actually apply the upgrade.

**Verification:**

```bash
# replica count should still be 3 (unchanged)
kubectl get deployment -n ex-1-1 -o jsonpath='{.items[0].spec.replicas}'; echo

# dry-run should show the change without applying
helm upgrade web-app bitnami/nginx -n ex-1-1 \
  --set replicaCount=5 \
  --set service.type=ClusterIP \
  --set resources.requests.memory=128Mi \
  --set resources.requests.cpu=100m \
  --dry-run | grep -A2 "replicas:"
```

Expected: Replicas still 3 in cluster, dry-run output shows replicas: 5.

-----

### Exercise 1.3

**Objective:** View release history and understand revision tracking.

**Setup:**

Use the web-app release from previous exercises.

**Task:**

View the complete history of the web-app release. Identify the revision number of the original installation and the most recent upgrade.

**Verification:**

```bash
# show all revisions
helm history web-app -n ex-1-1

# count total revisions
helm history web-app -n ex-1-1 | tail -n +2 | wc -l
```

Expected: At least 2 revisions shown, with descriptions indicating install and upgrade.

-----

## Level 2: Values Files

### Exercise 2.1

**Objective:** Create and use a values file for configuration.

**Setup:**

```bash
kubectl create namespace ex-2-1
```

**Task:**

Create a values file named `ex-2-1-values.yaml` that sets replicaCount to 2 and service.type to ClusterIP. Then install nginx with release name `values-demo` using this values file.

**Verification:**

```bash
# file should exist
cat ex-2-1-values.yaml

# release should be deployed
helm list -n ex-2-1 | grep values-demo

# should have 2 replicas
kubectl get deployment -n ex-2-1 -o jsonpath='{.items[0].spec.replicas}'; echo
```

Expected: Values file created, release deployed with 2 replicas.

-----

### Exercise 2.2

**Objective:** Override values file settings with --set.

**Setup:**

Use the values-demo release from exercise 2.1.

**Task:**

Upgrade the values-demo release using the same values file but override the replicaCount to 4 using the --set flag.

**Verification:**

```bash
# should have 4 replicas (--set override)
kubectl get deployment -n ex-2-1 -o jsonpath='{.items[0].spec.replicas}'; echo

# values should show replicaCount: 4
helm get values values-demo -n ex-2-1
```

Expected: 4 replicas, showing that --set overrides the values file.

-----

### Exercise 2.3

**Objective:** Use multiple values files with proper precedence.

**Setup:**

```bash
kubectl create namespace ex-2-3
```

**Task:**

Create two values files: base.yaml with replicaCount: 1 and service.type: ClusterIP, and overlay.yaml with replicaCount: 3. Install nginx with release name `layered-config` using both files so that overlay.yaml takes precedence for replicaCount.

**Verification:**

```bash
# both files should exist
cat base.yaml
cat overlay.yaml

# should have 3 replicas (from overlay)
kubectl get deployment -n ex-2-3 -o jsonpath='{.items[0].spec.replicas}'; echo

# should have ClusterIP (from base)
kubectl get svc -n ex-2-3 -o jsonpath='{.items[0].spec.type}'; echo
```

Expected: 3 replicas from overlay.yaml, ClusterIP service from base.yaml.

-----

## Level 3: Debugging Lifecycle Issues

### Exercise 3.1

**Objective:** Debug and fix an upgrade that used incorrect value reuse.

**Setup:**

```bash
kubectl create namespace ex-3-1
helm install config-app bitnami/nginx \
  --namespace ex-3-1 \
  --set replicaCount=2 \
  --set service.type=ClusterIP \
  --set resources.requests.memory=128Mi
```

A colleague upgraded the release to change only the replica count but lost the resource configuration.

```bash
helm upgrade config-app bitnami/nginx \
  --namespace ex-3-1 \
  --set replicaCount=3 \
  --set service.type=ClusterIP
```

**Task:**

The resource requests are now missing. Fix the release so it has replicaCount=3, service.type=ClusterIP, and resources.requests.memory=128Mi.

**Verification:**

```bash
# should have 3 replicas
kubectl get deployment -n ex-3-1 -o jsonpath='{.items[0].spec.replicas}'; echo

# should have memory request
kubectl get deployment -n ex-3-1 -o jsonpath='{.items[0].spec.template.spec.containers[0].resources.requests.memory}'; echo
```

Expected: 3 replicas and 128Mi memory request.

-----

### Exercise 3.2

**Objective:** Debug a rollback to the wrong revision.

**Setup:**

```bash
kubectl create namespace ex-3-2
helm install rollback-demo bitnami/nginx --namespace ex-3-2 --set replicaCount=1 --set service.type=ClusterIP
helm upgrade rollback-demo bitnami/nginx --namespace ex-3-2 --set replicaCount=2 --set service.type=ClusterIP
helm upgrade rollback-demo bitnami/nginx --namespace ex-3-2 --set replicaCount=3 --set service.type=ClusterIP
helm upgrade rollback-demo bitnami/nginx --namespace ex-3-2 --set replicaCount=5 --set service.type=ClusterIP
```

A colleague wanted to rollback to 3 replicas but accidentally rolled back too far.

```bash
helm rollback rollback-demo 1 -n ex-3-2
```

**Task:**

The release now has 1 replica (from revision 1). Fix it by rolling back to the revision that had 3 replicas.

**Verification:**

```bash
# should have 3 replicas
kubectl get deployment -n ex-3-2 -o jsonpath='{.items[0].spec.replicas}'; echo

# check history shows the rollbacks
helm history rollback-demo -n ex-3-2
```

Expected: 3 replicas.

-----

### Exercise 3.3

**Objective:** Debug an upgrade that failed due to --reuse-values issues.

**Setup:**

```bash
kubectl create namespace ex-3-3
cat > original-values.yaml <<'EOF'
replicaCount: 2
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

helm install complex-app bitnami/nginx --namespace ex-3-3 -f original-values.yaml
```

A colleague tried to add a new setting but used --reuse-values incorrectly with a values file, causing unexpected behavior.

```bash
cat > new-setting.yaml <<'EOF'
replicaCount: 4
EOF

helm upgrade complex-app bitnami/nginx --namespace ex-3-3 --reuse-values -f new-setting.yaml
```

**Task:**

Check what values are currently applied. Then upgrade the release to have 4 replicas while keeping all the original resource settings. Do not use --reuse-values.

**Verification:**

```bash
# should have 4 replicas
kubectl get deployment -n ex-3-3 -o jsonpath='{.items[0].spec.replicas}'; echo

# should still have memory request
kubectl get deployment -n ex-3-3 -o jsonpath='{.items[0].spec.template.spec.containers[0].resources.requests.memory}'; echo

# values should show complete configuration
helm get values complex-app -n ex-3-3
```

Expected: 4 replicas with all resource settings preserved.

-----

## Level 4: Rollback Operations

### Exercise 4.1

**Objective:** Roll back to the previous revision after a problematic upgrade.

**Setup:**

```bash
kubectl create namespace ex-4-1
helm install stable-app bitnami/nginx \
  --namespace ex-4-1 \
  --set replicaCount=2 \
  --set service.type=ClusterIP
```

Simulate a problematic upgrade.

```bash
helm upgrade stable-app bitnami/nginx \
  --namespace ex-4-1 \
  --set replicaCount=10 \
  --set service.type=ClusterIP
```

**Task:**

The upgrade to 10 replicas is too many. Roll back to the previous revision (2 replicas).

**Verification:**

```bash
# should have 2 replicas
kubectl get deployment -n ex-4-1 -o jsonpath='{.items[0].spec.replicas}'; echo

# history should show rollback
helm history stable-app -n ex-4-1 | tail -1
```

Expected: 2 replicas, history shows rollback.

-----

### Exercise 4.2

**Objective:** Roll back to a specific revision number.

**Setup:**

```bash
kubectl create namespace ex-4-2
helm install versioned-app bitnami/nginx --namespace ex-4-2 --set replicaCount=1 --set service.type=ClusterIP
helm upgrade versioned-app bitnami/nginx --namespace ex-4-2 --set replicaCount=2 --set service.type=ClusterIP
helm upgrade versioned-app bitnami/nginx --namespace ex-4-2 --set replicaCount=3 --set service.type=ClusterIP
helm upgrade versioned-app bitnami/nginx --namespace ex-4-2 --set replicaCount=4 --set service.type=ClusterIP
```

**Task:**

Roll back to revision 2 (which had 2 replicas).

**Verification:**

```bash
# should have 2 replicas
kubectl get deployment -n ex-4-2 -o jsonpath='{.items[0].spec.replicas}'; echo

# should be revision 5 now (rollback creates new revision)
helm history versioned-app -n ex-4-2 | tail -1 | awk '{print $1}'
```

Expected: 2 replicas, latest revision is 5 (the rollback).

-----

### Exercise 4.3

**Objective:** Understand that rollback creates a new revision.

**Setup:**

Use the versioned-app release from exercise 4.2.

**Task:**

Roll back to revision 4 (which had 4 replicas), then check the history to verify that a new revision was created.

**Verification:**

```bash
# should have 4 replicas
kubectl get deployment -n ex-4-2 -o jsonpath='{.items[0].spec.replicas}'; echo

# should now have 6 revisions
helm history versioned-app -n ex-4-2 | tail -n +2 | wc -l

# latest should say "Rollback to 4"
helm history versioned-app -n ex-4-2 | tail -1
```

Expected: 4 replicas, 6 total revisions, latest is a rollback.

-----

## Level 5: Complex Lifecycle

### Exercise 5.1

**Objective:** Manage a complete lifecycle: install, upgrade, rollback, uninstall.

**Setup:**

```bash
kubectl create namespace ex-5-1
```

**Task:**

1. Install nginx with release name `full-lifecycle` with 1 replica and ClusterIP service
2. Upgrade to 2 replicas
3. Upgrade to 3 replicas with memory request 128Mi
4. Roll back to the 2-replica state
5. Verify the final state has 2 replicas and no custom resource requests

**Verification:**

```bash
# should have 2 replicas
kubectl get deployment -n ex-5-1 -o jsonpath='{.items[0].spec.replicas}'; echo

# should have 4 revisions (install + 2 upgrades + rollback)
helm history full-lifecycle -n ex-5-1 | tail -n +2 | wc -l

# resource requests should not include custom memory
kubectl get deployment -n ex-5-1 -o jsonpath='{.items[0].spec.template.spec.containers[0].resources}'; echo
```

Expected: 2 replicas, 4 revisions, no custom resources.

-----

### Exercise 5.2

**Objective:** Debug and recover from a failed upgrade.

**Setup:**

```bash
kubectl create namespace ex-5-2
cat > stable-config.yaml <<'EOF'
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

helm install production-app bitnami/nginx --namespace ex-5-2 -f stable-config.yaml
```

A colleague made a problematic upgrade.

```bash
helm upgrade production-app bitnami/nginx --namespace ex-5-2 \
  --set replicaCount=100 \
  --set service.type=ClusterIP
```

**Task:**

The 100 replicas are way too many and resource settings were lost. Roll back to the stable state (2 replicas with proper resource settings), then verify the application is healthy.

**Verification:**

```bash
# should have 2 replicas
kubectl get deployment -n ex-5-2 -o jsonpath='{.items[0].spec.replicas}'; echo

# should have memory request
kubectl get deployment -n ex-5-2 -o jsonpath='{.items[0].spec.template.spec.containers[0].resources.requests.memory}'; echo

# pods should be running
kubectl get pods -n ex-5-2
```

Expected: 2 replicas with 128Mi memory request, pods running.

-----

### Exercise 5.3

**Objective:** Design an upgrade strategy with built-in rollback capability.

**Setup:**

```bash
kubectl create namespace ex-5-3
```

**Task:**

Create a values file `production.yaml` with 3 replicas, ClusterIP service, and resource requests (memory: 256Mi, cpu: 200m). Install nginx with release name `strategic-app` using this file. Then create a second values file `update.yaml` that changes replicas to 4. Perform the upgrade with --atomic flag and 2-minute timeout to ensure automatic rollback on failure.

**Verification:**

```bash
# values file exists
cat production.yaml

# update file exists
cat update.yaml

# should have 4 replicas (upgrade succeeded)
kubectl get deployment -n ex-5-3 -o jsonpath='{.items[0].spec.replicas}'; echo

# should have 2 revisions
helm history strategic-app -n ex-5-3 | tail -n +2 | wc -l
```

Expected: Values files created, 4 replicas, 2 revisions.

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

rm -f ex-2-1-values.yaml base.yaml overlay.yaml original-values.yaml new-setting.yaml stable-config.yaml production.yaml update.yaml
```

## Key Takeaways

After completing these exercises, you should be comfortable with upgrading releases with new values, using dry-run to preview changes safely, creating and using values files for configuration, combining values files with --set overrides, understanding values file precedence, using --reuse-values appropriately, rolling back to any revision, understanding that rollback creates a new revision, managing complete release lifecycles, and using --atomic for safer production upgrades.
