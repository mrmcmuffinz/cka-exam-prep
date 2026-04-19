# TLS and Certificates Homework: Certificates API and kubeconfig

This homework contains 15 exercises covering the Certificates API and kubeconfig management.

---

## Level 1: kubeconfig Exploration

### Exercise 1.1

**Objective:** View and interpret the default kubeconfig structure.

**Setup:**
```bash
kubectl create namespace ex-1-1
```

**Task:** View your kubeconfig and identify the clusters, users, and contexts defined.

**Verification:**
```bash
kubectl config view && echo "SUCCESS"
```

---

### Exercise 1.2

**Objective:** List and describe contexts.

**Setup:**
```bash
kubectl create namespace ex-1-2
```

**Task:** List all contexts and identify which one is current.

**Verification:**
```bash
kubectl config get-contexts && echo "SUCCESS"
kubectl config current-context && echo "SUCCESS"
```

---

### Exercise 1.3

**Objective:** Identify embedded vs file-referenced certificates.

**Setup:**
```bash
kubectl create namespace ex-1-3
```

**Task:** Examine your kubeconfig and determine whether certificates are embedded (as -data fields) or referenced as files.

**Verification:**
```bash
kubectl config view --raw | grep -E "certificate-authority-data|certificate-authority:" && echo "SUCCESS"
```

---

## Level 2: CSR Workflow

### Exercise 2.1

**Objective:** Create a CSR for a new user using the Certificates API.

**Setup:**
```bash
kubectl create namespace ex-2-1
mkdir -p /tmp/ex-2-1 && cd /tmp/ex-2-1
```

**Task:** Create a CSR for user "diana" in group "testers" and submit it as a CertificateSigningRequest resource.

**Verification:**
```bash
openssl genrsa -out diana.key 2048
openssl req -new -key diana.key -out diana.csr -subj "/CN=diana/O=testers"
CSR_BASE64=$(cat diana.csr | base64 -w0)
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: diana-csr
spec:
  request: ${CSR_BASE64}
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF
kubectl get csr diana-csr && echo "SUCCESS"
```

---

### Exercise 2.2

**Objective:** Approve the CSR and extract the signed certificate.

**Setup:**
```bash
kubectl create namespace ex-2-2
cd /tmp/ex-2-1
```

**Task:** Approve diana's CSR and extract the signed certificate.

**Verification:**
```bash
kubectl certificate approve diana-csr
kubectl get csr diana-csr -o jsonpath='{.status.certificate}' | base64 -d > diana.crt
openssl x509 -in diana.crt -noout -subject | grep -q "diana" && echo "SUCCESS"
```

---

### Exercise 2.3

**Objective:** Deny a CSR and observe the result.

**Setup:**
```bash
kubectl create namespace ex-2-3
mkdir -p /tmp/ex-2-3 && cd /tmp/ex-2-3
openssl genrsa -out denied.key 2048
openssl req -new -key denied.key -out denied.csr -subj "/CN=denied-user"
CSR_BASE64=$(cat denied.csr | base64 -w0)
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: denied-csr
spec:
  request: ${CSR_BASE64}
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF
```

**Task:** Deny the CSR and observe the status.

**Verification:**
```bash
kubectl certificate deny denied-csr
kubectl get csr denied-csr | grep -q "Denied" && echo "SUCCESS"
```

---

## Level 3: Debugging CSR Issues

### Exercise 3.1

**Objective:** Fix a CSR with wrong encoding.

**Setup:**
```bash
kubectl create namespace ex-3-1
```

**Task:** The following CSR resource has an encoding issue. Identify and document the problem:
```yaml
spec:
  request: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURSBSRVFVRVNULS0tLS0K...
            (newlines in the base64)
```

**Verification:**
```bash
echo "Issue: base64 must be on single line, use base64 -w0" && echo "SUCCESS"
```

---

### Exercise 3.2

**Objective:** Fix a CSR with wrong signerName.

**Setup:**
```bash
kubectl create namespace ex-3-2
```

**Task:** A CSR uses signerName "kubernetes.io/kubelet-serving" but is for a user certificate. What is wrong?

**Verification:**
```bash
echo "Issue: User certs need kubernetes.io/kube-apiserver-client signer" && echo "SUCCESS"
```

---

### Exercise 3.3

**Objective:** Diagnose a CSR stuck in Pending.

**Setup:**
```bash
kubectl create namespace ex-3-3
mkdir -p /tmp/ex-3-3 && cd /tmp/ex-3-3
openssl genrsa -out pending.key 2048
openssl req -new -key pending.key -out pending.csr -subj "/CN=pending-user"
CSR_BASE64=$(cat pending.csr | base64 -w0)
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: pending-csr
spec:
  request: ${CSR_BASE64}
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF
```

**Task:** The CSR is Pending. What needs to happen for it to be approved?

**Verification:**
```bash
kubectl get csr pending-csr | grep "Pending" && echo "SUCCESS"
echo "CSRs require manual approval: kubectl certificate approve pending-csr"
```

---

## Level 4: kubeconfig Management

### Exercise 4.1

**Objective:** Create a complete kubeconfig for a new user.

**Setup:**
```bash
kubectl create namespace ex-4-1
cd /tmp/ex-2-1
```

**Task:** Using diana's certificate from Exercise 2.2, create kubeconfig entries (user and context).

**Verification:**
```bash
kubectl config set-credentials diana --client-certificate=diana.crt --client-key=diana.key --embed-certs=true
kubectl config set-context diana@kind-kind --cluster=kind-kind --user=diana
kubectl config get-contexts | grep -q "diana" && echo "SUCCESS"
```

---

### Exercise 4.2

**Objective:** Configure multiple contexts in a single kubeconfig.

**Setup:**
```bash
kubectl create namespace ex-4-2
mkdir -p /tmp/ex-4-2 && cd /tmp/ex-4-2
```

**Task:** Create credentials for users "eric" and "fiona" and create contexts for each with different default namespaces.

**Verification:**
```bash
# Create minimal certs (won't work for auth but demonstrates config)
openssl genrsa -out eric.key 2048 && openssl req -new -x509 -key eric.key -out eric.crt -subj "/CN=eric"
openssl genrsa -out fiona.key 2048 && openssl req -new -x509 -key fiona.key -out fiona.crt -subj "/CN=fiona"
kubectl config set-credentials eric --client-certificate=eric.crt --client-key=eric.key --embed-certs=true
kubectl config set-credentials fiona --client-certificate=fiona.crt --client-key=fiona.key --embed-certs=true
kubectl config set-context eric@kind-kind --cluster=kind-kind --user=eric --namespace=ex-4-2
kubectl config set-context fiona@kind-kind --cluster=kind-kind --user=fiona --namespace=default
kubectl config get-contexts | grep -q "eric" && kubectl config get-contexts | grep -q "fiona" && echo "SUCCESS"
```

---

### Exercise 4.3

**Objective:** Use KUBECONFIG environment variable for multiple files.

**Setup:**
```bash
kubectl create namespace ex-4-3
```

**Task:** Document how to use KUBECONFIG to merge multiple kubeconfig files.

**Verification:**
```bash
echo "KUBECONFIG=~/.kube/config:~/.kube/other-config kubectl config get-contexts"
echo "Merges contexts from both files" && echo "SUCCESS"
```

---

## Level 5: Complex Scenarios

### Exercise 5.1

**Objective:** Complete user onboarding workflow.

**Setup:**
```bash
kubectl create namespace ex-5-1
mkdir -p /tmp/ex-5-1 && cd /tmp/ex-5-1
```

**Task:** Complete the full user onboarding for "george": generate key, create CSR resource, approve, extract cert, configure kubeconfig.

**Verification:**
```bash
# Full workflow
openssl genrsa -out george.key 2048
openssl req -new -key george.key -out george.csr -subj "/CN=george/O=devs"
CSR_BASE64=$(cat george.csr | base64 -w0)
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: george-csr
spec:
  request: ${CSR_BASE64}
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF
kubectl certificate approve george-csr
kubectl get csr george-csr -o jsonpath='{.status.certificate}' | base64 -d > george.crt
kubectl config set-credentials george --client-certificate=george.crt --client-key=george.key --embed-certs=true
kubectl config set-context george@kind-kind --cluster=kind-kind --user=george
echo "SUCCESS"
```

---

### Exercise 5.2

**Objective:** Set up multiple users with different contexts.

**Setup:**
```bash
kubectl create namespace ex-5-2
```

**Task:** Create contexts for "hannah" (namespace ex-5-2) and "ian" (namespace default) using the existing cluster.

**Verification:**
```bash
# Quick setup with self-signed (non-functional but demonstrates config)
mkdir -p /tmp/ex-5-2 && cd /tmp/ex-5-2
openssl genrsa -out hannah.key 2048 && openssl req -new -x509 -key hannah.key -out hannah.crt -subj "/CN=hannah"
openssl genrsa -out ian.key 2048 && openssl req -new -x509 -key ian.key -out ian.crt -subj "/CN=ian"
kubectl config set-credentials hannah --client-certificate=hannah.crt --client-key=hannah.key --embed-certs=true
kubectl config set-credentials ian --client-certificate=ian.crt --client-key=ian.key --embed-certs=true
kubectl config set-context hannah@kind-kind --cluster=kind-kind --user=hannah --namespace=ex-5-2
kubectl config set-context ian@kind-kind --cluster=kind-kind --user=ian --namespace=default
kubectl config get-contexts | grep -E "hannah|ian" && echo "SUCCESS"
```

---

### Exercise 5.3

**Objective:** Document service account token-based kubeconfig (alternative to certificates).

**Setup:**
```bash
kubectl create namespace ex-5-3
```

**Task:** Document how to create a kubeconfig using a ServiceAccount token instead of certificates.

**Verification:**
```bash
echo "Steps: 1) Create ServiceAccount, 2) Get token from secret, 3) Use token in kubeconfig"
echo "kubectl config set-credentials sa-user --token=\$TOKEN" && echo "SUCCESS"
```

---

## Cleanup

```bash
kubectl delete namespace ex-1-1 ex-1-2 ex-1-3 ex-2-1 ex-2-2 ex-2-3 ex-3-1 ex-3-2 ex-3-3 ex-4-1 ex-4-2 ex-4-3 ex-5-1 ex-5-2 ex-5-3
kubectl delete csr diana-csr denied-csr pending-csr george-csr 2>/dev/null
kubectl config delete-context diana@kind-kind eric@kind-kind fiona@kind-kind george@kind-kind hannah@kind-kind ian@kind-kind 2>/dev/null
kubectl config delete-user diana eric fiona george hannah ian 2>/dev/null
rm -rf /tmp/ex-2-1 /tmp/ex-2-3 /tmp/ex-3-3 /tmp/ex-4-2 /tmp/ex-5-1 /tmp/ex-5-2
```

---

## Key Takeaways

1. **CertificateSigningRequest** resources automate certificate issuance
2. **base64 -w0** is essential for encoding CSRs
3. **signerName** must match the certificate purpose
4. **kubeconfig** has three sections: clusters, users, contexts
5. **kubectl config** commands manage kubeconfig entries
6. **KUBECONFIG** env var can merge multiple files
