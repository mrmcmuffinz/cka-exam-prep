# CRDs and Operators Homework Answers: Operators and Controllers

This file contains complete solutions for all 15 exercises on operators and controllers.

---

## Exercise 1.1 Solution

**Task:** Create deployment and trace controller chain.

```bash
kubectl create deployment web --image=nginx:1.25 --replicas=2 -n ex-1-1
```

View the chain:

```bash
# Get ReplicaSet
kubectl get replicaset -n ex-1-1

# Get owner reference
kubectl get replicaset -n ex-1-1 -o jsonpath='{.items[0].metadata.ownerReferences[0].kind}'
# Output: Deployment

# Get Pods
kubectl get pods -n ex-1-1

# Get owner reference
kubectl get pods -n ex-1-1 -o jsonpath='{.items[0].metadata.ownerReferences[0].kind}'
# Output: ReplicaSet
```

**Explanation:** The Deployment controller creates a ReplicaSet with an ownerReference pointing to the Deployment. The ReplicaSet controller creates Pods with ownerReferences pointing to the ReplicaSet.

---

## Exercise 1.2 Solution

**Task:** Scale and observe reconciliation.

```bash
kubectl scale deployment demo --replicas=3 -n ex-1-2

kubectl get replicaset -n ex-1-2
kubectl get pods -n ex-1-2
```

**Explanation:** When you scale a Deployment, the Deployment controller updates the ReplicaSet's replica count. The ReplicaSet controller then creates additional Pods to match the desired count.

---

## Exercise 1.3 Solution

**Task:** View controller manager logs.

```bash
kubectl get pods -n kube-system | grep controller-manager
kubectl logs -n kube-system -l component=kube-controller-manager --tail=50
```

**Explanation:** The kube-controller-manager runs all built-in controllers. Its logs show controller activity including reconciliation events.

---

## Exercise 2.1 Solution

**Task:** Install a simple operator.

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: messages.demo.example.com
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
              content:
                type: string
  scope: Namespaced
  names:
    plural: messages
    singular: message
    kind: Message
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: message-operator
  namespace: ex-2-1
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: message-operator
  namespace: ex-2-1
rules:
- apiGroups: ["demo.example.com"]
  resources: ["messages"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: message-operator
  namespace: ex-2-1
subjects:
- kind: ServiceAccount
  name: message-operator
  namespace: ex-2-1
roleRef:
  kind: Role
  name: message-operator
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: message-operator
  namespace: ex-2-1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: message-operator
  template:
    metadata:
      labels:
        app: message-operator
    spec:
      serviceAccountName: message-operator
      containers:
      - name: operator
        image: busybox:1.36
        command: ["sleep", "3600"]
EOF
```

**Explanation:** A complete operator installation includes CRD, ServiceAccount, Role, RoleBinding, and Deployment.

---

## Exercise 2.2 Solution

**Task:** Verify operator installation.

```bash
kubectl api-resources | grep messages
kubectl auth can-i list messages -n ex-2-1 --as=system:serviceaccount:ex-2-1:message-operator
kubectl get pods -n ex-2-1 -l app=message-operator -o jsonpath='{.items[0].status.phase}'
```

**Explanation:** Verify CRD registration, RBAC permissions, and pod health.

---

## Exercise 2.3 Solution

**Task:** Create and verify custom resource.

```bash
kubectl apply -f - <<EOF
apiVersion: demo.example.com/v1
kind: Message
metadata:
  name: hello
  namespace: ex-2-1
spec:
  content: "Hello World"
EOF

kubectl get messages -n ex-2-1
kubectl describe message hello -n ex-2-1
```

**Explanation:** Custom resources are created like any Kubernetes resource using kubectl apply.

---

## Exercise 3.1 Solution

**Problem:** Image pull failure due to nonexistent registry.

**Fix:**

```bash
kubectl set image deployment/broken-operator operator=busybox:1.36 -n ex-3-1
```

Or patch:

```bash
kubectl patch deployment broken-operator -n ex-3-1 --type=strategic -p '{"spec":{"template":{"spec":{"containers":[{"name":"operator","image":"busybox:1.36"}]}}}}'
```

**Explanation:** The image was from a nonexistent registry. Updating to a valid image fixes the issue.

---

## Exercise 3.2 Solution

**Problem:** Role is missing permissions for configs resource.

**Fix:**

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: config-operator
  namespace: ex-3-2
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
- apiGroups: ["settings.example.com"]
  resources: ["configs"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF
```

**Explanation:** Added rules for the configs resource in the settings.example.com API group.

---

## Exercise 3.3 Solution

**Task:** Create missing RBAC.

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: incomplete-operator
  namespace: ex-3-3
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: incomplete-operator
  namespace: ex-3-3
subjects:
- kind: ServiceAccount
  name: incomplete-operator
  namespace: ex-3-3
roleRef:
  kind: Role
  name: incomplete-operator
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Explanation:** Created Role and RoleBinding with the required permissions.

---

## Exercise 4.1 Solution

**Task:** Upgrade operator version.

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: versioned-operator
  namespace: ex-4-1
  labels:
    version: "2.0"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: versioned-operator
  template:
    metadata:
      labels:
        app: versioned-operator
        version: "2.0"
    spec:
      containers:
      - name: operator
        image: busybox:1.36
        command: ["sh", "-c", "echo 'Operator v2.0' && sleep 3600"]
EOF
```

**Explanation:** Update the deployment with new version labels and updated command.

---

## Exercise 4.2 Solution

**Task:** Clean up operator in correct order.

```bash
# 1. Delete custom resources
kubectl delete widgets --all -n ex-4-2

# 2. Delete operator deployment
kubectl delete deployment widget-operator -n ex-4-2

# 3. Delete CRD
kubectl delete crd widgets.cleanup.example.com

# 4. Delete RBAC
kubectl delete rolebinding widget-operator -n ex-4-2
kubectl delete role widget-operator -n ex-4-2
kubectl delete serviceaccount widget-operator -n ex-4-2
```

**Explanation:** Delete custom resources first so the operator can clean up. Then delete operator, CRD, and RBAC.

---

## Exercise 4.3 Solution

**Task:** Document operator dependencies.

```bash
# List CRDs
kubectl get crd | grep example.com

# List Roles
kubectl get role -n <namespace>

# List RoleBindings
kubectl get rolebinding -n <namespace>

# List ServiceAccounts
kubectl get serviceaccount -n <namespace>
```

**Explanation:** Documentation helps with maintenance and troubleshooting.

---

## Exercise 5.1 Solution

**Task:** Design and install Application operator.

```bash
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: applications.mycompany.example.com
spec:
  group: mycompany.example.com
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
              replicas:
                type: integer
              image:
                type: string
  scope: Namespaced
  names:
    plural: applications
    singular: application
    kind: Application
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: application-operator
  namespace: ex-5-1
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: application-operator
  namespace: ex-5-1
rules:
- apiGroups: ["mycompany.example.com"]
  resources: ["applications"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: application-operator
  namespace: ex-5-1
subjects:
- kind: ServiceAccount
  name: application-operator
  namespace: ex-5-1
roleRef:
  kind: Role
  name: application-operator
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: application-operator
  namespace: ex-5-1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: application-operator
  template:
    metadata:
      labels:
        app: application-operator
    spec:
      serviceAccountName: application-operator
      containers:
      - name: operator
        image: busybox:1.36
        command: ["sleep", "3600"]
EOF
```

**Explanation:** Complete operator with CRD, RBAC, and Deployment.

---

## Exercise 5.2 Solution

**Task:** Fix multiple RBAC issues.

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: db-operator
  namespace: ex-5-2
rules:
- apiGroups: ["data.example.com"]
  resources: ["databases"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch", "create", "update", "delete"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["create", "patch"]
EOF
```

**Explanation:** Added permissions for databases, full pod management, and event creation.

---

## Exercise 5.3 Solution

**Task:** Document operator strategy.

```bash
kubectl create configmap operator-strategy -n default --from-literal=evaluation="1. Check if actively maintained, 2. Review required permissions, 3. Check community support, 4. Verify compatibility" --from-literal=testing="1. Deploy to dev/staging first, 2. Test all CR operations, 3. Test failure scenarios, 4. Load test if applicable" --from-literal=monitoring="1. Forward operator logs, 2. Create alerts for failures, 3. Track CR reconciliation time, 4. Monitor resource usage" --from-literal=upgrades="1. Read release notes, 2. Backup CRs, 3. Test in staging, 4. Have rollback plan, 5. Monitor after upgrade" --from-literal=rbac="1. Use least privilege, 2. Audit permissions, 3. Use dedicated namespaces, 4. Review periodically"
```

**Explanation:** A strategy ConfigMap documents the organization's approach to operator adoption.

---

## Common Mistakes

### Deleting CRD before custom resources (orphans them)

Always delete custom resources first so the operator can clean up managed resources.

### Operator RBAC too restrictive

Operators need permissions to watch their CRDs and manage the resources they create.

### Version mismatch between operator and CRD

Ensure the operator version matches the CRD schema version it expects.

### Not checking operator logs when troubleshooting

Operator logs are the first place to look for reconciliation errors.

### Installing operators without understanding their permissions

Review RBAC before installing operators in production.

---

## Operator Troubleshooting Cheat Sheet

| Issue | Diagnostic Command |
|-------|-------------------|
| Pod not starting | `kubectl describe pod <pod>` |
| Image pull error | `kubectl get events -n <ns>` |
| RBAC issues | `kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa>` |
| CRD not found | `kubectl get crd` |
| Reconciliation failing | `kubectl logs <operator-pod>` |
| Custom resource stuck | `kubectl describe <cr-type> <name>` |

### Operator Installation Checklist

1. CRD installed and shows in api-resources
2. ServiceAccount created
3. Role/ClusterRole has required permissions
4. RoleBinding/ClusterRoleBinding connects SA to Role
5. Operator Deployment running (1/1 Ready)
6. Operator pod logs show no errors

### Uninstall Order

1. Delete custom resources
2. Delete operator Deployment
3. Delete CRDs
4. Delete RoleBindings
5. Delete Roles
6. Delete ServiceAccounts
