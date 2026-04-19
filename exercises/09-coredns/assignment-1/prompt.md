I need you to create a comprehensive Kubernetes homework assignment to help me practice **DNS Fundamentals**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed 08-services/assignment-1 (ClusterIP Services)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers DNS record formats for services and pods, DNS policies, service discovery via DNS, and DNS query mechanics. CoreDNS configuration is covered in assignment-2. DNS troubleshooting is covered in assignment-3.

**In scope for this assignment:**

*Service DNS Format*
- Full format: <service>.<namespace>.svc.cluster.local
- Short form within namespace: <service>
- Cross-namespace: <service>.<namespace>
- cluster.local as default cluster domain
- Why FQDN matters for external domains

*Pod DNS Records*
- Pod DNS format: <pod-ip-dashed>.<namespace>.pod.cluster.local
- Example: 10-244-0-5.default.pod.cluster.local
- When pod DNS is used vs service DNS
- Headless service pod DNS: <pod-name>.<service>.<namespace>.svc.cluster.local

*DNS Policies in Pod Spec*
- spec.dnsPolicy: ClusterFirst (default): use cluster DNS, fall back to node DNS
- Default: inherit DNS from node
- None: no automatic DNS config, use spec.dnsConfig
- ClusterFirstWithHostNet: ClusterFirst for pods using host network
- When to use each policy

*Service Discovery via DNS*
- DNS-based discovery vs environment variables
- Querying services from pods
- SRV records for port discovery (conceptual)
- DNS caching in pods

*DNS Lookup Workflow*
- Pod's /etc/resolv.conf configuration
- nameserver: points to CoreDNS service
- search domains: <namespace>.svc.cluster.local, svc.cluster.local, cluster.local
- ndots:5 option and how it affects queries
- How short names become FQDNs

*DNS Queries from Pods*
- nslookup for basic queries
- dig for detailed DNS debugging
- Testing DNS from within pods
- Interpreting DNS responses

**Out of scope (covered in other assignments, do not include):**

- CoreDNS Deployment and configuration (exercises/09-09-coredns/assignment-2)
- Corefile structure and plugins (exercises/09-09-coredns/assignment-2)
- DNS troubleshooting (exercises/09-09-coredns/assignment-3)
- Service creation (exercises/08-08-services/assignment-1)
- Network Policies affecting DNS (exercises/10-network-policies/)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: coredns-tutorial.md
   - Explain service DNS format with examples
   - Show pod DNS records
   - Explain DNS policies and when to use each
   - Demonstrate DNS lookup workflow
   - Show nslookup and dig usage from pods
   - Use tutorial-coredns namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: coredns-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Service DNS**
   - Look up a service using short name
   - Look up a service using FQDN
   - Look up a service in another namespace

   **Level 2 (Exercises 2.1-2.3): Pod DNS and Policies**
   - Find pod DNS record
   - Test different DNS policies
   - Examine /etc/resolv.conf in pods

   **Level 3 (Exercises 3.1-3.3): Debugging DNS Queries**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: short name not resolving, wrong search domain, external domain query

   **Level 4 (Exercises 4.1-4.3): DNS Configuration**
   - Configure custom DNS with dnsConfig
   - Understand ndots and search domain behavior
   - Use dnsPolicy: None with custom config

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Exercise 5.1: Cross-namespace service discovery
   - Exercise 5.2: Debug DNS behavior with host network pod
   - Exercise 5.3: Design DNS strategy for multi-tier application

3. **Answer Key File**
   - Create the answer key: coredns-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Using IP instead of DNS name
     - Wrong DNS policy for host network pods
     - Not understanding search domains
     - External domains without trailing dot
     - ndots affecting query behavior
   - DNS commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of DNS Fundamentals assignment
   - Prerequisites: 08-services/assignment-1
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: multi-node kind cluster
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Multi-node kind cluster
- Services created for DNS testing
- Pods with nslookup/dig (busybox, dnsutils)
- kubectl client

RESOURCE GATE:
All CKA resources are in scope (generation order 20):
- Pods, Deployments
- Services
- ConfigMaps
- Namespaces

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-coredns`.
- Debugging exercise headings are bare.
- Container images: busybox:1.36, dnsutils images
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/08-08-services/assignment-1: Service basics

- **Follow-up assignments:**
  - exercises/09-09-coredns/assignment-2: CoreDNS configuration
  - exercises/09-09-coredns/assignment-3: DNS troubleshooting

COURSE MATERIAL REFERENCE:
- S9 (Lectures 227-230): DNS in Kubernetes, CoreDNS
