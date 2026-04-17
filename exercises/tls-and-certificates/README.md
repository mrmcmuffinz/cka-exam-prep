# TLS and Certificates

**CKA Domain:** Cluster Architecture, Installation & Configuration (25%)
**Competencies covered:** TLS certificates and Kubernetes PKI, kubeconfig management

---

## Why One Assignment

The TLS and certificate material in the CKA maps to a focused set of skills:
understanding the Kubernetes PKI structure, creating and inspecting certificates with
openssl, using the Certificates API for CSR approval workflows, and managing
certificate-based authentication in kubeconfig. These subtopics are tightly coupled
(certificates authenticate users, kubeconfig stores the credentials, the Certificates
API automates approval) and produce roughly 10-12 distinct exercise areas, which fits
comfortably within a single 15-exercise assignment.

---

## Assignments

| Assignment | Title | Covers | Prerequisites |
|---|---|---|---|
| assignment-1 | TLS and Certificates | K8s PKI overview, cert creation with openssl, viewing cert details, Certificates API (CSR resource), CSR approval workflow, kubeconfig cert-based auth, cert file locations, diagnosing cert issues | cluster-lifecycle/assignment-1 |

## Scope Boundaries

This topic covers authentication infrastructure. The following related areas are
handled by other topics:

- **RBAC** (what authenticated users are authorized to do): covered in `rbac/`
- **Certificate expiration as a troubleshooting scenario**: covered in `troubleshooting/assignment-2`
- **TLS termination for Ingress**: covered in `ingress-and-gateway-api/`
- **Service account tokens** (non-certificate authentication): covered in `rbac/assignment-1`

## Cluster Requirements

Single-node kind cluster. Kind generates its own CA and component certificates, which
exercises will inspect and extend. The tutorial should explain where kind's certs live
and how they differ from a kubeadm-managed cluster.

## Recommended Order

Complete cluster-lifecycle/assignment-1 first for context on control plane components
and their certificate requirements.
