# Bootstrapping Kubernetes Security (Single Node)

**Based on:** [kubernetes-the-harder-way/04_Bootstrapping_Kubernetes_Security.md](https://github.com/ghik/kubernetes-the-harder-way/blob/linux/docs/04_Bootstrapping_Kubernetes_Security.md)

**Simplified for:** A single-node cluster where one VM runs all control plane components (etcd, kube-apiserver, kube-scheduler, kube-controller-manager) and all worker components (kubelet, kube-proxy) together.

---

## What This Chapter Does

Before installing any Kubernetes components, you need to set up the security layer. Kubernetes components communicate over TLS with mutual certificate authentication, meaning both the server and the client present certificates signed by a trusted Certificate Authority (CA). This chapter generates all the certificates, keys, and kubeconfig files needed for a single-node cluster.

## Kubernetes Components and How They Talk

On your single node, the following components will run:

**Control plane:**
- `etcd` stores all cluster state
- `kube-apiserver` is the API frontend everything talks to
- `kube-scheduler` assigns pods to nodes
- `kube-controller-manager` runs reconciliation loops

**Worker (same node):**
- `kubelet` manages pod lifecycle
- `kube-proxy` handles service networking

**Communication pattern:** Nearly everything is a client of `kube-apiserver`. The API server is a client of `etcd` and occasionally calls back to `kubelet` (for logs, port-forwarding). External users reach the API server via `kubectl`.

Every one of these communication channels uses TLS with certificates signed by a single root CA.

## Certificates Needed (Single Node)

The multi-node guide generates certificates for 3 control nodes, 3 workers, and a load balancer. For a single node, the list collapses to:

1. **Root CA** - signs everything
2. **Kubernetes API certificate** - used by kube-apiserver as its server cert, also reused as the client cert for talking to etcd and kubelet
3. **admin user certificate** - for your kubectl access from outside the VM
4. **node1 certificate** - used by kubelet as both its server cert and its client cert to the API server
5. **kube-scheduler certificate** - client cert for scheduler to API server
6. **kube-controller-manager certificate** - client cert for controller-manager to API server
7. **kube-proxy certificate** - client cert for kube-proxy to API server
8. **service-account certificate** - used to sign and verify ServiceAccount JWT tokens

Each client certificate encodes an identity (user + group) in its CN and O fields. Kubernetes RBAC uses these identities to determine permissions. The "magic" names like `system:kube-scheduler` and `system:nodes` map to pre-configured RBAC bindings that Kubernetes expects.

## Prerequisites

All certificate and kubeconfig generation happens inside the VM. SSH into the VM before proceeding.

Install `cfssl` and `cfssljson` for certificate generation:

```bash
sudo apt install -y golang-cfssl
```

Verify:

```bash
cfssl version
cfssljson --help
```

Install `kubectl` for generating kubeconfig files. The `kubectl config set-*` commands used later in this chapter are purely local file operations and do not require a running cluster.

```bash
k8s_version=1.35.3
wget -q --show-progress --https-only --timestamping \
  "https://dl.k8s.io/release/v${k8s_version}/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

## Generating the Certificates

Create a working directory for all security artifacts:

```bash
mkdir -p ~/auth && cd ~/auth
```

### 1. Root Certificate Authority

Create `ca-csr.json`:

```json
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Austin",
      "O": "Kubernetes",
      "OU": "CKA Lab",
      "ST": "Texas"
    }
  ]
}
```

Generate the CA:

```bash
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```

This produces `ca.pem` (certificate) and `ca-key.pem` (private key). The `.csr` file can be ignored.

### 2. CA Configuration File

Create `ca-config.json` to define signing options used for all subsequent certificates:

```json
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "87600h"
      }
    }
  }
}
```

The expiry is set to 10 years. The `kubernetes` profile enables both server and client authentication, so a single certificate can serve both roles where needed.

### 3. Kubernetes API Server Certificate

This is the most important certificate. It must include every hostname and IP that could be used to reach the API server, both from outside the cluster and from within it. For the single-node QEMU setup, the SAN list includes:

- `kubernetes.default.*` names used by pods inside the cluster
- `10.96.0.1` is the Kubernetes API ClusterIP (the first IP in the service CIDR, which defaults to `10.96.0.0/12` with kubeadm, but we will use `10.96.0.0/16` for simplicity)
- `node1` and its FQDN
- The VM's internal IP (assigned by QEMU DHCP, typically `10.0.2.15` for user-mode networking)
- `127.0.0.1` for localhost access within the VM

Create `kubernetes-csr.json`:

```json
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Austin",
      "O": "Kubernetes",
      "OU": "CKA Lab",
      "ST": "Texas"
    }
  ],
  "hosts": [
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local",
    "10.96.0.1",
    "node1",
    "10.0.2.15",
    "127.0.0.1"
  ]
}
```

**Note:** If your VM gets a different IP than `10.0.2.15`, update it here. You can check after booting the VM with `ip addr show` inside the guest. QEMU user-mode networking typically assigns `10.0.2.15`.

Generate the certificate:

```bash
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
```

### 4. Admin User Certificate

The admin certificate uses the `system:masters` group (the O field), which is a built-in RBAC group with unrestricted cluster access.

Create `admin-csr.json`:

```json
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Austin",
      "O": "system:masters",
      "OU": "CKA Lab",
      "ST": "Texas"
    }
  ]
}
```

Generate:

```bash
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin
```

### 5. Node Certificate (node1)

The kubelet on `node1` authenticates to the API server as `system:node:node1` (CN) in the `system:nodes` group (O). These are magic names recognized by the Kubernetes Node authorization mode.

Create `node1-csr.json`:

```json
{
  "CN": "system:node:node1",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Austin",
      "O": "system:nodes",
      "OU": "CKA Lab",
      "ST": "Texas"
    }
  ],
  "hosts": [
    "node1",
    "10.0.2.15",
    "127.0.0.1"
  ]
}
```

Generate:

```bash
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  node1-csr.json | cfssljson -bare node1
```

### 6. kube-scheduler Certificate

Create `kube-scheduler-csr.json`:

```json
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Austin",
      "O": "system:kube-scheduler",
      "OU": "CKA Lab",
      "ST": "Texas"
    }
  ]
}
```

Generate:

```bash
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler
```

### 7. kube-controller-manager Certificate

Create `kube-controller-manager-csr.json`:

```json
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Austin",
      "O": "system:kube-controller-manager",
      "OU": "CKA Lab",
      "ST": "Texas"
    }
  ]
}
```

Generate:

```bash
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
```

### 8. kube-proxy Certificate

Create `kube-proxy-csr.json`:

```json
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Austin",
      "O": "system:node-proxier",
      "OU": "CKA Lab",
      "ST": "Texas"
    }
  ]
}
```

Generate:

```bash
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy
```

### 9. Service Account Token Signing Certificate

This certificate is not used for TLS communication. Its key pair is used by the controller-manager to sign ServiceAccount JWT tokens and by the API server to verify them.

Create `service-account-csr.json`:

```json
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Austin",
      "O": "Kubernetes",
      "OU": "CKA Lab",
      "ST": "Texas"
    }
  ]
}
```

Generate:

```bash
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account
```

## Generating Kubeconfigs

Every Kubernetes API client needs a kubeconfig file bundling three things: the CA certificate, the client certificate, and the client private key. Since this is a single-node setup, the API server is reachable at `https://127.0.0.1:6443` from inside the VM.

Run these commands from the `~/auth` directory:

```bash
# Helper function
genkubeconfig() {
  cert=$1
  user=$2
  kubeconfig="${cert}.kubeconfig"

  kubectl config set-cluster cka-lab \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig="$kubeconfig"

  kubectl config set-credentials "$user" \
    --client-certificate="${cert}.pem" \
    --client-key="${cert}-key.pem" \
    --embed-certs=true \
    --kubeconfig="$kubeconfig"

  kubectl config set-context default \
    --cluster=cka-lab \
    --user="$user" \
    --kubeconfig="$kubeconfig"

  kubectl config use-context default \
    --kubeconfig="$kubeconfig"
}

# Generate kubeconfigs
genkubeconfig admin admin
genkubeconfig node1 system:node:node1
genkubeconfig kube-scheduler system:kube-scheduler
genkubeconfig kube-controller-manager system:kube-controller-manager
genkubeconfig kube-proxy system:kube-proxy
```

This produces five `.kubeconfig` files in the auth directory.

## Generating the Encryption Key

The API server can encrypt sensitive data (like Secrets) at rest in etcd. This requires a symmetric encryption key wrapped in a YAML config file.

```bash
key=$(head -c 32 /dev/urandom | base64)

cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: $key
      - identity: {}
EOF
```

## File Location

Since all certificate generation was done inside the VM, the files are already where they need to be: in `~/auth/`. No file distribution step is necessary.

The subsequent chapters will copy individual files from `~/auth/` into the appropriate system directories (e.g., `/etc/etcd/`, `/var/lib/kubernetes/`, `/var/lib/kubelet/`) when each component is installed.

## Optional: Host-Side kubectl Access

If you want to run `kubectl` from the QEMU host (outside the VM) through the port-forwarded 6443, you can copy the admin kubeconfig out of the VM and configure it on the host. This is not required for the cluster setup but is convenient for day-to-day use.

From the QEMU host:

```bash
# Install kubectl on the host if not already present
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Copy the admin kubeconfig from the VM
scp -P 2222 kube@127.0.0.1:~/auth/admin.kubeconfig ~/.kube/cka-lab-config

# Use it
KUBECONFIG=~/.kube/cka-lab-config kubectl get nodes
```

The kubeconfig's server field is already set to `https://127.0.0.1:6443`, which matches the port-forwarded API server.

## Summary of Generated Files

After completing this chapter, your `~/auth/` directory contains:

| File | Purpose |
|------|---------|
| `ca.pem`, `ca-key.pem` | Root CA certificate and key |
| `kubernetes.pem`, `kubernetes-key.pem` | API server cert (also used for etcd and kubelet communication) |
| `admin.pem`, `admin-key.pem` | Admin user client cert |
| `node1.pem`, `node1-key.pem` | Kubelet server/client cert |
| `kube-scheduler.pem`, `kube-scheduler-key.pem` | Scheduler client cert |
| `kube-controller-manager.pem`, `kube-controller-manager-key.pem` | Controller-manager client cert |
| `kube-proxy.pem`, `kube-proxy-key.pem` | kube-proxy client cert |
| `service-account.pem`, `service-account-key.pem` | ServiceAccount token signing key pair |
| `admin.kubeconfig` | Kubeconfig for admin user |
| `node1.kubeconfig` | Kubeconfig for kubelet |
| `kube-scheduler.kubeconfig` | Kubeconfig for scheduler |
| `kube-controller-manager.kubeconfig` | Kubeconfig for controller-manager |
| `kube-proxy.kubeconfig` | Kubeconfig for kube-proxy |
| `encryption-config.yaml` | Encryption key for Secrets at rest |

No certificates were removed from the original guide. The simplification was entirely structural: collapsing 6 node certificates into 1, removing the load balancer and its virtual IP from the SAN list, and pointing all kubeconfigs at `127.0.0.1:6443` instead of a load-balanced hostname.
