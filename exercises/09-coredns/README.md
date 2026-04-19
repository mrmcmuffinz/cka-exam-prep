# CoreDNS and Cluster DNS

**CKA Domain:** Services & Networking (20%)
**Competencies covered:** Understand and use CoreDNS

---

## Rationale for Number of Assignments

CoreDNS and cluster DNS encompass DNS record formats, DNS policies, CoreDNS configuration, Corefile plugin structure, and DNS troubleshooting workflows. This produces roughly 16-18 distinct subtopics. The material splits naturally into three focused progressions: DNS fundamentals with lookup mechanics, CoreDNS configuration and plugin architecture, and comprehensive DNS troubleshooting. Each assignment delivers 5-6 subtopics at depth, building from basic DNS usage through configuration mastery to diagnostic expertise.

---

## Assignment Summary

| Assignment | Description | Prerequisites |
|---|---|---|
| assignment-1 | DNS Fundamentals | Service DNS format (<service>.<namespace>.svc.cluster.local), pod DNS records, DNS policies in pod spec (ClusterFirst, Default, None, ClusterFirstWithHostNet), service discovery via DNS, DNS lookup workflow and resolv.conf, DNS queries from pods (nslookup, dig) | 08-services/assignment-1 |
| assignment-2 | CoreDNS Configuration | CoreDNS Deployment in kube-system, CoreDNS ConfigMap and Corefile structure, CoreDNS plugins (kubernetes, forward, cache, errors, health), CoreDNS configuration customization, CoreDNS logging and verbosity, CoreDNS performance tuning | 09-coredns/assignment-1 |
| assignment-3 | DNS Troubleshooting | Diagnosing DNS resolution failures, CoreDNS pod failures, DNS policy misconfigurations, network policies blocking DNS traffic, DNS caching issues, service DNS not resolving | 09-coredns/assignment-2 |

## Scope Boundaries

This topic covers DNS within the cluster. The following related areas are handled by other topics:

- **Services** (DNS resolves service names, but service creation is separate): covered in `services/`
- **Network Policies** (can block DNS traffic if egress to kube-dns is denied): covered in `network-policies/`
- **DNS failures in cross-domain troubleshooting**: covered in `19-troubleshooting/assignment-4`

Assignment-1 focuses on DNS usage from application perspective. Assignment-2 focuses on CoreDNS configuration and operation. Assignment-3 focuses on DNS troubleshooting and failure diagnosis. The troubleshooting series adds cross-domain scenarios where DNS failures combine with other networking issues.

## Cluster Requirements

Multi-node kind cluster for all three assignments. CoreDNS runs as a Deployment in kube-system by default in kind, so no special configuration is needed. DNS debugging exercises use pods with nslookup/dig tools (busybox or dnsutils images).

## Recommended Order

1. Complete `08-services/assignment-1` first (DNS resolves service names, so understanding services is prerequisite)
2. Work through assignments 1, 2, 3 sequentially
3. Assignment-2 assumes understanding of DNS lookup mechanics from assignment-1
4. Assignment-3 assumes understanding of both DNS usage and CoreDNS configuration from assignments 1 and 2
