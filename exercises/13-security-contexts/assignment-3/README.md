# Assignment 3: Read-Only Root Filesystem and seccomp Profiles

This is the third and final Security Contexts assignment. Assignment 1 covered identity (UID, GID, `fsGroup`, `supplementalGroups`). Assignment 2 covered Linux capabilities and `allowPrivilegeEscalation`. This assignment covers two remaining layers: `readOnlyRootFilesystem`, which makes the container's root filesystem immutable at runtime, and `seccompProfile`, which filters what syscalls the container process can make. Together with Pod Security Admission (`exercises/14-14-pod-security/assignment-1`), these three assignments cover every field the Restricted profile cares about.

## Files

| File | Purpose |
|---|---|
| `prompt.md` | The generation prompt (input to the homework generator skill) |
| `README.md` | This overview |
| `security-contexts-tutorial.md` | Step-by-step tutorial teaching read-only root, writable mount patterns, and seccomp profiles |
| `security-contexts-homework.md` | 15 progressive exercises across five difficulty levels |
| `security-contexts-homework-answers.md` | Complete solutions with diagnostic reasoning and common mistakes |

## Recommended Workflow

Work through the tutorial first. Part 1 enables `readOnlyRootFilesystem: true` and proves that writes to `/tmp` and `/var/run` fail, then introduces the `emptyDir` pattern that makes specific paths writable without reintroducing the whole root filesystem's write surface. Part 2 introduces seccomp: the three profile types (`RuntimeDefault`, `Localhost`, `Unconfined`), the containerd default profile, and how to verify which profile is applied via the `Seccomp_filters` line in `/proc/self/status`. Part 3 walks through creating a custom Localhost profile, copying it into kind's node filesystem (the kind-specific `nerdctl cp` path), and applying it. The homework then practices each piece and combines them. Level 3 debugging and Level 5 comprehensive scenarios assume you can distinguish a seccomp-blocked syscall (`Operation not permitted` from the specific syscall) from a read-only-filesystem error (`Read-only file system` on writes).

## Difficulty Progression

Level 1 is read-only root basics: enable the flag, observe the failure, add an `emptyDir` for `/tmp`, and identify which paths an application writes. Level 2 is seccomp basics: apply `RuntimeDefault`, compare against `Unconfined`, read the applied profile from inside. Level 3 is debugging: the container is failing and you must diagnose whether the cause is filesystem, seccomp, or something else. Level 4 is custom seccomp profiles: create a Localhost profile, copy it to the kind node, apply it, and iterate until the workload runs. Level 5 is comprehensive defense-in-depth: a pod with every security control at once, a debugging scenario where multiple layers interact to block a legal operation, and a production-style design task.

## Prerequisites

Complete `exercises/13-13-security-contexts/assignment-1` (identity) and `exercises/13-13-security-contexts/assignment-2` (capabilities and privilege escalation) first. This assignment combines them; some exercises require `runAsNonRoot: true` plus `capabilities.drop: ["ALL"]` plus the fields introduced here.

## Cluster Requirements

A single-node kind cluster is sufficient. See `docs/cluster-setup.md#single-node-kind-cluster` for the creation command. The Level 4 custom-seccomp-profile exercises require access to the kind node's filesystem via `nerdctl` or `docker exec` for copying profiles to `/var/lib/kubelet/seccomp/`; the tutorial walks through the exact command. No other components are required.

## Estimated Time Commitment

The tutorial takes 60 to 90 minutes because custom seccomp profiles require a hands-on copy-to-node step. The 15 exercises together take four to six hours. Level 1 runs 10 to 15 minutes per exercise; Level 2 runs 15 to 20 minutes; Level 3 debugging runs 15 to 25 minutes per exercise; Level 4 custom-seccomp exercises take 25 to 35 minutes per exercise because of the node-copy step; Level 5 comprehensive exercises run 30 to 45 minutes each.

## Scope Boundary and What Comes Next

This assignment covers `readOnlyRootFilesystem`, `seccompProfile`, and the combination of every securityContext field across the three assignments into a hardened baseline. Pod Security Admission (how a namespace-level label enforces these settings across every pod) is `exercises/14-14-pod-security/assignment-1`. Admission webhooks and ValidatingAdmissionPolicy (arbitrary policy beyond PSS) are `exercises/16-16-admission-controllers/assignment-1`. Network policy (which complements workload hardening at the network layer) is `exercises/10-network-policies/`. AppArmor and SELinux are referenced but not exercised; their production use generally requires distro-specific tooling outside the CKA scope.

## Key Takeaways After Completing This Assignment

After finishing all 15 exercises you should be able to set `readOnlyRootFilesystem: true` on a container and identify every path the application needs to write, plan the `emptyDir` (or `tmpfs`) mounts that replace those paths, read a `Read-only file system` error and map it to the failing write path, apply `RuntimeDefault` as the seccomp profile and read the applied profile from inside the container, identify a syscall blocked by seccomp by its error signature (the same `Operation not permitted` as a missing capability, but from a different syscall class), create a Localhost seccomp profile as a JSON file on the kind node, apply it from a pod spec via `seccompProfile.type: Localhost` plus `localhostProfile: <path>`, iterate on the profile to allow syscalls a failing application needs, and combine every security-context field from all three assignments into one hardened baseline that satisfies Pod Security Admission's Restricted profile.
