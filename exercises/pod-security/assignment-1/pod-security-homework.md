# Pod Security Homework

15 progressive exercises on Pod Security Standards and Pod Security Admission. Complete `pod-security-tutorial.md` before starting. Each exercise uses its own namespace.

## Setup

```bash
kubectl get nodes
# Expected: at least one node Ready

# optional cleanup of prior attempts
for i in 1 2 3 4 5; do
  for j in 1 2 3; do
    kubectl delete namespace ex-${i}-${j} --ignore-not-found --wait=false
  done
done
```

-----

## Level 1: Basic Single-Concept Tasks

### Exercise 1.1

**Objective:** Create a namespace `ex-1-1` and label it to enforce the Baseline profile. Then apply a pod that complies with Baseline.

**Setup:**

```bash
kubectl create namespace ex-1-1
```

**Task:**

Label the namespace with `pod-security.kubernetes.io/enforce=baseline`. Create a pod named `web` using `nginx:1.25` in namespace `ex-1-1` with a simple single container that exposes port 80. The pod must be accepted and reach `Running`.

**Verification:**

```bash
# namespace is labeled
kubectl get namespace ex-1-1 -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'; echo
# Expected: baseline

# pod is Running
kubectl get pod web -n ex-1-1 -o jsonpath='{.status.phase}'; echo
# Expected: Running

# image is nginx:1.25
kubectl get pod web -n ex-1-1 -o jsonpath='{.spec.containers[0].image}'; echo
# Expected: nginx:1.25
```

-----

### Exercise 1.2

**Objective:** Create a namespace `ex-1-2` labeled to warn on Restricted, then apply a Baseline-compliant pod and observe the Restricted warnings without the pod being blocked.

**Setup:**

```bash
kubectl create namespace ex-1-2
```

**Task:**

Label the namespace with `pod-security.kubernetes.io/warn=restricted`. Apply a pod named `probe` using `nginx:1.25` with no `securityContext` (so it runs as root, allowing Baseline but failing Restricted). The pod must be created (warn does not block).

**Verification:**

```bash
# warn label present
kubectl get namespace ex-1-2 -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/warn}'; echo
# Expected: restricted

# pod exists (not blocked)
kubectl get pod probe -n ex-1-2 -o jsonpath='{.status.phase}'; echo
# Expected: Running (or Pending transiently)
```

When you applied the pod, you should have seen `Warning: would violate PodSecurity "restricted:latest": ...` lines in kubectl output. That visibility is the point of warn mode.

-----

### Exercise 1.3

**Objective:** Create a namespace `ex-1-3` labeled to enforce Restricted, and verify that a non-compliant pod is rejected.

**Setup:**

```bash
kubectl create namespace ex-1-3
```

**Task:**

Label the namespace with `pod-security.kubernetes.io/enforce=restricted`. Attempt to apply a pod named `naive` using `nginx:1.25` with no `securityContext`. The apply must fail with a PodSecurity violation message. Do not fix the pod to make it succeed; the exercise verifies the rejection path.

**Verification:**

```bash
# label present
kubectl get namespace ex-1-3 -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'; echo
# Expected: restricted

# pod does NOT exist
kubectl get pod naive -n ex-1-3 2>&1 | grep -E "NotFound|not found"
# Expected: a "not found" message confirming the pod was rejected at admission
```

-----

## Level 2: Multi-Concept Tasks

### Exercise 2.1

**Objective:** Create a namespace `ex-2-1` that enforces Baseline, audits Restricted, and warns Restricted, simultaneously.

**Setup:**

```bash
kubectl create namespace ex-2-1
```

**Task:**

Apply three labels to the namespace: `pod-security.kubernetes.io/enforce=baseline`, `pod-security.kubernetes.io/audit=restricted`, and `pod-security.kubernetes.io/warn=restricted`. No pods need to be created in this exercise; the verification checks the label set.

**Verification:**

```bash
kubectl get namespace ex-2-1 -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'; echo
# Expected: baseline
kubectl get namespace ex-2-1 -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/audit}'; echo
# Expected: restricted
kubectl get namespace ex-2-1 -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/warn}'; echo
# Expected: restricted
```

-----

### Exercise 2.2

**Objective:** Pin the enforce profile of a namespace `ex-2-2` to a specific Kubernetes version so cluster upgrades cannot silently tighten the policy.

**Setup:**

```bash
kubectl create namespace ex-2-2
```

**Task:**

Label the namespace with `pod-security.kubernetes.io/enforce=baseline` and `pod-security.kubernetes.io/enforce-version=v1.30`. Apply a Baseline-compliant pod named `anchor` using `nginx:1.25` to confirm the enforce policy works.

**Verification:**

```bash
# enforce label
kubectl get namespace ex-2-2 -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'; echo
# Expected: baseline

# version pin
kubectl get namespace ex-2-2 -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce-version}'; echo
# Expected: v1.30

# pod accepted
kubectl get pod anchor -n ex-2-2 -o jsonpath='{.status.phase}'; echo
# Expected: Running
```

-----

### Exercise 2.3

**Objective:** Create a Restricted-compliant pod named `hardened` in namespace `ex-2-3` that satisfies every Restricted requirement.

**Setup:**

```bash
kubectl create namespace ex-2-3
kubectl label namespace ex-2-3 pod-security.kubernetes.io/enforce=restricted
```

**Task:**

Apply a pod that uses `nginxinc/nginx-unprivileged:1.25` (an nginx image that runs as UID 101 by default) and sets `securityContext` fields to satisfy Restricted: `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]`, and `seccompProfile.type: RuntimeDefault`. Use pod-level `securityContext` for `runAsNonRoot` and `seccompProfile`, and container-level for `allowPrivilegeEscalation` and `capabilities`. The pod must reach `Running`.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/hardened -n ex-2-3 --timeout=60s
# Expected: pod/hardened condition met

kubectl get pod hardened -n ex-2-3 -o jsonpath='{.spec.securityContext.runAsNonRoot}'; echo
# Expected: true

kubectl get pod hardened -n ex-2-3 -o jsonpath='{.spec.containers[0].securityContext.allowPrivilegeEscalation}'; echo
# Expected: false

kubectl get pod hardened -n ex-2-3 -o jsonpath='{.spec.containers[0].securityContext.capabilities.drop[0]}'; echo
# Expected: ALL

kubectl get pod hardened -n ex-2-3 -o jsonpath='{.spec.securityContext.seccompProfile.type}'; echo
# Expected: RuntimeDefault
```

-----

## Level 3: Debugging Broken Configurations

### Exercise 3.1

**Objective:** The setup below creates a namespace with enforce=restricted and attempts to apply a pod that is rejected. Adjust the pod so it is accepted. You may not change the namespace labels.

**Setup:**

```bash
kubectl create namespace ex-3-1
kubectl label namespace ex-3-1 pod-security.kubernetes.io/enforce=restricted

# This apply will fail.
cat <<'EOF' | kubectl apply -n ex-3-1 -f - || true
apiVersion: v1
kind: Pod
metadata:
  name: broken-1
spec:
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginxinc/nginx-unprivileged:1.25
    securityContext:
      allowPrivilegeEscalation: false
EOF
```

**Task:**

Fix the pod so it is accepted. The pod must keep the name `broken-1` in namespace `ex-3-1`, keep the image `nginxinc/nginx-unprivileged:1.25`, keep the container name `app`, and keep the existing `runAsNonRoot`, `seccompProfile`, and `allowPrivilegeEscalation` fields. Add whatever else is required by Restricted.

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/broken-1 -n ex-3-1 --timeout=60s
# Expected: pod/broken-1 condition met

kubectl get pod broken-1 -n ex-3-1 -o jsonpath='{.spec.containers[0].securityContext.capabilities.drop[0]}'; echo
# Expected: ALL
```

-----

### Exercise 3.2

**Objective:** The setup below creates a Deployment in a namespace that enforces Baseline. The Deployment is accepted but no pods are created. Diagnose why and fix the Deployment so its pods are created.

**Setup:**

```bash
kubectl create namespace ex-3-2
kubectl label namespace ex-3-2 pod-security.kubernetes.io/enforce=baseline

cat <<'EOF' | kubectl apply -n ex-3-2 -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: broken-2
  template:
    metadata:
      labels:
        app: broken-2
    spec:
      hostNetwork: true
      containers:
      - name: app
        image: nginx:1.25
EOF
```

**Task:**

The Deployment's READY count stays at 0/2. Fix the Deployment's pod template so its pods can be created. The Deployment must keep the name `broken-2` in namespace `ex-3-2`, keep `replicas: 2`, keep the container name `app` and image `nginx:1.25`. You may not change the namespace labels.

**Verification:**

```bash
sleep 15
kubectl get deployment broken-2 -n ex-3-2 -o jsonpath='{.status.readyReplicas}'; echo
# Expected: 2

# hostNetwork must no longer be true
kubectl get deployment broken-2 -n ex-3-2 -o jsonpath='{.spec.template.spec.hostNetwork}'; echo
# Expected: (empty) or false
```

-----

### Exercise 3.3

**Objective:** The setup below attempts to apply a pod in a Restricted namespace. The pod is rejected with a long multi-violation message. Fix the pod so it is accepted.

**Setup:**

```bash
kubectl create namespace ex-3-3
kubectl label namespace ex-3-3 pod-security.kubernetes.io/enforce=restricted

# This apply will fail.
cat <<'EOF' | kubectl apply -n ex-3-3 -f - || true
apiVersion: v1
kind: Pod
metadata:
  name: broken-3
spec:
  containers:
  - name: worker
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
EOF
```

**Task:**

Add the pod- and container-level `securityContext` required for Restricted. The pod must keep the name `broken-3`, the container name `worker`, and the image `busybox:1.36`. You may add a `runAsUser` if needed (busybox will run as whatever UID you set).

**Verification:**

```bash
kubectl wait --for=condition=Ready pod/broken-3 -n ex-3-3 --timeout=60s
# Expected: pod/broken-3 condition met

kubectl get pod broken-3 -n ex-3-3 -o jsonpath='{.spec.securityContext.runAsNonRoot}'; echo
# Expected: true

kubectl get pod broken-3 -n ex-3-3 -o jsonpath='{.spec.containers[0].securityContext.allowPrivilegeEscalation}'; echo
# Expected: false
```

-----

## Level 4: Complex Real-World Scenarios

### Exercise 4.1

**Objective:** Set up a namespace `ex-4-1` for a production workload at Restricted with audit and warn at the next-higher (hypothetical) profile, then deploy a Restricted-compliant Deployment.

**Setup:**

```bash
kubectl create namespace ex-4-1
```

**Task:**

Apply three labels to the namespace: `pod-security.kubernetes.io/enforce=restricted`, `pod-security.kubernetes.io/audit=restricted`, `pod-security.kubernetes.io/warn=restricted`. Pin all three to version `v1.35`. Deploy a Deployment named `api` with 3 replicas using `nginxinc/nginx-unprivileged:1.25`, with full Restricted compliance in the pod template.

**Verification:**

```bash
# version pins on all three modes
kubectl get namespace ex-4-1 -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce-version}'; echo
# Expected: v1.35
kubectl get namespace ex-4-1 -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/audit-version}'; echo
# Expected: v1.35
kubectl get namespace ex-4-1 -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/warn-version}'; echo
# Expected: v1.35

# Deployment ready
kubectl get deployment api -n ex-4-1 -o jsonpath='{.status.readyReplicas}'; echo
# Expected: 3

# Restricted requirements satisfied on pod template
kubectl get deployment api -n ex-4-1 -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}'; echo
# Expected: true
kubectl get deployment api -n ex-4-1 -o jsonpath='{.spec.template.spec.containers[0].securityContext.capabilities.drop[0]}'; echo
# Expected: ALL
```

-----

### Exercise 4.2

**Objective:** Stage a migration from Baseline to Restricted for an existing workload. Namespace `ex-4-2` currently runs non-Restricted-compliant workloads; add warn-level Restricted checking without breaking anything.

**Setup:**

```bash
kubectl create namespace ex-4-2
kubectl label namespace ex-4-2 pod-security.kubernetes.io/enforce=baseline

# a non-Restricted-compliant pod (runs as root, no securityContext hardening)
cat <<'EOF' | kubectl apply -n ex-4-2 -f -
apiVersion: v1
kind: Pod
metadata:
  name: legacy
spec:
  containers:
  - name: app
    image: nginx:1.25
EOF
```

**Task:**

Add a `pod-security.kubernetes.io/warn=restricted` label to the namespace without removing or changing the enforce=baseline label. The `legacy` pod must remain Running (warn does not block). Then apply a NEW pod named `probe` using the same image and no securityContext; it too must remain Running, and its apply must emit a Warning.

**Verification:**

```bash
# both labels present
kubectl get namespace ex-4-2 -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'; echo
# Expected: baseline
kubectl get namespace ex-4-2 -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/warn}'; echo
# Expected: restricted

# both pods running
kubectl get pod legacy -n ex-4-2 -o jsonpath='{.status.phase}'; echo
# Expected: Running
kubectl get pod probe -n ex-4-2 -o jsonpath='{.status.phase}'; echo
# Expected: Running
```

-----

### Exercise 4.3

**Objective:** Build two namespaces side-by-side: `ex-4-3` at Baseline enforce and pinned to v1.30, and a clone namespace `ex-4-3-audit` at Restricted enforce without pinning. Apply the same pod to both and compare acceptance.

**Setup:**

```bash
kubectl create namespace ex-4-3
kubectl create namespace ex-4-3-audit
```

**Task:**

Label `ex-4-3` with `pod-security.kubernetes.io/enforce=baseline` and `pod-security.kubernetes.io/enforce-version=v1.30`. Label `ex-4-3-audit` with `pod-security.kubernetes.io/enforce=restricted` (no version pin).

Apply a pod named `explorer` to `ex-4-3` using `nginx:1.25` with no securityContext. It must be accepted. Attempt to apply the same pod spec (same name, same image, no securityContext) to `ex-4-3-audit`. It must be rejected.

**Verification:**

```bash
# ex-4-3 accepts
kubectl get pod explorer -n ex-4-3 -o jsonpath='{.status.phase}'; echo
# Expected: Running

# ex-4-3 version pin
kubectl get namespace ex-4-3 -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce-version}'; echo
# Expected: v1.30

# ex-4-3-audit rejects (pod does not exist)
kubectl get pod explorer -n ex-4-3-audit 2>&1 | grep -E "NotFound|not found"
# Expected: a "not found" message
```

-----

## Level 5: Advanced Debugging and Comprehensive Tasks

### Exercise 5.1

**Objective:** Build a namespace `ex-5-1` and a Deployment that together satisfy every constraint listed below simultaneously.

**Setup:**

```bash
kubectl create namespace ex-5-1
```

**Task:**

Configure the namespace with:

- `pod-security.kubernetes.io/enforce=restricted` pinned to `v1.35`
- `pod-security.kubernetes.io/audit=restricted` pinned to `latest`
- `pod-security.kubernetes.io/warn=restricted` pinned to `latest`

Create a Deployment named `secure-api` with 2 replicas using `nginxinc/nginx-unprivileged:1.25`. The pod template must:

- Set `runAsNonRoot: true` and `runAsUser: 101` at the pod level
- Set `seccompProfile.type: RuntimeDefault` at the pod level
- Set `allowPrivilegeEscalation: false` on the container
- Set `capabilities.drop: ["ALL"]` on the container
- Expose containerPort 8080

Both replicas must reach Ready.

**Verification:**

```bash
# namespace labels
for key in enforce audit warn; do
  val=$(kubectl get namespace ex-5-1 -o jsonpath="{.metadata.labels.pod-security\.kubernetes\.io/$key}")
  echo "$key=$val"
done
# Expected:
# enforce=restricted
# audit=restricted
# warn=restricted

# version pins
kubectl get namespace ex-5-1 -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce-version}'; echo
# Expected: v1.35
kubectl get namespace ex-5-1 -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/audit-version}'; echo
# Expected: latest
kubectl get namespace ex-5-1 -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/warn-version}'; echo
# Expected: latest

# Deployment ready
kubectl get deployment secure-api -n ex-5-1 -o jsonpath='{.status.readyReplicas}'; echo
# Expected: 2

# pod spec compliance
kubectl get deployment secure-api -n ex-5-1 -o jsonpath='{.spec.template.spec.securityContext.runAsUser}'; echo
# Expected: 101
```

-----

### Exercise 5.2

**Objective:** The setup below creates a namespace and a Deployment with multiple independent problems. Diagnose every problem and fix them all so the Deployment reaches 2 ready replicas.

**Setup:**

```bash
kubectl create namespace ex-5-2
kubectl label namespace ex-5-2 pod-security.kubernetes.io/enforce=restricted

cat <<'EOF' | kubectl apply -n ex-5-2 -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: multibug
spec:
  replicas: 2
  selector:
    matchLabels:
      app: multibug
  template:
    metadata:
      labels:
        app: multibug
    spec:
      hostNetwork: true
      securityContext:
        runAsUser: 0
      containers:
      - name: app
        image: nginx:1.25
        securityContext:
          privileged: true
          capabilities:
            add: ["NET_ADMIN"]
EOF
```

**Task:**

Fix every problem so that the Deployment reaches 2 ready replicas under Restricted enforcement. Keep the Deployment name `multibug`, `replicas: 2`, and the container name `app`. You may change the image if needed; `nginxinc/nginx-unprivileged:1.25` is a convenient choice because it runs as UID 101.

**Verification:**

```bash
kubectl rollout status deployment/multibug -n ex-5-2 --timeout=60s
# Expected: deployment "multibug" successfully rolled out

kubectl get deployment multibug -n ex-5-2 -o jsonpath='{.status.readyReplicas}'; echo
# Expected: 2

# confirm Restricted compliance of the pod template
kubectl get deployment multibug -n ex-5-2 -o jsonpath='{.spec.template.spec.hostNetwork}'; echo
# Expected: (empty) or false
kubectl get deployment multibug -n ex-5-2 -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}'; echo
# Expected: true
kubectl get deployment multibug -n ex-5-2 -o jsonpath='{.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}'; echo
# Expected: false
kubectl get deployment multibug -n ex-5-2 -o jsonpath='{.spec.template.spec.containers[0].securityContext.capabilities.drop[0]}'; echo
# Expected: ALL
```

-----

### Exercise 5.3

**Objective:** Diagnose why a Deployment in the setup below has 0 ready replicas even though its pod template looks correctly hardened. Fix the minimum required so it reaches 2 ready.

**Setup:**

```bash
kubectl create namespace ex-5-3
kubectl label namespace ex-5-3 pod-security.kubernetes.io/enforce=restricted

cat <<'EOF' | kubectl apply -n ex-5-3 -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: subtle
spec:
  replicas: 2
  selector:
    matchLabels:
      app: subtle
  template:
    metadata:
      labels:
        app: subtle
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 0
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: nginxinc/nginx-unprivileged:1.25
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
          seccompProfile:
            type: RuntimeDefault
EOF
```

**Task:**

Fix whatever is preventing ready pods from being created. Keep the Deployment name `subtle`, the image `nginxinc/nginx-unprivileged:1.25`, the container name `app`, and the Restricted compliance fields.

**Verification:**

```bash
kubectl rollout status deployment/subtle -n ex-5-3 --timeout=60s
# Expected: deployment "subtle" successfully rolled out

kubectl get deployment subtle -n ex-5-3 -o jsonpath='{.status.readyReplicas}'; echo
# Expected: 2
```

-----

## Cleanup

```bash
for i in 1 2 3 4 5; do
  for j in 1 2 3; do
    kubectl delete namespace ex-${i}-${j} --ignore-not-found --wait=false
  done
done
kubectl delete namespace ex-4-3-audit --ignore-not-found --wait=false
```

-----

## Key Takeaways

Pod Security Admission is a two-layer decision: the PSS profiles define the bar (Privileged, Baseline, Restricted) and the PSA modes decide what happens when a pod fails the bar (enforce rejects, audit logs, warn surfaces). Labels compose those two decisions per namespace. The full label family is six keys total: the three modes plus their `-version` pins.

Restricted is the one learners struggle with most, because it requires four specific `securityContext` settings simultaneously (`runAsNonRoot: true`, `allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]`, and `seccompProfile.type` set). The Restricted-compliant pod template in the Reference Commands section of the tutorial is worth memorizing.

The subtle failure mode is that PSA enforce only applies to Pod objects, not to the workload resources that create pods. A Deployment whose pod template violates Restricted is accepted by the API server, but its pods are rejected by the ReplicaSet controller at creation time. The symptom is `readyReplicas: 0` with a `FailedCreate` event on the ReplicaSet. Audit and warn modes catch this on the workload resource itself, which is one reason combining modes is valuable.

Move to the answer key only after genuine attempts. Level 3 and 5 answers walk through the diagnosis command sequence as well as the fix, which is the actual exam skill.
