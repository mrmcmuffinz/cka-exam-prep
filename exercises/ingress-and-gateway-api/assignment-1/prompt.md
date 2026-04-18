I need you to create a comprehensive Kubernetes homework assignment to help me practice **Ingress Fundamentals**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed services/assignment-1
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers Ingress resource structure, controller deployment, path types, host-based routing, and basic Ingress creation. Advanced Ingress patterns and TLS are covered in assignment-2. Gateway API is covered in assignment-3.

**In scope for this assignment:**

*Ingress Resource Spec*
- apiVersion: networking.k8s.io/v1
- kind: Ingress
- spec.rules: list of routing rules
- spec.rules[].host: optional hostname for routing
- spec.rules[].http.paths: list of path-based routes
- spec.defaultBackend: catch-all backend

*Ingress Controller Deployment*
- Ingress resources require a controller
- nginx-ingress as the standard example
- Controller watches Ingress resources
- Controller configures underlying load balancer/proxy
- Installing nginx-ingress in kind

*Path Types*
- Prefix: matches URL path prefix
- Exact: matches URL path exactly
- ImplementationSpecific: controller decides
- Path matching priority (Exact > longest Prefix)
- Leading slash requirements

*Host-Based Routing*
- Routing to different backends by hostname
- spec.rules[].host field
- Wildcard hosts (*.example.com)
- No host (matches all hosts)
- Testing with /etc/hosts or curl --header

*Ingress Creation and Verification*
- Creating Ingress with kubectl apply
- kubectl get ingress
- kubectl describe ingress
- Checking Ingress ADDRESS
- Testing with curl

*Basic Troubleshooting*
- Backend not found: service does not exist
- No endpoints: service has no ready pods
- Ingress no address: controller not running
- Path not matching: wrong pathType

**Out of scope (covered in other assignments, do not include):**

- Ingress annotations and rewrite-target (exercises/ingress-and-gateway-api/assignment-2)
- TLS termination (exercises/ingress-and-gateway-api/assignment-2)
- Gateway API (exercises/ingress-and-gateway-api/assignment-3)
- Services in depth (exercises/services/)
- Network Policies (exercises/network-policies/)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: ingress-and-gateway-api-tutorial.md
   - Explain what Ingress provides (L7 routing)
   - Include nginx-ingress installation for kind
   - Walk through Ingress resource structure
   - Demonstrate path-based routing
   - Demonstrate host-based routing
   - Show verification and basic troubleshooting
   - Use tutorial-ingress namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: ingress-and-gateway-api-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Basic Ingress Creation**
   - Create Ingress with single backend
   - Verify Ingress address assignment
   - Test Ingress with curl

   **Level 2 (Exercises 2.1-2.3): Path and Host Routing**
   - Create Ingress with multiple paths
   - Create Ingress with multiple hosts
   - Test different path types

   **Level 3 (Exercises 3.1-3.3): Debugging Ingress Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: backend service not found, path not matching, no address assigned

   **Level 4 (Exercises 4.1-4.3): Advanced Routing**
   - Configure default backend
   - Use wildcard hosts
   - Multiple services on different paths

   **Level 5 (Exercises 5.1-5.3): Application Scenarios**
   - Exercise 5.1: Multi-service application with path routing
   - Exercise 5.2: Debug complex routing issue
   - Exercise 5.3: Design Ingress strategy for microservices

3. **Answer Key File**
   - Create the answer key: ingress-and-gateway-api-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Ingress controller not installed
     - Service name or port wrong
     - PathType mismatch
     - Host not matching request
     - Backend service has no endpoints
   - Ingress debugging cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Ingress Fundamentals assignment
   - Prerequisites: services/assignment-1
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: multi-node kind with nginx-ingress
   - nginx-ingress installation instructions
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Multi-node kind cluster
- nginx-ingress controller installed
- kubectl client

KIND CLUSTER NOTE:
Kind requires special configuration for Ingress to work. Include the kind cluster config with extra port mappings:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
```

RESOURCE GATE:
All CKA resources are in scope (generation order 26):
- Ingress
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
  - exercises/services/assignment-1: Service basics

- **Follow-up assignments:**
  - exercises/ingress-and-gateway-api/assignment-2: Advanced Ingress and TLS
  - exercises/ingress-and-gateway-api/assignment-3: Gateway API

COURSE MATERIAL REFERENCE:
- S9 (Lectures 231-237): Ingress controllers, resources, annotations
