# Security Contexts Assignment 2: Capabilities and Privilege Control

This assignment covers Linux capabilities in Kubernetes security contexts. You will learn how to add and drop capabilities, understand the default capabilities granted by the container runtime, and control privilege escalation with allowPrivilegeEscalation.

## Prerequisites

Before starting this assignment, you should have completed:

- exercises/security-contexts/assignment-1 (User and group security)

You should understand how to configure runAsUser, runAsGroup, and fsGroup from the previous assignment.

## Estimated Time

4-6 hours for tutorial and all exercises.

## Cluster Requirements

This assignment uses a single-node kind cluster with no special configuration required.

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

## What You Will Learn

This assignment teaches capability management in Kubernetes security contexts:

- **Linux capabilities** provide fine-grained privileges instead of all-or-nothing root access
- **capabilities.add** grants specific capabilities to containers
- **capabilities.drop** removes capabilities from containers
- **allowPrivilegeEscalation** controls whether processes can gain more privileges than their parent
- **Defense in depth** patterns combine multiple security controls

You will learn to identify which capabilities an application needs, drop unnecessary capabilities, and prevent privilege escalation.

## Difficulty Progression

**Level 1 (Inspecting Capabilities):** Check default capabilities, compare privileged vs unprivileged containers.

**Level 2 (Adding and Dropping Capabilities):** Add NET_ADMIN, drop NET_RAW, implement drop-all-add-specific patterns.

**Level 3 (Debugging Capability Issues):** Diagnose operations failing due to missing capabilities.

**Level 4 (Privilege Escalation Control):** Configure allowPrivilegeEscalation, combine security controls.

**Level 5 (Complex Scenarios):** Design minimal capability sets, debug multi-constraint failures.

## Recommended Workflow

1. Read the tutorial file to understand Linux capabilities concepts
2. Complete the exercises in order, as later exercises build on earlier concepts
3. Try each exercise before checking the answer key
4. Compare your solutions with the answer key to learn alternative approaches

## Files in This Directory

| File | Description |
|------|-------------|
| `prompt.md` | The generation prompt used to create this assignment |
| `README.md` | This overview file |
| `security-contexts-tutorial.md` | Step-by-step tutorial on capabilities and privilege control |
| `security-contexts-homework.md` | 15 progressive exercises |
| `security-contexts-homework-answers.md` | Complete solutions with explanations |
