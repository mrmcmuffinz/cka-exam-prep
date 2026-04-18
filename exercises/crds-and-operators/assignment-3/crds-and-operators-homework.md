# CRDs and Operators Homework: Operators and Controllers

This homework contains 15 progressive exercises to practice working with operators and controllers. Complete the tutorial before attempting these exercises.

---

## Level 1: Understanding Controllers

### Exercise 1.1

**Objective:** Identify built-in controllers and their functions.

**Setup:**

```bash
kubectl create namespace ex-1-1
```

**Task:**

Create a Deployment in namespace ex-1-1 and trace the chain of resources created by controllers:
1. Create a deployment named `web` with image nginx:1.25 and 2 replicas
2. Identify the ReplicaSet created by the Deployment controller
3. Identify the Pods created by the ReplicaSet controller
4. Document the owner references showing the controller chain

**Verification:**

```bash
# Check the deployment
kubectl get deployment web -n ex-1-1

# Expected: Ready 2/2

# Check the ReplicaSet
kubectl get replicaset -n ex-1-1

# Expected: One ReplicaSet owned by deployment web

# Check Pods
kubectl get pods -n ex-1-1

# Expected: Two Pods owned by the ReplicaSet

# Check owner reference on ReplicaSet
kubectl get replicaset -n ex-1-1 -o jsonpath='{.items[0].metadata.ownerReferences[0].kind}'

# Expected: Deployment

# Check owner reference on Pod
kubectl get pods -n ex-1-1 -o jsonpath='{.items[0].metadata.ownerReferences[0].kind}'

# Expected: ReplicaSet
```

---

### Exercise 1.2

**Objective:** Trace a Deployment controller reconciliation.

**Setup:**

```bash
kubectl create namespace ex-1-2
kubectl create deployment demo --image=nginx:1.25 --replicas=1 -n ex-1-2
```

**Task:**

Trigger reconciliation by scaling the deployment and observe the results:
1. Scale the deployment to 3 replicas
2. Verify the ReplicaSet's desired count changed
3. Verify new Pods were created
4. Note the timing of controller actions

**Verification:**

```bash
# Scale the deployment
kubectl scale deployment demo --replicas=3 -n ex-1-2

# Check ReplicaSet replicas
kubectl get replicaset -n ex-1-2

# Expected: Desired 3, Current 3, Ready 3

# Check Pods
kubectl get pods -n ex-1-2

# Expected: 3 pods running
```

---

### Exercise 1.3

**Objective:** Observe controller manager logs.

**Setup:**

Ensure you have cluster admin access.

**Task:**

View the kube-controller-manager logs to see controller activity:
1. List pods in the kube-system namespace with controller-manager in the name
2. View the recent logs from the controller manager
3. Identify log entries related to a specific controller (like Deployment)

**Verification:**

```bash
# Find the controller manager pod
kubectl get pods -n kube-system | grep controller-manager

# View logs (may vary based on cluster setup)
kubectl logs -n kube-system -l component=kube-controller-manager --tail=50

# Expected: Log entries showing controller activity
```

---

## Level 2: Installing Operators

### Exercise 2.1

**Objective:** Install a simple operator from manifests.

**Setup:**

```bash
kubectl create namespace ex-2-1
```

**Task:**

Install a simple operator by creating:
1. A CRD for "Message" resources (group: demo.example.com)
2. A ServiceAccount named "message-operator"
3. A Role with permissions to manage Messages and Pods
4. A RoleBinding connecting the ServiceAccount to the Role
5. A Deployment for the operator (use busybox:1.36 with a sleep command as a placeholder)

**Verification:**

```bash
# Verify CRD exists
kubectl get crd messages.demo.example.com

# Verify operator deployment
kubectl get deployment message-operator -n ex-2-1

# Expected: 1/1 Ready

# Verify operator pod
kubectl get pods -n ex-2-1 -l app=message-operator

# Expected: Running
```

---

### Exercise 2.2

**Objective:** Verify operator deployment and CRD creation.

**Setup:**

Use the operator from Exercise 2.1.

**Task:**

Verify the operator installation is complete:
1. Confirm the CRD is registered and shows in api-resources
2. Confirm the operator service account has the expected permissions
3. Confirm the operator pod is running and healthy

**Verification:**

```bash
# Check CRD in api-resources
kubectl api-resources | grep messages

# Expected: messages  demo.example.com/v1  true  Message

# Check service account permissions
kubectl auth can-i list messages -n ex-2-1 --as=system:serviceaccount:ex-2-1:message-operator

# Expected: yes

# Check operator health
kubectl get pods -n ex-2-1 -l app=message-operator -o jsonpath='{.items[0].status.phase}'

# Expected: Running
```

---

### Exercise 2.3

**Objective:** Create a custom resource and observe operator behavior.

**Setup:**

Use the operator from Exercise 2.1.

**Task:**

Create a Message custom resource and verify it was created successfully:
1. Create a Message named "hello" with content "Hello World"
2. List all Messages in the namespace
3. Describe the Message
4. Check operator logs for any activity

**Verification:**

```bash
# Create Message resource
kubectl apply -f - <<EOF
apiVersion: demo.example.com/v1
kind: Message
metadata:
  name: hello
  namespace: ex-2-1
spec:
  content: "Hello World"
EOF

# List Messages
kubectl get messages -n ex-2-1

# Expected: hello

# Describe Message
kubectl describe message hello -n ex-2-1

# Expected: Shows spec.content: Hello World
```

---

## Level 3: Debugging Operator Issues

### Exercise 3.1

**Objective:** An operator pod is failing. Diagnose and fix the issue.

**Setup:**

```bash
kubectl create namespace ex-3-1

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-operator
  namespace: ex-3-1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: broken-operator
  template:
    metadata:
      labels:
        app: broken-operator
    spec:
      containers:
      - name: operator
        image: nonexistent-registry.example.com/operator:v1
        command: ["sleep", "3600"]
EOF
```

**Task:**

The operator pod is failing to start. Diagnose the issue and fix it by updating the image to busybox:1.36.

**Verification:**

```bash
# Check pod status before fix
kubectl get pods -n ex-3-1

# Expected: ImagePullBackOff or ErrImagePull

# After fixing, verify
kubectl get pods -n ex-3-1

# Expected: Running
```

---

### Exercise 3.2

**Objective:** A custom resource is not being reconciled. Diagnose the issue.

**Setup:**

```bash
kubectl create namespace ex-3-2

# Create CRD
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
            properties:
              setting:
                type: string
  scope: Namespaced
  names:
    plural: configs
    singular: config
    kind: Config
EOF

# Create operator without correct permissions
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: config-operator
  namespace: ex-3-2
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: config-operator
  namespace: ex-3-2
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: config-operator
  namespace: ex-3-2
subjects:
- kind: ServiceAccount
  name: config-operator
  namespace: ex-3-2
roleRef:
  kind: Role
  name: config-operator
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: config-operator
  namespace: ex-3-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: config-operator
  template:
    metadata:
      labels:
        app: config-operator
    spec:
      serviceAccountName: config-operator
      containers:
      - name: operator
        image: busybox:1.36
        command: ["sleep", "3600"]
EOF
```

**Task:**

The operator cannot watch Config resources because the RBAC is incorrect. Fix the Role to include permissions for the configs resource type in the settings.example.com API group.

**Verification:**

```bash
# Test permissions after fix
kubectl auth can-i watch configs.settings.example.com -n ex-3-2 --as=system:serviceaccount:ex-3-2:config-operator

# Expected: yes

kubectl auth can-i list configs.settings.example.com -n ex-3-2 --as=system:serviceaccount:ex-3-2:config-operator

# Expected: yes
```

---

### Exercise 3.3

**Objective:** An operator has missing RBAC permissions. Diagnose and fix.

**Setup:**

```bash
kubectl create namespace ex-3-3

kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: incomplete-operator
  namespace: ex-3-3
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: incomplete-operator
  namespace: ex-3-3
spec:
  replicas: 1
  selector:
    matchLabels:
      app: incomplete-operator
  template:
    metadata:
      labels:
        app: incomplete-operator
    spec:
      serviceAccountName: incomplete-operator
      containers:
      - name: operator
        image: busybox:1.36
        command: ["sleep", "3600"]
EOF
```

**Task:**

The incomplete-operator service account has no Role or RoleBinding. Create RBAC resources that allow it to:
- Watch, get, list pods
- Create, delete, update pods
- Get, list, watch deployments

**Verification:**

```bash
# Test pod permissions
kubectl auth can-i create pods -n ex-3-3 --as=system:serviceaccount:ex-3-3:incomplete-operator

# Expected: yes

kubectl auth can-i delete pods -n ex-3-3 --as=system:serviceaccount:ex-3-3:incomplete-operator

# Expected: yes

# Test deployment permissions
kubectl auth can-i watch deployments -n ex-3-3 --as=system:serviceaccount:ex-3-3:incomplete-operator

# Expected: yes
```

---

## Level 4: Operator Lifecycle

### Exercise 4.1

**Objective:** Upgrade an operator to a new version.

**Setup:**

```bash
kubectl create namespace ex-4-1

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: versioned-operator
  namespace: ex-4-1
  labels:
    version: "1.0"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: versioned-operator
  template:
    metadata:
      labels:
        app: versioned-operator
        version: "1.0"
    spec:
      containers:
      - name: operator
        image: busybox:1.36
        command: ["sh", "-c", "echo 'Operator v1.0' && sleep 3600"]
EOF
```

**Task:**

Upgrade the operator to version 2.0:
1. Update the deployment label to version: "2.0"
2. Update the pod template label to version: "2.0"
3. Update the container command to echo "Operator v2.0"
4. Verify the new version is running

**Verification:**

```bash
# Check deployment labels
kubectl get deployment versioned-operator -n ex-4-1 -o jsonpath='{.metadata.labels.version}'

# Expected: 2.0

# Check pod version
kubectl get pods -n ex-4-1 -l app=versioned-operator -o jsonpath='{.items[0].metadata.labels.version}'

# Expected: 2.0

# Check logs
kubectl logs -n ex-4-1 -l app=versioned-operator

# Expected: Operator v2.0
```

---

### Exercise 4.2

**Objective:** Clean up an operator installation properly.

**Setup:**

```bash
kubectl create namespace ex-4-2

# Create a full operator installation
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: widgets.cleanup.example.com
spec:
  group: cleanup.example.com
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
    plural: widgets
    singular: widget
    kind: Widget
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: widget-operator
  namespace: ex-4-2
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: widget-operator
  namespace: ex-4-2
rules:
- apiGroups: ["cleanup.example.com"]
  resources: ["widgets"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: widget-operator
  namespace: ex-4-2
subjects:
- kind: ServiceAccount
  name: widget-operator
  namespace: ex-4-2
roleRef:
  kind: Role
  name: widget-operator
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: widget-operator
  namespace: ex-4-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: widget-operator
  template:
    metadata:
      labels:
        app: widget-operator
    spec:
      serviceAccountName: widget-operator
      containers:
      - name: operator
        image: busybox:1.36
        command: ["sleep", "3600"]
EOF

# Create a custom resource
kubectl apply -f - <<EOF
apiVersion: cleanup.example.com/v1
kind: Widget
metadata:
  name: test-widget
  namespace: ex-4-2
spec: {}
EOF
```

**Task:**

Clean up the operator installation in the correct order:
1. Delete custom resources first
2. Delete the operator deployment
3. Delete the CRD
4. Delete RBAC resources

**Verification:**

```bash
# Verify all resources are deleted
kubectl get widgets -n ex-4-2 2>&1 | grep -E "not found|No resources"

# Expected: error or empty

kubectl get deployment widget-operator -n ex-4-2 2>&1

# Expected: not found

kubectl get crd widgets.cleanup.example.com 2>&1

# Expected: not found
```

---

### Exercise 4.3

**Objective:** Document operator dependencies.

**Setup:**

Use any operator from previous exercises or create a new one.

**Task:**

Document the dependencies for an operator by listing:
1. The CRDs it requires
2. The RBAC permissions it needs
3. Any other resources it depends on (ServiceAccounts, Secrets, ConfigMaps)
4. The namespace it runs in

Create a simple documentation file by using kubectl to extract this information.

**Verification:**

```bash
# Example commands to document an operator
kubectl get crd | grep example.com
kubectl get role -n <namespace>
kubectl get rolebinding -n <namespace>
kubectl get serviceaccount -n <namespace>
kubectl get configmap -n <namespace>
kubectl get secret -n <namespace>
```

---

## Level 5: Complex Scenarios

### Exercise 5.1

**Objective:** Evaluate and install an operator for a use case.

**Setup:**

```bash
kubectl create namespace ex-5-1
```

**Task:**

Design and install an operator for managing "Application" resources. The operator should:
1. Have a CRD with fields: name (string), replicas (integer), image (string)
2. Have proper RBAC to manage Applications, Pods, and Services
3. Have a ServiceAccount and Deployment
4. Be running and ready to process Application resources

**Verification:**

```bash
# Verify CRD
kubectl get crd applications.mycompany.example.com

# Verify operator is running
kubectl get deployment -n ex-5-1 | grep operator

# Expected: 1/1 Ready

# Test RBAC
kubectl auth can-i watch applications.mycompany.example.com -n ex-5-1 --as=system:serviceaccount:ex-5-1:application-operator

# Expected: yes

# Create test Application
kubectl apply -f - <<EOF
apiVersion: mycompany.example.com/v1
kind: Application
metadata:
  name: test-app
  namespace: ex-5-1
spec:
  name: Test Application
  replicas: 2
  image: nginx:1.25
EOF

kubectl get applications -n ex-5-1

# Expected: test-app
```

---

### Exercise 5.2

**Objective:** Debug a complex operator failure.

**Setup:**

```bash
kubectl create namespace ex-5-2

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
            properties:
              engine:
                type: string
  scope: Namespaced
  names:
    plural: databases
    singular: database
    kind: Database
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: db-operator
  namespace: ex-5-2
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: db-operator
  namespace: ex-5-2
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: db-operator
  namespace: ex-5-2
subjects:
- kind: ServiceAccount
  name: db-operator
  namespace: ex-5-2
roleRef:
  kind: Role
  name: db-operator
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db-operator
  namespace: ex-5-2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db-operator
  template:
    metadata:
      labels:
        app: db-operator
    spec:
      serviceAccountName: db-operator
      containers:
      - name: operator
        image: busybox:1.36
        command: ["sleep", "3600"]
EOF
```

**Task:**

The db-operator has multiple issues preventing it from functioning properly:
1. Missing permissions to watch databases
2. Missing permissions to create/delete pods
3. Missing permissions to create events

Fix all RBAC issues so the operator can function properly.

**Verification:**

```bash
# Test all required permissions
kubectl auth can-i watch databases.data.example.com -n ex-5-2 --as=system:serviceaccount:ex-5-2:db-operator
# Expected: yes

kubectl auth can-i create pods -n ex-5-2 --as=system:serviceaccount:ex-5-2:db-operator
# Expected: yes

kubectl auth can-i delete pods -n ex-5-2 --as=system:serviceaccount:ex-5-2:db-operator
# Expected: yes

kubectl auth can-i create events -n ex-5-2 --as=system:serviceaccount:ex-5-2:db-operator
# Expected: yes
```

---

### Exercise 5.3

**Objective:** Design an operator adoption strategy for an organization.

**Setup:**

No setup required.

**Task:**

Document an operator adoption strategy that addresses:
1. How to evaluate operators before adoption (what criteria to use)
2. How to test operators safely (environments, testing approach)
3. How to monitor operators in production (logs, metrics, alerts)
4. How to handle operator upgrades (process, rollback plan)
5. How to manage operator RBAC (least privilege, audit)

This is a documentation exercise. Write your strategy as comments in a YAML file or as a ConfigMap.

**Verification:**

Create a ConfigMap with your strategy:

```bash
kubectl create configmap operator-strategy --from-literal=evaluation="Check maintenance, permissions, community" --from-literal=testing="Test in staging first" --from-literal=monitoring="Watch operator logs and metrics" --from-literal=upgrades="Stage upgrades, have rollback plan" --from-literal=rbac="Least privilege, audit regularly"
```

---

## Cleanup

Delete all exercise namespaces and CRDs:

```bash
kubectl delete namespace ex-1-1 ex-1-2 ex-2-1 ex-3-1 ex-3-2 ex-3-3 ex-4-1 ex-4-2 ex-5-1 ex-5-2
kubectl delete crd messages.demo.example.com --ignore-not-found
kubectl delete crd configs.settings.example.com --ignore-not-found
kubectl delete crd widgets.cleanup.example.com --ignore-not-found
kubectl delete crd databases.data.example.com --ignore-not-found
kubectl delete crd applications.mycompany.example.com --ignore-not-found
```

---

## Key Takeaways

1. Controllers watch resources and reconcile state continuously
2. Operators combine CRDs with controllers for domain-specific automation
3. Install operators by deploying CRDs, RBAC, and controller Deployment
4. Uninstall in order: custom resources, operator, CRDs, RBAC
5. Debug operators by checking pod status, logs, and RBAC permissions
6. Always test operators in non-production before adopting
7. Document operator dependencies for maintainability
