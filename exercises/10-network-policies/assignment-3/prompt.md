I need you to create a comprehensive Kubernetes homework assignment to help me practice **Network Policy Debugging**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed network-policies/assignment-1 and assignment-2
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers diagnosing blocked and unexpectedly allowed traffic, policy conflicts, cross-namespace troubleshooting, and integration with services and DNS. Basic and advanced NetworkPolicy mechanics are assumed from assignments 1 and 2.

**In scope for this assignment:**

*Diagnosing Blocked Traffic*
- Symptoms: connection timeout, connection refused
- Identifying which policy is blocking
- Testing from different source pods
- Checking policy selectors match pods
- Verifying policyTypes includes relevant direction

*Diagnosing Unexpectedly Allowed Traffic*
- When traffic should be blocked but is not
- Missing default deny policy
- Additive policy allowing unintended traffic
- CNI not enforcing policies
- Verifying CNI supports NetworkPolicy

*Multi-Policy Conflict Resolution*
- Understanding policies are additive (union)
- No way to deny what another policy allows
- Tracing which policy allows specific traffic
- Policy design to avoid conflicts

*Cross-Namespace Troubleshooting*
- namespaceSelector not matching
- Namespace labels missing or wrong
- Source namespace has egress policy
- Destination namespace has ingress policy
- Both policies must allow

*Integration with Services and DNS*
- Policies affect traffic to service ClusterIPs
- DNS requires egress to kube-system on port 53
- Service backend pods need ingress
- Headless service vs ClusterIP considerations

*Policy Observability Patterns*
- Testing connectivity systematically
- Using temporary test pods
- Logging network traffic (CNI-specific)
- Documenting expected traffic flows
- Policy validation workflow

**Out of scope (covered in other assignments, do not include):**

- NetworkPolicy basics (exercises/network-policies/assignment-1)
- Advanced selectors (exercises/network-policies/assignment-2)
- Cross-domain troubleshooting (exercises/troubleshooting/assignment-4)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: network-policies-tutorial.md (section 3)
   - Explain troubleshooting methodology
   - Show how to diagnose blocked traffic
   - Show how to diagnose unexpectedly allowed traffic
   - Explain policy interaction and conflicts
   - Demonstrate cross-namespace debugging
   - Show DNS and service integration issues
   - Use tutorial-network-policies namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: network-policies-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Basic Debugging**
   - Test connectivity with and without policy
   - Identify policy blocking traffic
   - Verify policy selector matches

   **Level 2 (Exercises 2.1-2.3): Policy Verification**
   - Test egress to DNS service
   - Verify service access through policy
   - Check cross-namespace policies

   **Level 3 (Exercises 3.1-3.3): Debugging Blocked Traffic**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: policy selector mismatch, missing DNS egress, wrong namespace label

   **Level 4 (Exercises 4.1-4.3): Complex Policy Issues**
   - Debug multi-policy interaction
   - Find policy allowing unintended traffic
   - Trace cross-namespace policy chain

   **Level 5 (Exercises 5.1-5.3): Integration Debugging**
   - Exercise 5.1: Debug application with multiple policy issues
   - Exercise 5.2: Service discovery failure due to policy
   - Exercise 5.3: Create policy troubleshooting runbook

3. **Answer Key File**
   - Create the answer key: network-policies-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Forgetting to test from correct source pod
     - Missing DNS egress in default deny
     - Not understanding additive behavior
     - Checking wrong policy for the namespace
     - CNI not supporting NetworkPolicy
   - Policy debugging flowchart

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Network Policy Debugging assignment
   - Prerequisites: network-policies/assignment-1, assignment-2
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: multi-node kind with Calico
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Multi-node kind cluster with Calico CNI
- Multiple namespaces and policies for debugging
- kubectl client

RESOURCE GATE:
All CKA resources are in scope (generation order 25):
- NetworkPolicies
- Pods, Deployments
- Services
- Namespaces

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
  - exercises/network-policies/assignment-1: NetworkPolicy fundamentals
  - exercises/network-policies/assignment-2: Advanced selectors and isolation

- **Follow-up assignments:**
  - exercises/troubleshooting/assignment-4: Network troubleshooting

COURSE MATERIAL REFERENCE:
- S7 (Lectures 179-182): Network policies
- S14 (Lectures 295-296): Network troubleshooting
