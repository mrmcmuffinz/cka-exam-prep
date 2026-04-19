I need you to create a comprehensive Kubernetes homework assignment to help me practice **DNS Troubleshooting**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed 09-coredns/assignment-1 and assignment-2
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers diagnosing and resolving DNS issues: resolution failures, CoreDNS problems, policy misconfigurations, and integration issues. DNS fundamentals (assignment-1) and CoreDNS configuration (assignment-2) are assumed knowledge.

**In scope for this assignment:**

*Diagnosing DNS Resolution Failures*
- Symptoms: service not found, unknown host, timeout
- Testing DNS from different pods
- Comparing working vs non-working pods
- Using nslookup and dig for diagnosis
- Checking /etc/resolv.conf in problem pods

*CoreDNS Pod Failures*
- CoreDNS pods not running
- CoreDNS crashlooping
- Resource exhaustion
- OOMKilled CoreDNS pods
- Checking CoreDNS logs for errors
- CoreDNS unable to reach upstream

*DNS Policy Misconfigurations*
- Wrong dnsPolicy for pod type
- Host network pod with wrong policy
- dnsPolicy: None without dnsConfig
- Search domains missing or wrong

*Network Policies Blocking DNS*
- Default deny blocking UDP 53
- Missing egress to kube-dns
- Namespace isolation affecting DNS
- Debugging with Network Policy rules

*DNS Caching Issues*
- Stale cache entries
- Negative caching problems
- Cache TTL too long
- Forcing cache refresh

*Service DNS Not Resolving*
- Service does not exist
- Service in wrong namespace
- Using wrong DNS name format
- Headless service DNS differences

**Out of scope (covered in other assignments, do not include):**

- DNS fundamentals (exercises/09-09-coredns/assignment-1)
- CoreDNS configuration basics (exercises/09-09-coredns/assignment-2)
- Network Policy creation (exercises/10-network-policies/)
- Cross-domain troubleshooting (exercises/19-19-troubleshooting/assignment-4)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: coredns-tutorial.md (section 3)
   - Explain DNS troubleshooting methodology
   - Walk through common DNS failure scenarios
   - Show diagnostic commands and interpretation
   - Demonstrate CoreDNS log analysis
   - Show Network Policy DNS considerations
   - Use tutorial-coredns namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: coredns-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Basic DNS Diagnostics**
   - Test DNS resolution from a pod
   - Compare resolv.conf between pods
   - Check CoreDNS service availability

   **Level 2 (Exercises 2.1-2.3): CoreDNS Health**
   - Check CoreDNS pod status
   - View CoreDNS logs
   - Verify CoreDNS endpoints

   **Level 3 (Exercises 3.1-3.3): Debugging DNS Failures**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: CoreDNS not running, DNS policy wrong, service name typo

   **Level 4 (Exercises 4.1-4.3): Complex DNS Issues**
   - Debug Network Policy blocking DNS
   - Diagnose caching issue
   - Troubleshoot cross-namespace DNS

   **Level 5 (Exercises 5.1-5.3): Multi-Factor Failures**
   - Exercise 5.1: Multiple DNS problems in one cluster
   - Exercise 5.2: Intermittent DNS failures
   - Exercise 5.3: Create DNS troubleshooting runbook

3. **Answer Key File**
   - Create the answer key: coredns-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Not checking if CoreDNS is running first
     - Forgetting Network Policy affects DNS
     - Testing from wrong namespace
     - Cache masking the real issue
     - Not checking CoreDNS logs
   - DNS troubleshooting flowchart

4. **README File for the Assignment**
   - Create: README.md
   - Overview of DNS Troubleshooting assignment
   - Prerequisites: 09-coredns/assignment-1, assignment-2
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: multi-node kind cluster
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Multi-node kind cluster
- Pods with DNS debugging tools
- kubectl client

RESOURCE GATE:
All CKA resources are in scope (generation order 22):
- CoreDNS resources
- Services, Pods
- Network Policies (for testing)
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
  - exercises/09-09-coredns/assignment-2: CoreDNS configuration

- **Follow-up assignments:**
  - exercises/19-19-troubleshooting/assignment-4: Network troubleshooting

COURSE MATERIAL REFERENCE:
- S9 (Lectures 227-230): DNS in Kubernetes, CoreDNS
- S14 (Lectures 295-296): Network troubleshooting
