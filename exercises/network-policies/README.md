# Network Policies

**CKA Domain:** Services & Networking (20%)
**Competencies covered:** Define and enforce Network Policies

---

## Why One Assignment

Network Policies cover ingress and egress rules, selector combinations, namespace
isolation patterns, CIDR-based selectors, port filtering, and the additive policy
model. This produces roughly 12-14 exercise areas. The concepts are tightly related
(every exercise involves the NetworkPolicy resource and its interaction with pod
selectors and namespace selectors), and the debugging dimension (figuring out why
traffic is blocked or unexpectedly allowed) adds natural Level 3 and Level 5 material.
A single dense assignment covers this well.

---

## Assignments

| Assignment | Title | Covers | Prerequisites |
|---|---|---|---|
| assignment-1 | Network Policies | NetworkPolicy spec structure, ingress rules (podSelector, namespaceSelector, ipBlock), egress rules, default deny policies, namespace isolation patterns, AND vs OR semantics for combined selectors, CIDR selectors, port filtering, additive policy behavior | services/assignment-1 |

## Scope Boundaries

This topic covers L3/L4 traffic filtering via NetworkPolicy resources. The following
related areas are handled by other topics:

- **Services** (traffic being filtered flows to/from services): covered in `services/`
- **Ingress** (L7 routing, distinct from L3/L4 filtering): covered in `ingress-and-gateway-api/`
- **Network policy debugging in cross-domain scenarios**: covered in `troubleshooting/assignment-4`

## Cluster Requirements

Multi-node kind cluster with a CNI that supports NetworkPolicy. The default kind CNI
(kindnet) does not support NetworkPolicy enforcement. The tutorial must include
instructions for installing Calico (or another policy-capable CNI) on the kind cluster
before any exercises can work.

## Recommended Order

Complete services/assignment-1 first. Network policies filter traffic to and from
services, so understanding services and selectors is prerequisite knowledge.
