I need you to create a comprehensive Kubernetes homework assignment to help me practice **TLS Fundamentals and Certificate Creation**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S7 (through lecture 159, covering Security through KubeConfig)
- I have completed 17-cluster-lifecycle/assignment-1 (understanding of control plane components)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers the Kubernetes PKI structure, certificate anatomy, creating certificates with openssl, viewing and validating certificates, and understanding the certificate file locations on control plane nodes. The Certificates API for automated CSR workflows and kubeconfig management are covered in assignment-2. Certificate troubleshooting is covered in assignment-3.

**In scope for this assignment:**

*Kubernetes PKI Overview*
- Why Kubernetes uses TLS (mutual authentication, encrypted communication)
- The cluster CA (Certificate Authority) and its role
- Which components need certificates: API server, etcd, kubelet, scheduler, controller manager, front-proxy
- Client vs. server certificates (API server has both, kubelet is both client and server)
- Certificate chains and trust (all component certs signed by cluster CA)

*Certificate Anatomy*
- Subject field: CN (Common Name), O (Organization), and their meaning in Kubernetes
- CN for user certificates (becomes username), O for group membership
- Issuer field: who signed the certificate
- Validity period: NotBefore, NotAfter
- Key usage extensions: digitalSignature, keyEncipherment, serverAuth, clientAuth
- Subject Alternative Names (SANs): DNS names and IP addresses for server certs

*Creating Certificates with openssl*
- Generating private keys: openssl genrsa -out key.pem 2048
- Creating Certificate Signing Requests (CSRs): openssl req -new -key key.pem -out csr.pem
- Specifying subject in CSR: -subj "/CN=user/O=group"
- Signing CSRs with a CA: openssl x509 -req -in csr.pem -CA ca.crt -CAkey ca.key -CAcreateserial -out cert.pem
- Setting validity period: -days flag
- Adding SANs using openssl config files
- Converting between certificate formats (PEM, DER) if needed

*Viewing Certificate Details*
- openssl x509 -in cert.pem -text -noout for full certificate dump
- Extracting specific fields: -subject, -issuer, -dates, -ext
- Verifying certificate against CA: openssl verify -CAfile ca.crt cert.pem
- Checking certificate expiration dates
- Decoding base64-encoded certificates

*Certificate File Locations*
- /etc/kubernetes/pki/ as the standard PKI directory
- CA certificate and key: ca.crt, ca.key
- API server certificates: apiserver.crt, apiserver.key, apiserver-kubelet-client.crt
- etcd certificates: etcd/ca.crt, etcd/server.crt, etcd/peer.crt
- Front-proxy certificates: front-proxy-ca.crt, front-proxy-client.crt
- Service account key pair: sa.key, sa.pub
- How kubeadm organizes certificates

*Certificate Validation and Trust Chains*
- Verifying a certificate was signed by the correct CA
- Understanding certificate chain validation
- Common validation errors and what they mean
- Checking certificate purpose (client auth, server auth)

**Out of scope (covered in other assignments, do not include):**

- CertificateSigningRequest resource in Kubernetes (exercises/18-18-tls-and-certificates/assignment-2)
- kubeconfig file structure and management (exercises/18-18-tls-and-certificates/assignment-2)
- Certificate troubleshooting (expiration, mismatches, wrong CA) (exercises/18-18-tls-and-certificates/assignment-3)
- etcd operations beyond certificate location (exercises/17-17-cluster-lifecycle/assignment-3)
- RBAC (authorization happens after authentication) (exercises/12-rbac/)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: tls-and-certificates-tutorial.md
   - Explain why Kubernetes uses TLS and the PKI structure
   - Walk through generating a user certificate from scratch (key, CSR, signing with CA)
   - Show how to view certificate details with openssl
   - Explore certificate files in /etc/kubernetes/pki/ (via exec into kind container)
   - Demonstrate certificate validation
   - Use tutorial-tls namespace where applicable
   - Include cleanup commands

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: tls-and-certificates-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Exploring Cluster Certificates**
   - List and categorize certificates in /etc/kubernetes/pki/
   - View the cluster CA certificate and identify its properties
   - View the API server certificate and identify its SANs

   **Level 2 (Exercises 2.1-2.3): Certificate Operations**
   - Generate a private key and CSR for a new user
   - Sign the CSR with the cluster CA
   - Verify the certificate chain

   **Level 3 (Exercises 3.1-3.3): Debugging Certificate Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: identify which component a certificate belongs to, find certificate with wrong issuer, check if certificate is expired

   **Level 4 (Exercises 4.1-4.3): Advanced Certificate Creation**
   - Create a certificate with specific SANs (DNS and IP)
   - Create a certificate with correct key usage extensions
   - Create a certificate for a service account (conceptual)

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Exercise 5.1: Map all certificates to their components (create PKI inventory)
   - Exercise 5.2: Create certificates for a hypothetical new component
   - Exercise 5.3: Document certificate lifecycle and rotation strategy

3. **Answer Key File**
   - Create the answer key: tls-and-certificates-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Confusing CN (Common Name) with DNS SAN
     - Forgetting -CAcreateserial on first signing
     - Wrong key usage for certificate purpose
     - Certificate signed by wrong CA
     - Base64 encoding issues
   - openssl commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of TLS Fundamentals assignment
   - Prerequisites: 17-cluster-lifecycle/assignment-1
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster
   - Tools needed: openssl
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- openssl installed on host or accessible via kind exec
- Access to /etc/kubernetes/pki/ via nerdctl exec

RESOURCE GATE:
This assignment uses a restricted resource gate (generation order 4):
- Pods, ConfigMaps, Secrets
- Namespaces
- Certificate files (read-only inspection)
- Do NOT use: Services, Ingress, PersistentVolumes, NetworkPolicies, CertificateSigningRequest resource

KIND CLUSTER SETUP:
Single-node kind cluster is sufficient:
```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

Access PKI files via:
```bash
nerdctl exec -it kind-control-plane ls /etc/kubernetes/pki/
```

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-tls`.
- Debugging exercise headings are bare.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/17-17-cluster-lifecycle/assignment-1: Understanding control plane components

- **Follow-up assignments:**
  - exercises/18-18-tls-and-certificates/assignment-2: Certificates API and kubeconfig
  - exercises/18-18-tls-and-certificates/assignment-3: Certificate troubleshooting
  - exercises/12-12-rbac/assignment-1: Using certificate-based authentication with RBAC

COURSE MATERIAL REFERENCE:
- S7 (Lectures 143-145): Security primitives, authentication
- S7 (Lectures 146-159): TLS basics, Kubernetes certificates, certificate creation, viewing certificates, Certificates API, KubeConfig
