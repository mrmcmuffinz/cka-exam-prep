# CRDs and Operators Tutorial: Custom Resource Definitions

## Introduction

Custom Resource Definitions (CRDs) extend the Kubernetes API by letting you define new resource types. Once you create a CRD, users can create instances of that custom resource using kubectl, just like built-in resources such as Pods and Deployments. CRDs are the foundation of the Kubernetes operator pattern, where custom controllers watch custom resources and take action based on their specifications.

Understanding CRDs is important for the CKA exam and for working with Kubernetes operators in production. This tutorial walks through CRD structure, schema definition, versioning, and advanced features like status subresources and printer columns.

## Prerequisites

You need a running kind cluster. Create one if you do not have one already:

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

Verify the cluster is running:

```bash
kubectl cluster-info
```

## Setup

Create a namespace for tutorial resources (though CRDs themselves are cluster-scoped):

```bash
kubectl create namespace tutorial-crds
```

## Understanding CRDs

A Custom Resource Definition tells Kubernetes about a new resource type you want to create. The CRD specifies:

- The API group and version for the resource
- The names used to refer to the resource (plural, singular, kind)
- Whether resources are namespaced or cluster-scoped
- The schema that validates resource instances
- Optional features like status subresources and printer columns

Once a CRD is created, users can immediately create instances of that resource type.

## Basic CRD Structure

Let us create a simple CRD for a "Website" resource. This represents a website that might be managed by a hypothetical operator:

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: websites.stable.example.com
spec:
  group: stable.example.com
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
              siteName:
                type: string
              replicas:
                type: integer
  scope: Namespaced
  names:
    plural: websites
    singular: website
    kind: Website
    shortNames:
    - ws
```

Let us examine each section:

**apiVersion and kind:** All CRDs use `apiextensions.k8s.io/v1` and kind `CustomResourceDefinition`.

**metadata.name:** Must follow the format `<plural>.<group>`. In this case, `websites.stable.example.com`.

**spec.group:** The API group for your custom resources. Choose a domain you control to avoid conflicts.

**spec.versions:** A list of API versions for this resource. Each version can have its own schema.

**spec.scope:** Either `Namespaced` (resources exist in namespaces) or `Cluster` (resources are cluster-wide).

**spec.names:** How to refer to the resource:
- `plural`: Used in URLs and kubectl (e.g., `websites`)
- `singular`: Used for display (e.g., `website`)
- `kind`: The resource kind in manifests (e.g., `Website`)
- `shortNames`: Optional abbreviations for kubectl (e.g., `ws`)

## Creating a CRD

Apply the CRD to your cluster:

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: websites.stable.example.com
spec:
  group: stable.example.com
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
              siteName:
                type: string
              replicas:
                type: integer
  scope: Namespaced
  names:
    plural: websites
    singular: website
    kind: Website
    shortNames:
    - ws
EOF
```

Verify the CRD was created:

```bash
kubectl get crd websites.stable.example.com
```

The CRD is now registered. Check that the new API resource is available:

```bash
kubectl api-resources | grep website
```

You should see:

```
websites     ws           stable.example.com/v1     true         Website
```

## CRD Schema Definition

The schema defines what fields your custom resources can have and validates them. Kubernetes uses OpenAPI v3 schema format.

### Basic Types

The schema supports these types:
- `string`: Text values
- `integer`: Whole numbers
- `number`: Decimal numbers
- `boolean`: True/false
- `array`: Lists of items
- `object`: Nested structures

### Required Fields

You can mark fields as required:

```yaml
schema:
  openAPIV3Schema:
    type: object
    required:
    - spec
    properties:
      spec:
        type: object
        required:
        - siteName
        properties:
          siteName:
            type: string
          replicas:
            type: integer
```

### Field Validation

Add validation rules to fields:

```yaml
properties:
  replicas:
    type: integer
    minimum: 1
    maximum: 10
  environment:
    type: string
    enum:
    - development
    - staging
    - production
  url:
    type: string
    pattern: "^https?://"
```

### Nested Objects

Define complex nested structures:

```yaml
properties:
  spec:
    type: object
    properties:
      config:
        type: object
        properties:
          database:
            type: object
            properties:
              host:
                type: string
              port:
                type: integer
```

### Arrays

Define list fields:

```yaml
properties:
  spec:
    type: object
    properties:
      domains:
        type: array
        items:
          type: string
```

## Creating a More Complete CRD

Let us create a more realistic CRD with proper validation:

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: backupschedules.data.example.com
spec:
  group: data.example.com
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        required:
        - spec
        properties:
          spec:
            type: object
            required:
            - schedule
            - target
            properties:
              schedule:
                type: string
                description: Cron expression for backup schedule
              target:
                type: object
                required:
                - name
                - namespace
                properties:
                  name:
                    type: string
                    description: Name of the resource to back up
                  namespace:
                    type: string
                    description: Namespace of the resource
                  kind:
                    type: string
                    enum:
                    - Deployment
                    - StatefulSet
                    - ConfigMap
                    default: Deployment
              retention:
                type: object
                properties:
                  count:
                    type: integer
                    minimum: 1
                    maximum: 100
                    default: 7
                  days:
                    type: integer
                    minimum: 1
              enabled:
                type: boolean
                default: true
  scope: Namespaced
  names:
    plural: backupschedules
    singular: backupschedule
    kind: BackupSchedule
    shortNames:
    - bs
EOF
```

This CRD demonstrates:
- Required fields at multiple levels
- Enum constraints for limited choices
- Default values
- Descriptions for documentation
- Minimum/maximum constraints for numbers

Verify the CRD:

```bash
kubectl describe crd backupschedules.data.example.com
```

## CRD Versioning

CRDs support multiple versions for API evolution. Each version can have different schemas, but data is stored in only one version (the storage version).

```yaml
spec:
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        # v1 schema
  - name: v2
    served: true
    storage: false
    schema:
      openAPIV3Schema:
        # v2 schema with new fields
```

Key points:
- `served: true` means the version is available via the API
- `storage: true` marks which version is used for storage (only one can be true)
- When upgrading, you typically add a new version, make it served, then eventually make it the storage version

## Status Subresource

The status subresource separates user-managed spec from controller-managed status. Without it, users could accidentally overwrite status when updating spec.

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: deployments.apps.example.com
spec:
  group: apps.example.com
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
              replicas:
                type: integer
          status:
            type: object
            properties:
              readyReplicas:
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
  scope: Namespaced
  names:
    plural: deployments
    singular: deployment
    kind: Deployment
EOF
```

With status subresource enabled:
- Updates to `/status` only affect the status field
- Updates to the main resource only affect spec
- Controllers can update status without affecting spec

## Additional Printer Columns

Customize what kubectl shows when listing resources:

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: certificates.security.example.com
spec:
  group: security.example.com
  versions:
  - name: v1
    served: true
    storage: true
    additionalPrinterColumns:
    - name: Domain
      type: string
      jsonPath: .spec.domain
    - name: Issuer
      type: string
      jsonPath: .spec.issuer
    - name: Expires
      type: string
      jsonPath: .status.expiresAt
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
              domain:
                type: string
              issuer:
                type: string
          status:
            type: object
            properties:
              expiresAt:
                type: string
  scope: Namespaced
  names:
    plural: certificates
    singular: certificate
    kind: Certificate
    shortNames:
    - cert
EOF
```

Now kubectl get will show custom columns:

```bash
kubectl get certificates
```

Output format:
```
NAME      DOMAIN           ISSUER        EXPIRES              AGE
example   example.com      letsencrypt   2024-12-31T23:59:59  5m
```

## Inspecting CRDs

List all CRDs:

```bash
kubectl get crd
```

Get details about a specific CRD:

```bash
kubectl describe crd websites.stable.example.com
```

View the full CRD YAML:

```bash
kubectl get crd websites.stable.example.com -o yaml
```

Check which API versions a CRD supports:

```bash
kubectl get crd websites.stable.example.com -o jsonpath='{.spec.versions[*].name}'
```

## Deleting CRDs

**Warning:** Deleting a CRD also deletes all custom resources of that type.

```bash
kubectl delete crd websites.stable.example.com
```

This is an important consideration for production. Always ensure you have backups or have migrated resources before deleting a CRD.

## Cleanup

Delete the CRDs created in this tutorial:

```bash
kubectl delete crd websites.stable.example.com
kubectl delete crd backupschedules.data.example.com
kubectl delete crd deployments.apps.example.com
kubectl delete crd certificates.security.example.com
```

Delete the tutorial namespace:

```bash
kubectl delete namespace tutorial-crds
```

## Reference Commands

| Task | Command |
|------|---------|
| List all CRDs | `kubectl get crd` |
| Describe a CRD | `kubectl describe crd <name>` |
| Get CRD YAML | `kubectl get crd <name> -o yaml` |
| Check API resources | `kubectl api-resources | grep <name>` |
| Check API versions | `kubectl api-versions | grep <group>` |
| Delete a CRD | `kubectl delete crd <name>` |

## Key Takeaways

1. **CRDs extend the Kubernetes API** with custom resource types
2. **CRD names** must follow the format `<plural>.<group>`
3. **OpenAPI v3 schemas** validate custom resource fields
4. **Versioning** allows API evolution with served and storage flags
5. **Status subresources** separate user-managed spec from controller-managed status
6. **Printer columns** customize kubectl output for custom resources
7. **Deleting a CRD deletes all resources of that type**, so use caution
8. CRDs are immediately available after creation, no cluster restart needed
