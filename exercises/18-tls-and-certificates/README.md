# TLS and Certificates

**CKA Domain:** Cluster Architecture, Installation & Configuration (25%)
**Competencies supported:** Manage RBAC (authentication foundation via certificates), troubleshoot cluster components (certificate expiration and verification)

---

## Rationale for Number of Assignments

TLS and certificate management encompasses Kubernetes PKI structure, certificate creation with openssl, certificate inspection and validation, the Certificates API for automated CSR workflows, kubeconfig certificate-based authentication, and certificate troubleshooting. This produces roughly 16-18 distinct subtopics. The material splits naturally into three focused progressions: TLS fundamentals and certificate creation, the Certificates API with kubeconfig integration, and comprehensive certificate troubleshooting. Each assignment delivers 5-6 subtopics at depth, building from manual certificate operations through automated workflows to diagnostic expertise.

---

## Assignment Summary

| Assignment | Description | Prerequisites |
|---|---|---|
| assignment-1 | TLS Fundamentals and Certificate Creation | Kubernetes PKI overview, certificate anatomy (subject, issuer, validity, key usage), creating certificates with openssl (keys, CSRs, signing), viewing certificate details with openssl x509, certificate file locations on control plane nodes, certificate validation and trust chains | 17-cluster-lifecycle/assignment-1 |
| assignment-2 | Certificates API and kubeconfig | CertificateSigningRequest resource, CSR creation and submission, CSR approval and denial workflow, kubeconfig structure (clusters, users, contexts), certificate-based authentication in kubeconfig, kubeconfig context management | 18-tls-and-certificates/assignment-1 |
| assignment-3 | Certificate Troubleshooting | Diagnosing certificate expiration, certificate subject/issuer mismatches, wrong CA in certificate chain, certificate permission issues, component certificate rotation, user certificate renewal patterns | 18-tls-and-certificates/assignment-2 |

## Scope Boundaries

This topic covers authentication infrastructure via certificates. The following related areas are handled by other topics:

- **RBAC** (what authenticated users are authorized to do after certificate authentication): covered in `rbac/`
- **Service account tokens** (non-certificate authentication method): covered in `12-rbac/assignment-1`
- **TLS termination for Ingress** (application-layer TLS, not cluster PKI): covered in `ingress-and-gateway-api/`
- **Certificate expiration as control plane failure** (when expired certs break the cluster): covered in `19-troubleshooting/assignment-2`

Assignment-1 focuses on manual certificate operations. Assignment-2 focuses on automated workflows via the Certificates API. Assignment-3 focuses on diagnosing certificate-related failures. The troubleshooting series adds cross-domain scenarios where certificate issues combine with other failures.

## Cluster Requirements

Single-node kind cluster for all three assignments. Kind generates its own CA and component certificates, which exercises will inspect and extend. Assignment-1 tutorial should explain where kind's certs live (`/etc/kubernetes/pki/` within the kind container) and how they differ from a kubeadm-managed bare-metal cluster.

**Kind cluster note:** Kind's certificate structure follows kubeadm conventions, making it suitable for hands-on certificate exercises. However, some certificate rotation scenarios may be limited since kind manages the control plane as containers, not systemd services.

## Recommended Order

1. Complete `17-cluster-lifecycle/assignment-1` first for context on control plane components and their certificate requirements
2. Work through assignments 1, 2, 3 sequentially
3. Assignment-2 assumes understanding of certificate creation mechanics from assignment-1
4. Assignment-3 assumes understanding of both manual and automated certificate workflows from assignments 1 and 2
5. This series should be completed before attempting RBAC assignments, as certificate-based authentication feeds RBAC authorization
