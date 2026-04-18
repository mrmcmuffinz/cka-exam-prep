I need you to create a comprehensive Kubernetes homework assignment to help me practice **Network Troubleshooting**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed services, coredns, network-policies, and ingress assignments
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers network layer troubleshooting: service connectivity, DNS resolution, network policy issues, kube-proxy, and external access. This is a capstone assignment combining failures from multiple networking topics. Application, control plane, and node troubleshooting are covered in assignments 1, 2, and 3.

**In scope for this assignment:**

*Service Not Reachable*
- Empty endpoints
- Selector mismatch
- Wrong targetPort
- Service in wrong namespace
- kube-proxy not routing

*DNS Resolution Failures*
- CoreDNS not running
- CoreDNS misconfigured
- Pod DNS policy wrong
- DNS egress blocked by NetworkPolicy
- Service DNS name typo

*Network Policy Blocking Traffic*
- Default deny blocking expected traffic
- Missing ingress rule
- Missing egress rule (especially DNS)
- Selector mismatch in policy
- namespaceSelector issues

*kube-proxy Issues*
- kube-proxy not running
- kube-proxy mode (iptables vs ipvs)
- kube-proxy configuration errors
- Service routing not working

*Pod-to-Pod Connectivity*
- CNI issues
- Pod CIDR overlap
- Cross-node connectivity
- Network plugin failures

*Cross-Namespace Connectivity*
- Service access across namespaces
- Network policy cross-namespace rules
- DNS cross-namespace resolution

*External Access Failures*
- NodePort not accessible
- LoadBalancer stuck pending
- Ingress not routing
- External traffic policy issues

**Out of scope (covered in other assignments, do not include):**

- Application troubleshooting (exercises/troubleshooting/assignment-1)
- Control plane troubleshooting (exercises/troubleshooting/assignment-2)
- Node troubleshooting (exercises/troubleshooting/assignment-3)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: troubleshooting-tutorial.md (section 4)
   - Explain network architecture in Kubernetes
   - Show service connectivity debugging
   - Demonstrate DNS troubleshooting
   - Cover network policy diagnosis
   - Show external access debugging
   - Use tutorial-troubleshooting namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: troubleshooting-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)
   - All exercises are debugging exercises
   - Exercise headings are bare (### Exercise 1.1, etc.)

   **Level 1 (Exercises 1.1-1.3): Service Issues**
   - Service with empty endpoints
   - Service wrong port
   - Service selector mismatch

   **Level 2 (Exercises 2.1-2.3): DNS Issues**
   - CoreDNS not running
   - Wrong DNS name used
   - DNS blocked by policy

   **Level 3 (Exercises 3.1-3.3): Network Policy Issues**
   - Policy blocking ingress
   - Policy blocking egress
   - Cross-namespace policy issue

   **Level 4 (Exercises 4.1-4.3): External Access**
   - NodePort not working
   - Ingress not routing
   - LoadBalancer issues

   **Level 5 (Exercises 5.1-5.3): Complex Network Failures**
   - Multiple networking issues combined
   - Full application network debugging
   - Production incident simulation

3. **Answer Key File**
   - Create the answer key: troubleshooting-homework-answers.md
   - Full diagnostic workflow for each exercise
   - Network troubleshooting flowcharts
   - Common mistakes in diagnosis

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Network Troubleshooting assignment
   - Prerequisites: services, coredns, network-policies, ingress
   - Estimated time commitment: 6-8 hours
   - Cluster requirements: multi-node kind with Calico and ingress
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Multi-node kind cluster
- Calico CNI for NetworkPolicy support
- nginx-ingress installed
- Various network misconfigurations to debug

RESOURCE GATE:
All CKA resources are in scope (generation order 38):
- All Kubernetes resources
- All networking resources
- Network troubleshooting commands

CROSS-DOMAIN NOTE:
These exercises combine failures from services, DNS, NetworkPolicy, and Ingress. A single exercise might have:
- Service selector mismatch
- NetworkPolicy blocking traffic
- DNS resolution failing
The learner must diagnose all issues to fully fix the scenario.

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-troubleshooting`.
- ALL exercise headings are bare.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/services/ assignments
  - exercises/coredns/ assignments
  - exercises/network-policies/ assignments
  - exercises/ingress-and-gateway-api/ assignments

COURSE MATERIAL REFERENCE:
- S14 (Lectures 295-296): Network troubleshooting
- S9: Networking (all lectures)
