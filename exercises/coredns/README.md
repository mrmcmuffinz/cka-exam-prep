# CoreDNS and Cluster DNS

**CKA Domain:** Services & Networking (20%)
**Competencies covered:** Understand and use CoreDNS

---

## Why One Assignment

CoreDNS is a focused topic: how Kubernetes DNS works, how to configure it, and how
to debug it when it breaks. The subtopic count is moderate (roughly 8-10 areas
including service DNS format, pod DNS records, Corefile structure, DNS policies,
and the debugging workflow). The material is tightly coupled, since every subtopic
relates to the same system, and fits naturally into a single assignment.

---

## Assignments

| Assignment | Title | Covers | Prerequisites |
|---|---|---|---|
| assignment-1 | CoreDNS and Cluster DNS | Service DNS format, pod DNS records, CoreDNS Deployment and ConfigMap in kube-system, Corefile structure and plugins, DNS debugging workflow (nslookup, dig from pods), DNS policies (ClusterFirst, Default, None, ClusterFirstWithHostNet), troubleshooting DNS resolution failures | services/assignment-1 |

## Scope Boundaries

This topic covers DNS within the cluster. The following related areas are handled
by other topics:

- **Services** (DNS resolves service names, but service creation is separate): covered in `services/`
- **Network Policies** (can block DNS traffic if egress to kube-dns is denied): covered in `network-policies/`
- **DNS failures as a troubleshooting scenario**: covered in `troubleshooting/assignment-4`

## Cluster Requirements

Multi-node kind cluster. CoreDNS runs as a Deployment in kube-system by default in
kind, so no special configuration is needed. DNS debugging exercises use pods with
nslookup/dig tools (busybox or dnsutils images).

## Recommended Order

Complete services/assignment-1 first. DNS resolves service names, so understanding
how services work is prerequisite knowledge.
