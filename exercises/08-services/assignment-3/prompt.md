I need you to create a comprehensive Kubernetes homework assignment to help me practice **Service Patterns and Troubleshooting**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed 08-services/assignment-1 and assignment-2
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers advanced service patterns (multi-port, session affinity, traffic policies) and systematic service troubleshooting. ClusterIP basics (assignment-1) and external service types (assignment-2) are assumed knowledge.

**In scope for this assignment:**

*Multi-Port Services*
- Defining multiple ports in spec.ports array
- Port naming with spec.ports[].name
- Why port names matter (required for multi-port, used by Ingress)
- Different protocols per port (TCP, UDP)
- Use cases: HTTP + HTTPS, app + metrics, primary + replica

*Session Affinity*
- spec.sessionAffinity: None (default) or ClientIP
- ClientIP sticky sessions: same client IP goes to same pod
- spec.sessionAffinityConfig.clientIP.timeoutSeconds
- When to use session affinity
- Limitations: does not work across service types

*Traffic Policies*
- spec.externalTrafficPolicy: Cluster or Local
- Cluster (default): load balance across all pods, loses source IP
- Local: only route to node-local pods, preserves source IP
- Performance implications of Local policy
- spec.internalTrafficPolicy: Cluster or Local (for internal traffic)
- Topology-aware routing (conceptual)

*Troubleshooting Empty Endpoints*
- Service selector does not match any pods
- No pods in Ready state
- Pods in different namespace than intended
- Debugging with kubectl get endpoints

*Troubleshooting Selector Mismatches*
- Labels on service vs labels on pods
- Typos in label keys or values
- Missing labels on pods
- Comparing selectors with kubectl get svc -o wide

*Service Readiness and Endpoint Removal*
- How readiness probes affect endpoints
- Pod becomes unready, removed from endpoints
- Timing of endpoint updates
- publishNotReadyAddresses field

*Troubleshooting Port Issues*
- targetPort does not match container port
- Named port reference does not exist
- Protocol mismatch (TCP vs UDP)
- Connection refused vs timeout

**Out of scope (covered in other assignments, do not include):**

- ClusterIP basics (exercises/08-08-services/assignment-1)
- External service types (exercises/08-08-services/assignment-2)
- DNS resolution (exercises/09-coredns/)
- Network Policies (exercises/10-network-policies/)
- Ingress (exercises/11-ingress-and-gateway-api/)
- Cross-domain troubleshooting (exercises/19-19-troubleshooting/assignment-4)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: services-tutorial.md (section 3)
   - Demonstrate multi-port services
   - Explain session affinity configuration
   - Explain traffic policies and their implications
   - Show systematic troubleshooting workflow
   - Use tutorial-services namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: services-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Multi-Port Services**
   - Create service with multiple named ports
   - Access different ports from test pod
   - Configure different protocols per port

   **Level 2 (Exercises 2.1-2.3): Session Affinity and Traffic Policies**
   - Configure session affinity and verify
   - Test externalTrafficPolicy: Local
   - Observe source IP preservation

   **Level 3 (Exercises 3.1-3.3): Debugging Service Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: empty endpoints, selector mismatch, wrong targetPort

   **Level 4 (Exercises 4.1-4.3): Advanced Troubleshooting**
   - Diagnose readiness affecting endpoints
   - Debug named port reference errors
   - Trace traffic policy effects

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Exercise 5.1: Multi-tier application with multiple services
   - Exercise 5.2: Debug service with multiple failure modes
   - Exercise 5.3: Design resilient service configuration

3. **Answer Key File**
   - Create the answer key: services-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Missing port names for multi-port services
     - Session affinity with short timeout
     - externalTrafficPolicy: Local with uneven pod distribution
     - Checking endpoints before checking selectors
     - Named port reference typos
   - Service troubleshooting flowchart

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Service Patterns and Troubleshooting assignment
   - Prerequisites: 08-services/assignment-1, assignment-2
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: multi-node kind cluster
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Multi-node kind cluster
- Deployments for testing service behavior
- kubectl client

RESOURCE GATE:
All CKA resources are in scope (generation order 19):
- Services (all types)
- Endpoints, EndpointSlices
- Deployments, Pods
- ConfigMaps, Secrets
- Namespaces

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-services`.
- Debugging exercise headings are bare.
- Container images use explicit version tags.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/08-08-services/assignment-1: ClusterIP services
  - exercises/08-08-services/assignment-2: External service types

- **Follow-up assignments:**
  - exercises/09-09-coredns/assignment-1: DNS for service discovery
  - exercises/10-10-network-policies/assignment-1: Filtering service traffic
  - exercises/19-19-troubleshooting/assignment-4: Network troubleshooting

COURSE MATERIAL REFERENCE:
- S2 (Lectures 33-37): Services
- S9 (Lectures 223-226): Service networking
- S14 (Lectures 295-296): Network troubleshooting
