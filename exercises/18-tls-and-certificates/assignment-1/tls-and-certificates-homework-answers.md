# TLS and Certificates Homework Answers: TLS Fundamentals

Complete solutions for all 15 exercises.

---

## Exercise 1.1 Solution

```bash
nerdctl exec kind-control-plane ls /etc/kubernetes/pki/
```

**Categorization:**

| Category | Files |
|----------|-------|
| Cluster CA | ca.crt, ca.key |
| API Server | apiserver.crt, apiserver.key, apiserver-kubelet-client.crt, apiserver-kubelet-client.key, apiserver-etcd-client.crt, apiserver-etcd-client.key |
| Front Proxy | front-proxy-ca.crt, front-proxy-ca.key, front-proxy-client.crt, front-proxy-client.key |
| Service Account | sa.key, sa.pub |
| etcd | etcd/ directory (separate CA and certs) |

---

## Exercise 1.2 Solution

```bash
nerdctl exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/ca.crt -noout -subject -issuer -dates
```

**Properties:**
- Subject: CN=kubernetes
- Issuer: CN=kubernetes (self-signed)
- Validity: 10 years from cluster creation (default)

---

## Exercise 1.3 Solution

```bash
nerdctl exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text | grep -A1 "Subject Alternative Name"
```

**SANs include:**
- kubernetes
- kubernetes.default
- kubernetes.default.svc
- kubernetes.default.svc.cluster.local
- <control-plane-hostname>
- <control-plane-IP>
- 10.96.0.1 (default ClusterIP)
- 127.0.0.1

---

## Exercise 2.1 Solution

```bash
cd /tmp/ex-2-1
openssl genrsa -out bob.key 2048
openssl req -new -key bob.key -out bob.csr -subj "/CN=bob/O=qa-team"
```

---

## Exercise 2.2 Solution

```bash
openssl x509 -req -in bob.csr \
  -CA ca.crt -CAkey ca.key \
  -CAcreateserial \
  -out bob.crt \
  -days 90
```

---

## Exercise 2.3 Solution

```bash
openssl verify -CAfile ca.crt bob.crt
# Output: bob.crt: OK
```

---

## Exercise 3.1 Solution

```bash
nerdctl exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/apiserver-kubelet-client.crt -noout -subject -text | head -20
```

**Answer:** This certificate is used by the API server to authenticate when connecting to kubelet (for logs, exec, port-forward). Subject shows CN=kube-apiserver-kubelet-client, O=system:masters.

---

## Exercise 3.2 Solution

```bash
nerdctl exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/etcd/server.crt -noout -issuer
# Issuer: CN = etcd-ca

nerdctl exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/etcd/ca.crt -noout -subject
# Subject: CN = etcd-ca
```

**Answer:** All etcd certificates are signed by the etcd CA, which is separate from the cluster CA.

---

## Exercise 3.3 Solution

```bash
nerdctl exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates
```

Check if NotAfter is in the future.

---

## Exercise 4.1 Solution

```bash
cat > san.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = myapp.example.com
DNS.2 = myapp
IP.1 = 10.10.10.10
EOF

openssl genrsa -out myapp.key 2048
openssl req -new -key myapp.key -out myapp.csr -subj "/CN=myapp" -config san.cnf
openssl x509 -req -in myapp.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out myapp.crt -days 365 -extensions v3_req -extfile san.cnf

# Verify SANs
openssl x509 -in myapp.crt -noout -text | grep -A3 "Subject Alternative Name"
```

---

## Exercise 4.2 Solution

**Client Authentication Certificate:**
- Key Usage: Digital Signature, Key Encipherment
- Extended Key Usage: TLS Client Authentication (clientAuth)

**Server Authentication Certificate:**
- Key Usage: Digital Signature, Key Encipherment
- Extended Key Usage: TLS Server Authentication (serverAuth)

To add these in openssl config:
```
[v3_req]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth  # or serverAuth
```

---

## Exercise 4.3 Solution

```bash
nerdctl exec kind-control-plane ls -la /etc/kubernetes/pki/sa.*
```

**Purpose:**
- **sa.key:** Private key used to sign ServiceAccount tokens (JWT)
- **sa.pub:** Public key used by API server to verify token signatures

These are used for service account token authentication, not TLS certificates.

---

## Exercise 5.1 Solution

**PKI Inventory:**

| File | Component | Purpose |
|------|-----------|---------|
| ca.crt/key | Cluster CA | Signs all certificates |
| apiserver.crt/key | API Server | Server certificate for HTTPS |
| apiserver-kubelet-client.crt/key | API Server | Client cert for kubelet |
| apiserver-etcd-client.crt/key | API Server | Client cert for etcd |
| front-proxy-ca.crt/key | Aggregation | CA for aggregated APIs |
| front-proxy-client.crt/key | API Server | Client cert for aggregated APIs |
| sa.key/pub | Controller Manager | Signs/verifies ServiceAccount tokens |
| etcd/ca.crt/key | etcd CA | Signs etcd certificates |
| etcd/server.crt/key | etcd | Server certificate |
| etcd/peer.crt/key | etcd | Peer communication |
| etcd/healthcheck-client.crt/key | etcd | Health checks |

---

## Exercise 5.2 Solution

```bash
cd /tmp/ex-5-2

# Client certificate (for connecting to API server)
openssl genrsa -out controller-client.key 2048
openssl req -new -key controller-client.key -out controller-client.csr \
  -subj "/CN=custom-controller/O=system:controllers"
openssl x509 -req -in controller-client.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out controller-client.crt -days 365

# Server certificate (for accepting connections)
cat > server.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = custom-controller.kube-system.svc
DNS.2 = custom-controller
IP.1 = 10.0.0.50
EOF

openssl genrsa -out controller-server.key 2048
openssl req -new -key controller-server.key -out controller-server.csr \
  -subj "/CN=custom-controller" -config server.cnf
openssl x509 -req -in controller-server.csr -CA ca.crt -CAkey ca.key \
  -CAcreateserial -out controller-server.crt -days 365 \
  -extensions v3_req -extfile server.cnf
```

---

## Exercise 5.3 Solution

**Certificate Lifecycle Documentation:**

1. **Checking Expiration:**
```bash
# Check all certs
kubeadm certs check-expiration

# Check specific cert
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -dates
```

2. **Certificate Rotation:**
```bash
# Renew all certificates
kubeadm certs renew all

# Renew specific certificate
kubeadm certs renew apiserver

# After renewal, restart components:
# - For static pods: kubelet restarts them automatically
# - For kubelet: systemctl restart kubelet
```

3. **When Certificates Expire:**
- API server connections fail
- kubectl returns "x509: certificate has expired"
- kubelet cannot register with API server
- etcd stops accepting connections
- Cluster effectively becomes unusable

---

## Common Mistakes

1. **Confusing CN with SAN:** CN is for subject identity, SANs for server hostnames
2. **Forgetting -CAcreateserial:** Required on first signing
3. **Wrong key usage:** Client vs server certificates need different usages
4. **Certificate signed by wrong CA:** etcd certs need etcd CA, not cluster CA
5. **Base64 encoding issues:** Certificates must be properly formatted

---

## openssl Commands Cheat Sheet

| Task | Command |
|------|---------|
| Generate key | `openssl genrsa -out key.pem 2048` |
| Create CSR | `openssl req -new -key key.pem -out csr.pem -subj "/CN=name"` |
| Sign CSR | `openssl x509 -req -in csr.pem -CA ca.crt -CAkey ca.key -CAcreateserial -out cert.pem -days 365` |
| View cert | `openssl x509 -in cert.pem -text -noout` |
| View subject | `openssl x509 -in cert.pem -noout -subject` |
| View issuer | `openssl x509 -in cert.pem -noout -issuer` |
| View dates | `openssl x509 -in cert.pem -noout -dates` |
| Verify chain | `openssl verify -CAfile ca.crt cert.pem` |
| View CSR | `openssl req -in csr.pem -text -noout` |
| Decode base64 | `base64 -d <<< "..." > cert.pem` |
