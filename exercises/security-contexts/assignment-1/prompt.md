I need you to create a comprehensive Kubernetes homework assignment to help me practice **User and Group Security Contexts**.

CONTEXT:
- I'm studying for the CKA (Certified Kubernetes Administrator) exam
- I'm using a kind cluster with nerdctl (rootless containers, not Docker)
- I have completed the following CKA course sections: S1-S7 (through security contexts)
- I have completed pods/assignment-1 (pod fundamentals) and pods/assignment-2 (volumes)
- I want to build real-world skills, not just pass the exam

SCOPE (IMPORTANT):
This assignment covers user and group identity controls in security contexts: runAsUser, runAsGroup, fsGroup, supplementalGroups, and their interaction with volumes. Capabilities and privilege escalation are covered in assignment-2. Filesystem constraints and seccomp profiles are covered in assignment-3.

**In scope for this assignment:**

*Pod-Level securityContext*
- runAsUser: sets the UID for all containers in the pod
- runAsGroup: sets the primary GID for all containers
- fsGroup: sets the group ownership for mounted volumes
- supplementalGroups: adds additional group memberships
- Pod-level settings as defaults for all containers

*Container-Level securityContext*
- runAsUser at container level (overrides pod level)
- runAsNonRoot: requires container to run as non-root (validation, not enforcement)
- Container-level precedence over pod-level
- When to use pod vs. container level settings

*fsGroup Interaction with Volumes*
- How fsGroup affects mounted volume ownership
- fsGroup recursively chowns volume contents on mount
- Performance implications of fsGroup on large volumes
- fsGroupChangePolicy: OnRootMismatch vs Always
- Which volume types support fsGroup (PVC, emptyDir, configMap, secret)

*Volume Ownership and Permission Propagation*
- Default ownership when no securityContext specified
- emptyDir ownership with fsGroup
- ConfigMap and Secret volume permissions (default 0644)
- Using defaultMode to set permissions on projected volumes
- Combining fsGroup with read-only mounts

*Security Context Precedence*
- Container-level overrides pod-level for shared fields
- Pod-level applies when container-level not specified
- Merged behavior for supplementalGroups

*Verification via exec*
- Using kubectl exec to check effective UID/GID: id command
- Verifying file ownership in mounted volumes: ls -la
- Testing write permissions as specific user
- Confirming group membership

**Out of scope (covered in other assignments, do not include):**

- Linux capabilities (exercises/security-contexts/assignment-2)
- allowPrivilegeEscalation (exercises/security-contexts/assignment-2)
- readOnlyRootFilesystem (exercises/security-contexts/assignment-3)
- seccomp profiles (exercises/security-contexts/assignment-3)
- PersistentVolumes and PVCs in depth (exercises/storage/)
- Network Policies (exercises/network-policies/)
- RBAC (exercises/rbac/)

ASSIGNMENT REQUIREMENTS:

1. **Tutorial File (Separate from Exercises)**
   - Create a standalone tutorial file: security-contexts-tutorial.md
   - Explain why user/group identity matters for security
   - Demonstrate runAsUser and runAsGroup with verification
   - Show fsGroup behavior with emptyDir volumes
   - Explain precedence between pod and container level
   - Show verification techniques with kubectl exec
   - Use tutorial-security-contexts namespace

2. **Homework Exercises File (15 Progressive Exercises)**
   - Create the exercises file: security-contexts-homework.md
   - 15 exercises across 5 difficulty levels (3 exercises per level)

   **Level 1 (Exercises 1.1-1.3): Basic Identity Controls**
   - Run a pod as a specific user (runAsUser)
   - Run a pod as a specific group (runAsGroup)
   - Verify identity with kubectl exec and id command

   **Level 2 (Exercises 2.1-2.3): fsGroup and Volumes**
   - Use fsGroup to set volume ownership
   - Verify file ownership in mounted emptyDir
   - Configure supplementalGroups for additional group access

   **Level 3 (Exercises 3.1-3.3): Debugging Permission Issues**
   - Three debugging exercises
   - Exercise headings are bare (### Exercise 3.1)
   - Scenarios: write fails due to wrong UID, volume ownership mismatch, runAsNonRoot failure

   **Level 4 (Exercises 4.1-4.3): Precedence and Multi-Container**
   - Override pod-level settings at container level
   - Different users in different containers of same pod
   - fsGroup with multiple containers sharing volume

   **Level 5 (Exercises 5.1-5.3): Complex Scenarios**
   - Exercise 5.1: Application requiring specific UID/GID with shared volume
   - Exercise 5.2: Debug multi-container pod with permission conflicts
   - Exercise 5.3: Design security context strategy for a microservice

3. **Answer Key File**
   - Create the answer key: security-contexts-homework-answers.md
   - Full solutions with explanations
   - Common mistakes section covering:
     - Confusing runAsUser (UID) with runAsGroup (GID)
     - Forgetting fsGroup for volume write access
     - runAsNonRoot with image that defaults to root
     - fsGroup not taking effect on read-only volumes
     - Container-level settings not overriding as expected
   - Verification commands cheat sheet

4. **README File for the Assignment**
   - Create: README.md
   - Overview of User and Group Security assignment
   - Prerequisites: pods/assignment-1, pods/assignment-2
   - Estimated time commitment: 4-6 hours
   - Cluster requirements: single-node kind cluster
   - Recommended workflow

ENVIRONMENT REQUIREMENTS:
- Single-node kind cluster
- No special configuration needed
- Container images that support running as non-root

RESOURCE GATE:
This assignment uses a restricted resource gate (generation order 8):
- Pods with securityContext
- ConfigMaps, Secrets (for volume projection)
- emptyDir volumes
- Namespaces
- Do NOT use: Services, PersistentVolumes, NetworkPolicies

CONVENTIONS:
- No em dashes anywhere.
- Narrative paragraph flow in prose sections.
- Exercise namespaces follow `ex-<level>-<exercise>` pattern.
- Tutorial namespace is `tutorial-security-contexts`.
- Debugging exercise headings are bare.
- Container images use explicit version tags: nginx:1.25, busybox:1.36
- Full file replacements when generating.

CROSS-REFERENCES:
- **Prerequisites:**
  - exercises/pods/assignment-1: Pod fundamentals
  - exercises/pods/assignment-2: Volume mounts

- **Follow-up assignments:**
  - exercises/security-contexts/assignment-2: Capabilities and privilege control
  - exercises/security-contexts/assignment-3: Filesystem and seccomp profiles
  - exercises/storage/assignment-1: PersistentVolumes (fsGroup affects PVC mounts)

COURSE MATERIAL REFERENCE:
- S7 (Lectures 175-178): Security contexts
