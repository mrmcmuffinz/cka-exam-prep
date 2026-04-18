# CRDs and Operators Homework Answers: Custom Resource Definitions

This file contains complete solutions for all 15 exercises on Custom Resource Definitions.

---

## Exercise 1.1 Solution

**Task:** Create a simple Application CRD.

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: applications.apps.example.com
spec:
  group: apps.example.com
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
            properties:
              name:
                type: string
  scope: Namespaced
  names:
    plural: applications
    singular: application
    kind: Application
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: applications.apps.example.com
spec:
  group: apps.example.com
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
            properties:
              name:
                type: string
  scope: Namespaced
  names:
    plural: applications
    singular: application
    kind: Application
EOF
```

**Explanation:** This creates a minimal CRD with the required fields. The metadata.name follows the `<plural>.<group>` format.

---

## Exercise 1.2 Solution

**Task:** List and describe CRDs.

```bash
# List all CRDs
kubectl get crd

# Describe the applications CRD
kubectl describe crd applications.apps.example.com

# Extract group and scope
kubectl get crd applications.apps.example.com -o jsonpath='{.spec.group} {.spec.scope}'
```

**Explanation:** kubectl get lists resources, describe shows details, and jsonpath extracts specific fields.

---

## Exercise 1.3 Solution

**Task:** Verify the API resource is available.

```bash
# Check api-resources for the apps.example.com group
kubectl api-resources --api-group=apps.example.com

# Check API versions
kubectl api-versions | grep apps.example.com

# Use kubectl explain
kubectl explain applications --api-version=apps.example.com/v1
```

**Explanation:** These commands verify that the CRD has registered its API endpoints and the new resource type is usable.

---

## Exercise 2.1 Solution

**Task:** Create CRD with typed properties.

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: servers.infrastructure.example.com
spec:
  group: infrastructure.example.com
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
            properties:
              hostname:
                type: string
              ip:
                type: string
              port:
                type: integer
              enabled:
                type: boolean
  scope: Namespaced
  names:
    plural: servers
    singular: server
    kind: Server
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: servers.infrastructure.example.com
spec:
  group: infrastructure.example.com
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
            properties:
              hostname:
                type: string
              ip:
                type: string
              port:
                type: integer
              enabled:
                type: boolean
  scope: Namespaced
  names:
    plural: servers
    singular: server
    kind: Server
EOF
```

**Explanation:** Each property has a type that enforces validation. String, integer, and boolean are the most common types.

---

## Exercise 2.2 Solution

**Task:** Create CRD with validation.

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databases.data.example.com
spec:
  group: data.example.com
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
            required:
            - name
            - engine
            properties:
              name:
                type: string
              engine:
                type: string
                enum:
                - mysql
                - postgresql
                - mongodb
              replicas:
                type: integer
                minimum: 1
                maximum: 5
              storage:
                type: string
  scope: Namespaced
  names:
    plural: databases
    singular: database
    kind: Database
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databases.data.example.com
spec:
  group: data.example.com
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
            required:
            - name
            - engine
            properties:
              name:
                type: string
              engine:
                type: string
                enum:
                - mysql
                - postgresql
                - mongodb
              replicas:
                type: integer
                minimum: 1
                maximum: 5
              storage:
                type: string
  scope: Namespaced
  names:
    plural: databases
    singular: database
    kind: Database
EOF
```

**Explanation:** The required array lists mandatory fields. Enum restricts values to a fixed list. Minimum/maximum constrain numeric values.

---

## Exercise 2.3 Solution

**Task:** Create CRD with nested objects.

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: clusters.compute.example.com
spec:
  group: compute.example.com
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
            properties:
              name:
                type: string
              nodes:
                type: object
                properties:
                  count:
                    type: integer
                  size:
                    type: string
              networking:
                type: object
                properties:
                  cidr:
                    type: string
                  dns:
                    type: array
                    items:
                      type: string
  scope: Cluster
  names:
    plural: clusters
    singular: cluster
    kind: Cluster
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: clusters.compute.example.com
spec:
  group: compute.example.com
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
            properties:
              name:
                type: string
              nodes:
                type: object
                properties:
                  count:
                    type: integer
                  size:
                    type: string
              networking:
                type: object
                properties:
                  cidr:
                    type: string
                  dns:
                    type: array
                    items:
                      type: string
  scope: Cluster
  names:
    plural: clusters
    singular: cluster
    kind: Cluster
EOF
```

**Explanation:** Nested objects use `type: object` with their own `properties`. Arrays use `type: array` with `items` defining the element type.

---

## Exercise 3.1 Solution

**Problem:** The metadata.name is `myresources.test.example.com` but the plural is `resources`. The name must match `<plural>.<group>`.

**Fix:**

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: resources.test.example.com
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

**Explanation:** Changed metadata.name from `myresources.test.example.com` to `resources.test.example.com` to match the plural name.

---

## Exercise 3.2 Solution

**Problem:** The version is missing the required schema definition.

**Fix:**

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
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
  scope: Namespaced
  names:
    plural: configs
    singular: config
    kind: Config
EOF
```

**Explanation:** Added the schema.openAPIV3Schema section. In apiextensions.k8s.io/v1, all versions must have a schema.

---

## Exercise 3.3 Solution

**Problem:** Both versions have `storage: true`. Only one version can be the storage version.

**Fix:**

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
    storage: false
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

**Explanation:** Changed v1's storage to false and kept v2 as storage: true. Only one version can be the storage version.

---

## Exercise 4.1 Solution

**Task:** Create CRD with status subresource.

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: pipelines.ci.example.com
spec:
  group: ci.example.com
  versions:
  - name: v1
    served: true
    storage: true
    subresources:
      status: {}
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              stages:
                type: array
                items:
                  type: string
              timeout:
                type: integer
          status:
            type: object
            properties:
              phase:
                type: string
              startedAt:
                type: string
              completedAt:
                type: string
  scope: Namespaced
  names:
    plural: pipelines
    singular: pipeline
    kind: Pipeline
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: pipelines.ci.example.com
spec:
  group: ci.example.com
  versions:
  - name: v1
    served: true
    storage: true
    subresources:
      status: {}
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              stages:
                type: array
                items:
                  type: string
              timeout:
                type: integer
          status:
            type: object
            properties:
              phase:
                type: string
              startedAt:
                type: string
              completedAt:
                type: string
  scope: Namespaced
  names:
    plural: pipelines
    singular: pipeline
    kind: Pipeline
EOF
```

**Explanation:** The `subresources.status: {}` enables the status subresource. The schema defines both spec and status fields.

---

## Exercise 4.2 Solution

**Task:** Create CRD with printer columns.

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: virtualmachines.virtualization.example.com
spec:
  group: virtualization.example.com
  versions:
  - name: v1
    served: true
    storage: true
    additionalPrinterColumns:
    - name: Status
      type: string
      jsonPath: .status.state
    - name: CPU
      type: integer
      jsonPath: .spec.cpu
    - name: Memory
      type: string
      jsonPath: .spec.memory
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              cpu:
                type: integer
              memory:
                type: string
          status:
            type: object
            properties:
              state:
                type: string
  scope: Namespaced
  names:
    plural: virtualmachines
    singular: virtualmachine
    kind: VirtualMachine
    shortNames:
    - vm
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: virtualmachines.virtualization.example.com
spec:
  group: virtualization.example.com
  versions:
  - name: v1
    served: true
    storage: true
    additionalPrinterColumns:
    - name: Status
      type: string
      jsonPath: .status.state
    - name: CPU
      type: integer
      jsonPath: .spec.cpu
    - name: Memory
      type: string
      jsonPath: .spec.memory
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              cpu:
                type: integer
              memory:
                type: string
          status:
            type: object
            properties:
              state:
                type: string
  scope: Namespaced
  names:
    plural: virtualmachines
    singular: virtualmachine
    kind: VirtualMachine
    shortNames:
    - vm
EOF
```

**Explanation:** additionalPrinterColumns defines custom columns for kubectl get output. Each column specifies name, type, and jsonPath to extract the value.

---

## Exercise 4.3 Solution

**Task:** Create CRD with multiple versions.

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: policies.security.example.com
spec:
  group: security.example.com
  versions:
  - name: v1alpha1
    served: true
    storage: false
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              rules:
                type: array
                items:
                  type: string
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              rules:
                type: array
                items:
                  type: object
                  properties:
                    name:
                      type: string
                    action:
                      type: string
  scope: Namespaced
  names:
    plural: policies
    singular: policy
    kind: Policy
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: policies.security.example.com
spec:
  group: security.example.com
  versions:
  - name: v1alpha1
    served: true
    storage: false
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              rules:
                type: array
                items:
                  type: string
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              rules:
                type: array
                items:
                  type: object
                  properties:
                    name:
                      type: string
                    action:
                      type: string
  scope: Namespaced
  names:
    plural: policies
    singular: policy
    kind: Policy
EOF
```

**Explanation:** Each version has its own schema. v1alpha1 has simple string rules, while v1 has structured rule objects. Only v1 is the storage version.

---

## Exercise 5.1 Solution

**Task:** Design a BackupJob CRD.

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: backupjobs.backup.example.com
spec:
  group: backup.example.com
  versions:
  - name: v1
    served: true
    storage: true
    subresources:
      status: {}
    additionalPrinterColumns:
    - name: LastBackup
      type: string
      jsonPath: .status.lastBackupTime
    - name: Status
      type: string
      jsonPath: .status.lastBackupStatus
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required:
            - source
            - destination
            properties:
              source:
                type: object
                required:
                - namespace
                - resourceType
                - name
                properties:
                  namespace:
                    type: string
                  resourceType:
                    type: string
                    enum:
                    - deployment
                    - statefulset
                    - configmap
                  name:
                    type: string
              destination:
                type: object
                required:
                - bucket
                properties:
                  bucket:
                    type: string
                  path:
                    type: string
              schedule:
                type: string
              retention:
                type: object
                properties:
                  maxBackups:
                    type: integer
                    minimum: 1
                    maximum: 100
          status:
            type: object
            properties:
              lastBackupTime:
                type: string
              lastBackupStatus:
                type: string
                enum:
                - success
                - failed
                - running
  scope: Namespaced
  names:
    plural: backupjobs
    singular: backupjob
    kind: BackupJob
    shortNames:
    - bj
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: backupjobs.backup.example.com
spec:
  group: backup.example.com
  versions:
  - name: v1
    served: true
    storage: true
    subresources:
      status: {}
    additionalPrinterColumns:
    - name: LastBackup
      type: string
      jsonPath: .status.lastBackupTime
    - name: Status
      type: string
      jsonPath: .status.lastBackupStatus
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required:
            - source
            - destination
            properties:
              source:
                type: object
                required:
                - namespace
                - resourceType
                - name
                properties:
                  namespace:
                    type: string
                  resourceType:
                    type: string
                    enum:
                    - deployment
                    - statefulset
                    - configmap
                  name:
                    type: string
              destination:
                type: object
                required:
                - bucket
                properties:
                  bucket:
                    type: string
                  path:
                    type: string
              schedule:
                type: string
              retention:
                type: object
                properties:
                  maxBackups:
                    type: integer
                    minimum: 1
                    maximum: 100
          status:
            type: object
            properties:
              lastBackupTime:
                type: string
              lastBackupStatus:
                type: string
                enum:
                - success
                - failed
                - running
  scope: Namespaced
  names:
    plural: backupjobs
    singular: backupjob
    kind: BackupJob
    shortNames:
    - bj
EOF
```

**Explanation:** This CRD demonstrates a real-world design with nested required objects, enums for controlled values, status subresource for operator updates, and printer columns for quick visibility.

---

## Exercise 5.2 Solution

**Task:** Migrate CRD to new version.

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
    storage: false
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
  - name: v1
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
              priority:
                type: integer
  scope: Namespaced
  names:
    plural: features
    singular: feature
    kind: Feature
EOF
```

**Explanation:** Added v1 with the new priority field and made it the storage version. v1beta1 remains served but is no longer the storage version.

---

## Exercise 5.3 Solution

**Task:** Create comprehensive Tenant CRD.

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: tenants.multitenancy.example.com
spec:
  group: multitenancy.example.com
  scope: Cluster
  versions:
  - name: v1beta1
    served: true
    storage: false
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required:
            - name
            properties:
              name:
                type: string
              admin:
                type: object
                properties:
                  email:
                    type: string
                  name:
                    type: string
              quotas:
                type: object
                properties:
                  cpu:
                    type: string
                  memory:
                    type: string
                  pods:
                    type: integer
              namespaces:
                type: array
                items:
                  type: string
          status:
            type: object
            properties:
              phase:
                type: string
              namespaceCount:
                type: integer
              conditions:
                type: array
                items:
                  type: object
                  properties:
                    type:
                      type: string
                    status:
                      type: string
                    lastTransitionTime:
                      type: string
  - name: v1
    served: true
    storage: true
    subresources:
      status: {}
    additionalPrinterColumns:
    - name: Phase
      type: string
      jsonPath: .status.phase
    - name: Admin
      type: string
      jsonPath: .spec.admin.email
    - name: Namespaces
      type: integer
      jsonPath: .status.namespaceCount
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required:
            - name
            properties:
              name:
                type: string
              admin:
                type: object
                properties:
                  email:
                    type: string
                  name:
                    type: string
              quotas:
                type: object
                properties:
                  cpu:
                    type: string
                  memory:
                    type: string
                  pods:
                    type: integer
              namespaces:
                type: array
                items:
                  type: string
          status:
            type: object
            properties:
              phase:
                type: string
              namespaceCount:
                type: integer
              conditions:
                type: array
                items:
                  type: object
                  properties:
                    type:
                      type: string
                    status:
                      type: string
                    lastTransitionTime:
                      type: string
  names:
    plural: tenants
    singular: tenant
    kind: Tenant
    shortNames:
    - tnt
    categories:
    - all
```

Apply with:

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: tenants.multitenancy.example.com
spec:
  group: multitenancy.example.com
  scope: Cluster
  versions:
  - name: v1beta1
    served: true
    storage: false
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required:
            - name
            properties:
              name:
                type: string
              admin:
                type: object
                properties:
                  email:
                    type: string
                  name:
                    type: string
              quotas:
                type: object
                properties:
                  cpu:
                    type: string
                  memory:
                    type: string
                  pods:
                    type: integer
              namespaces:
                type: array
                items:
                  type: string
          status:
            type: object
            properties:
              phase:
                type: string
              namespaceCount:
                type: integer
              conditions:
                type: array
                items:
                  type: object
                  properties:
                    type:
                      type: string
                    status:
                      type: string
                    lastTransitionTime:
                      type: string
  - name: v1
    served: true
    storage: true
    subresources:
      status: {}
    additionalPrinterColumns:
    - name: Phase
      type: string
      jsonPath: .status.phase
    - name: Admin
      type: string
      jsonPath: .spec.admin.email
    - name: Namespaces
      type: integer
      jsonPath: .status.namespaceCount
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required:
            - name
            properties:
              name:
                type: string
              admin:
                type: object
                properties:
                  email:
                    type: string
                  name:
                    type: string
              quotas:
                type: object
                properties:
                  cpu:
                    type: string
                  memory:
                    type: string
                  pods:
                    type: integer
              namespaces:
                type: array
                items:
                  type: string
          status:
            type: object
            properties:
              phase:
                type: string
              namespaceCount:
                type: integer
              conditions:
                type: array
                items:
                  type: object
                  properties:
                    type:
                      type: string
                    status:
                      type: string
                    lastTransitionTime:
                      type: string
  names:
    plural: tenants
    singular: tenant
    kind: Tenant
    shortNames:
    - tnt
    categories:
    - all
EOF
```

**Explanation:** This comprehensive CRD demonstrates all features: cluster scope, multiple versions, status subresource, printer columns, short names, and categories.

---

## Common Mistakes

### Wrong CRD name format (must be plural.group)

The metadata.name must exactly match `<plural>.<group>`. If the plural is "widgets" and the group is "example.com", the name must be "widgets.example.com".

### Missing openAPIV3Schema (required in v1)

In apiextensions.k8s.io/v1, every version must have a schema.openAPIV3Schema. This was optional in v1beta1 but is required in v1.

### Storage version not set

Exactly one version must have `storage: true`. If you have multiple versions, only one can be the storage version where resources are persisted.

### Deleting CRD deletes all custom resources

When you delete a CRD, all custom resources of that type are also deleted. Always back up resources before deleting a CRD, or migrate them first.

### Scope mismatch between CRD and resources

If a CRD has `scope: Namespaced`, all resources must include a namespace. If `scope: Cluster`, resources cannot have a namespace.

---

## CRD Reference Cheat Sheet

| Field | Purpose |
|-------|---------|
| metadata.name | Must be `<plural>.<group>` |
| spec.group | API group for the resource |
| spec.versions[].name | Version name (v1, v1beta1, etc.) |
| spec.versions[].served | Whether version is available via API |
| spec.versions[].storage | Whether version is used for storage |
| spec.versions[].schema | OpenAPI v3 validation schema |
| spec.versions[].subresources.status | Enable status subresource |
| spec.versions[].additionalPrinterColumns | Custom kubectl columns |
| spec.scope | Namespaced or Cluster |
| spec.names.plural | Plural name for API URLs |
| spec.names.singular | Singular name for display |
| spec.names.kind | Kind in manifests |
| spec.names.shortNames | Short aliases for kubectl |
| spec.names.categories | Groups like "all" |

### Schema Types

| Type | Description |
|------|-------------|
| string | Text values |
| integer | Whole numbers |
| number | Decimal numbers |
| boolean | True/false |
| array | Lists with items |
| object | Nested structures with properties |

### Schema Validation

| Validation | Applies to |
|------------|-----------|
| required | Arrays of required field names |
| enum | Allowed string values |
| minimum/maximum | Number range |
| minLength/maxLength | String length |
| pattern | Regex for strings |
| default | Default value |
