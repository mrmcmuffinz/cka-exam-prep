# Security Contexts Assignment 3: Filesystem and seccomp Profiles

This assignment covers filesystem constraints and seccomp profiles for Kubernetes security contexts. You will learn how to use readOnlyRootFilesystem to prevent container filesystem modifications, how to apply seccomp profiles for syscall filtering, and how to combine security controls for defense in depth.

## Prerequisites

Before starting this assignment, you should have completed:

- exercises/security-contexts/assignment-1 (User and group security)
- exercises/security-contexts/assignment-2 (Capabilities and privilege control)

You should understand runAsUser, runAsGroup, fsGroup, capabilities, and allowPrivilegeEscalation from the previous assignments.

## Estimated Time

4-6 hours for tutorial and all exercises.

## Cluster Requirements

This assignment uses a single-node kind cluster. Custom seccomp profiles need to be placed in /var/lib/kubelet/seccomp/ on the kind node.

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

## What You Will Learn

This assignment teaches filesystem and syscall-level security controls:

- **readOnlyRootFilesystem** prevents writes to the container's root filesystem
- **emptyDir volumes** provide writable storage when using read-only root
- **seccomp profiles** filter system calls at the kernel level
- **RuntimeDefault** applies the container runtime's default seccomp policy
- **Localhost profiles** use custom seccomp profiles from the node
- **Defense in depth** combines all security controls

## Difficulty Progression

**Level 1 (Read-Only Filesystem):** Enable readOnlyRootFilesystem, add emptyDir for writable directories.

**Level 2 (seccomp Basics):** Apply RuntimeDefault profile, compare with Unconfined.

**Level 3 (Debugging Issues):** Diagnose failures caused by read-only filesystem and seccomp blocking.

**Level 4 (Custom seccomp Profiles):** Create and apply custom Localhost profiles.

**Level 5 (Defense in Depth):** Combine all security controls for hardened containers.

## Recommended Workflow

1. Read the tutorial file to understand filesystem and seccomp concepts
2. Complete the exercises in order, as later exercises build on earlier concepts
3. Try each exercise before checking the answer key
4. Compare your solutions with the answer key to learn alternative approaches

## Note About seccomp in kind

Custom seccomp profiles must be placed in /var/lib/kubelet/seccomp/ on the kind node. The tutorial explains how to copy profiles to the kind node using nerdctl cp or kubectl cp.

## Files in This Directory

| File | Description |
|------|-------------|
| `prompt.md` | The generation prompt used to create this assignment |
| `README.md` | This overview file |
| `security-contexts-tutorial.md` | Step-by-step tutorial on filesystem and seccomp |
| `security-contexts-homework.md` | 15 progressive exercises |
| `security-contexts-homework-answers.md` | Complete solutions with explanations |
