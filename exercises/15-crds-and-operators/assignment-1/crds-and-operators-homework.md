# CRDs and Operators Homework: Custom Resource Definitions

This homework contains 15 progressive exercises to practice creating and configuring Custom Resource Definitions. Complete the tutorial before attempting these exercises.

---

## Level 1: Basic CRD Creation

### Exercise 1.1

**Objective:** Create a simple CRD with minimal configuration.

**Setup:**

No namespace setup needed as CRDs are cluster-scoped.

**Task:**

Create a CRD for a custom resource called "Application" with the following specifications:
- API group: `apps.example.com`
- Version: v1 (served and storage)
- Kind: Application
- Plural: applications
- Singular: application
- Scope: Namespaced
- Minimal schema with spec.name as a string field

**Verification:**

```bash
# Verify the CRD was created
kubectl get crd applications.apps.example.com

# Expected: Shows the CRD

# Check the API resource is registered
kubectl api-resources | grep applications

# Expected: applications  apps.example.com/v1  true  Application
```

---

### Exercise 1.2

**Objective:** Create an instance of the `Application` custom resource from Exercise 1.1.

**Setup:**

The CRD from Exercise 1.1 must exist. Create a namespace for the custom resource:

```bash
kubectl create namespace ex-1-2
```

**Task:**

Create an `Application` custom resource named `webapp` in namespace `ex-1-2` with `spec.name` set to `webapp-production`. The object's apiVersion is `apps.example.com/v1` and kind is `Application`.

**Verification:**

```bash
kubectl get applications.apps.example.com webapp -n ex-1-2 \
  -o jsonpath='{.metadata.name}:{.spec.name}{"\n"}'
# Expected: webapp:webapp-production

kubectl get applications -n ex-1-2 \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
# Expected: webapp (on one line)
```

---

### Exercise 1.3

**Objective:** Update the `applications.apps.example.com` CRD to add additional printer columns so `kubectl get applications` shows the application's `spec.name` in its output.

**Setup:**

The CRD from Exercise 1.1 and the custom resource from Exercise 1.2 must both exist.

**Task:**

Modify the `applications.apps.example.com` CRD to add an `additionalPrinterColumns` entry on the `v1` version with a column named `Application-Name`, type `string`, and `jsonPath` `.spec.name`. After applying the change, `kubectl get applications -n ex-1-2` must show a new column containing the value of each resource's `spec.name`.

**Verification:**

```bash
kubectl get crd applications.apps.example.com \
  -o jsonpath='{.spec.versions[0].additionalPrinterColumns[0].name}:{.spec.versions[0].additionalPrinterColumns[0].jsonPath}{"\n"}'
# Expected: Application-Name:.spec.name

kubectl get applications -n ex-1-2 --no-headers
# Expected: a row showing webapp and webapp-production (the additional column).
```

---

## Level 2: Schema Definition

### Exercise 2.1

**Objective:** Add typed properties to a CRD schema.

**Setup:**

Delete the CRD from Exercise 1.1 if it exists:
```bash
kubectl delete crd applications.apps.example.com --ignore-not-found
```

**Task:**

Create a CRD for "Server" resources with a schema that includes:
- API group: `infrastructure.example.com`
- Version: v1
- Scope: Namespaced
- Schema with these typed properties:
  - spec.hostname (string)
  - spec.ip (string)
  - spec.port (integer)
  - spec.enabled (boolean)

**Verification:**

```bash
# Verify the CRD was created
kubectl get crd servers.infrastructure.example.com

# Check the schema includes the properties
kubectl get crd servers.infrastructure.example.com -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema.properties.spec.properties}' | grep -o '"[a-zA-Z]*"' | sort

# Expected: Shows "enabled", "hostname", "ip", "port"
```

---

### Exercise 2.2

**Objective:** Add required fields and validation to a CRD schema.

**Setup:**

Delete any existing CRDs from previous exercises if they conflict.

**Task:**

Create a CRD for "Database" resources with validation:
- API group: `data.example.com`
- Version: v1
- Scope: Namespaced
- Schema with:
  - spec.name (string, required)
  - spec.engine (string, required, enum: mysql, postgresql, mongodb)
  - spec.replicas (integer, minimum: 1, maximum: 5)
  - spec.storage (string)

**Verification:**

```bash
# Verify the CRD was created
kubectl get crd databases.data.example.com

# Verify required fields are set
kubectl get crd databases.data.example.com -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema.properties.spec.required}'

# Expected: ["name","engine"]

# Verify enum constraint exists
kubectl get crd databases.data.example.com -o yaml | grep -A 5 "engine:"

# Expected: Shows enum with mysql, postgresql, mongodb
```

---

### Exercise 2.3

**Objective:** Add nested objects to a CRD schema.

**Setup:**

Delete any existing CRDs from previous exercises if they conflict.

**Task:**

Create a CRD for "Cluster" resources with nested structure:
- API group: `compute.example.com`
- Version: v1
- Scope: Cluster (not namespaced)
- Schema with:
  - spec.name (string)
  - spec.nodes (object) containing:
    - count (integer)
    - size (string)
  - spec.networking (object) containing:
    - cidr (string)
    - dns (array of strings)

**Verification:**

```bash
# Verify the CRD was created
kubectl get crd clusters.compute.example.com

# Verify it is cluster-scoped
kubectl get crd clusters.compute.example.com -o jsonpath='{.spec.scope}'

# Expected: Cluster

# Verify nested properties exist
kubectl get crd clusters.compute.example.com -o yaml | grep -E "nodes:|networking:|count:|cidr:|dns:"

# Expected: Shows the nested structure
```

---

## Level 3: Debugging CRD Issues

### Exercise 3.1

**Objective:** A CRD creation is failing. Find and fix the issue.

**Setup:**

Try to apply this broken CRD:

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: myresources.test.example.com
spec:
  group: test.example.com
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
  scope: Namespaced
  names:
    plural: resources
    singular: myresource
    kind: MyResource
EOF
```

**Task:**

The CRD creation fails because the metadata.name does not match the expected format. The name must be `<plural>.<group>`. Fix the CRD so it creates successfully.

**Verification:**

```bash
# After fixing, verify the CRD was created
kubectl get crd

# Expected: Shows your fixed CRD name

# The name should match plural.group format
```

---

### Exercise 3.2

**Objective:** A CRD is missing required schema. Find and fix the issue.

**Setup:**

Try to apply this broken CRD:

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: configs.settings.example.com
spec:
  group: settings.example.com
  versions:
  - name: v1
    served: true
    storage: true
  scope: Namespaced
  names:
    plural: configs
    singular: config
    kind: Config
EOF
```

**Task:**

The CRD creation fails because the version is missing the required schema definition. In apiextensions.k8s.io/v1, all versions must have an openAPIV3Schema. Fix the CRD.

**Verification:**

```bash
# After fixing, verify the CRD was created
kubectl get crd configs.settings.example.com

# Expected: CRD exists
```

---

### Exercise 3.3

**Objective:** A CRD has versioning issues. Find and fix the problem.

**Setup:**

Try to apply this broken CRD:

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: jobs.batch.example.com
spec:
  group: batch.example.com
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
  - name: v2
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
  scope: Namespaced
  names:
    plural: jobs
    singular: job
    kind: Job
EOF
```

**Task:**

The CRD creation fails because multiple versions have `storage: true`. Only one version can be the storage version. Fix the CRD so v2 is the storage version.

**Verification:**

```bash
# After fixing, verify the CRD was created
kubectl get crd jobs.batch.example.com

# Check which version is storage
kubectl get crd jobs.batch.example.com -o jsonpath='{range .spec.versions[*]}{.name}: storage={.storage}{"\n"}{end}'

# Expected:
# v1: storage=false
# v2: storage=true
```

---

## Level 4: Advanced CRD Features

### Exercise 4.1

**Objective:** Configure a status subresource.

**Setup:**

Delete any conflicting CRDs.

**Task:**

Create a CRD for "Pipeline" resources with a status subresource:
- API group: `ci.example.com`
- Version: v1
- Scope: Namespaced
- Enable status subresource
- Schema with:
  - spec.stages (array of strings)
  - spec.timeout (integer)
  - status.phase (string)
  - status.startedAt (string)
  - status.completedAt (string)

**Verification:**

```bash
# Verify the CRD was created
kubectl get crd pipelines.ci.example.com

# Verify status subresource is enabled
kubectl get crd pipelines.ci.example.com -o jsonpath='{.spec.versions[0].subresources}'

# Expected: {"status":{}}
```

---

### Exercise 4.2

**Objective:** Add additional printer columns.

**Setup:**

Delete any conflicting CRDs.

**Task:**

Create a CRD for "VirtualMachine" resources with custom printer columns:
- API group: `virtualization.example.com`
- Version: v1
- Scope: Namespaced
- Add printer columns for:
  - Status (from .status.state)
  - CPU (from .spec.cpu)
  - Memory (from .spec.memory)
  - Age (from .metadata.creationTimestamp)
- Schema with spec.cpu (integer), spec.memory (string), status.state (string)

**Verification:**

```bash
# Verify the CRD was created
kubectl get crd virtualmachines.virtualization.example.com

# Check printer columns
kubectl get crd virtualmachines.virtualization.example.com -o jsonpath='{.spec.versions[0].additionalPrinterColumns[*].name}'

# Expected: Status CPU Memory Age
```

---

### Exercise 4.3

**Objective:** Configure multiple API versions.

**Setup:**

Delete any conflicting CRDs.

**Task:**

Create a CRD for "Policy" resources with two versions:
- API group: `security.example.com`
- Two versions: v1alpha1 and v1
- v1alpha1: served=true, storage=false, has spec.rules (array of strings)
- v1: served=true, storage=true, has spec.rules (array of objects with name and action)
- Scope: Namespaced

**Verification:**

```bash
# Verify the CRD was created
kubectl get crd policies.security.example.com

# Check both versions are available
kubectl api-versions | grep security.example.com

# Expected: security.example.com/v1 and security.example.com/v1alpha1

# Check version details
kubectl get crd policies.security.example.com -o jsonpath='{range .spec.versions[*]}{.name} served={.served} storage={.storage}{"\n"}{end}'

# Expected:
# v1alpha1 served=true storage=false
# v1 served=true storage=true
```

---

## Level 5: Complex Scenarios

### Exercise 5.1

**Objective:** Design a CRD for a specific use case.

**Setup:**

Delete any conflicting CRDs.

**Task:**

Design and create a CRD for "BackupJob" resources that would be used by a backup operator:
- API group: `backup.example.com`
- Version: v1
- Scope: Namespaced
- Schema requirements:
  - spec.source.namespace (string, required)
  - spec.source.resourceType (string, required, enum: deployment, statefulset, configmap)
  - spec.source.name (string, required)
  - spec.destination.bucket (string, required)
  - spec.destination.path (string)
  - spec.schedule (string, for cron expression)
  - spec.retention.maxBackups (integer, minimum 1, maximum 100)
  - status.lastBackupTime (string)
  - status.lastBackupStatus (string, enum: success, failed, running)
- Enable status subresource
- Add printer columns for LastBackup (status.lastBackupTime) and Status (status.lastBackupStatus)

**Verification:**

```bash
# Verify the CRD was created
kubectl get crd backupjobs.backup.example.com

# Verify status subresource
kubectl get crd backupjobs.backup.example.com -o jsonpath='{.spec.versions[0].subresources}'

# Expected: {"status":{}}

# Verify required fields
kubectl get crd backupjobs.backup.example.com -o yaml | grep -A 20 "source:"

# Expected: Shows required fields for source

# Verify printer columns
kubectl get crd backupjobs.backup.example.com -o jsonpath='{.spec.versions[0].additionalPrinterColumns[*].name}'

# Expected: Includes LastBackup and Status
```

---

### Exercise 5.2

**Objective:** Migrate a CRD to a new version.

**Setup:**

Create an initial CRD:

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: features.product.example.com
spec:
  group: product.example.com
  versions:
  - name: v1beta1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              name:
                type: string
              enabled:
                type: boolean
  scope: Namespaced
  names:
    plural: features
    singular: feature
    kind: Feature
EOF
```

**Task:**

Update the CRD to add a v1 version that becomes the storage version:
- v1beta1: served=true, storage=false (still available but deprecated)
- v1: served=true, storage=true
- v1 schema adds a new field: spec.priority (integer)
- Both versions should have the existing fields (name, enabled)

**Verification:**

```bash
# Verify both versions exist
kubectl api-versions | grep product.example.com

# Expected: product.example.com/v1 and product.example.com/v1beta1

# Check storage version changed to v1
kubectl get crd features.product.example.com -o jsonpath='{range .spec.versions[*]}{.name}: storage={.storage}{"\n"}{end}'

# Expected:
# v1beta1: storage=false
# v1: storage=true
```

---

### Exercise 5.3

**Objective:** Create a comprehensive CRD with all features.

**Setup:**

Delete any conflicting CRDs.

**Task:**

Create a comprehensive CRD for "Tenant" resources that demonstrates all CRD features:
- API group: `multitenancy.example.com`
- Scope: Cluster (not namespaced)
- Two versions: v1beta1 and v1 (v1 is storage)
- Enable status subresource
- Add short name: `tnt`
- Categories: `all`
- Comprehensive schema:
  - spec.name (string, required)
  - spec.admin (object with email and name, both strings)
  - spec.quotas (object with cpu, memory as strings, pods as integer)
  - spec.namespaces (array of strings)
  - status.phase (string)
  - status.namespaceCount (integer)
  - status.conditions (array of objects with type, status, lastTransitionTime)
- Printer columns: Phase, Admin, Namespaces (count), Age

**Verification:**

```bash
# Verify the CRD was created
kubectl get crd tenants.multitenancy.example.com

# Verify it is cluster-scoped
kubectl get crd tenants.multitenancy.example.com -o jsonpath='{.spec.scope}'

# Expected: Cluster

# Verify short name works
kubectl api-resources | grep tnt

# Expected: Shows tenants with short name tnt

# Verify categories
kubectl get crd tenants.multitenancy.example.com -o jsonpath='{.spec.names.categories}'

# Expected: ["all"]

# Verify status subresource
kubectl get crd tenants.multitenancy.example.com -o jsonpath='{.spec.versions[?(@.storage==true)].subresources}'

# Expected: {"status":{}}

# Verify printer columns
kubectl get crd tenants.multitenancy.example.com -o jsonpath='{.spec.versions[?(@.storage==true)].additionalPrinterColumns[*].name}'

# Expected: Phase Admin Namespaces Age
```

---

## Cleanup

Delete all CRDs created in these exercises:

```bash
kubectl delete crd applications.apps.example.com --ignore-not-found
kubectl delete crd servers.infrastructure.example.com --ignore-not-found
kubectl delete crd databases.data.example.com --ignore-not-found
kubectl delete crd clusters.compute.example.com --ignore-not-found
kubectl delete crd resources.test.example.com --ignore-not-found
kubectl delete crd configs.settings.example.com --ignore-not-found
kubectl delete crd jobs.batch.example.com --ignore-not-found
kubectl delete crd pipelines.ci.example.com --ignore-not-found
kubectl delete crd virtualmachines.virtualization.example.com --ignore-not-found
kubectl delete crd policies.security.example.com --ignore-not-found
kubectl delete crd backupjobs.backup.example.com --ignore-not-found
kubectl delete crd features.product.example.com --ignore-not-found
kubectl delete crd tenants.multitenancy.example.com --ignore-not-found
```

---

## Key Takeaways

1. CRD names must follow the format `<plural>.<group>`
2. All versions in apiextensions.k8s.io/v1 require an openAPIV3Schema
3. Only one version can have `storage: true`
4. Status subresources separate user-managed spec from controller-managed status
5. Printer columns customize kubectl get output
6. Short names and categories improve kubectl usability
7. Deleting a CRD deletes all custom resources of that type
8. Schema validation prevents invalid custom resources from being created
