I need you to create a comprehensive Kubernetes homework assignment to help me practice **CoreDNS Configuration**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed 09-coredns/assignment-1 (DNS Fundamentals)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers CoreDNS Deployment, ConfigMap, Corefile structure, plugins, and configuration customization. DNS fundamentals are assumed knowledge from assignment-1. DNS troubleshooting is covered in assignment-3.

**In scope for this assignment:**

*CoreDNS Deployment in kube-system*
- CoreDNS runs as Deployment in kube-system namespace
- CoreDNS Service (kube-dns) provides stable DNS endpoint
- Pod anti-affinity for high availability
- Resource requests and limits
- Viewing CoreDNS pods: kubectl get pods -n kube-system

*CoreDNS ConfigMap and Corefile*
- ConfigMap: coredns in kube-system
- Corefile: main configuration file
- Server blocks: define listener and zones
- How to view: kubectl get configmap coredns -n kube-system -o yaml

*CoreDNS Plugins*
- kubernetes: cluster DNS records
- forward: upstream DNS servers
- cache: response caching
- errors: error logging
- health: health check endpoint
- ready: readiness check
- loop: loop detection
- reload: hot reload configuration

*CoreDNS Configuration Customization*
- Adding custom DNS records
- Configuring upstream DNS servers
- Stub domains for enterprise DNS
- Adding logging
- Modifying cache TTL
- How changes take effect (automatic reload)

*CoreDNS Logging and Verbosity*
- log plugin for query logging
- errors plugin for error output
- Debug logging configuration
- Viewing logs: kubectl logs

*CoreDNS Performance Tuning*
- Cache sizing
- Negative cache settings
- Pod count scaling
- Resource allocation
- Monitoring CoreDNS metrics (conceptual)

**Out of scope (covered in other assignments, do not include):**

- DNS fundamentals (exercises/09-09-coredns/assignment-1)
- DNS troubleshooting (exercises/09-09-coredns/assignment-3)
- Network Policies (exercises/10-network-policies/)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: coredns-tutorial.md (section 2)
   - Explain CoreDNS Deployment and Service
   - Walk through Corefile structure
   - Explain each plugin and its role
   - Demonstrate configuration customization
   - Show logging configuration
   - Use tutorial-coredns namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: coredns-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): CoreDNS Exploration**
   - List CoreDNS pods and service
   - View CoreDNS ConfigMap
   - Identify plugins in Corefile

   **Level 2 (Exercises 2.1-2.3): Configuration Basics**
   - Understand kubernetes plugin configuration
   - Understand forward plugin configuration
   - View CoreDNS logs

   **Level 3 (Exercises 3.1-3.3): Debugging Configuration Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: syntax error in Corefile, missing plugin, wrong upstream server

   **Level 4 (Exercises 4.1-4.3): Customization**
   - Add custom DNS entry
   - Configure logging
   - Modify cache settings

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Exercise 5.1: Configure stub domain for enterprise DNS
   - Exercise 5.2: Troubleshoot custom configuration
   - Exercise 5.3: Design CoreDNS configuration for requirements

3. **Answer Key File**
   - Create the answer key: coredns-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Syntax errors in Corefile
     - Plugin order matters
     - Not waiting for reload
     - Wrong ConfigMap name or namespace
     - Breaking cluster DNS with bad config
   - CoreDNS configuration cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of CoreDNS Configuration assignment
   - Prerequisites: 09-coredns/assignment-1
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: multi-node kind cluster
   - Warning about careful ConfigMap editing
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Multi-node kind cluster
- Access to kube-system namespace
- kubectl client

RESOURCE GATE:
All CKA resources are in scope (generation order 21):
- CoreDNS ConfigMap
- CoreDNS Deployment and Pods
- Services
- Namespaces

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-coredns`.
- Debugging exercise headings are bare.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/09-09-coredns/assignment-1: DNS fundamentals

- **Follow-up assignments:**
  - exercises/09-09-coredns/assignment-3: DNS troubleshooting

COURSE MATERIAL REFERENCE:
- S9 (Lectures 227-230): DNS in Kubernetes, CoreDNS
