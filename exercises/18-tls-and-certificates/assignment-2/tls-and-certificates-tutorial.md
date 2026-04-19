# TLS and Certificates Tutorial: Certificates API and kubeconfig

This tutorial covers the Kubernetes Certificates API for automated CSR workflows and kubeconfig file structure and management.

## Introduction

The Certificates API provides a Kubernetes-native way to request and approve certificates. Instead of manually signing CSRs with the CA, you submit a CertificateSigningRequest resource and an administrator approves it. This enables automated certificate management and audit trails.

## Prerequisites

- Single-node kind cluster running
- Completed tls-and-certificates/assignment-1

## Tutorial Setup

```bash
kubectl create namespace tutorial-tls
mkdir -p /tmp/tls-tutorial && cd /tmp/tls-tutorial
```

## CertificateSigningRequest Resource

### Creating a CSR

First, generate a key and CSR:

```bash
openssl genrsa -out charlie.key 2048
openssl req -new -key charlie.key -out charlie.csr -subj "/CN=charlie/O=developers"
```

### Creating the CSR Resource

The CSR must be base64-encoded in the resource:

```bash
CSR_BASE64=$(cat charlie.csr | base64 -w0)

cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: charlie-csr
spec:
  request: ${CSR_BASE64}
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
  - digital signature
  - key encipherment
EOF
```

### CSR Spec Fields

| Field | Description |
|-------|-------------|
| request | Base64-encoded PEM CSR |
| signerName | Which signer to use |
| usages | Certificate usages |

### Common Signer Names

| Signer | Purpose |
|--------|---------|
| kubernetes.io/kube-apiserver-client | User certificates |
| kubernetes.io/kube-apiserver-client-kubelet | Kubelet client certs |
| kubernetes.io/kubelet-serving | Kubelet serving certs |

### CSR Lifecycle

```bash
# List CSRs
kubectl get csr

# View details
kubectl describe csr charlie-csr
```

States:
- **Pending:** Awaiting approval
- **Approved:** Certificate issued
- **Denied:** Request rejected

## Approving and Denying CSRs

### Approve

```bash
kubectl certificate approve charlie-csr
```

### Deny

```bash
kubectl certificate deny charlie-csr
```

### Extract Signed Certificate

```bash
kubectl get csr charlie-csr -o jsonpath='{.status.certificate}' | base64 -d > charlie.crt
```

### Verify

```bash
openssl x509 -in charlie.crt -noout -subject
```

## kubeconfig Structure

kubeconfig files define how kubectl connects to clusters.

### Default Location

```bash
cat ~/.kube/config
```

Or via KUBECONFIG environment variable.

### Three Sections

**clusters:** Cluster connection information
```yaml
clusters:
- name: kind-kind
  cluster:
    server: https://127.0.0.1:6443
    certificate-authority-data: <base64 CA cert>
```

**users:** Authentication credentials
```yaml
users:
- name: charlie
  user:
    client-certificate-data: <base64 cert>
    client-key-data: <base64 key>
```

**contexts:** Combine cluster + user + optional namespace
```yaml
contexts:
- name: charlie@kind-kind
  context:
    cluster: kind-kind
    user: charlie
    namespace: default
```

### Current Context

```yaml
current-context: kind-kind
```

## Creating kubeconfig Entries

### Add User

```bash
kubectl config set-credentials charlie \
  --client-certificate=charlie.crt \
  --client-key=charlie.key \
  --embed-certs=true
```

### Add Context

```bash
kubectl config set-context charlie@kind-kind \
  --cluster=kind-kind \
  --user=charlie \
  --namespace=default
```

### Switch Context

```bash
kubectl config use-context charlie@kind-kind
```

### Test

```bash
kubectl get pods
# Will fail without RBAC permissions
```

### Switch Back

```bash
kubectl config use-context kind-kind
```

## Context Management

### List Contexts

```bash
kubectl config get-contexts
```

### Current Context

```bash
kubectl config current-context
```

### View Config

```bash
kubectl config view
```

### Delete Context

```bash
kubectl config delete-context charlie@kind-kind
```

### Delete User

```bash
kubectl config delete-user charlie
```

## Complete User Onboarding

Here is the complete workflow:

```bash
# 1. Generate key and CSR
openssl genrsa -out user.key 2048
openssl req -new -key user.key -out user.csr -subj "/CN=user/O=group"

# 2. Create CSR resource
CSR_BASE64=$(cat user.csr | base64 -w0)
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: user-csr
spec:
  request: ${CSR_BASE64}
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF

# 3. Approve CSR
kubectl certificate approve user-csr

# 4. Extract certificate
kubectl get csr user-csr -o jsonpath='{.status.certificate}' | base64 -d > user.crt

# 5. Configure kubeconfig
kubectl config set-credentials user --client-certificate=user.crt --client-key=user.key --embed-certs=true
kubectl config set-context user@kind-kind --cluster=kind-kind --user=user

# 6. Test (needs RBAC)
kubectl config use-context user@kind-kind
kubectl get pods
kubectl config use-context kind-kind
```

## Tutorial Cleanup

```bash
kubectl delete csr charlie-csr 2>/dev/null
kubectl config delete-context charlie@kind-kind 2>/dev/null
kubectl config delete-user charlie 2>/dev/null
kubectl delete namespace tutorial-tls
rm -rf /tmp/tls-tutorial
```

## Reference Commands

| Task | Command |
|------|---------|
| Create CSR resource | `kubectl apply -f csr.yaml` |
| List CSRs | `kubectl get csr` |
| Approve CSR | `kubectl certificate approve <name>` |
| Deny CSR | `kubectl certificate deny <name>` |
| Extract cert | `kubectl get csr <name> -o jsonpath='{.status.certificate}' \| base64 -d` |
| Add user | `kubectl config set-credentials <name> --client-certificate=... --client-key=...` |
| Add context | `kubectl config set-context <name> --cluster=... --user=...` |
| Switch context | `kubectl config use-context <name>` |
| View config | `kubectl config view` |
| List contexts | `kubectl config get-contexts` |
