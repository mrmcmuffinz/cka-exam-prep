I need you to create a comprehensive Kubernetes homework assignment to help me practice **Certificates API and kubeconfig**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S7 (through lecture 159)
- I have completed tls-and-certificates/assignment-1 (manual certificate creation)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers the Kubernetes Certificates API for automated CSR workflows, kubeconfig file structure and management, and certificate-based authentication. Manual certificate creation with openssl is assumed knowledge from assignment-1. Certificate troubleshooting is covered in assignment-3.

**In scope for this assignment:**

*CertificateSigningRequest Resource*
- CSR resource structure: metadata, spec (request, signerName, usages)
- Encoding the CSR request (base64 of PEM-formatted CSR)
- signerName field: kubernetes.io/kube-apiserver-client for user certs
- usages field: client auth, digital signature, key encipherment
- Creating CSR resources with kubectl apply

*CSR Approval and Denial Workflow*
- Listing pending CSRs: kubectl get csr
- Inspecting CSR details: kubectl describe csr
- Approving CSRs: kubectl certificate approve <name>
- Denying CSRs: kubectl certificate deny <name>
- Extracting the signed certificate from approved CSR: kubectl get csr <name> -o jsonpath='{.status.certificate}' | base64 -d
- CSR lifecycle: Pending, Approved, Denied, Issued, Failed

*kubeconfig Structure*
- Three sections: clusters, users, contexts
- clusters section: server URL, certificate-authority-data (or certificate-authority file path)
- users section: client-certificate-data and client-key-data (or file paths), token, exec plugins
- contexts section: combining cluster, user, and optional namespace
- current-context: the default context
- File location: $HOME/.kube/config, KUBECONFIG environment variable

*Certificate-Based Authentication in kubeconfig*
- Embedding certificates directly (base64-encoded in -data fields)
- Referencing certificate files (certificate-authority, client-certificate, client-key)
- When to use embedded vs. file references
- Creating kubeconfig entries for new users

*kubeconfig Context Management*
- Listing contexts: kubectl config get-contexts
- Switching contexts: kubectl config use-context <name>
- Creating new contexts: kubectl config set-context
- Setting default namespace for a context
- Viewing current context: kubectl config current-context
- Viewing full config: kubectl config view
- Managing multiple kubeconfig files

**Out of scope (covered in other assignments, do not include):**

- Manual certificate creation with openssl (exercises/tls-and-certificates/assignment-1)
- Certificate file locations and PKI structure (exercises/tls-and-certificates/assignment-1)
- Certificate troubleshooting (exercises/tls-and-certificates/assignment-3)
- RBAC authorization (happens after authentication) (exercises/rbac/)
- Service account tokens (exercises/rbac/assignment-1)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: tls-and-certificates-tutorial.md (section 2)
   - Explain the Certificates API and why it exists (automated CSR workflow)
   - Walk through creating a CSR resource for a new user
   - Demonstrate approval and certificate extraction
   - Explain kubeconfig structure with annotated examples
   - Show how to create kubeconfig entries for the new user
   - Demonstrate context management
   - Use tutorial-tls namespace where applicable

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: tls-and-certificates-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): kubeconfig Exploration**
   - View and interpret the default kubeconfig structure
   - List and describe contexts
   - Identify which certificates are embedded vs. file-referenced

   **Level 2 (Exercises 2.1-2.3): CSR Workflow**
   - Create a CSR for a new user using the Certificates API
   - Approve the CSR and extract the signed certificate
   - Deny a CSR and observe the result

   **Level 3 (Exercises 3.1-3.3): Debugging CSR Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: CSR with wrong encoding, CSR with wrong signerName, CSR stuck in Pending

   **Level 4 (Exercises 4.1-4.3): kubeconfig Management**
   - Create a complete kubeconfig for a new user
   - Configure multiple contexts in a single kubeconfig
   - Merge kubeconfig files using KUBECONFIG environment variable

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Exercise 5.1: Complete user onboarding (generate key, CSR, approve, create kubeconfig)
   - Exercise 5.2: Set up multiple users with different contexts
   - Exercise 5.3: kubeconfig for service account (conceptual, token-based alternative)

3. **Answer Key File**
   - Create the answer key: tls-and-certificates-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Wrong base64 encoding (need -w0 or single line)
     - Wrong signerName for user certificates
     - Missing usages in CSR spec
     - Embedded certs without removing newlines
     - Context pointing to wrong cluster or user
   - kubectl config commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Certificates API and kubeconfig assignment
   - Prerequisites: tls-and-certificates/assignment-1
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- openssl for generating keys and CSRs
- base64 utility
- kubectl client

RESOURCE GATE:
This assignment uses a restricted resource gate (generation order 5):
- Pods, ConfigMaps, Secrets
- Namespaces
- CertificateSigningRequest resource
- kubeconfig files (create and manage)
- Do NOT use: Services, Ingress, PersistentVolumes, NetworkPolicies

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-tls`.
- Debugging exercise headings are bare.
- base64 encoding uses `base64 -w0` for single-line output.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/tls-and-certificates/assignment-1: Manual certificate creation

- **Follow-up assignments:**
  - exercises/tls-and-certificates/assignment-3: Certificate troubleshooting
  - exercises/rbac/assignment-1: RBAC for authenticated users
  - exercises/rbac/assignment-2: Cluster-scoped RBAC

COURSE MATERIAL REFERENCE:
- S7 (Lectures 146-159): TLS, Certificates API, KubeConfig
