# TLS and Certificates Tutorial: Certificate Troubleshooting

This tutorial covers diagnosing and resolving certificate-related issues in Kubernetes clusters.

## Introduction

Certificate problems cause errors like "x509: certificate has expired" or "certificate signed by unknown authority." Understanding how to diagnose these issues is essential for cluster administrators. This tutorial teaches systematic troubleshooting approaches.

## Prerequisites

- Single-node kind cluster running
- Completed 18-tls-and-certificates/assignment-1 and assignment-2

## Tutorial Setup

```bash
kubectl create namespace tutorial-tls
```

## Common Certificate Errors

### Certificate Expired

```
x509: certificate has expired or is not yet valid
```

Cause: Certificate validity period has passed.

### Unknown Authority

```
x509: certificate signed by unknown authority
```

Cause: Certificate was not signed by a trusted CA.

### Certificate Not Valid For Name

```
x509: certificate is valid for X, not Y
```

Cause: Server hostname does not match certificate SANs.

## Diagnosing Certificate Expiration

### Check Expiration Dates

```bash
# Single certificate
nerdctl exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates

# All certificates (kubeadm)
nerdctl exec kind-control-plane kubeadm certs check-expiration
```

### Before Symptoms Appear

Check certificates proactively:

```bash
# Find certificates expiring within 30 days
nerdctl exec kind-control-plane /bin/bash -c '
for cert in /etc/kubernetes/pki/*.crt; do
  echo "=== $cert ==="
  openssl x509 -in $cert -noout -enddate
done
'
```

### Expiration Symptoms

When certificates expire:
- kubectl commands fail
- API server connections rejected
- kubelet cannot communicate
- etcd becomes unreachable

## Diagnosing Subject/Issuer Mismatches

### Verify Certificate Subject

```bash
nerdctl exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -subject
```

### Verify Issuer

```bash
nerdctl exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -issuer
```

### Verify Certificate Chain

```bash
nerdctl exec kind-control-plane openssl verify -CAfile /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/apiserver.crt
```

Expected: `apiserver.crt: OK`

### SAN Verification

```bash
nerdctl exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text | grep -A1 "Subject Alternative Name"
```

## Diagnosing Wrong CA

### Symptoms

```
x509: certificate signed by unknown authority
```

### Diagnosis

Check which CA signed the certificate:

```bash
# Certificate issuer
openssl x509 -in cert.crt -noout -issuer

# CA subject
openssl x509 -in ca.crt -noout -subject
```

Issuer should match CA subject.

### Verification

```bash
openssl verify -CAfile expected-ca.crt cert.crt
# Should output: cert.crt: OK
```

If verification fails, certificate was signed by different CA.

## Certificate Permission Issues

### Symptoms

- Component fails to start
- "permission denied" in logs

### Diagnosis

```bash
nerdctl exec kind-control-plane ls -la /etc/kubernetes/pki/
```

Key files should be readable by the component running them:
- Certificate files (.crt): Usually 644
- Key files (.key): Usually 600

### Fix

```bash
# Fix permissions (example)
chmod 600 /etc/kubernetes/pki/apiserver.key
chmod 644 /etc/kubernetes/pki/apiserver.crt
```

## Certificate Renewal

### kubeadm Certificate Renewal

```bash
# Check expiration
kubeadm certs check-expiration

# Renew all certificates
kubeadm certs renew all

# Renew specific certificate
kubeadm certs renew apiserver
```

### After Renewal

Control plane components must be restarted:

```bash
# For static pods, move and restore manifests
mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/
sleep 5
mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/
```

Or restart kubelet:

```bash
systemctl restart kubelet
```

### User Certificate Renewal

For user certificates:

1. Generate new CSR
2. Submit via Certificates API
3. Approve
4. Extract new certificate
5. Update kubeconfig

## Troubleshooting Workflow

### Step 1: Identify the Error

Look for certificate errors in:
- kubectl output
- Component logs
- API server logs

### Step 2: Identify the Certificate

Determine which certificate is problematic:
- API server certificate (for kubectl)
- kubelet certificate (for API server to kubelet)
- etcd certificate (for etcd communication)

### Step 3: Check Certificate Properties

```bash
openssl x509 -in cert.crt -noout -dates -subject -issuer
```

### Step 4: Verify Certificate Chain

```bash
openssl verify -CAfile ca.crt cert.crt
```

### Step 5: Fix or Renew

- Expired: Renew with kubeadm
- Wrong CA: Regenerate with correct CA
- Wrong SAN: Regenerate with correct SANs

## Tutorial Cleanup

```bash
kubectl delete namespace tutorial-tls
```

## Reference Commands

| Task | Command |
|------|---------|
| Check expiration | `openssl x509 -in cert.crt -noout -dates` |
| Check subject | `openssl x509 -in cert.crt -noout -subject` |
| Check issuer | `openssl x509 -in cert.crt -noout -issuer` |
| Check SANs | `openssl x509 -in cert.crt -noout -text \| grep -A1 "Subject Alternative"` |
| Verify chain | `openssl verify -CAfile ca.crt cert.crt` |
| Check all (kubeadm) | `kubeadm certs check-expiration` |
| Renew all | `kubeadm certs renew all` |
| Renew specific | `kubeadm certs renew <component>` |
