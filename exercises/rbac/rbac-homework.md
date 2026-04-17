# RBAC Homework: 15 Progressive Exercises

These exercises build on the concepts covered in `rbac-tutorial.md`. Before starting, make sure you have completed the tutorial, or at least read the Reference Commands section at the end of it.

All exercises assume a running kind cluster:

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
kubectl config current-context   # should print kind-kind
```

Every exercise uses its own namespace (`ex-1-1`, `ex-1-2`, and so on) and its own user, so you can do them in any order and they will never collide with each other or with the tutorial. The `--as=USER` flag is used throughout for verification, which works because your admin context already has the rights to impersonate. You do not need to create real certificates for any exercise, which keeps the focus on the RBAC objects themselves.

If you want the extra realism of signed certificates and `user@kind-kind` contexts, the tutorial shows you how. For the exercises, `--as=` is faster and produces identical verification results.

## Global Setup

Run this once before starting. It creates every namespace you will need:

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 \
          ex-2-1 ex-2-2 ex-2-3 \
          ex-3-1 ex-3-2 ex-3-3 \
          ex-4-1-dev ex-4-1-prod \
          ex-4-2-frontend ex-4-2-backend ex-4-2-data \
          ex-4-3 \
          ex-5-1 \
          ex-5-2-dev ex-5-2-staging ex-5-2-prod \
          ex-5-3-db ex-5-3-api ex-5-3-web; do
  kubectl create namespace $ns
done
```

Per-exercise setup commands follow. Each exercise is self-contained: read the objective, run the setup, solve the task, then run the verification block.

---

## Level 1: Single-Concept Tasks

### Exercise 1.1

**Objective:** Give `alice` read-only access to pods in `ex-1-1`.

**Setup:**

```bash
kubectl -n ex-1-1 run webapp --image=nginx
kubectl -n ex-1-1 run cache --image=redis
```

**Task:**

Create a Role and RoleBinding so that user `alice` can `get`, `list`, and `watch` pods in `ex-1-1` but cannot modify or delete them, and has no access to any other resources or namespaces.

**Verification:**

```bash
kubectl auth can-i list pods -n ex-1-1 --as=alice         # expect: yes
kubectl auth can-i get pod/webapp -n ex-1-1 --as=alice    # expect: yes
kubectl auth can-i delete pods -n ex-1-1 --as=alice       # expect: no
kubectl auth can-i list pods -n default --as=alice        # expect: no
```

---

### Exercise 1.2

**Objective:** Give `bob` the ability to create deployments in `ex-1-2`, but nothing else.

**Setup:**

```bash
# No workloads needed; bob will be creating them.
echo "Namespace ex-1-2 is ready."
```

**Task:**

Create a Role and RoleBinding that allow `bob` to `create` deployments in `ex-1-2`. He should not be able to list, get, update, or delete them, and he should not have access to pods or any other resource.

**Verification:**

```bash
kubectl auth can-i create deployments -n ex-1-2 --as=bob    # expect: yes
kubectl auth can-i list deployments -n ex-1-2 --as=bob      # expect: no
kubectl auth can-i delete deployments -n ex-1-2 --as=bob    # expect: no
kubectl auth can-i create pods -n ex-1-2 --as=bob           # expect: no
```

---

### Exercise 1.3

**Objective:** Give `carol` read-only access to ConfigMaps in `ex-1-3`.

**Setup:**

```bash
kubectl -n ex-1-3 create configmap app-settings --from-literal=log_level=info
kubectl -n ex-1-3 create configmap db-settings --from-literal=max_conn=100
```

**Task:**

Create a Role named `cm-reader` and a RoleBinding named `carol-cm-reader` so that `carol` can `get`, `list`, and `watch` ConfigMaps in `ex-1-3`.

**Verification:**

```bash
kubectl auth can-i list configmaps -n ex-1-3 --as=carol           # expect: yes
kubectl auth can-i get cm/app-settings -n ex-1-3 --as=carol       # expect: yes
kubectl auth can-i create configmaps -n ex-1-3 --as=carol         # expect: no
```

---

## Level 2: Multi-Concept Tasks

### Exercise 2.1

**Objective:** Give `dave` full control of deployments and read-only access to pods and services in `ex-2-1`.

**Setup:**

```bash
kubectl -n ex-2-1 create deployment api --image=nginx
kubectl -n ex-2-1 expose deployment api --port=80
kubectl -n ex-2-1 run worker --image=busybox --command -- sleep 3600
```

**Task:**

Create a single Role with two rules: one granting full control (`get, list, watch, create, update, patch, delete`) over deployments, and one granting read-only access (`get, list, watch`) to pods and services. Bind it to `dave`.

**Verification:**

```bash
kubectl auth can-i create deployments -n ex-2-1 --as=dave       # expect: yes
kubectl auth can-i delete deployments -n ex-2-1 --as=dave       # expect: yes
kubectl auth can-i list pods -n ex-2-1 --as=dave                # expect: yes
kubectl auth can-i get svc/api -n ex-2-1 --as=dave              # expect: yes
kubectl auth can-i delete pods -n ex-2-1 --as=dave              # expect: no
kubectl auth can-i create services -n ex-2-1 --as=dave          # expect: no
```

---

### Exercise 2.2

**Objective:** Give `eve` full access to ConfigMaps but only read access to Secrets in `ex-2-2`.

**Setup:**

```bash
kubectl -n ex-2-2 create configmap feature-flags --from-literal=new_ui=true
kubectl -n ex-2-2 create secret generic api-key --from-literal=token=supersecret
```

**Task:**

Create a Role and RoleBinding so that `eve` can do anything with ConfigMaps (`get, list, watch, create, update, patch, delete`) but only `get, list, watch` on Secrets.

**Verification:**

```bash
kubectl auth can-i create configmaps -n ex-2-2 --as=eve     # expect: yes
kubectl auth can-i delete configmaps -n ex-2-2 --as=eve     # expect: yes
kubectl auth can-i list secrets -n ex-2-2 --as=eve          # expect: yes
kubectl auth can-i get secret/api-key -n ex-2-2 --as=eve    # expect: yes
kubectl auth can-i create secrets -n ex-2-2 --as=eve        # expect: no
kubectl auth can-i delete secrets -n ex-2-2 --as=eve        # expect: no
```

---

### Exercise 2.3

**Objective:** Give `frank` the ability to manage workloads (deployments, daemonsets, replicasets) and read pods and services in `ex-2-3`.

**Setup:**

```bash
kubectl -n ex-2-3 create deployment web --image=nginx
kubectl -n ex-2-3 expose deployment web --port=80
```

**Task:**

Create a Role named `workload-operator` that grants full control over deployments, daemonsets, and replicasets (all in the `apps` API group), and read-only access to pods and services (core API group). Bind it to `frank`.

**Verification:**

```bash
kubectl auth can-i create deployments -n ex-2-3 --as=frank        # expect: yes
kubectl auth can-i delete daemonsets -n ex-2-3 --as=frank         # expect: yes
kubectl auth can-i create replicasets -n ex-2-3 --as=frank        # expect: yes
kubectl auth can-i list pods -n ex-2-3 --as=frank                 # expect: yes
kubectl auth can-i get svc/web -n ex-2-3 --as=frank               # expect: yes
kubectl auth can-i delete pods -n ex-2-3 --as=frank               # expect: no
```

---

## Level 3: Debugging Broken Configurations

### Exercise 3.1

**Objective:** Fix the broken configuration so that `grace` can list and get deployments in `ex-3-1`.

**Setup:**

```bash
kubectl -n ex-3-1 create deployment app --image=nginx

cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployment-reader
  namespace: ex-3-1
rules:
  - apiGroups: [""]
    resources: ["deployments"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: grace-deployment-reader
  namespace: ex-3-1
subjects:
  - kind: User
    name: grace
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: deployment-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Task:**

The Role and RoleBinding above were applied but `grace` still cannot list deployments. Identify the single issue and fix it.

**Verification:**

```bash
kubectl auth can-i list deployments -n ex-3-1 --as=grace      # expect: yes
kubectl auth can-i get deployments -n ex-3-1 --as=grace       # expect: yes
kubectl auth can-i delete deployments -n ex-3-1 --as=grace    # expect: no
```

---

### Exercise 3.2

**Objective:** Fix the broken configuration so that `henry` can list pods in `ex-3-2`.

**Setup:**

```bash
kubectl -n ex-3-2 run demo --image=nginx

cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: ex-3-2
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: henry-pod-reader
  namespace: ex-3-2
subjects:
  - kind: User
    name: henry
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-viewer
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Task:**

The Role and RoleBinding above were applied with no errors, but `henry` still cannot list pods. Find and fix the single issue.

**Verification:**

```bash
kubectl auth can-i list pods -n ex-3-2 --as=henry        # expect: yes
kubectl auth can-i get pod/demo -n ex-3-2 --as=henry     # expect: yes
kubectl auth can-i delete pods -n ex-3-2 --as=henry      # expect: no
```

---

### Exercise 3.3

**Objective:** Fix the broken configuration so that `ivy` can list services in `ex-3-3`.

**Setup:**

```bash
kubectl -n ex-3-3 create deployment web --image=nginx
kubectl -n ex-3-3 expose deployment web --port=80

cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: service-reader
  namespace: ex-3-3
rules:
  - apiGroups: [""]
    resources: ["services"]
    verbs: ["read", "view"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ivy-service-reader
  namespace: ex-3-3
subjects:
  - kind: User
    name: ivy
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: service-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Task:**

`ivy` still cannot list services. Identify and fix the issue.

**Verification:**

```bash
kubectl auth can-i list services -n ex-3-3 --as=ivy           # expect: yes
kubectl auth can-i get svc/web -n ex-3-3 --as=ivy             # expect: yes
kubectl auth can-i create services -n ex-3-3 --as=ivy         # expect: no
kubectl auth can-i delete services -n ex-3-3 --as=ivy         # expect: no
```

---

## Level 4: Complex Real-World Scenarios

### Exercise 4.1

**Objective:** Give `jack` admin-level access in `ex-4-1-dev` and read-only access in `ex-4-1-prod`.

**Setup:**

```bash
kubectl -n ex-4-1-dev create deployment feature-x --image=nginx
kubectl -n ex-4-1-prod create deployment live-svc --image=nginx
kubectl -n ex-4-1-prod expose deployment live-svc --port=80
kubectl -n ex-4-1-prod create configmap prod-cfg --from-literal=env=production
```

**Task:**

In `ex-4-1-dev`, `jack` should have full control over deployments, pods, services, configmaps, and secrets. In `ex-4-1-prod`, he should only be able to read (`get, list, watch`) the same resource types. You may use one Role per namespace, or you can reuse a shared ClusterRole bound twice with different scopes. Pick whichever feels cleaner and be ready to explain the choice.

**Verification:**

```bash
kubectl auth can-i create deployments -n ex-4-1-dev --as=jack      # expect: yes
kubectl auth can-i delete pods -n ex-4-1-dev --as=jack             # expect: yes
kubectl auth can-i create secrets -n ex-4-1-dev --as=jack          # expect: yes
kubectl auth can-i list deployments -n ex-4-1-prod --as=jack       # expect: yes
kubectl auth can-i get cm/prod-cfg -n ex-4-1-prod --as=jack        # expect: yes
kubectl auth can-i list secrets -n ex-4-1-prod --as=jack           # expect: yes
kubectl auth can-i create deployments -n ex-4-1-prod --as=jack     # expect: no
kubectl auth can-i delete pods -n ex-4-1-prod --as=jack            # expect: no
kubectl auth can-i update configmaps -n ex-4-1-prod --as=jack      # expect: no
kubectl auth can-i list pods -n default --as=jack                  # expect: no
```

---

### Exercise 4.2

**Objective:** Set up team-based RBAC for a three-tier application.

**Setup:**

```bash
kubectl -n ex-4-2-frontend create deployment ui --image=nginx
kubectl -n ex-4-2-backend create deployment api --image=nginx
kubectl -n ex-4-2-data create deployment db --image=redis
kubectl -n ex-4-2-data create secret generic db-password --from-literal=pw=supersecret
```

**Task:**

Three users, three namespaces, different permission profiles:

- `kate` is on the frontend team. She needs full control of deployments, services, and configmaps in `ex-4-2-frontend`. She should have no access elsewhere.
- `liam` is on the backend team. He needs full control in `ex-4-2-backend` over the same resources as kate, plus read-only access to services in `ex-4-2-frontend` (so he can verify the frontend is reachable).
- `mia` is on the data team. She needs full control of deployments, services, configmaps, and secrets in `ex-4-2-data`. She should have no access to the frontend or backend namespaces.

**Verification:**

```bash
# kate
kubectl auth can-i create deployments -n ex-4-2-frontend --as=kate     # expect: yes
kubectl auth can-i create deployments -n ex-4-2-backend --as=kate      # expect: no
kubectl auth can-i get services -n ex-4-2-data --as=kate               # expect: no

# liam
kubectl auth can-i create deployments -n ex-4-2-backend --as=liam      # expect: yes
kubectl auth can-i delete services -n ex-4-2-backend --as=liam         # expect: yes
kubectl auth can-i list services -n ex-4-2-frontend --as=liam          # expect: yes
kubectl auth can-i create deployments -n ex-4-2-frontend --as=liam     # expect: no
kubectl auth can-i get services -n ex-4-2-data --as=liam               # expect: no

# mia
kubectl auth can-i create deployments -n ex-4-2-data --as=mia          # expect: yes
kubectl auth can-i get secret/db-password -n ex-4-2-data --as=mia      # expect: yes
kubectl auth can-i list services -n ex-4-2-frontend --as=mia           # expect: no
```

---

### Exercise 4.3

**Objective:** Use a group subject and a ServiceAccount subject in the same namespace.

**Setup:**

```bash
kubectl -n ex-4-3 create deployment app --image=nginx
kubectl -n ex-4-3 expose deployment app --port=80
kubectl -n ex-4-3 create serviceaccount ci-runner
```

**Task:**

Create RBAC so that:

- Anyone in the `auditors` group (a group, not a user) can read pods, services, and deployments in `ex-4-3`. Verify with `--as=noah --as-group=auditors`.
- The `ci-runner` ServiceAccount in `ex-4-3` can create and delete deployments, and read pods and services. This is so a CI job can deploy and check status.

**Verification:**

```bash
# Group-based: noah is a member of auditors
kubectl auth can-i list pods -n ex-4-3 --as=noah --as-group=auditors           # expect: yes
kubectl auth can-i list deployments -n ex-4-3 --as=noah --as-group=auditors    # expect: yes
kubectl auth can-i create pods -n ex-4-3 --as=noah --as-group=auditors         # expect: no

# noah is NOT in auditors
kubectl auth can-i list pods -n ex-4-3 --as=noah                                # expect: no

# ServiceAccount
kubectl auth can-i create deployments -n ex-4-3 \
  --as=system:serviceaccount:ex-4-3:ci-runner                                   # expect: yes
kubectl auth can-i delete deployments -n ex-4-3 \
  --as=system:serviceaccount:ex-4-3:ci-runner                                   # expect: yes
kubectl auth can-i list pods -n ex-4-3 \
  --as=system:serviceaccount:ex-4-3:ci-runner                                   # expect: yes
kubectl auth can-i create configmaps -n ex-4-3 \
  --as=system:serviceaccount:ex-4-3:ci-runner                                   # expect: no
```

---

## Level 5: Advanced Debugging and Comprehensive Tasks

### Exercise 5.1

**Objective:** Fix the broken configuration so that `olivia` can manage deployments and read pods in `ex-5-1`.

**Setup:**

```bash
kubectl -n ex-5-1 create deployment app --image=nginx
kubectl -n ex-5-1 run helper --image=busybox --command -- sleep 3600

cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-manager
  namespace: ex-5-1
rules:
  - apiGroups: ["apps"]
    resources: ["deployment"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["core"]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: olivia-app-manager
  namespace: ex-5-1
subjects:
  - kind: user
    name: olivia
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: app-manager
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Task:**

The configuration above has one or more problems. Find and fix whatever is needed so that `olivia` can manage deployments and read pods in `ex-5-1`.

**Verification:**

```bash
kubectl auth can-i create deployments -n ex-5-1 --as=olivia       # expect: yes
kubectl auth can-i delete deployments -n ex-5-1 --as=olivia       # expect: yes
kubectl auth can-i list deployments -n ex-5-1 --as=olivia         # expect: yes
kubectl auth can-i list pods -n ex-5-1 --as=olivia                # expect: yes
kubectl auth can-i get pod/helper -n ex-5-1 --as=olivia           # expect: yes
kubectl auth can-i delete pods -n ex-5-1 --as=olivia              # expect: no
kubectl auth can-i create pods -n ex-5-1 --as=olivia              # expect: no
kubectl auth can-i list pods -n default --as=olivia               # expect: no
```

---

### Exercise 5.2

**Objective:** Build a dev-to-staging-to-prod RBAC model where `peter` can only touch a specific named resource in production.

**Setup:**

```bash
kubectl -n ex-5-2-dev create deployment app --image=nginx
kubectl -n ex-5-2-staging create deployment app --image=nginx
kubectl -n ex-5-2-prod create deployment app --image=nginx
kubectl -n ex-5-2-prod create deployment other-team-app --image=nginx
```

**Task:**

`peter` is a release engineer. Configure RBAC so that:

- In `ex-5-2-dev`, peter has full control of deployments and pods.
- In `ex-5-2-staging`, peter has full control of deployments but read-only access to pods.
- In `ex-5-2-prod`, peter can only `get`, `list`, `watch`, `update`, and `patch` the single deployment named `app`. He must not be able to touch `other-team-app` or any other deployment, and he cannot create or delete any deployment.

The prod restriction requires the `resourceNames` field, which limits a rule to specific named objects. Note that `resourceNames` only works with verbs that target a specific object (`get, update, patch, delete`) and does not work with `create`, `list`, or `watch` in the expected way. For `list` and `watch`, you either grant them broadly on all resources of that type or not at all, so think carefully about what verbs you can scope by name and what you cannot.

**Verification:**

```bash
# dev: full control
kubectl auth can-i create deployments -n ex-5-2-dev --as=peter              # expect: yes
kubectl auth can-i delete pods -n ex-5-2-dev --as=peter                     # expect: yes

# staging: deployment admin, pod read-only
kubectl auth can-i create deployments -n ex-5-2-staging --as=peter          # expect: yes
kubectl auth can-i delete deployments -n ex-5-2-staging --as=peter          # expect: yes
kubectl auth can-i list pods -n ex-5-2-staging --as=peter                   # expect: yes
kubectl auth can-i delete pods -n ex-5-2-staging --as=peter                 # expect: no

# prod: scoped update of "app" only
kubectl auth can-i update deployment/app -n ex-5-2-prod --as=peter              # expect: yes
kubectl auth can-i patch deployment/app -n ex-5-2-prod --as=peter               # expect: yes
kubectl auth can-i get deployment/app -n ex-5-2-prod --as=peter                 # expect: yes
kubectl auth can-i update deployment/other-team-app -n ex-5-2-prod --as=peter   # expect: no
kubectl auth can-i create deployments -n ex-5-2-prod --as=peter                 # expect: no
kubectl auth can-i delete deployment/app -n ex-5-2-prod --as=peter              # expect: no
```

---

### Exercise 5.3

**Objective:** Model a realistic three-tier application with a database team, an API team, and a web team, where each team owns its own namespace but needs limited visibility into adjacent tiers.

**Setup:**

```bash
kubectl -n ex-5-3-db create deployment postgres --image=postgres:15 \
  --dry-run=client -o yaml \
  | kubectl set env --local -f - POSTGRES_PASSWORD=devpass -o yaml \
  | kubectl apply -f -
kubectl -n ex-5-3-db create secret generic db-creds --from-literal=password=devpass
kubectl -n ex-5-3-db expose deployment postgres --port=5432

kubectl -n ex-5-3-api create deployment api --image=nginx
kubectl -n ex-5-3-api create configmap api-config --from-literal=db_host=postgres.ex-5-3-db
kubectl -n ex-5-3-api expose deployment api --port=8080

kubectl -n ex-5-3-web create deployment web --image=nginx
kubectl -n ex-5-3-web create configmap web-config --from-literal=api_url=http://api.ex-5-3-api:8080
kubectl -n ex-5-3-web expose deployment web --port=80
```

**Task:**

Three users, three namespaces, carefully layered permissions. Create RBAC so that:

- `quinn` (database team): full control of deployments, services, configmaps, and secrets in `ex-5-3-db`. No access to other namespaces.
- `riley` (API team): full control of deployments, services, and configmaps in `ex-5-3-api`. Read-only access to services in `ex-5-3-db` (to verify the DB service exists). No access to db secrets or to the web namespace.
- `sam` (web team): full control of deployments, services, and configmaps in `ex-5-3-web`. Read-only access to services in `ex-5-3-api` (to verify the API is reachable). No access to any db or api resource besides the api services.

**Verification:**

```bash
# quinn
kubectl auth can-i create deployments -n ex-5-3-db --as=quinn             # expect: yes
kubectl auth can-i get secret/db-creds -n ex-5-3-db --as=quinn            # expect: yes
kubectl auth can-i delete services -n ex-5-3-db --as=quinn                # expect: yes
kubectl auth can-i list services -n ex-5-3-api --as=quinn                 # expect: no
kubectl auth can-i list services -n ex-5-3-web --as=quinn                 # expect: no

# riley
kubectl auth can-i create deployments -n ex-5-3-api --as=riley            # expect: yes
kubectl auth can-i update configmaps -n ex-5-3-api --as=riley             # expect: yes
kubectl auth can-i list services -n ex-5-3-db --as=riley                  # expect: yes
kubectl auth can-i get secret/db-creds -n ex-5-3-db --as=riley            # expect: no
kubectl auth can-i list deployments -n ex-5-3-db --as=riley               # expect: no
kubectl auth can-i list services -n ex-5-3-web --as=riley                 # expect: no

# sam
kubectl auth can-i create deployments -n ex-5-3-web --as=sam              # expect: yes
kubectl auth can-i delete configmaps -n ex-5-3-web --as=sam               # expect: yes
kubectl auth can-i list services -n ex-5-3-api --as=sam                   # expect: yes
kubectl auth can-i list deployments -n ex-5-3-api --as=sam                # expect: no
kubectl auth can-i list services -n ex-5-3-db --as=sam                    # expect: no
```

---

## Cleanup

When you finish the homework, tear everything down:

```bash
for ns in ex-1-1 ex-1-2 ex-1-3 \
          ex-2-1 ex-2-2 ex-2-3 \
          ex-3-1 ex-3-2 ex-3-3 \
          ex-4-1-dev ex-4-1-prod \
          ex-4-2-frontend ex-4-2-backend ex-4-2-data \
          ex-4-3 \
          ex-5-1 \
          ex-5-2-dev ex-5-2-staging ex-5-2-prod \
          ex-5-3-db ex-5-3-api ex-5-3-web; do
  kubectl delete namespace $ns --ignore-not-found
done
```

Deleting the namespace cascades through every Role and RoleBinding you created inside it. If you created any ClusterRoles for Exercise 4.1, delete those separately with `kubectl delete clusterrole NAME`.

---

## Key Takeaways

RBAC has only four objects (Role, RoleBinding, ClusterRole, ClusterRoleBinding), but every misconfiguration comes from the same small set of mistakes. Getting the API group right is the single most common source of silent failures, because `apiGroups: [""]` is the correct value for pods and services and that empty string looks wrong to most people on first read. Deployments, daemonsets, and replicasets live in `apps`, not in the core group, and mixing those two up is the second most common mistake.

Resource names are plural and lowercase, always. `deployments`, not `Deployment` or `deployment`. The same goes for the `kind` field in `subjects`: it is case-sensitive and must be `User`, `Group`, or `ServiceAccount` exactly. Lowercase `user` silently breaks a RoleBinding without producing any error at apply time, which is one of the reasons RBAC debugging feels so frustrating.

A RoleBinding's `roleRef` is immutable. If you need to change which role is bound, you have to delete and recreate the binding. This surprises people during the exam. The `subjects` list, by contrast, can be edited freely.

The `resourceNames` field is the main way to restrict a permission to specific named objects, and it comes with a subtle gotcha: it works with verbs that act on a single object (`get`, `update`, `patch`, `delete`) but it does not meaningfully restrict `list` or `watch`, because those verbs fetch collections. If you need a user to be able to `list` deployments and also be restricted to updating only one specific deployment, you need two rules in the same Role: one broad rule with just the list and watch verbs, and a second rule with `resourceNames` set for the destructive verbs.

The single most useful debugging command in all of RBAC is `kubectl auth can-i VERB RESOURCE -n NAMESPACE --as=USER`. Memorize it. It answers authorization questions without the noise of actually trying to perform the operation, and it works for user, group, and ServiceAccount subjects. For ServiceAccounts the subject string is `system:serviceaccount:NAMESPACE:NAME`, and for groups you add `--as-group=GROUP` alongside a `--as=` value.

When a RoleBinding does not seem to work, the three things to check in order are: does the Role actually exist with that name in that namespace, does the RoleBinding's `roleRef.name` match the Role's `metadata.name` character-for-character, and does the `subjects[].name` match the authenticated identity exactly. A common failure mode is naming the Role `pod-reader` and the `roleRef` pointing at `pod-viewer`. Kubernetes will happily apply both objects and then quietly reject every permission check because the binding points at a Role that does not exist.