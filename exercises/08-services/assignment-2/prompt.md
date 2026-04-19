I need you to create a comprehensive Kubernetes homework assignment to help me practice **External Service Types**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed 08-services/assignment-1 (ClusterIP Services)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers NodePort services, LoadBalancer services, ExternalName services, and services without selectors. ClusterIP fundamentals are assumed knowledge from assignment-1. Advanced service patterns and troubleshooting are covered in assignment-3.

**In scope for this assignment:**

*NodePort Services*
- Building on ClusterIP: same internal access plus external port
- NodePort port range: 30000-32767
- Automatic vs manual port allocation
- Accessing service via <NodeIP>:<NodePort>
- Every node opens the NodePort, regardless of where pods run
- kube-proxy role in NodePort routing

*NodePort Port Allocation and Behavior*
- spec.ports[].nodePort: specify port or let Kubernetes allocate
- Port collision prevention
- How kube-proxy routes external traffic
- Preserving source IP with externalTrafficPolicy

*LoadBalancer Services*
- Building on NodePort: adds external load balancer
- Cloud provider integration (conceptual)
- spec.loadBalancerIP: request specific external IP (if supported)
- status.loadBalancer.ingress: external IP or hostname
- metallb for LoadBalancer services in kind

*LoadBalancer in Kind Clusters*
- Kind does not natively provision load balancers
- metallb as local load balancer provisioner
- Configuring metallb IP address pool
- LoadBalancer service stuck in Pending without metallb

*ExternalName Services*
- No selector, no ClusterIP
- spec.type: ExternalName with spec.externalName
- Returns CNAME record pointing to external DNS name
- Use cases: external database, third-party API, cross-cluster services
- No proxying or port mapping, pure DNS alias

*Services Without Selectors*
- Creating service without spec.selector
- Manually creating Endpoints resource
- Use cases: external services, custom backends, database clusters
- Endpoints spec: addresses and ports
- EndpointSlices for scalable external services

**Out of scope (covered in other assignments, do not include):**

- ClusterIP basics (exercises/08-08-services/assignment-1)
- Service selectors and label matching (exercises/08-08-services/assignment-1)
- Endpoints inspection in depth (exercises/08-08-services/assignment-1)
- Service discovery (exercises/08-08-services/assignment-1)
- Headless services (exercises/08-08-services/assignment-1)
- Multi-port services (exercises/08-08-services/assignment-3)
- Session affinity (exercises/08-08-services/assignment-3)
- Service troubleshooting (exercises/08-08-services/assignment-3)
- Ingress and Gateway API (exercises/11-ingress-and-gateway-api/)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: services-tutorial.md (section 2)
   - Explain NodePort services with examples
   - Demonstrate LoadBalancer services with metallb
   - Explain ExternalName services
   - Show services without selectors with manual endpoints
   - Discuss when to use each type
   - Use tutorial-services namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: services-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): NodePort Services**
   - Create NodePort service with automatic port
   - Create NodePort service with specific port
   - Access service via node IP and NodePort

   **Level 2 (Exercises 2.1-2.3): LoadBalancer and ExternalName**
   - Create LoadBalancer service (with metallb)
   - Create ExternalName service
   - Compare different service types

   **Level 3 (Exercises 3.1-3.3): Debugging External Service Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: LoadBalancer stuck pending, NodePort not accessible, ExternalName not resolving

   **Level 4 (Exercises 4.1-4.3): Manual Endpoints**
   - Create service without selector
   - Create manual Endpoints resource
   - Update endpoints when backend changes

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Exercise 5.1: External database service with manual endpoints
   - Exercise 5.2: Migrate from NodePort to LoadBalancer
   - Exercise 5.3: Design external access strategy for application

3. **Answer Key File**
   - Create the answer key: services-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - NodePort outside valid range
     - LoadBalancer without cloud provider or metallb
     - ExternalName with IP address (must be DNS name)
     - Endpoints not matching service port
     - Forgetting that NodePort opens on all nodes
   - External service commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of External Service Types assignment
   - Prerequisites: 08-services/assignment-1
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: multi-node kind cluster with metallb
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Multi-node kind cluster
- metallb installed for LoadBalancer exercises
- Access to node IPs for NodePort testing
- kubectl client

RESOURCE GATE:
All CKA resources are in scope (generation order 18):
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

- **Follow-up assignments:**
  - exercises/08-08-services/assignment-3: Service patterns and troubleshooting
  - exercises/11-11-ingress-and-gateway-api/assignment-1: L7 routing

COURSE MATERIAL REFERENCE:
- S2 (Lectures 33-37): Services (ClusterIP, NodePort, LoadBalancer)
- S9 (Lectures 223-226): Service networking
