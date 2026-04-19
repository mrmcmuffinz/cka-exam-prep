I need you to create a comprehensive Kubernetes homework assignment to help me practice **NetworkPolicy Fundamentals**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed 08-services/assignment-1
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers NetworkPolicy spec structure, podSelector mechanics, basic ingress and egress rules within a namespace, and port-level filtering. Advanced selectors (namespaceSelector, ipBlock) are covered in assignment-2. Network policy debugging is covered in assignment-3.

**In scope for this assignment:**

*NetworkPolicy Spec Structure*
- apiVersion: networking.k8s.io/v1
- kind: NetworkPolicy
- metadata: name, namespace
- spec.podSelector: which pods the policy applies to
- spec.policyTypes: Ingress, Egress, or both
- spec.ingress: list of ingress rules
- spec.egress: list of egress rules

*podSelector Mechanics*
- Empty podSelector {} selects all pods in namespace
- Label selector restricts to matching pods
- Policy applies only to selected pods
- Pods not selected by any policy allow all traffic

*Basic Ingress Rules*
- from: list of sources allowed to send traffic
- from.podSelector: pods in same namespace
- Multiple from entries are OR (any match allows)
- Empty ingress array: deny all ingress
- No ingress field with policyTypes including Ingress: deny all

*Basic Egress Rules*
- to: list of destinations allowed to receive traffic
- to.podSelector: pods in same namespace
- Multiple to entries are OR (any match allows)
- Empty egress array: deny all egress
- No egress field with policyTypes including Egress: deny all

*Port-Level Filtering*
- ports: list of allowed ports
- ports.port: port number or named port
- ports.protocol: TCP (default) or UDP
- Port filtering combined with from/to (AND)
- No ports field: all ports allowed for that rule

*Policy Verification Workflow*
- Testing connectivity before and after policy
- kubectl describe networkpolicy
- Testing with curl/wget from pods
- Understanding what policy should allow/deny

**Out of scope (covered in other assignments, do not include):**

- namespaceSelector (exercises/10-10-network-policies/assignment-2)
- ipBlock/CIDR selectors (exercises/10-10-network-policies/assignment-2)
- Default deny policies (exercises/10-10-network-policies/assignment-2)
- Namespace isolation strategies (exercises/10-10-network-policies/assignment-2)
- Policy debugging and troubleshooting (exercises/10-10-network-policies/assignment-3)
- Ingress L7 routing (exercises/11-ingress-and-gateway-api/)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: network-policies-tutorial.md
   - Explain why Network Policies matter for security
   - Explain CNI requirement (kind default CNI does not support, need Calico)
   - Walk through NetworkPolicy structure
   - Demonstrate ingress rules within namespace
   - Demonstrate egress rules within namespace
   - Show port-level filtering
   - Include Calico installation for kind
   - Use tutorial-network-policies namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: network-policies-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Basic Policy Creation**
   - Create policy allowing specific pod ingress
   - Create policy allowing specific pod egress
   - Verify policy with connectivity tests

   **Level 2 (Exercises 2.1-2.3): Pod Selection and Rules**
   - Policy selecting pods by label
   - Policy with multiple from/to entries
   - Policy with port filtering

   **Level 3 (Exercises 3.1-3.3): Debugging Policy Effects**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: policy too restrictive, wrong selector, port mismatch

   **Level 4 (Exercises 4.1-4.3): Combined Rules**
   - Ingress and egress in same policy
   - Multiple ports with different protocols
   - Named ports in policies

   **Level 5 (Exercises 5.1-5.3): Application Scenarios**
   - Exercise 5.1: Web app with frontend and backend pods
   - Exercise 5.2: Debug policy blocking expected traffic
   - Exercise 5.3: Design policy for multi-tier application

3. **Answer Key File**
   - Create the answer key: network-policies-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - CNI not supporting NetworkPolicy
     - Empty podSelector means all pods
     - policyTypes must include what you want to control
     - Multiple from/to entries are OR, not AND
     - Forgetting DNS egress breaks name resolution
   - NetworkPolicy debugging cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of NetworkPolicy Fundamentals assignment
   - Prerequisites: 08-services/assignment-1
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: multi-node kind with Calico CNI
   - Calico installation instructions
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Multi-node kind cluster with Calico CNI
- Default kindnet does NOT support NetworkPolicy
- kubectl client

KIND CLUSTER NOTE:
The default kind CNI (kindnet) does not support NetworkPolicy enforcement. The tutorial must include instructions for creating a kind cluster with Calico:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
nodes:
- role: control-plane
- role: worker
- role: worker
```

Then install Calico after cluster creation.

RESOURCE GATE:
All CKA resources are in scope (generation order 23):
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
  - exercises/08-08-services/assignment-1: Service basics

- **Follow-up assignments:**
  - exercises/10-10-network-policies/assignment-2: Advanced selectors and isolation
  - exercises/10-10-network-policies/assignment-3: Network policy debugging

COURSE MATERIAL REFERENCE:
- S7 (Lectures 179-182): Network policies
