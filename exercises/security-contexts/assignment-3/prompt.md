I need you to create a comprehensive Kubernetes homework assignment to help me practice **Filesystem and seccomp Profiles**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S7 (through security contexts)
- I have completed security-contexts/assignment-1 and assignment-2
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers filesystem constraints (readOnlyRootFilesystem) and seccomp profiles for syscall filtering. User/group identity (assignment-1) and capabilities (assignment-2) are assumed knowledge.

**In scope for this assignment:**

*readOnlyRootFilesystem*
- Setting readOnlyRootFilesystem: true in securityContext
- What it prevents: writing to container filesystem
- Why it matters: prevents container escape, limits malware persistence
- Symptoms when enabled: "Read-only file system" errors

*Combining readOnlyRootFilesystem with Writable Mounts*
- Using emptyDir for temporary writable storage (/tmp, /var/run)
- ConfigMap and Secret mounts (already read-only)
- Application patterns: write logs to emptyDir, store temp files
- Identifying what directories an application needs to write to

*seccomp Profiles*
- What seccomp does: filters system calls at kernel level
- Three profile types: RuntimeDefault, Localhost, Unconfined
- RuntimeDefault: containerd's default profile, blocks dangerous syscalls
- Unconfined: no filtering (not recommended for production)
- Localhost: custom profile from node filesystem

*Using seccomp Profiles*
- seccompProfile field in securityContext
- Pod-level vs container-level profiles
- Specifying RuntimeDefault explicitly
- Specifying Localhost with localhostProfile path
- Verifying which profile is applied

*Creating Custom seccomp Profiles*
- seccomp profile JSON format
- defaultAction: SCMP_ACT_ALLOW or SCMP_ACT_ERRNO
- syscalls array: names and action
- Common syscalls to allow/deny
- Profile location on nodes (/var/lib/kubelet/seccomp/)

*seccomp Profile Debugging*
- Diagnosing syscall blocks: audit log, strace
- Identifying which syscalls an application needs
- Iterating on custom profiles
- Symptoms of seccomp blocking: unexpected failures, "operation not permitted"

*Security Context Best Practices*
- Defense in depth: combining all security controls
- Recommended baseline: runAsNonRoot, readOnlyRootFilesystem, drop ALL capabilities, RuntimeDefault seccomp
- Trade-offs between security and application compatibility
- Testing security contexts before deployment

**Out of scope (covered in other assignments, do not include):**

- runAsUser, runAsGroup, fsGroup (exercises/security-contexts/assignment-1)
- Capabilities (exercises/security-contexts/assignment-2)
- allowPrivilegeEscalation (exercises/security-contexts/assignment-2)
- Pod Security Standards/Admission (not in current CKA scope)
- Network Policies (exercises/network-policies/)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: security-contexts-tutorial.md (section 3)
   - Explain readOnlyRootFilesystem and why to use it
   - Demonstrate combining read-only root with writable mounts
   - Explain seccomp and the three profile types
   - Show how to apply seccomp profiles
   - Demonstrate creating a simple custom seccomp profile
   - Summarize security context best practices
   - Use tutorial-security-contexts namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: security-contexts-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Read-Only Filesystem**
   - Enable readOnlyRootFilesystem and verify writes fail
   - Add emptyDir mount for writable /tmp
   - Identify directories an application needs to write to

   **Level 2 (Exercises 2.1-2.3): seccomp Basics**
   - Apply RuntimeDefault seccomp profile explicitly
   - Compare behavior with Unconfined profile
   - Verify applied seccomp profile via pod spec

   **Level 3 (Exercises 3.1-3.3): Debugging Filesystem and seccomp Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: application fails with read-only filesystem, seccomp blocking required syscall, missing emptyDir mount

   **Level 4 (Exercises 4.1-4.3): Custom seccomp Profiles**
   - Create and apply a custom seccomp profile (Localhost)
   - Test profile with an application that uses specific syscalls
   - Iterate on profile to allow required syscalls

   **Level 5 (Exercises 5.1-5.3): Defense in Depth**
   - Exercise 5.1: Configure pod with all recommended security controls
   - Exercise 5.2: Debug application with multiple security constraints
   - Exercise 5.3: Design security context strategy for production deployment

3. **Answer Key File**
   - Create the answer key: security-contexts-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Forgetting emptyDir for /tmp when enabling read-only root
     - Wrong profile path for Localhost seccomp
     - Unconfined profile not recommended but sometimes needed for debugging
     - seccomp profile not supported by container runtime
     - Combining too many restrictions and breaking application
   - Security context reference cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of Filesystem and seccomp Profiles assignment
   - Prerequisites: security-contexts/assignment-1, assignment-2
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster
   - Note about seccomp profile location in kind
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- Access to node filesystem for custom seccomp profiles (via exec or volume mount)
- No special cluster configuration needed

RESOURCE GATE:
This assignment uses a restricted resource gate (generation order 10):
- Pods with full securityContext
- ConfigMaps, Secrets, emptyDir volumes
- Namespaces
- Do NOT use: Services, PersistentVolumes, NetworkPolicies

KIND CLUSTER NOTE:
Custom seccomp profiles need to be placed in /var/lib/kubelet/seccomp/ on the kind node. This can be done via nerdctl cp or by mounting a host directory. The tutorial should explain how to work with seccomp profiles in kind.

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
  - exercises/security-contexts/assignment-2: Capabilities and privilege control

- **Follow-up assignments:**
  - exercises/storage/assignment-1: PersistentVolumes (fsGroup interaction)
  - exercises/troubleshooting/assignment-1: Application troubleshooting

COURSE MATERIAL REFERENCE:
- S7 (Lectures 175-178): Security contexts
