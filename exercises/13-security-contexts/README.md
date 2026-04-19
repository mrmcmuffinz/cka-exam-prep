# Security Contexts

**CKA Domain:** Workloads & Scheduling (15%)
**Competencies covered:** Configure Pod admission and scheduling (security context aspects)

---

## Rationale for Number of Assignments

Security contexts control runtime security settings for pods and containers: which user and group the process runs as, which Linux capabilities it has access to, whether it can escalate privileges, whether the root filesystem is writable, and which seccomp profiles apply. This produces roughly 16-18 distinct subtopics. The material splits naturally into three focused progressions: user and group identity with filesystem permissions, capabilities and privilege control, and filesystem constraints with seccomp profiles. Each assignment delivers 5-6 subtopics at depth, building from basic identity management through fine-grained capability control to comprehensive defense-in-depth patterns.

---

## Assignment Summary

| Assignment | Description | Prerequisites |
|---|---|---|
| assignment-1 | User and Group Security | Pod-level securityContext (runAsUser, runAsGroup, fsGroup, supplementalGroups), container-level securityContext (runAsUser, runAsNonRoot), fsGroup interaction with volumes, volume ownership and permission propagation, security context precedence (container overrides pod), verification via exec | 01-pods/assignment-1, 01-pods/assignment-2 |
| assignment-2 | Capabilities and Privilege Control | Linux capabilities overview, adding capabilities (NET_ADMIN, SYS_TIME, SYS_ADMIN), dropping capabilities (CAP_NET_RAW, CAP_SETUID), default capabilities from container runtime, allowPrivilegeEscalation flag and implications, privilege escalation prevention patterns | 13-security-contexts/assignment-1 |
| assignment-3 | Filesystem and seccomp Profiles | readOnlyRootFilesystem flag, combining readOnlyRootFilesystem with writable emptyDir mounts, seccomp profiles (RuntimeDefault, Localhost, Unconfined), creating custom seccomp profiles, seccomp profile debugging, security context best practices and defense in depth | 13-security-contexts/assignment-2 |

## Scope Boundaries

This topic covers runtime security settings on pods and containers. The following related areas are handled by other topics:

- **RBAC** (who can create pods with specific security contexts): covered in `rbac/`
- **Network Policies** (network-level security, distinct from process-level security): covered in `network-policies/`
- **Pod Security Standards/Admission** (namespace-level enforcement of security baselines): covered in `pod-security/`
- **Admission controllers** (validating security configurations at admission time): covered in `admission-controllers/`

Assignment-1 focuses on identity and file permissions. Assignment-2 focuses on process capabilities and privilege escalation. Assignment-3 focuses on filesystem constraints and syscall filtering.

## Cluster Requirements

Single-node kind cluster for all three assignments. Security context enforcement is handled by the container runtime (containerd in kind), which provides full support for user/group identity, capabilities, and seccomp profiles out of the box. No special cluster configuration needed.

## Recommended Order

1. Complete `01-pods/assignment-1` (pod spec fundamentals) and `01-pods/assignment-2` (volume mounts, needed for fsGroup exercises) before this series
2. Work through assignments 1, 2, 3 sequentially
3. Assignment-2 assumes understanding of basic security context structure from assignment-1
4. Assignment-3 assumes understanding of both identity controls and capability management from assignments 1 and 2
