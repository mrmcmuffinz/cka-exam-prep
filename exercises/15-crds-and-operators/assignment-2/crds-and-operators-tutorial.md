# CRDs and Operators Tutorial: Custom Resources and RBAC

## Introduction

Once you have created a Custom Resource Definition (CRD), you can create instances of that custom resource type. Custom resources behave like built-in Kubernetes resources: you can create, list, describe, update, and delete them using kubectl. This tutorial covers the full lifecycle of custom resources and how to configure RBAC to control access to them.

Understanding custom resource operations and RBAC is essential for working with Kubernetes operators in production, where custom resources define the desired state and operators reconcile that state.

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

Create a namespace for the tutorial:

```bash
kubectl create namespace tutorial-crds
```

Create a CRD for the tutorial exercises. This CRD defines a "Website" resource:

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
    subresources:
      status: {}
    additionalPrinterColumns:
    - name: URL
      type: string
      jsonPath: .spec.url
    - name: Replicas
      type: integer
      jsonPath: .spec.replicas
    - name: Status
      type: string
      jsonPath: .status.phase
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
    schema:
      openAPIV3Schema:
        type: object
        required:
        - spec
        properties:
          spec:
            type: object
            required:
            - url
            properties:
              url:
                type: string
              replicas:
                type: integer
                minimum: 1
                maximum: 10
                default: 1
              environment:
                type: string
                enum:
                - development
                - staging
                - production
          status:
            type: object
            properties:
              phase:
                type: string
              availableReplicas:
                type: integer
  scope: Namespaced
  names:
    plural: websites
    singular: website
    kind: Website
    shortNames:
    - ws
    categories:
    - all
EOF
```

Verify the CRD was created:

```bash
kubectl get crd websites.stable.example.com
```

## Creating Custom Resources

Now that the CRD exists, you can create Website resources. Create a simple website:

```bash
kubectl apply -f - <<EOF
apiVersion: stable.example.com/v1
kind: Website
metadata:
  name: my-blog
  namespace: tutorial-crds
spec:
  url: https://blog.example.com
  replicas: 2
  environment: production
EOF
```

The custom resource uses the same YAML structure as built-in resources:
- `apiVersion` matches the CRD's group/version
- `kind` matches the CRD's kind
- `metadata` includes name and namespace
- `spec` contains fields defined in the CRD schema

## Listing Custom Resources

List all websites in a namespace:

```bash
kubectl get websites -n tutorial-crds
```

The output includes the custom printer columns we defined:

```
NAME      URL                        REPLICAS   STATUS   AGE
my-blog   https://blog.example.com   2                   5s
```

Use the short name:

```bash
kubectl get ws -n tutorial-crds
```

List across all namespaces:

```bash
kubectl get websites --all-namespaces
```

Since we added the "all" category, websites appear in `kubectl get all`:

```bash
kubectl get all -n tutorial-crds
```

## Describing Custom Resources

Get detailed information about a custom resource:

```bash
kubectl describe website my-blog -n tutorial-crds
```

This shows:
- Metadata (name, namespace, creation time, labels, annotations)
- Spec fields and their values
- Status fields (if any)
- Events (if any)

## Viewing Custom Resources as YAML/JSON

View the full resource definition:

```bash
kubectl get website my-blog -n tutorial-crds -o yaml
```

View as JSON:

```bash
kubectl get website my-blog -n tutorial-crds -o json
```

Use jsonpath to extract specific fields:

```bash
kubectl get website my-blog -n tutorial-crds -o jsonpath='{.spec.url}'
```

## Updating Custom Resources

Update a custom resource using kubectl apply:

```bash
kubectl apply -f - <<EOF
apiVersion: stable.example.com/v1
kind: Website
metadata:
  name: my-blog
  namespace: tutorial-crds
spec:
  url: https://blog.example.com
  replicas: 3
  environment: production
EOF
```

Or use kubectl patch:

```bash
kubectl patch website my-blog -n tutorial-crds --type=merge -p '{"spec":{"replicas":4}}'
```

Edit interactively:

```bash
kubectl edit website my-blog -n tutorial-crds
```

## Deleting Custom Resources

Delete a specific resource:

```bash
kubectl delete website my-blog -n tutorial-crds
```

Delete using a manifest file:

```bash
kubectl delete -f website.yaml
```

Delete all websites in a namespace:

```bash
kubectl delete websites --all -n tutorial-crds
```

## Custom Resource Validation

The CRD schema validates custom resources. Try creating an invalid resource:

```bash
kubectl apply -f - <<EOF
apiVersion: stable.example.com/v1
kind: Website
metadata:
  name: invalid-site
  namespace: tutorial-crds
spec:
  url: https://invalid.com
  replicas: 100
EOF
```

This fails because replicas exceeds the maximum of 10 defined in the schema.

Try with an invalid enum value:

```bash
kubectl apply -f - <<EOF
apiVersion: stable.example.com/v1
kind: Website
metadata:
  name: invalid-site
  namespace: tutorial-crds
spec:
  url: https://invalid.com
  environment: testing
EOF
```

This fails because "testing" is not in the allowed enum values.

## Namespaced vs Cluster-Scoped Resources

The Website CRD is namespaced (scope: Namespaced), so resources exist within namespaces. Let us also create a cluster-scoped CRD:

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: tenants.multitenancy.example.com
spec:
  group: multitenancy.example.com
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
              admins:
                type: array
                items:
                  type: string
  scope: Cluster
  names:
    plural: tenants
    singular: tenant
    kind: Tenant
EOF
```

Create a cluster-scoped resource (no namespace):

```bash
kubectl apply -f - <<EOF
apiVersion: multitenancy.example.com/v1
kind: Tenant
metadata:
  name: acme-corp
spec:
  name: ACME Corporation
  admins:
  - admin@acme.com
EOF
```

List cluster-scoped resources (no namespace flag needed):

```bash
kubectl get tenants
```

## Custom Resource Discovery

Find custom resources using api-resources:

```bash
kubectl api-resources | grep example.com
```

Check API versions:

```bash
kubectl api-versions | grep example.com
```

Use kubectl explain for documentation:

```bash
kubectl explain websites --api-version=stable.example.com/v1
kubectl explain websites.spec --api-version=stable.example.com/v1
```

## RBAC for Custom Resources

By default, only cluster administrators can access custom resources. To allow other users or service accounts to access them, you need to create RBAC rules.

### Creating a Role for Custom Resources

Create a Role that allows reading websites:

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: website-reader
  namespace: tutorial-crds
rules:
- apiGroups: ["stable.example.com"]
  resources: ["websites"]
  verbs: ["get", "list", "watch"]
EOF
```

Key points:
- `apiGroups` must match the CRD's group (stable.example.com)
- `resources` must use the plural name (websites)
- `verbs` specify allowed operations

### Creating a Role with Full Access

Create a Role with all permissions:

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: website-admin
  namespace: tutorial-crds
rules:
- apiGroups: ["stable.example.com"]
  resources: ["websites"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["stable.example.com"]
  resources: ["websites/status"]
  verbs: ["get", "update", "patch"]
EOF
```

Note the separate rule for `websites/status` to allow updating the status subresource.

### Binding Roles to Service Accounts

Create a service account:

```bash
kubectl create serviceaccount website-operator -n tutorial-crds
```

Bind the Role to the service account:

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: website-operator-binding
  namespace: tutorial-crds
subjects:
- kind: ServiceAccount
  name: website-operator
  namespace: tutorial-crds
roleRef:
  kind: Role
  name: website-admin
  apiGroup: rbac.authorization.k8s.io
EOF
```

### Testing Permissions

Use kubectl auth can-i to test permissions:

```bash
# Test as the service account
kubectl auth can-i get websites -n tutorial-crds --as=system:serviceaccount:tutorial-crds:website-operator

# Expected: yes

kubectl auth can-i delete websites -n tutorial-crds --as=system:serviceaccount:tutorial-crds:website-operator

# Expected: yes

# Test an unpermitted operation (create in a different namespace)
kubectl auth can-i create websites -n default --as=system:serviceaccount:tutorial-crds:website-operator

# Expected: no
```

### ClusterRole for Cluster-Scoped Resources

For cluster-scoped resources like Tenants, use ClusterRole:

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: tenant-reader
rules:
- apiGroups: ["multitenancy.example.com"]
  resources: ["tenants"]
  verbs: ["get", "list", "watch"]
EOF
```

Bind with ClusterRoleBinding:

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tenant-reader-binding
subjects:
- kind: ServiceAccount
  name: tenant-viewer
  namespace: tutorial-crds
roleRef:
  kind: ClusterRole
  name: tenant-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

## Short Names and Categories

The Website CRD defined a short name "ws". Use it:

```bash
kubectl get ws -n tutorial-crds
```

The CRD also added the "all" category, so websites appear in:

```bash
kubectl get all -n tutorial-crds
```

## Cleanup

Delete the custom resources:

```bash
kubectl delete website --all -n tutorial-crds
kubectl delete tenant --all
```

Delete the RBAC resources:

```bash
kubectl delete rolebinding website-operator-binding -n tutorial-crds
kubectl delete role website-reader website-admin -n tutorial-crds
kubectl delete serviceaccount website-operator -n tutorial-crds
kubectl delete clusterrolebinding tenant-reader-binding
kubectl delete clusterrole tenant-reader
```

Delete the CRDs:

```bash
kubectl delete crd websites.stable.example.com
kubectl delete crd tenants.multitenancy.example.com
```

Delete the namespace:

```bash
kubectl delete namespace tutorial-crds
```

## Reference Commands

| Task | Command |
|------|---------|
| List custom resources | `kubectl get <resource> -n <namespace>` |
| Describe custom resource | `kubectl describe <resource> <name> -n <namespace>` |
| Create custom resource | `kubectl apply -f <file>` |
| Update custom resource | `kubectl apply -f <file>` or `kubectl patch` |
| Delete custom resource | `kubectl delete <resource> <name> -n <namespace>` |
| Check permissions | `kubectl auth can-i <verb> <resource> -n <namespace>` |
| List API resources | `kubectl api-resources --api-group=<group>` |
| Explain resource | `kubectl explain <resource> --api-version=<version>` |

## Key Takeaways

1. **Custom resources** behave like built-in resources: create, get, describe, update, delete
2. **Namespaced resources** require a namespace, cluster-scoped do not
3. **Schema validation** prevents invalid resources from being created
4. **RBAC for custom resources** uses the CRD's group as apiGroups and plural name as resources
5. **Status subresource** requires separate RBAC rules for /status
6. **Short names** and categories improve kubectl usability
7. **kubectl auth can-i** tests permissions without actually performing operations
