# Security Contexts Assignment 1: User and Group Security

This assignment covers user and group identity controls in Kubernetes security contexts. You will learn how to control the user and group identity that containers run as, how to set volume ownership with fsGroup, and how pod-level and container-level security settings interact.

## Prerequisites

Before starting this assignment, you should have completed:

- exercises/pods/assignment-1 (Pod fundamentals)
- exercises/pods/assignment-2 (Volume mounts)

You should be comfortable creating pods with volumes and understand basic container security concepts.

## Estimated Time

4-6 hours for tutorial and all exercises.

## Cluster Requirements

This assignment uses a single-node kind cluster with no special configuration required.

```bash
KIND_EXPERIMENTAL_PROVIDER=nerdctl kind create cluster
```

## What You Will Learn

This assignment teaches the identity-related fields in Kubernetes security contexts:

- **runAsUser** sets the UID that containers run as
- **runAsGroup** sets the primary GID for containers
- **fsGroup** sets group ownership for mounted volumes
- **supplementalGroups** adds additional group memberships
- **runAsNonRoot** validates that containers do not run as root

You will also learn how pod-level settings serve as defaults that container-level settings can override.

## Difficulty Progression

**Level 1 (Basic Identity Controls):** Run pods as specific users and groups, verify identity with kubectl exec.

**Level 2 (fsGroup and Volumes):** Configure volume ownership with fsGroup, understand supplementalGroups.

**Level 3 (Debugging Permission Issues):** Diagnose and fix containers that fail due to UID/GID misconfigurations.

**Level 4 (Precedence and Multi-Container):** Override pod-level settings at container level, configure different users for different containers.

**Level 5 (Complex Scenarios):** Design security context strategies for real applications, debug multi-container permission conflicts.

## Recommended Workflow

1. Read the tutorial file to understand user and group security concepts
2. Complete the exercises in order, as later exercises build on earlier concepts
3. Try each exercise before checking the answer key
4. Compare your solutions with the answer key to learn alternative approaches

## Files in This Directory

| File | Description |
|------|-------------|
| `prompt.md` | The generation prompt used to create this assignment |
| `README.md` | This overview file |
| `security-contexts-tutorial.md` | Step-by-step tutorial on user and group security |
| `security-contexts-homework.md` | 15 progressive exercises |
| `security-contexts-homework-answers.md` | Complete solutions with explanations |
