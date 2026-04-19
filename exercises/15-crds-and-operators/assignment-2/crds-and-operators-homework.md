# CRDs and Operators Homework: Custom Resources and RBAC

This homework contains 15 progressive exercises to practice custom resource operations and RBAC configuration. Complete the tutorial before attempting these exercises.

---

## Setup for All Exercises

Create the CRD that will be used throughout these exercises:

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
    subresources:
      status: {}
    additionalPrinterColumns:
    - name: Version
      type: string
      jsonPath: .spec.version
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
            - name
            properties:
              name:
                type: string
              version:
                type: string
              replicas:
                type: integer
                minimum: 1
                maximum: 10
              environment:
                type: string
                enum:
                - dev
                - staging
                - prod
          status:
            type: object
            properties:
              phase:
                type: string
              availableReplicas:
                type: integer
  scope: Namespaced
  names:
    plural: applications
    singular: application
    kind: Application
    shortNames:
    - app
    - apps
    categories:
    - all
EOF
```

---

## Level 1: Basic Custom Resource Operations

### Exercise 1.1

**Objective:** Create a custom resource instance.

**Setup:**

```bash
kubectl create namespace ex-1-1
```

**Task:**

Create an Application resource named `web-frontend` in namespace `ex-1-1` with:
- name: "Frontend Service"
- version: "2.0.0"
- replicas: 3
- environment: prod

**Verification:**

```bash
# Verify the resource was created
kubectl get application web-frontend -n ex-1-1

# Expected: Shows web-frontend with Version 2.0.0 and Replicas 3

# Verify the spec
kubectl get application web-frontend -n ex-1-1 -o jsonpath='{.spec.name}'

# Expected: Frontend Service
```

---

### Exercise 1.2

**Objective:** List and describe custom resources.

**Setup:**

```bash
kubectl create namespace ex-1-2

# Create some applications
kubectl apply -f - <<EOF
apiVersion: apps.example.com/v1
kind: Application
metadata:
  name: api-server
  namespace: ex-1-2
spec:
  name: API Server
  version: "1.5.0"
  replicas: 2
---
apiVersion: apps.example.com/v1
kind: Application
metadata:
  name: worker
  namespace: ex-1-2
spec:
  name: Background Worker
  version: "1.2.0"
  replicas: 5
---
apiVersion: apps.example.com/v1
kind: Application
metadata:
  name: scheduler
  namespace: ex-1-2
spec:
  name: Task Scheduler
  version: "0.9.0"
  replicas: 1
EOF
```

**Task:**

1. List all applications in namespace ex-1-2
2. List applications using the short name
3. Describe the api-server application
4. Extract just the version of the worker application

**Verification:**

```bash
# List all applications
kubectl get applications -n ex-1-2

# Expected: Shows 3 applications with their versions and replicas

# List using short name
kubectl get app -n ex-1-2

# Expected: Same output

# Describe api-server
kubectl describe application api-server -n ex-1-2

# Expected: Shows full details including spec fields

# Get worker version
kubectl get application worker -n ex-1-2 -o jsonpath='{.spec.version}'

# Expected: 1.2.0
```

---

### Exercise 1.3

**Objective:** Update and delete custom resources.

**Setup:**

```bash
kubectl create namespace ex-1-3

kubectl apply -f - <<EOF
apiVersion: apps.example.com/v1
kind: Application
metadata:
  name: myapp
  namespace: ex-1-3
spec:
  name: My Application
  version: "1.0.0"
  replicas: 2
EOF
```

**Task:**

1. Update the myapp resource to version "1.1.0" and replicas 4
2. Verify the update
3. Delete the myapp resource
4. Verify deletion

**Verification:**

```bash
# After update
kubectl get application myapp -n ex-1-3

# Expected: Version 1.1.0, Replicas 4

# After deletion
kubectl get application myapp -n ex-1-3

# Expected: Error: not found
```

---

## Level 2: Namespacing and Discovery

### Exercise 2.1

**Objective:** Create applications in different namespaces.

**Setup:**

```bash
kubectl create namespace ex-2-1-dev
kubectl create namespace ex-2-1-prod
```

**Task:**

Create applications in both namespaces:
1. In ex-2-1-dev: app named "feature-branch" with environment: dev
2. In ex-2-1-prod: app named "release" with environment: prod

Then list applications across all namespaces.

**Verification:**

```bash
# List in dev namespace
kubectl get app -n ex-2-1-dev

# Expected: feature-branch

# List in prod namespace
kubectl get app -n ex-2-1-prod

# Expected: release

# List across all namespaces
kubectl get app --all-namespaces

# Expected: Shows both applications with their namespaces
```

---

### Exercise 2.2

**Objective:** Use kubectl api-resources to discover custom resources.

**Setup:**

Ensure the applications CRD exists.

**Task:**

1. Find the applications resource using api-resources
2. Verify the API group is apps.example.com
3. Check if it is namespaced
4. Find the short names

**Verification:**

```bash
# Find applications resource
kubectl api-resources --api-group=apps.example.com

# Expected: Shows applications with short names app, apps

# Verify namespaced
kubectl api-resources --api-group=apps.example.com -o wide | grep applications

# Expected: Shows NAMESPACED as true
```

---

### Exercise 2.3

**Objective:** Use short names and verify categories.

**Setup:**

```bash
kubectl create namespace ex-2-3

kubectl apply -f - <<EOF
apiVersion: apps.example.com/v1
kind: Application
metadata:
  name: demo
  namespace: ex-2-3
spec:
  name: Demo App
  version: "1.0.0"
  replicas: 1
EOF
```

**Task:**

1. Get the application using both short names (app and apps)
2. Verify the application appears in "kubectl get all"

**Verification:**

```bash
# Using short name 'app'
kubectl get app demo -n ex-2-3

# Expected: Shows demo application

# Using short name 'apps'
kubectl get apps demo -n ex-2-3

# Expected: Same output

# Check if appears in 'all' category
kubectl get all -n ex-2-3 | grep demo

# Expected: Shows application.apps.example.com/demo
```

---

## Level 3: Debugging Custom Resource Issues

### Exercise 3.1

**Objective:** A custom resource fails validation. Find and fix the issue.

**Setup:**

```bash
kubectl create namespace ex-3-1
```

**Task:**

Try to create this application (it will fail):

```bash
kubectl apply -f - <<EOF
apiVersion: apps.example.com/v1
kind: Application
metadata:
  name: invalid-app
  namespace: ex-3-1
spec:
  name: Invalid Application
  version: "1.0.0"
  replicas: 15
  environment: production
EOF
```

Diagnose why it fails and fix the resource so it creates successfully.

**Verification:**

```bash
# After fixing, verify the resource was created
kubectl get app invalid-app -n ex-3-1

# Expected: Resource exists and shows valid configuration
```

---

### Exercise 3.2

**Objective:** A service account cannot access custom resources. Find and fix the issue.

**Setup:**

```bash
kubectl create namespace ex-3-2
kubectl create serviceaccount app-viewer -n ex-3-2

kubectl apply -f - <<EOF
apiVersion: apps.example.com/v1
kind: Application
metadata:
  name: secure-app
  namespace: ex-3-2
spec:
  name: Secure Application
  version: "1.0.0"
  replicas: 1
EOF
```

**Task:**

The app-viewer service account cannot list applications. Create the necessary RBAC resources to grant it read-only access (get, list, watch) to applications in the ex-3-2 namespace.

**Verification:**

```bash
# Test the permission
kubectl auth can-i list applications -n ex-3-2 --as=system:serviceaccount:ex-3-2:app-viewer

# Expected: yes

kubectl auth can-i get applications -n ex-3-2 --as=system:serviceaccount:ex-3-2:app-viewer

# Expected: yes

kubectl auth can-i delete applications -n ex-3-2 --as=system:serviceaccount:ex-3-2:app-viewer

# Expected: no (we only granted read access)
```

---

### Exercise 3.3

**Objective:** A custom resource lookup fails. Find and fix the issue.

**Setup:**

```bash
kubectl create namespace ex-3-3

kubectl apply -f - <<EOF
apiVersion: apps.example.com/v1
kind: Application
metadata:
  name: prod-api
  namespace: ex-3-3
spec:
  name: Production API
  version: "2.0.0"
  replicas: 3
EOF
```

**Task:**

A user tries to get the application but uses the wrong namespace:

```bash
kubectl get application prod-api -n default
```

This fails because the resource is in ex-3-3, not default. Demonstrate:
1. How to find which namespace contains the resource
2. How to get the resource from the correct namespace

**Verification:**

```bash
# Find the resource across namespaces
kubectl get applications --all-namespaces | grep prod-api

# Expected: Shows ex-3-3 namespace

# Get from correct namespace
kubectl get application prod-api -n ex-3-3

# Expected: Shows the resource
```

---

## Level 4: RBAC for Custom Resources

### Exercise 4.1

**Objective:** Create a Role allowing specific verbs on custom resources.

**Setup:**

```bash
kubectl create namespace ex-4-1
kubectl create serviceaccount app-manager -n ex-4-1
```

**Task:**

Create a Role named "application-manager" in namespace ex-4-1 that allows:
- get, list, watch, create, update, patch on applications
- get, update, patch on applications/status

Then create a RoleBinding to bind this role to the app-manager service account.

**Verification:**

```bash
# Test permissions
kubectl auth can-i create applications -n ex-4-1 --as=system:serviceaccount:ex-4-1:app-manager

# Expected: yes

kubectl auth can-i update applications/status -n ex-4-1 --as=system:serviceaccount:ex-4-1:app-manager

# Expected: yes

kubectl auth can-i delete applications -n ex-4-1 --as=system:serviceaccount:ex-4-1:app-manager

# Expected: no (delete not granted)
```

---

### Exercise 4.2

**Objective:** Bind a role to a service account and test permissions.

**Setup:**

```bash
kubectl create namespace ex-4-2
kubectl create serviceaccount deployer -n ex-4-2

# Create a simple role
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-deployer
  namespace: ex-4-2
rules:
- apiGroups: ["apps.example.com"]
  resources: ["applications"]
  verbs: ["get", "list", "create", "update"]
EOF
```

**Task:**

1. Create a RoleBinding to bind the app-deployer role to the deployer service account
2. Test that the deployer can create and update applications
3. Test that the deployer cannot delete applications

**Verification:**

```bash
# Test create permission
kubectl auth can-i create applications -n ex-4-2 --as=system:serviceaccount:ex-4-2:deployer

# Expected: yes

# Test update permission
kubectl auth can-i update applications -n ex-4-2 --as=system:serviceaccount:ex-4-2:deployer

# Expected: yes

# Test delete permission (should be denied)
kubectl auth can-i delete applications -n ex-4-2 --as=system:serviceaccount:ex-4-2:deployer

# Expected: no
```

---

### Exercise 4.3

**Objective:** Test permissions with kubectl auth can-i.

**Setup:**

```bash
kubectl create namespace ex-4-3
kubectl create serviceaccount tester -n ex-4-3

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: limited-access
  namespace: ex-4-3
rules:
- apiGroups: ["apps.example.com"]
  resources: ["applications"]
  verbs: ["get", "list"]
EOF

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: tester-binding
  namespace: ex-4-3
subjects:
- kind: ServiceAccount
  name: tester
  namespace: ex-4-3
roleRef:
  kind: Role
  name: limited-access
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Task:**

Use kubectl auth can-i to test all standard verbs for the tester service account and document which are allowed and which are denied.

**Verification:**

```bash
# Test all verbs
kubectl auth can-i get applications -n ex-4-3 --as=system:serviceaccount:ex-4-3:tester
# Expected: yes

kubectl auth can-i list applications -n ex-4-3 --as=system:serviceaccount:ex-4-3:tester
# Expected: yes

kubectl auth can-i watch applications -n ex-4-3 --as=system:serviceaccount:ex-4-3:tester
# Expected: no

kubectl auth can-i create applications -n ex-4-3 --as=system:serviceaccount:ex-4-3:tester
# Expected: no

kubectl auth can-i update applications -n ex-4-3 --as=system:serviceaccount:ex-4-3:tester
# Expected: no

kubectl auth can-i patch applications -n ex-4-3 --as=system:serviceaccount:ex-4-3:tester
# Expected: no

kubectl auth can-i delete applications -n ex-4-3 --as=system:serviceaccount:ex-4-3:tester
# Expected: no
```

---

## Level 5: Complex Scenarios

### Exercise 5.1

**Objective:** Set up multi-user access to custom resources.

**Setup:**

```bash
kubectl create namespace ex-5-1
kubectl create serviceaccount developer -n ex-5-1
kubectl create serviceaccount operator -n ex-5-1
kubectl create serviceaccount admin -n ex-5-1
```

**Task:**

Create RBAC resources to implement these access levels:
- developer: get, list, watch applications
- operator: get, list, watch, create, update, patch applications
- admin: all verbs on applications including delete

Create separate Roles (or one Role with multiple rules) and RoleBindings for each service account.

**Verification:**

```bash
# Developer permissions
kubectl auth can-i list applications -n ex-5-1 --as=system:serviceaccount:ex-5-1:developer
# Expected: yes
kubectl auth can-i create applications -n ex-5-1 --as=system:serviceaccount:ex-5-1:developer
# Expected: no

# Operator permissions
kubectl auth can-i create applications -n ex-5-1 --as=system:serviceaccount:ex-5-1:operator
# Expected: yes
kubectl auth can-i delete applications -n ex-5-1 --as=system:serviceaccount:ex-5-1:operator
# Expected: no

# Admin permissions
kubectl auth can-i delete applications -n ex-5-1 --as=system:serviceaccount:ex-5-1:admin
# Expected: yes
```

---

### Exercise 5.2

**Objective:** Debug permission denied for custom resource operations.

**Setup:**

```bash
kubectl create namespace ex-5-2
kubectl create serviceaccount broken-sa -n ex-5-2

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: broken-role
  namespace: ex-5-2
rules:
- apiGroups: ["apps"]
  resources: ["application"]
  verbs: ["get", "list", "create"]
EOF

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: broken-binding
  namespace: ex-5-2
subjects:
- kind: ServiceAccount
  name: broken-sa
  namespace: ex-5-2
roleRef:
  kind: Role
  name: broken-role
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Task:**

The broken-sa service account cannot access applications despite having a Role. Diagnose and fix the issues. There are two problems with the Role.

**Verification:**

```bash
# After fixing, test permissions
kubectl auth can-i get applications -n ex-5-2 --as=system:serviceaccount:ex-5-2:broken-sa

# Expected: yes

kubectl auth can-i create applications -n ex-5-2 --as=system:serviceaccount:ex-5-2:broken-sa

# Expected: yes
```

---

### Exercise 5.3

**Objective:** Design RBAC strategy for custom resource lifecycle.

**Setup:**

```bash
kubectl create namespace ex-5-3
kubectl create serviceaccount controller -n ex-5-3
```

**Task:**

Design and implement RBAC for a controller that needs to:
1. Watch all applications in its namespace
2. Update the status of applications
3. Create Events related to applications
4. Get and list ConfigMaps for configuration

Create the necessary Role and RoleBinding. The controller should NOT be able to modify the spec of applications (only status).

**Verification:**

```bash
# Can watch applications
kubectl auth can-i watch applications -n ex-5-3 --as=system:serviceaccount:ex-5-3:controller
# Expected: yes

# Can update status
kubectl auth can-i update applications/status -n ex-5-3 --as=system:serviceaccount:ex-5-3:controller
# Expected: yes

# Cannot update the main resource (spec)
kubectl auth can-i update applications -n ex-5-3 --as=system:serviceaccount:ex-5-3:controller
# Expected: no

# Can create events
kubectl auth can-i create events -n ex-5-3 --as=system:serviceaccount:ex-5-3:controller
# Expected: yes

# Can get configmaps
kubectl auth can-i get configmaps -n ex-5-3 --as=system:serviceaccount:ex-5-3:controller
# Expected: yes
```

---

## Cleanup

Delete all exercise namespaces:

```bash
kubectl delete namespace ex-1-1 ex-1-2 ex-1-3 ex-2-1-dev ex-2-1-prod ex-2-3 ex-3-1 ex-3-2 ex-3-3 ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3
```

Delete the CRD:

```bash
kubectl delete crd applications.apps.example.com
```

---

## Key Takeaways

1. Custom resources support all standard kubectl operations: get, create, update, delete
2. RBAC for custom resources uses the CRD's API group (not "apps" but "apps.example.com")
3. RBAC resources field uses the plural name (applications, not application)
4. Status subresource requires separate RBAC rules for /status
5. Short names and categories improve kubectl usability
6. kubectl auth can-i tests permissions without performing operations
7. Always verify namespace when resources are not found
