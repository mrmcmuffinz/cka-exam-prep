# TLS and Certificates Tutorial: TLS Fundamentals and Certificate Creation

This tutorial covers the Kubernetes PKI structure, certificate anatomy, creating certificates with openssl, and viewing certificate details.

## Introduction

Kubernetes uses TLS (Transport Layer Security) for secure communication between all components. Every component authenticates using certificates signed by the cluster CA. Understanding certificates is essential for cluster administration, troubleshooting, and security.

## Prerequisites

- Single-node kind cluster running
- openssl installed

## Tutorial Setup

```bash
kubectl create namespace tutorial-tls
mkdir -p /tmp/tls-tutorial
cd /tmp/tls-tutorial
```

## Kubernetes PKI Overview

### Why TLS?

TLS provides:
- **Authentication:** Proves identity of communicating parties
- **Encryption:** Protects data in transit
- **Integrity:** Detects tampering

### Components Requiring Certificates

| Component | Server Cert | Client Cert |
|-----------|-------------|-------------|
| API server | Yes (for kubectl) | Yes (for etcd, kubelet) |
| etcd | Yes | Yes (peer communication) |
| kubelet | Yes (for API server) | Yes (for API server) |
| Controller manager | No | Yes (for API server) |
| Scheduler | No | Yes (for API server) |

### Certificate Chain

All certificates in the cluster are signed by the cluster CA:
```
Cluster CA (ca.crt, ca.key)
├── API server certificate
├── etcd certificates
├── kubelet certificates
├── User certificates
└── Service account signing key
```

## Certificate Anatomy

### Key Fields

**Subject:** Who the certificate belongs to
- CN (Common Name): Identity (username for client certs)
- O (Organization): Group membership

**Issuer:** Who signed the certificate

**Validity:** NotBefore, NotAfter dates

**Extensions:**
- Key Usage: What the certificate can do
- Subject Alternative Names (SANs): Additional identities

### Viewing Certificate Details

```bash
# Copy cluster CA from kind
nerdctl cp kind-control-plane:/etc/kubernetes/pki/ca.crt ./ca.crt

# View certificate
openssl x509 -in ca.crt -text -noout
```

Key sections to look for:
- Subject: `CN = kubernetes`
- Issuer: Same as subject (self-signed)
- Validity: NotBefore and NotAfter
- X509v3 extensions

## Creating Certificates with openssl

### Step 1: Generate Private Key

```bash
openssl genrsa -out alice.key 2048
```

This creates a 2048-bit RSA private key.

### Step 2: Create Certificate Signing Request (CSR)

```bash
openssl req -new -key alice.key -out alice.csr -subj "/CN=alice/O=developers"
```

- CN=alice: Username
- O=developers: Group membership

### Step 3: Sign CSR with CA

First, get the cluster CA:

```bash
nerdctl cp kind-control-plane:/etc/kubernetes/pki/ca.crt ./ca.crt
nerdctl cp kind-control-plane:/etc/kubernetes/pki/ca.key ./ca.key
```

Sign the CSR:

```bash
openssl x509 -req -in alice.csr \
  -CA ca.crt -CAkey ca.key \
  -CAcreateserial \
  -out alice.crt \
  -days 365
```

### Step 4: Verify the Certificate

```bash
openssl x509 -in alice.crt -text -noout
```

Check:
- Subject contains CN=alice
- Issuer matches CA
- Validity period is correct

### Verify Certificate Chain

```bash
openssl verify -CAfile ca.crt alice.crt
```

Should output: `alice.crt: OK`

## Adding Subject Alternative Names

Server certificates need SANs for hostnames and IPs they serve.

Create an openssl config file:

```bash
cat > san.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = myserver.example.com
DNS.2 = myserver
IP.1 = 10.0.0.1
EOF
```

Generate certificate with SANs:

```bash
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -subj "/CN=myserver" -config san.cnf
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 365 -extensions v3_req -extfile san.cnf
```

View SANs:

```bash
openssl x509 -in server.crt -text -noout | grep -A2 "Subject Alternative Name"
```

## Certificate File Locations

### Exploring the PKI Directory

```bash
nerdctl exec kind-control-plane ls -la /etc/kubernetes/pki/
```

### Key Files

| File | Purpose |
|------|---------|
| ca.crt, ca.key | Cluster CA |
| apiserver.crt, apiserver.key | API server serving certificate |
| apiserver-kubelet-client.crt | API server client cert for kubelet |
| apiserver-etcd-client.crt | API server client cert for etcd |
| front-proxy-ca.crt | CA for aggregated API servers |
| sa.key, sa.pub | Service account signing keys |
| etcd/ca.crt | etcd CA |
| etcd/server.crt | etcd serving certificate |

### Examining API Server Certificate

```bash
nerdctl exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout | head -50
```

Note the SANs including kubernetes, kubernetes.default, and IP addresses.

## Certificate Validation

### Check Expiration

```bash
nerdctl exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates
```

### Verify Against CA

```bash
nerdctl exec kind-control-plane openssl verify -CAfile /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/apiserver.crt
```

### Check Subject and Issuer

```bash
nerdctl exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -subject -issuer
```

## Tutorial Cleanup

```bash
kubectl delete namespace tutorial-tls
rm -rf /tmp/tls-tutorial
```

## Reference Commands

| Task | Command |
|------|---------|
| Generate key | `openssl genrsa -out key.pem 2048` |
| Create CSR | `openssl req -new -key key.pem -out csr.pem -subj "/CN=name"` |
| Sign CSR | `openssl x509 -req -in csr.pem -CA ca.crt -CAkey ca.key -CAcreateserial -out cert.pem` |
| View cert | `openssl x509 -in cert.pem -text -noout` |
| Check dates | `openssl x509 -in cert.pem -noout -dates` |
| Check subject | `openssl x509 -in cert.pem -noout -subject` |
| Verify chain | `openssl verify -CAfile ca.crt cert.pem` |
