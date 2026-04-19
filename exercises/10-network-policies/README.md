# Network Policies

**CKA Domain:** Services & Networking (20%)
**Competencies covered:** Define and enforce Network Policies, understand connectivity between Pods

---

## Rationale for Number of Assignments

Network Policies encompass NetworkPolicy spec structure, multiple selector types
(pod, namespace, CIDR), ingress and egress rules, default deny patterns, isolation
strategies, policy ordering, and systematic debugging. This produces roughly 14-16
distinct subtopics. Rather than compressing this into one dense assignment, the
material splits naturally into three focused progressions: foundational mechanics,
advanced patterns and isolation, and comprehensive debugging scenarios. Each assignment
delivers 5-6 subtopics at depth, building expertise incrementally.

---

## Assignment Summary

| Assignment | Description | Prerequisites |
|---|---|---|
| assignment-1 | NetworkPolicy Fundamentals | NetworkPolicy spec structure, podSelector mechanics (same namespace), basic ingress rules, basic egress rules, port-level filtering, policy verification workflow | services/assignment-1 |
| assignment-2 | Advanced Selectors and Isolation | namespaceSelector, combined selectors (AND vs OR semantics), ipBlock/CIDR for external traffic, default deny patterns, namespace isolation strategies, policy ordering and additive behavior | network-policies/assignment-1 |
| assignment-3 | Network Policy Debugging | Diagnosing blocked traffic, diagnosing unexpectedly allowed traffic, multi-policy conflict resolution, cross-namespace troubleshooting, integration with services and DNS, observability patterns | network-policies/assignment-2 |

## Scope Boundaries

This topic covers L3/L4 traffic filtering via NetworkPolicy resources. The following
related areas are handled by other topics:

- **Services** (traffic being filtered flows to/from services): covered in `services/`
- **CoreDNS** (DNS resolution that policies may filter): covered in `coredns/`
- **Ingress** (L7 routing, distinct from L3/L4 filtering): covered in `ingress-and-gateway-api/`
- **Cross-domain network troubleshooting** (combining network policy failures with other failure modes): covered in `troubleshooting/assignment-4`

Assignment-3 focuses on NetworkPolicy-specific debugging (policy conflicts, selector
issues, rule evaluation). The troubleshooting series adds cross-domain scenarios where
network policy failures combine with service misconfigurations, DNS issues, or
application problems.

## Cluster Requirements

Multi-node kind cluster with a CNI that supports NetworkPolicy. The default kind CNI
(kindnet) does not support NetworkPolicy enforcement. Assignment-1 tutorial must include
detailed instructions for installing Calico (or another policy-capable CNI) on the kind
cluster before any exercises can work. Assignments 2 and 3 assume the CNI is already
configured.

## Recommended Order

1. Complete `services/assignment-1` first (prerequisite for all three assignments)
2. Work through assignments 1, 2, 3 sequentially
3. Assignment-2 assumes mastery of basic NetworkPolicy mechanics from assignment-1
4. Assignment-3 assumes understanding of all selector types and isolation patterns from assignments 1 and 2
