# Helm Basics Homework

This homework file contains 15 progressive exercises organized into five difficulty levels. The exercises assume you have worked through `helm-tutorial.md`. Each exercise uses its own namespace where applicable. Complete the exercises in order; the progression is designed to build skills incrementally. Use `helm-homework-answers.md` only after a genuine attempt at each exercise.

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

## Level 1: Repository Management

### Exercise 1.1

**Objective:** Add a new Helm repository and verify it was added correctly.

**Setup:**

No namespace needed for this exercise.

**Task:**

Add the Jetstack repository (https://charts.jetstack.io) with the name `jetstack`. List all configured repositories to verify it appears.

**Verification:**

```bash
# repository should appear in list
helm repo list | grep jetstack

# should show jetstack URL
helm repo list | grep "charts.jetstack.io"
```

Expected: The jetstack repository appears in the list with the correct URL.

-----

### Exercise 1.2

**Objective:** Search for charts in a repository and find specific chart versions.

**Setup:**

Ensure you have the bitnami repository added and updated.

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

**Task:**

Search for the redis chart in the bitnami repository. Then find all available versions of the bitnami/redis chart.

**Verification:**

```bash
# should find redis chart
helm search repo bitnami/redis | head -5

# should show multiple versions
helm search repo bitnami/redis --versions | head -10
```

Expected: The redis chart appears in search results, and multiple versions are shown with the --versions flag.

-----

### Exercise 1.3

**Objective:** Update repository indexes and understand why this matters.

**Setup:**

No namespace needed.

**Task:**

Update all repository indexes. Before updating, note the timestamp of when repositories were last updated (if visible), then run the update and verify it completed.

**Verification:**

```bash
# update should complete without errors
helm repo update

# list should show repositories
helm repo list
```

Expected: The update command completes successfully and shows "Successfully got an update" for each repository.

-----

## Level 2: Chart Installation

### Exercise 2.1

**Objective:** Install a chart with default values.

**Setup:**

```bash
kubectl create namespace ex-2-1
```

**Task:**

Install the bitnami/nginx chart with the release name `web-server` in namespace `ex-2-1`. Use all default values.

**Verification:**

```bash
# release should be deployed
helm list -n ex-2-1 | grep web-server

# status should show deployed
helm status web-server -n ex-2-1 | grep STATUS

# pods should be running
kubectl get pods -n ex-2-1
```

Expected: The release is listed with status DEPLOYED, and pods are running.

-----

### Exercise 2.2

**Objective:** Install a chart to a namespace that does not exist yet.

**Setup:**

Ensure namespace ex-2-2 does not exist.

```bash
kubectl delete namespace ex-2-2 --ignore-not-found
```

**Task:**

Install the bitnami/redis chart with release name `cache-server` into namespace `ex-2-2`. The namespace should be created automatically as part of the installation.

**Verification:**

```bash
# namespace should exist
kubectl get namespace ex-2-2

# release should be deployed
helm list -n ex-2-2 | grep cache-server

# pods should be running
kubectl get pods -n ex-2-2
```

Expected: The namespace was created, the release is deployed, and pods are running.

-----

### Exercise 2.3

**Objective:** List releases and check detailed status.

**Setup:**

Ensure you have completed exercises 2.1 and 2.2 so releases exist.

**Task:**

List all Helm releases across all namespaces. Then get detailed status information for the web-server release from exercise 2.1.

**Verification:**

```bash
# should show releases from both namespaces
helm list --all-namespaces | grep -E "(web-server|cache-server)"

# should show detailed status including notes
helm status web-server -n ex-2-1
```

Expected: Both releases appear in the all-namespaces list, and status shows deployment information and chart notes.

-----

## Level 3: Debugging Installation Issues

### Exercise 3.1

**Objective:** Debug and fix a failed installation.

**Setup:**

```bash
kubectl create namespace ex-3-1
```

A colleague tried to install nginx but made a mistake. They ran the following command.

```bash
helm install web-app bitnaim/nginx --namespace ex-3-1 2>&1 || true
```

**Task:**

Identify why the installation failed and run the correct command to install nginx with release name `web-app` in namespace `ex-3-1`.

**Verification:**

```bash
# release should be deployed
helm list -n ex-3-1 | grep web-app

# pods should be running
kubectl get pods -n ex-3-1
```

Expected: The release is deployed and pods are running.

-----

### Exercise 3.2

**Objective:** Debug and fix a release name conflict.

**Setup:**

```bash
kubectl create namespace ex-3-2
helm install my-release bitnami/nginx --namespace ex-3-2
```

A colleague tried to install another nginx instance with the same release name in the same namespace.

```bash
helm install my-release bitnami/nginx --namespace ex-3-2 2>&1 || true
```

**Task:**

The second installation failed. Install another nginx instance in the same namespace with a different, valid release name.

**Verification:**

```bash
# should show two releases in ex-3-2
helm list -n ex-3-2

# both should be deployed
helm list -n ex-3-2 | grep deployed | wc -l
```

Expected: Two releases are shown in the namespace, both with deployed status.

-----

### Exercise 3.3

**Objective:** Debug and fix an installation with incorrect --set syntax.

**Setup:**

```bash
kubectl create namespace ex-3-3
```

A colleague tried to install nginx with custom values but used incorrect syntax.

```bash
helm install broken-nginx bitnami/nginx --namespace ex-3-3 --set replicaCount:3 2>&1 || true
```

**Task:**

Identify the syntax error and install nginx with release name `fixed-nginx` in namespace `ex-3-3` with replicaCount set to 3 using the correct syntax.

**Verification:**

```bash
# release should be deployed
helm list -n ex-3-3 | grep fixed-nginx

# should have 3 replicas
kubectl get deployment -n ex-3-3 -o jsonpath='{.items[0].spec.replicas}'; echo
```

Expected: The release is deployed and the deployment has 3 replicas.

-----

## Level 4: Values Customization

### Exercise 4.1

**Objective:** Install a chart with simple --set value overrides.

**Setup:**

```bash
kubectl create namespace ex-4-1
```

**Task:**

Install the bitnami/nginx chart with release name `custom-web` in namespace `ex-4-1`. Configure it with 2 replicas and service type ClusterIP (instead of LoadBalancer).

**Verification:**

```bash
# release deployed
helm list -n ex-4-1 | grep custom-web

# 2 replicas
kubectl get deployment -n ex-4-1 -o jsonpath='{.items[0].spec.replicas}'; echo

# service type ClusterIP
kubectl get svc -n ex-4-1 -o jsonpath='{.items[0].spec.type}'; echo

# check values that were set
helm get values custom-web -n ex-4-1
```

Expected: Release deployed, 2 replicas, service type ClusterIP.

-----

### Exercise 4.2

**Objective:** Configure nested values using --set with dot notation.

**Setup:**

```bash
kubectl create namespace ex-4-2
```

**Task:**

Install the bitnami/nginx chart with release name `resource-web` in namespace `ex-4-2`. Configure resource requests: memory 128Mi and cpu 100m. Also set the service type to ClusterIP.

**Verification:**

```bash
# release deployed
helm list -n ex-4-2 | grep resource-web

# check resource requests
kubectl get deployment -n ex-4-2 -o jsonpath='{.items[0].spec.template.spec.containers[0].resources.requests}'; echo

# should show memory and cpu
kubectl get deployment -n ex-4-2 -o yaml | grep -A2 "requests:"
```

Expected: Release deployed with resource requests for memory (128Mi) and cpu (100m).

-----

### Exercise 4.3

**Objective:** Inspect chart values before installing, then install with informed customization.

**Setup:**

```bash
kubectl create namespace ex-4-3
```

**Task:**

First, inspect the default values for the bitnami/redis chart to understand what configuration options are available. Then install redis with release name `custom-cache` in namespace `ex-4-3` with the following customizations: architecture set to standalone (not replication), and auth.enabled set to false.

**Verification:**

```bash
# release deployed
helm list -n ex-4-3 | grep custom-cache

# architecture should be standalone
helm get values custom-cache -n ex-4-3 | grep architecture

# auth should be disabled
helm get values custom-cache -n ex-4-3 | grep -A1 auth
```

Expected: Release deployed with standalone architecture and auth disabled.

-----

## Level 5: Complex Installations

### Exercise 5.1

**Objective:** Install multiple related charts to create a complete application stack.

**Setup:**

```bash
kubectl create namespace ex-5-1
```

**Task:**

Create a simple application stack with both nginx (as a web frontend) and redis (as a cache backend) in the same namespace. Install nginx with release name `frontend` and redis with release name `backend`. Configure both with service type ClusterIP and redis with standalone architecture and auth disabled.

**Verification:**

```bash
# both releases deployed
helm list -n ex-5-1 | grep -E "(frontend|backend)"

# two services exist
kubectl get svc -n ex-5-1

# pods are running
kubectl get pods -n ex-5-1

# frontend nginx is accessible
kubectl get svc -n ex-5-1 frontend-nginx -o jsonpath='{.spec.type}'; echo

# backend redis is accessible
kubectl get svc -n ex-5-1 backend-redis-master -o jsonpath='{.spec.type}'; echo
```

Expected: Both releases deployed, services exist for both, all pods running.

-----

### Exercise 5.2

**Objective:** Debug an installation where multiple things went wrong.

**Setup:**

```bash
kubectl create namespace ex-5-2
```

A colleague attempted to set up a redis cache with several configuration options but the installation is not working correctly. They cannot remember exactly what commands they ran.

The colleague's notes say: "I wanted redis in standalone mode, no authentication, service type ClusterIP, and I think I set some resource limits."

Examine what exists in the namespace and determine what configuration was actually applied.

```bash
helm install broken-cache bitnaim/redis --namespace ex-5-2 2>&1 || true
```

**Task:**

Clean up any failed state and install redis correctly with release name `working-cache` in namespace `ex-5-2`. Use standalone architecture, disable auth, and set service type to ClusterIP.

**Verification:**

```bash
# release deployed
helm list -n ex-5-2 | grep working-cache

# check configuration
helm get values working-cache -n ex-5-2

# pods running
kubectl get pods -n ex-5-2
```

Expected: Release deployed with the correct configuration, pods running.

-----

### Exercise 5.3

**Objective:** Document an installation for your team.

**Setup:**

```bash
kubectl create namespace ex-5-3
```

**Task:**

Install the bitnami/nginx chart with release name `production-web` in namespace `ex-5-3` with the following configuration: 3 replicas, service type ClusterIP, resource requests of 256Mi memory and 200m cpu, and resource limits of 512Mi memory and 500m cpu.

After installation, retrieve all relevant information that a team member would need to understand and maintain this deployment: the release status, the manifest showing what was created, and the values that were configured.

**Verification:**

```bash
# release deployed
helm list -n ex-5-3 | grep production-web

# 3 replicas
kubectl get deployment -n ex-5-3 -o jsonpath='{.items[0].spec.replicas}'; echo

# resources configured
kubectl get deployment -n ex-5-3 -o jsonpath='{.items[0].spec.template.spec.containers[0].resources}'; echo

# can retrieve release information
helm status production-web -n ex-5-3 > /dev/null && echo "Status: OK"
helm get manifest production-web -n ex-5-3 > /dev/null && echo "Manifest: OK"
helm get values production-web -n ex-5-3 > /dev/null && echo "Values: OK"
```

Expected: Release deployed with 3 replicas, proper resources, and all information retrievable.

-----

## Cleanup

Remove all exercise namespaces when you are done.

```bash
for i in 1 2 3 4 5; do
  for j in 1 2 3; do
    helm uninstall $(helm list -n ex-${i}-${j} -q) -n ex-${i}-${j} 2>/dev/null || true
    kubectl delete namespace ex-${i}-${j} --ignore-not-found --wait=false
  done
done
```

Remove the jetstack repository if you no longer need it.

```bash
helm repo remove jetstack
```

## Key Takeaways

After completing these exercises, you should be comfortable with adding and managing Helm repositories, searching for charts and chart versions, installing charts with default and custom values, using --set for simple and nested value overrides, inspecting charts before installation, listing releases and checking their status, retrieving release manifests and values, and debugging common installation failures.
