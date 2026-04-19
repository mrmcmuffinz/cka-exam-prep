I need you to create a comprehensive Kubernetes homework assignment to help me practice **Advanced Selectors and Isolation**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed 10-network-policies/assignment-1
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers namespaceSelector, combined selectors, ipBlock/CIDR, default deny policies, namespace isolation, and policy ordering. Basic NetworkPolicy mechanics are assumed from assignment-1. Policy debugging is covered in assignment-3.

**In scope for this assignment:**

*namespaceSelector Mechanics*
- from.namespaceSelector: pods from namespaces matching labels
- to.namespaceSelector: pods in namespaces matching labels
- Namespace labels for policy matching
- Selecting all namespaces with empty selector

*Combined Selectors*
- podSelector AND namespaceSelector: both must match
- Multiple entries in same rule: AND semantics
- Multiple rules: OR semantics
- Understanding when AND vs OR applies

*ipBlock/CIDR for External Traffic*
- from.ipBlock.cidr: allow from IP range
- to.ipBlock.cidr: allow to IP range
- ipBlock.except: exclude IP ranges
- Use cases: external services, on-premises systems
- Cannot combine ipBlock with pod/namespace selectors in same entry

*Default Deny Policies*
- Deny all ingress: empty ingress array with policyTypes: [Ingress]
- Deny all egress: empty egress array with policyTypes: [Egress]
- Combined deny all: policyTypes: [Ingress, Egress]
- Default deny as security baseline
- Implicit allow without any policy

*Namespace Isolation Patterns*
- Isolate namespace completely
- Allow specific cross-namespace traffic
- Allow ingress from specific namespace
- Allow egress to specific namespace
- Production namespace isolation strategy

*Policy Ordering and Additive Behavior*
- No priority or ordering between policies
- Multiple policies: union of their rules
- More policies = more permissive (additive)
- Cannot use policies to deny what another allows
- Policy design for least privilege

**Out of scope (covered in other assignments, do not include):**

- Basic NetworkPolicy structure (exercises/10-10-network-policies/assignment-1)
- podSelector basics (exercises/10-10-network-policies/assignment-1)
- Port filtering basics (exercises/10-10-network-policies/assignment-1)
- Policy debugging (exercises/10-10-network-policies/assignment-3)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: network-policies-tutorial.md (section 2)
   - Explain namespaceSelector mechanics
   - Show combined selector behavior
   - Demonstrate ipBlock for external traffic
   - Explain default deny policies
   - Show namespace isolation patterns
   - Explain additive policy behavior
   - Use tutorial-network-policies namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: network-policies-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Cross-Namespace Policies**
   - Allow ingress from specific namespace
   - Allow egress to specific namespace
   - Use namespace labels for selection

   **Level 2 (Exercises 2.1-2.3): Combined Selectors and ipBlock**
   - Combine pod and namespace selectors
   - Configure ipBlock for external access
   - Use ipBlock.except for carve-outs

   **Level 3 (Exercises 3.1-3.3): Debugging Selector Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: namespace label missing, wrong AND/OR semantics, ipBlock overlapping except

   **Level 4 (Exercises 4.1-4.3): Default Deny and Isolation**
   - Create default deny all policy
   - Isolate namespace with allow-list
   - Implement least privilege policy

   **Level 5 (Exercises 5.1-5.3): Complex Isolation**
   - Exercise 5.1: Multi-namespace application isolation
   - Exercise 5.2: Debug policy interaction (additive behavior)
   - Exercise 5.3: Design zero-trust network policy strategy

3. **Answer Key File**
   - Create the answer key: network-policies-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Namespace missing required labels
     - Confusing AND vs OR in selectors
     - ipBlock not allowing expected CIDR
     - Default deny breaking cluster DNS
     - Multiple policies being additive (cannot subtract)
   - Advanced selector cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Advanced Selectors and Isolation assignment
   - Prerequisites: 10-network-policies/assignment-1
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: multi-node kind with Calico
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Multi-node kind cluster with Calico CNI (from assignment-1)
- Multiple namespaces for cross-namespace testing
- kubectl client

RESOURCE GATE:
All CKA resources are in scope (generation order 24):
- NetworkPolicies
- Pods, Deployments
- Services
- Namespaces (with labels)

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-network-policies`.
- Debugging exercise headings are bare.
- Container images use explicit version tags.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/10-10-network-policies/assignment-1: NetworkPolicy fundamentals

- **Follow-up assignments:**
  - exercises/10-10-network-policies/assignment-3: Network policy debugging

COURSE MATERIAL REFERENCE:
- S7 (Lectures 179-182): Network policies
