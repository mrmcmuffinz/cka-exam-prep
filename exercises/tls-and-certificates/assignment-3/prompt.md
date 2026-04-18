I need you to create a comprehensive Kubernetes homework assignment to help me practice **Certificate Troubleshooting**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S7 (through lecture 159)
- I have completed tls-and-certificates/assignment-1 and assignment-2
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers diagnosing and resolving certificate-related issues: expiration, subject/issuer mismatches, wrong CA, permission issues, and renewal patterns. Manual certificate creation (assignment-1) and the Certificates API (assignment-2) are assumed knowledge.

**In scope for this assignment:**

*Diagnosing Certificate Expiration*
- Checking certificate validity dates: openssl x509 -dates
- Identifying expired certificates before symptoms appear
- Understanding expiration symptoms: connection refused, TLS handshake failures
- kubeadm certs check-expiration command
- Certificate expiration in logs (API server, kubelet, etcd)

*Certificate Subject/Issuer Mismatches*
- Verifying certificate subject matches expected identity
- Checking issuer matches expected CA
- Understanding "certificate is not valid for" errors
- SAN (Subject Alternative Name) mismatches for server certificates
- Diagnosing "x509: certificate signed by unknown authority" errors

*Wrong CA in Certificate Chain*
- Identifying when client trusts wrong CA
- Verifying certificate against CA: openssl verify
- Understanding certificate chain validation process
- Diagnosing "certificate verify failed" errors
- Finding which CA signed a certificate

*Certificate Permission Issues*
- File permissions on certificate and key files
- Certificate ownership (who can read the private key)
- Symptoms of permission problems (component fails to start)
- Checking permissions with ls -la

*Component Certificate Rotation*
- Understanding when certificates need rotation
- kubeadm certs renew commands
- Manual rotation process (generate new cert, update component)
- Restarting components after rotation
- Verifying rotation success

*User Certificate Renewal Patterns*
- User certificate expiration handling
- Regenerating user certificates via Certificates API
- Updating kubeconfig with new certificates
- Automating certificate renewal (conceptual)

**Out of scope (covered in other assignments, do not include):**

- Manual certificate creation from scratch (exercises/tls-and-certificates/assignment-1)
- CSR resource creation and approval (exercises/tls-and-certificates/assignment-2)
- kubeconfig structure basics (exercises/tls-and-certificates/assignment-2)
- etcd backup/restore (exercises/cluster-lifecycle/assignment-3)
- Control plane troubleshooting beyond certificates (exercises/troubleshooting/assignment-2)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: tls-and-certificates-tutorial.md (section 3)
   - Explain common certificate failure modes and their symptoms
   - Demonstrate checking certificate expiration
   - Show how to diagnose subject/issuer mismatches
   - Walk through certificate renewal with kubeadm
   - Show user certificate renewal workflow
   - Use tutorial-tls namespace where applicable

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: tls-and-certificates-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Certificate Health Checks**
   - Check expiration dates for all cluster certificates
   - Identify certificates expiring within 30 days
   - Verify certificate chain for a component

   **Level 2 (Exercises 2.1-2.3): Diagnosing Issues**
   - Identify the CA that signed a given certificate
   - Verify a certificate is valid for a specific hostname
   - Check file permissions on certificate files

   **Level 3 (Exercises 3.1-3.3): Debugging Broken Certificates**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: expired certificate, wrong CA, missing SAN

   **Level 4 (Exercises 4.1-4.3): Certificate Renewal**
   - Renew a user certificate using the Certificates API
   - Document the kubeadm certificate renewal process
   - Update kubeconfig after certificate renewal

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Exercise 5.1: Full cluster certificate audit and renewal plan
   - Exercise 5.2: Diagnose multi-certificate failure scenario
   - Exercise 5.3: Create certificate monitoring and alerting strategy

3. **Answer Key File**
   - Create the answer key: tls-and-certificates-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Checking wrong certificate for expiration
     - Confusing subject CN with SAN
     - Not restarting component after renewal
     - Renewing certificate but not updating kubeconfig
     - Permission issues after renewal
   - Diagnostic commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Certificate Troubleshooting assignment
   - Prerequisites: tls-and-certificates/assignment-1, assignment-2
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- openssl for certificate inspection
- Access to /etc/kubernetes/pki/ via nerdctl exec

RESOURCE GATE:
This assignment uses a restricted resource gate (generation order 6):
- All resources from assignments 1-5
- CertificateSigningRequest resource
- Certificate files (inspection and conceptual rotation)
- Do NOT use: Services, Ingress, PersistentVolumes, NetworkPolicies

KIND CLUSTER NOTE:
Some certificate rotation exercises may be conceptual because modifying certificates in kind requires careful manipulation of the control-plane container. The tutorial should clearly identify which exercises are hands-on vs. documentation/planning exercises.

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-tls`.
- Debugging exercise headings are bare.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/tls-and-certificates/assignment-1: Certificate creation
  - exercises/tls-and-certificates/assignment-2: Certificates API

- **Follow-up assignments:**
  - exercises/rbac/assignment-2: Cluster-scoped RBAC with certificate-based auth
  - exercises/troubleshooting/assignment-2: Control plane troubleshooting (cert issues)

COURSE MATERIAL REFERENCE:
- S7 (Lectures 146-159): TLS, certificate viewing, troubleshooting
- S14 (Lectures 289-291): Control plane failure (includes certificate issues)
