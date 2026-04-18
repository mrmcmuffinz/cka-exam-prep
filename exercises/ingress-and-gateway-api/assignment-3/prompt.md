I need you to create a comprehensive Kubernetes homework assignment to help me practice **Gateway API**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed ingress-and-gateway-api/assignment-1 and assignment-2
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers Gateway API resources (GatewayClass, Gateway, HTTPRoute), comparing Gateway API to Ingress, traffic routing with HTTPRoute, and Gateway API troubleshooting. Ingress fundamentals are assumed from assignments 1 and 2.

**In scope for this assignment:**

*Gateway API Resources*
- GatewayClass: defines controller implementation
- Gateway: defines listener and entry point
- HTTPRoute: defines HTTP routing rules
- Resource hierarchy: GatewayClass -> Gateway -> HTTPRoute
- Standard channel vs experimental

*GatewayClass*
- Defines which controller handles Gateways
- controllerName: identifies the controller
- parametersRef: controller-specific configuration
- Multiple GatewayClasses in a cluster

*Gateway*
- References GatewayClass via gatewayClassName
- spec.listeners: ports, protocols, hostnames
- TLS configuration in listeners
- Gateway status and conditions

*HTTPRoute*
- References Gateway via parentRefs
- spec.rules: list of routing rules
- spec.rules[].matches: path, headers, query params
- spec.rules[].backendRefs: services to route to
- Weights for traffic splitting

*Gateway API vs Ingress Comparison*
- Role separation (infra vs app team)
- More expressive routing
- Better multi-tenancy support
- TLS configuration location
- Portability across implementations

*Traffic Routing with HTTPRoute*
- Path matching (PathPrefix, Exact)
- Header-based routing
- Query parameter matching
- Traffic splitting with weights

*Gateway API Path Matching*
- PathPrefix: matches path prefix
- Exact: matches exact path
- RegularExpression: regex matching
- Matching priority

*Gateway API Troubleshooting*
- Gateway not ready: controller issue
- HTTPRoute not attached: parentRef wrong
- Backend not found: service issue
- Status conditions and events

**Out of scope (covered in other assignments, do not include):**

- Ingress basics (exercises/ingress-and-gateway-api/assignment-1)
- Ingress TLS (exercises/ingress-and-gateway-api/assignment-2)
- TCPRoute, UDPRoute, GRPCRoute (beyond CKA scope)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: ingress-and-gateway-api-tutorial.md (section 3)
   - Explain Gateway API architecture
   - Install Gateway API CRDs
   - Install a Gateway controller (e.g., nginx-gateway-fabric or Envoy)
   - Walk through GatewayClass, Gateway, HTTPRoute
   - Demonstrate traffic routing
   - Compare with Ingress
   - Use tutorial-ingress namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: ingress-and-gateway-api-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Gateway API Basics**
   - List GatewayClasses in cluster
   - Create Gateway resource
   - Create HTTPRoute with simple path

   **Level 2 (Exercises 2.1-2.3): HTTPRoute Routing**
   - Configure path-based routing
   - Configure header-based routing
   - Route to multiple backends

   **Level 3 (Exercises 3.1-3.3): Debugging Gateway API**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: HTTPRoute not attached, Gateway not ready, backend not found

   **Level 4 (Exercises 4.1-4.3): Advanced Routing**
   - Configure traffic splitting
   - Use multiple matches in rule
   - Configure TLS on Gateway

   **Level 5 (Exercises 5.1-5.3): Migration and Design**
   - Exercise 5.1: Migrate Ingress to Gateway API
   - Exercise 5.2: Debug complex routing issue
   - Exercise 5.3: Design Gateway API architecture for organization

3. **Answer Key File**
   - Create the answer key: ingress-and-gateway-api-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Gateway API CRDs not installed
     - Wrong GatewayClass name
     - HTTPRoute parentRef wrong namespace
     - Backend service port mismatch
     - Controller not supporting feature
   - Gateway API cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Gateway API assignment
   - Prerequisites: ingress-and-gateway-api/assignment-1, assignment-2
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: multi-node kind with Gateway controller
   - Gateway API CRD installation instructions
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Multi-node kind cluster
- Gateway API CRDs installed
- Gateway controller (nginx-gateway-fabric or similar)
- kubectl client

KIND CLUSTER NOTE:
Gateway API requires CRD installation and a controller. The tutorial should include installation steps for both.

RESOURCE GATE:
All CKA resources are in scope (generation order 28):
- GatewayClass, Gateway, HTTPRoute
- Services, Deployments, Pods
- Namespaces

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-ingress`.
- Debugging exercise headings are bare.
- Container images use explicit version tags.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/ingress-and-gateway-api/assignment-1: Ingress fundamentals
  - exercises/ingress-and-gateway-api/assignment-2: Advanced Ingress and TLS

- **Follow-up assignments:**
  - exercises/troubleshooting/assignment-4: Network troubleshooting

COURSE MATERIAL REFERENCE:
- S9 (Lectures 238-240): Gateway API
