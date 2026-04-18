I need you to create a comprehensive Kubernetes homework assignment to help me practice **Capabilities and Privilege Control**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S7 (through security contexts)
- I have completed security-contexts/assignment-1 (user/group security)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers Linux capabilities in Kubernetes: adding and dropping capabilities, understanding default capabilities, and controlling privilege escalation with allowPrivilegeEscalation. User and group identity (assignment-1) is assumed knowledge. Filesystem constraints and seccomp profiles are covered in assignment-3.

**In scope for this assignment:**

*Linux Capabilities Overview*
- What capabilities are: fine-grained privileges replacing all-or-nothing root
- Common capabilities: NET_ADMIN, SYS_TIME, SYS_ADMIN, NET_RAW, SETUID, SETGID, CHOWN
- How capabilities differ from running as root
- Capability sets: permitted, effective, inheritable (conceptual)

*Adding Capabilities*
- capabilities.add field in securityContext
- Common use cases: NET_ADMIN for network configuration, SYS_TIME for clock adjustment
- Adding capabilities to non-root containers
- Verifying capabilities with capsh or /proc/self/status

*Dropping Capabilities*
- capabilities.drop field in securityContext
- Dropping ALL and then adding specific capabilities (defense in depth)
- Common capabilities to drop: NET_RAW, SETUID, SETGID, CHOWN
- Why dropping capabilities improves security
- Verifying capabilities were dropped

*Default Capabilities from Container Runtime*
- What capabilities containerd grants by default
- Difference between privileged and unprivileged containers
- How default capabilities affect security posture
- Auditing default capabilities

*allowPrivilegeEscalation*
- What allowPrivilegeEscalation controls: setuid binaries, capability acquisition
- Setting to false to prevent privilege escalation
- Relationship to runAsNonRoot
- When allowPrivilegeEscalation must be false (security best practices)
- Verifying privilege escalation is blocked

*Privilege Escalation Prevention Patterns*
- Combining runAsNonRoot with allowPrivilegeEscalation: false
- Dropping ALL capabilities and adding only required
- Defense in depth with multiple controls
- When applications need privilege escalation (and alternatives)

**Out of scope (covered in other assignments, do not include):**

- runAsUser, runAsGroup, fsGroup (exercises/security-contexts/assignment-1)
- supplementalGroups (exercises/security-contexts/assignment-1)
- readOnlyRootFilesystem (exercises/security-contexts/assignment-3)
- seccomp profiles (exercises/security-contexts/assignment-3)
- Pod Security Standards/Admission (exercises/pod-security/assignment-1)
- Network Policies (exercises/network-policies/)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: security-contexts-tutorial.md (section 2)
   - Explain Linux capabilities and why they matter
   - Demonstrate adding and dropping capabilities
   - Show how to verify capabilities inside containers
   - Explain allowPrivilegeEscalation and demonstrate its effect
   - Show defense-in-depth patterns
   - Use tutorial-security-contexts namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: security-contexts-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Inspecting Capabilities**
   - Check default capabilities in a container
   - Run a privileged container and compare capabilities
   - Verify capability sets with /proc/self/status

   **Level 2 (Exercises 2.1-2.3): Adding and Dropping Capabilities**
   - Add NET_ADMIN capability and verify with ip command
   - Drop NET_RAW capability and verify ping fails
   - Drop ALL and add only required capabilities

   **Level 3 (Exercises 3.1-3.3): Debugging Capability Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: operation fails due to missing capability, container needs capability it does not have, allowPrivilegeEscalation blocking expected behavior

   **Level 4 (Exercises 4.1-4.3): Privilege Escalation Control**
   - Configure allowPrivilegeEscalation: false and verify
   - Combine multiple security controls for defense in depth
   - Test setuid binary behavior with different settings

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Exercise 5.1: Configure minimal capability set for a specific application
   - Exercise 5.2: Debug application failing due to security constraints
   - Exercise 5.3: Design capability strategy for multi-container pod

3. **Answer Key File**
   - Create the answer key: security-contexts-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Adding capability but not enabling it at runtime
     - Dropping ALL without adding required capabilities
     - Confusing privileged mode with individual capabilities
     - allowPrivilegeEscalation not affecting existing processes
     - Capability names without CAP_ prefix in Kubernetes
   - Capability debugging commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Capabilities and Privilege Control assignment
   - Prerequisites: security-contexts/assignment-1
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- Container images with capability testing tools or ability to exec
- No special cluster configuration needed

RESOURCE GATE:
This assignment uses a restricted resource gate (generation order 9):
- Pods with securityContext.capabilities
- ConfigMaps, Secrets
- Namespaces
- Do NOT use: Services, PersistentVolumes, NetworkPolicies

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-security-contexts`.
- Debugging exercise headings are bare.
- Container images use explicit version tags.
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/security-contexts/assignment-1: User and group security

- **Follow-up assignments:**
  - exercises/security-contexts/assignment-3: Filesystem and seccomp profiles

COURSE MATERIAL REFERENCE:
- S7 (Lectures 175-178): Security contexts, capabilities
