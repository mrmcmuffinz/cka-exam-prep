I need you to create a comprehensive Kubernetes homework assignment to help me practice **Kubernetes Services**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S9 (through lecture 226, covering Core Concepts, Scheduling, Logging & Monitoring, Application Lifecycle Management, Cluster Maintenance, Security, Storage, and Networking through Service networking)
- I have completed all pod assignments (1-7) and understand Deployments, which will serve as service backends
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers how Kubernetes Services expose applications, how pods discover and communicate with services, and how the different service types provide varying levels of external access. Pod fundamentals, workload controllers (especially Deployments), and basic networking concepts are assumed knowledge. DNS configuration, Ingress, Gateway API, and Network Policies will get their own dedicated assignments later and MUST NOT appear here beyond what is necessary to demonstrate service discovery.

**In scope for this assignment:**

*Service Types and Mechanics*
- ClusterIP services: the default service type, internal cluster access only, stable virtual IP within cluster CIDR
- NodePort services: builds on ClusterIP, exposes service on a static port (30000-32767 range) on every node, enables external access
- LoadBalancer services: builds on NodePort, provisions external load balancer (cloud provider integration, metallb for kind)
- ExternalName services: maps service to a DNS name (CNAME), no selectors, no proxying, used for external service abstraction
- Headless services: ClusterIP set to None, returns pod IPs directly instead of service IP, used for StatefulSet and client-side load balancing

*Service Configuration*
- Service spec fields: type, selector, ports (port, targetPort, nodePort, protocol), clusterIP, externalName
- Port naming and its role in multi-port services
- Port mapping: service port vs. targetPort vs. nodePort, when each matters
- Protocol field: TCP (default) and UDP
- sessionAffinity: ClientIP for sticky sessions, timeoutSeconds
- externalTrafficPolicy: Cluster (default, distributes across all pods) vs. Local (preserves source IP, only routes to node-local pods)

*Service Discovery*
- Environment variables injected into pods: `<SERVICE_NAME>_SERVICE_HOST`, `<SERVICE_NAME>_SERVICE_PORT`, format and ordering constraints
- DNS-based discovery: `<service>.<namespace>.svc.cluster.local`, short-form `<service>` within same namespace, cluster domain suffix
- When to prefer DNS over environment variables (dynamic services, services created after pods)

*Endpoints and EndpointSlices*
- Endpoints objects: how Kubernetes maps service selectors to pod IPs and ports
- Inspecting endpoints to diagnose service issues: `kubectl get endpoints <service>`, empty endpoints as symptom of selector mismatch
- EndpointSlices as the scalable replacement for Endpoints (conceptual understanding, observable via `kubectl get endpointslices`)
- Manual endpoints for services without selectors (external services, custom backends)

*Service and Pod Integration*
- How service selectors match pod labels (label equality, multiple labels as AND condition)
- Impact of pod readiness on service endpoints: only Ready pods are included, readiness probe failures remove pod from endpoints
- Service updates when pods are added, removed, or become unready
- Traffic distribution: default round-robin behavior, kube-proxy role (iptables vs. ipvs modes conceptually)

*Debugging and Verification*
- Verifying service creation and configuration: `kubectl get service`, `kubectl describe service`
- Checking endpoints to confirm pod selection: `kubectl get endpoints`
- Testing service connectivity from within the cluster: `kubectl run` for temporary test pods, curl/wget to service IP or DNS name
- Diagnosing common issues: wrong selector, wrong targetPort, pods not ready, service created before pods (environment variables missing)
- Using `kubectl get svc -o wide` to see selectors at a glance

*Service Networking Concepts*
- Service CIDR vs. pod CIDR (distinct IP ranges, service IPs are virtual, not routable outside cluster)
- kube-proxy role in service routing (iptables/ipvs rules, not in scope to manipulate directly, but understanding it manages service traffic)
- ClusterIP allocation (automatic within service CIDR, can be specified manually for idempotent creation)
- NodePort allocation (automatic within range, can be specified for well-known ports)

**Out of scope (covered in other assignments, do not include):**

- CoreDNS configuration, Corefile structure, DNS debugging with nslookup/dig (exercises/09-09-coredns/assignment-1). DNS discovery is in scope, but DNS troubleshooting and CoreDNS internals are not.
- Network Policies for filtering traffic to services (exercises/10-10-network-policies/assignment-1)
- Ingress resources and Ingress controllers (exercises/11-11-ingress-and-gateway-api/assignment-1)
- Gateway API (GatewayClass, Gateway, HTTPRoute) (exercises/11-11-ingress-and-gateway-api/assignment-1)
- TLS termination at the service or ingress layer (exercises/11-11-ingress-and-gateway-api/assignment-1)
- Pod scheduling, node affinity, taints, tolerations (exercises/01-01-pods/assignment-4). Exercises may use nodeSelector for simple placement, but scheduling is not the focus.
- Resource requests and limits, QoS classes (exercises/01-01-pods/assignment-5). Service backends may specify resources, but tuning them is not the focus.
- Multi-container patterns beyond simple Deployment backends (exercises/01-01-pods/assignment-6)
- Deployment strategies, rollouts, rollbacks (exercises/01-01-pods/assignment-7). Deployments are used as service backends, but rollout mechanics are assumed knowledge.
- StatefulSets and their integration with headless services (not covered in CKA exam, only headless service mechanics are in scope)
- Service mesh concepts (Istio, Linkerd, etc.)
- External load balancer provider configuration beyond metallb setup for kind
- kube-proxy mode switching or advanced configuration
- Custom kube-proxy iptables/ipvs rule manipulation
- Service topology (deprecated feature)

Service backends in this assignment should be Deployments with 2-3 replicas running nginx, httpd, or simple busybox http servers. Avoid introducing StatefulSets or advanced workload controllers. When demonstrating headless services, show how DNS returns multiple pod IPs, but do not dive into StatefulSet-specific behavior.

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: services-tutorial.md
   - Complete step-by-step tutorial showing how to create services of each type, verify their configuration, test connectivity, and understand service discovery mechanisms
   - Include BOTH imperative (kubectl expose, kubectl create service) AND declarative (YAML) approaches
   - Be explicit about when imperative is practical (exposing existing Deployments with kubectl expose) versus when declarative is required (ExternalName services, custom port mappings, sessionAffinity)
   - Explain every service type with a worked example: ClusterIP, NodePort, LoadBalancer (with metallb in kind), ExternalName, headless
   - Demonstrate service discovery via environment variables and DNS, including short-form and FQDN
   - Show how to inspect endpoints and correlate them with pod IPs and readiness state
   - Demonstrate debugging: wrong selector (empty endpoints), wrong targetPort (connection refused), pod not ready (missing from endpoints)
   - Use a dedicated tutorial namespace (tutorial-services) so learners can work through examples without conflicting with homework exercises
   - Include cleanup commands at the end of each major section

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: services-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)
   - Each exercise is self-contained with setup commands (create namespace, create deployment/pods, etc.) and verification commands
   - Every exercise uses its own namespace: ex-1-1, ex-1-2, ex-1-3, ex-2-1, ..., ex-5-3

   **Level 1 (Exercises 1.1-1.3): Basic Service Creation**
   - Create ClusterIP services using both imperative (kubectl expose) and declarative (YAML) approaches
   - Verify service creation and inspect basic configuration
   - Test connectivity from a temporary pod using service IP and DNS name

   **Level 2 (Exercises 2.1-2.3): Service Types and Discovery**
   - Create NodePort and LoadBalancer services
   - Demonstrate service discovery via environment variables and DNS (both short-form and FQDN)
   - Create a headless service and observe multiple pod IP responses
   - Create an ExternalName service for an external endpoint

   **Level 3 (Exercises 3.1-3.3): Debugging Broken Services**
   - Three debugging exercises with broken service configurations
   - Exercise headings are bare (### Exercise 3.1) with no descriptive titles to avoid spoilers
   - Scenarios: wrong selector (empty endpoints), wrong targetPort (connection fails), pod not ready (missing from endpoints)
   - Each exercise provides broken YAML in the setup and asks the learner to diagnose and fix

   **Level 4 (Exercises 4.1-4.3): Multi-Port Services and Advanced Configuration**
   - Create services with multiple ports (named ports, different protocols)
   - Configure sessionAffinity for sticky sessions
   - Configure externalTrafficPolicy: Local to preserve source IP on NodePort services
   - Create a service without selectors and manually define endpoints

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios and Advanced Debugging**
   - Exercise 5.1: Complex multi-tier application (frontend service -> backend service -> database headless service)
   - Exercise 5.2: Debugging exercise with multiple failure modes (wrong selector + wrong targetPort + pod not ready)
   - Exercise 5.3: Service migration scenario (change service type from ClusterIP to NodePort, preserve backend, verify no downtime)

3. **Answer Key File**
   - Create the answer key: services-homework-answers.md
   - Full solutions for all 15 exercises with explanations
   - For debugging exercises (Level 3 and 5.2), include diagnostic workflow: what to check first, what kubectl commands to run, what the symptoms tell you
   - Common mistakes section covering:
     - Forgetting that service and pod ports are independent (targetPort must match container port, not service port)
     - Selector mismatch (service selector doesn't match any pod labels)
     - Creating service before deployment (environment variables not injected)
     - Using LoadBalancer type without metallb or cloud provider (service stays in Pending state)
     - Confusing service IP (virtual, cluster-internal) with pod IP (real, routable within cluster)
     - Not understanding that NodePort makes the service accessible on EVERY node, not just one
     - Assuming externalTrafficPolicy: Local provides load balancing across all pods (it only routes to node-local pods)
   - Verification commands cheat sheet (kubectl get svc, kubectl get endpoints, kubectl describe svc, test connectivity from temporary pod)

4. **README File for the Assignment**
   - Create: README.md
   - Overview of the Services assignment and its place in the CKA exam prep series
   - Prerequisites: 01-pods/assignment-7 (Deployments), basic networking understanding
   - Estimated time commitment: 4-6 hours (tutorial 2 hours, homework 2-3 hours, review 1 hour)
   - Cluster requirements: multi-node kind cluster (1 control-plane, 3 workers)
   - metallb setup instructions for LoadBalancer services in kind
   - Recommended workflow: read tutorial, work exercises, compare with answers
   - Link to the homework plan (cka-homework-plan.md) for context on where this fits

ENVIRONMENT REQUIREMENTS:
- Multi-node kind cluster (1 control-plane, 3 workers)
- metallb or similar local load balancer provisioner for LoadBalancer service type testing
- No special CNI requirements (default kindnet is sufficient, NetworkPolicy support not needed for this assignment)
- kubectl client (any recent version, no specific version requirements)

RESOURCE GATE:
All CKA resources are in scope. This assignment unlocks after the Networking section (generation order 4), so learners have encountered Deployments, ConfigMaps, Secrets, and all pod-related resources. Exercises may use any resource type covered in prior assignments (pods, Deployments, ConfigMaps) as needed to demonstrate service functionality.

KIND CLUSTER SETUP:
Learners should already have the multi-node kind cluster from exercises/01-01-pods/assignment-4. If not, provide the kind config file for creating a multi-node cluster:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
```

Create the cluster with:
```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster --config kind-multi-node.yaml
```

METALLB SETUP:
LoadBalancer services in kind require a local load balancer provisioner. The tutorial should include setup instructions for metallb:

1. Install metallb manifests
2. Configure IP address pool from Docker/nerdctl network range (detect with `docker network inspect kind` or `nerdctl network inspect kind`)
3. Verify metallb is running and can assign external IPs to LoadBalancer services

CONVENTIONS:
- No em dashes anywhere in generated content. Use commas, periods, or parentheses.
- Narrative paragraph flow in prose sections, not stacked single-sentence bullet points.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern (for example, ex-3-2 for Level 3, Exercise 2).
- Tutorial namespace is `tutorial-services`.
- Debugging exercise headings are bare (### Exercise 3.1) with no descriptive titles that would hint at the problem.
- Container images use explicit version tags: nginx:1.25, httpd:2.4, busybox:1.36
- Service backends are Deployments with 2-3 replicas unless the exercise specifically requires a different configuration
- When testing connectivity, use temporary pods with curl or wget (kubectl run curl-test --image=curlimages/curl:8.1.0 --rm -it -- curl <target>)
- Base64 encoding uses `base64 -w0` for Secrets if needed (though Secrets are not the focus of this assignment)
- Full file replacements when generating, never patches or diffs

CROSS-REFERENCES:
- **Prerequisites (must be completed first):**
  - exercises/01-01-pods/assignment-7 (Workload Controllers): Learners need to understand Deployments, which serve as service backends throughout this assignment
  - exercises/01-01-pods/assignment-3 (Pod Health and Observability): Understanding readiness probes is necessary to understand how services manage endpoints based on pod readiness

- **Follow-up assignments (reference these in the README for what comes next):**
  - exercises/09-09-coredns/assignment-1: DNS configuration, CoreDNS internals, DNS debugging with nslookup/dig
  - exercises/10-10-network-policies/assignment-1: Filtering traffic to services using Network Policies
  - exercises/11-11-ingress-and-gateway-api/assignment-1: L7 routing to services with Ingress and Gateway API

- **Related assignments:**
  - exercises/19-19-troubleshooting/assignment-4: Network troubleshooting, which includes service resolution failures and endpoint debugging

COURSE MATERIAL REFERENCE:
This assignment aligns with Mumshad CKA course sections:
- S2 (Lectures 33-37): Services (ClusterIP, NodePort, LoadBalancer) - introduces service types and basic mechanics
- S9 (Lectures 223-226): Service networking - covers service CIDR, kube-proxy, endpoint management

Learners should have watched these sections before starting this assignment. The tutorial should reference course concepts where appropriate but not duplicate lecture content verbatim. The exercises should test hands-on application of the concepts taught in those sections.

EXERCISE DESIGN GUIDANCE:
- Favor realistic scenarios over contrived examples. Services exist to expose applications, so every service should have a meaningful backend (usually a Deployment running a simple web server).
- In debugging exercises, the symptoms should be what a kubectl user would observe (empty endpoints, connection refused, DNS resolution succeeds but connection fails), not abstract descriptions.
- Avoid exercises that require deep knowledge of kube-proxy iptables rules or ipvs configuration. Understanding the role of kube-proxy is in scope, but manipulating its configuration is not.
- LoadBalancer exercises should acknowledge that LoadBalancer services are cloud-specific and explain why metallb is needed in kind.
- Headless service exercises should show how DNS returns multiple A records (one per pod), but do not introduce StatefulSet concepts like stable pod identities.
- Multi-port service exercises should use realistic scenarios: an application server with an HTTP port and a metrics port, or a database with primary and secondary ports.
