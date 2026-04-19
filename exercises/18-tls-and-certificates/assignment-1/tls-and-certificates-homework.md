# TLS and Certificates Homework: TLS Fundamentals and Certificate Creation

This homework contains 15 exercises covering TLS fundamentals and certificate operations.

---

## Level 1: Exploring Cluster Certificates

### Exercise 1.1

**Objective:** List and categorize certificates in /etc/kubernetes/pki/.

**Setup:**
```bash
kubectl create namespace ex-1-1
```

**Task:** List all certificate files in the PKI directory and categorize them by component (CA, API server, etcd, front-proxy).

**Verification:**
```bash
nerdctl exec kind-control-plane ls /etc/kubernetes/pki/ && echo "SUCCESS"
```

---

### Exercise 1.2

**Objective:** View the cluster CA certificate and identify its properties.

**Setup:**
```bash
kubectl create namespace ex-1-2
```

**Task:** Examine the cluster CA certificate. Identify the subject, issuer, and validity period.

**Verification:**
```bash
nerdctl exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/ca.crt -noout -subject -issuer -dates && echo "SUCCESS"
```

---

### Exercise 1.3

**Objective:** View the API server certificate and identify its SANs.

**Setup:**
```bash
kubectl create namespace ex-1-3
```

**Task:** Examine the API server certificate and list all Subject Alternative Names (SANs).

**Verification:**
```bash
nerdctl exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text | grep -A1 "Subject Alternative Name" && echo "SUCCESS"
```

---

## Level 2: Certificate Operations

### Exercise 2.1

**Objective:** Generate a private key and CSR for a new user.

**Setup:**
```bash
kubectl create namespace ex-2-1
mkdir -p /tmp/ex-2-1 && cd /tmp/ex-2-1
```

**Task:** Create a private key and CSR for user "bob" in group "qa-team".

**Verification:**
```bash
openssl genrsa -out bob.key 2048
openssl req -new -key bob.key -out bob.csr -subj "/CN=bob/O=qa-team"
openssl req -in bob.csr -noout -subject | grep -q "CN = bob" && echo "SUCCESS"
```

---

### Exercise 2.2

**Objective:** Sign the CSR with the cluster CA.

**Setup:**
```bash
kubectl create namespace ex-2-2
cd /tmp/ex-2-1
nerdctl cp kind-control-plane:/etc/kubernetes/pki/ca.crt ./ca.crt
nerdctl cp kind-control-plane:/etc/kubernetes/pki/ca.key ./ca.key
```

**Task:** Sign bob's CSR with the cluster CA, creating a certificate valid for 90 days.

**Verification:**
```bash
openssl x509 -req -in bob.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out bob.crt -days 90
openssl x509 -in bob.crt -noout -subject | grep -q "CN = bob" && echo "SUCCESS"
```

---

### Exercise 2.3

**Objective:** Verify the certificate chain.

**Setup:**
```bash
kubectl create namespace ex-2-3
cd /tmp/ex-2-1
```

**Task:** Verify that bob's certificate was signed by the cluster CA.

**Verification:**
```bash
openssl verify -CAfile ca.crt bob.crt && echo "SUCCESS"
```

---

## Level 3: Debugging Certificate Issues

### Exercise 3.1

**Objective:** Identify which component a certificate belongs to.

**Setup:**
```bash
kubectl create namespace ex-3-1
```

**Task:** Given the file `/etc/kubernetes/pki/apiserver-kubelet-client.crt`, determine what component uses this certificate and for what purpose.

**Verification:**
```bash
nerdctl exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/apiserver-kubelet-client.crt -noout -subject
echo "This is the API server's client certificate for authenticating to kubelet" && echo "SUCCESS"
```

---

### Exercise 3.2

**Objective:** Find a certificate with a specific issuer.

**Setup:**
```bash
kubectl create namespace ex-3-2
```

**Task:** Find a certificate in /etc/kubernetes/pki/etcd/ that is signed by the etcd CA (not the cluster CA).

**Verification:**
```bash
nerdctl exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/etcd/server.crt -noout -issuer | grep -q "etcd" && echo "SUCCESS"
```

---

### Exercise 3.3

**Objective:** Check if a certificate is expired.

**Setup:**
```bash
kubectl create namespace ex-3-3
```

**Task:** Check the expiration date of the API server certificate. Document when it expires.

**Verification:**
```bash
nerdctl exec kind-control-plane openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -enddate && echo "SUCCESS"
```

---

## Level 4: Advanced Certificate Creation

### Exercise 4.1

**Objective:** Create a certificate with specific SANs.

**Setup:**
```bash
kubectl create namespace ex-4-1
mkdir -p /tmp/ex-4-1 && cd /tmp/ex-4-1
nerdctl cp kind-control-plane:/etc/kubernetes/pki/ca.crt ./ca.crt
nerdctl cp kind-control-plane:/etc/kubernetes/pki/ca.key ./ca.key
```

**Task:** Create a server certificate with SANs for DNS names "myapp.example.com" and "myapp" and IP "10.10.10.10".

**Verification:**
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
openssl x509 -req -in myapp.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out myapp.crt -days 365 -extensions v3_req -extfile san.cnf
openssl x509 -in myapp.crt -noout -text | grep -A3 "Subject Alternative Name" && echo "SUCCESS"
```

---

### Exercise 4.2

**Objective:** Create a certificate with correct key usage extensions.

**Setup:**
```bash
kubectl create namespace ex-4-2
cd /tmp/ex-4-1
```

**Task:** Research and document the key usage extensions needed for:
1. A client authentication certificate
2. A server authentication certificate

**Verification:**
```bash
echo "Client auth needs: Digital Signature, Key Encipherment, clientAuth"
echo "Server auth needs: Digital Signature, Key Encipherment, serverAuth"
echo "SUCCESS"
```

---

### Exercise 4.3

**Objective:** Understand service account certificates.

**Setup:**
```bash
kubectl create namespace ex-4-3
```

**Task:** Examine the service account signing key pair. Document what these files are used for.

**Verification:**
```bash
nerdctl exec kind-control-plane ls -la /etc/kubernetes/pki/sa.* && echo "SUCCESS"
echo "sa.key signs service account tokens, sa.pub verifies them"
```

---

## Level 5: Complex Scenarios

### Exercise 5.1

**Objective:** Create a PKI inventory.

**Setup:**
```bash
kubectl create namespace ex-5-1
```

**Task:** Create a comprehensive inventory mapping each certificate file to its component and purpose.

**Verification:**
```bash
echo "Inventory should map all certs in /etc/kubernetes/pki/" && echo "SUCCESS"
```

---

### Exercise 5.2

**Objective:** Create certificates for a hypothetical new component.

**Setup:**
```bash
kubectl create namespace ex-5-2
mkdir -p /tmp/ex-5-2 && cd /tmp/ex-5-2
nerdctl cp kind-control-plane:/etc/kubernetes/pki/ca.crt ./ca.crt
nerdctl cp kind-control-plane:/etc/kubernetes/pki/ca.key ./ca.key
```

**Task:** Create both client and server certificates for a hypothetical "custom-controller" component that needs to:
- Connect to the API server as a client
- Accept connections from the API server as a server

**Verification:**
```bash
# Client cert
openssl genrsa -out controller-client.key 2048
openssl req -new -key controller-client.key -out controller-client.csr -subj "/CN=custom-controller/O=system:controllers"
openssl x509 -req -in controller-client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out controller-client.crt -days 365
# Server cert
openssl genrsa -out controller-server.key 2048
openssl req -new -key controller-server.key -out controller-server.csr -subj "/CN=custom-controller"
openssl x509 -req -in controller-server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out controller-server.crt -days 365
echo "Created both client and server certs" && echo "SUCCESS"
```

---

### Exercise 5.3

**Objective:** Document certificate lifecycle and rotation strategy.

**Setup:**
```bash
kubectl create namespace ex-5-3
```

**Task:** Document:
1. How to check when certificates expire
2. How certificates are rotated in Kubernetes
3. What happens when certificates expire

**Verification:**
```bash
echo "Document should cover: expiration checking, kubeadm certs renew, symptoms of expired certs" && echo "SUCCESS"
```

---

## Cleanup

```bash
kubectl delete namespace ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3
rm -rf /tmp/ex-2-1 /tmp/ex-4-1 /tmp/ex-5-2
```

---

## Key Takeaways

1. **Cluster CA** signs all component certificates
2. **CN** becomes username for client certificates
3. **O** becomes group membership
4. **SANs** required for server certificates
5. **Certificate chain** must be verifiable
6. **etcd** has its own CA separate from cluster CA
