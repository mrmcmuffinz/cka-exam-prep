# CRDs and Operators Tutorial: Operators and Controllers

## Introduction

Operators extend Kubernetes by encoding operational knowledge into software. They combine Custom Resource Definitions (CRDs) with custom controllers that watch for changes to those resources and take action to reconcile the actual state with the desired state. Understanding the operator pattern is essential for working with complex applications in Kubernetes.

This tutorial explains how controllers work, what the operator pattern is, how to install and manage operators, and how to troubleshoot common issues.

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

## Understanding Controllers

A controller is a control loop that watches the state of resources and takes action to move the current state toward the desired state. Kubernetes has many built-in controllers that manage built-in resources.

### The Watch-Reconcile Loop

Controllers follow a simple pattern:

1. **Watch** for changes to resources (created, updated, deleted)
2. **Read** the current state and desired state
3. **Compare** the two states
4. **Reconcile** by taking action to move current toward desired
5. **Repeat** continuously

This is sometimes called a "level-triggered" system: the controller responds to the current state, not just to events.

### Built-in Controllers

Kubernetes includes many controllers that run in the kube-controller-manager:

| Controller | What it manages |
|------------|-----------------|
| Deployment controller | Creates/updates ReplicaSets based on Deployment specs |
| ReplicaSet controller | Creates/deletes Pods to match replica count |
| Node controller | Monitors node health, taints unhealthy nodes |
| Service controller | Creates cloud load balancers for LoadBalancer services |
| EndpointSlice controller | Populates EndpointSlices for Services |

### Observing the Deployment Controller

Let us observe how the Deployment controller works:

```bash
kubectl create deployment nginx --image=nginx:1.25 -n tutorial-crds
```

Watch the controller manager logs (you may need to wait a moment):

```bash
kubectl logs -n kube-system -l component=kube-controller-manager --tail=20
```

Observe the chain of reconciliation:

```bash
# The Deployment controller created a ReplicaSet
kubectl get replicasets -n tutorial-crds

# The ReplicaSet controller created Pods
kubectl get pods -n tutorial-crds
```

The Deployment controller watches Deployments and creates/updates ReplicaSets. The ReplicaSet controller watches ReplicaSets and creates/deletes Pods.

## The Operator Pattern

An operator is a controller that:
1. Manages application-specific resources (CRDs)
2. Encodes domain knowledge about how to operate the application
3. Automates tasks that a human operator would perform

For example, a database operator might:
- Deploy database instances based on a Database CRD
- Handle backups automatically based on a BackupSchedule CRD
- Perform failover when a primary fails
- Scale replicas based on load

### Operator Components

A typical operator includes:

1. **CRDs** that define the custom resource types
2. **Controller** (usually a Deployment) that watches the CRDs
3. **RBAC** that grants the controller permissions
4. **Service Account** for the controller to use

### Why Operators?

Operators are useful when:
- Applications have complex operational requirements
- Manual intervention is error-prone
- You want to standardize operations across teams
- Applications need to respond to Kubernetes events

## Installing an Operator

Operators are typically installed via:
- kubectl apply with YAML manifests
- Helm charts
- Operator Lifecycle Manager (OLM)

### Creating a Simple Operator

Let us create a simple "echo operator" that demonstrates the pattern. First, create the CRD:

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: echoconfigs.demo.example.com
spec:
  group: demo.example.com
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
              message:
                type: string
              replicas:
                type: integer
  scope: Namespaced
  names:
    plural: echoconfigs
    singular: echoconfig
    kind: EchoConfig
EOF
```

Create the RBAC resources:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: echo-operator
  namespace: tutorial-crds
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: echo-operator
  namespace: tutorial-crds
rules:
- apiGroups: ["demo.example.com"]
  resources: ["echoconfigs"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch", "create", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: echo-operator
  namespace: tutorial-crds
subjects:
- kind: ServiceAccount
  name: echo-operator
  namespace: tutorial-crds
roleRef:
  kind: Role
  name: echo-operator
  apiGroup: rbac.authorization.k8s.io
EOF
```

In a real operator, you would deploy a controller that watches EchoConfig resources and creates Pods. For this tutorial, we will use a shell-based watcher to demonstrate the concept:

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo-operator
  namespace: tutorial-crds
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo-operator
  template:
    metadata:
      labels:
        app: echo-operator
    spec:
      serviceAccountName: echo-operator
      containers:
      - name: operator
        image: busybox:1.36
        command: ["sh", "-c", "echo 'Echo operator started'; sleep 3600"]
EOF
```

Verify the operator is running:

```bash
kubectl get deployment echo-operator -n tutorial-crds
kubectl get pods -n tutorial-crds -l app=echo-operator
```

### Creating a Custom Resource

Now create an EchoConfig resource:

```bash
kubectl apply -f - <<EOF
apiVersion: demo.example.com/v1
kind: EchoConfig
metadata:
  name: my-echo
  namespace: tutorial-crds
spec:
  message: "Hello from the operator!"
  replicas: 2
EOF
```

In a real operator, the controller would notice this resource and create Pods. Since our demo operator just sleeps, nothing happens automatically, but you can verify the resource was created:

```bash
kubectl get echoconfigs -n tutorial-crds
```

## Operator Lifecycle

### Verifying Operator Installation

After installing an operator, verify:

1. The CRDs exist:
```bash
kubectl get crd | grep example.com
```

2. The operator deployment is running:
```bash
kubectl get deployment -n tutorial-crds -l app=echo-operator
```

3. The operator pod is healthy:
```bash
kubectl get pods -n tutorial-crds -l app=echo-operator
kubectl logs -n tutorial-crds -l app=echo-operator
```

### Uninstalling Operators

When uninstalling operators, follow this order:

1. **Delete custom resources first** (so the operator can clean up)
2. **Delete the operator deployment**
3. **Delete the CRDs** (this also deletes any remaining custom resources)
4. **Delete RBAC resources**

```bash
# 1. Delete custom resources
kubectl delete echoconfigs --all -n tutorial-crds

# 2. Delete operator deployment
kubectl delete deployment echo-operator -n tutorial-crds

# 3. Delete CRD
kubectl delete crd echoconfigs.demo.example.com

# 4. Delete RBAC
kubectl delete rolebinding echo-operator -n tutorial-crds
kubectl delete role echo-operator -n tutorial-crds
kubectl delete serviceaccount echo-operator -n tutorial-crds
```

**Warning:** Deleting the CRD before custom resources can orphan resources or prevent proper cleanup.

## Troubleshooting Operators

### Operator Pod Not Starting

Check pod status:
```bash
kubectl get pods -n <namespace> -l <operator-label>
kubectl describe pod <operator-pod> -n <namespace>
```

Common issues:
- Image pull errors (wrong image name or no access)
- RBAC errors (missing permissions)
- Missing secrets or configmaps

### Operator Not Reconciling

Check operator logs:
```bash
kubectl logs -n <namespace> <operator-pod>
```

Common issues:
- CRD not installed
- Wrong API version in custom resource
- RBAC missing for watched resources

### Custom Resource Not Being Processed

Verify:
1. The operator pod is running
2. The operator has RBAC to watch the resource type
3. The custom resource has the correct API version and kind
4. Check operator logs for errors

## Best Practices

### When to Use Operators

Operators are appropriate when:
- Applications have complex operational logic
- You need to automate day-2 operations (backup, upgrade, failover)
- The application has stateful components

Consider simpler approaches when:
- Standard Kubernetes resources suffice
- Operations are straightforward
- Maintenance burden outweighs benefits

### Evaluating Operators

Before adopting an operator:
- Check if it is actively maintained
- Review the permissions it requires
- Test in non-production first
- Understand the CRDs it creates
- Have a plan for upgrades

### Operator Security

- Review RBAC permissions (least privilege)
- Use dedicated service accounts
- Limit namespace access where possible
- Monitor operator behavior

## Cleanup

Delete the remaining tutorial resources:

```bash
kubectl delete namespace tutorial-crds
kubectl delete crd echoconfigs.demo.example.com --ignore-not-found
```

## Reference Commands

| Task | Command |
|------|---------|
| List operator pods | `kubectl get pods -n <ns> -l <label>` |
| View operator logs | `kubectl logs -n <ns> <pod>` |
| Check CRDs | `kubectl get crd` |
| Describe CRD | `kubectl describe crd <name>` |
| View controller manager logs | `kubectl logs -n kube-system -l component=kube-controller-manager` |
| Check RBAC | `kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa>` |

## Key Takeaways

1. **Controllers** watch resources and reconcile state in a continuous loop
2. **Operators** combine CRDs with controllers to manage complex applications
3. **The operator pattern** encodes operational knowledge as software
4. **Installation** typically includes CRDs, RBAC, and a controller Deployment
5. **Uninstall in order:** custom resources, then operator, then CRDs
6. **Troubleshoot** by checking pod status, logs, and RBAC permissions
7. **Evaluate carefully** before adopting operators in production
