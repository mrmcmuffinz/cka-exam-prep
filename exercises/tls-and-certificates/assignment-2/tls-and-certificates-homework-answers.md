# TLS and Certificates Homework Answers: Certificates API and kubeconfig

Complete solutions for all 15 exercises.

---

## Exercise 1.1 Solution

```bash
kubectl config view
```

Identifies:
- Clusters: server URLs, CA certificates
- Users: authentication methods (certs, tokens)
- Contexts: cluster+user combinations

---

## Exercise 1.2 Solution

```bash
kubectl config get-contexts
kubectl config current-context
```

The asterisk (*) marks the current context.

---

## Exercise 1.3 Solution

```bash
kubectl config view --raw | grep -E "certificate|key"
```

- `-data` suffix: Embedded (base64)
- No `-data` suffix: File path reference

---

## Exercise 2.1 Solution

```bash
cd /tmp/ex-2-1
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
```

---

## Exercise 2.2 Solution

```bash
kubectl certificate approve diana-csr
kubectl get csr diana-csr -o jsonpath='{.status.certificate}' | base64 -d > diana.crt
openssl x509 -in diana.crt -noout -subject
```

---

## Exercise 2.3 Solution

```bash
kubectl certificate deny denied-csr
kubectl get csr denied-csr
# Shows Denied condition
kubectl describe csr denied-csr
# Shows denial in conditions
```

---

## Exercise 3.1 Solution

**Issue:** base64 encoding has newlines.

**Fix:** Use `base64 -w0` to output on single line.

```bash
cat file.csr | base64 -w0
```

---

## Exercise 3.2 Solution

**Issue:** Wrong signer.

- `kubernetes.io/kubelet-serving`: For kubelet server certs
- `kubernetes.io/kube-apiserver-client`: For user client certs

**Fix:** Use `kubernetes.io/kube-apiserver-client` for user certificates.

---

## Exercise 3.3 Solution

**Issue:** CSRs require manual approval.

**Fix:**
```bash
kubectl certificate approve pending-csr
```

In production, automated approval controllers can approve certain CSRs automatically.

---

## Exercise 4.1 Solution

```bash
kubectl config set-credentials diana \
  --client-certificate=diana.crt \
  --client-key=diana.key \
  --embed-certs=true

kubectl config set-context diana@kind-kind \
  --cluster=kind-kind \
  --user=diana

kubectl config get-contexts
```

---

## Exercise 4.2 Solution

```bash
kubectl config set-credentials eric --client-certificate=eric.crt --client-key=eric.key --embed-certs=true
kubectl config set-credentials fiona --client-certificate=fiona.crt --client-key=fiona.key --embed-certs=true

kubectl config set-context eric@kind-kind --cluster=kind-kind --user=eric --namespace=ex-4-2
kubectl config set-context fiona@kind-kind --cluster=kind-kind --user=fiona --namespace=default
```

---

## Exercise 4.3 Solution

**Using KUBECONFIG:**

```bash
# Merge two config files
export KUBECONFIG=~/.kube/config:~/.kube/cluster2-config

# List all contexts from both files
kubectl config get-contexts

# Permanently merge
KUBECONFIG=~/.kube/config:~/.kube/cluster2-config kubectl config view --flatten > ~/.kube/merged-config
```

---

## Exercise 5.1 Solution

Complete workflow:

```bash
cd /tmp/ex-5-1

# 1. Generate key
openssl genrsa -out george.key 2048

# 2. Create CSR
openssl req -new -key george.key -out george.csr -subj "/CN=george/O=devs"

# 3. Submit CSR resource
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

# 4. Approve
kubectl certificate approve george-csr

# 5. Extract certificate
kubectl get csr george-csr -o jsonpath='{.status.certificate}' | base64 -d > george.crt

# 6. Configure kubeconfig
kubectl config set-credentials george --client-certificate=george.crt --client-key=george.key --embed-certs=true
kubectl config set-context george@kind-kind --cluster=kind-kind --user=george

# 7. Test (will need RBAC for actual access)
kubectl config use-context george@kind-kind
kubectl get pods  # Will fail without RBAC
kubectl config use-context kind-kind
```

---

## Exercise 5.2 Solution

```bash
kubectl config set-credentials hannah --client-certificate=hannah.crt --client-key=hannah.key --embed-certs=true
kubectl config set-credentials ian --client-certificate=ian.crt --client-key=ian.key --embed-certs=true

kubectl config set-context hannah@kind-kind --cluster=kind-kind --user=hannah --namespace=ex-5-2
kubectl config set-context ian@kind-kind --cluster=kind-kind --user=ian --namespace=default
```

---

## Exercise 5.3 Solution

**Service Account Token kubeconfig:**

```bash
# 1. Create ServiceAccount
kubectl create serviceaccount automation -n default

# 2. Create token (Kubernetes 1.24+)
TOKEN=$(kubectl create token automation -n default)

# Or get from secret (older method):
# SECRET=$(kubectl get sa automation -o jsonpath='{.secrets[0].name}')
# TOKEN=$(kubectl get secret $SECRET -o jsonpath='{.data.token}' | base64 -d)

# 3. Configure kubeconfig
kubectl config set-credentials automation --token=$TOKEN
kubectl config set-context automation@kind-kind --cluster=kind-kind --user=automation

# 4. Use
kubectl config use-context automation@kind-kind
```

---

## Common Mistakes

1. **Wrong base64 encoding:** Must use `base64 -w0` for single-line output
2. **Wrong signerName:** User certs need `kube-apiserver-client`
3. **Missing usages:** CSR spec must include appropriate usages
4. **Embedded certs without --embed-certs:** Leaves file references that may break
5. **Context pointing to wrong cluster/user:** Typos in context creation

---

## kubectl config Commands Cheat Sheet

| Task | Command |
|------|---------|
| View config | `kubectl config view` |
| View raw (with secrets) | `kubectl config view --raw` |
| List contexts | `kubectl config get-contexts` |
| Current context | `kubectl config current-context` |
| Switch context | `kubectl config use-context <name>` |
| Add credentials | `kubectl config set-credentials <name> --client-certificate=... --client-key=...` |
| Add context | `kubectl config set-context <name> --cluster=... --user=...` |
| Delete context | `kubectl config delete-context <name>` |
| Delete user | `kubectl config delete-user <name>` |
| Set namespace | `kubectl config set-context --current --namespace=<ns>` |
